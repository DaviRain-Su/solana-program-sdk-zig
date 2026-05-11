const sol = @import("solana_program_sdk");

fn processInstruction(context: *sol.entrypoint.InstructionContext(1)) sol.ProgramResult {
    if (sol.entrypoint.unlikely(context.remaining() != 1)) {
        return error.NotEnoughAccountKeys;
    }
    const account = context.nextAccountEx(.unchecked);

    if (sol.pubkey.pubkeyEqAligned(account.key(), account.owner())) {
        return;
    } else {
        return error.InvalidArgument;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointMax(1, processInstruction)(input);
}
