const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Same shape as the other parse-account primitives, but isolates the
// writable-flag checks in `parseAccountsWith`.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const accs = try ctx.parseAccountsWith(.{
        .{ "from", sol.entrypoint.AccountExpectation{ .writable = true } },
        .{ "to", sol.entrypoint.AccountExpectation{ .writable = true } },
    });

    if (sol.pubkey.pubkeyEq(accs.from.key(), accs.to.key())) {
        return error.InvalidArgument;
    }
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
