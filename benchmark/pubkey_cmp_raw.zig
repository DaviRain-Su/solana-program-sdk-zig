const sol = @import("solana_program_sdk");

export fn entrypoint(input: [*]u8) u64 {
    const key_ptr: *const sol.Pubkey = @ptrCast(@alignCast(input + 16));
    const owner_ptr: *const sol.Pubkey = @ptrCast(@alignCast(input + 16 + 32));
    if (sol.pubkey.pubkeyEqAligned(key_ptr, owner_ptr)) {
        return 0;
    } else {
        return 1;
    }
}
