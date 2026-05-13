//! Token dispatch variant that uses manual unchecked account iteration,
//! but validates and binds ix-data through `bindIxDataUnchecked`.
//! Isolates the ix-data helper overhead from account parsing.

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

const Tag = enum(u32) {
    transfer,
    burn,
    mint,
};

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() < 2)) {
        return error.NotEnoughAccountKeys;
    }
    const first = ctx.nextAccountUnchecked();
    const second = ctx.nextAccountUnchecked();

    const Args = extern struct {
        tag: u32 align(1),
        amount: u64 align(1),
    };
    const args = try ctx.bindIxDataUnchecked(Args);
    const tag: Tag = @enumFromInt(args.get(.tag));
    const amount = args.get(.amount);

    if (tag == .transfer) {
        first.subLamports(amount);
        second.addLamports(amount);
        return;
    }
    if (tag == .burn) {
        first.subLamports(amount);
        second.addLamports(amount);
        return;
    }
    if (tag == .mint) {
        second.subLamports(amount);
        first.addLamports(amount);
        return;
    }
    return error.InvalidInstructionData;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
