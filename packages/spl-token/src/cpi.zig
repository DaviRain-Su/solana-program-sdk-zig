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
const ProgramError = sol.ProgramError;
const ProgramResult = sol.ProgramResult;
const MAX_SIGNERS = instruction.MAX_SIGNERS;

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

inline fn mapMultisigInstructionError(err: instruction.MultisigInstructionError) ProgramError {
    return switch (err) {
        error.InvalidMultisigSignerCount,
        error.InvalidMultisigThreshold,
        => error.InvalidArgument,
    };
}

inline fn validateSignerInfoCount(signer_infos: []const CpiAccountInfo) ProgramResult {
    if (signer_infos.len < 1 or signer_infos.len > MAX_SIGNERS) {
        return error.InvalidArgument;
    }
}

fn signerPubkeysFromInfos(
    signer_infos: []const CpiAccountInfo,
    out: *[MAX_SIGNERS]Pubkey,
) ProgramError![]const Pubkey {
    if (signer_infos.len < 1 or signer_infos.len > MAX_SIGNERS) {
        return error.InvalidArgument;
    }
    for (signer_infos, 0..) |signer, i| {
        out[i] = signer.key().*;
    }
    return out[0..signer_infos.len];
}

fn runtimeAccountsWithSigners(
    comptime fixed_len: usize,
    fixed_accounts: [fixed_len]CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    token_program: CpiAccountInfo,
    out: *[fixed_len + MAX_SIGNERS + 1]CpiAccountInfo,
) ProgramError![]const CpiAccountInfo {
    try validateSignerInfoCount(signer_infos);

    for (fixed_accounts, 0..) |info, i| {
        out[i] = info;
    }
    for (signer_infos, 0..) |info, i| {
        out[fixed_len + i] = info;
    }
    out[fixed_len + signer_infos.len] = token_program;
    return out[0 .. fixed_len + signer_infos.len + 1];
}

