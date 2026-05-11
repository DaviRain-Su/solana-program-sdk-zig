const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Same as parse_accounts.zig, but with comptime-validated signer +
// writable flags via parseAccountsWith. The compiler unrolls each
// inline check — the resulting BPF should be byte-identical to
// hand-written `if (!from.isSigner()) return error.MissingRequiredSignature`.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const accs = try ctx.parseAccountsWith(.{
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
