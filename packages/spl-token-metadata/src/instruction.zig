//! SPL Token Metadata instruction builders and parsers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const id = @import("id.zig");
const metadata_state = @import("state.zig");
const MaybeNullPubkey = @import("maybe_null_pubkey.zig").MaybeNullPubkey;
const parity_fixture = @import("parity_fixture.zig");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;
pub const ProgramError = sol.ProgramError;
pub const NAMESPACE = id.INTERFACE_NAMESPACE;
pub const Field = metadata_state.Field;

pub const INITIALIZE_DISCRIMINATOR = [_]u8{ 210, 225, 30, 162, 88, 184, 77, 141 };
pub const UPDATE_FIELD_DISCRIMINATOR = [_]u8{ 221, 233, 49, 45, 181, 202, 220, 200 };
pub const REMOVE_KEY_DISCRIMINATOR = [_]u8{ 234, 18, 32, 56, 89, 141, 37, 181 };
pub const UPDATE_AUTHORITY_DISCRIMINATOR = [_]u8{ 215, 228, 166, 228, 84, 100, 86, 123 };
pub const EMIT_DISCRIMINATOR = [_]u8{ 250, 166, 180, 250, 13, 12, 184, 70 };

pub const initialize_accounts_len: usize = 4;
pub const update_field_accounts_len: usize = 2;
pub const remove_key_accounts_len: usize = 2;
pub const update_authority_accounts_len: usize = 2;
pub const emit_accounts_len: usize = 1;
pub const update_authority_data_len: usize = sol.DISCRIMINATOR_LEN + MaybeNullPubkey.LEN;

pub const InitializeMetas = [initialize_accounts_len]AccountMeta;
pub const UpdateFieldMetas = [update_field_accounts_len]AccountMeta;
pub const RemoveKeyMetas = [remove_key_accounts_len]AccountMeta;
pub const UpdateAuthorityMetas = [update_authority_accounts_len]AccountMeta;
pub const EmitMetas = [emit_accounts_len]AccountMeta;

pub const BuildError = error{
    InvalidInstructionDataSliceLength,
    LengthOverflow,
};

pub const Initialize = struct {
    name: []const u8,
    symbol: []const u8,
    uri: []const u8,

    pub fn packedLen(self: Initialize) BuildError!usize {
        var len: usize = 0;
        len = try checkedAddLen(len, try borshStringLen(self.name));
        len = try checkedAddLen(len, try borshStringLen(self.symbol));
        len = try checkedAddLen(len, try borshStringLen(self.uri));
        return len;
    }

    pub fn pack(self: Initialize, out: []u8) BuildError![]const u8 {
        const expected_len = try self.packedLen();
        if (out.len != expected_len) return error.InvalidInstructionDataSliceLength;

        var cursor: usize = 0;
        cursor += try writeBorshString(out[cursor..], self.name);
        cursor += try writeBorshString(out[cursor..], self.symbol);
        cursor += try writeBorshString(out[cursor..], self.uri);
        return out[0..cursor];
    }

    pub fn parse(input: []const u8) ProgramError!Initialize {
        var cursor = Cursor.init(input);
        const name = try cursor.readBorshString();
        const symbol = try cursor.readBorshString();
        const uri = try cursor.readBorshString();
        try cursor.finish();
        return .{
            .name = name,
            .symbol = symbol,
            .uri = uri,
        };
    }
};

pub const UpdateField = struct {
    field: Field,
    value: []const u8,

    pub fn packedLen(self: UpdateField) BuildError!usize {
        return checkedAddLen(try self.field.packedLen(), try borshStringLen(self.value));
    }

    pub fn pack(self: UpdateField, out: []u8) BuildError![]const u8 {
        const expected_len = try self.packedLen();
        if (out.len != expected_len) return error.InvalidInstructionDataSliceLength;

        const field_len = try self.field.packedLen();
        _ = try self.field.pack(out[0..field_len]);
        _ = try writeBorshString(out[field_len..], self.value);
        return out[0..expected_len];
    }

    pub fn parse(input: []const u8) ProgramError!UpdateField {
        var cursor = Cursor.init(input);
        const field = try cursor.readField();
        const value = try cursor.readBorshString();
        try cursor.finish();
        return .{
            .field = field,
            .value = value,
        };
    }
};

pub const RemoveKey = struct {
    idempotent: bool,
    key: []const u8,

    pub fn packedLen(self: RemoveKey) BuildError!usize {
        return checkedAddLen(1, try borshStringLen(self.key));
    }

    pub fn pack(self: RemoveKey, out: []u8) BuildError![]const u8 {
        const expected_len = try self.packedLen();
        if (out.len != expected_len) return error.InvalidInstructionDataSliceLength;

        out[0] = if (self.idempotent) 1 else 0;
        _ = try writeBorshString(out[1..], self.key);
        return out[0..expected_len];
    }

    pub fn parse(input: []const u8) ProgramError!RemoveKey {
        var cursor = Cursor.init(input);
        const idempotent = try cursor.readBool();
        const key = try cursor.readBorshString();
        try cursor.finish();
        return .{
            .idempotent = idempotent,
            .key = key,
        };
    }
};

