const std = @import("std");
const sol = @import("solana_program_sdk");
const spl_token_2022 = @import("spl_token_2022");
const spl_token_metadata = @import("spl_token_metadata");
const spl_token_group = @import("spl_token_group");

const MetadataAdditional = spl_token_metadata.state.AdditionalMetadata;
const MetadataMaybeNull = spl_token_metadata.MaybeNullPubkey;
const TokenMetadata = spl_token_metadata.state.TokenMetadata;
const GroupMaybeNull = spl_token_group.MaybeNullPubkey;
const TokenGroup = spl_token_group.state.TokenGroup;
const TokenGroupMember = spl_token_group.state.TokenGroupMember;

fn writeRecord(dst: []u8, extension_type: u16, value: []const u8) usize {
    std.mem.writeInt(u16, dst[0..2], extension_type, .little);
    std.mem.writeInt(u16, dst[2..4], @intCast(value.len), .little);
    @memcpy(dst[4 .. 4 + value.len], value);
    return 4 + value.len;
}

fn fillPubkey(base: u8) sol.Pubkey {
    var pubkey: sol.Pubkey = undefined;
    for (pubkey[0..], 0..) |*byte, i| {
        byte.* = base +% @as(u8, @intCast(i * 7));
    }
    return pubkey;
}

fn writeMaybeNullPair(
    comptime MaybeNullType: type,
    first: MaybeNullType,
    second: MaybeNullType,
    out: []u8,
) ![]const u8 {
    try std.testing.expectEqual(@as(usize, 64), out.len);
    _ = try first.write(out[0..32]);
    _ = try second.write(out[32..64]);
    return out[0..64];
}

fn writeTokenGroupBody(
    update_authority: GroupMaybeNull,
    mint: *const sol.Pubkey,
    size: u64,
    max_size: u64,
    out: []u8,
) ![]const u8 {
    try std.testing.expectEqual(TokenGroup.BODY_LEN, out.len);
    _ = try update_authority.write(out[0..32]);
    @memcpy(out[32..64], mint[0..]);
    std.mem.writeInt(u64, out[64..72], size, .little);
    std.mem.writeInt(u64, out[72..80], max_size, .little);
    return out[0..TokenGroup.BODY_LEN];
}

fn writeTokenGroupMemberBody(
    mint: *const sol.Pubkey,
    group: *const sol.Pubkey,
    member_number: u64,
    out: []u8,
) []const u8 {
    std.debug.assert(out.len == TokenGroupMember.BODY_LEN);
    @memcpy(out[0..32], mint[0..]);
    @memcpy(out[32..64], group[0..]);
    std.mem.writeInt(u64, out[64..72], member_number, .little);
    return out[0..TokenGroupMember.BODY_LEN];
}

fn expectMaybeNullEqual(
    comptime MaybeNullType: type,
    actual: MaybeNullType,
    expected: MaybeNullType,
) !void {
    try std.testing.expectEqual(expected.isPresent(), actual.isPresent());
    if (expected.presentKey()) |expected_key| {
        try std.testing.expectEqualSlices(u8, expected_key[0..], actual.presentKey().?[0..]);
    } else {
        try std.testing.expectEqual(@as(?*const sol.Pubkey, null), actual.presentKey());
    }
}

fn expectMetadataEqual(actual: TokenMetadata, expected: TokenMetadata) !void {
    try expectMaybeNullEqual(MetadataMaybeNull, actual.update_authority, expected.update_authority);
    try std.testing.expectEqualSlices(u8, expected.mint[0..], actual.mint[0..]);
    try std.testing.expectEqualStrings(expected.name, actual.name);
    try std.testing.expectEqualStrings(expected.symbol, actual.symbol);
    try std.testing.expectEqualStrings(expected.uri, actual.uri);
    try std.testing.expectEqual(expected.additional_metadata.len, actual.additional_metadata.len);
    for (expected.additional_metadata, actual.additional_metadata) |expected_entry, actual_entry| {
        try std.testing.expectEqualStrings(expected_entry.key, actual_entry.key);
        try std.testing.expectEqualStrings(expected_entry.value, actual_entry.value);
    }
}

