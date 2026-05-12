//! `spl-memo` reference on-chain example.
//!
//! Emits a memo by CPI'ing into the real SPL Memo program. Used by
//! `program-test/tests/spl_memo.rs` to prove that the bytes our
//! builder produces are actually accepted by SPL Memo running inside
//! a real Mollusk VM — not just shaped right at the host-test level.
//!
//! Accounts (in order):
//!   0. memo_program — the SPL Memo program account (read-only,
//!      executable). Required so the runtime can look up the
//!      callee for the CPI.
//!   1..N. zero or more signers — every account passed beyond
//!         `memo_program` is treated as a signer that must co-sign
//!         the memo. SPL Memo verifies this on its own end.
//!
//! Instruction data: the raw UTF-8 memo bytes (no discriminator,
//! no length prefix — same on-the-wire shape the SPL Memo program
//! itself expects).
//!
//! Why a thin pass-through is enough for an integration test: it
//! exercises both `spl_memo.cpi.memo` (signer path) and the runtime
//! CPI machinery, while keeping the demo's own logic minimal so any
//! failure during testing points at the SDK / sub-package, not at
//! application logic.

const sol = @import("solana_program_sdk");
const spl_memo = @import("spl_memo");

pub const panic = sol.panic.Panic;

const max_signers = 4;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    // Snapshot the runtime-supplied account count up front — the
    // unchecked iterator below does *not* decrement
    // `ctx.remaining`, so we drive the loop with our own counter to
    // avoid reading past the end of the input buffer.
    const total = ctx.remainingAccounts();
    if (sol.entrypoint.unlikely(total < 1)) return error.NotEnoughAccountKeys;

    const memo_program = ctx.nextAccountUnchecked();

    const extras: usize = @intCast(total - 1);
    if (extras > max_signers) return error.InvalidArgument;

    var signers_buf: [max_signers]sol.CpiAccountInfo = undefined;
    var i: usize = 0;
    while (i < extras) : (i += 1) {
        signers_buf[i] = ctx.nextAccountUnchecked().toCpiInfo();
    }

    const message = ctx.instructionDataUnchecked();

    try spl_memo.cpi.memo(
        message,
        memo_program.toCpiInfo(),
        signers_buf[0..extras],
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
