//! Zig implementation of Solana SDK's entrypoint module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/program-entrypoint/src/lib.rs
//!
//! This module provides the entrypoint macro and types for Solana BPF programs.
//! It defines the ProcessInstruction function signature and ProgramResult type.

const PublicKey = @import("public_key.zig").PublicKey;
const Account = @import("account.zig").Account;
const ProgramError = @import("solana_sdk").ProgramError;
const Context = @import("context.zig").Context;

/// Result type for process instruction functions
///
/// Rust equivalent: `solana_program_entrypoint::ProgramResult`
pub const ProgramResult = union(enum) {
    ok: void,
    err: ProgramError,
};

/// Function signature for process instruction handlers
pub const ProcessInstruction = *const fn (
    program_id: *PublicKey,
    accounts: []Account,
    data: []const u8,
) ProgramResult;

pub fn declareEntrypoint(comptime process_instruction: ProcessInstruction) void {
    const S = struct {
        pub export fn entrypoint(input: [*]u8) callconv(.c) u64 {
            const context = Context.load(input) catch return 1;
            // context.accounts is already a properly-sized slice (heap-allocated in BPF)
            const result = process_instruction(context.program_id, context.accounts, context.data);
            return switch (result) {
                .ok => 0,
                .err => |e| e.toU64(),
            };
        }
    };
    _ = &S.entrypoint;
}

/// Helper macro-like function for simple entrypoint declaration
pub inline fn entrypoint(comptime process_instruction: ProcessInstruction) void {
    declareEntrypoint(process_instruction);
}
