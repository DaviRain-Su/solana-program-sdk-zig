const sol = @import("solana_program_sdk");

fn processInstruction(context: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const account = context.nextAccount() orelse return error.NotEnoughAccountKeys;

    if (sol.pubkey.pubkeyEqAligned(account.key(), account.owner())) {
        return;
    } else {
        return error.InvalidArgument;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(processInstruction)(input);
}