pub const UpdateAuthority = struct {
    new_authority: MaybeNullPubkey,

    pub fn packedLen(self: UpdateAuthority) BuildError!usize {
        _ = self;
        return MaybeNullPubkey.LEN;
    }

    pub fn pack(self: UpdateAuthority, out: []u8) BuildError![]const u8 {
        if (out.len != MaybeNullPubkey.LEN) return error.InvalidInstructionDataSliceLength;
        _ = self.new_authority.write(out) catch unreachable;
        return out[0..MaybeNullPubkey.LEN];
    }

    pub fn parse(input: []const u8) ProgramError!UpdateAuthority {
        if (input.len != MaybeNullPubkey.LEN) return ProgramError.InvalidInstructionData;
        return .{
            .new_authority = MaybeNullPubkey.parse(input) catch return ProgramError.InvalidInstructionData,
        };
    }
};

pub const Emit = struct {
    start: ?u64,
    end: ?u64,

    pub fn packedLen(self: Emit) BuildError!usize {
        return optionU64Len(self.start) + optionU64Len(self.end);
    }

    pub fn pack(self: Emit, out: []u8) BuildError![]const u8 {
        const expected_len = try self.packedLen();
        if (out.len != expected_len) return error.InvalidInstructionDataSliceLength;

        var cursor: usize = 0;
        cursor += try writeOptionU64(out[cursor..], self.start);
        cursor += try writeOptionU64(out[cursor..], self.end);
        return out[0..cursor];
    }

    pub fn parse(input: []const u8) ProgramError!Emit {
        var cursor = Cursor.init(input);
        const start = try cursor.readOptionU64();
        const end = try cursor.readOptionU64();
        try cursor.finish();
        return .{
            .start = start,
            .end = end,
        };
    }
};

pub const TokenMetadataInstruction = union(enum) {
    initialize: Initialize,
    update_field: UpdateField,
    remove_key: RemoveKey,
    update_authority: UpdateAuthority,
    emit: Emit,

    pub fn packedLen(self: TokenMetadataInstruction) BuildError!usize {
        return checkedAddLen(sol.DISCRIMINATOR_LEN, switch (self) {
            .initialize => |data| try data.packedLen(),
            .update_field => |data| try data.packedLen(),
            .remove_key => |data| try data.packedLen(),
            .update_authority => |data| try data.packedLen(),
            .emit => |data| try data.packedLen(),
        });
    }

    pub fn pack(self: TokenMetadataInstruction, out: []u8) BuildError![]const u8 {
        const expected_len = try self.packedLen();
        if (out.len != expected_len) return error.InvalidInstructionDataSliceLength;

        const payload = out[sol.DISCRIMINATOR_LEN..];
        switch (self) {
            .initialize => |data| {
                @memcpy(out[0..sol.DISCRIMINATOR_LEN], &INITIALIZE_DISCRIMINATOR);
                _ = try data.pack(payload);
            },
            .update_field => |data| {
                @memcpy(out[0..sol.DISCRIMINATOR_LEN], &UPDATE_FIELD_DISCRIMINATOR);
                _ = try data.pack(payload);
            },
            .remove_key => |data| {
                @memcpy(out[0..sol.DISCRIMINATOR_LEN], &REMOVE_KEY_DISCRIMINATOR);
                _ = try data.pack(payload);
            },
            .update_authority => |data| {
                @memcpy(out[0..sol.DISCRIMINATOR_LEN], &UPDATE_AUTHORITY_DISCRIMINATOR);
                _ = try data.pack(payload);
            },
            .emit => |data| {
                @memcpy(out[0..sol.DISCRIMINATOR_LEN], &EMIT_DISCRIMINATOR);
                _ = try data.pack(payload);
            },
        }
        return out[0..expected_len];
    }

    pub fn unpack(input: []const u8) ProgramError!TokenMetadataInstruction {
        if (input.len < sol.DISCRIMINATOR_LEN) return ProgramError.InvalidInstructionData;

        const discriminator = input[0..sol.DISCRIMINATOR_LEN];
        const payload = input[sol.DISCRIMINATOR_LEN..];

        if (std.mem.eql(u8, discriminator, &INITIALIZE_DISCRIMINATOR)) {
            return .{ .initialize = try Initialize.parse(payload) };
        }
        if (std.mem.eql(u8, discriminator, &UPDATE_FIELD_DISCRIMINATOR)) {
            return .{ .update_field = try UpdateField.parse(payload) };
        }
        if (std.mem.eql(u8, discriminator, &REMOVE_KEY_DISCRIMINATOR)) {
            return .{ .remove_key = try RemoveKey.parse(payload) };
        }
        if (std.mem.eql(u8, discriminator, &UPDATE_AUTHORITY_DISCRIMINATOR)) {
            return .{ .update_authority = try UpdateAuthority.parse(payload) };
        }
        if (std.mem.eql(u8, discriminator, &EMIT_DISCRIMINATOR)) {
            return .{ .emit = try Emit.parse(payload) };
        }

        return ProgramError.InvalidInstructionData;
    }
};

/// Minimal raw instruction helper for interface consumers that already
/// own both the account-meta slice and exact data bytes.
pub inline fn buildRawInstruction(
    program_id: *const Pubkey,
    accounts: []const AccountMeta,
    data: []const u8,
) Instruction {
    return Instruction.init(program_id, accounts, data);
}

pub fn initializeDataLen(name: []const u8, symbol: []const u8, uri: []const u8) BuildError!usize {
    return (TokenMetadataInstruction{
        .initialize = .{
            .name = name,
            .symbol = symbol,
            .uri = uri,
        },
    }).packedLen();
}

