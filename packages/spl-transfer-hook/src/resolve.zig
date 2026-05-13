//! SPL Transfer Hook validation PDA derivation and future account
//! resolution helpers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const meta = @import("meta.zig");
const instruction = @import("instruction.zig");
const account_resolution_parity_fixture = @import("account_resolution_parity_fixture.zig");
const seed = @import("seed.zig");
const Seed = seed.Seed;
const pubkey_data = @import("pubkey_data.zig");
const PubkeyData = pubkey_data.PubkeyData;

const AccountMeta = sol.cpi.AccountMeta;
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

pub const AccountKeyData = struct {
    key: *const Pubkey,
    data: ?[]const u8 = null,
};

pub fn resolveExtraAccountMeta(
    extra_account_meta: *const meta.ExtraAccountMeta,
    instruction_data: []const u8,
    hook_program_id: *const Pubkey,
    account_key_data: []const AccountKeyData,
    out_pubkey: *Pubkey,
) ProgramError!AccountMeta {
    try extra_account_meta.validate();

    switch (extra_account_meta.discriminator) {
        meta.ACCOUNT_META_DISCRIMINATOR => {
            out_pubkey.* = extra_account_meta.address_config;
        },
        meta.HOOK_PROGRAM_PDA_DISCRIMINATOR => {
            out_pubkey.* = try resolveDynamicPda(
                &extra_account_meta.address_config,
                instruction_data,
                hook_program_id,
                account_key_data,
                &.{},
            );
        },
        meta.PUBKEY_DATA_DISCRIMINATOR => {
            out_pubkey.* = try resolvePubkeyData(
                &extra_account_meta.address_config,
                instruction_data,
                account_key_data,
                &.{},
            );
        },
        else => |discriminator| {
            if (discriminator < meta.EXTERNAL_PDA_DISCRIMINATOR_MIN) return ProgramError.InvalidAccountData;
            const program_index = discriminator - meta.EXTERNAL_PDA_DISCRIMINATOR_MIN;
            const program_id = lookupAccount(program_index, account_key_data, &.{})
                orelse return ProgramError.InvalidAccountData;
            out_pubkey.* = try resolveDynamicPda(
                &extra_account_meta.address_config,
                instruction_data,
                program_id.key,
                account_key_data,
                &.{},
            );
        },
    }

    return .{
        .pubkey = out_pubkey,
        .is_signer = extra_account_meta.is_signer,
        .is_writable = extra_account_meta.is_writable,
    };
}

pub fn resolveExtraAccountMetaList(
    extra_account_metas: meta.ExtraAccountMetaSlice,
    instruction_data: []const u8,
    hook_program_id: *const Pubkey,
    base_accounts: []const AccountKeyData,
    out_metas: []AccountMeta,
    out_keys: []Pubkey,
) ProgramError![]const AccountMeta {
    if (out_metas.len < extra_account_metas.len()) return ProgramError.InvalidAccountData;
    if (out_keys.len < extra_account_metas.len()) return ProgramError.InvalidAccountData;

    for (0..extra_account_metas.len()) |i| {
        const extra_account_meta = try extra_account_metas.get(i);
        try extra_account_meta.validate();

        switch (extra_account_meta.discriminator) {
            meta.ACCOUNT_META_DISCRIMINATOR => {
                out_keys[i] = extra_account_meta.address_config;
            },
            meta.HOOK_PROGRAM_PDA_DISCRIMINATOR => {
                out_keys[i] = try resolveDynamicPda(
                    &extra_account_meta.address_config,
                    instruction_data,
                    hook_program_id,
                    base_accounts,
                    out_keys[0..i],
                );
            },
            meta.PUBKEY_DATA_DISCRIMINATOR => {
                out_keys[i] = try resolvePubkeyData(
                    &extra_account_meta.address_config,
                    instruction_data,
                    base_accounts,
                    out_keys[0..i],
                );
            },
            else => |discriminator| {
                if (discriminator < meta.EXTERNAL_PDA_DISCRIMINATOR_MIN) return ProgramError.InvalidAccountData;
                const program_index = discriminator - meta.EXTERNAL_PDA_DISCRIMINATOR_MIN;
                const program_id = lookupAccount(program_index, base_accounts, out_keys[0..i])
                    orelse return ProgramError.InvalidAccountData;
                out_keys[i] = try resolveDynamicPda(
                    &extra_account_meta.address_config,
                    instruction_data,
                    program_id.key,
                    base_accounts,
                    out_keys[0..i],
                );
            },
        }

        out_metas[i] = .{
            .pubkey = &out_keys[i],
            .is_signer = extra_account_meta.is_signer,
            .is_writable = extra_account_meta.is_writable,
        };
    }

    return out_metas[0..extra_account_metas.len()];
}

