const sol = @import("solana_program_sdk");

// Direct entrypoint using eager deserialize - like rosetta zig
fn processInstruction(
    program_id: *const sol.Pubkey,
    accounts: []sol.AccountInfo,
    instruction_data: []const u8,
) sol.ProgramResult {
    _ = program_id;
    _ = instruction_data;
    
    // Log accounts length for debugging
    if (accounts.len >= 2) {
        return;
    } else if (accounts.len == 1) {
        return error.NotEnoughAccountKeys;
    } else {
        return error.NotEnoughAccountKeys;
    }
}

export fn entrypoint(input: [*]align(8) u8) u64 {
    return sol.entrypoint.entrypoint(2, processInstruction)(input);
}
