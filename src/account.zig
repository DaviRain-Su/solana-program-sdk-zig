const std = @import("std");
const pubkey = @import("pubkey.zig");
const program_error = @import("program_error.zig");

const Pubkey = pubkey.Pubkey;
const ProgramError = program_error.ProgramError;

/// Value used to indicate that a serialized account is not a duplicate
pub const NON_DUP_MARKER: u8 = 0xFF;

/// Maximum permitted data increase per instruction
pub const MAX_PERMITTED_DATA_INCREASE: usize = 10 * 1024;

/// Maximum number of accounts that a transaction may process
pub const MAX_TX_ACCOUNTS: usize = 256; // u8::MAX

/// BPF alignment for u128
pub const BPF_ALIGN_OF_U128: usize = 8;

/// Not borrowed state (all bits set)
pub const NOT_BORROWED: u8 = 0xFF;

/// Borrow state masks
pub const BorrowState = enum(u8) {
    /// Mask to check if account is borrowed (any borrow)
    Borrowed = 0b11111111,
    /// Mask to check if account is mutably borrowed
    MutablyBorrowed = 0b10001000,
};

/// Bit shift for lamports borrow tracking
const LAMPORTS_BORROW_SHIFT: u3 = 4;

/// Bit shift for data borrow tracking
const DATA_BORROW_SHIFT: u3 = 0;

/// Bitmask for lamports mutable borrow flag
const LAMPORTS_MUTABLE_BORROW_BITMASK: u8 = 0b10000000;

/// Bitmask for data mutable borrow flag
const DATA_MUTABLE_BORROW_BITMASK: u8 = 0b00001000;

/// Direct mapping of Solana runtime account memory layout
/// Memory structure: [Account header][data][padding(10KB)][align]
pub const Account = extern struct {
    /// Borrow state (bit-packed)
    /// Bits 7-4: lamport borrows (1 mut flag + 3 count bits)
    /// Bits 3-0: data borrows (1 mut flag + 3 count bits)
    /// Initial: 0xFF (NOT_BORROWED)
    borrow_state: u8,

    /// Indicates whether the transaction was signed by this account
    is_signer: u8,

    /// Indicates whether the account is writable
    is_writable: u8,

    /// Indicates whether this account represents a program
    is_executable: u8,

    /// Original data length (u32 LE) stored in padding for resize validation
    /// When account-resize is not enabled, this is just padding
    _padding: [4]u8,

    /// Public key of the account
    key: Pubkey,

    /// Program that owns this account
    owner: Pubkey,

    /// The lamports in the account
    lamports: u64,

    /// Length of the data
    data_len: u64,

    // Account data follows immediately in memory after this struct
};

