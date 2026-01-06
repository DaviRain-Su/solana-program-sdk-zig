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
//! - `InstructionData` - Helper for type-safe instruction data packing

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;

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
