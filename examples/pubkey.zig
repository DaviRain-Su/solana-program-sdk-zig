//! Pubkey — exercises the SDK's `sol.pubkey` / `sol.pda` API.
//!
//! Three instructions, each loading a different corner of the pubkey
//! surface area:
//!
//!   ix=0  DerivePda
//!         Run `sol_try_find_program_address` for seeds
//!         `["pubkey-example", caller.key()]` and emit the resulting
//!         `(address, bump)` as return data. Demonstrates the
//!         expensive runtime path (~1500–3000 CU depending on luck).
//!
//!   ix=1  VerifyPda
//!         Caller supplies `bump` in the instruction data and passes
//!         the derived PDA as account[1]. The program calls
//!         `sol.verifyPda` — the Anchor `seeds = [...], bump = stored`
//!         equivalent — which costs ONE SHA-256 (~1500 CU) instead of
//!         up-to-255. Returns `InvalidSeeds` if the bump is wrong.
//!         This is the canonical client-supplied-bump optimisation.
//!
//!   ix=2  CheckOwner
//!         Reads account[1] and verifies its owner is in a whitelist
//!         via `sol.pubkey.pubkeyEqAny(&owner, &.{
//!             sol.system_program_id, sol.bpf_loader_upgradeable_id,
//!         })`. Returns `IncorrectProgramId` on mismatch. Demonstrates
//!         the comptime-folded multi-pubkey equality (each entry is
//!         a 4×u64 immediate compare — ~9 CU per pubkey).
//!
//! Accounts (always 2, even when unused):
//!   0. caller       — signer (used in seeds for ix 0/1)
//!   1. target       — meaning depends on tag:
//!                       ix=0 ignored, ix=1 expected PDA,
//!                       ix=2 owner-check target
//!
//! Instruction data:
//!   ix=0:  [tag:1]
//!   ix=1:  [tag:1][bump:1]
//!   ix=2:  [tag:1]

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

const PROGRAM_ID = sol.pubkey.comptimeFromBase58(
    "Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK",
);

const SEED_PREFIX: []const u8 = "pubkey-example";

const Ix = enum(u8) {
    derive_pda = 0,
    verify_pda = 1,
    check_owner = 2,
};

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() < 2)) {
        return error.NotEnoughAccountKeys;
    }
    const caller = ctx.nextAccountUnchecked();
    const target = ctx.nextAccountUnchecked();

    const data = ctx.instructionDataUnchecked();
    const tag = sol.instruction.parseTag(Ix, data) orelse
        return error.InvalidInstructionData;

    return switch (tag) {
        .derive_pda => derivePda(caller),
        .verify_pda => verifyPda(caller, target, data),
        .check_owner => checkOwner(target),
    };
}

// -------------------------------------------------------------------------
// ix=0  DerivePda
// -------------------------------------------------------------------------

fn derivePda(caller: sol.AccountInfo) sol.ProgramResult {
    // `findProgramAddress` is the syscall that walks bumps 255..0
    // server-side. The off-chain client usually does this once and
    // passes the result in via `VerifyPda` (see ix=1) — that saves
    // ~1500-3000 CU on every subsequent call.
    const seeds = [_][]const u8{ SEED_PREFIX, caller.key()[0..] };
    const derived = try sol.pda.findProgramAddress(&seeds, &PROGRAM_ID);

    // Surface the result via return data so the test can assert
    // against it without parsing logs.
    var buf: [33]u8 = undefined;
    @memcpy(buf[0..32], &derived.address);
    buf[32] = derived.bump_seed;
    sol.cpi.setReturnData(&buf);
}

// -------------------------------------------------------------------------
// ix=1  VerifyPda
// -------------------------------------------------------------------------

fn verifyPda(
    caller: sol.AccountInfo,
    expected: sol.AccountInfo,
    data: []const u8,
) sol.ProgramResult {
    const bump = sol.instruction.tryReadUnaligned(u8, data, 1) orelse
        return error.InvalidInstructionData;

    const seeds = [_][]const u8{ SEED_PREFIX, caller.key()[0..] };
    try sol.verifyPda(expected.key(), &seeds, bump, &PROGRAM_ID);
}

// -------------------------------------------------------------------------
// ix=2  CheckOwner
// -------------------------------------------------------------------------

fn checkOwner(target: sol.AccountInfo) sol.ProgramResult {
    // Comptime-folded multi-pubkey equality. The `inline for` inside
    // `pubkeyEqAny` unrolls into 2 × 4×u64 immediate compares —
    // ~18 CU total for this 2-way check.
    if (!sol.pubkey.pubkeyEqAny(target.owner(), &.{
        sol.system_program_id,
        sol.bpf_loader_upgradeable_id,
    })) {
        return error.IncorrectProgramId;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
