//! CPI integration test program.
//!
//! Transfers `amount` lamports from `from` (signer) to `to` via a
//! System Program CPI.
//!
//! Accounts (in order):
//!   0. from           — signer, writable
//!   1. to             — writable
//!   2. system program — read-only (required by CPI)
//!
//! Instruction data: little-endian u64 `amount` (8 bytes).

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() < 3)) {
        return error.NotEnoughAccountKeys;
    }

    const from = ctx.nextAccountUnchecked();
    const to = ctx.nextAccountUnchecked();
    const system_program = ctx.nextAccountUnchecked();

    const amount = ctx.readIx(u64, 0);

    var ix_data: [12]u8 = undefined;
    // discriminant: SystemInstruction.Transfer (2)
    @as(*align(1) u32, @ptrCast(&ix_data[0])).* = @intFromEnum(sol.system.SystemInstruction.Transfer);
    @as(*align(1) u64, @ptrCast(&ix_data[4])).* = amount;

    const metas = [_]sol.cpi.AccountMeta{
        .{ .pubkey = from.key(), .is_writable = true, .is_signer = true },
        .{ .pubkey = to.key(), .is_writable = true, .is_signer = false },
    };

    // Use the system program's key from the parsed account (lives in the
    // runtime input buffer — a valid VM address).
    const ix = sol.cpi.Instruction{
        .program_id = system_program.key(),
        .accounts = &metas,
        .data = &ix_data,
    };

    const infos = [_]sol.account.CpiAccountInfo{
        from.toCpiInfo(),
        to.toCpiInfo(),
        system_program.toCpiInfo(),
    };

    try sol.cpi.invoke(&ix, &infos);
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
