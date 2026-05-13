//! Token-2022 base layout constants.

const std = @import("std");
const state = @import("state.zig");

/// Canonical base mint payload length before any extension storage.
pub const MINT_BASE_LEN: usize = 82;
/// Canonical base token account payload length.
pub const ACCOUNT_BASE_LEN: usize = 165;
/// Mint extension padding starts immediately after the 82-byte mint base.
pub const MINT_PADDING_START: usize = MINT_BASE_LEN;
/// AccountType byte offset for extension-capable mint/account buffers.
pub const ACCOUNT_TYPE_OFFSET: usize = ACCOUNT_BASE_LEN;
/// TLV records begin immediately after the AccountType byte.
pub const TLV_START_OFFSET: usize = ACCOUNT_TYPE_OFFSET + 1;
/// One-past-the-end offset for the zero-padded mint extension prefix.
pub const MINT_PADDING_END: usize = ACCOUNT_TYPE_OFFSET;

pub const Error = error{
    InvalidAccountData,
    WrongAccountType,
    ExtensionNotFound,
};

pub const Record = struct {
    extension_type: u16,
    value: []const u8,
};

pub const Iterator = struct {
    bytes: []const u8,
    offset: usize = 0,

    pub fn next(self: *Iterator) Error!?Record {
        if (self.offset == self.bytes.len) return null;

        const remaining = self.bytes.len - self.offset;
        if (remaining < 4) return error.InvalidAccountData;

        const header = self.bytes[self.offset .. self.offset + 4];
        const extension_type = std.mem.readInt(u16, header[0..2], .little);
        const value_len: usize = std.mem.readInt(u16, header[2..4], .little);
        const value_start = self.offset + 4;
        const value_end = value_start + value_len;
        if (value_end < value_start or value_end > self.bytes.len) {
            return error.InvalidAccountData;
        }

        self.offset = value_end;
        return .{
            .extension_type = extension_type,
            .value = self.bytes[value_start..value_end],
        };
    }
};

pub const Parsed = struct {
    kind: state.AccountType,
    base_data: []const u8,
    tlv_data: []const u8,

    pub inline fn iterator(self: Parsed) Iterator {
        return .{ .bytes = self.tlv_data };
    }

    pub fn findExtension(self: Parsed, extension_type: u16) Error!Record {
        var it = self.iterator();
        var first_match: ?Record = null;

        while (try it.next()) |record| {
            if (first_match == null and record.extension_type == extension_type) {
                first_match = record;
            }
        }

        return first_match orelse error.ExtensionNotFound;
    }
};

pub fn findMintExtension(bytes: []const u8, extension_type: u16) Error!Record {
    return (try parseMint(bytes)).findExtension(extension_type);
}

pub fn findAccountExtension(bytes: []const u8, extension_type: u16) Error!Record {
    return (try parseAccount(bytes)).findExtension(extension_type);
}

pub fn parseMint(bytes: []const u8) Error!Parsed {
    if (isClassicMultisigShape(bytes)) return error.InvalidAccountData;

    if (bytes.len < MINT_BASE_LEN) return error.InvalidAccountData;
    if (bytes.len == MINT_BASE_LEN) {
        return .{
            .kind = .mint,
            .base_data = bytes,
            .tlv_data = &.{},
        };
    }
    if (bytes.len < TLV_START_OFFSET) {
        return if (bytes.len == ACCOUNT_BASE_LEN)
            error.WrongAccountType
        else
            error.InvalidAccountData;
    }

    for (bytes[MINT_PADDING_START..MINT_PADDING_END]) |byte| {
        if (byte != 0) return error.InvalidAccountData;
    }

    const account_type = parseExtensionAccountType(bytes[ACCOUNT_TYPE_OFFSET]) catch {
        return error.InvalidAccountData;
    };
    if (account_type != .mint) return error.WrongAccountType;

    const tlv_data = bytes[TLV_START_OFFSET..];
    try validateTlvRegion(tlv_data);

    return .{
        .kind = .mint,
        .base_data = bytes[0..MINT_BASE_LEN],
        .tlv_data = tlv_data,
    };
}

