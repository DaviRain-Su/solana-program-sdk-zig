//! Raw instruction boundary helpers for `spl_token_metadata`.

const std = @import("std");
const sol = @import("solana_program_sdk");
const id = @import("id.zig");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;
pub const INTERFACE_NAMESPACE = id.INTERFACE_NAMESPACE;

/// Minimal raw instruction helper for the interface scaffold.
///
/// This stays intentionally narrow: callers supply the target program
/// id plus borrowed account-meta and data slices. The helper performs
/// no transaction assembly, signing, RPC submission, or buffer
/// ownership.
pub inline fn buildRawInstruction(
    program_id: *const Pubkey,
    accounts: []const AccountMeta,
    data: []const u8,
) Instruction {
    return Instruction.init(program_id, accounts, data);
}

fn expectMeta(
    actual: AccountMeta,
    expected_key: *const Pubkey,
    expected_writable: u8,
    expected_signer: u8,
) !void {
    try std.testing.expectEqual(expected_key, actual.pubkey);
    try std.testing.expectEqual(expected_writable, actual.is_writable);
    try std.testing.expectEqual(expected_signer, actual.is_signer);
}

test "buildRawInstruction preserves caller program id and borrowed slices" {
    const program_id_a: Pubkey = .{0x11} ** 32;
    const program_id_b: Pubkey = .{0x22} ** 32;
    const meta_a: Pubkey = .{0x33} ** 32;
    const meta_b: Pubkey = .{0x44} ** 32;

    var metas = [_]AccountMeta{
        AccountMeta.writable(&meta_a),
        AccountMeta.signer(&meta_b),
    };
    const data_a = [_]u8{ 1, 2, 3, 4 };
    const data_b = [_]u8{ 9, 8, 7 };

    const ix_a = buildRawInstruction(&program_id_a, &metas, &data_a);
    try std.testing.expectEqual(&program_id_a, ix_a.program_id);
    try std.testing.expectEqual(@intFromPtr(&metas[0]), @intFromPtr(ix_a.accounts.ptr));
    try std.testing.expectEqual(@intFromPtr(&data_a[0]), @intFromPtr(ix_a.data.ptr));
    try std.testing.expectEqual(@as(usize, 2), ix_a.accounts.len);
    try std.testing.expectEqual(@as(usize, 4), ix_a.data.len);
    try expectMeta(ix_a.accounts[0], &meta_a, 1, 0);
    try expectMeta(ix_a.accounts[1], &meta_b, 0, 1);
    try std.testing.expectEqualSlices(u8, &data_a, ix_a.data);

    const ix_b = buildRawInstruction(&program_id_b, metas[0..1], &data_b);
    try std.testing.expectEqual(&program_id_b, ix_b.program_id);
    try std.testing.expectEqual(@intFromPtr(&metas[0]), @intFromPtr(ix_b.accounts.ptr));
    try std.testing.expectEqual(@intFromPtr(&data_b[0]), @intFromPtr(ix_b.data.ptr));
    try std.testing.expectEqual(@as(usize, 1), ix_b.accounts.len);
    try std.testing.expectEqual(@as(usize, 3), ix_b.data.len);
    try expectMeta(ix_b.accounts[0], &meta_a, 1, 0);
    try std.testing.expectEqualSlices(u8, &data_b, ix_b.data);
}

test "buildRawInstruction stays raw borrowed and transaction-free" {
    const info = @typeInfo(@TypeOf(buildRawInstruction)).@"fn";
    try std.testing.expectEqual(@as(usize, 3), info.params.len);
    try std.testing.expect(info.params[0].type.? == *const Pubkey);
    try std.testing.expect(info.params[1].type.? == []const AccountMeta);
    try std.testing.expect(info.params[2].type.? == []const u8);
    try std.testing.expect(info.return_type.? == Instruction);
}

test {
    std.testing.refAllDecls(@This());
}
