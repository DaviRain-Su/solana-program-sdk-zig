const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Compare an account's owner against TWO compile-time-known pubkeys
// (e.g. the SPL Token / Token-2022 case). Each pubkeyEqComptime is
// the xor-or 4×u64-immediate shape; pubkeyEqAny unrolls and short-
// circuits on the first match. We use the SDK's well-known program
// IDs so this benchmark mirrors realistic call-site code.
fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const account = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;

    if (account.isOwnedByAny(&.{
        sol.spl_token_program_id,
        sol.spl_token_2022_program_id,
    })) {
        return;
    } else {
        return error.InvalidArgument;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
