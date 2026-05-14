//! SPL Token Group instruction builders and parsers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const id = @import("id.zig");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;
pub const ProgramError = sol.ProgramError;
pub const INTERFACE_NAMESPACE = id.INTERFACE_NAMESPACE;
pub const MaybeNullPubkey = @import("maybe_null_pubkey.zig").MaybeNullPubkey;

pub const INITIALIZE_GROUP_DISCRIMINATOR = [_]u8{ 0x79, 0x71, 0x6c, 0x27, 0x36, 0x33, 0x00, 0x04 };
pub const UPDATE_GROUP_MAX_SIZE_DISCRIMINATOR = [_]u8{ 0x6c, 0x25, 0xab, 0x8f, 0xf8, 0x1e, 0x12, 0x6e };
pub const UPDATE_GROUP_AUTHORITY_DISCRIMINATOR = [_]u8{ 0xa1, 0x69, 0x58, 0x01, 0xed, 0xdd, 0xd8, 0xcb };
pub const INITIALIZE_MEMBER_DISCRIMINATOR = [_]u8{ 0x98, 0x20, 0xde, 0xb0, 0xdf, 0xed, 0x74, 0x86 };

pub const initialize_group_accounts_len: usize = 3;
pub const update_group_max_size_accounts_len: usize = 2;
pub const update_group_authority_accounts_len: usize = 2;
pub const initialize_member_accounts_len: usize = 5;

pub const initialize_group_data_len: usize = sol.DISCRIMINATOR_LEN + MaybeNullPubkey.LEN + @sizeOf(u64);
pub const update_group_max_size_data_len: usize = sol.DISCRIMINATOR_LEN + @sizeOf(u64);
pub const update_group_authority_data_len: usize = sol.DISCRIMINATOR_LEN + MaybeNullPubkey.LEN;
pub const initialize_member_data_len: usize = sol.DISCRIMINATOR_LEN;

pub const InitializeGroupMetas = [initialize_group_accounts_len]AccountMeta;
pub const UpdateGroupMaxSizeMetas = [update_group_max_size_accounts_len]AccountMeta;
pub const UpdateGroupAuthorityMetas = [update_group_authority_accounts_len]AccountMeta;
pub const InitializeMemberMetas = [initialize_member_accounts_len]AccountMeta;

pub const BuildError = error{InvalidInstructionDataSliceLength};

/// Minimal raw instruction helper for interface consumers that already
/// own both the account-meta slice and exact data bytes.
pub inline fn buildRawInstruction(
    program_id: *const Pubkey,
    accounts: []const AccountMeta,
    data: []const u8,
) Instruction {
    return Instruction.init(program_id, accounts, data);
}

pub const InitializeGroup = struct {
    update_authority: MaybeNullPubkey,
    max_size: u64,

    pub fn packedLen(self: InitializeGroup) usize {
        _ = self;
        return initialize_group_data_len;
    }

    pub fn pack(self: InitializeGroup, out: []u8) BuildError![]const u8 {
        if (out.len < initialize_group_data_len) return error.InvalidInstructionDataSliceLength;
        const bytes = out[0..initialize_group_data_len];
        @memcpy(bytes[0..sol.DISCRIMINATOR_LEN], &INITIALIZE_GROUP_DISCRIMINATOR);
        _ = self.update_authority.write(bytes[sol.DISCRIMINATOR_LEN..][0..MaybeNullPubkey.LEN]) catch unreachable;
        std.mem.writeInt(u64, bytes[sol.DISCRIMINATOR_LEN + MaybeNullPubkey.LEN ..][0..@sizeOf(u64)], self.max_size, .little);
        return bytes;
    }

    pub fn parsePayload(payload: []const u8) ProgramError!InitializeGroup {
        if (payload.len != MaybeNullPubkey.LEN + @sizeOf(u64)) return ProgramError.InvalidArgument;
        return .{
            .update_authority = MaybeNullPubkey.parse(payload[0..MaybeNullPubkey.LEN]) catch return ProgramError.InvalidArgument,
            .max_size = std.mem.readInt(u64, payload[MaybeNullPubkey.LEN..][0..@sizeOf(u64)], .little),
        };
    }
};

