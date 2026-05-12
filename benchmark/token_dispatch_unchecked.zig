//! Same dispatch shape as `examples/token_dispatch.zig`, but uses the
//! `Unchecked` SDK variants:
//!   - `nextAccountUnchecked` (no dup-aware MaybeAccount union)
//!   - `readIxTag` / `readIx` (no `instructionData()` length guard)
//!
//! Used as a CU comparison vs the safe `parseAccounts`-based dispatcher
//! to isolate where the cost of the "safe" path comes from.

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

const Tag = enum(u32) {
    transfer,
    burn,
    mint,
};

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() < 2)) {
        return error.NotEnoughAccountKeys;
    }
    const first = ctx.nextAccountUnchecked();
    const second = ctx.nextAccountUnchecked();

    // After nextAccountUnchecked × 2, `remaining` is unchanged (the
    // unchecked variant does NOT decrement it) — so the buffer now
    // sits at the ix-data length prefix, exactly where the
    // `readIx*` family expects it.
    const tag = ctx.readIxTag(Tag);
    const amount = ctx.readIx(u64, 4);

    if (tag == .transfer) {
        first.subLamports(amount);
        second.addLamports(amount);
        return;
    }
    if (tag == .burn) {
        first.subLamports(amount);
        second.addLamports(amount);
        return;
    }
    if (tag == .mint) {
        second.subLamports(amount);
        first.addLamports(amount);
        return;
    }
    return error.InvalidInstructionData;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
