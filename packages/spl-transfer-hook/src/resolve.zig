//! SPL Transfer Hook validation PDA derivation and future account
//! resolution helpers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const meta = @import("meta.zig");
const instruction = @import("instruction.zig");

const Pubkey = sol.Pubkey;
const ProgramError = sol.ProgramError;

pub const ProgramDerivedAddress = sol.pda.ProgramDerivedAddress;
pub const EXTRA_ACCOUNT_METAS_SEED = "extra-account-metas";
pub const tlv_entry_header_len: usize = sol.DISCRIMINATOR_LEN + @sizeOf(u32);
pub const extra_account_meta_list_value_header_len: usize = @sizeOf(u32);
pub const extra_account_meta_list_tlv_overhead_len: usize = tlv_entry_header_len + extra_account_meta_list_value_header_len;

pub fn findValidationAddress(
    mint: *const Pubkey,
    hook_program_id: *const Pubkey,
) ProgramDerivedAddress {
    return sol.pda.findProgramAddress(
        &.{ EXTRA_ACCOUNT_METAS_SEED, mint },
        hook_program_id,
    ) catch unreachable;
}

pub fn extraAccountMetaListTlvDataLen(extra_account_metas_len: usize) ProgramError!usize {
    const records_len = std.math.mul(usize, extra_account_metas_len, meta.EXTRA_ACCOUNT_META_LEN)
        catch return ProgramError.InvalidAccountData;
    const value_len = std.math.add(usize, extra_account_meta_list_value_header_len, records_len)
        catch return ProgramError.InvalidAccountData;
    return std.math.add(usize, tlv_entry_header_len, value_len)
        catch return ProgramError.InvalidAccountData;
}

fn unpackExtraAccountMetaListValue(value: []const u8) ProgramError!meta.ExtraAccountMetaSlice {
    if (value.len < extra_account_meta_list_value_header_len) return ProgramError.InvalidAccountData;

    const count = sol.instruction.tryReadUnaligned(u32, value, 0)
        orelse return ProgramError.InvalidAccountData;
    const records = value[extra_account_meta_list_value_header_len..];
    const expected_records_len = std.math.mul(usize, @as(usize, count), meta.EXTRA_ACCOUNT_META_LEN)
        catch return ProgramError.InvalidAccountData;
    if (records.len != expected_records_len) return ProgramError.InvalidAccountData;

    const extra_account_metas = try meta.ExtraAccountMetaSlice.init(records);
    try extra_account_metas.validateAll();
    return extra_account_metas;
}

pub fn unpackExecuteExtraAccountMetaList(data: []const u8) ProgramError!meta.ExtraAccountMetaSlice {
    var offset: usize = 0;
    var execute_value: ?[]const u8 = null;

    while (offset < data.len) {
        const remaining_len = data.len - offset;
        if (remaining_len < tlv_entry_header_len) return ProgramError.InvalidAccountData;

        const discriminator = data[offset..][0..sol.DISCRIMINATOR_LEN];
        const value_len_slice = data[offset + sol.DISCRIMINATOR_LEN ..][0..@sizeOf(u32)];
        const value_len_u32 = std.mem.readInt(u32, value_len_slice, .little);
        const value_len: usize = value_len_u32;
        const value_start = std.math.add(usize, offset, tlv_entry_header_len)
            catch return ProgramError.InvalidAccountData;
        const next_offset = std.math.add(usize, value_start, value_len)
            catch return ProgramError.InvalidAccountData;
        if (next_offset > data.len) return ProgramError.InvalidAccountData;

        if (std.mem.eql(u8, discriminator, &instruction.EXECUTE_DISCRIMINATOR)) {
            if (execute_value != null) return ProgramError.InvalidAccountData;
            execute_value = data[value_start..next_offset];
        }

        offset = next_offset;
    }

    return unpackExtraAccountMetaListValue(execute_value orelse return ProgramError.InvalidAccountData);
}

