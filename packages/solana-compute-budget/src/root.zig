//! `solana_compute_budget` — Compute Budget instruction builders.

const std = @import("std");
const sol = @import("solana_program_sdk");

pub const Pubkey = sol.Pubkey;
pub const Instruction = sol.cpi.Instruction;
pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("ComputeBudget111111111111111111111111111111");

pub const InstructionTag = enum(u8) {
    unused = 0,
    request_heap_frame = 1,
    set_compute_unit_limit = 2,
    set_compute_unit_price = 3,
    set_loaded_accounts_data_size_limit = 4,
};

pub const REQUEST_HEAP_FRAME_DATA_LEN: usize = 1 + @sizeOf(u32);
pub const SET_COMPUTE_UNIT_LIMIT_DATA_LEN: usize = 1 + @sizeOf(u32);
pub const SET_COMPUTE_UNIT_PRICE_DATA_LEN: usize = 1 + @sizeOf(u64);
pub const SET_LOADED_ACCOUNTS_DATA_SIZE_LIMIT_LEN: usize = 1 + @sizeOf(u32);

pub const RequestHeapFrameData = [REQUEST_HEAP_FRAME_DATA_LEN]u8;
pub const SetComputeUnitLimitData = [SET_COMPUTE_UNIT_LIMIT_DATA_LEN]u8;
pub const SetComputeUnitPriceData = [SET_COMPUTE_UNIT_PRICE_DATA_LEN]u8;
pub const SetLoadedAccountsDataSizeLimitData = [SET_LOADED_ACCOUNTS_DATA_SIZE_LIMIT_LEN]u8;

pub fn requestHeapFrame(bytes: u32, data: *RequestHeapFrameData) Instruction {
    writeU32(.request_heap_frame, bytes, data);
    return noAccounts(data);
}

pub fn setComputeUnitLimit(units: u32, data: *SetComputeUnitLimitData) Instruction {
    writeU32(.set_compute_unit_limit, units, data);
    return noAccounts(data);
}

pub fn setComputeUnitPrice(micro_lamports: u64, data: *SetComputeUnitPriceData) Instruction {
    data[0] = @intFromEnum(InstructionTag.set_compute_unit_price);
    std.mem.writeInt(u64, data[1..9], micro_lamports, .little);
    return noAccounts(data);
}

pub fn setLoadedAccountsDataSizeLimit(bytes: u32, data: *SetLoadedAccountsDataSizeLimitData) Instruction {
    writeU32(.set_loaded_accounts_data_size_limit, bytes, data);
    return noAccounts(data);
}

fn writeU32(tag: InstructionTag, value: u32, data: []u8) void {
    std.debug.assert(data.len == 1 + @sizeOf(u32));
    data[0] = @intFromEnum(tag);
    std.mem.writeInt(u32, data[1..5], value, .little);
}

fn noAccounts(data: []const u8) Instruction {
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = &.{},
        .data = data,
    };
}

test "setComputeUnitLimit builds canonical instruction data" {
    var data: SetComputeUnitLimitData = undefined;
    const ix = setComputeUnitLimit(1_400_000, &data);

    try std.testing.expectEqualSlices(u8, &PROGRAM_ID, ix.program_id);
    try std.testing.expectEqual(@as(usize, 0), ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &.{ 2, 0xc0, 0x5c, 0x15, 0x00 }, ix.data);
}

test "setComputeUnitPrice builds canonical instruction data" {
    var data: SetComputeUnitPriceData = undefined;
    const ix = setComputeUnitPrice(5_000, &data);

    try std.testing.expectEqual(@as(usize, 0), ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &.{ 3, 0x88, 0x13, 0, 0, 0, 0, 0, 0 }, ix.data);
}

test "requestHeapFrame and setLoadedAccountsDataSizeLimit encode u32 payloads" {
    var heap_data: RequestHeapFrameData = undefined;
    const heap_ix = requestHeapFrame(32 * 1024, &heap_data);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0x80, 0, 0 }, heap_ix.data);

    var loaded_data: SetLoadedAccountsDataSizeLimitData = undefined;
    const loaded_ix = setLoadedAccountsDataSizeLimit(64 * 1024, &loaded_data);
    try std.testing.expectEqualSlices(u8, &.{ 4, 0, 0, 1, 0 }, loaded_ix.data);
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "PROGRAM_ID"));
    try std.testing.expect(@hasDecl(@This(), "setComputeUnitLimit"));
    try std.testing.expect(@hasDecl(@This(), "setComputeUnitPrice"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
}
