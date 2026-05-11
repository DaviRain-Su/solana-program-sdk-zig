const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn processInstruction(context: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    _ = context;
    sol.log.log("Hello from the hello-world template");
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sol.entrypoint.lazyEntrypoint(processInstruction), .{input});
}
