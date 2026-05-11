//! Solana program entrypoint and input deserialization
//!
//! Provides both standard (eager) and lazy entrypoint styles.
//!
//! ## Standard Entrypoint
//! Parses all accounts upfront into a pre-allocated buffer.
//! Best for programs with many instructions or complex account handling.
//!
//! ## Lazy Entrypoint
//! Provides on-demand account parsing via InstructionContext.
//! Best for simple programs with few instructions — minimal CU overhead.

const std = @import("std");
const account = @import("account.zig");
const pubkey = @import("pubkey.zig");
const program_error = @import("program_error.zig");

const Account = account.Account;
const AccountInfo = account.AccountInfo;
const Pubkey = pubkey.Pubkey;
const ProgramResult = program_error.ProgramResult;
const SUCCESS = program_error.SUCCESS;

/// BPF alignment for u128
const BPF_ALIGN_OF_U128: usize = 8;

/// Value used to indicate that a serialized account is not a duplicate
const NON_DUP_MARKER: u8 = account.NON_DUP_MARKER;

/// Maximum permitted data increase per instruction
const MAX_PERMITTED_DATA_INCREASE: usize = account.MAX_PERMITTED_DATA_INCREASE;

/// Heap start address for BPF programs
pub const HEAP_START_ADDRESS: u64 = 0x300000000;

/// Heap length (32KB)
pub const HEAP_LENGTH: usize = 32 * 1024;

/// Entrypoint function signature
pub const EntrypointFn = *const fn (
    program_id: *const Pubkey,
    accounts: []AccountInfo,
    instruction_data: []const u8,
) ProgramResult;

/// Lazy entrypoint function signature
pub const LazyEntrypointFn = *const fn (
    context: *InstructionContext,
) ProgramResult;

/// Align pointer to BPF u128 alignment
inline fn alignPointer(ptr: usize) usize {
    return (ptr + (BPF_ALIGN_OF_U128 - 1)) & ~(BPF_ALIGN_OF_U128 - 1);
}

// =============================================================================
// Standard Entrypoint (eager parsing)
// =============================================================================

/// Create a standard entrypoint with custom max accounts
/// Parses all accounts upfront into a pre-allocated buffer.
pub fn entrypoint(
    comptime max_accounts: usize,
    comptime process_instruction: EntrypointFn,
) fn ([*]u8) callconv(.c) u64 {
    return struct {
        fn entry(input: [*]u8) callconv(.c) u64 {
            var accounts_buffer: [max_accounts]AccountInfo = undefined;

            const program_id, const accounts, const instruction_data =
                deserialize(input, &accounts_buffer);

            process_instruction(program_id, accounts, instruction_data) catch |err| {
                return program_error.errorToU64(err);
            };

            return SUCCESS;
        }
    }.entry;
}