pub fn updateFieldDataLen(field: Field, value: []const u8) BuildError!usize {
    return (TokenMetadataInstruction{
        .update_field = .{
            .field = field,
            .value = value,
        },
    }).packedLen();
}

pub fn removeKeyDataLen(key: []const u8) BuildError!usize {
    return (TokenMetadataInstruction{
        .remove_key = .{
            .idempotent = false,
            .key = key,
        },
    }).packedLen();
}

pub inline fn emitDataLen(start: ?u64, end: ?u64) usize {
    return sol.DISCRIMINATOR_LEN + optionU64Len(start) + optionU64Len(end);
}

pub fn initialize(
    program_id: *const Pubkey,
    metadata_pubkey: *const Pubkey,
    update_authority_pubkey: *const Pubkey,
    mint_pubkey: *const Pubkey,
    mint_authority_pubkey: *const Pubkey,
    name: []const u8,
    symbol: []const u8,
    uri: []const u8,
    metas: *InitializeMetas,
    data: []u8,
) BuildError!Instruction {
    metas.* = .{
        AccountMeta.writable(metadata_pubkey),
        AccountMeta.readonly(update_authority_pubkey),
        AccountMeta.readonly(mint_pubkey),
        AccountMeta.signer(mint_authority_pubkey),
    };
    const data_slice = try (TokenMetadataInstruction{
        .initialize = .{
            .name = name,
            .symbol = symbol,
            .uri = uri,
        },
    }).pack(data);
    return Instruction.init(program_id, metas, data_slice);
}

pub fn updateField(
    program_id: *const Pubkey,
    metadata_pubkey: *const Pubkey,
    update_authority_pubkey: *const Pubkey,
    field: Field,
    value: []const u8,
    metas: *UpdateFieldMetas,
    data: []u8,
) BuildError!Instruction {
    metas.* = .{
        AccountMeta.writable(metadata_pubkey),
        AccountMeta.signer(update_authority_pubkey),
    };
    const data_slice = try (TokenMetadataInstruction{
        .update_field = .{
            .field = field,
            .value = value,
        },
    }).pack(data);
    return Instruction.init(program_id, metas, data_slice);
}

pub fn removeKey(
    program_id: *const Pubkey,
    metadata_pubkey: *const Pubkey,
    update_authority_pubkey: *const Pubkey,
    key: []const u8,
    idempotent: bool,
    metas: *RemoveKeyMetas,
    data: []u8,
) BuildError!Instruction {
    metas.* = .{
        AccountMeta.writable(metadata_pubkey),
        AccountMeta.signer(update_authority_pubkey),
    };
    const data_slice = try (TokenMetadataInstruction{
        .remove_key = .{
            .idempotent = idempotent,
            .key = key,
        },
    }).pack(data);
    return Instruction.init(program_id, metas, data_slice);
}

pub fn updateAuthority(
    program_id: *const Pubkey,
    metadata_pubkey: *const Pubkey,
    current_authority_pubkey: *const Pubkey,
    new_authority: MaybeNullPubkey,
    metas: *UpdateAuthorityMetas,
    data: []u8,
) BuildError!Instruction {
    metas.* = .{
        AccountMeta.writable(metadata_pubkey),
        AccountMeta.signer(current_authority_pubkey),
    };
    const data_slice = try (TokenMetadataInstruction{
        .update_authority = .{
            .new_authority = new_authority,
        },
    }).pack(data);
    return Instruction.init(program_id, metas, data_slice);
}

pub fn emit(
    program_id: *const Pubkey,
    metadata_pubkey: *const Pubkey,
    start: ?u64,
    end: ?u64,
    metas: *EmitMetas,
    data: []u8,
) BuildError!Instruction {
    metas.* = .{
        AccountMeta.readonly(metadata_pubkey),
    };
    const data_slice = try (TokenMetadataInstruction{
        .emit = .{
            .start = start,
            .end = end,
        },
    }).pack(data);
    return Instruction.init(program_id, metas, data_slice);
}

const Cursor = struct {
    input: []const u8,
    index: usize = 0,

    fn init(input: []const u8) Cursor {
        return .{ .input = input };
    }

    fn readExact(self: *Cursor, len: usize) ProgramError![]const u8 {
        const end = std.math.add(usize, self.index, len) catch return ProgramError.InvalidInstructionData;
        if (end > self.input.len) return ProgramError.InvalidInstructionData;
        const start = self.index;
        self.index = end;
        return self.input[start..end];
    }

    fn readByte(self: *Cursor) ProgramError!u8 {
        return (try self.readExact(1))[0];
    }

    fn readBool(self: *Cursor) ProgramError!bool {
        return switch (try self.readByte()) {
            0 => false,
            1 => true,
            else => ProgramError.InvalidInstructionData,
        };
    }

    fn readU64(self: *Cursor) ProgramError!u64 {
        const bytes = try self.readExact(@sizeOf(u64));
        return std.mem.readInt(u64, bytes[0..@sizeOf(u64)], .little);
    }

    fn readOptionU64(self: *Cursor) ProgramError!?u64 {
        return switch (try self.readByte()) {
            0 => null,
            1 => try self.readU64(),
            else => ProgramError.InvalidInstructionData,
        };
    }

    fn readBorshString(self: *Cursor) ProgramError![]const u8 {
        const len_bytes = try self.readExact(@sizeOf(u32));
        const len = std.mem.readInt(u32, len_bytes[0..@sizeOf(u32)], .little);
        return try self.readExact(@as(usize, len));
    }

    fn readField(self: *Cursor) ProgramError!Field {
        const parsed = try Field.parse(self.input[self.index..]);
        self.index = std.math.add(usize, self.index, parsed.consumed) catch
            return ProgramError.InvalidInstructionData;
        return parsed.field;
    }

    fn finish(self: *Cursor) ProgramError!void {
        if (self.index != self.input.len) return ProgramError.InvalidInstructionData;
    }
};

