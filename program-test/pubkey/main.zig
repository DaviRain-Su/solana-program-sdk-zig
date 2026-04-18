const sol = @import("solana_program_sdk");

export fn entrypoint(input: [*]u8) u64 {
    _ = sol.context.Context.load(input) catch return 1;
    sol.log.log("Hello zig program");
    return 0;
}