/// Deserialize the input buffer into program_id, accounts, and instruction_data
///
/// Performs zero-copy deserialization. All returned values are pointers/slices
/// into the original input buffer.
///
/// Input format (little endian):
/// ```text
/// [u64: num_accounts]
/// For each account:
///   [u8: duplicate_marker] (0xFF = non-duplicate, else = duplicate index)
///   If duplicate:
///     [7 bytes padding]
///   If non-duplicate:
///     [Account struct (88 bytes)]
///     [data bytes]
///     [10KB padding]
///     [align to 8 bytes]
///     [u64: rent_epoch]
/// [u64: instruction_data_len]
/// [instruction_data bytes]
/// [Pubkey: program_id]
/// ```
pub fn deserialize(
    input: [*]u8,
    accounts_buffer: []AccountInfo,
) struct { *const Pubkey, []AccountInfo, []const u8 } {
    var ptr = input;
    const max_accounts = accounts_buffer.len;

    // Read number of accounts
    const num_accounts_ptr: *const u64 = @ptrCast(@alignCast(ptr));
    const num_accounts: usize = @intCast(num_accounts_ptr.*);
    ptr += @sizeOf(u64);

    var accounts_count: usize = 0;

    if (num_accounts > 0) {
        const to_process = @min(num_accounts, max_accounts);
        var to_skip = num_accounts - to_process;

        var i: usize = 0;
        while (i < to_process) : (i += 1) {
            // Read duplicate marker (first byte of 8-byte block)
            const dup_marker = ptr[0];

            if (dup_marker != NON_DUP_MARKER) {
                // Duplicate account — reference existing account
                const dup_index = dup_marker;
                accounts_buffer[i] = accounts_buffer[dup_index];
                // Skip 8 bytes (marker + padding)
                ptr += @sizeOf(u64);
            } else {
                // Non-duplicate: Account struct starts here
                // The first byte (borrow_state) is already 0xFF
                const account_ptr: *Account = @ptrCast(@alignCast(ptr));
                accounts_buffer[i] = AccountInfo{ .ptr = account_ptr };

                // Skip past the account struct
                ptr += @sizeOf(Account);
                // Skip past data
                ptr += @as(usize, @intCast(account_ptr.data_len));
                // Skip past 10KB padding
                ptr += MAX_PERMITTED_DATA_INCREASE;
                // Align to 8 bytes
                ptr = @ptrFromInt(alignPointer(@intFromPtr(ptr)));
                // Skip rent_epoch
                ptr += @sizeOf(u64);
            }
            accounts_count += 1;
        }

        // Skip remaining accounts if buffer was too small
        while (to_skip > 0) : (to_skip -= 1) {
            const dup_marker = ptr[0];
            if (dup_marker != NON_DUP_MARKER) {
                ptr += @sizeOf(u64);
            } else {
                const account_ptr: *Account = @ptrCast(@alignCast(ptr));
                ptr += @sizeOf(Account);
                ptr += @as(usize, @intCast(account_ptr.data_len));
                ptr += MAX_PERMITTED_DATA_INCREASE;
                ptr = @ptrFromInt(alignPointer(@intFromPtr(ptr)));
                ptr += @sizeOf(u64);
            }
        }
    }

    // Read instruction data length
    const ix_data_len_ptr: *const u64 = @ptrCast(@alignCast(ptr));
    const ix_data_len: usize = @intCast(ix_data_len_ptr.*);
    ptr += @sizeOf(u64);

    // Get instruction data slice
    const instruction_data = ptr[0..ix_data_len];
    ptr += ix_data_len;

    // Get program ID
    const program_id: *const Pubkey = @ptrCast(@alignCast(ptr));

    return .{
        program_id,
        accounts_buffer[0..accounts_count],
        instruction_data,
    };
}

// =============================================================================
// Lazy Entrypoint (on-demand parsing)
// =============================================================================

