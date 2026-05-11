const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Compare an account's owner against a module-scope `const` Pubkey using
// the regular pubkeyEq (i.e. with a pointer dereference for the
// expected key). This is what most user code does today.
const EXPECTED_OWNER: sol.Pubkey = sol.pubkey.comptimeFromBase58(
    "BenchPubkey11111111111111111111111111111112",
);

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const account = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;

    if (sol.pubkey.pubkeyEq(account.owner(), &EXPECTED_OWNER)) {
        return;
    } else {
        return error.InvalidArgument;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
