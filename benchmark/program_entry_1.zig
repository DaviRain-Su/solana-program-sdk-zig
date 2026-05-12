const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// Counterpart to parse_accounts.zig — same business logic (read 1
// account, succeed) but via the `programEntrypoint` eager-parse path.
// Single-account form so it shares the `run_simple_primitive` harness
// with the other 1-account benchmarks. Compare against a paired
// `program_entry_lazy_1` to isolate the entrypoint-path delta.
fn process(
    accounts: *const [1]sol.AccountInfo,
    _: []const u8,
    _: *const sol.Pubkey,
) sol.ProgramResult {
    // Force a use of the parsed account so the compiler doesn't fold
    // the parse away.
    if (accounts[0].isSigner()) return error.InvalidArgument;
    return;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.programEntrypoint(1, process)(input);
}
