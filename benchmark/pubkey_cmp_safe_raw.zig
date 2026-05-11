const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Same byte-by-byte pubkeyEq as pubkey_cmp_safe.zig, but via lazyEntrypointRaw.
fn process(ctx: *sol.entrypoint.InstructionContext) u64 {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() != 1)) return 1;

    const account = ctx.nextAccountUnchecked();

    if (sol.pubkey.pubkeyEq(account.key(), account.owner())) {
        return 0;
    } else {
        return 1;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointRaw(process)(input);
}
