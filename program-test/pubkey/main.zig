const sol = @import("solana_program_sdk");

fn processInstruction(
    program_id: *const sol.Pubkey,
    accounts: []sol.AccountInfo,
    instruction_data: []const u8,
) sol.ProgramResult {
    _ = program_id;
    _ = accounts;
    _ = instruction_data;
    sol.log.log("Hello zig program");
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sol.entrypoint.entrypoint(10, processInstruction), .{input});
}
