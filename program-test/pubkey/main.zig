const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn processInstruction(context: *sol.entrypoint.InstructionContext(1)) sol.ProgramResult {
    _ = context;
    sol.log.log("Hello zig program");
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sol.entrypoint.lazyEntrypointMax(1, processInstruction), .{input});
}
