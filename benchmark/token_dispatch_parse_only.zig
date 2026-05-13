//! Token dispatch variant that uses `parseAccountsUnchecked` for account
//! parsing, but keeps raw `readIxTag` / `readIx` instruction decoding.
//! Isolates the account-parser helper overhead from ix-data binding.

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

const Tag = enum(u32) {
    transfer,
    burn,
    mint,
};

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const accs = try ctx.parseAccountsUnchecked(.{ "first", "second" });
    const tag = ctx.readIxTag(Tag);
    const amount = ctx.readIx(u64, 4);

    if (tag == .transfer) {
        accs.first.subLamports(amount);
        accs.second.addLamports(amount);
        return;
    }
    if (tag == .burn) {
        accs.first.subLamports(amount);
        accs.second.addLamports(amount);
        return;
    }
    if (tag == .mint) {
        accs.second.subLamports(amount);
        accs.first.addLamports(amount);
        return;
    }
    return error.InvalidInstructionData;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
