//! More realistic typed-args benchmark using `bindIxData` + `IxDataReader`.
//! Exercises a wider payload and multiple field accesses so we can see
//! whether typed binding overhead shows up outside the tiny token-dispatch case.

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

const Tag = enum(u32) {
    transfer,
    rebate,
    settle,
};

const Args = extern struct {
    tag: u32 align(1),
    amount: u64 align(1),
    fee: u64 align(1),
    bonus: u64 align(1),
    flags: u16 align(1),
    bump: u8,
    mode: u8,
    limit: u64 align(1),
};

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const accs = try ctx.parseAccountsUnchecked(.{ "source", "destination" });
    const args = try ctx.bindIxData(Args);

    const tag: Tag = @enumFromInt(args.get(.tag));
    const amount = args.get(.amount);
    const fee = args.get(.fee);
    const bonus = args.get(.bonus);
    const flags = args.get(.flags);
    const bump = args.get(.bump);
    const mode = args.get(.mode);
    const limit = args.get(.limit);

    var delta = amount;
    if ((flags & 0x1) != 0) delta += bonus;
    if ((flags & 0x2) != 0) delta -= bonus;
    if (mode == 1) delta += fee;

    if (tag == .rebate) delta -= fee;
    if (tag == .settle and bump == 9) delta += 1;
    if (limit < delta) return error.InvalidInstructionData;

    accs.source.subLamports(delta);
    accs.destination.addLamports(delta);
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