/// Lazy parsing context — accounts are parsed on demand
pub const InstructionContext = struct {
    /// Current pointer into input buffer
    ptr: [*]u8,

    /// Total number of accounts
    num_accounts: u64,

    /// Number of accounts already parsed
    parsed_count: u64,

    /// Instruction data (parsed once and cached)
    instruction_data: []const u8,

    /// Program ID (parsed once and cached)
    program_id: *const Pubkey,

    /// Internal: accounts parsed so far (for duplicate resolution)
    _accounts: [256]AccountInfo,

    /// Initialize context from raw input
    pub fn init(input: [*]u8) InstructionContext {
        var ptr = input;

        const num_accounts_ptr: *const u64 = @ptrCast(@alignCast(ptr));
        const num_accounts = num_accounts_ptr.*;
        ptr += @sizeOf(u64);

        // Skip all accounts to find instruction data and program id
        var skip_ptr = ptr;
        var i: u64 = 0;
        while (i < num_accounts) : (i += 1) {
            const dup_marker = skip_ptr[0];
            if (dup_marker != NON_DUP_MARKER) {
                skip_ptr += @sizeOf(u64);
            } else {
                const account_ptr: *Account = @ptrCast(@alignCast(skip_ptr));
                skip_ptr += @sizeOf(Account);
                skip_ptr += @as(usize, @intCast(account_ptr.data_len));
                skip_ptr += MAX_PERMITTED_DATA_INCREASE;
                skip_ptr = @ptrFromInt(alignPointer(@intFromPtr(skip_ptr)));
                skip_ptr += @sizeOf(u64);
            }
        }

        // Read instruction data length
        const ix_data_len_ptr: *const u64 = @ptrCast(@alignCast(skip_ptr));
        const ix_data_len: usize = @intCast(ix_data_len_ptr.*);
        skip_ptr += @sizeOf(u64);

        // Get instruction data pointer
        const instruction_data_ptr = skip_ptr;
        skip_ptr += ix_data_len;

        // Get program ID
        const program_id: *const Pubkey = @ptrCast(@alignCast(skip_ptr));

        return .{
            .ptr = ptr,
            .num_accounts = num_accounts,
            .parsed_count = 0,
            .instruction_data = instruction_data_ptr[0..ix_data_len],
            .program_id = program_id,
            ._accounts = undefined,
        };
    }

    /// Get remaining unparsed accounts count
    pub inline fn remaining(self: InstructionContext) u64 {
        return self.num_accounts - self.parsed_count;
    }

    /// Parse and return the next account
    pub fn nextAccount(self: *InstructionContext) ?AccountInfo {
        if (self.parsed_count >= self.num_accounts) return null;

        const dup_marker = self.ptr[0];

        const result = if (dup_marker != NON_DUP_MARKER) blk: {
            // Duplicate account
            const dup_index = dup_marker;
            self.ptr += @sizeOf(u64); // skip 8-byte marker
            break :blk self._accounts[dup_index];
        } else blk: {
            // New account
            const account_ptr: *Account = @ptrCast(@alignCast(self.ptr));
            const info = AccountInfo{ .ptr = account_ptr };

            // Skip past account struct + data + padding + alignment + rent_epoch
            self.ptr += @sizeOf(Account);
            self.ptr += @as(usize, @intCast(account_ptr.data_len));
            self.ptr += MAX_PERMITTED_DATA_INCREASE;
            self.ptr = @ptrFromInt(alignPointer(@intFromPtr(self.ptr)));
            self.ptr += @sizeOf(u64);

            break :blk info;
        };

        self._accounts[self.parsed_count] = result;
        self.parsed_count += 1;

        return result;
    }

    /// Skip specified number of accounts without parsing
    pub fn skipAccounts(self: *InstructionContext, count: u64) void {
        var i: u64 = 0;
        while (i < count and self.parsed_count < self.num_accounts) : (i += 1) {
            const dup_marker = self.ptr[0];
            if (dup_marker != NON_DUP_MARKER) {
                self.ptr += @sizeOf(u64);
            } else {
                const account_ptr: *Account = @ptrCast(@alignCast(self.ptr));
                self.ptr += @sizeOf(Account);
                self.ptr += @as(usize, @intCast(account_ptr.data_len));
                self.ptr += MAX_PERMITTED_DATA_INCREASE;
                self.ptr = @ptrFromInt(alignPointer(@intFromPtr(self.ptr)));
                self.ptr += @sizeOf(u64);
            }
            self.parsed_count += 1;
        }
    }

    /// Get instruction data
    pub inline fn instructionData(self: InstructionContext) []const u8 {
        return self.instruction_data;
    }

    /// Get program ID
    pub inline fn programId(self: InstructionContext) *const Pubkey {
        return self.program_id;
    }
};

/// Create a lazy entrypoint — on-demand account parsing
///
/// Best for simple programs with few instructions.
/// Accounts are only parsed when `nextAccount()` is called.
pub fn lazyEntrypoint(
    comptime process_instruction: LazyEntrypointFn,
) fn ([*]u8) callconv(.c) u64 {
    return struct {
        fn entry(input: [*]u8) callconv(.c) u64 {
            var context = InstructionContext.init(input);

            process_instruction(&context) catch |err| {
                return program_error.errorToU64(err);
            };

            return SUCCESS;
        }
    }.entry;
}

