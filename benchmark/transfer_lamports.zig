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

    // Read little-endian u64 from instruction data (zero overhead)
    const transfer_amount: u64 = @as(*align(1) const u64, @ptrCast(ix_data[0..8])).*;

    source.raw.lamports -= transfer_amount;
    destination.raw.lamports += transfer_amount;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
