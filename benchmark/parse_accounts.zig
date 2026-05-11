const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Demonstrate ctx.parseAccounts — the compiler unrolls the loop and
// generates a named struct from the comptime tuple. This program is
// behaviour-equivalent to two `nextAccount() orelse ...` calls.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const accs = try ctx.parseAccounts(.{ "from", "to" });

    if (sol.pubkey.pubkeyEq(accs.from.key(), accs.to.key())) {
        return error.InvalidArgument;
    }
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
