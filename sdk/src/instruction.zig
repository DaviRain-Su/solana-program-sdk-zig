//! Zig implementation of Solana SDK's instruction module (SDK version - no CPI)
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/instruction/src/lib.rs
//!
//! This module provides instruction type definitions for building Solana transactions.
//! Note: This is the SDK version without CPI (Cross-Program Invocation) functionality.
//! For on-chain programs that need CPI, use the program-sdk version.
//!
//! ## Key Types
//! - `Instruction` - A directive for a single invocation of a Solana program
//! - `AccountMeta` - Describes a single account used in an instruction
//! - `CompiledInstruction` - A compiled instruction for transaction building
//! - `InstructionData` - Helper for type-safe instruction data packing
//!
//! ## Example
//! ```zig
//! const instruction = try Instruction.newWithBytes(
//!     allocator,
//!     program_id,
//!     &[_]u8{ 0x01, 0x02, 0x03 },
//!     &[_]AccountMeta{
//!         AccountMeta.newWritableSigner(from_pubkey),
//!         AccountMeta.newWritable(to_pubkey),
//!     },
//! );
//! defer instruction.deinit(allocator);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const PublicKey = @import("public_key.zig").PublicKey;
const borsh = @import("borsh.zig");
const bincode = @import("bincode.zig");

/// Stack height when processing transaction-level instructions
///
/// Rust equivalent: `TRANSACTION_LEVEL_STACK_HEIGHT`
pub const TRANSACTION_LEVEL_STACK_HEIGHT: usize = 1;

/// Maximum size of return data from CPI (1024 bytes)
///
/// Rust equivalent: `solana_cpi::MAX_RETURN_DATA`
pub const MAX_RETURN_DATA: usize = 1024;

/// Describes a single account used in an instruction.
///
/// Rust equivalent: `solana_instruction::AccountMeta`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/instruction/src/account_meta.rs
pub const AccountMeta = struct {
    /// The public key of the account
    pubkey: PublicKey,
    /// True if the instruction requires a transaction signature for this account
    is_signer: bool,
    /// True if the account data or metadata may be mutated during execution
    is_writable: bool,

    /// Construct metadata for a writable account that is also a signer.
    ///
    /// Equivalent to Rust's `AccountMeta::new(pubkey, true)`
    pub fn newWritableSigner(pubkey: PublicKey) AccountMeta {
        return .{
            .pubkey = pubkey,
            .is_signer = true,
            .is_writable = true,
        };
    }

    /// Construct metadata for a writable account that is not a signer.
    ///
    /// Equivalent to Rust's `AccountMeta::new(pubkey, false)`
    pub fn newWritable(pubkey: PublicKey) AccountMeta {
        return .{
            .pubkey = pubkey,
            .is_signer = false,
            .is_writable = true,
        };
    }

    /// Construct metadata for a read-only account that is also a signer.
    ///
    /// Equivalent to Rust's `AccountMeta::new_readonly(pubkey, true)`
    pub fn newReadonlySigner(pubkey: PublicKey) AccountMeta {
        return .{
            .pubkey = pubkey,
            .is_signer = true,
            .is_writable = false,
        };
    }

    /// Construct metadata for a read-only account that is not a signer.
    ///
    /// Equivalent to Rust's `AccountMeta::new_readonly(pubkey, false)`
    pub fn newReadonly(pubkey: PublicKey) AccountMeta {
        return .{
            .pubkey = pubkey,
            .is_signer = false,
            .is_writable = false,
        };
    }

    /// Create AccountMeta with explicit signer and writable flags
    pub fn init(pubkey: PublicKey, is_signer: bool, is_writable: bool) AccountMeta {
        return .{
            .pubkey = pubkey,
            .is_signer = is_signer,
            .is_writable = is_writable,
        };
    }

    // =========================================================================
    // Rust API compatibility accessors
    // =========================================================================

    /// Get the public key (Rust API compatibility)
    /// Rust equivalent: accessing `.pubkey` field
    pub fn getPubkey(self: AccountMeta) PublicKey {
        return self.pubkey;
    }

    /// Check if this account is a signer (Rust API compatibility)
    /// Rust equivalent: accessing `.is_signer` field
    pub fn isSigner(self: AccountMeta) bool {
        return self.is_signer;
    }

    /// Check if this account is writable (Rust API compatibility)
    /// Rust equivalent: accessing `.is_writable` field
    pub fn isWritable(self: AccountMeta) bool {
        return self.is_writable;
    }
};

