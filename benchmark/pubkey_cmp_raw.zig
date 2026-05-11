const sol = @import("solana_program_sdk");

fn processInstruction(context: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    // Pinocchio-style: use unlikely() for error path
    if (sol.entrypoint.unlikely(context.remaining() != 1)) {
        return error.NotEnoughAccountKeys;
    }

    // Pinocchio-style: use unchecked since we know there's 1 account
    const account = context.nextAccountUnchecked();

    // Pinocchio-style: pubkey comparison
    if (sol.pubkey.pubkeyEqAligned(account.key(), account.owner())) {
        return;
    } else {
        return error.InvalidArgument;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(processInstruction)(input);
}