pub fn parseAccount(bytes: []const u8) Error!Parsed {
    if (isClassicMultisigShape(bytes)) return error.InvalidAccountData;

    if (bytes.len < ACCOUNT_BASE_LEN) {
        return if (bytes.len == MINT_BASE_LEN)
            error.WrongAccountType
        else
            error.InvalidAccountData;
    }
    if (bytes.len == ACCOUNT_BASE_LEN) {
        return .{
            .kind = .account,
            .base_data = bytes,
            .tlv_data = &.{},
        };
    }

    const account_type = parseExtensionAccountType(bytes[ACCOUNT_TYPE_OFFSET]) catch {
        return error.InvalidAccountData;
    };
    if (account_type != .account) return error.WrongAccountType;

    const tlv_data = bytes[TLV_START_OFFSET..];
    try validateTlvRegion(tlv_data);

    return .{
        .kind = .account,
        .base_data = bytes[0..ACCOUNT_BASE_LEN],
        .tlv_data = tlv_data,
    };
}

fn parseExtensionAccountType(tag: u8) error{InvalidAccountData}!state.AccountType {
    return state.parseAccountType(tag) catch error.InvalidAccountData;
}

fn isClassicMultisigShape(bytes: []const u8) bool {
    if (bytes.len != 355) return false;

    const m = bytes[0];
    const n = bytes[1];
    if (m == 0 or n == 0 or m > n or n > 11) return false;
    if (bytes[2] != 1) return false;

    var signer_index: usize = 0;
    while (signer_index < n) : (signer_index += 1) {
        const start = 3 + (signer_index * 32);
        const end = start + 32;
        const signer = bytes[start..end];

        var all_zero = true;
        for (signer) |byte| {
            if (byte != 0) {
                all_zero = false;
                break;
            }
        }
        if (all_zero) return false;
    }

    return true;
}

fn validateTlvRegion(bytes: []const u8) Error!void {
    var it = Iterator{ .bytes = bytes };
    while (try it.next()) |_| {}
}

test "base layout constants are canonical" {
    try std.testing.expectEqual(@as(usize, 82), MINT_BASE_LEN);
    try std.testing.expectEqual(@as(usize, 165), ACCOUNT_BASE_LEN);
    try std.testing.expectEqual(@as(usize, 82), MINT_PADDING_START);
    try std.testing.expectEqual(@as(usize, 165), ACCOUNT_TYPE_OFFSET);
    try std.testing.expectEqual(@as(usize, 166), TLV_START_OFFSET);
    try std.testing.expectEqual(@as(usize, 165), MINT_PADDING_END);
}

fn makeExtensionCapableMint(total_len: usize) [256]u8 {
    std.debug.assert(total_len <= 256);
    var buf = [_]u8{0} ** 256;
    buf[ACCOUNT_TYPE_OFFSET] = @intFromEnum(state.AccountType.mint);
    return buf;
}

fn makeExtensionCapableAccount(total_len: usize) [384]u8 {
    std.debug.assert(total_len <= 384);
    var buf = [_]u8{0} ** 384;
    @memset(buf[0..ACCOUNT_BASE_LEN], 0xAB);
    buf[ACCOUNT_TYPE_OFFSET] = @intFromEnum(state.AccountType.account);
    return buf;
}

fn writeRecord(dst: []u8, extension_type: u16, value: []const u8) usize {
    std.mem.writeInt(u16, dst[0..2], extension_type, .little);
    std.mem.writeInt(u16, dst[2..4], @intCast(value.len), .little);
    @memcpy(dst[4 .. 4 + value.len], value);
    return 4 + value.len;
}