/// A directive for a single invocation of a Solana program.
///
/// An instruction specifies which program it is calling, which accounts it may
/// read or modify, and additional data that serves as input to the program.
/// One or more instructions are included in transactions submitted by Solana
/// clients. Instructions are also used to describe cross-program invocations.
///
/// Rust equivalent: `solana_instruction::Instruction`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/instruction/src/lib.rs
pub const Instruction = struct {
    /// Pubkey of the program that executes this instruction
    program_id: PublicKey,
    /// Metadata describing accounts that should be passed to the program
    accounts: []const AccountMeta,
    /// Opaque data passed to the program for its own interpretation
    data: []const u8,

    /// Whether this instruction owns its memory (for deinit)
    _owns_accounts: bool = false,
    _owns_data: bool = false,

    const Self = @This();

    /// Create a new instruction from a byte slice.
    ///
    /// This is the most basic constructor. The caller is responsible for
    /// ensuring the correct encoding of `data` as expected by the callee program.
    ///
    /// The instruction takes ownership of the copied data.
    ///
    /// Rust equivalent: `Instruction::new_with_bytes()`
    pub fn newWithBytes(
        allocator: Allocator,
        program_id: PublicKey,
        data: []const u8,
        accounts: []const AccountMeta,
    ) Allocator.Error!Self {
        const owned_data = try allocator.dupe(u8, data);
        errdefer allocator.free(owned_data);

        const owned_accounts = try allocator.dupe(AccountMeta, accounts);

        return .{
            .program_id = program_id,
            .accounts = owned_accounts,
            .data = owned_data,
            ._owns_accounts = true,
            ._owns_data = true,
        };
    }

    /// Create a new instruction from a Borsh-serializable value.
    ///
    /// Borsh serialization is often preferred over bincode as it has a stable
    /// specification and implementations in multiple languages.
    ///
    /// Rust equivalent: `Instruction::new_with_borsh()`
    pub fn newWithBorsh(
        allocator: Allocator,
        program_id: PublicKey,
        comptime T: type,
        data: *const T,
        accounts: []const AccountMeta,
    ) !Self {
        const serialized = try borsh.serializeAlloc(allocator, T, data.*);
        errdefer allocator.free(serialized);

        const owned_accounts = try allocator.dupe(AccountMeta, accounts);

        return .{
            .program_id = program_id,
            .accounts = owned_accounts,
            .data = serialized,
            ._owns_accounts = true,
            ._owns_data = true,
        };
    }

    /// Create a new instruction from a Bincode-serializable value.
    ///
    /// Rust equivalent: `Instruction::new_with_bincode()`
    pub fn newWithBincode(
        allocator: Allocator,
        program_id: PublicKey,
        comptime T: type,
        data: *const T,
        accounts: []const AccountMeta,
    ) !Self {
        const serialized = try bincode.serializeAlloc(allocator, T, data.*);
        errdefer allocator.free(serialized);

        const owned_accounts = try allocator.dupe(AccountMeta, accounts);

        return .{
            .program_id = program_id,
            .accounts = owned_accounts,
            .data = serialized,
            ._owns_accounts = true,
            ._owns_data = true,
        };
    }

    /// Create an instruction without copying data (borrows references).
    ///
    /// The caller must ensure the data and accounts slices outlive the instruction.
    /// This is useful for stack-allocated instructions or when data is already owned.
    pub fn initBorrowed(
        program_id: PublicKey,
        data: []const u8,
        accounts: []const AccountMeta,
    ) Self {
        return .{
            .program_id = program_id,
            .accounts = accounts,
            .data = data,
            ._owns_accounts = false,
            ._owns_data = false,
        };
    }

    /// Free the instruction's owned memory.
    ///
    /// Only call this if the instruction was created with one of the allocating
    /// constructors (newWithBytes, newWithBorsh, newWithBincode).
    pub fn deinit(self: Self, allocator: Allocator) void {
        if (self._owns_data) {
            allocator.free(self.data);
        }
        if (self._owns_accounts) {
            allocator.free(self.accounts);
        }
    }

    // =========================================================================
    // Accessors (Rust API compatibility)
    // =========================================================================

    /// Get the program ID
    pub fn getProgramId(self: Self) PublicKey {
        return self.program_id;
    }

    /// Get the accounts slice
    pub fn getAccounts(self: Self) []const AccountMeta {
        return self.accounts;
    }

    /// Get the data slice
    pub fn getData(self: Self) []const u8 {
        return self.data;
    }
};

