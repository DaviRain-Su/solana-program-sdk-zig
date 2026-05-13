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

test "consumer can exercise public MaybeNullPubkey helper via spl_token_metadata" {
    try std.testing.expect(@hasDecl(spl_token_metadata, "MaybeNullPubkey"));
    try std.testing.expectEqual(@as(usize, 32), spl_token_metadata.MaybeNullPubkey.LEN);

    const present_pubkey: sol.Pubkey = .{
        0x10, 0x32, 0x54, 0x76, 0x98, 0xba, 0xdc, 0xfe,
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
        0xf0, 0xde, 0xbc, 0x9a, 0x78, 0x56, 0x34, 0x12,
        0x55, 0xaa, 0x11, 0x22, 0x77, 0x88, 0x99, 0xcc,
    };

    const decoded_null = try spl_token_metadata.MaybeNullPubkey.fromBytes(&([_]u8{0} ** 32));
    try std.testing.expect(decoded_null.isNull());
    try std.testing.expect(!decoded_null.isPresent());
    try std.testing.expectEqual(@as(?*const sol.Pubkey, null), decoded_null.presentKey());

    const decoded_present = try spl_token_metadata.MaybeNullPubkey.parse(&present_pubkey);
    try std.testing.expect(decoded_present.isPresent());
    try std.testing.expect(!decoded_present.isNull());
    try std.testing.expectEqualSlices(u8, &present_pubkey, decoded_present.presentKey().?[0..]);

    var out = [_]u8{0xaa} ** 40;
    const written = try decoded_present.encode(out[0..]);
    try std.testing.expectEqual(@as(usize, 32), written.len);
    try std.testing.expectEqualSlices(u8, &present_pubkey, written);
    try std.testing.expectEqual(@as(u8, 0xaa), out[32]);

    var short: [31]u8 = undefined;
    try std.testing.expectError(error.InvalidLength, spl_token_metadata.MaybeNullPubkey.fromBytes(short[0..]));
    try std.testing.expectError(error.BufferTooSmall, decoded_null.write(short[0..]));

    var exact_storage: [32]u8 = undefined;
    var exact_fba = std.heap.FixedBufferAllocator.init(&exact_storage);
    const owned = try decoded_present.allocBytes(exact_fba.allocator());
    try std.testing.expectEqualSlices(u8, &present_pubkey, owned);

    var undersized_storage: [31]u8 = undefined;
    var undersized_fba = std.heap.FixedBufferAllocator.init(&undersized_storage);
    try std.testing.expectError(error.OutOfMemory, decoded_present.allocBytes(undersized_fba.allocator()));
}
