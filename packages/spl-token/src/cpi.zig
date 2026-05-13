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
//! signing. The most common 1-PDA case also gets `*SignedSingle`
//! helpers, which route through `sol.cpi.invokeSignedSingle` and skip
//! the raw `Signer` boilerplate at the call site while keeping the
//! low-CU fast path.

const std = @import("std");
const sol = @import("solana_program_sdk");
const instruction = @import("instruction.zig");

const Pubkey = sol.Pubkey;
const CpiAccountInfo = sol.CpiAccountInfo;
const AccountMeta = sol.cpi.AccountMeta;
const Instruction = sol.cpi.Instruction;
const Signer = sol.cpi.Signer;
const ProgramResult = sol.ProgramResult;

// Pull the per-instruction wire-format specs into scope. The
// builders' signatures already enforce that any local scratch
// buffer must match the spec's `accounts_len` / `data_len` — so
// re-typing the array shapes via `metasArray(spec)` /
// `dataArray(spec)` keeps the wrappers honest by construction
// (change the spec, every call site moves with it).
const metasArray = instruction.metasArray;
const dataArray = instruction.dataArray;

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
    var metas: metasArray(instruction.transfer_spec) = undefined;
    var data: dataArray(instruction.transfer_spec) = undefined;
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
    var metas: metasArray(instruction.transfer_spec) = undefined;
    var data: dataArray(instruction.transfer_spec) = undefined;
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

pub inline fn transferSignedSingle(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.transfer_spec) = undefined;
    var data: dataArray(instruction.transfer_spec) = undefined;
    const ix = rebrand(
        instruction.transfer(source.key(), destination.key(), authority.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ source, destination, authority, token_program },
        signer_seeds,
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
    var metas: metasArray(instruction.transfer_checked_spec) = undefined;
    var data: dataArray(instruction.transfer_checked_spec) = undefined;
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
    var metas: metasArray(instruction.transfer_checked_spec) = undefined;
    var data: dataArray(instruction.transfer_checked_spec) = undefined;
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

pub inline fn transferCheckedSignedSingle(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    decimals: u8,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.transfer_checked_spec) = undefined;
    var data: dataArray(instruction.transfer_checked_spec) = undefined;
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
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ source, mint, destination, authority, token_program },
        signer_seeds,
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
    var metas: metasArray(instruction.mint_to_spec) = undefined;
    var data: dataArray(instruction.mint_to_spec) = undefined;
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
    var metas: metasArray(instruction.mint_to_spec) = undefined;
    var data: dataArray(instruction.mint_to_spec) = undefined;
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

pub inline fn mintToSignedSingle(
    token_program: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.mint_to_spec) = undefined;
    var data: dataArray(instruction.mint_to_spec) = undefined;
    const ix = rebrand(
        instruction.mintTo(mint.key(), destination.key(), authority.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ mint, destination, authority, token_program },
        signer_seeds,
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
    var metas: metasArray(instruction.mint_to_checked_spec) = undefined;
    var data: dataArray(instruction.mint_to_checked_spec) = undefined;
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

pub fn mintToCheckedSigned(
    token_program: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    decimals: u8,
    signers: []const Signer,
) ProgramResult {
    var metas: metasArray(instruction.mint_to_checked_spec) = undefined;
    var data: dataArray(instruction.mint_to_checked_spec) = undefined;
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
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ mint, destination, authority, token_program },
        signers,
    );
}

pub inline fn mintToCheckedSignedSingle(
    token_program: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    decimals: u8,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.mint_to_checked_spec) = undefined;
    var data: dataArray(instruction.mint_to_checked_spec) = undefined;
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
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ mint, destination, authority, token_program },
        signer_seeds,
    );
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
    var metas: metasArray(instruction.burn_spec) = undefined;
    var data: dataArray(instruction.burn_spec) = undefined;
    const ix = rebrand(
        instruction.burn(source.key(), mint.key(), authority.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ source, mint, authority, token_program });
}

pub fn burnSigned(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    signers: []const Signer,
) ProgramResult {
    var metas: metasArray(instruction.burn_spec) = undefined;
    var data: dataArray(instruction.burn_spec) = undefined;
    const ix = rebrand(
        instruction.burn(source.key(), mint.key(), authority.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ source, mint, authority, token_program },
        signers,
    );
}

pub inline fn burnSignedSingle(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.burn_spec) = undefined;
    var data: dataArray(instruction.burn_spec) = undefined;
    const ix = rebrand(
        instruction.burn(source.key(), mint.key(), authority.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ source, mint, authority, token_program },
        signer_seeds,
    );
}

pub fn burnChecked(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    decimals: u8,
) ProgramResult {
    var metas: metasArray(instruction.burn_checked_spec) = undefined;
    var data: dataArray(instruction.burn_checked_spec) = undefined;
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

pub fn burnCheckedSigned(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    decimals: u8,
    signers: []const Signer,
) ProgramResult {
    var metas: metasArray(instruction.burn_checked_spec) = undefined;
    var data: dataArray(instruction.burn_checked_spec) = undefined;
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
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ source, mint, authority, token_program },
        signers,
    );
}

