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

// Anchor-style foundations (typed accounts, discriminators, error codes)
pub const discriminator = @import("discriminator.zig");
pub const typed_account = @import("typed_account.zig");
pub const error_code = @import("error_code.zig");

// Existing modules
pub const instruction = @import("instruction.zig");
pub const clock = @import("clock.zig");
pub const rent = @import("rent.zig");
pub const hash = @import("hash.zig");
pub const slot_hashes = @import("slot_hashes.zig");
pub const blake3 = @import("blake3.zig");
pub const bpf = @import("bpf.zig");

// Panic handler namespace
/// Usage in your program: `pub const panic = solana_program_sdk.panic.Panic;`
pub const panic = @import("panic.zig");

// Type aliases (Pinocchio naming convention)
pub const Pubkey = pubkey.Pubkey;
pub const PUBKEY_BYTES = pubkey.PUBKEY_BYTES;
pub const Account = account.Account;
pub const AccountInfo = account.AccountInfo;
pub const CpiAccountInfo = account.CpiAccountInfo;
pub const MaybeAccount = account.MaybeAccount;
pub const InstructionContext = entrypoint.InstructionContext;
pub const ProgramError = program_error.ProgramError;
pub const ProgramResult = program_error.ProgramResult;
pub const SUCCESS = program_error.SUCCESS;
pub const customError = program_error.customError;

// Anchor-style aliases — short names for the most common usage.
pub const TypedAccount = typed_account.TypedAccount;
pub const ErrorCode = error_code.ErrorCode;
pub const discriminatorFor = discriminator.forAccount;
pub const eventDiscriminatorFor = discriminator.forEvent;
pub const DISCRIMINATOR_LEN = discriminator.DISCRIMINATOR_LEN;

// Constants
pub const lamports_per_sol = 1_000_000_000;

// Well-known program / sysvar IDs.
//
// ⚠️ These are module-scope `const` `Pubkey` values. On Zig 0.16 BPF
// builds, taking `&foo_id` and passing it to a syscall is unsafe — the
// rodata segment can be placed at low VM addresses that the runtime
// rejects. Use these constants only for comparisons (`pubkeyEq`,
// equality checks). For CPI calls, derive the program ID from a parsed
// `CpiAccountInfo` (e.g. `system_program.key()`) that the caller passed
// in as part of the instruction's accounts.

// Program IDs (comparison-only — see warning above re: rodata addresses)
pub const native_loader_id = pubkey.comptimeFromBase58("NativeLoader1111111111111111111111111111111");
pub const incinerator_id = pubkey.comptimeFromBase58("1nc1nerator11111111111111111111111111111111");
pub const sysvar_id = pubkey.comptimeFromBase58("Sysvar1111111111111111111111111111111111111");
pub const instructions_id = pubkey.comptimeFromBase58("Sysvar1nstructions1111111111111111111111111");
pub const ed25519_program_id = pubkey.comptimeFromBase58("Ed25519SigVerify111111111111111111111111111");
pub const secp256k1_program_id = pubkey.comptimeFromBase58("KeccakSecp256k11111111111111111111111111111");

// BPF Loader variants
pub const bpf_loader_id = pubkey.comptimeFromBase58("BPFLoader1111111111111111111111111111111111");
pub const bpf_loader_deprecated_id = pubkey.comptimeFromBase58("BPFLoader1111111111111111111111111111111111");
pub const bpf_loader_upgradeable_id = pubkey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");

// SPL Token / Token-2022 / Associated Token Account
//
// Use these for owner checks (e.g.
// `mint_account.isOwnedByComptime(sol.spl_token_program_id)`) and for
// constructing CPI instruction-data buffers. For CPI program-id args,
// always derive the address from a parsed `CpiAccountInfo` that was
// passed in by the caller — see the warning above re: rodata.
pub const spl_token_program_id = pubkey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
pub const spl_token_2022_program_id = pubkey.comptimeFromBase58("TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb");
pub const spl_associated_token_account_id = pubkey.comptimeFromBase58("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL");
pub const spl_memo_program_id = pubkey.comptimeFromBase58("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");

// Sysvar IDs
pub const clock_id = sysvar.CLOCK_ID;
pub const rent_id = sysvar.RENT_ID;
pub const epoch_schedule_id = sysvar.EPOCH_SCHEDULE_ID;
pub const slot_hashes_id = sysvar.SLOT_HASHES_ID;
pub const stake_history_id = sysvar.STAKE_HISTORY_ID;
pub const instructions_sysvar_id = sysvar.INSTRUCTIONS_ID;

// System Program — see warning above; for CPI use `system_program.key()`
// from a parsed `CpiAccountInfo`.
pub const system_program_id = system.SYSTEM_PROGRAM_ID;

test {
    std.testing.refAllDecls(@This());
}