pub const UpdateGroupMaxSize = struct {
    max_size: u64,

    pub fn packedLen(self: UpdateGroupMaxSize) usize {
        _ = self;
        return update_group_max_size_data_len;
    }

    pub fn pack(self: UpdateGroupMaxSize, out: []u8) BuildError![]const u8 {
        if (out.len < update_group_max_size_data_len) return error.InvalidInstructionDataSliceLength;
        const bytes = out[0..update_group_max_size_data_len];
        @memcpy(bytes[0..sol.DISCRIMINATOR_LEN], &UPDATE_GROUP_MAX_SIZE_DISCRIMINATOR);
        std.mem.writeInt(u64, bytes[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u64)], self.max_size, .little);
        return bytes;
    }

    pub fn parsePayload(payload: []const u8) ProgramError!UpdateGroupMaxSize {
        if (payload.len != @sizeOf(u64)) return ProgramError.InvalidArgument;
        return .{
            .max_size = std.mem.readInt(u64, payload[0..@sizeOf(u64)], .little),
        };
    }
};

pub const UpdateGroupAuthority = struct {
    new_authority: MaybeNullPubkey,

    pub fn packedLen(self: UpdateGroupAuthority) usize {
        _ = self;
        return update_group_authority_data_len;
    }

    pub fn pack(self: UpdateGroupAuthority, out: []u8) BuildError![]const u8 {
        if (out.len < update_group_authority_data_len) return error.InvalidInstructionDataSliceLength;
        const bytes = out[0..update_group_authority_data_len];
        @memcpy(bytes[0..sol.DISCRIMINATOR_LEN], &UPDATE_GROUP_AUTHORITY_DISCRIMINATOR);
        _ = self.new_authority.write(bytes[sol.DISCRIMINATOR_LEN..][0..MaybeNullPubkey.LEN]) catch unreachable;
        return bytes;
    }

    pub fn parsePayload(payload: []const u8) ProgramError!UpdateGroupAuthority {
        if (payload.len != MaybeNullPubkey.LEN) return ProgramError.InvalidArgument;
        return .{
            .new_authority = MaybeNullPubkey.parse(payload) catch return ProgramError.InvalidArgument,
        };
    }
};

pub const InitializeMember = struct {
    pub fn packedLen(self: InitializeMember) usize {
        _ = self;
        return initialize_member_data_len;
    }

    pub fn pack(self: InitializeMember, out: []u8) BuildError![]const u8 {
        _ = self;
        if (out.len < initialize_member_data_len) return error.InvalidInstructionDataSliceLength;
        const bytes = out[0..initialize_member_data_len];
        @memcpy(bytes[0..sol.DISCRIMINATOR_LEN], &INITIALIZE_MEMBER_DISCRIMINATOR);
        return bytes;
    }

    pub fn parsePayload(payload: []const u8) ProgramError!InitializeMember {
        if (payload.len != 0) return ProgramError.InvalidArgument;
        return .{};
    }
};

pub const TokenGroupInstruction = union(enum) {
    initialize_group: InitializeGroup,
    update_group_max_size: UpdateGroupMaxSize,
    update_group_authority: UpdateGroupAuthority,
    initialize_member: InitializeMember,

    pub fn packedLen(self: TokenGroupInstruction) BuildError!usize {
        return switch (self) {
            .initialize_group => |data| data.packedLen(),
            .update_group_max_size => |data| data.packedLen(),
            .update_group_authority => |data| data.packedLen(),
            .initialize_member => |data| data.packedLen(),
        };
    }

    pub fn pack(self: TokenGroupInstruction, out: []u8) BuildError![]const u8 {
        return switch (self) {
            .initialize_group => |data| data.pack(out),
            .update_group_max_size => |data| data.pack(out),
            .update_group_authority => |data| data.pack(out),
            .initialize_member => |data| data.pack(out),
        };
    }

    pub fn fromBytes(input: []const u8) ProgramError!TokenGroupInstruction {
        return parse(input);
    }

    pub fn parse(input: []const u8) ProgramError!TokenGroupInstruction {
        if (input.len < sol.DISCRIMINATOR_LEN) return ProgramError.InvalidInstructionData;
        const discriminator = input[0..sol.DISCRIMINATOR_LEN];
        const payload = input[sol.DISCRIMINATOR_LEN..];

        if (std.mem.eql(u8, discriminator, &INITIALIZE_GROUP_DISCRIMINATOR)) {
            return .{ .initialize_group = try InitializeGroup.parsePayload(payload) };
        }
        if (std.mem.eql(u8, discriminator, &UPDATE_GROUP_MAX_SIZE_DISCRIMINATOR)) {
            return .{ .update_group_max_size = try UpdateGroupMaxSize.parsePayload(payload) };
        }
        if (std.mem.eql(u8, discriminator, &UPDATE_GROUP_AUTHORITY_DISCRIMINATOR)) {
            return .{ .update_group_authority = try UpdateGroupAuthority.parsePayload(payload) };
        }
        if (std.mem.eql(u8, discriminator, &INITIALIZE_MEMBER_DISCRIMINATOR)) {
            return .{ .initialize_member = try InitializeMember.parsePayload(payload) };
        }
        return ProgramError.InvalidInstructionData;
    }
};