/// Information about a processed sibling instruction.
///
/// Used with `sol_get_processed_sibling_instruction` syscall.
///
/// Rust equivalent: `ProcessedSiblingInstruction`
pub const ProcessedSiblingInstruction = extern struct {
    /// Length of the instruction data
    data_len: u64,
    /// Number of accounts
    accounts_len: u64,
};

/// A compiled instruction for transactions (SDK version).
///
/// This is the format used for building transactions off-chain.
/// For on-chain CPI, use the program-sdk's Instruction type.
///
/// Rust equivalent: `solana_instruction::CompiledInstruction`
pub const CompiledInstruction = struct {
    /// Index into the transaction keys array indicating the program account that executes this instruction
    program_id_index: u8,
    /// Ordered indices into the transaction keys array indicating which accounts to pass to the program
    accounts: []const u8,
    /// The program input data
    data: []const u8,
};

/// Return data from a CPI call (type definition only)
pub const ReturnData = struct {
    /// The program that set the return data
    program_id: PublicKey,
    /// The return data itself
    data: []const u8,
};

// ============================================================================
// Instruction Data Helper
// ============================================================================

/// Helper for type-safe instruction data serialization.
///
/// By providing a discriminant and data type, the dynamic type can be
/// constructed in-place and used for instruction data:
///
/// ```zig
/// const Discriminant = enum(u32) { one };
/// const Data = packed struct { field: u64 };
/// const data = InstructionData(Discriminant, Data){
///     .discriminant = Discriminant.one,
///     .data = .{ .field = 1 }
/// };
/// const bytes = data.asBytes();
/// ```
pub fn InstructionData(comptime Discriminant: type, comptime Data: type) type {
    comptime {
        if (@bitSizeOf(Discriminant) % 8 != 0) {
            @panic("Discriminant bit size is not divisible by 8");
        }
        if (@bitSizeOf(Data) % 8 != 0) {
            @panic("Data bit size is not divisible by 8");
        }
    }
    return packed struct {
        discriminant: Discriminant,
        data: Data,
        const Self = @This();
        pub fn asBytes(self: *const Self) []const u8 {
            return std.mem.asBytes(self)[0..((@bitSizeOf(Discriminant) + @bitSizeOf(Data)) / 8)];
        }
    };
}

test "instruction: data transmute" {
    const Discriminant = enum(u32) {
        zero,
        one,
        two,
        three,
    };

    const Data = packed struct {
        a: u8,
        b: u16,
        c: u64,
    };

    const instruction = InstructionData(Discriminant, Data){ .discriminant = Discriminant.three, .data = Data{ .a = 1, .b = 2, .c = 3 } };
    try std.testing.expectEqualSlices(u8, instruction.asBytes(), &[_]u8{ 3, 0, 0, 0, 1, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0 });
}

