const std = @import("std");
const sol = @import("solana_program_sdk");
const parity_fixture = @import("parity_fixture.zig");
const instruction = @import("instruction.zig");
const state = @import("state.zig");

const MaybeNullPubkey = instruction.MaybeNullPubkey;
const Pubkey = instruction.Pubkey;
const AccountMeta = instruction.AccountMeta;
const Instruction = instruction.Instruction;
const TokenGroupInstruction = instruction.TokenGroupInstruction;

fn fixturePubkey(bytes: [32]u8) Pubkey {
    return bytes;
}

fn fixtureMaybeNull(bytes: [32]u8) MaybeNullPubkey {
    return MaybeNullPubkey.fromBytes(bytes[0..]) catch unreachable;
}

fn expectInstructionFixture(
    actual: Instruction,
    expected: parity_fixture.InstructionFixture,
) !void {
    try std.testing.expectEqualSlices(u8, expected.program_id[0..], actual.program_id[0..]);
    try std.testing.expectEqual(expected.accounts.len, actual.accounts.len);
    try std.testing.expectEqualSlices(u8, expected.data, actual.data);

    for (expected.accounts, actual.accounts) |expected_meta, actual_meta| {
        try std.testing.expectEqualSlices(u8, expected_meta.pubkey[0..], actual_meta.pubkey[0..]);
        try std.testing.expectEqual(expected_meta.is_signer, actual_meta.is_signer);
        try std.testing.expectEqual(expected_meta.is_writable, actual_meta.is_writable);
    }
}

fn expectMaybeNullEqual(actual: MaybeNullPubkey, expected: MaybeNullPubkey) !void {
    try std.testing.expectEqual(expected.isPresent(), actual.isPresent());
    if (expected.presentKey()) |expected_key| {
        try std.testing.expectEqualSlices(u8, expected_key[0..], actual.presentKey().?[0..]);
    } else {
        try std.testing.expect(actual.presentKey() == null);
    }
}

test "instruction discriminators are canonical" {
    const loaded = try parity_fixture.load(std.testing.allocator);
    defer loaded.deinit();

    try std.testing.expectEqualSlices(u8, &loaded.value.discriminators.initialize_group, &instruction.INITIALIZE_GROUP_DISCRIMINATOR);
    try std.testing.expectEqualSlices(u8, &loaded.value.discriminators.update_group_max_size, &instruction.UPDATE_GROUP_MAX_SIZE_DISCRIMINATOR);
    try std.testing.expectEqualSlices(u8, &loaded.value.discriminators.update_group_authority, &instruction.UPDATE_GROUP_AUTHORITY_DISCRIMINATOR);
    try std.testing.expectEqualSlices(u8, &loaded.value.discriminators.initialize_member, &instruction.INITIALIZE_MEMBER_DISCRIMINATOR);
    try std.testing.expectEqualSlices(u8, &loaded.value.discriminators.token_group, &state.TOKEN_GROUP_DISCRIMINATOR);
    try std.testing.expectEqualSlices(u8, &loaded.value.discriminators.token_group_member, &state.TOKEN_GROUP_MEMBER_DISCRIMINATOR);
}

test "official Rust parity fixture matches token-group instruction builders and parsers" {
    const loaded = try parity_fixture.load(std.testing.allocator);
    defer loaded.deinit();

    for (loaded.value.initialize_group) |case| {
        var metas: instruction.InitializeGroupMetas = undefined;
        const data = try std.testing.allocator.alloc(u8, case.instruction.data.len);
        defer std.testing.allocator.free(data);

        const group = fixturePubkey(case.instruction.accounts[0].pubkey);
        const mint = fixturePubkey(case.instruction.accounts[1].pubkey);
        const mint_authority = fixturePubkey(case.instruction.accounts[2].pubkey);
        const program_id = fixturePubkey(case.instruction.program_id);
        const update_authority = fixtureMaybeNull(case.update_authority);

        const ix = try instruction.initializeGroup(
            &program_id,
            &group,
            &mint,
            &mint_authority,
            update_authority,
            case.max_size,
            &metas,
            data,
        );
        try expectInstructionFixture(ix, case.instruction);

        const parsed = try TokenGroupInstruction.parse(case.instruction.data);
        try std.testing.expectEqual(@as(usize, case.instruction.data.len), try parsed.packedLen());
        switch (parsed) {
            .initialize_group => |value| {
                try expectMaybeNullEqual(value.update_authority, update_authority);
                try std.testing.expectEqual(case.max_size, value.max_size);
            },
            else => return error.UnexpectedValue,
        }
    }

    for (loaded.value.update_group_max_size) |case| {
        var metas: instruction.UpdateGroupMaxSizeMetas = undefined;
        const data = try std.testing.allocator.alloc(u8, case.instruction.data.len);
        defer std.testing.allocator.free(data);

        const group = fixturePubkey(case.instruction.accounts[0].pubkey);
        const update_authority = fixturePubkey(case.instruction.accounts[1].pubkey);
        const program_id = fixturePubkey(case.instruction.program_id);

        const ix = try instruction.updateGroupMaxSize(
            &program_id,
            &group,
            &update_authority,
            case.max_size,
            &metas,
            data,
        );
        try expectInstructionFixture(ix, case.instruction);

        const parsed = try TokenGroupInstruction.parse(case.instruction.data);
        switch (parsed) {
            .update_group_max_size => |value| try std.testing.expectEqual(case.max_size, value.max_size),
            else => return error.UnexpectedValue,
        }
    }

    for (loaded.value.update_group_authority) |case| {
        var metas: instruction.UpdateGroupAuthorityMetas = undefined;
        const data = try std.testing.allocator.alloc(u8, case.instruction.data.len);
        defer std.testing.allocator.free(data);

        const group = fixturePubkey(case.instruction.accounts[0].pubkey);
        const current_authority = fixturePubkey(case.instruction.accounts[1].pubkey);
        const program_id = fixturePubkey(case.instruction.program_id);
        const new_authority = fixtureMaybeNull(case.new_authority);

        const ix = try instruction.updateGroupAuthority(
            &program_id,
            &group,
            &current_authority,
            new_authority,
            &metas,
            data,
        );
        try expectInstructionFixture(ix, case.instruction);

        const parsed = try TokenGroupInstruction.parse(case.instruction.data);
        switch (parsed) {
            .update_group_authority => |value| try expectMaybeNullEqual(value.new_authority, new_authority),
            else => return error.UnexpectedValue,
        }
    }

    for (loaded.value.initialize_member) |case| {
        var metas: instruction.InitializeMemberMetas = undefined;
        const data = try std.testing.allocator.alloc(u8, case.instruction.data.len);
        defer std.testing.allocator.free(data);

        const member = fixturePubkey(case.instruction.accounts[0].pubkey);
        const member_mint = fixturePubkey(case.instruction.accounts[1].pubkey);
        const member_mint_authority = fixturePubkey(case.instruction.accounts[2].pubkey);
        const group = fixturePubkey(case.instruction.accounts[3].pubkey);
        const group_update_authority = fixturePubkey(case.instruction.accounts[4].pubkey);
        const program_id = fixturePubkey(case.instruction.program_id);

        const ix = try instruction.initializeMember(
            &program_id,
            &member,
            &member_mint,
            &member_mint_authority,
            &group,
            &group_update_authority,
            &metas,
            data,
        );
        try expectInstructionFixture(ix, case.instruction);

        const parsed = try TokenGroupInstruction.parse(case.instruction.data);
        switch (parsed) {
            .initialize_member => {},
            else => return error.UnexpectedValue,
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
