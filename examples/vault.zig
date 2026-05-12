//! End-to-end demo of the SDK's "Anchor-style foundations" without a framework.
//!
//! Demonstrates:
//!   - `parseAccountsWith` with comptime signer / writable / owner checks
//!   - `TypedAccount(VaultState)` zero-copy typed account access
//!   - `discriminator.forAccount("Vault")` type-confusion defence
//!   - `ErrorCode(VaultError)` custom error codes
//!   - `system.createRentExempt` + PDA signing
//!   - `pda.verifyPda` to assert a passed-in PDA matches stored seeds + bump
//!   - `vault.requireHasOne("authority", a.authority)` (`has_one` constraint)
//!   - `sol.emit(DepositEvent{...})` structured event logging
//!
//! Three instructions, dispatched on a `u8` tag at byte 0 of the
//! instruction data:
//!   0 = Initialize     accounts: payer (sig+w), vault PDA (w), system_program
//!   1 = Deposit        accounts: payer (sig+w), vault PDA (w), system_program;
//!                      data: u64 amount
//!   2 = Withdraw       accounts: authority (sig), vault PDA (w), recipient (w);
//!                      data: u64 amount
//!
//! The vault PDA is derived from `[b"vault", authority.key().as_ref()]`
//! at runtime for create/dispatch purposes; `parseAccountsWith` enforces
//! the program-id ownership check on the vault for ix 1 / 2, and
//! `verifyPda` / `requireHasOne` enforce the relational constraints in
//! the withdraw path.

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// =========================================================================
// Program identity (placeholder ID — replace with your deployed program ID)
// =========================================================================

const PROGRAM_ID = sol.pubkey.comptimeFromBase58("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");

// =========================================================================
// State
// =========================================================================

const VaultState = extern struct {
    discriminator: [sol.DISCRIMINATOR_LEN]u8,
    authority: sol.Pubkey,
    balance: u64,
    bump: u8,
    _pad: [7]u8 = .{0} ** 7,

    pub const DISCRIMINATOR = sol.discriminatorFor("Vault");
};

// =========================================================================
// Events (emitted via sol_log_data)
// =========================================================================

// Events stay small on purpose. The off-chain indexer can recover
// the involved pubkeys from the transaction's account list, so
// duplicating them in the event payload is pure CU waste (each
// 32-byte field costs ~32 CU on `sol_log_data` byte-fee alone, plus
// memcpy/setup overhead).
const DepositEvent = extern struct {
    amount: u64,
    new_balance: u64,

    pub const DISCRIMINATOR = sol.eventDiscriminatorFor("Deposit");
};

const WithdrawEvent = extern struct {
    amount: u64,
    new_balance: u64,

    pub const DISCRIMINATOR = sol.eventDiscriminatorFor("Withdraw");
};

// =========================================================================
// Custom error codes (Anchor's #[error_code])
// =========================================================================

const VaultErr = sol.ErrorCode(enum(u32) {
    Unauthorized = 6000,
    InsufficientVaultBalance = 6001,
    AmountOverflow = 6002,
});

// =========================================================================
// Instruction tags
// =========================================================================

const Ix = enum(u8) {
    initialize = 0,
    deposit = 1,
    withdraw = 2,
};

// =========================================================================
// Entrypoint
// =========================================================================

/// Dispatch pattern for `lazyEntrypoint`-style programs:
///
///   1. Parse all accounts first (with whatever shape your ixes share).
///      Here every vault ix takes 3 accounts; the third differs in
///      semantics (system_program vs recipient) but for dispatch we
///      treat them uniformly.
///   2. Read the ix data — `instructionData()` is now safe because
///      `remaining == 0` after parsing.
///   3. Dispatch on the first byte; each handler re-applies the
///      per-ix expectations (signer/writable/owner/has_one) on the
///      already-parsed accounts.
///
/// This is the "parse-then-dispatch" pattern Pinocchio programs use.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    // `parseAccountsUnchecked` skips the dup-aware tagged-union switch
    // — vault's three accounts have structurally distinct roles
    // (authority / vault PDA / system_program or recipient), so duplicates
    // are nonsensical and would fail downstream checks anyway. Saves
    // ~70 CU per call vs the safe `parseAccounts`.
    const a = try ctx.parseAccountsUnchecked(.{ "first", "second", "third" });
    const data = try ctx.instructionData();
    if (data.len < 1) return error.InvalidInstructionData;

    const tag: Ix = @enumFromInt(data[0]);
    if (tag == .initialize) return processInitialize(a.first, a.second, a.third, data);
    if (tag == .deposit) return processDeposit(a.first, a.second, a.third, data);
    if (tag == .withdraw) return processWithdraw(a.first, a.second, a.third, data);
    return error.InvalidInstructionData;
}

const AccountInfo = sol.AccountInfo;