fn checkedAddLen(base: usize, extra: usize) BuildError!usize {
    return std.math.add(usize, base, extra) catch error.LengthOverflow;
}

fn borshStringLen(value: []const u8) BuildError!usize {
    if (value.len > std.math.maxInt(u32)) return error.LengthOverflow;
    return checkedAddLen(@sizeOf(u32), value.len);
}

fn writeBorshString(out: []u8, value: []const u8) BuildError!usize {
    const expected_len = try borshStringLen(value);
    if (out.len < expected_len) return error.InvalidInstructionDataSliceLength;
    std.mem.writeInt(u32, out[0..@sizeOf(u32)], @intCast(value.len), .little);
    @memcpy(out[@sizeOf(u32)..expected_len], value);
    return expected_len;
}

fn optionU64Len(value: ?u64) usize {
    return if (value == null) 1 else 1 + @sizeOf(u64);
}

fn writeOptionU64(out: []u8, value: ?u64) BuildError!usize {
    const expected_len = optionU64Len(value);
    if (out.len < expected_len) return error.InvalidInstructionDataSliceLength;
    if (value) |unwrapped| {
        out[0] = 1;
        std.mem.writeInt(u64, out[1..][0..@sizeOf(u64)], unwrapped, .little);
    } else {
        out[0] = 0;
    }
    return expected_len;
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

fn expectField(actual: Field, expected: Field) !void {
    switch (expected) {
        .name => try std.testing.expect(switch (actual) {
            .name => true,
            else => false,
        }),
        .symbol => try std.testing.expect(switch (actual) {
            .symbol => true,
            else => false,
        }),
        .uri => try std.testing.expect(switch (actual) {
            .uri => true,
            else => false,
        }),
        .key => |expected_key| switch (actual) {
            .key => |actual_key| try std.testing.expectEqualStrings(expected_key, actual_key),
            else => return error.TestUnexpectedResult,
        },
    }
}

fn expectInitialize(actual: Initialize, name: []const u8, symbol: []const u8, uri: []const u8) !void {
    try std.testing.expectEqualStrings(name, actual.name);
    try std.testing.expectEqualStrings(symbol, actual.symbol);
    try std.testing.expectEqualStrings(uri, actual.uri);
}

fn expectUpdateField(actual: UpdateField, field: Field, value: []const u8) !void {
    try expectField(actual.field, field);
    try std.testing.expectEqualStrings(value, actual.value);
}

fn expectRemoveKey(actual: RemoveKey, idempotent: bool, key: []const u8) !void {
    try std.testing.expectEqual(idempotent, actual.idempotent);
    try std.testing.expectEqualStrings(key, actual.key);
}

fn expectUpdateAuthority(actual: UpdateAuthority, expected: MaybeNullPubkey) !void {
    try std.testing.expectEqual(expected.isPresent(), actual.new_authority.isPresent());
    if (expected.presentKey()) |expected_key| {
        try std.testing.expectEqualSlices(u8, expected_key[0..], actual.new_authority.presentKey().?[0..]);
    } else {
        try std.testing.expect(actual.new_authority.isNull());
    }
}

fn expectEmit(actual: Emit, start: ?u64, end: ?u64) !void {
    try std.testing.expectEqual(start, actual.start);
    try std.testing.expectEqual(end, actual.end);
}

fn expectInstructionRoundTrip(expected_bytes: []const u8) !void {
    const parsed = try TokenMetadataInstruction.unpack(expected_bytes);
    const repacked_len = try parsed.packedLen();
    const repacked = try std.testing.allocator.alloc(u8, repacked_len);
    defer std.testing.allocator.free(repacked);
    try std.testing.expectEqualSlices(u8, expected_bytes, try parsed.pack(repacked));
}

test "buildRawInstruction preserves caller program id and borrowed slices" {
    const program_id_a: Pubkey = .{0x11} ** 32;
    const program_id_b: Pubkey = .{0x22} ** 32;
    const meta_a: Pubkey = .{0x33} ** 32;
    const meta_b: Pubkey = .{0x44} ** 32;

    var metas = [_]AccountMeta{
        AccountMeta.writable(&meta_a),
        AccountMeta.signer(&meta_b),
    };
    const data_a = [_]u8{ 1, 2, 3, 4 };
    const data_b = [_]u8{ 9, 8, 7 };

    const ix_a = buildRawInstruction(&program_id_a, &metas, &data_a);
    try std.testing.expectEqual(&program_id_a, ix_a.program_id);
    try std.testing.expectEqual(@intFromPtr(&metas[0]), @intFromPtr(ix_a.accounts.ptr));
    try std.testing.expectEqual(@intFromPtr(&data_a[0]), @intFromPtr(ix_a.data.ptr));
    try std.testing.expectEqual(@as(usize, 2), ix_a.accounts.len);
    try std.testing.expectEqual(@as(usize, 4), ix_a.data.len);
    try expectMeta(ix_a.accounts[0], &meta_a, 1, 0);
    try expectMeta(ix_a.accounts[1], &meta_b, 0, 1);
    try std.testing.expectEqualSlices(u8, &data_a, ix_a.data);

    const ix_b = buildRawInstruction(&program_id_b, metas[0..1], &data_b);
    try std.testing.expectEqual(&program_id_b, ix_b.program_id);
    try std.testing.expectEqual(@intFromPtr(&metas[0]), @intFromPtr(ix_b.accounts.ptr));
    try std.testing.expectEqual(@intFromPtr(&data_b[0]), @intFromPtr(ix_b.data.ptr));
    try std.testing.expectEqual(@as(usize, 1), ix_b.accounts.len);
    try std.testing.expectEqual(@as(usize, 3), ix_b.data.len);
    try expectMeta(ix_b.accounts[0], &meta_a, 1, 0);
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

test "metadata instruction discriminators are canonical" {
    try std.testing.expectEqualStrings("spl_token_metadata_interface", NAMESPACE);
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 210, 225, 30, 162, 88, 184, 77, 141 },
        &INITIALIZE_DISCRIMINATOR,
    );
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 221, 233, 49, 45, 181, 202, 220, 200 },
        &UPDATE_FIELD_DISCRIMINATOR,
    );
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 234, 18, 32, 56, 89, 141, 37, 181 },
        &REMOVE_KEY_DISCRIMINATOR,
    );
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 215, 228, 166, 228, 84, 100, 86, 123 },
        &UPDATE_AUTHORITY_DISCRIMINATOR,
    );
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 250, 166, 180, 250, 13, 12, 184, 70 },
        &EMIT_DISCRIMINATOR,
    );
}

