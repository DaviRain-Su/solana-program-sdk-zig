const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

const PROGRAM_ID: sol.Pubkey = sol.pubkey.comptimeFromBase58(
    "BenchPubkey11111111111111111111111111111111",
);

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() != 4)) {
        return error.NotEnoughAccountKeys;
    }

    const from = ctx.nextAccountUnchecked();
    const base = ctx.nextAccountUnchecked();
    const to = ctx.nextAccountUnchecked();
    const system_program = ctx.nextAccountUnchecked();
    const bump = ctx.readIx(u8, 0);
    const bump_seed = [_]u8{bump};

    try sol.system.transferWithSeedSignedSingle(
        from.toCpiInfo(),
        base.toCpiInfo(),
        to.toCpiInfo(),
        system_program.toCpiInfo(),
        "vault",
        &PROGRAM_ID,
        1,
        .{ "base", &bump_seed },
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
