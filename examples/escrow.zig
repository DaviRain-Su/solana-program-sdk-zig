//! Escrow — classic lamport-for-lamport escrow.
//!
//! A maker locks `offered` lamports into an escrow PDA expecting
//! `requested` lamports in return. A taker can fulfil the offer
//! (sending the requested lamports to the maker, claiming the
//! offered lamports). The maker can refund the offer at any time
//! before it's filled.
//!
//! This is the simplest meaningful example of a multi-instruction
//! state machine: `Make` writes state, `Take` reads & destroys it,
//! `Refund` reads & destroys it.
//!
//! Instructions:
//!   0 = Make    accounts: maker (sig+w), escrow PDA (w), system_program
//!               data: [bump:u8][offered:u64][requested:u64]
//!   1 = Take    accounts: taker (sig+w), maker (w), escrow PDA (w)
//!               data: (none)
//!   2 = Refund  accounts: maker (sig+w), escrow PDA (w)
//!               data: (none)
//!
//! The escrow PDA is derived from `[b"escrow", maker.key()]`. Only
//! one outstanding offer per maker — a real escrow would key by an
//! additional nonce so a maker could have multiple offers open.
//!
//! SDK features showcased:
//!   - `ErrorCode + lazyEntrypointTyped` — typed custom codes
//!   - `TypedAccount(EscrowState)` — discriminator-protected state
//!   - `requireHasOneWith` — owner check with custom error
//!   - `verifyPda` — proof the supplied PDA matches stored seeds
//!   - `Seed.fromPubkey` + `Seed.fromByte` — PDA seeds
//!   - `system.createRentExemptComptimeRaw` — comptime rent
//!   - Direct lamport mutation for sub/add (3 CU each, no CPI)
//!   - `sol.emit` events

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// =========================================================================
// Program identity (placeholder — replace before deploy)
// =========================================================================

const PROGRAM_ID = sol.pubkey.comptimeFromBase58("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");

// =========================================================================
// State
// =========================================================================

const EscrowState = extern struct {
    discriminator: [sol.DISCRIMINATOR_LEN]u8,
    maker: sol.Pubkey,
    offered: u64,
    requested: u64,
    bump: u8,
    _pad: [7]u8 = .{0} ** 7,

    pub const DISCRIMINATOR = sol.discriminatorFor("Escrow");
};

// =========================================================================
// Events
// =========================================================================

const MakeEvent = extern struct {
    offered: u64,
    requested: u64,

    pub const DISCRIMINATOR = sol.eventDiscriminatorFor("Make");
};

const TakeEvent = extern struct {
    offered: u64,
    requested: u64,

    pub const DISCRIMINATOR = sol.eventDiscriminatorFor("Take");
};

const RefundEvent = extern struct {
    offered: u64,

    pub const DISCRIMINATOR = sol.eventDiscriminatorFor("Refund");
};

// =========================================================================
// Errors
// =========================================================================

const EscrowErr = sol.ErrorCode(
    enum(u32) {
        NotMaker = 6000,
        InsufficientFunds = 6001,
        InvalidEscrow = 6002,
    },
    error{ NotMaker, InsufficientFunds, InvalidEscrow },
);

// =========================================================================
// Instructions
// =========================================================================

const Ix = enum(u8) {
    make = 0,
    take = 1,
    refund = 2,
};

const AccountInfo = sol.AccountInfo;

fn process(ctx: *sol.entrypoint.InstructionContext) EscrowErr.Error!void {
    // `parseAccountsUnchecked` — `make`/`refund` have 3 accounts;
    // `take` also has 3. We over-parse for the 2-account case but
    // the extra slot is a no-op.
    const a = try ctx.parseAccountsUnchecked(.{ "first", "second", "third" });
    const data = try ctx.instructionData();

    const tag = sol.instruction.parseTag(Ix, data) orelse
        return error.InvalidInstructionData;

    if (tag == .make) return processMake(a.first, a.second, a.third, data);
    if (tag == .take) return processTake(a.first, a.second, a.third);
    if (tag == .refund) return processRefund(a.first, a.second);
    return error.InvalidInstructionData;
}

// -------------------------------------------------------------------------
// make: maker funds the escrow PDA with `offered` lamports
// -------------------------------------------------------------------------
// ix-data: [tag:1][bump:1][offered:u64][requested:u64]