fn resolveDynamicPda(
    address_config: *const [32]u8,
    instruction_data: []const u8,
    program_id: *const Pubkey,
    base_accounts: []const AccountKeyData,
    resolved_keys: []const Pubkey,
) ProgramError!Pubkey {
    var resolved_seeds: [seed.max_seed_configs_per_address_config][]const u8 = undefined;
    var resolved_seed_count: usize = 0;
    var it = seed.iterator(address_config);

    while (try it.next()) |seed_config| {
        if (resolved_seed_count >= resolved_seeds.len) return ProgramError.InvalidAccountData;
        resolved_seeds[resolved_seed_count] = switch (seed_config) {
            .literal => |bytes| bytes,
            .instruction_data => |source| try resolveInstructionDataSeed(instruction_data, source.index, source.length),
            .account_key => |source| blk: {
                const account = lookupAccount(source.index, base_accounts, resolved_keys)
                    orelse return ProgramError.InvalidAccountData;
                break :blk account.key[0..];
            },
            .account_data => |source| blk: {
                const account = lookupAccount(source.account_index, base_accounts, resolved_keys)
                    orelse return ProgramError.InvalidAccountData;
                const account_data = account.data orelse return ProgramError.InvalidAccountData;
                break :blk try resolveInstructionDataSeed(account_data, source.data_index, source.length);
            },
        };
        resolved_seed_count += 1;
    }

    return (try sol.pda.findProgramAddress(resolved_seeds[0..resolved_seed_count], program_id)).address;
}

fn resolveInstructionDataSeed(bytes: []const u8, start: u8, length: u8) ProgramError![]const u8 {
    if (length > sol.pda.MAX_SEED_LEN) return ProgramError.InvalidAccountData;
    const begin: usize = start;
    const end = std.math.add(usize, begin, @as(usize, length)) catch return ProgramError.InvalidAccountData;
    if (end > bytes.len) return ProgramError.InvalidAccountData;
    return bytes[begin..end];
}

fn resolvePubkeyData(
    address_config: *const [32]u8,
    instruction_data: []const u8,
    base_accounts: []const AccountKeyData,
    resolved_keys: []const Pubkey,
) ProgramError!Pubkey {
    return switch (try pubkey_data.unpackAddressConfig(address_config)) {
        .instruction_data => |source| try resolvePubkeyBytes(instruction_data, source.index),
        .account_data => |source| blk: {
            const account = lookupAccount(source.account_index, base_accounts, resolved_keys)
                orelse return ProgramError.InvalidAccountData;
            const account_data = account.data orelse return ProgramError.InvalidAccountData;
            break :blk try resolvePubkeyBytes(account_data, source.data_index);
        },
    };
}

fn resolvePubkeyBytes(bytes: []const u8, start: u8) ProgramError!Pubkey {
    const begin: usize = start;
    const end = std.math.add(usize, begin, @sizeOf(Pubkey)) catch return ProgramError.InvalidAccountData;
    if (end > bytes.len) return ProgramError.InvalidAccountData;

    var pubkey: Pubkey = undefined;
    @memcpy(&pubkey, bytes[begin..end]);
    return pubkey;
}