test "instruction: AccountMeta constructors" {
    const pubkey = PublicKey.from([_]u8{1} ** 32);

    // Writable signer
    {
        const meta = AccountMeta.newWritableSigner(pubkey);
        try std.testing.expectEqual(pubkey, meta.pubkey);
        try std.testing.expect(meta.is_signer);
        try std.testing.expect(meta.is_writable);
    }

    // Writable non-signer
    {
        const meta = AccountMeta.newWritable(pubkey);
        try std.testing.expectEqual(pubkey, meta.pubkey);
        try std.testing.expect(!meta.is_signer);
        try std.testing.expect(meta.is_writable);
    }

    // Readonly signer
    {
        const meta = AccountMeta.newReadonlySigner(pubkey);
        try std.testing.expectEqual(pubkey, meta.pubkey);
        try std.testing.expect(meta.is_signer);
        try std.testing.expect(!meta.is_writable);
    }

    // Readonly non-signer
    {
        const meta = AccountMeta.newReadonly(pubkey);
        try std.testing.expectEqual(pubkey, meta.pubkey);
        try std.testing.expect(!meta.is_signer);
        try std.testing.expect(!meta.is_writable);
    }
}

test "instruction: TRANSACTION_LEVEL_STACK_HEIGHT" {
    try std.testing.expectEqual(@as(usize, 1), TRANSACTION_LEVEL_STACK_HEIGHT);
}

test "instruction: ProcessedSiblingInstruction size" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(ProcessedSiblingInstruction));
}

// ============================================================================
// Instruction Tests
// ============================================================================

test "instruction: Instruction.newWithBytes basic" {
    const allocator = std.testing.allocator;

    const program_id = PublicKey.from([_]u8{1} ** 32);
    const from_pubkey = PublicKey.from([_]u8{2} ** 32);
    const to_pubkey = PublicKey.from([_]u8{3} ** 32);

    const data = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
    const accounts = [_]AccountMeta{
        AccountMeta.newWritableSigner(from_pubkey),
        AccountMeta.newWritable(to_pubkey),
    };

    const instruction = try Instruction.newWithBytes(allocator, program_id, &data, &accounts);
    defer instruction.deinit(allocator);

    // Verify fields
    try std.testing.expect(instruction.program_id.equals(program_id));
    try std.testing.expectEqual(@as(usize, 2), instruction.accounts.len);
    try std.testing.expectEqualSlices(u8, &data, instruction.data);

    // Verify accounts
    try std.testing.expect(instruction.accounts[0].pubkey.equals(from_pubkey));
    try std.testing.expect(instruction.accounts[0].is_signer);
    try std.testing.expect(instruction.accounts[0].is_writable);

    try std.testing.expect(instruction.accounts[1].pubkey.equals(to_pubkey));
    try std.testing.expect(!instruction.accounts[1].is_signer);
    try std.testing.expect(instruction.accounts[1].is_writable);
}

test "instruction: Instruction.newWithBytes empty data" {
    const allocator = std.testing.allocator;

    const program_id = PublicKey.from([_]u8{1} ** 32);
    const accounts = [_]AccountMeta{
        AccountMeta.newReadonly(PublicKey.from([_]u8{2} ** 32)),
    };

    const instruction = try Instruction.newWithBytes(allocator, program_id, &[_]u8{}, &accounts);
    defer instruction.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), instruction.data.len);
    try std.testing.expectEqual(@as(usize, 1), instruction.accounts.len);
}

test "instruction: Instruction.newWithBytes empty accounts" {
    const allocator = std.testing.allocator;

    const program_id = PublicKey.from([_]u8{1} ** 32);
    const data = [_]u8{ 0x01, 0x02 };

    const instruction = try Instruction.newWithBytes(allocator, program_id, &data, &[_]AccountMeta{});
    defer instruction.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), instruction.data.len);
    try std.testing.expectEqual(@as(usize, 0), instruction.accounts.len);
}

