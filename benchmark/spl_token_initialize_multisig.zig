const sol = @import("solana_program_sdk");
const spl_token = @import("spl_token");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const a = try ctx.parseAccountsUnchecked(.{
        "token_program",
        "multisig",
        "rent_sysvar",
        "signer_one",
        "signer_two",
        "signer_three",
    });

    const signer_infos = [_]sol.CpiAccountInfo{
        a.signer_one.toCpiInfo(),
        a.signer_two.toCpiInfo(),
        a.signer_three.toCpiInfo(),
    };

    try spl_token.cpi.initializeMultisig(
        a.token_program.toCpiInfo(),
        a.multisig.toCpiInfo(),
        a.rent_sysvar.toCpiInfo(),
        &signer_infos,
        2,
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