fn expectNoEntries(parsed: anytype) !void {
    var it = parsed.iterator();
    try std.testing.expect((try it.next()) == null);
}

test "parseMint accepts canonical 82-byte base mint without reading extension area" {
    const buf = [_]u8{0x11} ** MINT_BASE_LEN;
    const parsed = try parseMint(&buf);

    try std.testing.expectEqual(state.AccountType.mint, parsed.kind);
    try std.testing.expectEqualSlices(u8, &buf, parsed.base_data);
    try std.testing.expectEqual(@as(usize, 0), parsed.tlv_data.len);
    try expectNoEntries(parsed);
}

test "parseAccount accepts canonical 165-byte base account without TLV header" {
    const buf = [_]u8{0x22} ** ACCOUNT_BASE_LEN;
    const parsed = try parseAccount(&buf);

    try std.testing.expectEqual(state.AccountType.account, parsed.kind);
    try std.testing.expectEqualSlices(u8, &buf, parsed.base_data);
    try std.testing.expectEqual(@as(usize, 0), parsed.tlv_data.len);
    try expectNoEntries(parsed);
}

test "extension-capable mint validates zero padding and mint account type" {
    var good = makeExtensionCapableMint(TLV_START_OFFSET + 7);
    _ = writeRecord(good[TLV_START_OFFSET .. TLV_START_OFFSET + 7], 0x1234, "abc");

    const parsed = try parseMint(good[0 .. TLV_START_OFFSET + 7]);
    const record = try parsed.findExtension(0x1234);
    try std.testing.expectEqual(@as(u16, 0x1234), record.extension_type);
    try std.testing.expectEqualStrings("abc", record.value);

    var bad_padding = good;
    bad_padding[MINT_PADDING_START + 10] = 1;
    try std.testing.expectError(error.InvalidAccountData, parseMint(bad_padding[0 .. TLV_START_OFFSET + 7]));

    var wrong_type = good;
    wrong_type[ACCOUNT_TYPE_OFFSET] = @intFromEnum(state.AccountType.account);
    try std.testing.expectError(error.WrongAccountType, parseMint(wrong_type[0 .. TLV_START_OFFSET + 7]));
}

test "extension-capable account validates account type without mint padding rule" {
    var good = makeExtensionCapableAccount(TLV_START_OFFSET + 6);
    _ = writeRecord(good[TLV_START_OFFSET .. TLV_START_OFFSET + 6], 0x4321, "xy");

    const parsed = try parseAccount(good[0 .. TLV_START_OFFSET + 6]);
    const record = try parsed.findExtension(0x4321);
    try std.testing.expectEqual(@as(u16, 0x4321), record.extension_type);
    try std.testing.expectEqualStrings("xy", record.value);

    var wrong_type = good;
    wrong_type[ACCOUNT_TYPE_OFFSET] = @intFromEnum(state.AccountType.mint);
    try std.testing.expectError(error.WrongAccountType, parseAccount(wrong_type[0 .. TLV_START_OFFSET + 6]));

    var invalid_type = good;
    invalid_type[ACCOUNT_TYPE_OFFSET] = 255;
    try std.testing.expectError(error.InvalidAccountData, parseAccount(invalid_type[0 .. TLV_START_OFFSET + 6]));

    var non_zero_prefix = good;
    non_zero_prefix[MINT_PADDING_START + 3] = 0xFE;
    _ = try parseAccount(non_zero_prefix[0 .. TLV_START_OFFSET + 6]);
}