/// Zero-copy account view — layout matches Solana C ABI (SolAccountInfo)
/// This allows passing AccountInfo directly to CPI syscalls without conversion.
///
/// C ABI layout (56 bytes):
///   0-7:   key (*const Pubkey)
///   8-15:  lamports (*u64)
///   16-23: data_len (u64)
///   24-31: data ([*]u8)
///   32-39: owner (*const Pubkey)
///   40-47: rent_epoch (u64)
///   48:    is_signer (bool/u8)
///   49:    is_writable (bool/u8)
///   50:    executable (bool/u8)
///   51-55: padding
///
/// Extended fields (after C ABI layout):
///   56:    borrow_state_ptr (*u8) — for borrow checking
///   57:    flags (u8) — packed is_signer/is_writable/executable cache
pub const AccountInfo = extern struct {
    // === C ABI compatible fields (must match SolAccountInfo exactly) ===
    key_ptr: *const Pubkey,
    lamports_ptr: *u64,
    data_len: u64,
    data_ptr: [*]u8,
    owner_ptr: *const Pubkey,
    rent_epoch: u64,
    is_signer: u8,
    is_writable: u8,
    is_executable: u8,
    _abi_padding: [5]u8,

    // === Extended fields (not part of C ABI, used by SDK) ===
    borrow_state_ptr: *u8,
    flags: u8,
    _ext_padding: [6]u8,

    // === Flag bit layout ===
    const FLAG_SIGNER: u8 = 1 << 0;
    const FLAG_WRITABLE: u8 = 1 << 1;
    const FLAG_EXECUTABLE: u8 = 1 << 2;

    /// Create AccountInfo from raw Account pointer
    /// Pre-computes all derived pointers for zero-overhead access
    pub inline fn fromPtr(ptr: *Account) AccountInfo {
        const data_ptr: [*]u8 = @ptrFromInt(@intFromPtr(ptr) + @sizeOf(Account));
        return .{
            .key_ptr = &ptr.key,
            .lamports_ptr = &ptr.lamports,
            .data_len = ptr.data_len,
            .data_ptr = data_ptr,
            .owner_ptr = &ptr.owner,
            .rent_epoch = 0,
            .is_signer = ptr.is_signer,
            .is_writable = ptr.is_writable,
            .is_executable = ptr.is_executable,
            ._abi_padding = .{0} ** 5,
            .borrow_state_ptr = &ptr.borrow_state,
            .flags = makeFlags(ptr.is_signer, ptr.is_writable, ptr.is_executable),
            ._ext_padding = .{0} ** 6,
        };
    }

    /// Pack boolean flags into a single byte
    inline fn makeFlags(is_signer: u8, is_writable: u8, is_exec: u8) u8 {
        var f: u8 = 0;
        if (is_signer != 0) f |= FLAG_SIGNER;
        if (is_writable != 0) f |= FLAG_WRITABLE;
        if (is_exec != 0) f |= FLAG_EXECUTABLE;
        return f;
    }

    // === Inline accessors (forced inline, zero overhead) ===

    /// Get public key
    pub inline fn key(self: AccountInfo) *const Pubkey {
        return self.key_ptr;
    }

    /// Get owner
    pub inline fn owner(self: AccountInfo) *const Pubkey {
        return self.owner_ptr;
    }

    /// Get lamports
    pub inline fn lamports(self: AccountInfo) u64 {
        return self.lamports_ptr.*;
    }

    /// Get data length
    pub inline fn dataLen(self: AccountInfo) usize {
        return @intCast(self.data_len);
    }

    /// Check if signer
    pub inline fn isSigner(self: AccountInfo) bool {
        return self.flags & FLAG_SIGNER != 0;
    }

    /// Check if writable
    pub inline fn isWritable(self: AccountInfo) bool {
        return self.flags & FLAG_WRITABLE != 0;
    }

    /// Check if executable
    pub inline fn executable(self: AccountInfo) bool {
        return self.flags & FLAG_EXECUTABLE != 0;
    }

    // === Data access (zero-copy) ===

    /// Get pointer to account data
    pub inline fn dataPtr(self: AccountInfo) [*]u8 {
        return self.data_ptr;
    }

    /// Get data slice
    pub inline fn data(self: AccountInfo) []u8 {
        return self.data_ptr[0..self.dataLen()];
    }

    // === Unchecked access (highest performance, no borrow checks) ===

    /// Borrow data immutably without checking (unsafe)
    pub inline fn dataUnchecked(self: AccountInfo) []const u8 {
        return self.data_ptr[0..self.dataLen()];
    }

    /// Borrow data mutably without checking (unsafe)
    pub inline fn dataMutUnchecked(self: AccountInfo) []u8 {
        return self.data_ptr[0..self.dataLen()];
    }

    /// Borrow lamports immutably without checking (unsafe)
    pub inline fn lamportsUnchecked(self: AccountInfo) *const u64 {
        return self.lamports_ptr;
    }

    /// Borrow lamports mutably without checking (unsafe)
    pub inline fn lamportsMutUnchecked(self: AccountInfo) *u64 {
        return self.lamports_ptr;
    }

    // === Borrow checking ===

    /// Check if can borrow data immutably
    pub fn canBorrowData(self: AccountInfo) ProgramError!void {
        const borrow_state = self.borrow_state_ptr.*;

        // Check if mutably borrowed
        if (borrow_state & DATA_MUTABLE_BORROW_BITMASK == 0) {
            return ProgramError.AccountBorrowFailed;
        }

        // Check if max immutable borrows reached
        if (borrow_state & 0b00000111 == 0) {
            return ProgramError.AccountBorrowFailed;
        }
    }

    /// Check if can borrow data mutably
    pub fn canBorrowMutData(self: AccountInfo) ProgramError!void {
        const borrow_state = self.borrow_state_ptr.*;

        // Check if any borrow exists
        if (borrow_state & 0b00001111 != 0b00001111) {
            return ProgramError.AccountBorrowFailed;
        }
    }

    /// Check if can borrow lamports immutably
    pub fn canBorrowLamports(self: AccountInfo) ProgramError!void {
        const borrow_state = self.borrow_state_ptr.*;

        // Check if mutably borrowed
        if (borrow_state & LAMPORTS_MUTABLE_BORROW_BITMASK == 0) {
            return ProgramError.AccountBorrowFailed;
        }

        // Check if max immutable borrows reached
        if (borrow_state & 0b01110000 == 0) {
            return ProgramError.AccountBorrowFailed;
        }
    }

    /// Check if can borrow lamports mutably
    pub fn canBorrowMutLamports(self: AccountInfo) ProgramError!void {
        const borrow_state = self.borrow_state_ptr.*;

        // Check if any borrow exists
        if (borrow_state & 0b11110000 != 0b11110000) {
            return ProgramError.AccountBorrowFailed;
        }
    }

    /// Borrow data immutably with RAII guard
    pub fn tryBorrowData(self: AccountInfo) ProgramError!Ref([]const u8) {
        try self.canBorrowData();

        // Decrement immutable borrow count
        self.borrow_state_ptr.* -= 1 << DATA_BORROW_SHIFT;

        return Ref([]const u8){
            .value = self.data_ptr[0..self.dataLen()],
            .state = self.borrow_state_ptr,
            .borrow_shift = DATA_BORROW_SHIFT,
        };
    }

    /// Borrow data mutably with RAII guard
    pub fn tryBorrowMutData(self: AccountInfo) ProgramError!RefMut([]u8) {
        try self.canBorrowMutData();

        // Set mutable borrow bit to 0
        self.borrow_state_ptr.* &= ~DATA_MUTABLE_BORROW_BITMASK;

        return RefMut([]u8){
            .value = self.data_ptr[0..self.dataLen()],
            .state = self.borrow_state_ptr,
            .borrow_bitmask = DATA_MUTABLE_BORROW_BITMASK,
        };
    }

    /// Borrow lamports immutably with RAII guard
    pub fn tryBorrowLamports(self: AccountInfo) ProgramError!Ref(*const u64) {
        try self.canBorrowLamports();

        // Decrement immutable borrow count
        self.borrow_state_ptr.* -= 1 << LAMPORTS_BORROW_SHIFT;

        return Ref(*const u64){
            .value = self.lamports_ptr,
            .state = self.borrow_state_ptr,
            .borrow_shift = LAMPORTS_BORROW_SHIFT,
        };
    }

    /// Borrow lamports mutably with RAII guard
    pub fn tryBorrowMutLamports(self: AccountInfo) ProgramError!RefMut(*u64) {
        try self.canBorrowMutLamports();

        // Set mutable borrow bit to 0
        self.borrow_state_ptr.* &= ~LAMPORTS_MUTABLE_BORROW_BITMASK;

        return RefMut(*u64){
            .value = self.lamports_ptr,
            .state = self.borrow_state_ptr,
            .borrow_bitmask = LAMPORTS_MUTABLE_BORROW_BITMASK,
        };
    }

    /// Assign new owner (unsafe - must ensure no active references)
    pub inline fn assign(self: AccountInfo, new_owner: *const Pubkey) void {
        // Use @memcpy for volatile-like semantics
        @memcpy(@constCast(self.owner_ptr)[0..32], new_owner[0..32]);
    }

    /// Reallocate account data
    pub fn realloc(self: AccountInfo, new_len: u64) ProgramError!void {
        const original_data_len = std.mem.readInt(u32, @ptrCast(self.borrow_state_ptr + 1), .little);
        const diff = @subWithOverflow(new_len, original_data_len);
        if (diff[1] == 0 and diff[0] > MAX_PERMITTED_DATA_INCREASE) {
            return ProgramError.InvalidRealloc;
        }
        self.data_len = new_len;
    }

    /// Check if owned by program
    pub inline fn isOwnedBy(self: AccountInfo, program: *const Pubkey) bool {
        return pubkey.pubkeyEq(self.key(), program);
    }
};