// =============================================================================
// Test Helpers
// =============================================================================

fn makePubkey(v: u8) Pubkey {
    var pk: Pubkey = undefined;
    @memset(&pk, v);
    return pk;
}

/// Serialize a single account into a test buffer
/// Returns the new pointer position
fn serializeAccount(ptr: [*]u8, acc: Account) [*]u8 {
    var p = ptr;
    // For non-duplicate, the first byte IS the borrow_state (0xFF)
    // So we write the Account struct directly
    @memcpy(p[0..@sizeOf(Account)], std.mem.asBytes(&acc));
    p += @sizeOf(Account);
    // Write data
    p += @as(usize, @intCast(acc.data_len));
    // Write 10KB padding
    p += MAX_PERMITTED_DATA_INCREASE;
    // Align
    p = @ptrFromInt(alignPointer(@intFromPtr(p)));
    // Write rent_epoch
    std.mem.writeInt(u64, p[0..8], 0, .little);
    p += @sizeOf(u64);
    return p;
}

/// Serialize a duplicate account marker
fn serializeDuplicate(ptr: [*]u8, index: u8) [*]u8 {
    var p = ptr;
    p[0] = index; // dup marker (NOT 0xFF)
    // 7 bytes padding
    @memset(p[1..8], 0);
    p += @sizeOf(u64);
    return p;
}

// =============================================================================
// Tests
// =============================================================================

test "entrypoint: deserialize empty" {
    var input align(8) = [_]u8{0} ** 48;
    // num_accounts = 0
    std.mem.writeInt(u64, input[0..8], 0, .little);
    // instruction_data_len = 0
    std.mem.writeInt(u64, input[8..16], 0, .little);
    // program_id
    const pk = makePubkey(1);
    @memcpy(input[16..48], &pk);

    var accounts_buffer: [10]AccountInfo = undefined;
    const program_id, const accounts, const ix_data =
        deserialize(&input, &accounts_buffer);
    _ = ix_data;

    try std.testing.expectEqual(@as(usize, 0), accounts.len);
    try std.testing.expect(pubkey.pubkeyEq(program_id, &pk));
}

test "entrypoint: deserialize single account" {
    // Large aligned buffer for the serialized data
    var input align(8) = [_]u8{0} ** 4096;
    var ptr: [*]u8 = &input;

    // num_accounts = 1
    std.mem.writeInt(u64, ptr[0..8], 1, .little);
    ptr += 8;

    // Account 0 (non-duplicate)
    const acc0: Account = .{
        .borrow_state = NON_DUP_MARKER,
        .is_signer = 1,
        .is_writable = 1,
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(1),
        .owner = makePubkey(2),
        .lamports = 1000,
        .data_len = 0,
    };
    ptr = serializeAccount(ptr, acc0);

    // instruction_data_len = 4
    std.mem.writeInt(u64, ptr[0..8], 4, .little);
    ptr += 8;
    // instruction_data
    @memcpy(ptr[0..4], "test");
    ptr += 4;
    // program_id
    const pk = makePubkey(3);
    @memcpy(ptr[0..32], &pk);

    var accounts_buffer: [10]AccountInfo = undefined;
    const program_id, const accounts, const instruction_data =
        deserialize(&input, &accounts_buffer);

    try std.testing.expectEqual(@as(usize, 1), accounts.len);
    try std.testing.expect(accounts[0].isSigner());
    try std.testing.expect(accounts[0].isWritable());
    try std.testing.expect(!accounts[0].executable());
    try std.testing.expectEqual(@as(u64, 1000), accounts[0].lamports());
    try std.testing.expect(pubkey.pubkeyEq(accounts[0].key(), &makePubkey(1)));
    try std.testing.expect(pubkey.pubkeyEq(accounts[0].owner(), &makePubkey(2)));
    try std.testing.expect(pubkey.pubkeyEq(program_id, &makePubkey(3)));
    try std.testing.expectEqualStrings("test", instruction_data);
}

