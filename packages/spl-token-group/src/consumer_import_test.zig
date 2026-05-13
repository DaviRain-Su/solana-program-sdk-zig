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

test "consumer can exercise public MaybeNullPubkey helper via spl_token_group" {
    try std.testing.expect(@hasDecl(spl_token_group, "MaybeNullPubkey"));
    try std.testing.expectEqual(@as(usize, 32), spl_token_group.MaybeNullPubkey.LEN);

    const present_pubkey: sol.Pubkey = .{
        0xca, 0xfe, 0xba, 0xbe, 0x10, 0x20, 0x30, 0x40,
        0x50, 0x60, 0x70, 0x80, 0x90, 0xa0, 0xb0, 0xc0,
        0xd0, 0xe0, 0xf0, 0x0f, 0x1e, 0x2d, 0x3c, 0x4b,
        0x5a, 0x69, 0x78, 0x87, 0x96, 0xa5, 0xb4, 0xc3,
    };

    const decoded_null = try spl_token_group.MaybeNullPubkey.fromBytes(&([_]u8{0} ** 32));
    try std.testing.expect(decoded_null.isNull());
    try std.testing.expect(!decoded_null.isPresent());
    try std.testing.expectEqual(@as(?*const sol.Pubkey, null), decoded_null.presentKey());

    const decoded_present = try spl_token_group.MaybeNullPubkey.parse(&present_pubkey);
    try std.testing.expect(decoded_present.isPresent());
    try std.testing.expect(!decoded_present.isNull());
    try std.testing.expectEqualSlices(u8, &present_pubkey, decoded_present.presentKey().?[0..]);

    var out = [_]u8{0xbb} ** 40;
    const written = try decoded_present.encode(out[0..]);
    try std.testing.expectEqual(@as(usize, 32), written.len);
    try std.testing.expectEqualSlices(u8, &present_pubkey, written);
    try std.testing.expectEqual(@as(u8, 0xbb), out[32]);

    var short: [31]u8 = undefined;
    try std.testing.expectError(error.InvalidLength, spl_token_group.MaybeNullPubkey.fromBytes(short[0..]));
    try std.testing.expectError(error.BufferTooSmall, decoded_null.write(short[0..]));

    var exact_storage: [32]u8 = undefined;
    var exact_fba = std.heap.FixedBufferAllocator.init(&exact_storage);
    const owned = try decoded_present.allocBytes(exact_fba.allocator());
    try std.testing.expectEqualSlices(u8, &present_pubkey, owned);

    var undersized_storage: [31]u8 = undefined;
    var undersized_fba = std.heap.FixedBufferAllocator.init(&undersized_storage);
    try std.testing.expectError(error.OutOfMemory, decoded_present.allocBytes(undersized_fba.allocator()));
}
