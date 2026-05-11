const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Pubkey comparison — unchecked (aligned u64 chunks, max performance)
fn process(ctx: *sol.entrypoint.InstructionContext) u64 {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() != 1)) return 1;

    const account = ctx.nextAccountUnchecked();

    if (sol.pubkey.pubkeyEqAligned(account.key(), account.owner())) {
        return 0;
    } else {
        return 1;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointRaw(process)(input);
}
