const std = @import("std");
const sol = @import("solana_program_sdk");
const spl_token_group = @import("spl_token_group");

test "consumer can import spl_token_group without private paths" {
    try std.testing.expect(@hasDecl(spl_token_group, "id"));
    try std.testing.expect(@hasDecl(spl_token_group, "instruction"));
    try std.testing.expect(@hasDecl(spl_token_group, "state"));
    try std.testing.expectEqualStrings("spl_token_group", spl_token_group.MODULE_NAME);
    try std.testing.expectEqualStrings("spl-token-group", spl_token_group.PACKAGE_NAME);
    try std.testing.expectEqualStrings("spl_token_group_interface", spl_token_group.INTERFACE_NAMESPACE);
    try std.testing.expectEqualStrings("on-chain/interface", spl_token_group.SCOPE);

    try std.testing.expect(!@hasDecl(spl_token_group, "PROGRAM_ID"));
    try std.testing.expect(!@hasDecl(spl_token_group, "processor"));
    try std.testing.expect(!@hasDecl(spl_token_group, "rpc"));
    try std.testing.expect(!@hasDecl(spl_token_group, "client"));
    try std.testing.expect(!@hasDecl(spl_token_group, "keypair"));
    try std.testing.expect(!@hasDecl(spl_token_group, "searcher"));
    try std.testing.expect(!@hasDecl(spl_token_group, "transaction"));

    const program_id: sol.Pubkey = .{0xe1} ** 32;
    const meta_key: sol.Pubkey = .{0xf1} ** 32;
    var metas = [_]sol.cpi.AccountMeta{sol.cpi.AccountMeta.signerWritable(&meta_key)};
    const data = [_]u8{ 2, 4, 6, 8 };
    const ix = spl_token_group.instruction.buildRawInstruction(&program_id, &metas, &data);
    try std.testing.expectEqual(&program_id, ix.program_id);
    try std.testing.expectEqual(@as(usize, 1), ix.accounts.len);
    try std.testing.expectEqual(@as(usize, 4), ix.data.len);
    try std.testing.expectEqual(sol.DISCRIMINATOR_LEN, spl_token_group.state.INTERFACE_DISCRIMINATOR_LEN);
}
