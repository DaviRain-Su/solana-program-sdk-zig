//! Solana Program SDK for Zig
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk
//!
//! This is the main entry point for the Solana Program SDK in Zig.
//! It provides a complete implementation of the Solana SDK for writing
//! on-chain programs (smart contracts) in the Zig programming language.
//!
//! ## Modules
//! - `public_key` - PublicKey type and PDA derivation (with syscall support)
//! - `account` - Account info and metadata
//! - `instruction` - CPI instruction building (with syscall support)
//! - `entrypoint` - Program entrypoint macros
//! - `error` - Program error types (from SDK)
//! - `syscalls` - Solana runtime syscalls
//! - `clock`, `rent`, `slot_hashes` - Sysvar access

const std = @import("std");

// Import shared SDK types (no syscall dependencies)
const sdk = @import("solana_sdk");

// Program-specific modules (with syscall/BPF support)
pub const public_key = @import("public_key.zig");
pub const account = @import("account.zig");
pub const instruction = @import("instruction.zig");
pub const allocator = @import("allocator.zig");
pub const context = @import("context.zig");
pub const clock = @import("clock.zig");
pub const rent = @import("rent.zig");
pub const log = @import("log.zig");
pub const message = @import("message.zig");
pub const signer = @import("signer.zig");
pub const transaction = @import("transaction.zig");

// Re-export pure modules from SDK
pub const hash = sdk.hash;
pub const signature = sdk.signature;
pub const keypair = sdk.keypair;
pub const short_vec = sdk.short_vec;
pub const borsh = sdk.borsh;
pub const bincode = sdk.bincode;
pub const native_token = sdk.native_token;
pub const nonce = sdk.nonce;
const error_mod = sdk.@"error";

pub const blake3 = @import("blake3.zig");
pub const sha256_hasher = @import("sha256_hasher.zig");
pub const keccak_hasher = @import("keccak_hasher.zig");
pub const slot_hashes = @import("slot_hashes.zig");
pub const slot_history = @import("slot_history.zig");
pub const epoch_schedule = @import("epoch_schedule.zig");

pub const bpf = @import("bpf.zig");
pub const syscalls = @import("syscalls.zig");

// Phase 8: Native Programs
pub const system_program = @import("system_program.zig");
pub const bpf_loader = @import("bpf_loader.zig");
pub const ed25519_program = @import("ed25519_program.zig");
pub const secp256k1_program = @import("secp256k1_program.zig");
pub const compute_budget = @import("compute_budget.zig");

// Phase 9: Native Token (re-exported from SDK)

// Phase 10: v0.19.0 - Memory, Instructions Sysvar, Address Lookup Tables
pub const program_memory = @import("program_memory.zig");
pub const instructions_sysvar = @import("instructions_sysvar.zig");
pub const address_lookup_table = @import("address_lookup_table.zig");

// Phase 11: v0.20.0 - Pack/Unpack & Nonce Support
pub const program_pack = @import("program_pack.zig");
// nonce re-exported from SDK

// Phase 12: v0.21.0 - Remaining Program Foundation
pub const program_option = @import("program_option.zig");
pub const msg = @import("msg.zig");
pub const stable_layout = @import("stable_layout.zig");

// Phase 13: v0.22.0 - Sysvar Completion
pub const last_restart_slot = @import("last_restart_slot.zig");
pub const sysvar = @import("sysvar.zig");
// Note: sysvar_id is already defined below as a constant
pub const epoch_rewards = @import("epoch_rewards.zig");

// Phase 14: v0.23.0 - Advanced Crypto
pub const bn254 = @import("bn254.zig");
pub const big_mod_exp = @import("big_mod_exp.zig");
pub const mcl = @import("mcl.zig");

// Phase 16: v0.25.0 - Epoch Rewards Hasher
pub const epoch_rewards_hasher = @import("epoch_rewards_hasher.zig");

// Phase 17: v0.26.0 - Feature Gate
pub const feature_gate = @import("feature_gate.zig");

// Phase 18: v0.27.0 - Vote Interface
pub const vote_interface = @import("vote_interface.zig");

// Phase 19: v0.28.0 - BLS Signatures
pub const bls_signatures = @import("bls_signatures.zig");

// Phase 15: v0.24.0 - Extended Native Programs
pub const loader_v4 = @import("loader_v4.zig");
pub const secp256r1_program = @import("secp256r1_program.zig");

// Phase 20: v2.0.0 - SPL Programs (re-exported from SDK)
pub const spl = sdk.spl;

// Phase 21: v3.0.0 - Anchor Framework (sol-anchor-zig)

const entrypoint_mod = @import("entrypoint.zig");
// error_mod defined above from SDK

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
pub const instructions_sysvar_id = instructions_sysvar.ID;

pub const ed25519_program_id = public_key.PublicKey.comptimeFromBase58("Ed25519SigVerify111111111111111111111111111");
pub const secp256k1_program_id = public_key.PublicKey.comptimeFromBase58("KeccakSecp256k11111111111111111111111111111");
pub const compute_budget_program_id = compute_budget.ID;
pub const address_lookup_table_program_id = address_lookup_table.ID;

