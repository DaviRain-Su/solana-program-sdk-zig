const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn process(_: *sol.entrypoint.InstructionContext) sol.ProgramResult {}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
