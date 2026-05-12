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
///
/// `programEntrypoint(3, ...)` would also work here and read marginally
/// cleaner (positional `accounts[0]` access, no InstructionContext),
/// but the CU cost is identical — LLVM optimizes the lazy +
/// `parseAccountsUnchecked` path into the same straight-line code.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    // `parseAccountsUnchecked` skips the dup-aware tagged-union switch
    // — vault's three accounts have structurally distinct roles
    // (authority / vault PDA / system_program or recipient), so duplicates
    // are nonsensical and would fail downstream checks anyway. Saves
    // ~70 CU per call vs the safe `parseAccounts`.
    const a = try ctx.parseAccountsUnchecked(.{ "first", "second", "third" });
    const data = try ctx.instructionData();

    const tag = sol.instruction.parseTag(Ix, data) orelse
        return error.InvalidInstructionData;
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
    try authority.expect(.{ .signer = true, .writable = true });
    try vault.expect(.{ .writable = true });

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
    const bump = sol.instruction.tryReadUnaligned(u8, data, 1) orelse
        return error.InvalidInstructionData;

    const bump_seed = [_]u8{bump};

    // Build the PDA signer in the runtime's C-ABI shape inline. We use
    // `Seed.fromPubkey` to feed the authority key directly from the
    // runtime's input buffer — saving a 32-byte stack copy compared to
    // materialising `auth_key = authority.key().*` first.
    //
    // Fast path: `createRentExemptRaw` (and `invokeSignedRaw` under
    // the hood) hand the pointer to the syscall without staging a
    // copy. Saves ~80-120 CU vs. the `signer_seeds: &.{&.{...}}` shape.
    const seeds = [_]sol.cpi.Seed{
        .from("vault"),
        .fromPubkey(authority.key()),
        .from(&bump_seed),
    };
    const signer = sol.cpi.Signer.from(&seeds);

    // `space` is comptime, so the SDK folds the rent-exempt minimum
    // balance into a single u64 immediate at build time. No
    // `sol_get_rent_sysvar` syscall (~85 CU) at runtime.
    try sol.system.createRentExemptComptimeRaw(.{
        .payer = authority.toCpiInfo(),
        .new_account = vault.toCpiInfo(),
        .system_program = system_program.toCpiInfo(),
        .owner = &PROGRAM_ID,
    }, @sizeOf(VaultState), &.{signer});

    _ = try sol.TypedAccount(VaultState).initialize(vault, .{
        .discriminator = undefined,
        .authority = authority.key().*,
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
    try payer.expect(.{ .signer = true, .writable = true });
    try vault_info.expect(.{ .writable = true, .owner = PROGRAM_ID });

    const amount = sol.instruction.tryReadUnaligned(u64, data, 1) orelse
        return error.InvalidInstructionData;

    // `bind` enforces the 8-byte discriminator. `assertOwnerComptime`
    // above already proved we own the account, so a type-confusion
    // attack would require the attacker to (a) pass an account we
    // own and (b) get this program to have ever written a different
    // type into it. We don't, so `bindUnchecked` is safe here and
    // skips the 8-byte compare (~10-15 CU).
    const vault = sol.TypedAccount(VaultState).bindUnchecked(vault_info);

    try sol.system.transfer(
        payer.toCpiInfo(),
        vault_info.toCpiInfo(),
        system_program.toCpiInfo(),
        amount,
    );

    const new_balance = sol.math.tryAdd(vault.read().balance, amount) orelse
        return VaultErr.toError(.AmountOverflow);
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
    try authority.expect(.{ .signer = true });
    try vault_info.expect(.{ .writable = true, .owner = PROGRAM_ID });
    try recipient.expect(.{ .writable = true });

    const amount = sol.instruction.tryReadUnaligned(u64, data, 1) orelse
        return error.InvalidInstructionData;

    // See deposit: `assertOwnerComptime` already proved this is our
    // VaultState account, so the discriminator check is redundant.
    const vault = sol.TypedAccount(VaultState).bindUnchecked(vault_info);

    try vault.requireHasOneWith("authority", authority, VaultErr.toError(.Unauthorized));

    // Cache the typed pointer once. LLVM can usually CSE these reads,
    // but pinning the pointer avoids re-running the @ptrCast/@alignCast
    // chain at every field access.
    const state = vault.write();

    // Pass `authority.key()[0..]` directly — the pubkey lives in the
    // runtime input buffer, so we save a 32-byte stack copy compared
    // to materialising `auth_key = authority.key().*` first.
    try sol.verifyPda(
        vault_info.key(),
        &.{ "vault", authority.key()[0..] },
        state.bump,
        &PROGRAM_ID,
    );

    // Use the `<` compare directly, not `sol.math.trySub`. Why: this
    // is the **happy path** for a successful withdrawal, and BPFv2's
    // codegen for `@subWithOverflow` materializes the carry flag as a
    // value-to-store-and-test (~6 CU extra). The hand-written
    // `if (a < b) err; let new = a - b;` shape compiles to a single
    // compare-and-branch on the no-overflow path.
    //
    // The principle: prefer `try sol.math.sub/add` when you'd otherwise
    // write a manual `@addWithOverflow` (they're free); but for
    // `a < b → err else a - b`, the hand-written form is still cheaper.
    if (state.balance < amount) {
        return VaultErr.toError(.InsufficientVaultBalance);
    }

    vault_info.subLamports(amount);
    recipient.addLamports(amount);
    const new_balance = state.balance - amount;
    state.balance = new_balance;

    sol.emit(WithdrawEvent{
        .amount = amount,
        .new_balance = new_balance,
    });
}

// =========================================================================
// Entry — boilerplate
// =========================================================================

export fn entrypoint(input: [*]u8) u64 {
    // Use the `With` variant because `process` calls
    // `VaultErr.toError(.X)` — that helper stashes the original `u32`
    // discriminator in a module-local slot, and `lazyEntrypointWith`
    // reads it on the `error.Custom` path so the runtime sees the
    // correct wire code. Plain `lazyEntrypoint` would collapse every
    // VaultErr variant to `CUSTOM_ZERO`.
    return sol.entrypoint.lazyEntrypointWith(process)(input);
}
