const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const accs = try ctx.parseAccountsUnchecked(.{"sysvar_account"});
    const es = try sol.sysvar.getSysvar(sol.sysvar.EpochSchedule, accs.sysvar_account);
    if (es.warmup) return error.InvalidArgument;
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
