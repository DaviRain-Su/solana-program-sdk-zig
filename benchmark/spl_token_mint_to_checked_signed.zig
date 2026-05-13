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
    const seeds = [_]sol.cpi.Seed{
        .from("vault"),
        .from(&bump_seed),
    };
    const signer = sol.cpi.Signer.from(&seeds);

    try spl_token.cpi.mintToCheckedSigned(
        a.token_program.toCpiInfo(),
        a.mint.toCpiInfo(),
        a.destination.toCpiInfo(),
        a.authority.toCpiInfo(),
        1,
        6,
        &.{signer},
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