fn expectValidationVector(
    mint: *const Pubkey,
    hook_program_id: *const Pubkey,
    expected_bump_seed: u8,
    expected_address: *const Pubkey,
) !void {
    const Self = @This();
    try std.testing.expect(@hasDecl(Self, "findValidationAddress"));
    if (!@hasDecl(Self, "findValidationAddress")) return;

    const find_validation_address = @field(Self, "findValidationAddress");
    const actual = find_validation_address(mint, hook_program_id);
    try std.testing.expectEqual(expected_bump_seed, actual.bump_seed);
    try std.testing.expectEqualSlices(u8, expected_address, &actual.address);
}

test "resolve exposes canonical extra-account-metas seed bytes" {
    const Self = @This();
    try std.testing.expect(@hasDecl(Self, "EXTRA_ACCOUNT_METAS_SEED"));
    if (!@hasDecl(Self, "EXTRA_ACCOUNT_METAS_SEED")) return;

    const extra_account_metas_seed = @field(Self, "EXTRA_ACCOUNT_METAS_SEED");
    try std.testing.expectEqualStrings("extra-account-metas", extra_account_metas_seed);
}

test "findValidationAddress matches canonical seed and program-specific golden vectors" {
    const mint_a: Pubkey = .{0x11} ** 32;
    const mint_b: Pubkey = .{0x22} ** 32;
    const hook_program_a: Pubkey = .{0xa1} ** 32;
    const hook_program_b: Pubkey = .{0xb2} ** 32;

    const expected_a_a: Pubkey = .{ 55, 49, 232, 125, 247, 117, 73, 26, 57, 218, 226, 59, 26, 145, 183, 14, 234, 21, 131, 15, 67, 179, 215, 205, 253, 81, 22, 155, 105, 89, 189, 71 };
    const expected_a_b: Pubkey = .{ 11, 167, 177, 207, 201, 85, 227, 141, 97, 112, 150, 42, 115, 216, 51, 246, 5, 182, 248, 28, 41, 165, 184, 178, 152, 91, 129, 202, 108, 94, 180, 202 };
    const expected_b_a: Pubkey = .{ 91, 253, 165, 84, 93, 156, 222, 200, 255, 60, 244, 92, 91, 60, 160, 54, 124, 235, 60, 194, 27, 247, 253, 207, 187, 237, 56, 91, 24, 116, 254, 177 };
    const expected_b_b: Pubkey = .{ 150, 147, 209, 64, 248, 20, 55, 68, 31, 177, 76, 58, 240, 58, 15, 189, 85, 115, 239, 27, 111, 53, 86, 121, 173, 153, 25, 194, 14, 74, 240, 58 };

    try expectValidationVector(&mint_a, &hook_program_a, 253, &expected_a_a);
    try expectValidationVector(&mint_a, &hook_program_b, 253, &expected_a_b);
    try expectValidationVector(&mint_b, &hook_program_a, 255, &expected_b_a);
    try expectValidationVector(&mint_b, &hook_program_b, 253, &expected_b_b);
}

fn expectExtraAccountMeta(
    actual: meta.ExtraAccountMeta,
    expected: meta.ExtraAccountMeta,
) !void {
    try std.testing.expectEqual(expected.discriminator, actual.discriminator);
    try std.testing.expectEqualSlices(u8, &expected.address_config, &actual.address_config);
    try std.testing.expectEqual(expected.is_signer, actual.is_signer);
    try std.testing.expectEqual(expected.is_writable, actual.is_writable);
}

fn writeTestTlvEntry(
    discriminator: *const [sol.DISCRIMINATOR_LEN]u8,
    value: []const u8,
    dst: []u8,
) void {
    @memcpy(dst[0..sol.DISCRIMINATOR_LEN], discriminator);
    std.mem.writeInt(u32, dst[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u32)], @intCast(value.len), .little);
    @memcpy(dst[tlv_entry_header_len..][0..value.len], value);
}