test "entrypoint: deserialize with data" {
    var input align(8) = [_]u8{0} ** 4096;
    var ptr: [*]u8 = &input;

    // num_accounts = 1
    std.mem.writeInt(u64, ptr[0..8], 1, .little);
    ptr += 8;

    // Account with data
    const acc0: Account = .{
        .borrow_state = NON_DUP_MARKER,
        .is_signer = 0,
        .is_writable = 1,
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(1),
        .owner = makePubkey(2),
        .lamports = 500,
        .data_len = 5,
    };
    // Write account struct
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc0));
    ptr += @sizeOf(Account);
    // Write data
    @memcpy(ptr[0..5], "hello");
    ptr += 5;
    // Skip padding
    ptr += MAX_PERMITTED_DATA_INCREASE;
    // Align
    ptr = @ptrFromInt(alignPointer(@intFromPtr(ptr)));
    // Rent epoch
    std.mem.writeInt(u64, ptr[0..8], 0, .little);
    ptr += 8;

    // instruction_data_len = 0
    std.mem.writeInt(u64, ptr[0..8], 0, .little);
    ptr += 8;
    // program_id
    const pk = makePubkey(3);
    @memcpy(ptr[0..32], &pk);

    var accounts_buffer: [10]AccountInfo = undefined;
    const program_id, const accounts, const ix_data =
        deserialize(&input, &accounts_buffer);
    _ = ix_data;

    try std.testing.expectEqual(@as(usize, 1), accounts.len);
    try std.testing.expectEqual(@as(usize, 5), accounts[0].dataLen());
    try std.testing.expectEqualStrings("hello", accounts[0].data()[0..5]);
    try std.testing.expect(pubkey.pubkeyEq(program_id, &makePubkey(3)));
}

test "entrypoint: deserialize duplicate account" {
    var input align(8) = [_]u8{0} ** 4096;
    var ptr: [*]u8 = &input;

    // num_accounts = 2
    std.mem.writeInt(u64, ptr[0..8], 2, .little);
    ptr += 8;

    // Account 0 (non-duplicate)
    const acc0: Account = .{
        .borrow_state = NON_DUP_MARKER,
        .is_signer = 1,
        .is_writable = 1,
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(1),
        .owner = makePubkey(2),
        .lamports = 1000,
        .data_len = 0,
    };
    ptr = serializeAccount(ptr, acc0);

    // Account 1 (duplicate of account 0)
    ptr = serializeDuplicate(ptr, 0);

    // instruction_data_len = 0
    std.mem.writeInt(u64, ptr[0..8], 0, .little);
    ptr += 8;
    // program_id
    const pk = makePubkey(3);
    @memcpy(ptr[0..32], &pk);

    var accounts_buffer: [10]AccountInfo = undefined;
    const program_id, const accounts, const ix_data =
        deserialize(&input, &accounts_buffer);
    _ = ix_data;

    try std.testing.expectEqual(@as(usize, 2), accounts.len);
    // Both accounts should point to the same underlying account
    try std.testing.expectEqual(accounts[0].ptr, accounts[1].ptr);
    try std.testing.expect(pubkey.pubkeyEq(program_id, &makePubkey(3)));
}