test "metadata and group packages compose with spl_token_2022 without forbidden off-chain expansion" {
    try std.testing.expectEqual(@as(u16, 18), @intFromEnum(spl_token_2022.ExtensionType.metadata_pointer));
    try std.testing.expectEqual(@as(u16, 19), @intFromEnum(spl_token_2022.ExtensionType.token_metadata));
    try std.testing.expectEqual(@as(u16, 20), @intFromEnum(spl_token_2022.ExtensionType.group_pointer));
    try std.testing.expectEqual(@as(u16, 21), @intFromEnum(spl_token_2022.ExtensionType.token_group));
    try std.testing.expectEqual(@as(u16, 22), @intFromEnum(spl_token_2022.ExtensionType.group_member_pointer));
    try std.testing.expectEqual(@as(u16, 23), @intFromEnum(spl_token_2022.ExtensionType.token_group_member));

    try std.testing.expect(@hasDecl(spl_token_2022, "parseMint"));
    try std.testing.expect(@hasDecl(spl_token_2022, "findMintExtension"));
    try std.testing.expect(@hasDecl(spl_token_metadata, "state"));
    try std.testing.expect(@hasDecl(spl_token_group, "state"));

    try std.testing.expect(@hasDecl(spl_token_2022, "instruction"));
    try std.testing.expect(@hasDecl(spl_token_2022, "cpi"));
    try std.testing.expect(@hasDecl(spl_token_2022.instruction, "transferChecked"));
    try std.testing.expect(!@hasDecl(spl_token_2022, "transaction"));
    try std.testing.expect(!@hasDecl(spl_token_2022, "rpc"));
    try std.testing.expect(!@hasDecl(spl_token_2022, "keypair"));
    try std.testing.expect(!@hasDecl(spl_token_metadata, "PROGRAM_ID"));
    try std.testing.expect(!@hasDecl(spl_token_metadata, "transaction"));
    try std.testing.expect(!@hasDecl(spl_token_group, "PROGRAM_ID"));
    try std.testing.expect(!@hasDecl(spl_token_group, "transaction"));
}