test "metadata instruction parser rejects short and unknown discriminators" {
    inline for (0..sol.DISCRIMINATOR_LEN) |len| {
        const short = [_]u8{0} ** len;
        try std.testing.expectError(ProgramError.InvalidInstructionData, TokenMetadataInstruction.unpack(&short));
    }

    try std.testing.expectError(
        ProgramError.InvalidInstructionData,
        TokenMetadataInstruction.unpack(&[_]u8{0} ** sol.DISCRIMINATOR_LEN),
    );
    try std.testing.expectError(
        ProgramError.InvalidInstructionData,
        TokenMetadataInstruction.unpack(&[_]u8{0xff} ** sol.DISCRIMINATOR_LEN),
    );

    var mutated = INITIALIZE_DISCRIMINATOR;
    mutated[7] ^= 1;
    try std.testing.expectError(
        ProgramError.InvalidInstructionData,
        TokenMetadataInstruction.unpack(&mutated),
    );
}

test "Initialize layout parser and account metas are canonical" {
    const program_ids = [_]Pubkey{ .{0x01} ** 32, .{0x02} ** 32 };
    const metadata: Pubkey = .{0x11} ** 32;
    const update_authority: Pubkey = .{0x22} ** 32;
    const mint: Pubkey = .{0x33} ** 32;
    const mint_authority: Pubkey = .{0x44} ** 32;
    const expected = [_]u8{
        210, 225, 30, 162, 88, 184, 77, 141,
        0,   0,   0,  0,
        0,   0,   0,  0,
        0,   0,   0,  0,
    };

    inline for (program_ids) |program_id| {
        var metas: InitializeMetas = undefined;
        var data: [expected.len]u8 = undefined;
        const ix = try initialize(
            &program_id,
            &metadata,
            &update_authority,
            &mint,
            &mint_authority,
            "",
            "",
            "",
            &metas,
            data[0..],
        );

        try std.testing.expectEqual(&program_id, ix.program_id);
        try std.testing.expectEqual(@intFromPtr(&metas[0]), @intFromPtr(ix.accounts.ptr));
        try std.testing.expectEqual(@intFromPtr(&data[0]), @intFromPtr(ix.data.ptr));
        try std.testing.expectEqualSlices(u8, &expected, ix.data);
        try std.testing.expectEqual(@as(usize, initialize_accounts_len), ix.accounts.len);
        try expectMeta(ix.accounts[0], &metadata, 1, 0);
        try expectMeta(ix.accounts[1], &update_authority, 0, 0);
        try expectMeta(ix.accounts[2], &mint, 0, 0);
        try expectMeta(ix.accounts[3], &mint_authority, 0, 1);

        switch (try TokenMetadataInstruction.unpack(ix.data)) {
            .initialize => |parsed| try expectInitialize(parsed, "", "", ""),
            else => return error.TestUnexpectedResult,
        }
        try expectInstructionRoundTrip(ix.data);
    }

    const utf8_name = "名札";
    const utf8_symbol = "μ";
    const utf8_uri = "https://例.invalid/名";
    const utf8_len = try initializeDataLen(utf8_name, utf8_symbol, utf8_uri);
    const utf8_data = try std.testing.allocator.alloc(u8, utf8_len);
    defer std.testing.allocator.free(utf8_data);
    var utf8_metas: InitializeMetas = undefined;
    const utf8_ix = try initialize(
        &program_ids[0],
        &metadata,
        &update_authority,
        &mint,
        &mint_authority,
        utf8_name,
        utf8_symbol,
        utf8_uri,
        &utf8_metas,
        utf8_data,
    );
    switch (try TokenMetadataInstruction.unpack(utf8_ix.data)) {
        .initialize => |parsed| try expectInitialize(parsed, utf8_name, utf8_symbol, utf8_uri),
        else => return error.TestUnexpectedResult,
    }
}

