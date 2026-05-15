//! Instruction discriminators, payload types, and `TokenMetadataInstruction` Borsh layout.

const std = @import("std");
const sol = @import("solana_program_sdk");
const codec = @import("solana_codec");
const id = @import("id.zig");
const metadata_state = @import("state.zig");
const MaybeNullPubkey = @import("maybe_null_pubkey.zig").MaybeNullPubkey;

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
        return codec.borshOptionU64Len(self.start) + codec.borshOptionU64Len(self.end);
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

        const UnpackRow = struct {
            disc: *const [sol.DISCRIMINATOR_LEN]u8,
            parse: *const fn ([]const u8) ProgramError!TokenMetadataInstruction,
        };
        const unpack_table = [_]UnpackRow{
            .{ .disc = &INITIALIZE_DISCRIMINATOR, .parse = unpackInitialize },
            .{ .disc = &UPDATE_FIELD_DISCRIMINATOR, .parse = unpackUpdateField },
            .{ .disc = &REMOVE_KEY_DISCRIMINATOR, .parse = unpackRemoveKey },
            .{ .disc = &UPDATE_AUTHORITY_DISCRIMINATOR, .parse = unpackUpdateAuthority },
            .{ .disc = &EMIT_DISCRIMINATOR, .parse = unpackEmit },
        };

        inline for (unpack_table) |row| {
            if (std.mem.eql(u8, discriminator, row.disc)) {
                return try row.parse(payload);
            }
        }

        return ProgramError.InvalidInstructionData;
    }
};

fn unpackInitialize(payload: []const u8) ProgramError!TokenMetadataInstruction {
    return .{ .initialize = try Initialize.parse(payload) };
}
fn unpackUpdateField(payload: []const u8) ProgramError!TokenMetadataInstruction {
    return .{ .update_field = try UpdateField.parse(payload) };
}
fn unpackRemoveKey(payload: []const u8) ProgramError!TokenMetadataInstruction {
    return .{ .remove_key = try RemoveKey.parse(payload) };
}
fn unpackUpdateAuthority(payload: []const u8) ProgramError!TokenMetadataInstruction {
    return .{ .update_authority = try UpdateAuthority.parse(payload) };
}
fn unpackEmit(payload: []const u8) ProgramError!TokenMetadataInstruction {
    return .{ .emit = try Emit.parse(payload) };
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

    fn readOptionU64(self: *Cursor) ProgramError!?u64 {
        const parsed = codec.readBorshOptionU64(self.input[self.index..]) catch
            return ProgramError.InvalidInstructionData;
        self.index = std.math.add(usize, self.index, parsed.len) catch
            return ProgramError.InvalidInstructionData;
        return parsed.value;
    }

    fn readBorshString(self: *Cursor) ProgramError![]const u8 {
        const parsed = codec.readBorshString(self.input[self.index..]) catch return ProgramError.InvalidInstructionData;
        self.index = std.math.add(usize, self.index, parsed.len) catch
            return ProgramError.InvalidInstructionData;
        return parsed.value;
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
    return codec.borshStringLen(value) catch |err| switch (err) {
        error.LengthOverflow => error.LengthOverflow,
        error.BufferTooSmall,
        error.InputTooShort,
        error.NonCanonicalShortVec,
        error.InvalidCOptionTag,
        => unreachable,
    };
}

fn writeBorshString(out: []u8, value: []const u8) BuildError!usize {
    return codec.writeBorshString(out, value) catch |err| switch (err) {
        error.LengthOverflow => return error.LengthOverflow,
        error.BufferTooSmall => return error.InvalidInstructionDataSliceLength,
        error.InputTooShort,
        error.NonCanonicalShortVec,
        error.InvalidCOptionTag,
        => unreachable,
    };
}

fn writeOptionU64(out: []u8, value: ?u64) BuildError!usize {
    return codec.writeBorshOptionU64(out, value) catch |err| switch (err) {
        error.BufferTooSmall => return error.InvalidInstructionDataSliceLength,
        error.InputTooShort,
        error.LengthOverflow,
        error.NonCanonicalShortVec,
        error.InvalidCOptionTag,
        => unreachable,
    };
}
