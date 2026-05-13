const std = @import("std");

pub const AccountKeyDataFixture = struct {
    key: [32]u8,
    data: ?[]const u8,
};

pub const MetaFixture = struct {
    discriminator: u8,
    address_config: [32]u8,
    is_signer: u8,
    is_writable: u8,
};

pub const ResolvedFixture = struct {
    pubkey: [32]u8,
    is_signer: u8,
    is_writable: u8,
};

pub const CaseFixture = struct {
    name: []const u8,
    meta: MetaFixture,
    resolved: ResolvedFixture,
};

pub const Fixture = struct {
    hook_program_id: [32]u8,
    instruction_data: []const u8,
    base_accounts: []const AccountKeyDataFixture,
    cases: []const CaseFixture,
};

pub fn load(allocator: std.mem.Allocator) !std.json.Parsed(Fixture) {
    return std.json.parseFromSlice(
        Fixture,
        allocator,
        @embedFile("official_account_resolution_parity.json"),
        .{},
    );
}
