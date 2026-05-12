const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Same logical shape as parse_accounts_with.zig, but assumes the
// account slots are structurally unique and therefore uses the new
// validated fast path.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const accs = try ctx.parseAccountsWithUnchecked(.{
        .{ "from", sol.entrypoint.AccountExpectation{ .signer = true, .writable = true } },
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
