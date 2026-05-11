const sol = @import("solana_program_sdk");

fn processInstruction(context: *sol.entrypoint.InstructionContext(2)) sol.ProgramResult {
    if (sol.entrypoint.unlikely(context.remaining() != 2)) {
        return error.NotEnoughAccountKeys;
    }

    const source = context.nextAccountEx(.unchecked);
    const destination = context.nextAccountEx(.unchecked);

    const ix_data = context.instructionData();
    if (ix_data.len < 8) return error.InvalidInstructionData;

    const transfer_amount: u64 = @as(u64, ix_data[0]) |
        (@as(u64, ix_data[1]) << 8) |
        (@as(u64, ix_data[2]) << 16) |
        (@as(u64, ix_data[3]) << 24) |
        (@as(u64, ix_data[4]) << 32) |
        (@as(u64, ix_data[5]) << 40) |
        (@as(u64, ix_data[6]) << 48) |
        (@as(u64, ix_data[7]) << 56);

    source.lamports_ptr.* -= transfer_amount;
    destination.lamports_ptr.* += transfer_amount;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointMax(2, processInstruction)(input);
}