pub inline fn initializeGroupDataLen() usize {
    return initialize_group_data_len;
}

pub inline fn updateGroupMaxSizeDataLen() usize {
    return update_group_max_size_data_len;
}

pub inline fn updateGroupAuthorityDataLen() usize {
    return update_group_authority_data_len;
}

pub inline fn initializeMemberDataLen() usize {
    return initialize_member_data_len;
}

pub fn initializeGroup(
    program_id: *const Pubkey,
    group: *const Pubkey,
    mint: *const Pubkey,
    mint_authority: *const Pubkey,
    update_authority: MaybeNullPubkey,
    max_size: u64,
    metas: *InitializeGroupMetas,
    data: []u8,
) BuildError!Instruction {
    metas.* = .{
        AccountMeta.writable(group),
        AccountMeta.readonly(mint),
        AccountMeta.signer(mint_authority),
    };
    const data_slice = try (TokenGroupInstruction{
        .initialize_group = .{
            .update_authority = update_authority,
            .max_size = max_size,
        },
    }).pack(data);
    return Instruction.init(program_id, metas, data_slice);
}

pub fn updateGroupMaxSize(
    program_id: *const Pubkey,
    group: *const Pubkey,
    update_authority: *const Pubkey,
    max_size: u64,
    metas: *UpdateGroupMaxSizeMetas,
    data: []u8,
) BuildError!Instruction {
    metas.* = .{
        AccountMeta.writable(group),
        AccountMeta.signer(update_authority),
    };
    const data_slice = try (TokenGroupInstruction{
        .update_group_max_size = .{ .max_size = max_size },
    }).pack(data);
    return Instruction.init(program_id, metas, data_slice);
}

pub fn updateGroupAuthority(
    program_id: *const Pubkey,
    group: *const Pubkey,
    current_authority: *const Pubkey,
    new_authority: MaybeNullPubkey,
    metas: *UpdateGroupAuthorityMetas,
    data: []u8,
) BuildError!Instruction {
    metas.* = .{
        AccountMeta.writable(group),
        AccountMeta.signer(current_authority),
    };
    const data_slice = try (TokenGroupInstruction{
        .update_group_authority = .{ .new_authority = new_authority },
    }).pack(data);
    return Instruction.init(program_id, metas, data_slice);
}

pub fn initializeMember(
    program_id: *const Pubkey,
    member: *const Pubkey,
    member_mint: *const Pubkey,
    member_mint_authority: *const Pubkey,
    group: *const Pubkey,
    group_update_authority: *const Pubkey,
    metas: *InitializeMemberMetas,
    data: []u8,
) BuildError!Instruction {
    metas.* = .{
        AccountMeta.writable(member),
        AccountMeta.readonly(member_mint),
        AccountMeta.signer(member_mint_authority),
        AccountMeta.writable(group),
        AccountMeta.signer(group_update_authority),
    };
    const data_slice = try (TokenGroupInstruction{
        .initialize_member = .{},
    }).pack(data);
    return Instruction.init(program_id, metas, data_slice);
}

