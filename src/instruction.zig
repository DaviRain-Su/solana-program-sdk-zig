//! Zig implementation of Solana SDK's instruction module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/instruction/src/lib.rs
//!
//! This module provides the Instruction type for Cross-Program Invocation (CPI).
//! Instructions contain program_id, accounts metadata, and instruction data.
//!
//! ## Key Types
//! - `Instruction` - A directive for a single invocation of a Solana program
//! - `AccountMeta` - Describes a single account used in an instruction
//! - `InstructionData` - Helper for type-safe instruction data packing

const std = @import("std");
const Account = @import("account.zig").Account;
const PublicKey = @import("public_key.zig").PublicKey;
const bpf = @import("bpf.zig");

/// Stack height when processing transaction-level instructions
///
/// Rust equivalent: `TRANSACTION_LEVEL_STACK_HEIGHT`
pub const TRANSACTION_LEVEL_STACK_HEIGHT: usize = 1;

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

    /// Convert to Account.Param for use with Instruction
    /// Note: Takes pointer to ensure the returned Param.id points to stable memory
    pub fn toParam(self: *const AccountMeta) Account.Param {
        return .{
            .id = &self.pubkey,
            .is_writable = self.is_writable,
            .is_signer = self.is_signer,
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

/// A Solana instruction for CPI
///
/// Rust equivalent: `solana_instruction::Instruction`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/instruction/src/lib.rs
pub const Instruction = extern struct {
    program_id: *const PublicKey,
    accounts: [*]const Account.Param,
    accounts_len: usize,
    data: [*]const u8,
    data_len: usize,

    extern fn sol_invoke_signed_c(
        instruction: *const Instruction,
        account_infos: ?[*]const Account.Info,
        account_infos_len: usize,
        signer_seeds: ?[*]const []const []const u8,
        signer_seeds_len: usize,
    ) callconv(.c) u64;

    pub fn from(params: struct {
        program_id: *const PublicKey,
        accounts: []const Account.Param,
        data: []const u8,
    }) Instruction {
        return .{
            .program_id = params.program_id,
            .accounts = params.accounts.ptr,
            .accounts_len = params.accounts.len,
            .data = params.data.ptr,
            .data_len = params.data.len,
        };
    }

    pub fn invoke(self: *const Instruction, accounts: []const Account.Info) !void {
        if (bpf.is_bpf_program) {
            return switch (sol_invoke_signed_c(self, accounts.ptr, accounts.len, null, 0)) {
                0 => {},
                else => error.CrossProgramInvocationFailed,
            };
        }
        return error.CrossProgramInvocationFailed;
    }

    pub fn invokeSigned(self: *const Instruction, accounts: []const Account.Info, signer_seeds: []const []const []const u8) !void {
        if (bpf.is_bpf_program) {
            return switch (sol_invoke_signed_c(self, accounts.ptr, accounts.len, signer_seeds.ptr, signer_seeds.len)) {
                0 => {},
                else => error.CrossProgramInvocationFailed,
            };
        }
        return error.CrossProgramInvocationFailed;
    }
};

// ============================================================================
// Return Data
// ============================================================================

/// Maximum size of return data from CPI (1024 bytes)
///
/// Rust equivalent: `solana_cpi::MAX_RETURN_DATA`
pub const MAX_RETURN_DATA: usize = 1024;

/// Return data from a CPI call
pub const ReturnData = struct {
    /// The program that set the return data
    program_id: PublicKey,
    /// The return data itself
    data: []const u8,
};

/// Set the return data for this program invocation.
///
/// Return data is a way for a called program to return data to its caller.
/// The data is limited to MAX_RETURN_DATA bytes (1024).
///
/// Rust equivalent: `solana_cpi::set_return_data`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/cpi/src/lib.rs
pub fn setReturnData(data: []const u8) void {
    if (bpf.is_bpf_program) {
        const Syscall = struct {
            extern fn sol_set_return_data(data: [*]const u8, len: u64) callconv(.c) void;
        };
        const len = @min(data.len, MAX_RETURN_DATA);
        Syscall.sol_set_return_data(data.ptr, len);
    }
}

/// Get the return data from the last CPI call.
///
/// Returns the program ID that set the data and the data itself.
/// If no return data was set, returns null.
///
/// The caller must provide a buffer to receive the data. The buffer should
/// be at least MAX_RETURN_DATA bytes to ensure all data can be received.
///
/// Rust equivalent: `solana_cpi::get_return_data`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/cpi/src/lib.rs
pub fn getReturnData(buffer: []u8) ?ReturnData {
    if (bpf.is_bpf_program) {
        const Syscall = struct {
            extern fn sol_get_return_data(data: [*]u8, len: u64, program_id: [*]u8) callconv(.c) u64;
        };

        var program_id_bytes: [32]u8 = undefined;
        const size = Syscall.sol_get_return_data(
            buffer.ptr,
            buffer.len,
            &program_id_bytes,
        );

        if (size == 0) return null;

        const actual_size = @min(size, buffer.len);
        return ReturnData{
            .program_id = PublicKey.from(program_id_bytes),
            .data = buffer[0..actual_size],
        };
    }
    return null;
}

/// Get the return data from the last CPI call into a stack-allocated buffer.
///
/// This is a convenience function that uses a stack buffer of MAX_RETURN_DATA size.
/// Returns a copy of the data and program ID if return data was set.
pub fn getReturnDataStatic() ?struct {
    program_id: PublicKey,
    data: [MAX_RETURN_DATA]u8,
    len: usize,
} {
    if (bpf.is_bpf_program) {
        var buffer: [MAX_RETURN_DATA]u8 = undefined;
        if (getReturnData(&buffer)) |result| {
            var data: [MAX_RETURN_DATA]u8 = undefined;
            @memcpy(data[0..result.data.len], result.data);
            return .{
                .program_id = result.program_id,
                .data = data,
                .len = result.data.len,
            };
        }
    }
    return null;
}

// ============================================================================
// Instruction Data Helper
// ============================================================================

/// Helper for no-alloc CPIs. By providing a discriminant and data type, the
/// dynamic type can be constructed in-place and used for instruction data:
///
/// const Discriminant = enum(u32) {
///     one,
/// };
/// const Data = packed struct {
///     field: u64
/// };
/// const data = InstructionData(Discriminant, Data) {
///     .discriminant = Discriminant.one,
///     .data = .{ .field = 1 }
/// };
/// const instruction = Instruction.from(.{
///     .program_id = ...,
///     .accounts = &[_]Account.Param{...},
///     .data = data.asBytes(),
/// });
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

test "instruction: AccountMeta to Param conversion" {
    const pubkey = PublicKey.from([_]u8{42} ** 32);
    const meta = AccountMeta.init(pubkey, true, true);
    const param = meta.toParam();

    try std.testing.expectEqual(&meta.pubkey, param.id);
    try std.testing.expect(param.is_signer);
    try std.testing.expect(param.is_writable);
}

test "instruction: TRANSACTION_LEVEL_STACK_HEIGHT" {
    try std.testing.expectEqual(@as(usize, 1), TRANSACTION_LEVEL_STACK_HEIGHT);
}

test "instruction: ProcessedSiblingInstruction size" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(ProcessedSiblingInstruction));
}
