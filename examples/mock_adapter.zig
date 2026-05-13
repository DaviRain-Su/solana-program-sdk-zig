//! Mock-only adapter boundary for the router demo.
//!
//! This program exists only to prove that the router's dynamic CPI
//! staging reaches a real SBF execution boundary with the exact
//! staged account order and flags preserved.
//!
//! Instruction data ABI (all numeric fields little-endian):
//!   - `u8 adapter_opcode`
//!   - `u64 amount_in`
//!   - `u64 min_out`
//!   - `u8 hop_index`
//!
//! Return data ABI:
//!   - `u8 adapter_opcode`
//!   - `u64 amount_in`
//!   - `u64 amount_out`
//!   - `u64 min_out`
//!   - `u8 hop_index`
//!   - `u8 account_count`
//!   - `u8 first_flags`  (`bit0=signer`, `bit1=writable`)
//!   - `u8 second_flags` (`bit0=signer`, `bit1=writable`)
//!   - `[32]u8 first_pubkey`
//!   - `[32]u8 second_pubkey`
//!
//! If the first staged account is writable, owned by this mock
//! adapter, and has at least one data byte, the adapter increments
//! byte 0. The Rust negative tests use that as a "CPI reached this
//! hop" probe when proving downstream hops were skipped after an
//! earlier failure.

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;
pub const ID = sol.pubkey.comptimeFromBase58("7d3y2WdzxE7CfsWjkGy3WndkvZcj1EHMkzKJiFPiDecH");

const FEE_BPS_MASK: u8 = 0x7f;

fn accountFlags(info: sol.AccountInfo) u8 {
    return @as(u8, @intFromBool(info.isSigner())) |
        (@as(u8, @intFromBool(info.isWritable())) << 1);
}

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    var data_ctx = ctx.*;
    data_ctx.skipAccounts(data_ctx.remainingAccounts());

    var ix = sol.IxDataCursor.init(data_ctx.instructionDataUnchecked());
    const adapter_opcode = try ix.read(u8);
    const amount_in = try ix.read(u64);
    const min_out = try ix.read(u64);
    const hop_index = try ix.read(u8);
    try ix.expectEnd();

    const amount_out = try sol.math.amountAfterFeeBps(
        amount_in,
        @as(u64, adapter_opcode & FEE_BPS_MASK),
        .down,
    );

    var accounts = try ctx.accountCursor();
    var first: ?sol.AccountInfo = null;
    var second: ?sol.AccountInfo = null;
    var account_count: u8 = 0;

    while (accounts.remainingAccounts() > 0) {
        const info = try accounts.takeOne();
        if (account_count == 0) {
            first = info;
        } else if (account_count == 1) {
            second = info;
        }
        account_count +%= 1;
    }

    var first_key: sol.Pubkey = .{0} ** sol.PUBKEY_BYTES;
    var second_key: sol.Pubkey = .{0} ** sol.PUBKEY_BYTES;
    var first_flags: u8 = 0;
    var second_flags: u8 = 0;

    if (first) |info| {
        if (info.isWritable() and info.isOwnedByComptime(ID) and info.dataLen() > 0) {
            info.data()[0] +%= 1;
        }
        first_key = info.key().*;
        first_flags = accountFlags(info);
    }
    if (second) |info| {
        second_key = info.key().*;
        second_flags = accountFlags(info);
    }

    var buf: [93]u8 = undefined;
    var out = sol.IxDataStaging.init(buf[0..]);
    try out.writeIntLittleEndian(u8, adapter_opcode);
    try out.writeIntLittleEndian(u64, amount_in);
    try out.writeIntLittleEndian(u64, amount_out);
    try out.writeIntLittleEndian(u64, min_out);
    try out.writeIntLittleEndian(u8, hop_index);
    try out.writeIntLittleEndian(u8, account_count);
    try out.writeIntLittleEndian(u8, first_flags);
    try out.writeIntLittleEndian(u8, second_flags);
    try out.appendBytes(first_key[0..]);
    try out.appendBytes(second_key[0..]);

    sol.cpi.setReturnData(out.written());
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