test "Initialize parser rejects truncated hostile-length and trailing payloads" {
    const truncated = [_]u8{
        210, 225, 30, 162, 88, 184, 77, 141,
        1,   0,   0,  0,
    };
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenMetadataInstruction.unpack(&truncated));

    const hostile = [_]u8{
        210, 225, 30, 162, 88, 184, 77, 141,
        0xff, 0xff, 0xff, 0xff,
    };
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenMetadataInstruction.unpack(&hostile));

    const trailing = [_]u8{
        210, 225, 30, 162, 88, 184, 77, 141,
        0,   0,   0,  0,
        0,   0,   0,  0,
        0,   0,   0,  0,
        0xaa,
    };
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenMetadataInstruction.unpack(&trailing));
}

test "UpdateField layout account metas and Field payloads are canonical" {
    const program_id: Pubkey = .{0x51} ** 32;
    const metadata: Pubkey = .{0x61} ** 32;
    const update_authority: Pubkey = .{0x71} ** 32;

    const expected_name = [_]u8{
        221, 233, 49, 45, 181, 202, 220, 200,
        0,
        3,   0,   0,  0, 'v', 'a', 'l',
    };
    var name_metas: UpdateFieldMetas = undefined;
    var name_data: [expected_name.len]u8 = undefined;
    const name_ix = try updateField(
        &program_id,
        &metadata,
        &update_authority,
        .{ .name = {} },
        "val",
        &name_metas,
        name_data[0..],
    );
    try std.testing.expectEqualSlices(u8, &expected_name, name_ix.data);
    try expectMeta(name_ix.accounts[0], &metadata, 1, 0);
    try expectMeta(name_ix.accounts[1], &update_authority, 0, 1);
    switch (try TokenMetadataInstruction.unpack(name_ix.data)) {
        .update_field => |parsed| try expectUpdateField(parsed, .{ .name = {} }, "val"),
        else => return error.TestUnexpectedResult,
    }

    const key_field = Field{ .key = "key" };
    const utf8_value = "μ";
    const key_len = try updateFieldDataLen(key_field, utf8_value);
    const key_data = try std.testing.allocator.alloc(u8, key_len);
    defer std.testing.allocator.free(key_data);
    var key_metas: UpdateFieldMetas = undefined;
    const key_ix = try updateField(
        &program_id,
        &metadata,
        &update_authority,
        key_field,
        utf8_value,
        &key_metas,
        key_data,
    );
    switch (try TokenMetadataInstruction.unpack(key_ix.data)) {
        .update_field => |parsed| try expectUpdateField(parsed, key_field, utf8_value),
        else => return error.TestUnexpectedResult,
    }
    try expectInstructionRoundTrip(key_ix.data);
}

test "RemoveKey layout account metas and parser are canonical" {
    const program_id: Pubkey = .{0x81} ** 32;
    const metadata: Pubkey = .{0x91} ** 32;
    const update_authority: Pubkey = .{0xa1} ** 32;

    const expected_true = [_]u8{
        234, 18, 32, 56, 89, 141, 37, 181,
        1,
        3,  0,  0,  0, 'k', 'e', 'y',
    };
    var true_metas: RemoveKeyMetas = undefined;
    var true_data: [expected_true.len]u8 = undefined;
    const true_ix = try removeKey(
        &program_id,
        &metadata,
        &update_authority,
        "key",
        true,
        &true_metas,
        true_data[0..],
    );
    try std.testing.expectEqualSlices(u8, &expected_true, true_ix.data);
    try expectMeta(true_ix.accounts[0], &metadata, 1, 0);
    try expectMeta(true_ix.accounts[1], &update_authority, 0, 1);
    switch (try TokenMetadataInstruction.unpack(true_ix.data)) {
        .remove_key => |parsed| try expectRemoveKey(parsed, true, "key"),
        else => return error.TestUnexpectedResult,
    }
    try expectInstructionRoundTrip(true_ix.data);

    const utf8_key = "ключ";
    const false_len = try removeKeyDataLen(utf8_key);
    const false_data = try std.testing.allocator.alloc(u8, false_len);
    defer std.testing.allocator.free(false_data);
    var false_metas: RemoveKeyMetas = undefined;
    const false_ix = try removeKey(
        &program_id,
        &metadata,
        &update_authority,
        utf8_key,
        false,
        &false_metas,
        false_data,
    );
    switch (try TokenMetadataInstruction.unpack(false_ix.data)) {
        .remove_key => |parsed| try expectRemoveKey(parsed, false, utf8_key),
        else => return error.TestUnexpectedResult,
    }

    const invalid_bool = [_]u8{
        234, 18, 32, 56, 89, 141, 37, 181,
        2,
        0,  0,  0,  0,
    };
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenMetadataInstruction.unpack(&invalid_bool));
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenMetadataInstruction.unpack(expected_true[0 .. expected_true.len - 1]));

    var trailing: [expected_true.len + 1]u8 = undefined;
    @memcpy(trailing[0..expected_true.len], &expected_true);
    trailing[expected_true.len] = 0xff;
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenMetadataInstruction.unpack(&trailing));
}

