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
    executable: u8,

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

/// Zero-copy account view — directly points to runtime buffer
pub const AccountInfo = struct {
    /// Pointer to raw account data
    ptr: *Account,

    // === Inline accessors (forced inline, zero overhead) ===

    /// Get public key
    pub inline fn key(self: AccountInfo) *const Pubkey {
        return &self.ptr.key;
    }

    /// Get owner
    pub inline fn owner(self: AccountInfo) *const Pubkey {
        return &self.ptr.owner;
    }

    /// Get lamports
    pub inline fn lamports(self: AccountInfo) u64 {
        return self.ptr.lamports;
    }

    /// Get data length
    pub inline fn dataLen(self: AccountInfo) usize {
        return @intCast(self.ptr.data_len);
    }

    /// Check if signer
    pub inline fn isSigner(self: AccountInfo) bool {
        return self.ptr.is_signer != 0;
    }

    /// Check if writable
    pub inline fn isWritable(self: AccountInfo) bool {
        return self.ptr.is_writable != 0;
    }

    /// Check if executable
    pub inline fn executable(self: AccountInfo) bool {
        return self.ptr.executable != 0;
    }

    // === Data access (zero-copy) ===

    /// Get pointer to account data
    pub inline fn dataPtr(self: AccountInfo) [*]u8 {
        const ptr = @intFromPtr(self.ptr);
        return @ptrFromInt(ptr + @sizeOf(Account));
    }

    /// Get data slice
    pub inline fn data(self: AccountInfo) []u8 {
        return self.dataPtr()[0..self.dataLen()];
    }

    // === Unchecked access (highest performance, no borrow checks) ===

    /// Borrow data immutably without checking (unsafe)
    pub inline fn dataUnchecked(self: AccountInfo) []const u8 {
        return self.dataPtr()[0..self.dataLen()];
    }

    /// Borrow data mutably without checking (unsafe)
    pub inline fn dataMutUnchecked(self: AccountInfo) []u8 {
        return self.dataPtr()[0..self.dataLen()];
    }

    /// Borrow lamports immutably without checking (unsafe)
    pub inline fn lamportsUnchecked(self: AccountInfo) *const u64 {
        return &self.ptr.lamports;
    }

    /// Borrow lamports mutably without checking (unsafe)
    pub inline fn lamportsMutUnchecked(self: AccountInfo) *u64 {
        return &self.ptr.lamports;
    }

    // === Borrow checking ===

    /// Check if can borrow data immutably
    pub fn canBorrowData(self: AccountInfo) ProgramError!void {
        const borrow_state = self.ptr.borrow_state;

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
        const borrow_state = self.ptr.borrow_state;

        // Check if any borrow exists
        if (borrow_state & 0b00001111 != 0b00001111) {
            return ProgramError.AccountBorrowFailed;
        }
    }

    /// Check if can borrow lamports immutably
    pub fn canBorrowLamports(self: AccountInfo) ProgramError!void {
        const borrow_state = self.ptr.borrow_state;

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
        const borrow_state = self.ptr.borrow_state;

        // Check if any borrow exists
        if (borrow_state & 0b11110000 != 0b11110000) {
            return ProgramError.AccountBorrowFailed;
        }
    }

    /// Borrow data immutably with RAII guard
    pub fn tryBorrowData(self: AccountInfo) ProgramError!Ref([]const u8) {
        try self.canBorrowData();

        const borrow_state_ptr = @as(*u8, @ptrCast(&self.ptr.borrow_state));
        // Decrement immutable borrow count
        borrow_state_ptr.* -= 1 << DATA_BORROW_SHIFT;

        return Ref([]const u8){
            .value = self.dataPtr()[0..self.dataLen()],
            .state = borrow_state_ptr,
            .borrow_shift = DATA_BORROW_SHIFT,
        };
    }

    /// Borrow data mutably with RAII guard
    pub fn tryBorrowMutData(self: AccountInfo) ProgramError!RefMut([]u8) {
        try self.canBorrowMutData();

        const borrow_state_ptr = @as(*u8, @ptrCast(&self.ptr.borrow_state));
        // Set mutable borrow bit to 0
        borrow_state_ptr.* &= ~DATA_MUTABLE_BORROW_BITMASK;

        return RefMut([]u8){
            .value = self.dataPtr()[0..self.dataLen()],
            .state = borrow_state_ptr,
            .borrow_bitmask = DATA_MUTABLE_BORROW_BITMASK,
        };
    }

    /// Borrow lamports immutably with RAII guard
    pub fn tryBorrowLamports(self: AccountInfo) ProgramError!Ref(*const u64) {
        try self.canBorrowLamports();

        const borrow_state_ptr = @as(*u8, @ptrCast(&self.ptr.borrow_state));
        // Decrement immutable borrow count
        borrow_state_ptr.* -= 1 << LAMPORTS_BORROW_SHIFT;

        return Ref(*const u64){
            .value = &self.ptr.lamports,
            .state = borrow_state_ptr,
            .borrow_shift = LAMPORTS_BORROW_SHIFT,
        };
    }

    /// Borrow lamports mutably with RAII guard
    pub fn tryBorrowMutLamports(self: AccountInfo) ProgramError!RefMut(*u64) {
        try self.canBorrowMutLamports();

        const borrow_state_ptr = @as(*u8, @ptrCast(&self.ptr.borrow_state));
        // Set mutable borrow bit to 0
        borrow_state_ptr.* &= ~LAMPORTS_MUTABLE_BORROW_BITMASK;

        return RefMut(*u64){
            .value = &self.ptr.lamports,
            .state = borrow_state_ptr,
            .borrow_bitmask = LAMPORTS_MUTABLE_BORROW_BITMASK,
        };
    }

    /// Assign new owner (unsafe - must ensure no active references)
    pub inline fn assign(self: AccountInfo, new_owner: *const Pubkey) void {
        self.ptr.owner = new_owner.*;
    }

    /// Reallocate account data
    pub fn realloc(self: AccountInfo, new_len: u64) ProgramError!void {
        const original_data_len = std.mem.readInt(u32, &self.ptr._padding, .little);
        const diff = @subWithOverflow(new_len, original_data_len);
        if (diff[1] == 0 and diff[0] > MAX_PERMITTED_DATA_INCREASE) {
            return ProgramError.InvalidRealloc;
        }
        self.ptr.data_len = new_len;
    }

    /// Check if owned by program
    pub inline fn isOwnedBy(self: AccountInfo, program: *const Pubkey) bool {
        return pubkey.pubkeyEq(self.owner(), program);
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
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = .{1} ** 32,
        .owner = .{2} ** 32,
        .lamports = 1000,
        .data_len = 10,
    };
    const account = AccountInfo{ .ptr = &data };

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
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = .{0} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 10,
    };
    const account = AccountInfo{ .ptr = &runtime_account };

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
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = .{0} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 10,
    };
    const account = AccountInfo{ .ptr = &runtime_account };

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
        .executable = 0,
        ._padding = .{0} ** 4,
        .key = .{0} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 5,
    };
    @memcpy(buf[0..@sizeOf(Account)], std.mem.asBytes(&runtime_account));

    const account = AccountInfo{ .ptr = @ptrCast(@alignCast(&buf[0])) };
    const data = account.dataUnchecked();
    try std.testing.expectEqualStrings("hello", data[0..5]);
}
