const std = @import("std");

pub const AccountFixture = struct {
    pubkey: [32]u8,
    is_signer: u8,
    is_writable: u8,
};

pub const InstructionFixture = struct {
    program_id: [32]u8,
    accounts: []const AccountFixture,
    data: []const u8,
};

pub const Discriminators = struct {
    initialize_group: [8]u8,
    update_group_max_size: [8]u8,
    update_group_authority: [8]u8,
    initialize_member: [8]u8,
    token_group: [8]u8,
    token_group_member: [8]u8,
};

pub const InitializeGroupCase = struct {
    label: []const u8,
    update_authority: [32]u8,
    max_size: u64,
    instruction: InstructionFixture,
};

pub const UpdateGroupMaxSizeCase = struct {
    label: []const u8,
    max_size: u64,
    instruction: InstructionFixture,
};

pub const UpdateGroupAuthorityCase = struct {
    label: []const u8,
    new_authority: [32]u8,
    instruction: InstructionFixture,
};

pub const InitializeMemberCase = struct {
    label: []const u8,
    instruction: InstructionFixture,
};

pub const TokenGroupCase = struct {
    label: []const u8,
    update_authority: [32]u8,
    mint: [32]u8,
    size: u64,
    max_size: u64,
    data: []const u8,
};

pub const TokenGroupMemberCase = struct {
    label: []const u8,
    mint: [32]u8,
    group: [32]u8,
    member_number: u64,
    data: []const u8,
};

pub const Fixture = struct {
    discriminators: Discriminators,
    initialize_group: []const InitializeGroupCase,
    update_group_max_size: []const UpdateGroupMaxSizeCase,
    update_group_authority: []const UpdateGroupAuthorityCase,
    initialize_member: []const InitializeMemberCase,
    token_groups: []const TokenGroupCase,
    token_group_members: []const TokenGroupMemberCase,
};

pub fn load(allocator: std.mem.Allocator) !std.json.Parsed(Fixture) {
    return std.json.parseFromSlice(
        Fixture,
        allocator,
        @embedFile("official_parity_fixture.json"),
        .{},
    );
}
