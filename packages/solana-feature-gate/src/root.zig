//! `solana_feature_gate` — Feature Program helpers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const system = @import("solana_system");

pub const Pubkey = sol.Pubkey;
pub const Instruction = sol.cpi.Instruction;
pub const AccountMeta = sol.cpi.AccountMeta;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("Feature111111111111111111111111111111111111");
pub const FEATURE_DATA_LEN: usize = 9;

pub const Error = error{
    BufferTooSmall,
    InputTooShort,
    InvalidFeatureOptionTag,
};

pub const Feature = struct {
    activated_at: ?u64,
};

pub const ActivationBuffers = struct {
    transfer_metas: *[2]system.AccountMeta,
    transfer_data: *system.TransferData,
    allocate_metas: *[1]system.AccountMeta,
    allocate_data: *system.AllocateData,
    assign_metas: *[1]system.AccountMeta,
    assign_data: *system.AssignData,
};

pub const ActivationInstructions = struct {
    instructions: [3]Instruction,

    pub fn transfer(self: *const ActivationInstructions) *const Instruction {
        return &self.instructions[0];
    }

    pub fn allocate(self: *const ActivationInstructions) *const Instruction {
        return &self.instructions[1];
    }

    pub fn assign(self: *const ActivationInstructions) *const Instruction {
        return &self.instructions[2];
    }

    pub fn slice(self: *const ActivationInstructions) []const Instruction {
        return self.instructions[0..];
    }
};

pub fn encodeFeature(feature: Feature, out: []u8) Error![]const u8 {
    if (out.len < FEATURE_DATA_LEN) return error.BufferTooSmall;
    @memset(out[0..FEATURE_DATA_LEN], 0);
    if (feature.activated_at) |slot| {
        out[0] = 1;
        std.mem.writeInt(u64, out[1..9], slot, .little);
    }
    return out[0..FEATURE_DATA_LEN];
}

pub fn decodeFeature(input: []const u8) Error!Feature {
    if (input.len < FEATURE_DATA_LEN) return error.InputTooShort;
    return switch (input[0]) {
        0 => .{ .activated_at = null },
        1 => .{ .activated_at = std.mem.readInt(u64, input[1..9], .little) },
        else => error.InvalidFeatureOptionTag,
    };
}

pub fn activateWithLamports(
    feature_id: *const Pubkey,
    funding_address: *const Pubkey,
    lamports: u64,
    buffers: ActivationBuffers,
) ActivationInstructions {
    return .{
        .instructions = .{
            system.transfer(
                funding_address,
                feature_id,
                lamports,
                buffers.transfer_metas,
                buffers.transfer_data,
            ),
            system.allocate(
                feature_id,
                FEATURE_DATA_LEN,
                buffers.allocate_metas,
                buffers.allocate_data,
            ),
            system.assign(
                feature_id,
                &PROGRAM_ID,
                buffers.assign_metas,
                buffers.assign_data,
            ),
        },
    };
}

test "feature account encoding matches bincode option layout" {
    var inactive_data: [FEATURE_DATA_LEN]u8 = undefined;
    const inactive = try encodeFeature(.{ .activated_at = null }, &inactive_data);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 0, 0, 0, 0, 0 }, inactive);
    try std.testing.expectEqual(@as(?u64, null), (try decodeFeature(inactive)).activated_at);

    var active_data: [FEATURE_DATA_LEN]u8 = undefined;
    const active = try encodeFeature(.{ .activated_at = 0x0102_0304_0506_0708 }, &active_data);
    try std.testing.expectEqual(@as(u8, 1), active[0]);
    try std.testing.expectEqual(@as(u64, 0x0102_0304_0506_0708), std.mem.readInt(u64, active[1..9], .little));
    try std.testing.expectEqual(@as(?u64, 0x0102_0304_0506_0708), (try decodeFeature(active)).activated_at);
}

test "decodeFeature rejects short input and invalid option tags" {
    try std.testing.expectError(error.InputTooShort, decodeFeature(&.{ 0, 0, 0 }));
    try std.testing.expectError(error.InvalidFeatureOptionTag, decodeFeature(&.{ 2, 0, 0, 0, 0, 0, 0, 0, 0 }));
}

test "activateWithLamports composes canonical system instructions" {
    const feature: Pubkey = .{1} ** 32;
    const funder: Pubkey = .{2} ** 32;
    var transfer_metas: [2]system.AccountMeta = undefined;
    var transfer_data: system.TransferData = undefined;
    var allocate_metas: [1]system.AccountMeta = undefined;
    var allocate_data: system.AllocateData = undefined;
    var assign_metas: [1]system.AccountMeta = undefined;
    var assign_data: system.AssignData = undefined;

    const instructions = activateWithLamports(&feature, &funder, 500, .{
        .transfer_metas = &transfer_metas,
        .transfer_data = &transfer_data,
        .allocate_metas = &allocate_metas,
        .allocate_data = &allocate_data,
        .assign_metas = &assign_metas,
        .assign_data = &assign_data,
    });

    try std.testing.expectEqual(@as(usize, 3), instructions.slice().len);
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, instructions.transfer().data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 500), std.mem.readInt(u64, instructions.transfer().data[4..12], .little));
    try std.testing.expectEqual(@as(u8, 1), instructions.transfer().accounts[0].is_signer);
    try std.testing.expectEqual(@as(u32, 8), std.mem.readInt(u32, instructions.allocate().data[0..4], .little));
    try std.testing.expectEqual(@as(u64, FEATURE_DATA_LEN), std.mem.readInt(u64, instructions.allocate().data[4..12], .little));
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, instructions.assign().data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &PROGRAM_ID, instructions.assign().data[4..36]);
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "PROGRAM_ID"));
    try std.testing.expect(@hasDecl(@This(), "encodeFeature"));
    try std.testing.expect(@hasDecl(@This(), "decodeFeature"));
    try std.testing.expect(@hasDecl(@This(), "activateWithLamports"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
}