test "UpdateAuthority layout account metas and parser are canonical" {
    const program_ids = [_]Pubkey{ .{0xb1} ** 32, .{0xc1} ** 32 };
    const metadata: Pubkey = .{0xd1} ** 32;
    const current_authority: Pubkey = .{0xe1} ** 32;
    const new_authority_key: Pubkey = .{0xf1} ** 32;

    inline for (program_ids) |program_id| {
        var null_metas: UpdateAuthorityMetas = undefined;
        var null_data: [update_authority_data_len]u8 = undefined;
        const null_ix = try updateAuthority(
            &program_id,
            &metadata,
            &current_authority,
            MaybeNullPubkey.initNull(),
            &null_metas,
            null_data[0..],
        );
        try std.testing.expectEqual(&program_id, null_ix.program_id);
        try expectMeta(null_ix.accounts[0], &metadata, 1, 0);
        try expectMeta(null_ix.accounts[1], &current_authority, 0, 1);
        var expected_null: [update_authority_data_len]u8 = .{0} ** update_authority_data_len;
        @memcpy(expected_null[0..sol.DISCRIMINATOR_LEN], &UPDATE_AUTHORITY_DISCRIMINATOR);
        try std.testing.expectEqualSlices(u8, &expected_null, null_ix.data);
        switch (try TokenMetadataInstruction.unpack(null_ix.data)) {
            .update_authority => |parsed| try expectUpdateAuthority(parsed, MaybeNullPubkey.initNull()),
            else => return error.TestUnexpectedResult,
        }
    }

    var present_metas: UpdateAuthorityMetas = undefined;
    var present_data: [update_authority_data_len]u8 = undefined;
    const present = MaybeNullPubkey.fromPubkey(&new_authority_key);
    const present_ix = try updateAuthority(
        &program_ids[0],
        &metadata,
        &current_authority,
        present,
        &present_metas,
        present_data[0..],
    );
    try std.testing.expectEqualSlices(u8, &new_authority_key, present_ix.data[sol.DISCRIMINATOR_LEN..]);
    switch (try TokenMetadataInstruction.unpack(present_ix.data)) {
        .update_authority => |parsed| try expectUpdateAuthority(parsed, present),
        else => return error.TestUnexpectedResult,
    }

    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenMetadataInstruction.unpack(present_ix.data[0 .. present_ix.data.len - 1]));
    var overlong: [update_authority_data_len + 1]u8 = undefined;
    @memcpy(overlong[0..update_authority_data_len], present_ix.data);
    overlong[update_authority_data_len] = 0xaa;
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenMetadataInstruction.unpack(&overlong));
}

test "Emit layout account metas and parser are canonical" {
    const program_id: Pubkey = .{0x13} ** 32;
    const metadata: Pubkey = .{0x23} ** 32;

    const cases = [_]struct {
        start: ?u64,
        end: ?u64,
        expected: []const u8,
    }{
        .{
            .start = null,
            .end = null,
            .expected = &[_]u8{ 250, 166, 180, 250, 13, 12, 184, 70, 0, 0 },
        },
        .{
            .start = 0,
            .end = 7,
            .expected = &[_]u8{
                250, 166, 180, 250, 13, 12, 184, 70,
                1, 0, 0, 0, 0, 0, 0, 0, 0,
                1, 7, 0, 0, 0, 0, 0, 0, 0,
            },
        },
        .{
            .start = null,
            .end = std.math.maxInt(u64),
            .expected = &[_]u8{
                250, 166, 180, 250, 13, 12, 184, 70,
                0,
                1, 255, 255, 255, 255, 255, 255, 255, 255,
            },
        },
    };

    inline for (cases) |case| {
        var metas: EmitMetas = undefined;
        const data = try std.testing.allocator.alloc(u8, case.expected.len);
        defer std.testing.allocator.free(data);
        const ix = try emit(&program_id, &metadata, case.start, case.end, &metas, data);
        try std.testing.expectEqualSlices(u8, case.expected, ix.data);
        try expectMeta(ix.accounts[0], &metadata, 0, 0);
        switch (try TokenMetadataInstruction.unpack(ix.data)) {
            .emit => |parsed| try expectEmit(parsed, case.start, case.end),
            else => return error.TestUnexpectedResult,
        }
        try expectInstructionRoundTrip(ix.data);
    }

    const invalid_option = [_]u8{ 250, 166, 180, 250, 13, 12, 184, 70, 2, 0 };
    try std.testing.expectError(ProgramError.InvalidInstructionData, TokenMetadataInstruction.unpack(&invalid_option));
}

test "metadata instruction round-trips are byte-stable across all variants" {
    const update_authority_key: Pubkey = .{0x37} ** 32;
    const cases = [_]TokenMetadataInstruction{
        .{ .initialize = .{ .name = "A", .symbol = "B", .uri = "C" } },
        .{ .update_field = .{ .field = .{ .uri = {} }, .value = "value" } },
        .{ .remove_key = .{ .idempotent = true, .key = "extra" } },
        .{ .update_authority = .{ .new_authority = MaybeNullPubkey.fromPubkey(&update_authority_key) } },
        .{ .emit = .{ .start = 5, .end = null } },
    };

    inline for (cases) |case| {
        const len = try case.packedLen();
        const bytes = try std.testing.allocator.alloc(u8, len);
        defer std.testing.allocator.free(bytes);
        const encoded = try case.pack(bytes);
        try expectInstructionRoundTrip(encoded);
    }
}

