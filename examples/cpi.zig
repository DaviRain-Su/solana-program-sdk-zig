//! CPI — minimal cross-program invocation example.
//!
//! Transfers `amount` lamports from `from` (signer) to `to` via a
//! System Program CPI, using the SDK's high-level wrapper
//! `sol.system.transfer`.
//!
//! Accounts (in order):
//!   0. from           — signer, writable
//!   1. to             — writable
//!   2. system program — read-only (required by the CPI syscall)
//!
//! Instruction data: little-endian u64 `amount` (8 bytes).
//!
//! Cost: a System Program CPI is ~1200 CU runtime-imposed; this
//! program adds only the parsing + dispatch overhead on top.

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() < 3)) {
        return error.NotEnoughAccountKeys;
    }

    const from = ctx.nextAccountUnchecked();
    const to = ctx.nextAccountUnchecked();
    const system_program = ctx.nextAccountUnchecked();

    const amount = ctx.readIx(u64, 0);

    try sol.system.transfer(
        from.toCpiInfo(),
        to.toCpiInfo(),
        system_program.toCpiInfo(),
        amount,
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
