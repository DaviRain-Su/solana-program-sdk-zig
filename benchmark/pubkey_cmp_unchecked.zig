const sol = @import("solana_program_sdk");

fn processInstruction(context: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    // Unchecked mode: no bounds check, no alignment check
    if (sol.entrypoint.unlikely(context.remaining() != 1)) {
        return error.NotEnoughAccountKeys;
    }
    const account = context.nextAccountEx(.unchecked);

    // Aligned comparison (caller guarantees alignment)
    if (sol.pubkey.pubkeyEqAligned(account.key(), account.owner())) {
        return;
    } else {
        return error.InvalidArgument;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(processInstruction)(input);
}
