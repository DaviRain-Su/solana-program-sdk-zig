const sol = @import("solana_program_sdk");
const spl_token = @import("spl_token");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const a = try ctx.parseAccountsUnchecked(.{
        "token_program",
        "source",
        "mint",
        "destination",
        "multisig_authority",
        "signer_one",
        "signer_two",
        "signer_three",
    });

    const signer_infos = [_]sol.CpiAccountInfo{
        a.signer_one.toCpiInfo(),
        a.signer_two.toCpiInfo(),
        a.signer_three.toCpiInfo(),
    };

    try spl_token.cpi.transferCheckedMultisig(
        a.token_program.toCpiInfo(),
        a.source.toCpiInfo(),
        a.mint.toCpiInfo(),
        a.destination.toCpiInfo(),
        a.multisig_authority.toCpiInfo(),
        &signer_infos,
        1,
        6,
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
