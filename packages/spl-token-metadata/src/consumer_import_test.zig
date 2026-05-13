const std = @import("std");
const sol = @import("solana_program_sdk");
const spl_token_metadata = @import("spl_token_metadata");

test "consumer can import spl_token_metadata without private paths" {
    try std.testing.expect(@hasDecl(spl_token_metadata, "id"));
    try std.testing.expect(@hasDecl(spl_token_metadata, "instruction"));
    try std.testing.expect(@hasDecl(spl_token_metadata, "state"));
    try std.testing.expectEqualStrings("spl_token_metadata", spl_token_metadata.MODULE_NAME);
    try std.testing.expectEqualStrings("spl-token-metadata", spl_token_metadata.PACKAGE_NAME);
    try std.testing.expectEqualStrings("spl_token_metadata_interface", spl_token_metadata.INTERFACE_NAMESPACE);
    try std.testing.expectEqualStrings("on-chain/interface", spl_token_metadata.SCOPE);

    try std.testing.expect(!@hasDecl(spl_token_metadata, "PROGRAM_ID"));
    try std.testing.expect(!@hasDecl(spl_token_metadata, "processor"));
    try std.testing.expect(!@hasDecl(spl_token_metadata, "rpc"));
    try std.testing.expect(!@hasDecl(spl_token_metadata, "client"));
    try std.testing.expect(!@hasDecl(spl_token_metadata, "keypair"));
    try std.testing.expect(!@hasDecl(spl_token_metadata, "searcher"));
    try std.testing.expect(!@hasDecl(spl_token_metadata, "transaction"));

    const program_id: sol.Pubkey = .{0x91} ** 32;
    const meta_key: sol.Pubkey = .{0xa1} ** 32;
    var metas = [_]sol.cpi.AccountMeta{sol.cpi.AccountMeta.readonly(&meta_key)};
    const data = [_]u8{ 7, 7, 7 };
    const ix = spl_token_metadata.instruction.buildRawInstruction(&program_id, &metas, &data);
    try std.testing.expectEqual(&program_id, ix.program_id);
    try std.testing.expectEqual(@as(usize, 1), ix.accounts.len);
    try std.testing.expectEqual(@as(usize, 3), ix.data.len);
    try std.testing.expectEqual(sol.DISCRIMINATOR_LEN, spl_token_metadata.state.INTERFACE_DISCRIMINATOR_LEN);
}
