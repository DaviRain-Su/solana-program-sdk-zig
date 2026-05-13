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

pub const Inputs = struct {
    program_id: [32]u8,
    source: [32]u8,
    mint: [32]u8,
    destination: [32]u8,
    authority: [32]u8,
    validation: [32]u8,
    amount: u64,
    extra_account_metas: []const AccountFixture,
};

pub const Fixture = struct {
    inputs: Inputs,
    execute: InstructionFixture,
    initialize: InstructionFixture,
    update: InstructionFixture,
};

pub fn load(allocator: std.mem.Allocator) !std.json.Parsed(Fixture) {
    return std.json.parseFromSlice(
        Fixture,
        allocator,
        @embedFile("official_instruction_parity.json"),
        .{},
    );
}
