const sol = @import("solana_program_sdk");
const spl_token = @import("spl_token");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const a = try ctx.parseAccountsUnchecked(.{
        "token_program",
        "source",
        "mint",
        "destination",
        "authority",
    });

    var child_a_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_a_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_a = spl_token.instruction.transferChecked(
        a.source.key(),
        a.mint.key(),
        a.destination.key(),
        a.authority.key(),
        11,
        6,
        &child_a_metas,
        &child_a_data,
    );

    var child_b_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_b_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_b = spl_token.instruction.transferChecked(
        a.source.key(),
        a.mint.key(),
        a.destination.key(),
        a.authority.key(),
        22,
        6,
        &child_b_metas,
        &child_b_data,
    );

    const entries = [_]spl_token.instruction.BatchEntry{
        spl_token.instruction.asBatchEntry(child_a),
        spl_token.instruction.asBatchEntry(child_b),
    };
    var batch_metas: [spl_token.instruction.transfer_checked_spec.accounts_len * entries.len]sol.cpi.AccountMeta = undefined;
    var batch_data: [1 + entries.len * (2 + spl_token.instruction.transfer_checked_spec.data_len)]u8 = undefined;
    var invoke_accounts: [spl_token.instruction.transfer_checked_spec.accounts_len * entries.len + 1]sol.CpiAccountInfo = undefined;

    try spl_token.cpi.batch(
        a.token_program.toCpiInfo(),
        &entries,
        &.{
            a.source.toCpiInfo(),
            a.mint.toCpiInfo(),
            a.destination.toCpiInfo(),
            a.authority.toCpiInfo(),
            a.source.toCpiInfo(),
            a.mint.toCpiInfo(),
            a.destination.toCpiInfo(),
            a.authority.toCpiInfo(),
        },
        invoke_accounts[0..],
        batch_metas[0..],
        batch_data[0..],
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