// -------------------------------------------------------------------------
// initialize: create the vault PDA, write the discriminator + state
// -------------------------------------------------------------------------

fn processInitialize(
    authority: AccountInfo,
    vault: AccountInfo,
    system_program: AccountInfo,
    data: []const u8,
) sol.ProgramResult {
    // Per-ix expectations.
    try authority.expectSigner();
    try authority.expectWritable();
    try vault.expectWritable();

    // ix-data layout: [tag:1][bump:1]. The client passes the canonical
    // bump (found off-chain via `find_program_address`) so we only need
    // ONE `create_program_address` syscall (~1500 CU) instead of the
    // up-to-255 SHA-256s of `find_program_address` (~3000-5000 CU).
    //
    // Security: `verifyPda` (via the seeds we feed into the CPI's
    // signer_seeds list, which the runtime checks against the vault's
    // claimed key) is what makes this safe — if the client lies about
    // the bump, the CPI's signer-seed proof fails and the create
    // aborts. We don't need a separate up-front PDA check.
    if (data.len < 2) return error.InvalidInstructionData;
    const bump: u8 = data[1];

    const auth_key = authority.key().*;
    const bump_seed = [_]u8{bump};

    // Build the PDA signer in the runtime's C-ABI shape inline. This
    // is the fast path — `createRentExemptRaw` (and `invokeSignedRaw`
    // under the hood) hand the pointer to the syscall without staging
    // a copy. Saves ~80-120 CU vs. the `signer_seeds: &.{&.{...}}` shape.
    const seeds = [_]sol.cpi.Seed{
        .from("vault"),
        .from(auth_key[0..]),
        .from(&bump_seed),
    };
    const signer = sol.cpi.Signer.from(&seeds);

    try sol.system.createRentExemptRaw(.{
        .payer = authority.toCpiInfo(),
        .new_account = vault.toCpiInfo(),
        .system_program = system_program.toCpiInfo(),
        .space = @sizeOf(VaultState),
        .owner = &PROGRAM_ID,
    }, &.{signer});

    _ = try sol.TypedAccount(VaultState).initialize(vault, .{
        .discriminator = undefined,
        .authority = auth_key,
        .balance = 0,
        .bump = bump,
    });
}

// -------------------------------------------------------------------------
// deposit: transfer lamports from payer to vault, bump `balance`
// -------------------------------------------------------------------------

fn processDeposit(
    payer: AccountInfo,
    vault_info: AccountInfo,
    system_program: AccountInfo,
    data: []const u8,
) sol.ProgramResult {
    try payer.expectSigner();
    try payer.expectWritable();
    try vault_info.expectWritable();
    try vault_info.assertOwnerComptime(PROGRAM_ID);

    if (data.len < 9) return error.InvalidInstructionData;
    const amount: u64 = @as(*align(1) const u64, @ptrCast(data[1..9])).*;

    const vault = try sol.TypedAccount(VaultState).bind(vault_info);

    try sol.system.transfer(
        payer.toCpiInfo(),
        vault_info.toCpiInfo(),
        system_program.toCpiInfo(),
        amount,
    );

    const new_balance, const overflow = @addWithOverflow(vault.read().balance, amount);
    if (overflow != 0) return VaultErr.toError(.AmountOverflow);
    vault.write().balance = new_balance;

    sol.emit(DepositEvent{
        .amount = amount,
        .new_balance = new_balance,
    });
}

// -------------------------------------------------------------------------
// withdraw: authority moves lamports from vault → recipient
// -------------------------------------------------------------------------

fn processWithdraw(
    authority: AccountInfo,
    vault_info: AccountInfo,
    recipient: AccountInfo,
    data: []const u8,
) sol.ProgramResult {
    try authority.expectSigner();
    try vault_info.expectWritable();
    try vault_info.assertOwnerComptime(PROGRAM_ID);
    try recipient.expectWritable();

    if (data.len < 9) return error.InvalidInstructionData;
    const amount: u64 = @as(*align(1) const u64, @ptrCast(data[1..9])).*;

    const vault = try sol.TypedAccount(VaultState).bind(vault_info);

    try vault.requireHasOneWith("authority", authority, VaultErr.toError(.Unauthorized));

    const auth_key = authority.key().*;
    try sol.verifyPda(
        vault_info.key(),
        &.{ "vault", auth_key[0..] },
        vault.read().bump,
        &PROGRAM_ID,
    );

    if (vault.read().balance < amount) {
        return VaultErr.toError(.InsufficientVaultBalance);
    }

    vault_info.subLamports(amount);
    recipient.addLamports(amount);
    const new_balance = vault.read().balance - amount;
    vault.write().balance = new_balance;

    sol.emit(WithdrawEvent{
        .amount = amount,
        .new_balance = new_balance,
    });
}

// =========================================================================
// Entry — boilerplate
// =========================================================================

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