test "instruction: Instruction.initBorrowed" {
    const program_id = PublicKey.from([_]u8{1} ** 32);
    const data = [_]u8{ 0x01, 0x02, 0x03 };
    const accounts = [_]AccountMeta{
        AccountMeta.newWritableSigner(PublicKey.from([_]u8{2} ** 32)),
    };

    const instruction = Instruction.initBorrowed(program_id, &data, &accounts);
    // No deinit needed for borrowed instruction

    try std.testing.expect(instruction.program_id.equals(program_id));
    try std.testing.expectEqualSlices(u8, &data, instruction.data);
    try std.testing.expectEqual(@as(usize, 1), instruction.accounts.len);
}

test "instruction: Instruction.newWithBorsh" {
    const allocator = std.testing.allocator;

    const TransferData = struct {
        lamports: u64,
    };

    const program_id = PublicKey.from([_]u8{1} ** 32);
    const from_pubkey = PublicKey.from([_]u8{2} ** 32);
    const to_pubkey = PublicKey.from([_]u8{3} ** 32);

    const transfer_data = TransferData{ .lamports = 1000 };
    const accounts = [_]AccountMeta{
        AccountMeta.newWritableSigner(from_pubkey),
        AccountMeta.newWritable(to_pubkey),
    };

    const instruction = try Instruction.newWithBorsh(
        allocator,
        program_id,
        TransferData,
        &transfer_data,
        &accounts,
    );
    defer instruction.deinit(allocator);

    // Verify fields
    try std.testing.expect(instruction.program_id.equals(program_id));
    try std.testing.expectEqual(@as(usize, 2), instruction.accounts.len);

    // Borsh serializes u64 as 8 little-endian bytes
    try std.testing.expectEqual(@as(usize, 8), instruction.data.len);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xE8, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, instruction.data);
}

test "instruction: Instruction.newWithBincode" {
    const allocator = std.testing.allocator;

    const TransferData = struct {
        lamports: u64,
    };

    const program_id = PublicKey.from([_]u8{1} ** 32);
    const transfer_data = TransferData{ .lamports = 500 };

    const instruction = try Instruction.newWithBincode(
        allocator,
        program_id,
        TransferData,
        &transfer_data,
        &[_]AccountMeta{},
    );
    defer instruction.deinit(allocator);

    // Verify fields
    try std.testing.expect(instruction.program_id.equals(program_id));
    try std.testing.expectEqual(@as(usize, 0), instruction.accounts.len);

    // Bincode serializes u64 as 8 little-endian bytes
    try std.testing.expectEqual(@as(usize, 8), instruction.data.len);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xF4, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, instruction.data);
}

test "instruction: Instruction accessors" {
    const allocator = std.testing.allocator;

    const program_id = PublicKey.from([_]u8{1} ** 32);
    const data = [_]u8{ 0xAB, 0xCD };
    const accounts = [_]AccountMeta{
        AccountMeta.newReadonlySigner(PublicKey.from([_]u8{2} ** 32)),
    };

    const instruction = try Instruction.newWithBytes(allocator, program_id, &data, &accounts);
    defer instruction.deinit(allocator);

    // Test accessors
    try std.testing.expect(instruction.getProgramId().equals(program_id));
    try std.testing.expectEqual(@as(usize, 1), instruction.getAccounts().len);
    try std.testing.expectEqualSlices(u8, &data, instruction.getData());
}

test "instruction: AccountMeta accessors" {
    const pubkey = PublicKey.from([_]u8{42} ** 32);
    const meta = AccountMeta.init(pubkey, true, false);

    // Test accessors
    try std.testing.expect(meta.getPubkey().equals(pubkey));
    try std.testing.expect(meta.isSigner());
    try std.testing.expect(!meta.isWritable());
}