test "mixed Token-2022 TLV regions remain traversable for metadata and group payloads" {
    const metadata_authority = fillPubkey(0x11);
    const metadata_address = fillPubkey(0x31);
    const metadata_mint = fillPubkey(0x51);
    const group_authority = fillPubkey(0x71);
    const group_address = fillPubkey(0x91);
    const member_address = fillPubkey(0xb1);
    const hook_authority = fillPubkey(0xc1);
    const hook_program_id = fillPubkey(0xd1);

    const metadata_state = TokenMetadata{
        .update_authority = MetadataMaybeNull.fromPubkey(&metadata_authority),
        .mint = metadata_mint,
        .name = "Metadata Group Token",
        .symbol = "MGT",
        .uri = "https://example.invalid/mgt",
        .additional_metadata = &.{
            .{ .key = "tier", .value = "gold" },
            .{ .key = "tier", .value = "duplicate-order-preserved" },
        },
    };

    var metadata_body_storage: [spl_token_metadata.state.MAX_SERIALIZED_METADATA_BODY_LEN]u8 = undefined;
    const metadata_body = try metadata_state.writeBody(metadata_body_storage[0..]);

    var metadata_pointer_payload: [64]u8 = undefined;
    _ = try writeMaybeNullPair(
        MetadataMaybeNull,
        MetadataMaybeNull.fromPubkey(&metadata_authority),
        MetadataMaybeNull.fromPubkey(&metadata_address),
        metadata_pointer_payload[0..],
    );

    var group_pointer_payload: [64]u8 = undefined;
    _ = try writeMaybeNullPair(
        GroupMaybeNull,
        GroupMaybeNull.fromPubkey(&group_authority),
        GroupMaybeNull.fromPubkey(&group_address),
        group_pointer_payload[0..],
    );

    var group_member_pointer_payload: [64]u8 = undefined;
    _ = try writeMaybeNullPair(
        GroupMaybeNull,
        GroupMaybeNull.initNull(),
        GroupMaybeNull.fromPubkey(&member_address),
        group_member_pointer_payload[0..],
    );

    var token_group_body: [TokenGroup.BODY_LEN]u8 = undefined;
    _ = try writeTokenGroupBody(
        GroupMaybeNull.fromPubkey(&group_authority),
        &metadata_mint,
        7,
        42,
        token_group_body[0..],
    );

    var token_group_member_body: [TokenGroupMember.BODY_LEN]u8 = undefined;
    _ = writeTokenGroupMemberBody(&metadata_mint, &group_address, 9, token_group_member_body[0..]);

    var transfer_hook_payload: [spl_token_2022.extension.TransferHookView.PAYLOAD_LEN]u8 = undefined;
    @memcpy(transfer_hook_payload[0..32], hook_authority[0..]);
    @memcpy(transfer_hook_payload[32..64], hook_program_id[0..]);

    var mint = [_]u8{0} ** 1024;
    mint[spl_token_2022.ACCOUNT_TYPE_OFFSET] = @intFromEnum(spl_token_2022.AccountType.mint);

    var offset: usize = spl_token_2022.TLV_START_OFFSET;
    offset += writeRecord(mint[offset..], @intFromEnum(spl_token_2022.ExtensionType.metadata_pointer), metadata_pointer_payload[0..]);
    offset += writeRecord(mint[offset..], 0xfffe, "???");
    offset += writeRecord(mint[offset..], @intFromEnum(spl_token_2022.ExtensionType.token_metadata), metadata_body);
    offset += writeRecord(mint[offset..], @intFromEnum(spl_token_2022.ExtensionType.transfer_hook), transfer_hook_payload[0..]);
    offset += writeRecord(mint[offset..], @intFromEnum(spl_token_2022.ExtensionType.group_pointer), group_pointer_payload[0..]);
    offset += writeRecord(mint[offset..], @intFromEnum(spl_token_2022.ExtensionType.token_group), token_group_body[0..]);
    offset += writeRecord(mint[offset..], @intFromEnum(spl_token_2022.ExtensionType.group_member_pointer), group_member_pointer_payload[0..]);
    offset += writeRecord(mint[offset..], @intFromEnum(spl_token_2022.ExtensionType.token_group_member), token_group_member_body[0..]);

    const before = mint;
    const parsed_mint = try spl_token_2022.parseMint(mint[0..offset]);

    var seen_types: [8]u16 = undefined;
    var count: usize = 0;
    var iterator = parsed_mint.iterator();
    while (try iterator.next()) |record| {
        seen_types[count] = record.extension_type;
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 8), count);
    try std.testing.expectEqual(@as(u16, 18), seen_types[0]);
    try std.testing.expectEqual(@as(u16, 0xfffe), seen_types[1]);
    try std.testing.expectEqual(@as(u16, 19), seen_types[2]);
    try std.testing.expectEqual(@as(u16, 14), seen_types[3]);
    try std.testing.expectEqual(@as(u16, 20), seen_types[4]);
    try std.testing.expectEqual(@as(u16, 21), seen_types[5]);
    try std.testing.expectEqual(@as(u16, 22), seen_types[6]);
    try std.testing.expectEqual(@as(u16, 23), seen_types[7]);

    const metadata_pointer_record = try parsed_mint.findExtension(@intFromEnum(spl_token_2022.ExtensionType.metadata_pointer));
    try std.testing.expectEqual(@as(usize, 64), metadata_pointer_record.value.len);
    const metadata_pointer_authority = try MetadataMaybeNull.parse(metadata_pointer_record.value[0..32]);
    const metadata_pointer_target = try MetadataMaybeNull.parse(metadata_pointer_record.value[32..64]);
    try expectMaybeNullEqual(MetadataMaybeNull, metadata_pointer_authority, MetadataMaybeNull.fromPubkey(&metadata_authority));
    try expectMaybeNullEqual(MetadataMaybeNull, metadata_pointer_target, MetadataMaybeNull.fromPubkey(&metadata_address));

    var parsed_pairs: [2]MetadataAdditional = undefined;
    const metadata_record = try spl_token_2022.findMintExtension(
        mint[0..offset],
        @intFromEnum(spl_token_2022.ExtensionType.token_metadata),
    );
    const parsed_metadata = try TokenMetadata.parseBody(metadata_record.value, parsed_pairs[0..]);
    try expectMetadataEqual(parsed_metadata, metadata_state);

    var helper_pairs: [2]MetadataAdditional = undefined;
    const helper_metadata = try spl_token_2022.parseTokenMetadata(parsed_mint, helper_pairs[0..]);
    try expectMetadataEqual(helper_metadata, metadata_state);

    const hook_record = try parsed_mint.findExtension(@intFromEnum(spl_token_2022.ExtensionType.transfer_hook));
    const hook_view = try spl_token_2022.extension.TransferHookView.fromBytes(hook_record.value);
    try std.testing.expectEqualSlices(u8, hook_authority[0..], hook_view.authority[0..]);
    try std.testing.expectEqualSlices(u8, hook_program_id[0..], hook_view.program_id[0..]);

    const group_pointer_record = try parsed_mint.findExtension(@intFromEnum(spl_token_2022.ExtensionType.group_pointer));
    try std.testing.expectEqual(@as(usize, 64), group_pointer_record.value.len);
    const parsed_group_pointer_authority = try GroupMaybeNull.parse(group_pointer_record.value[0..32]);
    const parsed_group_pointer_target = try GroupMaybeNull.parse(group_pointer_record.value[32..64]);
    try expectMaybeNullEqual(GroupMaybeNull, parsed_group_pointer_authority, GroupMaybeNull.fromPubkey(&group_authority));
    try expectMaybeNullEqual(GroupMaybeNull, parsed_group_pointer_target, GroupMaybeNull.fromPubkey(&group_address));

    const group_record = try parsed_mint.findExtension(@intFromEnum(spl_token_2022.ExtensionType.token_group));
    const parsed_group = try TokenGroup.parseBody(group_record.value);
    const helper_group = try spl_token_2022.parseTokenGroupMint(mint[0..offset]);
    try expectMaybeNullEqual(GroupMaybeNull, parsed_group.update_authority, GroupMaybeNull.fromPubkey(&group_authority));
    try expectMaybeNullEqual(GroupMaybeNull, helper_group.update_authority, GroupMaybeNull.fromPubkey(&group_authority));
    try std.testing.expectEqualSlices(u8, metadata_mint[0..], parsed_group.mint[0..]);
    try std.testing.expectEqualSlices(u8, metadata_mint[0..], helper_group.mint[0..]);
    try std.testing.expectEqual(@as(u64, 7), parsed_group.size);
    try std.testing.expectEqual(@as(u64, 7), helper_group.size);
    try std.testing.expectEqual(@as(u64, 42), parsed_group.max_size);
    try std.testing.expectEqual(@as(u64, 42), helper_group.max_size);

    const member_pointer_record = try parsed_mint.findExtension(@intFromEnum(spl_token_2022.ExtensionType.group_member_pointer));
    try std.testing.expectEqual(@as(usize, 64), member_pointer_record.value.len);
    const parsed_member_pointer_authority = try GroupMaybeNull.parse(member_pointer_record.value[0..32]);
    const parsed_member_pointer_target = try GroupMaybeNull.parse(member_pointer_record.value[32..64]);
    try expectMaybeNullEqual(GroupMaybeNull, parsed_member_pointer_authority, GroupMaybeNull.initNull());
    try expectMaybeNullEqual(GroupMaybeNull, parsed_member_pointer_target, GroupMaybeNull.fromPubkey(&member_address));

    const member_record = try parsed_mint.findExtension(@intFromEnum(spl_token_2022.ExtensionType.token_group_member));
    const parsed_member = try TokenGroupMember.parseBody(member_record.value);
    const helper_member = try spl_token_2022.parseTokenGroupMember(parsed_mint);
    try std.testing.expectEqualSlices(u8, metadata_mint[0..], parsed_member.mint[0..]);
    try std.testing.expectEqualSlices(u8, metadata_mint[0..], helper_member.mint[0..]);
    try std.testing.expectEqualSlices(u8, group_address[0..], parsed_member.group[0..]);
    try std.testing.expectEqualSlices(u8, group_address[0..], helper_member.group[0..]);
    try std.testing.expectEqual(@as(u64, 9), parsed_member.member_number);
    try std.testing.expectEqual(@as(u64, 9), helper_member.member_number);

    try std.testing.expectEqualSlices(u8, before[0..offset], mint[0..offset]);
}