/// RAII guard for immutable borrows
pub fn Ref(comptime T: type) type {
    return struct {
        value: T,
        state: *u8,
        borrow_shift: u3,

        const Self = @This();

        /// Release the borrow
        pub inline fn release(self: *Self) void {
            // Increment borrow count back
            self.state.* += @as(u8, 1) << self.borrow_shift;
        }
    };
}

/// RAII guard for mutable borrows
pub fn RefMut(comptime T: type) type {
    return struct {
        value: T,
        state: *u8,
        borrow_bitmask: u8,

        const Self = @This();

        /// Release the borrow
        pub inline fn release(self: *Self) void {
            // Set mutable borrow bit back to 1
            self.state.* |= self.borrow_bitmask;
        }
    };
}

/// Align pointer to BPF u128 alignment
pub inline fn alignPointer(ptr: usize) usize {
    return (ptr + (BPF_ALIGN_OF_U128 - 1)) & ~(BPF_ALIGN_OF_U128 - 1);
}

// =============================================================================
// Tests
// =============================================================================

test "account: Account size" {
    // Account struct should be 88 bytes (matching Solana runtime)
    try std.testing.expectEqual(@as(usize, 88), @sizeOf(Account));
}

test "account: AccountInfo accessors" {
    var data: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{1} ** 32,
        .owner = .{2} ** 32,
        .lamports = 1000,
        .data_len = 10,
    };
    const account = AccountInfo.fromPtr(&data);

    try std.testing.expect(account.isSigner());
    try std.testing.expect(account.isWritable());
    try std.testing.expect(!account.executable());
    try std.testing.expectEqual(@as(u64, 1000), account.lamports());
    try std.testing.expectEqual(@as(usize, 10), account.dataLen());
    try std.testing.expect(pubkey.pubkeyEq(account.key(), &[_]u8{1} ** 32));
    try std.testing.expect(pubkey.pubkeyEq(account.owner(), &[_]u8{2} ** 32));
}

