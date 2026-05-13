const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Same shape as the other parse-account primitives, but isolates the
// signer-check portion of `parseAccountsWith`.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const accs = try ctx.parseAccountsWith(.{
        .{ "from", sol.entrypoint.AccountExpectation{ .signer = true } },
        .{ "to", sol.entrypoint.AccountExpectation{} },
    });

    if (sol.pubkey.pubkeyEq(accs.from.key(), accs.to.key())) {
        return error.InvalidArgument;
    }
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
