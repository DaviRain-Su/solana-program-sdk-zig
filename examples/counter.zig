//! Counter — minimal stateful PDA program.
//!
//! Demonstrates a one-account-per-user state machine:
//!   - `Initialize` — create a counter PDA, set count = 0
//!   - `Increment` — bump the counter by `delta` (u64, instruction data)
//!   - `Reset`     — set count back to 0 (owner-only)
//!
//! Each user owns a PDA derived from `[b"counter", owner.key()]`. The
//! program enforces the owner-only constraint via stored authority +
//! `has_one`-style check.
//!
//! SDK features showcased:
//!   - `programEntrypoint(N, ...)` — eager 3-account parse with
//!     positional access (no `InstructionContext` threading)
//!   - `TypedAccount(CounterState)` — discriminator-protected typed
//!     account access (`bind` checks the 8-byte discriminator)
//!   - `AccountInfo.expect(.{...})` — declarative per-account checks
//!   - `sol.math.add` — checked arithmetic with single-line error
//!     mapping (replaces `@addWithOverflow + if (ovf) err`)
//!   - `cpi.Seed.fromPubkey` / `Seed.fromByte` — clean PDA seed
//!     construction
//!   - `system.createRentExemptComptimeRaw` — comptime-folded rent
//!     calculation (no `sol_get_rent_sysvar` syscall)
//!   - `ErrorCode` + `programEntrypointTyped` — preserve custom
//!     discriminator across the wire
//!   - `sol.emit` — typed structured event

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Replace with your deployed program ID.
const PROGRAM_ID = sol.pubkey.comptimeFromBase58(
    "Cou1terZigExamp1eProgram111111111111111111X",
);

// =========================================================================
// State
// =========================================================================

const CounterState = extern struct {
    discriminator: [sol.DISCRIMINATOR_LEN]u8,
    owner: sol.Pubkey,
    count: u64,
    bump: u8,
    _pad: [7]u8 = .{0} ** 7,

    pub const DISCRIMINATOR = sol.discriminatorFor("Counter");
};

// =========================================================================
// Events
// =========================================================================

const IncrementEvent = extern struct {
    new_count: u64,
    delta: u64,

    pub const DISCRIMINATOR = sol.eventDiscriminatorFor("Increment");
};

// =========================================================================
// Errors
// =========================================================================

const CounterErr = sol.ErrorCode(
    enum(u32) {
        NotOwner = 6000,
        Overflow = 6001,
    },
    error{ NotOwner, Overflow },
);

// =========================================================================
// Instructions
// =========================================================================

const Ix = enum(u8) {
    initialize = 0,
    increment = 1,
    reset = 2,
};

// =========================================================================
// Entrypoint
// =========================================================================

const AccountInfo = sol.AccountInfo;

fn process(
    accounts: *const [3]AccountInfo,
    data: []const u8,
    _: *const sol.Pubkey,
) CounterErr.Error!void {
    const tag = sol.instruction.parseTag(Ix, data) orelse
        return error.InvalidInstructionData;

    const owner = accounts[0];
    const counter = accounts[1];
    const system_program = accounts[2];

    if (tag == .initialize) return processInitialize(owner, counter, system_program, data);
    if (tag == .increment) return processIncrement(owner, counter, data);
    if (tag == .reset) return processReset(owner, counter);
    return error.InvalidInstructionData;
}

// -------------------------------------------------------------------------
// initialize
// -------------------------------------------------------------------------
// ix-data: [tag:1][bump:1]
//
// The client passes the canonical bump (found off-chain) so the program
// only needs ONE `create_program_address` syscall, not the
// up-to-255 SHA-256s of `find_program_address`.

fn processInitialize(
    owner: AccountInfo,
    counter: AccountInfo,
    system_program: AccountInfo,
    data: []const u8,
) CounterErr.Error!void {
    try owner.expect(.{ .signer = true, .writable = true });
    try counter.expect(.{ .writable = true });

    const bump = sol.instruction.tryReadUnaligned(u8, data, 1) orelse
        return error.InvalidInstructionData;

    const bump_seed = [_]u8{bump};
    const seeds = [_]sol.cpi.Seed{
        .from("counter"),
        .fromPubkey(owner.key()),
        .from(&bump_seed),
    };
    const signer = sol.cpi.Signer.from(&seeds);

    // `space` is comptime → rent-exempt minimum is a u64 immediate
    // at build time (no `sol_get_rent_sysvar` syscall ~85 CU).
    try sol.system.createRentExemptComptimeRaw(.{
        .payer = owner.toCpiInfo(),
        .new_account = counter.toCpiInfo(),
        .system_program = system_program.toCpiInfo(),
        .owner = &PROGRAM_ID,
    }, @sizeOf(CounterState), &.{signer});

    _ = try sol.TypedAccount(CounterState).initialize(counter, .{
        .discriminator = undefined,
        .owner = owner.key().*,
        .count = 0,
        .bump = bump,
    });
}

// -------------------------------------------------------------------------
// increment
// -------------------------------------------------------------------------
// ix-data: [tag:1][delta:u64]

fn processIncrement(
    owner: AccountInfo,
    counter_info: AccountInfo,
    data: []const u8,
) CounterErr.Error!void {
    try owner.expect(.{ .signer = true });
    try counter_info.expect(.{ .writable = true, .owner = PROGRAM_ID });

    const delta = sol.instruction.tryReadUnaligned(u64, data, 1) orelse
        return error.InvalidInstructionData;

    const counter = try sol.TypedAccount(CounterState).bind(counter_info);
    try counter.requireHasOneWith("owner", owner, CounterErr.toError(.NotOwner));

    const state = counter.write();
    const new_count = sol.math.tryAdd(state.count, delta) orelse
        return CounterErr.toError(.Overflow);
    state.count = new_count;

    sol.emit(IncrementEvent{
        .new_count = new_count,
        .delta = delta,
    });
}

// -------------------------------------------------------------------------
// reset
// -------------------------------------------------------------------------
// ix-data: [tag:1]  (no payload)

fn processReset(owner: AccountInfo, counter_info: AccountInfo) CounterErr.Error!void {
    try owner.expect(.{ .signer = true });
    try counter_info.expect(.{ .writable = true, .owner = PROGRAM_ID });

    const counter = try sol.TypedAccount(CounterState).bind(counter_info);
    try counter.requireHasOneWith("owner", owner, CounterErr.toError(.NotOwner));

    counter.write().count = 0;
}

// =========================================================================
// Entry
// =========================================================================

export fn entrypoint(input: [*]u8) u64 {
    // `programEntrypointTyped` catches `CounterErr.Error`, dispatches
    // on variant name (custom code vs builtin ProgramError), and
    // emits the matching wire u64.
    return sol.entrypoint.programEntrypointTyped(3, CounterErr, process)(input);
}
