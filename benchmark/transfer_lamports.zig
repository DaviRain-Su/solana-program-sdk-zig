const sol = @import("solana_program_sdk");

fn processInstruction(context: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    // Pinocchio-style: check account count
    if (sol.entrypoint.unlikely(context.remaining() != 2)) {
        return error.NotEnoughAccountKeys;
    }

    // Use compile-time safety level: .unchecked for max performance
    const source = context.nextAccountEx(.unchecked);
    const destination = context.nextAccountEx(.unchecked);

    // Get instruction data (unchecked since we know all accounts are parsed)
    const ix_data = context.instructionDataEx(.unchecked);
    if (ix_data.len < 8) return error.InvalidInstructionData;

    // Manual bytes to u64 (avoid std.mem.readInt stack usage)
    const transfer_amount: u64 = @as(u64, ix_data[0]) |
        (@as(u64, ix_data[1]) << 8) |
        (@as(u64, ix_data[2]) << 16) |
        (@as(u64, ix_data[3]) << 24) |
        (@as(u64, ix_data[4]) << 32) |
        (@as(u64, ix_data[5]) << 40) |
        (@as(u64, ix_data[6]) << 48) |
        (@as(u64, ix_data[7]) << 56);

    // Direct lamports manipulation (no borrow checking)
    source.lamports_ptr.* -= transfer_amount;
    destination.lamports_ptr.* += transfer_amount;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(processInstruction)(input);
}
