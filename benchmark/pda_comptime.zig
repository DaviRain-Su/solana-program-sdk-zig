const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Compile-time-derived PDA — no syscall, just two `[32]u8` constants.
const VAULT = sol.pda.comptimeFindProgramAddress(
    .{"vault"},
    @as(sol.Pubkey, .{0} ** 32), // System Program for comparison only
);

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    _ = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;

    // Pretend we use the PDA — store the bump somewhere observable
    // so the optimizer can't drop it.
    if (VAULT.bump_seed == 0) return error.InvalidArgument;
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
