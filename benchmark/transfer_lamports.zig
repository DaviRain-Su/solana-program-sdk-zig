const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Transfer lamports — using comptime typed deserialization
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() != 2)) {
        return error.NotEnoughAccountKeys;
    }

    const source = ctx.nextAccountUnchecked();
    const destination = ctx.nextAccountUnchecked();

    // Comptime typed read — no manual pointer casting
    const transfer_amount = ctx.readIx(u64, 0);

    source.subLamports(transfer_amount);
    destination.addLamports(transfer_amount);
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