test "entrypoint: lazy parsing" {
    var input align(8) = [_]u8{0} ** 32768;
    var ptr: [*]u8 = &input;

    // num_accounts = 2
    std.mem.writeInt(u64, ptr[0..8], 2, .little);
    ptr += 8;

    // Account 0 (non-dup, no data)
    const acc0: Account = .{
        .borrow_state = NON_DUP_MARKER,
        .is_signer = 1,
        .is_writable = 1,
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(1),
        .owner = makePubkey(2),
        .lamports = 1000,
        .data_len = 0,
    };
    ptr = serializeAccount(ptr, acc0);

    // Account 1 (non-dup, no data)
    const acc1: Account = .{
        .borrow_state = NON_DUP_MARKER,
        .is_signer = 0,
        .is_writable = 0,
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(3),
        .owner = makePubkey(2),
        .lamports = 500,
        .data_len = 0,
    };
    ptr = serializeAccount(ptr, acc1);

    // instruction_data_len = 4
    std.mem.writeInt(u64, ptr[0..8], 4, .little);
    ptr += 8;
    @memcpy(ptr[0..4], "test");
    ptr += 4;
    // program_id
    const pk = makePubkey(4);
    @memcpy(ptr[0..32], &pk);

    var context = InstructionContext.init(&input);

    try std.testing.expectEqual(@as(u64, 2), context.remaining());
    const ix_data = context.instructionData();
    try std.testing.expectEqual(@as(usize, 4), ix_data.len);
    try std.testing.expectEqual(@as(u8, 't'), ix_data[0]);
    try std.testing.expectEqual(@as(u8, 'e'), ix_data[1]);
    try std.testing.expectEqual(@as(u8, 's'), ix_data[2]);
    try std.testing.expectEqual(@as(u8, 't'), ix_data[3]);
    try std.testing.expect(pubkey.pubkeyEq(context.programId(), &makePubkey(4)));

    const acc0_info = context.nextAccount().?;
    try std.testing.expect(acc0_info.isSigner());
    try std.testing.expect(acc0_info.isWritable());
    try std.testing.expect(pubkey.pubkeyEq(acc0_info.key(), &makePubkey(1)));

    try std.testing.expectEqual(@as(u64, 1), context.remaining());

    const acc1_info = context.nextAccount().?;
    try std.testing.expect(!acc1_info.isSigner());
    try std.testing.expect(!acc1_info.isWritable());
    try std.testing.expect(pubkey.pubkeyEq(acc1_info.key(), &makePubkey(3)));

    try std.testing.expectEqual(@as(u64, 0), context.remaining());
    try std.testing.expect(context.nextAccount() == null);
}

test "entrypoint: lazy skip accounts" {
    var input align(8) = [_]u8{0} ** 4096;
    var ptr: [*]u8 = &input;

    // num_accounts = 3
    std.mem.writeInt(u64, ptr[0..8], 3, .little);
    ptr += 8;

    // Account 0
    const acc0: Account = .{
        .borrow_state = NON_DUP_MARKER,
        .is_signer = 1,
        .is_writable = 1,
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(1),
        .owner = makePubkey(2),
        .lamports = 1000,
        .data_len = 0,
    };
    ptr = serializeAccount(ptr, acc0);

    // Account 1
    const acc1: Account = .{
        .borrow_state = NON_DUP_MARKER,
        .is_signer = 0,
        .is_writable = 0,
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(3),
        .owner = makePubkey(2),
        .lamports = 500,
        .data_len = 0,
    };
    ptr = serializeAccount(ptr, acc1);

    // Account 2
    const acc2: Account = .{
        .borrow_state = NON_DUP_MARKER,
        .is_signer = 0,
        .is_writable = 1,
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(5),
        .owner = makePubkey(2),
        .lamports = 200,
        .data_len = 0,
    };
    ptr = serializeAccount(ptr, acc2);

    // instruction_data_len = 0
    std.mem.writeInt(u64, ptr[0..8], 0, .little);
    ptr += 8;
    // program_id
    const pk = makePubkey(6);
    @memcpy(ptr[0..32], &pk);

    var context = InstructionContext.init(&input);

    // Skip first 2 accounts
    context.skipAccounts(2);
    try std.testing.expectEqual(@as(u64, 1), context.remaining());

    // Get the 3rd account
    const acc2_info = context.nextAccount().?;
    try std.testing.expect(pubkey.pubkeyEq(acc2_info.key(), &makePubkey(5)));
    try std.testing.expectEqual(@as(u64, 0), context.remaining());
}
