const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn processInstruction(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    _ = ctx;
    sol.log.log("Hello zig program");
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(processInstruction)(input);
}