fn lookupAccount(
    index: u8,
    base_accounts: []const AccountKeyData,
    resolved_keys: []const Pubkey,
) ?AccountKeyData {
    const idx: usize = index;
    if (idx < base_accounts.len) return base_accounts[idx];

    const resolved_index = idx -| base_accounts.len;
    if (resolved_index >= resolved_keys.len) return null;
    return .{
        .key = &resolved_keys[resolved_index],
        .data = null,
    };
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

test "dynamic metas resolve canonical internal and external PDAs" {
    const hook_program_id: Pubkey = .{0x91} ** 32;
    const external_program_id: Pubkey = .{0x72} ** 32;
    const account_key: Pubkey = .{0x33} ** 32;
    const account_data = [_]u8{ 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff };
    const instruction_data = [_]u8{ 0x99, 0x10, 0x20, 0x30, 0x40, 0x55 };

    const seeds = [_]Seed{
        .{ .literal = "vault" },
        .{ .instruction_data = .{ .index = 1, .length = 4 } },
        .{ .account_key = .{ .index = 0 } },
        .{ .account_data = .{ .account_index = 0, .data_index = 1, .length = 3 } },
    };

    const base_accounts = [_]AccountKeyData{
        .{ .key = &account_key, .data = account_data[0..] },
        .{ .key = &external_program_id, .data = null },
    };

    const internal_meta = try meta.ExtraAccountMeta.hookProgramDerived(&seeds, false, true);
    const external_meta = try meta.ExtraAccountMeta.externalProgramDerived(1, &seeds, true, false);

    var resolved_internal_key: Pubkey = undefined;
    var resolved_external_key: Pubkey = undefined;
    const resolved_internal = try resolveExtraAccountMeta(
        &internal_meta,
        instruction_data[0..],
        &hook_program_id,
        base_accounts[0..],
        &resolved_internal_key,
    );
    const resolved_external = try resolveExtraAccountMeta(
        &external_meta,
        instruction_data[0..],
        &hook_program_id,
        base_accounts[0..],
        &resolved_external_key,
    );

    const expected_internal = sol.pda.findProgramAddress(
        &.{
            "vault",
            instruction_data[1..5],
            &account_key,
            account_data[1..4],
        },
        &hook_program_id,
    ) catch unreachable;
    const expected_external = sol.pda.findProgramAddress(
        &.{
            "vault",
            instruction_data[1..5],
            &account_key,
            account_data[1..4],
        },
        &external_program_id,
    ) catch unreachable;

    try std.testing.expectEqualSlices(u8, &expected_internal.address, resolved_internal.pubkey[0..]);
    try std.testing.expectEqual(@as(u8, 0), resolved_internal.is_signer);
    try std.testing.expectEqual(@as(u8, 1), resolved_internal.is_writable);

    try std.testing.expectEqualSlices(u8, &expected_external.address, resolved_external.pubkey[0..]);
    try std.testing.expectEqual(@as(u8, 1), resolved_external.is_signer);
    try std.testing.expectEqual(@as(u8, 0), resolved_external.is_writable);
}

test "pubkey-data metas resolve from canonical instruction and account data sources" {
    const hook_program_id: Pubkey = .{0x44} ** 32;
    const instruction_key: Pubkey = .{0xa1} ** 32;
    const account_key: Pubkey = .{0xb2} ** 32;
    const account_key_data = [_]u8{0xcc} ** 32;

    var instruction_data: [40]u8 = .{0} ** 40;
    @memcpy(instruction_data[8..40], &instruction_key);

    const base_accounts = [_]AccountKeyData{
        .{ .key = &account_key, .data = account_key_data[0..] },
    };

    const instruction_meta = try meta.ExtraAccountMeta.pubkeyData(
        PubkeyData{ .instruction_data = .{ .index = 8 } },
        false,
        true,
    );
    const account_meta = try meta.ExtraAccountMeta.pubkeyData(
        PubkeyData{ .account_data = .{ .account_index = 0, .data_index = 0 } },
        true,
        false,
    );

    var resolved_instruction_key: Pubkey = undefined;
    var resolved_account_key: Pubkey = undefined;
    const resolved_instruction = try resolveExtraAccountMeta(
        &instruction_meta,
        instruction_data[0..],
        &hook_program_id,
        base_accounts[0..],
        &resolved_instruction_key,
    );
    const resolved_account = try resolveExtraAccountMeta(
        &account_meta,
        instruction_data[0..],
        &hook_program_id,
        base_accounts[0..],
        &resolved_account_key,
    );

    try std.testing.expectEqualSlices(u8, &instruction_key, resolved_instruction.pubkey[0..]);
    try std.testing.expectEqual(@as(u8, 0), resolved_instruction.is_signer);
    try std.testing.expectEqual(@as(u8, 1), resolved_instruction.is_writable);
    try std.testing.expectEqualSlices(u8, &account_key_data, resolved_account.pubkey[0..]);
    try std.testing.expectEqual(@as(u8, 1), resolved_account.is_signer);
    try std.testing.expectEqual(@as(u8, 0), resolved_account.is_writable);
}

test "seed and pubkey-data resolution enforce config and source boundaries" {
    const hook_program_id: Pubkey = .{0x55} ** 32;
    const account_key: Pubkey = .{0x66} ** 32;
    const short_account_data = [_]u8{ 0x01, 0x02, 0x03 };
    const short_instruction_data = [_]u8{ 0x10, 0x20, 0x30 };
    var scratch_pubkey: Pubkey = undefined;

    const base_accounts = [_]AccountKeyData{
        .{ .key = &account_key, .data = short_account_data[0..] },
    };

    const too_large_literal = [_]u8{0xab} ** 33;
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        meta.ExtraAccountMeta.hookProgramDerived(
            &.{.{ .literal = too_large_literal[0..] }},
            false,
            false,
        ),
    );
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        meta.ExtraAccountMeta.hookProgramDerived(
            &.{
                .{ .literal = ([_]u8{0xcd} ** 30)[0..] },
                .{ .instruction_data = .{ .index = 0, .length = 4 } },
            },
            false,
            false,
        ),
    );

    var malformed_config = meta.ExtraAccountMeta{
        .discriminator = meta.HOOK_PROGRAM_PDA_DISCRIMINATOR,
        .address_config = .{0} ** 32,
        .is_signer = 0,
        .is_writable = 0,
    };
    malformed_config.address_config[0] = 1;
    malformed_config.address_config[1] = 31;
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMeta(
            &malformed_config,
            short_instruction_data[0..],
            &hook_program_id,
            base_accounts[0..],
            &scratch_pubkey,
        ),
    );

    const instruction_seed_meta = try meta.ExtraAccountMeta.hookProgramDerived(
        &.{.{ .instruction_data = .{ .index = 1, .length = 4 } }},
        false,
        false,
    );
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMeta(
            &instruction_seed_meta,
            short_instruction_data[0..],
            &hook_program_id,
            base_accounts[0..],
            &scratch_pubkey,
        ),
    );

    const account_seed_meta = try meta.ExtraAccountMeta.hookProgramDerived(
        &.{.{ .account_data = .{ .account_index = 0, .data_index = 1, .length = 4 } }},
        false,
        false,
    );
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMeta(
            &account_seed_meta,
            short_instruction_data[0..],
            &hook_program_id,
            base_accounts[0..],
            &scratch_pubkey,
        ),
    );

    const missing_account_seed_meta = try meta.ExtraAccountMeta.hookProgramDerived(
        &.{.{ .account_key = .{ .index = 1 } }},
        false,
        false,
    );
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMeta(
            &missing_account_seed_meta,
            short_instruction_data[0..],
            &hook_program_id,
            base_accounts[0..],
            &scratch_pubkey,
        ),
    );

    const instruction_pubkey_meta = try meta.ExtraAccountMeta.pubkeyData(
        PubkeyData{ .instruction_data = .{ .index = 2 } },
        false,
        false,
    );
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMeta(
            &instruction_pubkey_meta,
            short_instruction_data[0..],
            &hook_program_id,
            base_accounts[0..],
            &scratch_pubkey,
        ),
    );
}

