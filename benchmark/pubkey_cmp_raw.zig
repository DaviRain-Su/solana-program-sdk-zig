const sol = @import("solana_program_sdk");

fn processInstruction(context: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    // Pinocchio-style: check account count with unlikely hint
    if (sol.entrypoint.unlikely(context.remaining() != 1)) {
        return error.NotEnoughAccountKeys;
    }

    // Use compile-time safety level: .unchecked for max performance
    // This eliminates bounds check at compile time
    const account = context.nextAccountEx(.unchecked);

    // Use aligned comparison (caller guarantees alignment from runtime)
    if (sol.pubkey.pubkeyEqAligned(account.key(), account.owner())) {
        return;
    } else {
        return error.InvalidArgument;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(processInstruction)(input);
}
