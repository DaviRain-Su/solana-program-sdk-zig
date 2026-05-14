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

pub const FieldInput = struct {
    tag: u8,
    key: []const u8,
};

pub const FieldCase = struct {
    label: []const u8,
    input: FieldInput,
    data: []const u8,
};

pub const InitializeCase = struct {
    label: []const u8,
    name: []const u8,
    symbol: []const u8,
    uri: []const u8,
    instruction: InstructionFixture,
};

pub const UpdateFieldCase = struct {
    label: []const u8,
    field: FieldInput,
    value: []const u8,
    instruction: InstructionFixture,
};

pub const RemoveKeyCase = struct {
    label: []const u8,
    idempotent: u8,
    key: []const u8,
    instruction: InstructionFixture,
};

pub const UpdateAuthorityCase = struct {
    label: []const u8,
    new_authority: [32]u8,
    instruction: InstructionFixture,
};

pub const EmitCase = struct {
    label: []const u8,
    start_is_some: u8,
    start: u64,
    end_is_some: u8,
    end: u64,
    instruction: InstructionFixture,
};

pub const AdditionalMetadataFixture = struct {
    key: []const u8,
    value: []const u8,
};

pub const StateCase = struct {
    label: []const u8,
    update_authority: [32]u8,
    mint: [32]u8,
    name: []const u8,
    symbol: []const u8,
    uri: []const u8,
    additional_metadata: []const AdditionalMetadataFixture,
    data: []const u8,
};

pub const Fixture = struct {
    fields: []const FieldCase,
    initialize: []const InitializeCase,
    update_field: []const UpdateFieldCase,
    remove_key: []const RemoveKeyCase,
    update_authority: []const UpdateAuthorityCase,
    emit: []const EmitCase,
    states: []const StateCase,
};

pub fn load(allocator: std.mem.Allocator) !std.json.Parsed(Fixture) {
    return std.json.parseFromSlice(
        Fixture,
        allocator,
        @embedFile("official_parity_fixture.json"),
        .{},
    );
}
