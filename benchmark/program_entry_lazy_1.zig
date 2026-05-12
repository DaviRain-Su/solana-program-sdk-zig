const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Paired with program_entry_1.zig — same business logic (read 1
// account, check signer flag, return) but via `lazyEntrypoint` +
// `parseAccountsUnchecked`. The delta vs. program_entry_1 isolates
// the entrypoint-path cost.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const a = try ctx.parseAccountsUnchecked(.{"only"});
    if (a.only.isSigner()) return error.InvalidArgument;
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
