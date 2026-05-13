const std = @import("std");
const sol = @import("solana_program_sdk");
const spl_token_metadata = @import("spl_token_metadata");
const spl_token_group = @import("spl_token_group");

test "consumer can import metadata and group together without collisions" {
    try std.testing.expectEqualStrings("spl_token_metadata", spl_token_metadata.MODULE_NAME);
    try std.testing.expectEqualStrings("spl_token_group", spl_token_group.MODULE_NAME);
    try std.testing.expect(!std.mem.eql(u8, spl_token_metadata.MODULE_NAME, spl_token_group.MODULE_NAME));

    try std.testing.expect(@hasDecl(spl_token_metadata, "instruction"));
    try std.testing.expect(@hasDecl(spl_token_group, "instruction"));
    try std.testing.expect(@hasDecl(spl_token_metadata, "state"));
    try std.testing.expect(@hasDecl(spl_token_group, "state"));

    try std.testing.expect(!@hasDecl(spl_token_metadata, "PROGRAM_ID"));
    try std.testing.expect(!@hasDecl(spl_token_group, "PROGRAM_ID"));
    try std.testing.expect(!@hasDecl(spl_token_metadata, "transaction"));
    try std.testing.expect(!@hasDecl(spl_token_group, "transaction"));

    const metadata_program_id: sol.Pubkey = .{0xb1} ** 32;
    const group_program_id: sol.Pubkey = .{0xc1} ** 32;
    const shared_key: sol.Pubkey = .{0xd1} ** 32;
    var metadata_metas = [_]sol.cpi.AccountMeta{sol.cpi.AccountMeta.writable(&shared_key)};
    var group_metas = [_]sol.cpi.AccountMeta{sol.cpi.AccountMeta.signer(&shared_key)};
    const metadata_data = [_]u8{ 1, 3, 3, 7 };
    const group_data = [_]u8{ 4, 2 };

    const metadata_ix = spl_token_metadata.instruction.buildRawInstruction(
        &metadata_program_id,
        &metadata_metas,
        &metadata_data,
    );
    const group_ix = spl_token_group.instruction.buildRawInstruction(
        &group_program_id,
        &group_metas,
        &group_data,
    );
    try std.testing.expectEqual(&metadata_program_id, metadata_ix.program_id);
    try std.testing.expectEqual(&group_program_id, group_ix.program_id);
    try std.testing.expectEqual(sol.DISCRIMINATOR_LEN, spl_token_metadata.state.INTERFACE_DISCRIMINATOR_LEN);
    try std.testing.expectEqual(sol.DISCRIMINATOR_LEN, spl_token_group.state.INTERFACE_DISCRIMINATOR_LEN);
}
