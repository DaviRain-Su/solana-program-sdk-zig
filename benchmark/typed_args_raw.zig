//! More realistic typed-args benchmark using checked raw ix-data reads.
//! This mirrors `typed_args_bind.zig` logic without `bindIxData` / `IxDataReader`.

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
    try ctx.requireIxDataLen(@sizeOf(Args));

    const tag: Tag = @enumFromInt(ctx.readIx(u32, @offsetOf(Args, "tag")));
    const amount = ctx.readIx(u64, @offsetOf(Args, "amount"));
    const fee = ctx.readIx(u64, @offsetOf(Args, "fee"));
    const bonus = ctx.readIx(u64, @offsetOf(Args, "bonus"));
    const flags = ctx.readIx(u16, @offsetOf(Args, "flags"));
    const bump = ctx.readIx(u8, @offsetOf(Args, "bump"));
    const mode = ctx.readIx(u8, @offsetOf(Args, "mode"));
    const limit = ctx.readIx(u64, @offsetOf(Args, "limit"));

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
