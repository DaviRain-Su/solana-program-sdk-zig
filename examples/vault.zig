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

const DepositEvent = extern struct {
    vault: sol.Pubkey,
    payer: sol.Pubkey,
    amount: u64,
    new_balance: u64,

    pub const DISCRIMINATOR = sol.eventDiscriminatorFor("Deposit");
};

const WithdrawEvent = extern struct {
    vault: sol.Pubkey,
    recipient: sol.Pubkey,
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

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const data = ctx.instructionDataUnchecked();
    if (data.len < 1) return error.InvalidInstructionData;

    const tag: Ix = @enumFromInt(data[0]);

    if (tag == .initialize) return processInitialize(ctx);
    if (tag == .deposit) return processDeposit(ctx);
    if (tag == .withdraw) return processWithdraw(ctx);
    return error.InvalidInstructionData;
}

// -------------------------------------------------------------------------
// initialize: create the vault PDA, write the discriminator + state
// -------------------------------------------------------------------------

const Exp = sol.entrypoint.AccountExpectation;

fn processInitialize(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const a = try ctx.parseAccountsWith(.{
        .{ "authority", Exp{ .signer = true, .writable = true } },
        .{ "vault", Exp{ .writable = true } },
        .{ "system_program", Exp{} },
    });

    // Derive PDA + bump for `["vault", authority.key]`
    const auth_key = a.authority.key().*;
    const seeds = [_][]const u8{ "vault", auth_key[0..] };
    const found = try sol.pda.findProgramAddress(&seeds, &PROGRAM_ID);
    const bump_seed = [_]u8{found.bump_seed};

    // Create the account (PDA-signed)
    try sol.system.createRentExempt(.{
        .payer = a.authority.toCpiInfo(),
        .new_account = a.vault.toCpiInfo(),
        .system_program = a.system_program.toCpiInfo(),
        .space = @sizeOf(VaultState),
        .owner = &PROGRAM_ID,
        .signer_seeds = &.{&.{ "vault", auth_key[0..], &bump_seed }},
    });

    // Initialize typed state — discriminator is written automatically.
    _ = try sol.TypedAccount(VaultState).initialize(a.vault, .{
        .discriminator = undefined,
        .authority = auth_key,
        .balance = 0,
        .bump = found.bump_seed,
    });
}

// -------------------------------------------------------------------------
// deposit: transfer lamports from payer to vault, bump `balance`
// -------------------------------------------------------------------------

fn processDeposit(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const a = try ctx.parseAccountsWith(.{
        .{ "payer", Exp{ .signer = true, .writable = true } },
        .{ "vault", Exp{ .writable = true, .owner = PROGRAM_ID } },
        .{ "system_program", Exp{} },
    });

    const data = ctx.instructionDataUnchecked();
    if (data.len < 9) return error.InvalidInstructionData;
    const amount: u64 = @as(*align(1) const u64, @ptrCast(data[1..9])).*;

    const vault = try sol.TypedAccount(VaultState).bind(a.vault);

    // CPI: System Program transfer
    try sol.system.transfer(
        a.payer.toCpiInfo(),
        a.vault.toCpiInfo(),
        a.system_program.toCpiInfo(),
        amount,
    );

    // Bump the on-chain accounting field
    const new_balance, const overflow = @addWithOverflow(vault.read().balance, amount);
    if (overflow != 0) return VaultErr.toError(.AmountOverflow);
    vault.write().balance = new_balance;

    // Emit a structured event so off-chain indexers can react.
    sol.emit(DepositEvent{
        .vault = a.vault.key().*,
        .payer = a.payer.key().*,
        .amount = amount,
        .new_balance = new_balance,
    });
}

// -------------------------------------------------------------------------
// withdraw: authority moves lamports from vault → recipient
// (Direct lamport mutation; the program owns the vault account.)
// -------------------------------------------------------------------------

fn processWithdraw(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const a = try ctx.parseAccountsWith(.{
        .{ "authority", Exp{ .signer = true } },
        .{ "vault", Exp{ .writable = true, .owner = PROGRAM_ID } },
        .{ "recipient", Exp{ .writable = true } },
    });

    const data = ctx.instructionDataUnchecked();
    if (data.len < 9) return error.InvalidInstructionData;
    const amount: u64 = @as(*align(1) const u64, @ptrCast(data[1..9])).*;

    const vault = try sol.TypedAccount(VaultState).bind(a.vault);

    // has_one(authority) — vault.authority must equal the signer.
    // Returns error.IncorrectAuthority on mismatch.
    try vault.requireHasOneWith("authority", a.authority, VaultErr.toError(.Unauthorized));

    // PDA verification: vault.key == createProgramAddress(
    //   ["vault", authority.key, vault.bump], PROGRAM_ID)
    // Saves the ~3000 CU of a full findProgramAddress by reusing the
    // bump stored in account data.
    const auth_key = a.authority.key().*;
    try sol.verifyPda(
        a.vault.key(),
        &.{ "vault", auth_key[0..] },
        vault.read().bump,
        &PROGRAM_ID,
    );

    if (vault.read().balance < amount) {
        return VaultErr.toError(.InsufficientVaultBalance);
    }

    // Direct lamport move (program owns vault → no CPI required)
    a.vault.subLamports(amount);
    a.recipient.addLamports(amount);
    const new_balance = vault.read().balance - amount;
    vault.write().balance = new_balance;

    sol.emit(WithdrawEvent{
        .vault = a.vault.key().*,
        .recipient = a.recipient.key().*,
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
