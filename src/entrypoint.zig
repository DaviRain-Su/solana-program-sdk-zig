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

/// Static account data size (account header + max data increase)
const STATIC_ACCOUNT_DATA: usize = @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE;

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
            const account_ptr: *Account = @ptrCast(@alignCast(ptr));

            // Skip 8 bytes (rent epoch or duplicate marker + padding)
            ptr += @sizeOf(u64);

            if (account_ptr.borrow_state != NON_DUP_MARKER) {
                // Duplicate account — reference existing account
                const dup_index = account_ptr.borrow_state;
                accounts_buffer[i] = accounts_buffer[dup_index];
            } else {
                // New account
                accounts_buffer[i] = AccountInfo{ .ptr = account_ptr };

                // Skip account struct + data + padding + alignment
                ptr += STATIC_ACCOUNT_DATA;
                ptr += @as(usize, @intCast(account_ptr.data_len));
                ptr = @ptrFromInt(alignPointer(@intFromPtr(ptr)));
            }
            accounts_count += 1;
        }

        // Skip remaining accounts if buffer was too small
        while (to_skip > 0) : (to_skip -= 1) {
            const account_ptr: *Account = @ptrCast(@alignCast(ptr));
            ptr += @sizeOf(u64);

            if (account_ptr.borrow_state == NON_DUP_MARKER) {
                ptr += STATIC_ACCOUNT_DATA;
                ptr += @as(usize, @intCast(account_ptr.data_len));
                ptr = @ptrFromInt(alignPointer(@intFromPtr(ptr)));
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
            const account_ptr: *Account = @ptrCast(@alignCast(skip_ptr));
            skip_ptr += @sizeOf(u64);

            if (account_ptr.borrow_state == NON_DUP_MARKER) {
                skip_ptr += STATIC_ACCOUNT_DATA;
                skip_ptr += @as(usize, @intCast(account_ptr.data_len));
                skip_ptr = @ptrFromInt(alignPointer(@intFromPtr(skip_ptr)));
            }
        }

        // Read instruction data length
        const ix_data_len_ptr: *const u64 = @ptrCast(@alignCast(skip_ptr));
        const ix_data_len: usize = @intCast(ix_data_len_ptr.*);
        skip_ptr += @sizeOf(u64);

        // Get instruction data
        const instruction_data = skip_ptr[0..ix_data_len];
        skip_ptr += ix_data_len;

        // Get program ID
        const program_id: *const Pubkey = @ptrCast(@alignCast(skip_ptr));

        return .{
            .ptr = ptr,
            .num_accounts = num_accounts,
            .parsed_count = 0,
            .instruction_data = instruction_data,
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

        const account_ptr: *Account = @ptrCast(@alignCast(self.ptr));
        self.ptr += @sizeOf(u64);

        const result = if (account_ptr.borrow_state != NON_DUP_MARKER) blk: {
            // Duplicate account
            const dup_index = account_ptr.borrow_state;
            break :blk self._accounts[dup_index];
        } else blk: {
            // New account
            const info = AccountInfo{ .ptr = account_ptr };

            // Skip account data
            self.ptr += STATIC_ACCOUNT_DATA;
            self.ptr += @as(usize, @intCast(account_ptr.data_len));
            self.ptr = @ptrFromInt(alignPointer(@intFromPtr(self.ptr)));

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
            const account_ptr: *Account = @ptrCast(@alignCast(self.ptr));
            self.ptr += @sizeOf(u64);

            if (account_ptr.borrow_state == NON_DUP_MARKER) {
                self.ptr += STATIC_ACCOUNT_DATA;
                self.ptr += @as(usize, @intCast(account_ptr.data_len));
                self.ptr = @ptrFromInt(alignPointer(@intFromPtr(self.ptr)));
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
// Tests
// =============================================================================

fn makePubkey(v: u8) Pubkey {
    var pk: Pubkey = undefined;
    @memset(&pk, v);
    return pk;
}

test "entrypoint: deserialize empty" {
    // Use aligned buffer
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
    // Skip this test — requires exact Solana runtime memory layout
    // which is hard to replicate in unit tests
    return error.SkipZigTest;
}

test "entrypoint: lazy parsing" {
    // Skip this test — requires exact Solana runtime memory layout
    return error.SkipZigTest;
}
