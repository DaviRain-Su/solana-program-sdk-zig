const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

const PROGRAM_ID: sol.Pubkey = sol.pubkey.comptimeFromBase58(
    "BenchPubkey11111111111111111111111111111111",
);

// Same shape as the other parse-account primitives, but isolates the
// comptime owner-compare path in `parseAccountsWith`.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const accs = try ctx.parseAccountsWith(.{
        .{ "from", sol.entrypoint.AccountExpectation{} },
        .{ "to", sol.entrypoint.AccountExpectation{ .owner = PROGRAM_ID } },
    });

    if (sol.pubkey.pubkeyEq(accs.from.key(), accs.to.key())) {
        return error.InvalidArgument;
    }
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
