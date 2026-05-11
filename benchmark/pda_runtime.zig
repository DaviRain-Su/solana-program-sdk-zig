const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Find a PDA at runtime via sol_try_find_program_address.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    _ = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;

    // Use a fixed program id and seed so the result is deterministic
    // and matches pda_comptime.zig's reference.
    const program_id: sol.Pubkey = .{0} ** 32; // System Program for now
    const pda = try sol.pda.findProgramAddress(&.{"vault"}, &program_id);
    _ = pda;
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
