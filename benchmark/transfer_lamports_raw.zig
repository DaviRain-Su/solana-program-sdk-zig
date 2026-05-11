const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Same transfer logic as transfer_lamports.zig, but via lazyEntrypointRaw.
fn process(ctx: *sol.entrypoint.InstructionContext) u64 {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() != 2)) return 1;

    const source = ctx.nextAccountUnchecked();
    const destination = ctx.nextAccountUnchecked();

    const transfer_amount = ctx.readIx(u64, 0);

    source.subLamports(transfer_amount);
    destination.addLamports(transfer_amount);

    return 0;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointRaw(process)(input);
}
