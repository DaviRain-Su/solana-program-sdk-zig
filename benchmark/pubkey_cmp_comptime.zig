const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Compare an account's owner against a compile-time-known pubkey using
// pubkeyEqComptime — four `u64`-immediate compares, no rodata load for
// the expected pubkey.
const EXPECTED_OWNER = sol.pubkey.comptimeFromBase58(
    "BenchPubkey11111111111111111111111111111112",
);

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const account = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;

    if (account.isOwnedByComptime(EXPECTED_OWNER)) {
        return;
    } else {
        return error.InvalidArgument;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
