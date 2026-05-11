const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Pubkey comparison — safe (byte-by-byte)
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const account = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;

    if (sol.pubkey.pubkeyEq(account.key(), account.owner())) {
        return;
    } else {
        return error.InvalidArgument;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
