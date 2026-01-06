//! Zig implementation of Solana SDK's instruction module (Program SDK version)
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/instruction/src/lib.rs
//!
//! This module provides the Instruction type for Cross-Program Invocation (CPI).
//! It re-exports pure types from the SDK and adds syscall-based CPI functionality.
//!
//! ## Re-exported from SDK
//! - `AccountMeta` - Describes a single account used in an instruction
//! - `CompiledInstruction` - Compiled instruction for transaction building
//! - `InstructionData` - Helper for type-safe instruction data packing
//! - `ProcessedSiblingInstruction` - Info about processed sibling instructions
//! - `ReturnData` - Return data type definition
//!
//! ## Program SDK Additions
//! - `Instruction` - CPI instruction with invoke/invokeSigned methods
//! - `setReturnData` / `getReturnData` - Syscall-based return data handling
//! - `accountMetaToParam` - Convert AccountMeta to Account.Param for CPI

const std = @import("std");
const sdk = @import("solana_sdk");
const Account = @import("account.zig").Account;
const PublicKey = @import("public_key.zig").PublicKey;
const bpf = @import("bpf.zig");

// ============================================================================
// Re-export SDK types
// ============================================================================

/// Stack height when processing transaction-level instructions
pub const TRANSACTION_LEVEL_STACK_HEIGHT = sdk.instruction.TRANSACTION_LEVEL_STACK_HEIGHT;

/// Maximum size of return data from CPI (1024 bytes)
pub const MAX_RETURN_DATA = sdk.instruction.MAX_RETURN_DATA;

/// Describes a single account used in an instruction.
///
/// Re-exported from SDK. Use `accountMetaToParam` to convert to Account.Param for CPI.
pub const AccountMeta = sdk.instruction.AccountMeta;

/// Information about a processed sibling instruction.
pub const ProcessedSiblingInstruction = sdk.instruction.ProcessedSiblingInstruction;

/// A compiled instruction for transactions (SDK version).
pub const CompiledInstruction = sdk.instruction.CompiledInstruction;

/// Return data type definition.
pub const ReturnData = sdk.instruction.ReturnData;

/// Helper for type-safe instruction data serialization.
pub const InstructionData = sdk.instruction.InstructionData;

// ============================================================================
// Program SDK Additions: CPI Instruction
// ============================================================================

/// Convert AccountMeta to Account.Param for use with CPI Instruction.
///
/// Note: Takes pointer to ensure the returned Param.id points to stable memory.
pub fn accountMetaToParam(meta: *const AccountMeta) Account.Param {
    return .{
        .id = &meta.pubkey,
        .is_writable = meta.is_writable,
        .is_signer = meta.is_signer,
    };
}

/// A Solana instruction for CPI (Cross-Program Invocation)
///
/// This is the on-chain format used for invoking other programs.
/// For off-chain transaction building, use CompiledInstruction from the SDK.
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
// Return Data Syscalls
// ============================================================================

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
// Tests (Program SDK specific tests only, SDK tests are in sdk/src/instruction.zig)
// ============================================================================

test "instruction: accountMetaToParam conversion" {
    const pubkey = PublicKey.from([_]u8{42} ** 32);
    const meta = AccountMeta.init(pubkey, true, true);
    const param = accountMetaToParam(&meta);

    try std.testing.expectEqual(&meta.pubkey, param.id);
    try std.testing.expect(param.is_signer);
    try std.testing.expect(param.is_writable);
}

test "instruction: Instruction.from" {
    const program_id = PublicKey.from([_]u8{1} ** 32);
    const data = [_]u8{ 1, 2, 3, 4 };

    const instr = Instruction.from(.{
        .program_id = &program_id,
        .accounts = &[_]Account.Param{},
        .data = &data,
    });

    try std.testing.expectEqual(&program_id, instr.program_id);
    try std.testing.expectEqual(@as(usize, 0), instr.accounts_len);
    try std.testing.expectEqual(@as(usize, 4), instr.data_len);
}

test "instruction: re-exported constants" {
    try std.testing.expectEqual(@as(usize, 1), TRANSACTION_LEVEL_STACK_HEIGHT);
    try std.testing.expectEqual(@as(usize, 1024), MAX_RETURN_DATA);
}

test "instruction: re-exported ProcessedSiblingInstruction size" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(ProcessedSiblingInstruction));
}
