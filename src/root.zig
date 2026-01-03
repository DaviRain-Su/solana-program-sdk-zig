//! Solana Program SDK for Zig
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk
//!
//! This is the main entry point for the Solana Program SDK in Zig.
//! It provides a complete implementation of the Solana SDK for writing
//! on-chain programs (smart contracts) in the Zig programming language.
//!
//! ## Modules
//! - `public_key` - PublicKey type and PDA derivation
//! - `account` - Account info and metadata
//! - `instruction` - CPI instruction building
//! - `entrypoint` - Program entrypoint macros
//! - `error` - Program error types
//! - `syscalls` - Solana runtime syscalls
//! - `clock`, `rent`, `slot_hashes` - Sysvar access

const std = @import("std");

pub const public_key = @import("public_key.zig");
pub const account = @import("account.zig");
pub const instruction = @import("instruction.zig");
pub const allocator = @import("allocator.zig");
pub const context = @import("context.zig");
pub const clock = @import("clock.zig");
pub const rent = @import("rent.zig");
pub const log = @import("log.zig");
pub const hash = @import("hash.zig");
pub const signature = @import("signature.zig");
pub const keypair = @import("keypair.zig");
pub const short_vec = @import("short_vec.zig");
pub const borsh = @import("borsh.zig");
pub const bincode = @import("bincode.zig");

pub const blake3 = @import("blake3.zig");
pub const slot_hashes = @import("slot_hashes.zig");

pub const bpf = @import("bpf.zig");
pub const syscalls = @import("syscalls.zig");

const entrypoint_mod = @import("entrypoint.zig");
const error_mod = @import("error.zig");

// Direct exports for convenience
pub const entrypoint = entrypoint_mod.entrypoint;
pub const declareEntrypoint = entrypoint_mod.declareEntrypoint;
pub const ProgramResult = entrypoint_mod.ProgramResult;
pub const ProcessInstruction = entrypoint_mod.ProcessInstruction;
pub const PublicKey = public_key.PublicKey;
pub const Account = account.Account;
pub const ProgramError = error_mod.ProgramError;
pub const print = log.print;
pub const Signature = signature.Signature;
pub const SIGNATURE_BYTES = signature.SIGNATURE_BYTES;
pub const Keypair = keypair.Keypair;
pub const KEYPAIR_LENGTH = keypair.KEYPAIR_LENGTH;
pub const SECRET_KEY_LENGTH = keypair.SECRET_KEY_LENGTH;
pub const ShortU16 = short_vec.ShortU16;
pub const ShortVec = short_vec.ShortVec;

pub const native_loader_id = public_key.PublicKey.comptimeFromBase58("NativeLoader1111111111111111111111111111111");
pub const incinerator_id = public_key.PublicKey.comptimeFromBase58("1nc1nerator11111111111111111111111111111111");

pub const sysvar_id = public_key.PublicKey.comptimeFromBase58("Sysvar1111111111111111111111111111111111111");
pub const instructions_id = public_key.PublicKey.comptimeFromBase58("Sysvar1nstructions1111111111111111111111111");

pub const ed25519_program_id = public_key.PublicKey.comptimeFromBase58("Ed25519SigVerify111111111111111111111111111");
pub const secp256k1_program_id = public_key.PublicKey.comptimeFromBase58("KeccakSecp256k11111111111111111111111111111");

pub const lamports_per_sol = 1_000_000_000;

test {
    std.testing.refAllDecls(@This());
}