test "metadata and group parsers keep error mapping deterministic without mutating TLV payloads" {
    var oversized_name_body = [_]u8{0} ** (MetadataMaybeNull.LEN + @sizeOf(sol.Pubkey) + 4);
    std.mem.writeInt(u32, oversized_name_body[64..68], spl_token_metadata.state.MAX_STRING_LEN + 1, .little);
    const oversized_name_before = oversized_name_body;
    var no_pairs: [0]MetadataAdditional = .{};
    try std.testing.expectError(
        error.BoundsExceeded,
        TokenMetadata.parseBody(oversized_name_body[0..], no_pairs[0..]),
    );
    try std.testing.expectEqualSlices(u8, oversized_name_before[0..], oversized_name_body[0..]);

    var pair_count_without_storage = [_]u8{0} ** (MetadataMaybeNull.LEN + @sizeOf(sol.Pubkey) + 4 + 4 + 4 + 4);
    std.mem.writeInt(u32, pair_count_without_storage[64..68], 0, .little);
    std.mem.writeInt(u32, pair_count_without_storage[68..72], 0, .little);
    std.mem.writeInt(u32, pair_count_without_storage[72..76], 0, .little);
    std.mem.writeInt(u32, pair_count_without_storage[76..80], 1, .little);
    const pair_count_before = pair_count_without_storage;
    try std.testing.expectError(
        error.BufferTooSmall,
        TokenMetadata.parseBody(pair_count_without_storage[0..], no_pairs[0..]),
    );
    try std.testing.expectEqualSlices(u8, pair_count_before[0..], pair_count_without_storage[0..]);

    var truncated_group_body = [_]u8{0} ** (TokenGroup.BODY_LEN - 1);
    const truncated_group_before = truncated_group_body;
    try std.testing.expectError(error.InvalidAccountData, TokenGroup.parseBody(truncated_group_body[0..]));
    try std.testing.expectEqualSlices(u8, truncated_group_before[0..], truncated_group_body[0..]);

    var wrong_member_payload: [TokenGroupMember.PACKED_LEN]u8 = undefined;
    @memcpy(wrong_member_payload[0..spl_token_group.state.INTERFACE_DISCRIMINATOR_LEN], &spl_token_group.state.TOKEN_GROUP_DISCRIMINATOR);
    @memset(wrong_member_payload[spl_token_group.state.INTERFACE_DISCRIMINATOR_LEN..], 0);
    const wrong_member_before = wrong_member_payload;
    try std.testing.expectError(error.InvalidAccountData, TokenGroupMember.parse(wrong_member_payload[0..]));
    try std.testing.expectEqualSlices(u8, wrong_member_before[0..], wrong_member_payload[0..]);
}