test "TLV scanning starts at offset 166, decodes little-endian headers, and returns zero-copy slices" {
    var buf = makeExtensionCapableMint(TLV_START_OFFSET + 7);
    buf[TLV_START_OFFSET - 1] = @intFromEnum(state.AccountType.mint);
    _ = writeRecord(buf[TLV_START_OFFSET .. TLV_START_OFFSET + 7], 0x1234, "zig");

    const parsed = try parseMint(buf[0 .. TLV_START_OFFSET + 7]);
    var it = parsed.iterator();
    const record = (try it.next()).?;

    try std.testing.expectEqual(@as(u16, 0x1234), record.extension_type);
    try std.testing.expectEqual(@as(usize, 3), record.value.len);
    try std.testing.expectEqualStrings("zig", record.value);
    try std.testing.expectEqual(@intFromPtr(&buf[TLV_START_OFFSET + 4]), @intFromPtr(record.value.ptr));
    try std.testing.expect((try it.next()) == null);
}

test "TLV iterator scans multiple entries in order, skips unknown records, and handles duplicates deterministically" {
    var buf = makeExtensionCapableAccount(TLV_START_OFFSET + 20);
    var off: usize = TLV_START_OFFSET;
    off += writeRecord(buf[off .. off + 5], 0x9999, "u");
    off += writeRecord(buf[off .. off + 6], 0x0102, "ab");
    off += writeRecord(buf[off .. off + 5], 0x0102, "c");

    const parsed = try parseAccount(buf[0..off]);
    var it = parsed.iterator();

    const first = (try it.next()).?;
    const second = (try it.next()).?;
    const third = (try it.next()).?;

    try std.testing.expectEqual(@as(u16, 0x9999), first.extension_type);
    try std.testing.expectEqual(@as(u16, 0x0102), second.extension_type);
    try std.testing.expectEqual(@as(u16, 0x0102), third.extension_type);
    try std.testing.expectEqualStrings("ab", (try parsed.findExtension(0x0102)).value);
    try std.testing.expect((try it.next()) == null);
}

test "TLV iterator rejects short headers and value overruns while leaving input unchanged" {
    inline for ([_]usize{ 1, 2, 3 }) |tail_len| {
        var short_tail = makeExtensionCapableMint(TLV_START_OFFSET + tail_len);
        const before = short_tail;
        try std.testing.expectError(error.InvalidAccountData, parseMint(short_tail[0 .. TLV_START_OFFSET + tail_len]));
        try std.testing.expectEqualSlices(u8, before[0 .. TLV_START_OFFSET + tail_len], short_tail[0 .. TLV_START_OFFSET + tail_len]);
    }

    var overrun = makeExtensionCapableAccount(TLV_START_OFFSET + 4);
    std.mem.writeInt(u16, overrun[TLV_START_OFFSET .. TLV_START_OFFSET + 2], 7, .little);
    std.mem.writeInt(u16, overrun[TLV_START_OFFSET + 2 .. TLV_START_OFFSET + 4], 8, .little);
    const before = overrun;
    try std.testing.expectError(error.InvalidAccountData, parseAccount(overrun[0 .. TLV_START_OFFSET + 4]));
    try std.testing.expectEqualSlices(u8, before[0 .. TLV_START_OFFSET + 4], overrun[0 .. TLV_START_OFFSET + 4]);
}

test "zero-length entries and empty extension regions are accepted" {
    var zero_len = makeExtensionCapableMint(TLV_START_OFFSET + 9);
    var off: usize = TLV_START_OFFSET;
    off += writeRecord(zero_len[off .. off + 4], 9, "");
    off += writeRecord(zero_len[off .. off + 5], 10, "z");

    const parsed = try parseMint(zero_len[0..off]);
    var it = parsed.iterator();
    const first = (try it.next()).?;
    const second = (try it.next()).?;
    try std.testing.expectEqual(@as(u16, 9), first.extension_type);
    try std.testing.expectEqual(@as(usize, 0), first.value.len);
    try std.testing.expectEqualStrings("z", second.value);
    try std.testing.expect((try it.next()) == null);

    const empty_mint = try parseMint(makeExtensionCapableMint(TLV_START_OFFSET)[0..TLV_START_OFFSET]);
    try expectNoEntries(empty_mint);

    const empty_account = try parseAccount(makeExtensionCapableAccount(TLV_START_OFFSET)[0..TLV_START_OFFSET]);
    try expectNoEntries(empty_account);
}