test "account: borrow data" {
    var runtime_account: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{0} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 10,
    };
    const account = AccountInfo.fromPtr(&runtime_account);

    // Immutable borrow
    var ref = try account.tryBorrowData();
    try std.testing.expectEqual(@as(usize, 10), ref.value.len);
    ref.release();

    // Mutable borrow
    var ref_mut = try account.tryBorrowMutData();
    try std.testing.expectEqual(@as(usize, 10), ref_mut.value.len);
    ref_mut.release();
}

test "account: double mutable borrow fails" {
    var runtime_account: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{0} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 10,
    };
    const account = AccountInfo.fromPtr(&runtime_account);

    var ref = try account.tryBorrowMutData();
    try std.testing.expectError(ProgramError.AccountBorrowFailed, account.tryBorrowMutData());
    ref.release();
}

test "account: dataUnchecked" {
    var buf align(8) = [_]u8{0} ** 200;
    @memcpy(buf[@sizeOf(Account)..][0..5], "hello");

    var runtime_account: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{0} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 5,
    };
    @memcpy(buf[0..@sizeOf(Account)], std.mem.asBytes(&runtime_account));

    const account = AccountInfo.fromPtr(@ptrCast(@alignCast(&buf[0])));
    const data = account.dataUnchecked();
    try std.testing.expectEqualStrings("hello", data[0..5]);
}
