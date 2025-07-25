const std = @import("std");
const sol = @import("solana");

// Process instruction handler
fn processInstruction(
    program_id: *const sol.Pubkey,
    accounts: []const sol.AccountInfo,
    instruction_data: []const u8,
) !void {
    _ = program_id;
    _ = accounts;
    _ = instruction_data;
    
    sol.log.log("Hello, Solana from Zig!");
}

// Direct entrypoint export (following joncinque's pattern)
export fn entrypoint(input: [*]u8) u64 {
    const context = sol.Context.load(input) catch return 1;
    
    processInstruction(context.program_id, context.accounts, context.instruction_data) catch |err| {
        _ = err;
        return 1;
    };
    
    return 0;
}