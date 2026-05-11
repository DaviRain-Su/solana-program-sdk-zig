const std = @import("std");

// Core types
pub const pubkey = @import("pubkey.zig");
pub const account = @import("account.zig");
pub const program_error = @import("program_error.zig");
pub const entrypoint = @import("entrypoint.zig");

// Infrastructure
pub const log = @import("log.zig");
pub const allocator = @import("allocator.zig");
pub const hint = @import("hint.zig");
pub const memory = @import("memory.zig");

// CPI and program wrappers
pub const cpi = @import("cpi.zig");
pub const system = @import("system.zig");
pub const sysvar = @import("sysvar.zig");
pub const pda = @import("pda.zig");

// Existing modules
pub const instruction = @import("instruction.zig");
pub const clock = @import("clock.zig");
pub const rent = @import("rent.zig");
pub const hash = @import("hash.zig");
pub const slot_hashes = @import("slot_hashes.zig");
pub const blake3 = @import("blake3.zig");
pub const bpf = @import("bpf.zig");

// Type aliases for convenience
pub const Pubkey = pubkey.Pubkey;
pub const PUBKEY_BYTES = pubkey.PUBKEY_BYTES;
pub const AccountInfo = account.AccountInfo;
pub const Account = account.Account;
pub const ProgramError = program_error.ProgramError;
pub const ProgramResult = program_error.ProgramResult;
pub const SUCCESS = program_error.SUCCESS;

// Constants
pub const lamports_per_sol = 1_000_000_000;

// Program IDs (using new comptimeFromBase58)
pub const native_loader_id = pubkey.comptimeFromBase58("NativeLoader1111111111111111111111111111111");
pub const incinerator_id = pubkey.comptimeFromBase58("1nc1nerator11111111111111111111111111111111");
pub const sysvar_id = pubkey.comptimeFromBase58("Sysvar1111111111111111111111111111111111111");
pub const instructions_id = pubkey.comptimeFromBase58("Sysvar1nstructions1111111111111111111111111");
pub const ed25519_program_id = pubkey.comptimeFromBase58("Ed25519SigVerify111111111111111111111111111");
pub const secp256k1_program_id = pubkey.comptimeFromBase58("KeccakSecp256k11111111111111111111111111111");

test {
    std.testing.refAllDecls(@This());
}
