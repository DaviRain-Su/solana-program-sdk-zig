const sol = @import("solana_program_sdk");

fn processInstruction(context: *sol.entrypoint.InstructionContext(2)) sol.ProgramResult {
    // No checks at all - direct access like rosetta zig
    const source = context.nextAccountEx(.unchecked);
    const destination = context.nextAccountEx(.unchecked);

    const ix_data = context.instructionData();
    const transfer_amount = @as(u64, ix_data[0]);

    source.lamports_ptr.* -= transfer_amount;
    destination.lamports_ptr.* += transfer_amount;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointMax(2, processInstruction)(input);
}