test "short buffers, mint prefix gaps, and cross-kind base lengths are classified safely" {
    const short_mint = [_]u8{0} ** (MINT_BASE_LEN - 1);
    try std.testing.expectError(error.InvalidAccountData, parseMint(&short_mint));

    const short_account = [_]u8{0} ** (ACCOUNT_BASE_LEN - 1);
    try std.testing.expectError(error.InvalidAccountData, parseAccount(&short_account));

    const mint_gap_83 = [_]u8{0} ** 83;
    const mint_gap_164 = [_]u8{0} ** 164;
    const mint_gap_165 = [_]u8{0} ** 165;
    try std.testing.expectError(error.InvalidAccountData, parseMint(&mint_gap_83));
    try std.testing.expectError(error.InvalidAccountData, parseMint(&mint_gap_164));
    try std.testing.expectError(error.WrongAccountType, parseMint(&mint_gap_165));

    const base_mint = [_]u8{0} ** MINT_BASE_LEN;
    const base_account = [_]u8{0} ** ACCOUNT_BASE_LEN;
    try std.testing.expectError(error.WrongAccountType, parseAccount(&base_mint));
    try std.testing.expectError(error.WrongAccountType, parseMint(&base_account));
}

test "classic multisig-shaped data is rejected for both mint and account parsers" {
    var multisig = [_]u8{0} ** 355;
    multisig[0] = 2;
    multisig[1] = 3;
    multisig[2] = 1;
    @memset(multisig[3..35], 0x11);
    @memset(multisig[35..67], 0x22);
    @memset(multisig[67..99], 0x33);
    multisig[ACCOUNT_TYPE_OFFSET] = @intFromEnum(state.AccountType.account);
    _ = writeRecord(multisig[TLV_START_OFFSET .. TLV_START_OFFSET + 5], 0x4444, "x");

    try std.testing.expectError(error.InvalidAccountData, parseAccount(&multisig));

    multisig[ACCOUNT_TYPE_OFFSET] = @intFromEnum(state.AccountType.mint);
    try std.testing.expectError(error.InvalidAccountData, parseMint(&multisig));
}

test "missing extension is distinct from malformed data and lookup validates malformed tails after matches" {
    var valid = makeExtensionCapableAccount(TLV_START_OFFSET + 11);
    var off: usize = TLV_START_OFFSET;
    off += writeRecord(valid[off .. off + 6], 1, "ab");
    off += writeRecord(valid[off .. off + 5], 2, "c");

    const parsed = try parseAccount(valid[0..off]);
    try std.testing.expectError(error.ExtensionNotFound, parsed.findExtension(3));

    var malformed_after_match = valid;
    std.mem.writeInt(u16, malformed_after_match[off..][0..2], 9, .little);
    std.mem.writeInt(u16, malformed_after_match[off + 2 ..][0..2], 10, .little);
    try std.testing.expectError(error.InvalidAccountData, findAccountExtension(malformed_after_match[0 .. off + 4], 1));

    var duplicate_then_malformed = makeExtensionCapableAccount(TLV_START_OFFSET + 15);
    var dup_off: usize = TLV_START_OFFSET;
    dup_off += writeRecord(duplicate_then_malformed[dup_off .. dup_off + 5], 7, "a");
    dup_off += writeRecord(duplicate_then_malformed[dup_off .. dup_off + 5], 7, "b");
    std.mem.writeInt(u16, duplicate_then_malformed[dup_off..][0..2], 8, .little);
    std.mem.writeInt(u16, duplicate_then_malformed[dup_off + 2 ..][0..2], 9, .little);
    try std.testing.expectError(error.InvalidAccountData, findAccountExtension(duplicate_then_malformed[0 .. dup_off + 4], 7));
}