// Native token exports
pub const lamports_per_sol = native_token.LAMPORTS_PER_SOL;
pub const LAMPORTS_PER_SOL = native_token.LAMPORTS_PER_SOL;
pub const Sol = native_token.Sol;
pub const solStrToLamports = native_token.solStrToLamports;

// CPI exports
pub const MAX_RETURN_DATA = instruction.MAX_RETURN_DATA;
pub const setReturnData = instruction.setReturnData;
pub const getReturnData = instruction.getReturnData;

// Memory operations exports
pub const sol_memcpy = program_memory.sol_memcpy;
pub const sol_memmove = program_memory.sol_memmove;
pub const sol_memset = program_memory.sol_memset;
pub const sol_memcmp = program_memory.sol_memcmp;

// Address Lookup Table exports
pub const AddressLookupTable = address_lookup_table.AddressLookupTable;
pub const LookupTableMeta = address_lookup_table.LookupTableMeta;
pub const LOOKUP_TABLE_MAX_ADDRESSES = address_lookup_table.LOOKUP_TABLE_MAX_ADDRESSES;

// Nonce exports
pub const DurableNonce = nonce.DurableNonce;
pub const State = nonce.State;
pub const Data = nonce.Data;
pub const Versions = nonce.Versions;
pub const FeeCalculator = nonce.FeeCalculator;
pub const NONCE_ACCOUNT_LENGTH = nonce.NONCE_ACCOUNT_LENGTH;

// Program Option exports
pub const COption = program_option.COption;

// Msg exports
pub const msg_fn = msg.msg;
pub const format = msg.format;
pub const formatBuf = msg.formatBuf;
pub const formatBufTrunc = msg.formatBufTrunc;

// Stable Layout exports
pub const StableLayout = stable_layout.StableLayout;
pub const ExampleStableAccount = stable_layout.ExampleStableAccount;
pub const ExampleStableConfig = stable_layout.ExampleStableConfig;

// Sysvar exports
pub const LastRestartSlot = last_restart_slot.LastRestartSlot;
pub const EpochRewards = epoch_rewards.EpochRewards;

// Sysvar ID exports (from sysvar_id.zig module)
// Vote Interface exports
pub const vote_program_id = vote_interface.ID;
pub const VoteInit = vote_interface.VoteInit;
pub const VoteError = vote_interface.VoteError;
pub const Lockout = vote_interface.Lockout;

// BLS Signatures exports
pub const BlsError = bls_signatures.BlsError;
pub const BlsPubkey = bls_signatures.Pubkey;
pub const BlsPubkeyCompressed = bls_signatures.PubkeyCompressed;
pub const BlsSignature = bls_signatures.Signature;
pub const BlsSignatureCompressed = bls_signatures.SignatureCompressed;
pub const ProofOfPossession = bls_signatures.ProofOfPossession;
pub const ProofOfPossessionCompressed = bls_signatures.ProofOfPossessionCompressed;
pub const BLS_PUBLIC_KEY_COMPRESSED_SIZE = bls_signatures.BLS_PUBLIC_KEY_COMPRESSED_SIZE;
pub const BLS_PUBLIC_KEY_AFFINE_SIZE = bls_signatures.BLS_PUBLIC_KEY_AFFINE_SIZE;
pub const BLS_SIGNATURE_COMPRESSED_SIZE = bls_signatures.BLS_SIGNATURE_COMPRESSED_SIZE;
pub const BLS_SIGNATURE_AFFINE_SIZE = bls_signatures.BLS_SIGNATURE_AFFINE_SIZE;
pub const POP_DST = bls_signatures.POP_DST;

pub const CLOCK_ID = @import("sysvar_id.zig").CLOCK;
pub const RENT_ID = @import("sysvar_id.zig").RENT;
pub const SLOT_HASHES_ID = @import("sysvar_id.zig").SLOT_HASHES;
pub const SLOT_HISTORY_ID = @import("sysvar_id.zig").SLOT_HISTORY;
pub const STAKE_HISTORY_ID = @import("sysvar_id.zig").STAKE_HISTORY;
pub const INSTRUCTIONS_ID = @import("sysvar_id.zig").INSTRUCTIONS;
pub const EPOCH_REWARDS_ID = @import("sysvar_id.zig").EPOCH_REWARDS;
pub const LAST_RESTART_SLOT_ID = @import("sysvar_id.zig").LAST_RESTART_SLOT;

// Sysvar size constants
pub const CLOCK_SIZE = @import("clock.zig").Clock.SIZE;
pub const RENT_SIZE = @import("rent.zig").Rent.SIZE;
pub const SLOT_HASHES_SIZE = @import("slot_hashes.zig").SlotHashes.SIZE;
pub const SLOT_HISTORY_SIZE = @import("slot_history.zig").SlotHistory.SIZE;
// Instructions sysvar doesn't have a fixed SIZE constant
pub const EPOCH_REWARDS_SIZE = epoch_rewards.EpochRewards.SIZE;
pub const LAST_RESTART_SLOT_SIZE = last_restart_slot.LastRestartSlot.SIZE;

test {
    std.testing.refAllDecls(@This());
}