test "ExtraAccountMetaList TLV size math is canonical" {
    try std.testing.expectEqual(@as(usize, 12), tlv_entry_header_len);
    try std.testing.expectEqual(@as(usize, 16), extra_account_meta_list_tlv_overhead_len);
    try std.testing.expectEqual(@as(usize, 16), try extraAccountMetaListTlvDataLen(0));
    try std.testing.expectEqual(@as(usize, 51), try extraAccountMetaListTlvDataLen(1));
    try std.testing.expectEqual(@as(usize, 86), try extraAccountMetaListTlvDataLen(2));
    try std.testing.expectError(ProgramError.InvalidAccountData, extraAccountMetaListTlvDataLen(std.math.maxInt(usize)));
}

test "Execute TLV lookup selects only Execute metas and rejects duplicate or malformed entries" {
    const pubkey_a: Pubkey = .{0x41} ** 32;
    const pubkey_b: Pubkey = .{0x52} ** 32;
    const fixed_a = meta.ExtraAccountMeta.fixed(&pubkey_a, false, true);
    const fixed_b = meta.ExtraAccountMeta.fixed(&pubkey_b, true, false);

    var execute_value: [4 + meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    std.mem.writeInt(u32, execute_value[0..4], 1, .little);
    fixed_a.write(execute_value[4..][0..meta.EXTRA_ACCOUNT_META_LEN]);

    var wrong_value: [4 + meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    std.mem.writeInt(u32, wrong_value[0..4], 1, .little);
    fixed_b.write(wrong_value[4..][0..meta.EXTRA_ACCOUNT_META_LEN]);

    const wrong_discriminator = [_]u8{0xaa} ** sol.DISCRIMINATOR_LEN;
    var mixed_tlv: [2 * tlv_entry_header_len + execute_value.len + wrong_value.len]u8 = undefined;
    writeTestTlvEntry(&wrong_discriminator, wrong_value[0..], mixed_tlv[0 .. tlv_entry_header_len + wrong_value.len]);
    writeTestTlvEntry(
        &instruction.EXECUTE_DISCRIMINATOR,
        execute_value[0..],
        mixed_tlv[tlv_entry_header_len + wrong_value.len ..],
    );

    const parsed = try unpackExecuteExtraAccountMetaList(mixed_tlv[0..]);
    try std.testing.expectEqual(@as(usize, 1), parsed.len());
    try expectExtraAccountMeta(fixed_a, try parsed.get(0));

    var wrong_only: [tlv_entry_header_len + wrong_value.len]u8 = undefined;
    writeTestTlvEntry(&wrong_discriminator, wrong_value[0..], wrong_only[0..]);
    try std.testing.expectError(ProgramError.InvalidAccountData, unpackExecuteExtraAccountMetaList(wrong_only[0..]));

    var duplicate: [2 * (tlv_entry_header_len + execute_value.len)]u8 = undefined;
    writeTestTlvEntry(
        &instruction.EXECUTE_DISCRIMINATOR,
        execute_value[0..],
        duplicate[0 .. tlv_entry_header_len + execute_value.len],
    );
    writeTestTlvEntry(
        &instruction.EXECUTE_DISCRIMINATOR,
        wrong_value[0..],
        duplicate[tlv_entry_header_len + execute_value.len ..],
    );
    try std.testing.expectError(ProgramError.InvalidAccountData, unpackExecuteExtraAccountMetaList(duplicate[0..]));

    var short_header = [_]u8{0} ** (tlv_entry_header_len - 1);
    try std.testing.expectError(ProgramError.InvalidAccountData, unpackExecuteExtraAccountMetaList(short_header[0..]));

    var truncated_value = [_]u8{0} ** (tlv_entry_header_len + 3);
    @memcpy(truncated_value[0..sol.DISCRIMINATOR_LEN], &instruction.EXECUTE_DISCRIMINATOR);
    std.mem.writeInt(u32, truncated_value[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u32)], 4, .little);
    try std.testing.expectError(ProgramError.InvalidAccountData, unpackExecuteExtraAccountMetaList(truncated_value[0..]));
}
