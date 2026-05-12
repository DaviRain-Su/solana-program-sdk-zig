//! End-to-end demo of the SDK's "Anchor-style foundations" without a framework.
//!
//! Demonstrates:
//!   - `parseAccountsWith` with comptime signer / writable / owner checks
//!   - `TypedAccount(VaultState)` zero-copy typed account access
//!   - `discriminator.forAccount("Vault")` type-confusion defence
//!   - `ErrorCode(VaultError)` + `VaultErr.Error` — typed errors per
//!     variant survive on the wire as `Custom(u32)` codes
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
// duplicating them in the event payload is pure CU waste.
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

const VaultErr = sol.ErrorCode(
    enum(u32) {
        Unauthorized = 6000,
        InsufficientVaultBalance = 6001,
        AmountOverflow = 6002,
    },
    error{ Unauthorized, InsufficientVaultBalance, AmountOverflow },
);

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

/// `process` returns `VaultErr.Error!void` — the union of:
///   - per-variant errors (`error.Unauthorized`, `error.Overflow`, ...)
///     synthesised by `ErrorCode(VaultError)` — these encode as
///     `Custom(N)` on the wire;
///   - `ProgramError` variants for system-error propagation via `try`.
///
/// `lazyEntrypointTyped` catches the error, dispatches on the variant
/// name (custom vs builtin) and emits the right wire code.
fn process(ctx: *sol.entrypoint.InstructionContext) VaultErr.Error!void {
    // `parseAccountsUnchecked` skips the dup-aware tagged-union switch
    // — vault's three accounts have structurally distinct roles, so
    // duplicates are nonsensical. Saves ~70 CU per call.
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
) VaultErr.Error!void {
    try authority.expect(.{ .signer = true, .writable = true });
    try vault.expect(.{ .writable = true });

    // ix-data layout: [tag:1][bump:1]. The client passes the canonical
    // bump (found off-chain via `find_program_address`) so we only
    // need ONE `create_program_address` syscall (~1500 CU) instead of
    // up to 255 SHA-256s.
    const bump = sol.instruction.tryReadUnaligned(u8, data, 1) orelse
        return error.InvalidInstructionData;

    const bump_seed = [_]u8{bump};

    // Build the PDA signer in the runtime's C-ABI shape inline. We use
    // `Seed.fromPubkey` so the authority key is read directly from the
    // runtime's input buffer — no 32-byte stack copy.
    const seeds = [_]sol.cpi.Seed{
        .from("vault"),
        .fromPubkey(authority.key()),
        .from(&bump_seed),
    };
    const signer = sol.cpi.Signer.from(&seeds);

    // `space` is comptime, so the SDK folds the rent-exempt minimum
    // into a single u64 immediate at build time — no `sol_get_rent_sysvar`
    // syscall (~85 CU) at runtime.
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
) VaultErr.Error!void {
    try payer.expect(.{ .signer = true, .writable = true });
    try vault_info.expect(.{ .writable = true, .owner = PROGRAM_ID });

    const amount = sol.instruction.tryReadUnaligned(u64, data, 1) orelse
        return error.InvalidInstructionData;

    // `assertOwnerComptime` already proved we own the account, so
    // `bindUnchecked` is safe here (skips the 8-byte discriminator
    // compare — ~10-15 CU).
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
) VaultErr.Error!void {
    try authority.expect(.{ .signer = true });
    try vault_info.expect(.{ .writable = true, .owner = PROGRAM_ID });
    try recipient.expect(.{ .writable = true });

    const amount = sol.instruction.tryReadUnaligned(u64, data, 1) orelse
        return error.InvalidInstructionData;

    const vault = sol.TypedAccount(VaultState).bindUnchecked(vault_info);

    // `requireHasOneWith` lets us pick which error to return on
    // mismatch — we want `VaultErr.toError(.Unauthorized)` so the
    // runtime sees code 6000 (not the default IncorrectAuthority).
    try vault.requireHasOneWith("authority", authority, VaultErr.toError(.Unauthorized));

    // Cache the typed pointer once.
    const state = vault.write();

    try sol.verifyPda(
        vault_info.key(),
        &.{ "vault", authority.key()[0..] },
        state.bump,
        &PROGRAM_ID,
    );

    // Use `<` directly, not `sol.math.trySub`. BPFv2 codegen for
    // `@subWithOverflow` materializes the carry flag as a value-to-
    // store-and-test (~6 CU extra). The hand-written form compiles
    // to a single compare-and-branch on the no-overflow path.
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
    // `lazyEntrypointTyped` catches `VaultErr.Error`, dispatches on
    // variant name (custom code vs builtin ProgramError), and emits
    // the matching wire u64.
    return sol.entrypoint.lazyEntrypointTyped(VaultErr, process)(input);
}