fn fixturePubkey(bytes: [32]u8) Pubkey {
    return bytes;
}

fn fixtureField(input: parity_fixture.FieldInput) Field {
    return switch (input.tag) {
        @intFromEnum(metadata_state.FieldTag.name) => .{ .name = {} },
        @intFromEnum(metadata_state.FieldTag.symbol) => .{ .symbol = {} },
        @intFromEnum(metadata_state.FieldTag.uri) => .{ .uri = {} },
        @intFromEnum(metadata_state.FieldTag.key) => .{ .key = input.key },
        else => unreachable,
    };
}

fn fixtureMaybeNullPubkey(bytes: [32]u8) MaybeNullPubkey {
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

test "official Rust parity fixture matches metadata field encodings" {
    const loaded = try parity_fixture.load(std.testing.allocator);
    defer loaded.deinit();

    for (loaded.value.fields) |case| {
        const expected = fixtureField(case.input);
        const bytes = try std.testing.allocator.alloc(u8, case.data.len);
        defer std.testing.allocator.free(bytes);

        try std.testing.expectEqualSlices(u8, case.data, try expected.pack(bytes));
        const parsed = try Field.parse(case.data);
        try std.testing.expectEqual(case.data.len, parsed.consumed);
        try expectField(parsed.field, expected);
    }
}

test "official Rust parity fixture matches metadata instruction builders" {
    const loaded = try parity_fixture.load(std.testing.allocator);
    defer loaded.deinit();

    for (loaded.value.initialize) |case| {
        var metas: InitializeMetas = undefined;
        const data = try std.testing.allocator.alloc(u8, case.instruction.data.len);
        defer std.testing.allocator.free(data);

        const metadata = fixturePubkey(case.instruction.accounts[0].pubkey);
        const update_authority = fixturePubkey(case.instruction.accounts[1].pubkey);
        const mint = fixturePubkey(case.instruction.accounts[2].pubkey);
        const mint_authority = fixturePubkey(case.instruction.accounts[3].pubkey);
        const program_id = fixturePubkey(case.instruction.program_id);

        const ix = try initialize(
            &program_id,
            &metadata,
            &update_authority,
            &mint,
            &mint_authority,
            case.name,
            case.symbol,
            case.uri,
            &metas,
            data,
        );
        try expectInstructionFixture(ix, case.instruction);
    }

    for (loaded.value.update_field) |case| {
        var metas: UpdateFieldMetas = undefined;
        const data = try std.testing.allocator.alloc(u8, case.instruction.data.len);
        defer std.testing.allocator.free(data);

        const metadata = fixturePubkey(case.instruction.accounts[0].pubkey);
        const update_authority = fixturePubkey(case.instruction.accounts[1].pubkey);
        const program_id = fixturePubkey(case.instruction.program_id);

        const ix = try updateField(
            &program_id,
            &metadata,
            &update_authority,
            fixtureField(case.field),
            case.value,
            &metas,
            data,
        );
        try expectInstructionFixture(ix, case.instruction);
    }

    for (loaded.value.remove_key) |case| {
        var metas: RemoveKeyMetas = undefined;
        const data = try std.testing.allocator.alloc(u8, case.instruction.data.len);
        defer std.testing.allocator.free(data);

        const metadata = fixturePubkey(case.instruction.accounts[0].pubkey);
        const update_authority = fixturePubkey(case.instruction.accounts[1].pubkey);
        const program_id = fixturePubkey(case.instruction.program_id);

        const ix = try removeKey(
            &program_id,
            &metadata,
            &update_authority,
            case.key,
            case.idempotent != 0,
            &metas,
            data,
        );
        try expectInstructionFixture(ix, case.instruction);
    }

    for (loaded.value.update_authority) |case| {
        var metas: UpdateAuthorityMetas = undefined;
        const data = try std.testing.allocator.alloc(u8, case.instruction.data.len);
        defer std.testing.allocator.free(data);

        const metadata = fixturePubkey(case.instruction.accounts[0].pubkey);
        const current_authority = fixturePubkey(case.instruction.accounts[1].pubkey);
        const program_id = fixturePubkey(case.instruction.program_id);

        const ix = try updateAuthority(
            &program_id,
            &metadata,
            &current_authority,
            fixtureMaybeNullPubkey(case.new_authority),
            &metas,
            data,
        );
        try expectInstructionFixture(ix, case.instruction);
    }

    for (loaded.value.emit) |case| {
        var metas: EmitMetas = undefined;
        const data = try std.testing.allocator.alloc(u8, case.instruction.data.len);
        defer std.testing.allocator.free(data);

        const metadata = fixturePubkey(case.instruction.accounts[0].pubkey);
        const program_id = fixturePubkey(case.instruction.program_id);
        const start: ?u64 = if (case.start_is_some != 0) case.start else null;
        const end: ?u64 = if (case.end_is_some != 0) case.end else null;

        const ix = try emit(&program_id, &metadata, start, end, &metas, data);
        try expectInstructionFixture(ix, case.instruction);
    }
}

test {
    std.testing.refAllDecls(@This());
}
