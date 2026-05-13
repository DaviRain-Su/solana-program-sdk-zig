const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

const PROGRAM_ID: sol.Pubkey = sol.pubkey.comptimeFromBase58(
    "BenchPubkey11111111111111111111111111111111",
);
const SPACE: u64 = 32;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() != 3)) {
        return error.NotEnoughAccountKeys;
    }

    const payer = ctx.nextAccountUnchecked();
    const new_account = ctx.nextAccountUnchecked();
    const system_program = ctx.nextAccountUnchecked();

    try sol.system.createRentExempt(.{
        .payer = payer.toCpiInfo(),
        .new_account = new_account.toCpiInfo(),
        .system_program = system_program.toCpiInfo(),
        .space = SPACE,
        .owner = &PROGRAM_ID,
    });
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