fn processMake(
    maker: AccountInfo,
    escrow: AccountInfo,
    system_program: AccountInfo,
    data: []const u8,
) EscrowErr.Error!void {
    try maker.expect(.{ .signer = true, .writable = true });
    try escrow.expect(.{ .writable = true });

    const bump = sol.instruction.tryReadUnaligned(u8, data, 1) orelse
        return error.InvalidInstructionData;
    const offered = sol.instruction.tryReadUnaligned(u64, data, 2) orelse
        return error.InvalidInstructionData;
    const requested = sol.instruction.tryReadUnaligned(u64, data, 10) orelse
        return error.InvalidInstructionData;

    // Build PDA signer seeds inline. `fromPubkey` lets us point the
    // syscall at the maker's pubkey in-place (no 32-byte copy).
    const bump_seed = [_]u8{bump};
    const seeds = [_]sol.cpi.Seed{
        .from("escrow"),
        .fromPubkey(maker.key()),
        .from(&bump_seed),
    };
    const signer = sol.cpi.Signer.from(&seeds);

    // Create the PDA rent-exempt. Comptime size → no rent sysvar
    // syscall. The PDA itself starts with the rent-exempt minimum;
    // the `offered` amount is transferred separately below.
    try sol.system.createRentExemptComptimeRaw(.{
        .payer = maker.toCpiInfo(),
        .new_account = escrow.toCpiInfo(),
        .system_program = system_program.toCpiInfo(),
        .owner = &PROGRAM_ID,
    }, @sizeOf(EscrowState), &.{signer});

    _ = try sol.TypedAccount(EscrowState).initialize(escrow, .{
        .discriminator = undefined,
        .maker = maker.key().*,
        .offered = offered,
        .requested = requested,
        .bump = bump,
    });

    // Fund the escrow with `offered` lamports. We need a separate
    // transfer because `createAccount` only puts the rent-exempt
    // minimum on the PDA. Use system_program CPI since the maker
    // is the funding source (and isn't program-owned).
    try sol.system.transfer(
        maker.toCpiInfo(),
        escrow.toCpiInfo(),
        system_program.toCpiInfo(),
        offered,
    );

    sol.emit(MakeEvent{
        .offered = offered,
        .requested = requested,
    });
}

// -------------------------------------------------------------------------
// take: taker sends `requested` lamports to maker, claims `offered`
// from escrow PDA, closes the PDA.
// -------------------------------------------------------------------------
// ix-data: [tag:1]

fn processTake(
    taker: AccountInfo,
    maker: AccountInfo,
    escrow_info: AccountInfo,
) EscrowErr.Error!void {
    try taker.expect(.{ .signer = true, .writable = true });
    try maker.expect(.{ .writable = true });
    try escrow_info.expect(.{ .writable = true, .owner = PROGRAM_ID });

    const escrow = try sol.TypedAccount(EscrowState).bind(escrow_info);
    try escrow.requireHasOneWith("maker", maker, EscrowErr.toError(.NotMaker));

    const state = escrow.read();

    // Verify the escrow PDA matches the maker's seeds. Without this
    // check, an attacker could supply a PDA from a different program
    // that happens to have matching state layout.
    try sol.verifyPda(
        escrow_info.key(),
        &.{ "escrow", maker.key()[0..] },
        state.bump,
        &PROGRAM_ID,
    );

    // Taker → maker direct lamport move (~3 CU vs ~1200 CU CPI).
    // Safe because the taker is a signer and the maker is writable.
    if (taker.lamports() < state.requested) {
        return EscrowErr.toError(.InsufficientFunds);
    }
    taker.subLamports(state.requested);
    maker.addLamports(state.requested);

    // Escrow → taker: drain the entire escrow PDA's lamports to
    // the taker (this closes the PDA, since rent is no longer met).
    // We can mutate `escrow_info` lamports directly because we own
    // it (`escrow_info.expect(.owner = PROGRAM_ID)`).
    const escrow_balance = escrow_info.lamports();
    escrow_info.subLamports(escrow_balance);
    taker.addLamports(escrow_balance);

    sol.emit(TakeEvent{
        .offered = state.offered,
        .requested = state.requested,
    });
}

// -------------------------------------------------------------------------
// refund: maker cancels the offer, reclaims the escrow's lamports.
// -------------------------------------------------------------------------
// ix-data: [tag:1]

fn processRefund(maker: AccountInfo, escrow_info: AccountInfo) EscrowErr.Error!void {
    try maker.expect(.{ .signer = true, .writable = true });
    try escrow_info.expect(.{ .writable = true, .owner = PROGRAM_ID });

    const escrow = try sol.TypedAccount(EscrowState).bind(escrow_info);
    try escrow.requireHasOneWith("maker", maker, EscrowErr.toError(.NotMaker));

    const state = escrow.read();

    try sol.verifyPda(
        escrow_info.key(),
        &.{ "escrow", maker.key()[0..] },
        state.bump,
        &PROGRAM_ID,
    );

    // Drain the escrow PDA back to the maker — same direct-lamport
    // pattern as in `take`.
    const escrow_balance = escrow_info.lamports();
    escrow_info.subLamports(escrow_balance);
    maker.addLamports(escrow_balance);

    sol.emit(RefundEvent{
        .offered = state.offered,
    });
}

// =========================================================================
// Entry
// =========================================================================

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointTyped(EscrowErr, process)(input);
}
