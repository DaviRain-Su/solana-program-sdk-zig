const sol = @import("solana_program_sdk");
const spl_token = @import("spl_token");

pub const panic = sol.panic.Panic;

const PROGRAM_ID = sol.pubkey.comptimeFromBase58(
    "BenchPubkey11111111111111111111111111111111",
);
const AUTHORITY = sol.pda.comptimeFindProgramAddress(.{"vault"}, PROGRAM_ID);

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const a = try ctx.parseAccountsUnchecked(.{
        "token_program",
        "mint",
        "destination",
        "authority",
    });

    const bump_seed = [_]u8{AUTHORITY.bump_seed};
    try spl_token.cpi.mintToCheckedSignedSingle(
        a.token_program.toCpiInfo(),
        a.mint.toCpiInfo(),
        a.destination.toCpiInfo(),
        a.authority.toCpiInfo(),
        1,
        6,
        .{ "vault", &bump_seed },
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
