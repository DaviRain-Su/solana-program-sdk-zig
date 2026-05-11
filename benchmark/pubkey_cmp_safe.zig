const sol = @import("solana_program_sdk");

fn processInstruction(context: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    // Safe mode: check remaining first, then use unchecked
    if (context.remaining() < 1) return error.NotEnoughAccountKeys;
    const account = context.nextAccountEx(.safe);

    // Safe comparison (with alignment check)
    if (sol.pubkey.pubkeyEq(account.key(), account.owner())) {
        return;
    } else {
        return error.InvalidArgument;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(processInstruction)(input);
}
