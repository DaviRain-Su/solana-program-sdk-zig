const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Transfer lamports — full business logic with validation
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() != 2)) {
        return error.NotEnoughAccountKeys;
    }

    const source = ctx.nextAccountUnchecked();
    const destination = ctx.nextAccountUnchecked();

    const ix_data = ctx.instructionData();
    if (ix_data.len < 8) return error.InvalidInstructionData;

    const transfer_amount: u64 = @as(u64, ix_data[0]) |
        (@as(u64, ix_data[1]) << 8) |
        (@as(u64, ix_data[2]) << 16) |
        (@as(u64, ix_data[3]) << 24) |
        (@as(u64, ix_data[4]) << 32) |
        (@as(u64, ix_data[5]) << 40) |
        (@as(u64, ix_data[6]) << 48) |
        (@as(u64, ix_data[7]) << 56);

    source.raw.lamports -= transfer_amount;
    destination.raw.lamports += transfer_amount;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