pub inline fn burnCheckedSignedSingle(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    authority: CpiAccountInfo,
    amount: u64,
    decimals: u8,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.burn_checked_spec) = undefined;
    var data: dataArray(instruction.burn_checked_spec) = undefined;
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
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ source, mint, authority, token_program },
        signer_seeds,
    );
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
    var metas: metasArray(instruction.close_account_spec) = undefined;
    var data: dataArray(instruction.close_account_spec) = undefined;
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
    var metas: metasArray(instruction.close_account_spec) = undefined;
    var data: dataArray(instruction.close_account_spec) = undefined;
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

pub inline fn closeAccountSignedSingle(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    destination: CpiAccountInfo,
    authority: CpiAccountInfo,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.close_account_spec) = undefined;
    var data: dataArray(instruction.close_account_spec) = undefined;
    const ix = rebrand(
        instruction.closeAccount(account.key(), destination.key(), authority.key(), &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ account, destination, authority, token_program },
        signer_seeds,
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
    var metas: metasArray(instruction.initialize_account3_spec) = undefined;
    var data: dataArray(instruction.initialize_account3_spec) = undefined;
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
    var metas: metasArray(instruction.initialize_mint2_spec) = undefined;
    var data: dataArray(instruction.initialize_mint2_spec) = undefined;
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

fn testCpiInfo(acc: *sol.account.Account) CpiAccountInfo {
    const info = sol.account.AccountInfo{ .raw = acc };
    return info.toCpiInfo();
}

test "spl-token cpi: SignedSingle wrappers compile and use host fallback" {
    var token_program_acc: sol.account.Account = .{
        .borrow_state = sol.account.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 1,
        ._padding = .{0} ** 4,
        .key = sol.spl_token_program_id,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    var source_acc: sol.account.Account = .{
        .borrow_state = sol.account.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{1} ** 32,
        .owner = .{2} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    var mint_acc: sol.account.Account = .{
        .borrow_state = sol.account.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{3} ** 32,
        .owner = .{4} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    var destination_acc: sol.account.Account = .{
        .borrow_state = sol.account.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{5} ** 32,
        .owner = .{6} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    var authority_acc: sol.account.Account = .{
        .borrow_state = sol.account.NOT_BORROWED,
        .is_signer = 1,
        .is_writable = 0,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{7} ** 32,
        .owner = .{8} ** 32,
        .lamports = 0,
        .data_len = 0,
    };

    const token_program = testCpiInfo(&token_program_acc);
    const source = testCpiInfo(&source_acc);
    const mint = testCpiInfo(&mint_acc);
    const destination = testCpiInfo(&destination_acc);
    const authority = testCpiInfo(&authority_acc);
    const bump_seed = [_]u8{255};

    try std.testing.expectError(
        error.InvalidArgument,
        transferSignedSingle(token_program, source, destination, authority, 1, .{ "vault", &bump_seed }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        transferCheckedSignedSingle(token_program, source, mint, destination, authority, 1, 6, .{ "vault", &bump_seed }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        mintToSignedSingle(token_program, mint, destination, authority, 1, .{ "mint", &bump_seed }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        mintToCheckedSignedSingle(token_program, mint, destination, authority, 1, 6, .{ "mint", &bump_seed }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        burnSignedSingle(token_program, source, mint, authority, 1, .{ "burn", &bump_seed }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        burnCheckedSignedSingle(token_program, source, mint, authority, 1, 6, .{ "burn", &bump_seed }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        closeAccountSignedSingle(token_program, source, destination, authority, .{ "close", &bump_seed }),
    );
}

test "spl-token cpi: new signed raw wrappers use host fallback" {
    var token_program_acc: sol.account.Account = .{
        .borrow_state = sol.account.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 1,
        ._padding = .{0} ** 4,
        .key = sol.spl_token_program_id,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    var source_acc: sol.account.Account = .{
        .borrow_state = sol.account.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{9} ** 32,
        .owner = .{10} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    var mint_acc: sol.account.Account = .{
        .borrow_state = sol.account.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{11} ** 32,
        .owner = .{12} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    var destination_acc: sol.account.Account = .{
        .borrow_state = sol.account.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{13} ** 32,
        .owner = .{14} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    var authority_acc: sol.account.Account = .{
        .borrow_state = sol.account.NOT_BORROWED,
        .is_signer = 1,
        .is_writable = 0,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{15} ** 32,
        .owner = .{16} ** 32,
        .lamports = 0,
        .data_len = 0,
    };

    const token_program = testCpiInfo(&token_program_acc);
    const source = testCpiInfo(&source_acc);
    const mint = testCpiInfo(&mint_acc);
    const destination = testCpiInfo(&destination_acc);
    const authority = testCpiInfo(&authority_acc);
    const seeds = [_]sol.cpi.Seed{ .from("vault"), .from(&[_]u8{254}) };
    const signer = sol.cpi.Signer.from(&seeds);

    try std.testing.expectError(
        error.InvalidArgument,
        mintToCheckedSigned(token_program, mint, destination, authority, 1, 6, &.{signer}),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        burnSigned(token_program, source, mint, authority, 1, &.{signer}),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        burnCheckedSigned(token_program, source, mint, authority, 1, 6, &.{signer}),
    );
}