test "external PDA discriminator boundaries map to account indexes with no fallback" {
    const hook_program_id: Pubkey = .{0x87} ** 32;
    const zero_program_id: Pubkey = .{0x31} ** 32;
    const max_program_id: Pubkey = .{0xfe} ** 32;
    const instruction_data = [_]u8{ 0x42, 0x24 };
    const seeds = [_]Seed{.{ .instruction_data = .{ .index = 0, .length = 2 } }};

    var account_keys: [128]Pubkey = undefined;
    var account_key_data: [128]AccountKeyData = undefined;
    for (&account_keys, 0..) |*account_key, index| {
        account_key.* = .{@as(u8, @truncate(index))} ** 32;
        account_key_data[index] = .{ .key = account_key, .data = null };
    }
    account_keys[0] = zero_program_id;
    account_keys[127] = max_program_id;

    const min_meta = try meta.ExtraAccountMeta.externalProgramDerived(0, &seeds, false, false);
    const max_meta = try meta.ExtraAccountMeta.externalProgramDerived(127, &seeds, false, false);

    var resolved_min_key: Pubkey = undefined;
    var resolved_max_key: Pubkey = undefined;
    const resolved_min = try resolveExtraAccountMeta(
        &min_meta,
        instruction_data[0..],
        &hook_program_id,
        account_key_data[0..],
        &resolved_min_key,
    );
    const resolved_max = try resolveExtraAccountMeta(
        &max_meta,
        instruction_data[0..],
        &hook_program_id,
        account_key_data[0..],
        &resolved_max_key,
    );

    const expected_min = sol.pda.findProgramAddress(&.{instruction_data[0..2]}, &zero_program_id) catch unreachable;
    const expected_max = sol.pda.findProgramAddress(&.{instruction_data[0..2]}, &max_program_id) catch unreachable;
    const expected_hook = sol.pda.findProgramAddress(&.{instruction_data[0..2]}, &hook_program_id) catch unreachable;

    try std.testing.expectEqualSlices(u8, &expected_min.address, resolved_min.pubkey[0..]);
    try std.testing.expectEqualSlices(u8, &expected_max.address, resolved_max.pubkey[0..]);
    try std.testing.expect(!std.mem.eql(u8, &expected_hook.address, resolved_min.pubkey[0..]));
    try std.testing.expect(!std.mem.eql(u8, &expected_hook.address, resolved_max.pubkey[0..]));

    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMeta(&max_meta, instruction_data[0..], &hook_program_id, account_key_data[0..127], &resolved_max_key),
    );
}

