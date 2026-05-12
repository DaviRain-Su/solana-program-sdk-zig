//! On-chain CPI wrappers around the SPL Token program.
//!
//! Thin syntactic sugar over `instruction.zig` + `sol.cpi.invokeRaw`
//! / `sol.cpi.invokeSignedRaw`. The wrappers stage their account
//! metas and instruction bytes on the stack, derive the
//! `Instruction.program_id` from the caller-supplied
//! `token_program: CpiAccountInfo` (so the same wrapper works
//! against classic SPL Token and Token-2022 — caller decides which
//! by passing the right account), and forward to the runtime
//! `sol_invoke_signed_c` syscall.
//!
//! All wrappers expose both an unsigned variant (`transfer`,
//! `mintTo`, …) and a `*Signed` variant for PDA-derived authority
//! signing. Use the `*Signed` form when the `authority` is a PDA
//! owned by *your* program.

const sol = @import("solana_program_sdk");
const instruction = @import("instruction.zig");

const Pubkey = sol.Pubkey;
const CpiAccountInfo = sol.CpiAccountInfo;
const AccountMeta = sol.cpi.AccountMeta;
const Instruction = sol.cpi.Instruction;
const Signer = sol.cpi.Signer;
const ProgramResult = sol.ProgramResult;

/// Make a `cpi.Instruction` carry the caller-supplied program ID
/// instead of the comptime classic-SPL-Token ID — necessary so the
/// same wrappers work against Token-2022.
inline fn rebrand(ix: Instruction, program_id: *const Pubkey) Instruction {
    return .{ .program_id = program_id, .accounts = ix.accounts, .data = ix.data };
}

// =============================================================================
// Transfer
// =============================================================================

pub fn transfer(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
) ProgramResult {
    var metas: [3]AccountMeta = undefined;
    var data: [9]u8 = undefined;
    const ix = rebrand(
        instruction.transfer(source.key(), destination.key(), authority.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ source, destination, authority, token_program });
}

pub fn transferSigned(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    signers: []const Signer,
) ProgramResult {
    var metas: [3]AccountMeta = undefined;
    var data: [9]u8 = undefined;
    const ix = rebrand(
        instruction.transfer(source.key(), destination.key(), authority.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ source, destination, authority, token_program },
        signers,
    );
}

// =============================================================================
// TransferChecked
// =============================================================================

pub fn transferChecked(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    decimals: u8,
) ProgramResult {
    var metas: [4]AccountMeta = undefined;
    var data: [10]u8 = undefined;
    const ix = rebrand(
        instruction.transferChecked(
            source.key(),
            mint.key(),
            destination.key(),
            authority.key(),
            amount,
            decimals,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(
        &ix,
        &[_]CpiAccountInfo{ source, mint, destination, authority, token_program },
    );
}

pub fn transferCheckedSigned(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    decimals: u8,
    signers: []const Signer,
) ProgramResult {
    var metas: [4]AccountMeta = undefined;
    var data: [10]u8 = undefined;
    const ix = rebrand(
        instruction.transferChecked(
            source.key(),
            mint.key(),
            destination.key(),
            authority.key(),
            amount,
            decimals,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ source, mint, destination, authority, token_program },
        signers,
    );
}

// =============================================================================
// MintTo
// =============================================================================

pub fn mintTo(
    token_program: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
) ProgramResult {
    var metas: [3]AccountMeta = undefined;
    var data: [9]u8 = undefined;
    const ix = rebrand(
        instruction.mintTo(mint.key(), destination.key(), authority.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ mint, destination, authority, token_program });
}

pub fn mintToSigned(
    token_program: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    signers: []const Signer,
) ProgramResult {
    var metas: [3]AccountMeta = undefined;
    var data: [9]u8 = undefined;
    const ix = rebrand(
        instruction.mintTo(mint.key(), destination.key(), authority.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ mint, destination, authority, token_program },
        signers,
    );
}

pub fn mintToChecked(
    token_program: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    decimals: u8,
) ProgramResult {
    var metas: [3]AccountMeta = undefined;
    var data: [10]u8 = undefined;
    const ix = rebrand(
        instruction.mintToChecked(
            mint.key(),
            destination.key(),
            authority.key(),
            amount,
            decimals,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ mint, destination, authority, token_program });
}

// =============================================================================
// Burn
// =============================================================================

pub fn burn(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
) ProgramResult {
    var metas: [3]AccountMeta = undefined;
    var data: [9]u8 = undefined;
    const ix = rebrand(
        instruction.burn(source.key(), mint.key(), authority.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ source, mint, authority, token_program });
}

pub fn burnChecked(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    decimals: u8,
) ProgramResult {
    var metas: [3]AccountMeta = undefined;
    var data: [10]u8 = undefined;
    const ix = rebrand(
        instruction.burnChecked(
            source.key(),
            mint.key(),
            authority.key(),
            amount,
            decimals,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ source, mint, authority, token_program });
}

// =============================================================================
// CloseAccount
// =============================================================================

pub fn closeAccount(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
) ProgramResult {
    var metas: [3]AccountMeta = undefined;
    var data: [1]u8 = undefined;
    const ix = rebrand(
        instruction.closeAccount(account.key(), destination.key(), authority.key(), &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ account, destination, authority, token_program });
}

pub fn closeAccountSigned(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    signers: []const Signer,
) ProgramResult {
    var metas: [3]AccountMeta = undefined;
    var data: [1]u8 = undefined;
    const ix = rebrand(
        instruction.closeAccount(account.key(), destination.key(), authority.key(), &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ account, destination, authority, token_program },
        signers,
    );
}

// =============================================================================
// Initialize* — typically used at mint/account creation time.
// =============================================================================

pub fn initializeAccount3(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    mint: CpiAccountInfo,
    owner: *const Pubkey,
) ProgramResult {
    var metas: [2]AccountMeta = undefined;
    var data: [33]u8 = undefined;
    const ix = rebrand(
        instruction.initializeAccount3(account.key(), mint.key(), owner, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ account, mint, token_program });
}

pub fn initializeMint2(
    token_program: CpiAccountInfo,
    mint: CpiAccountInfo,
    decimals: u8,
    mint_authority: *const Pubkey,
    freeze_authority: ?*const Pubkey,
) ProgramResult {
    var metas: [1]AccountMeta = undefined;
    var data: [1 + 1 + 32 + 4 + 32]u8 = undefined;
    const ix = rebrand(
        instruction.initializeMint2(
            mint.key(),
            decimals,
            mint_authority,
            freeze_authority,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ mint, token_program });
}