fn expectMeta(
    actual: AccountMeta,
    expected_key: *const Pubkey,
    expected_writable: u8,
    expected_signer: u8,
) !void {
    try std.testing.expectEqual(expected_key, actual.pubkey);
    try std.testing.expectEqual(expected_writable, actual.is_writable);
    try std.testing.expectEqual(expected_signer, actual.is_signer);
}

test "buildRawInstruction preserves caller program id and borrowed slices" {
    const program_id_a: Pubkey = .{0x51} ** 32;
    const program_id_b: Pubkey = .{0x61} ** 32;
    const meta_a: Pubkey = .{0x71} ** 32;
    const meta_b: Pubkey = .{0x81} ** 32;

    var metas = [_]AccountMeta{
        AccountMeta.readonly(&meta_a),
        AccountMeta.signerWritable(&meta_b),
    };
    const data_a = [_]u8{ 5, 4, 3, 2, 1 };
    const data_b = [_]u8{ 6, 7 };

    const ix_a = buildRawInstruction(&program_id_a, &metas, &data_a);
    try std.testing.expectEqual(&program_id_a, ix_a.program_id);
    try std.testing.expectEqual(@intFromPtr(&metas[0]), @intFromPtr(ix_a.accounts.ptr));
    try std.testing.expectEqual(@intFromPtr(&data_a[0]), @intFromPtr(ix_a.data.ptr));
    try std.testing.expectEqual(@as(usize, 2), ix_a.accounts.len);
    try std.testing.expectEqual(@as(usize, 5), ix_a.data.len);
    try expectMeta(ix_a.accounts[0], &meta_a, 0, 0);
    try expectMeta(ix_a.accounts[1], &meta_b, 1, 1);
    try std.testing.expectEqualSlices(u8, &data_a, ix_a.data);

    const ix_b = buildRawInstruction(&program_id_b, metas[1..], &data_b);
    try std.testing.expectEqual(&program_id_b, ix_b.program_id);
    try std.testing.expectEqual(@intFromPtr(&metas[1]), @intFromPtr(ix_b.accounts.ptr));
    try std.testing.expectEqual(@intFromPtr(&data_b[0]), @intFromPtr(ix_b.data.ptr));
    try std.testing.expectEqual(@as(usize, 1), ix_b.accounts.len);
    try std.testing.expectEqual(@as(usize, 2), ix_b.data.len);
    try expectMeta(ix_b.accounts[0], &meta_b, 1, 1);
    try std.testing.expectEqualSlices(u8, &data_b, ix_b.data);
}

test "buildRawInstruction stays raw borrowed and transaction-free" {
    const info = @typeInfo(@TypeOf(buildRawInstruction)).@"fn";
    try std.testing.expectEqual(@as(usize, 3), info.params.len);
    try std.testing.expect(info.params[0].type.? == *const Pubkey);
    try std.testing.expect(info.params[1].type.? == []const AccountMeta);
    try std.testing.expect(info.params[2].type.? == []const u8);
    try std.testing.expect(info.return_type.? == Instruction);
}

test "instruction parser rejects short unknown and wrong-length payloads" {
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenGroupInstruction.parse(&[_]u8{}));
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenGroupInstruction.parse(&[_]u8{ 1, 2, 3, 4, 5, 6, 7 }));

    const unknown = [_]u8{0} ** sol.DISCRIMINATOR_LEN;
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenGroupInstruction.parse(&unknown));

    var short_initialize = [_]u8{0} ** (initialize_group_data_len - 1);
    @memcpy(short_initialize[0..sol.DISCRIMINATOR_LEN], &INITIALIZE_GROUP_DISCRIMINATOR);
    try std.testing.expectError(ProgramError.InvalidArgument, TokenGroupInstruction.parse(&short_initialize));

    var long_member = [_]u8{0} ** (initialize_member_data_len + 1);
    @memcpy(long_member[0..sol.DISCRIMINATOR_LEN], &INITIALIZE_MEMBER_DISCRIMINATOR);
    try std.testing.expectError(ProgramError.InvalidArgument, TokenGroupInstruction.parse(&long_member));
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("instruction_tests.zig");
}