test "resolveExtraAccountMetaList makes prior resolved extras available by account index" {
    const hook_program_id: Pubkey = .{0x7a} ** 32;
    const fixed_pubkey: Pubkey = .{0x21} ** 32;
    const base_key: Pubkey = .{0x63} ** 32;
    const base_accounts = [_]AccountKeyData{
        .{ .key = &base_key, .data = null },
    };

    const entries = [_]meta.ExtraAccountMeta{
        meta.ExtraAccountMeta.fixed(&fixed_pubkey, false, false),
        try meta.ExtraAccountMeta.hookProgramDerived(
            &.{
                .{ .literal = "nested" },
                .{ .account_key = .{ .index = 1 } },
                .{ .account_key = .{ .index = 0 } },
            },
            false,
            true,
        ),
    };

    var bytes: [entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (entries, 0..) |entry, i| {
        entry.write(bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }

    const slice = try meta.ExtraAccountMetaSlice.init(bytes[0..]);
    var out_metas: [entries.len]AccountMeta = undefined;
    var out_keys: [entries.len]Pubkey = undefined;
    const resolved = try resolveExtraAccountMetaList(
        slice,
        &.{},
        &hook_program_id,
        base_accounts[0..],
        out_metas[0..],
        out_keys[0..],
    );

    const expected_nested = sol.pda.findProgramAddress(
        &.{ "nested", &fixed_pubkey, &base_key },
        &hook_program_id,
    ) catch unreachable;

    try std.testing.expectEqual(@as(usize, 2), resolved.len);
    try std.testing.expectEqualSlices(u8, &fixed_pubkey, resolved[0].pubkey[0..]);
    try std.testing.expectEqualSlices(u8, &expected_nested.address, resolved[1].pubkey[0..]);
    try std.testing.expectEqual(@as(u8, 1), resolved[1].is_writable);
}

test "official TLV account-resolution parity vectors match Zig behavior" {
    var parsed = try account_resolution_parity_fixture.load(std.testing.allocator);
    defer parsed.deinit();

    const fixture = parsed.value;
    const hook_program_id: Pubkey = fixture.hook_program_id;

    const base_accounts = try std.testing.allocator.alloc(AccountKeyData, fixture.base_accounts.len);
    defer std.testing.allocator.free(base_accounts);

    for (fixture.base_accounts, 0..) |_, i| {
        const fixture_account = &fixture.base_accounts[i];
        base_accounts[i] = .{
            .key = @ptrCast(&fixture_account.key),
            .data = fixture_account.data,
        };
    }

    for (fixture.cases) |case| {
        const extra_account_meta = meta.ExtraAccountMeta{
            .discriminator = case.meta.discriminator,
            .address_config = case.meta.address_config,
            .is_signer = case.meta.is_signer,
            .is_writable = case.meta.is_writable,
        };
        var resolved_key: Pubkey = undefined;
        const resolved = try resolveExtraAccountMeta(
            &extra_account_meta,
            fixture.instruction_data,
            &hook_program_id,
            base_accounts,
            &resolved_key,
        );
        try std.testing.expectEqualSlices(u8, &case.resolved.pubkey, resolved.pubkey[0..]);
        try std.testing.expectEqual(case.resolved.is_signer, resolved.is_signer);
        try std.testing.expectEqual(case.resolved.is_writable, resolved.is_writable);
    }
}