fn multisigPubkeysAndRuntimeAccounts(
    comptime fixed_len: usize,
    fixed_accounts: [fixed_len]CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    token_program: CpiAccountInfo,
    pubkeys_out: *[MAX_SIGNERS]Pubkey,
    accounts_out: *[fixed_len + MAX_SIGNERS + 1]CpiAccountInfo,
) ProgramError!struct {
    signer_pubkeys: []const Pubkey,
    runtime_accounts: []const CpiAccountInfo,
} {
    try validateSignerInfoCount(signer_infos);

    for (fixed_accounts, 0..) |info, i| {
        accounts_out[i] = info;
    }
    for (signer_infos, 0..) |info, i| {
        pubkeys_out[i] = info.key().*;
        accounts_out[fixed_len + i] = info;
    }
    accounts_out[fixed_len + signer_infos.len] = token_program;

    return .{
        .signer_pubkeys = pubkeys_out[0..signer_infos.len],
        .runtime_accounts = accounts_out[0 .. fixed_len + signer_infos.len + 1],
    };
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

pub fn transferMultisig(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    destination: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    amount: u64,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.transfer_spec.accounts_len) = undefined;
    var data: dataArray(instruction.transfer_spec) = undefined;
    const ix = rebrand(
        instruction.transferMultisig(
            source.key(),
            destination.key(),
            multisig_authority.key(),
            signer_pubkeys,
            amount,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.transfer_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.transfer_spec.accounts_len,
        .{ source, destination, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
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

pub fn transferCheckedMultisig(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    amount: u64,
    decimals: u8,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.transfer_checked_spec.accounts_len) = undefined;
    var data: dataArray(instruction.transfer_checked_spec) = undefined;
    const ix = rebrand(
        instruction.transferCheckedMultisig(
            source.key(),
            mint.key(),
            destination.key(),
            multisig_authority.key(),
            signer_pubkeys,
            amount,
            decimals,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.transfer_checked_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.transfer_checked_spec.accounts_len,
        .{ source, mint, destination, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
}

// =============================================================================
// Approve / Revoke / SetAuthority / Freeze / Thaw
// =============================================================================

pub fn approve(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    delegate: CpiAccountInfo,
    owner: CpiAccountInfo,
    amount: u64,
) ProgramResult {
    var metas: metasArray(instruction.approve_spec) = undefined;
    var data: dataArray(instruction.approve_spec) = undefined;
    const ix = rebrand(
        instruction.approve(source.key(), delegate.key(), owner.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ source, delegate, owner, token_program });
}

pub fn approveSigned(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    delegate: CpiAccountInfo,
    owner: CpiAccountInfo,
    amount: u64,
    signers: []const Signer,
) ProgramResult {
    var metas: metasArray(instruction.approve_spec) = undefined;
    var data: dataArray(instruction.approve_spec) = undefined;
    const ix = rebrand(
        instruction.approve(source.key(), delegate.key(), owner.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ source, delegate, owner, token_program },
        signers,
    );
}

pub inline fn approveSignedSingle(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    delegate: CpiAccountInfo,
    owner: CpiAccountInfo,
    amount: u64,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.approve_spec) = undefined;
    var data: dataArray(instruction.approve_spec) = undefined;
    const ix = rebrand(
        instruction.approve(source.key(), delegate.key(), owner.key(), amount, &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ source, delegate, owner, token_program },
        signer_seeds,
    );
}

pub fn approveMultisig(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    delegate: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    amount: u64,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.approve_spec.accounts_len) = undefined;
    var data: dataArray(instruction.approve_spec) = undefined;
    const ix = rebrand(
        instruction.approveMultisig(
            source.key(),
            delegate.key(),
            multisig_authority.key(),
            signer_pubkeys,
            amount,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.approve_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.approve_spec.accounts_len,
        .{ source, delegate, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
}

pub fn approveChecked(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    delegate: CpiAccountInfo,
    owner: CpiAccountInfo,
    amount: u64,
    decimals: u8,
) ProgramResult {
    var metas: metasArray(instruction.approve_checked_spec) = undefined;
    var data: dataArray(instruction.approve_checked_spec) = undefined;
    const ix = rebrand(
        instruction.approveChecked(
            source.key(),
            mint.key(),
            delegate.key(),
            owner.key(),
            amount,
            decimals,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(
        &ix,
        &[_]CpiAccountInfo{ source, mint, delegate, owner, token_program },
    );
}

pub fn approveCheckedSigned(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    delegate: CpiAccountInfo,
    owner: CpiAccountInfo,
    amount: u64,
    decimals: u8,
    signers: []const Signer,
) ProgramResult {
    var metas: metasArray(instruction.approve_checked_spec) = undefined;
    var data: dataArray(instruction.approve_checked_spec) = undefined;
    const ix = rebrand(
        instruction.approveChecked(
            source.key(),
            mint.key(),
            delegate.key(),
            owner.key(),
            amount,
            decimals,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ source, mint, delegate, owner, token_program },
        signers,
    );
}

pub inline fn approveCheckedSignedSingle(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    delegate: CpiAccountInfo,
    owner: CpiAccountInfo,
    amount: u64,
    decimals: u8,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.approve_checked_spec) = undefined;
    var data: dataArray(instruction.approve_checked_spec) = undefined;
    const ix = rebrand(
        instruction.approveChecked(
            source.key(),
            mint.key(),
            delegate.key(),
            owner.key(),
            amount,
            decimals,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ source, mint, delegate, owner, token_program },
        signer_seeds,
    );
}

pub fn approveCheckedMultisig(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    delegate: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    amount: u64,
    decimals: u8,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.approve_checked_spec.accounts_len) = undefined;
    var data: dataArray(instruction.approve_checked_spec) = undefined;
    const ix = rebrand(
        instruction.approveCheckedMultisig(
            source.key(),
            mint.key(),
            delegate.key(),
            multisig_authority.key(),
            signer_pubkeys,
            amount,
            decimals,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.approve_checked_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.approve_checked_spec.accounts_len,
        .{ source, mint, delegate, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
}

pub fn revoke(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    owner: CpiAccountInfo,
) ProgramResult {
    var metas: metasArray(instruction.revoke_spec) = undefined;
    var data: dataArray(instruction.revoke_spec) = undefined;
    const ix = rebrand(
        instruction.revoke(source.key(), owner.key(), &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ source, owner, token_program });
}

pub fn revokeSigned(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    owner: CpiAccountInfo,
    signers: []const Signer,
) ProgramResult {
    var metas: metasArray(instruction.revoke_spec) = undefined;
    var data: dataArray(instruction.revoke_spec) = undefined;
    const ix = rebrand(
        instruction.revoke(source.key(), owner.key(), &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ source, owner, token_program },
        signers,
    );
}

pub inline fn revokeSignedSingle(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    owner: CpiAccountInfo,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.revoke_spec) = undefined;
    var data: dataArray(instruction.revoke_spec) = undefined;
    const ix = rebrand(
        instruction.revoke(source.key(), owner.key(), &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ source, owner, token_program },
        signer_seeds,
    );
}

pub fn revokeMultisig(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.revoke_spec.accounts_len) = undefined;
    var data: dataArray(instruction.revoke_spec) = undefined;
    const ix = rebrand(
        instruction.revokeMultisig(
            source.key(),
            multisig_authority.key(),
            signer_pubkeys,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.revoke_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.revoke_spec.accounts_len,
        .{ source, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
}

pub fn setAuthority(
    token_program: CpiAccountInfo,
    target: CpiAccountInfo,
    current_authority: CpiAccountInfo,
    authority_type: instruction.AuthorityType,
    new_authority: ?*const Pubkey,
) ProgramResult {
    var metas: metasArray(instruction.set_authority_spec) = undefined;
    var data: dataArray(instruction.set_authority_spec) = undefined;
    const ix = rebrand(
        instruction.setAuthority(
            target.key(),
            current_authority.key(),
            authority_type,
            new_authority,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(
        &ix,
        &[_]CpiAccountInfo{ target, current_authority, token_program },
    );
}

pub fn setAuthoritySigned(
    token_program: CpiAccountInfo,
    target: CpiAccountInfo,
    current_authority: CpiAccountInfo,
    authority_type: instruction.AuthorityType,
    new_authority: ?*const Pubkey,
    signers: []const Signer,
) ProgramResult {
    var metas: metasArray(instruction.set_authority_spec) = undefined;
    var data: dataArray(instruction.set_authority_spec) = undefined;
    const ix = rebrand(
        instruction.setAuthority(
            target.key(),
            current_authority.key(),
            authority_type,
            new_authority,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ target, current_authority, token_program },
        signers,
    );
}

pub inline fn setAuthoritySignedSingle(
    token_program: CpiAccountInfo,
    target: CpiAccountInfo,
    current_authority: CpiAccountInfo,
    authority_type: instruction.AuthorityType,
    new_authority: ?*const Pubkey,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.set_authority_spec) = undefined;
    var data: dataArray(instruction.set_authority_spec) = undefined;
    const ix = rebrand(
        instruction.setAuthority(
            target.key(),
            current_authority.key(),
            authority_type,
            new_authority,
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ target, current_authority, token_program },
        signer_seeds,
    );
}

pub fn setAuthorityMultisig(
    token_program: CpiAccountInfo,
    target: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    authority_type: instruction.AuthorityType,
    new_authority: ?*const Pubkey,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.set_authority_spec.accounts_len) = undefined;
    var data: dataArray(instruction.set_authority_spec) = undefined;
    const ix = rebrand(
        instruction.setAuthorityMultisig(
            target.key(),
            multisig_authority.key(),
            signer_pubkeys,
            authority_type,
            new_authority,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.set_authority_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.set_authority_spec.accounts_len,
        .{ target, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
}

pub fn freezeAccount(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    mint: CpiAccountInfo,
    freeze_authority: CpiAccountInfo,
) ProgramResult {
    var metas: metasArray(instruction.freeze_account_spec) = undefined;
    var data: dataArray(instruction.freeze_account_spec) = undefined;
    const ix = rebrand(
        instruction.freezeAccount(
            account.key(),
            mint.key(),
            freeze_authority.key(),
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(
        &ix,
        &[_]CpiAccountInfo{ account, mint, freeze_authority, token_program },
    );
}

pub fn freezeAccountSigned(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    mint: CpiAccountInfo,
    freeze_authority: CpiAccountInfo,
    signers: []const Signer,
) ProgramResult {
    var metas: metasArray(instruction.freeze_account_spec) = undefined;
    var data: dataArray(instruction.freeze_account_spec) = undefined;
    const ix = rebrand(
        instruction.freezeAccount(
            account.key(),
            mint.key(),
            freeze_authority.key(),
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ account, mint, freeze_authority, token_program },
        signers,
    );
}

pub inline fn freezeAccountSignedSingle(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    mint: CpiAccountInfo,
    freeze_authority: CpiAccountInfo,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.freeze_account_spec) = undefined;
    var data: dataArray(instruction.freeze_account_spec) = undefined;
    const ix = rebrand(
        instruction.freezeAccount(
            account.key(),
            mint.key(),
            freeze_authority.key(),
            &metas,
            &data,
        ),
        token_program.key(),
    );
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ account, mint, freeze_authority, token_program },
        signer_seeds,
    );
}

pub fn freezeAccountMultisig(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    mint: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.freeze_account_spec.accounts_len) = undefined;
    var data: dataArray(instruction.freeze_account_spec) = undefined;
    const ix = rebrand(
        instruction.freezeAccountMultisig(
            account.key(),
            mint.key(),
            multisig_authority.key(),
            signer_pubkeys,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.freeze_account_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.freeze_account_spec.accounts_len,
        .{ account, mint, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
}

pub fn thawAccount(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    mint: CpiAccountInfo,
    freeze_authority: CpiAccountInfo,
) ProgramResult {
    var metas: metasArray(instruction.thaw_account_spec) = undefined;
    var data: dataArray(instruction.thaw_account_spec) = undefined;
    const ix = rebrand(
        instruction.thawAccount(account.key(), mint.key(), freeze_authority.key(), &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(
        &ix,
        &[_]CpiAccountInfo{ account, mint, freeze_authority, token_program },
    );
}

pub fn thawAccountSigned(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    mint: CpiAccountInfo,
    freeze_authority: CpiAccountInfo,
    signers: []const Signer,
) ProgramResult {
    var metas: metasArray(instruction.thaw_account_spec) = undefined;
    var data: dataArray(instruction.thaw_account_spec) = undefined;
    const ix = rebrand(
        instruction.thawAccount(account.key(), mint.key(), freeze_authority.key(), &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ account, mint, freeze_authority, token_program },
        signers,
    );
}

pub inline fn thawAccountSignedSingle(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    mint: CpiAccountInfo,
    freeze_authority: CpiAccountInfo,
    signer_seeds: anytype,
) ProgramResult {
    var metas: metasArray(instruction.thaw_account_spec) = undefined;
    var data: dataArray(instruction.thaw_account_spec) = undefined;
    const ix = rebrand(
        instruction.thawAccount(account.key(), mint.key(), freeze_authority.key(), &metas, &data),
        token_program.key(),
    );
    try sol.cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ account, mint, freeze_authority, token_program },
        signer_seeds,
    );
}

pub fn thawAccountMultisig(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    mint: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.thaw_account_spec.accounts_len) = undefined;
    var data: dataArray(instruction.thaw_account_spec) = undefined;
    const ix = rebrand(
        instruction.thawAccountMultisig(
            account.key(),
            mint.key(),
            multisig_authority.key(),
            signer_pubkeys,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.thaw_account_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.thaw_account_spec.accounts_len,
        .{ account, mint, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
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

pub fn mintToMultisig(
    token_program: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    amount: u64,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    var accounts: [instruction.mint_to_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const staged = try multisigPubkeysAndRuntimeAccounts(
        instruction.mint_to_spec.accounts_len,
        .{ mint, destination, multisig_authority },
        signer_infos,
        token_program,
        &signer_pubkeys_buf,
        &accounts,
    );
    var metas: instruction.multisigMetasArray(instruction.mint_to_spec.accounts_len) = undefined;
    var data: dataArray(instruction.mint_to_spec) = undefined;
    const ix = rebrand(
        instruction.mintToMultisig(
            mint.key(),
            destination.key(),
            multisig_authority.key(),
            staged.signer_pubkeys,
            amount,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, staged.runtime_accounts);
}

pub fn mintToCheckedMultisig(
    token_program: CpiAccountInfo,
    mint: CpiAccountInfo,
    destination: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    amount: u64,
    decimals: u8,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    var accounts: [instruction.mint_to_checked_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const staged = try multisigPubkeysAndRuntimeAccounts(
        instruction.mint_to_checked_spec.accounts_len,
        .{ mint, destination, multisig_authority },
        signer_infos,
        token_program,
        &signer_pubkeys_buf,
        &accounts,
    );
    var metas: instruction.multisigMetasArray(instruction.mint_to_checked_spec.accounts_len) = undefined;
    var data: dataArray(instruction.mint_to_checked_spec) = undefined;
    const ix = rebrand(
        instruction.mintToCheckedMultisig(
            mint.key(),
            destination.key(),
            multisig_authority.key(),
            staged.signer_pubkeys,
            amount,
            decimals,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    try sol.cpi.invokeRaw(&ix, staged.runtime_accounts);
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

pub fn burnMultisig(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    amount: u64,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.burn_spec.accounts_len) = undefined;
    var data: dataArray(instruction.burn_spec) = undefined;
    const ix = rebrand(
        instruction.burnMultisig(
            source.key(),
            mint.key(),
            multisig_authority.key(),
            signer_pubkeys,
            amount,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.burn_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.burn_spec.accounts_len,
        .{ source, mint, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
}

pub fn burnCheckedMultisig(
    token_program: CpiAccountInfo,
    source: CpiAccountInfo,
    mint: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    amount: u64,
    decimals: u8,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.burn_checked_spec.accounts_len) = undefined;
    var data: dataArray(instruction.burn_checked_spec) = undefined;
    const ix = rebrand(
        instruction.burnCheckedMultisig(
            source.key(),
            mint.key(),
            multisig_authority.key(),
            signer_pubkeys,
            amount,
            decimals,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.burn_checked_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.burn_checked_spec.accounts_len,
        .{ source, mint, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
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

pub fn closeAccountMultisig(
    token_program: CpiAccountInfo,
    account: CpiAccountInfo,
    destination: CpiAccountInfo,
    multisig_authority: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.close_account_spec.accounts_len) = undefined;
    var data: dataArray(instruction.close_account_spec) = undefined;
    const ix = rebrand(
        instruction.closeAccountMultisig(
            account.key(),
            destination.key(),
            multisig_authority.key(),
            signer_pubkeys,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.close_account_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.close_account_spec.accounts_len,
        .{ account, destination, multisig_authority },
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
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

pub fn initializeMultisig2(
    token_program: CpiAccountInfo,
    multisig: CpiAccountInfo,
    signer_infos: []const CpiAccountInfo,
    threshold: u8,
) ProgramResult {
    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(signer_infos, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.initialize_multisig2_spec.accounts_len) = undefined;
    var data: dataArray(instruction.initialize_multisig2_spec) = undefined;
    const ix = rebrand(
        instruction.initializeMultisig2(
            multisig.key(),
            signer_pubkeys,
            threshold,
            &metas,
            &data,
        ) catch |err| return mapMultisigInstructionError(err),
        token_program.key(),
    );
    var accounts: [instruction.initialize_multisig2_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.initialize_multisig2_spec.accounts_len,
        .{multisig},
        signer_infos,
        token_program,
        &accounts,
    );
    try sol.cpi.invokeRaw(&ix, runtime_accounts);
}

const TestAccount = extern struct {
    raw: sol.account.Account,
    data: [8]u8 = .{0} ** 8,
};

fn testAccount(
    key: Pubkey,
    owner: Pubkey,
    signer: bool,
    writable: bool,
    executable: bool,
) TestAccount {
    return .{
        .raw = .{
            .borrow_state = sol.account.NOT_BORROWED,
            .is_signer = @intFromBool(signer),
            .is_writable = @intFromBool(writable),
            .is_executable = @intFromBool(executable),
            ._padding = .{0} ** 4,
            .key = key,
            .owner = owner,
            .lamports = 0,
            .data_len = 8,
        },
    };
}

fn testCpiInfo(acc: *sol.account.Account) CpiAccountInfo {
    const info = sol.account.AccountInfo{ .raw = acc };
    return info.toCpiInfo();
}

test "spl-token cpi: public v0.2 wrapper decls exist" {
    inline for ([_][]const u8{
        "approve",
        "approveSigned",
        "approveSignedSingle",
        "approveMultisig",
        "approveChecked",
        "approveCheckedSigned",
        "approveCheckedSignedSingle",
        "approveCheckedMultisig",
        "revoke",
        "revokeSigned",
        "revokeSignedSingle",
        "revokeMultisig",
        "setAuthority",
        "setAuthoritySigned",
        "setAuthoritySignedSingle",
        "setAuthorityMultisig",
        "freezeAccount",
        "freezeAccountSigned",
        "freezeAccountSignedSingle",
        "freezeAccountMultisig",
        "thawAccount",
        "thawAccountSigned",
        "thawAccountSignedSingle",
        "thawAccountMultisig",
        "initializeMultisig2",
        "transferMultisig",
        "transferCheckedMultisig",
        "mintToMultisig",
        "mintToCheckedMultisig",
        "burnMultisig",
        "burnCheckedMultisig",
        "closeAccountMultisig",
    }) |name| {
        try std.testing.expect(@hasDecl(@This(), name));
    }
}

test "spl-token cpi: multisig runtime accounts keep caller order and token program last" {
    var source_account = testAccount(.{0x21} ** 32, .{0x81} ** 32, false, true, false);
    var delegate_account = testAccount(.{0x22} ** 32, .{0x82} ** 32, false, false, false);
    var multisig_account = testAccount(.{0x23} ** 32, .{0x83} ** 32, false, false, false);
    var signer_a_account = testAccount(.{0x24} ** 32, .{0x84} ** 32, true, false, false);
    var signer_b_account = testAccount(.{0x25} ** 32, .{0x85} ** 32, true, false, false);
    var token_program_account = testAccount(.{0x26} ** 32, .{0x86} ** 32, false, false, true);

    const source = testCpiInfo(&source_account.raw);
    const delegate = testCpiInfo(&delegate_account.raw);
    const multisig = testCpiInfo(&multisig_account.raw);
    const signer_a = testCpiInfo(&signer_a_account.raw);
    const signer_b = testCpiInfo(&signer_b_account.raw);
    const token_program = testCpiInfo(&token_program_account.raw);

    var infos: [instruction.approve_spec.accounts_len + MAX_SIGNERS + 1]CpiAccountInfo = undefined;
    const runtime_accounts = try runtimeAccountsWithSigners(
        instruction.approve_spec.accounts_len,
        .{ source, delegate, multisig },
        &.{ signer_a, signer_b },
        token_program,
        &infos,
    );

    try std.testing.expectEqual(@as(usize, 6), runtime_accounts.len);
    try std.testing.expectEqualSlices(u8, source.key(), runtime_accounts[0].key());
    try std.testing.expectEqualSlices(u8, delegate.key(), runtime_accounts[1].key());
    try std.testing.expectEqualSlices(u8, multisig.key(), runtime_accounts[2].key());
    try std.testing.expectEqualSlices(u8, signer_a.key(), runtime_accounts[3].key());
    try std.testing.expectEqualSlices(u8, signer_b.key(), runtime_accounts[4].key());
    try std.testing.expectEqualSlices(u8, token_program.key(), runtime_accounts[5].key());
}

test "spl-token cpi: initializeMultisig2 rebrands callee and preserves signer order" {
    var multisig_account = testAccount(.{0x31} ** 32, .{0x91} ** 32, false, true, false);
    var signer_a_account = testAccount(.{0x32} ** 32, .{0x92} ** 32, false, false, false);
    var signer_b_account = testAccount(.{0x33} ** 32, .{0x93} ** 32, false, false, false);
    var token_program_account = testAccount(sol.spl_token_2022_program_id, .{0x94} ** 32, false, false, true);

    const multisig = testCpiInfo(&multisig_account.raw);
    const signer_a = testCpiInfo(&signer_a_account.raw);
    const signer_b = testCpiInfo(&signer_b_account.raw);
    const token_program = testCpiInfo(&token_program_account.raw);

    var signer_pubkeys_buf: [MAX_SIGNERS]Pubkey = undefined;
    const signer_pubkeys = try signerPubkeysFromInfos(&.{ signer_a, signer_b }, &signer_pubkeys_buf);
    var metas: instruction.multisigMetasArray(instruction.initialize_multisig2_spec.accounts_len) = undefined;
    var data: dataArray(instruction.initialize_multisig2_spec) = undefined;
    const ix = rebrand(
        try instruction.initializeMultisig2(multisig.key(), signer_pubkeys, 2, &metas, &data),
        token_program.key(),
    );

    try std.testing.expectEqual(token_program.key(), ix.program_id);
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expectEqual(@as(usize, 2), ix.data.len);
    try std.testing.expectEqual(@as(u8, @intFromEnum(instruction.TokenInstruction.initialize_multisig2)), ix.data[0]);
    try std.testing.expectEqual(@as(u8, 2), ix.data[1]);
    try std.testing.expectEqualSlices(u8, multisig.key(), ix.accounts[0].pubkey);
    try std.testing.expectEqualSlices(u8, signer_a.key(), ix.accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, signer_b.key(), ix.accounts[2].pubkey);
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
        approveSignedSingle(token_program, source, destination, authority, 1, .{ "approve", &bump_seed }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        approveCheckedSignedSingle(token_program, source, mint, destination, authority, 1, 6, .{ "approve_checked", &bump_seed }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        revokeSignedSingle(token_program, source, authority, .{ "revoke", &bump_seed }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        setAuthoritySignedSingle(
            token_program,
            source,
            authority,
            .AccountOwner,
            destination.key(),
            .{ "set_authority", &bump_seed },
        ),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        freezeAccountSignedSingle(token_program, source, mint, authority, .{ "freeze", &bump_seed }),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        thawAccountSignedSingle(token_program, source, mint, authority, .{ "thaw", &bump_seed }),
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
        approveSigned(token_program, source, destination, authority, 1, &.{signer}),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        approveCheckedSigned(token_program, source, mint, destination, authority, 1, 6, &.{signer}),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        revokeSigned(token_program, source, authority, &.{signer}),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        setAuthoritySigned(token_program, source, authority, .CloseAccount, null, &.{signer}),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        freezeAccountSigned(token_program, source, mint, authority, &.{signer}),
    );
    try std.testing.expectError(
        error.InvalidArgument,
        thawAccountSigned(token_program, source, mint, authority, &.{signer}),
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
