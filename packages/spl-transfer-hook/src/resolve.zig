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
pub const DuplicatePolicy = sol.DuplicatePolicy;
pub const EXTRA_ACCOUNT_METAS_SEED = "extra-account-metas";
pub const tlv_entry_header_len: usize = sol.DISCRIMINATOR_LEN + @sizeOf(u32);
pub const extra_account_meta_list_value_header_len: usize = @sizeOf(u32);
pub const extra_account_meta_list_tlv_overhead_len: usize = tlv_entry_header_len + extra_account_meta_list_value_header_len;
const max_indexed_extra_accounts: usize = std.math.maxInt(u8) + 1;

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

pub fn unpackExecuteExtraAccountMetaListFromAccount(
    validation_account: sol.AccountInfo,
    mint: *const Pubkey,
    hook_program_id: *const Pubkey,
) ProgramError!meta.ExtraAccountMetaSlice {
    const expected_validation = findValidationAddress(mint, hook_program_id);
    if (!sol.pubkey.pubkeyEq(validation_account.key(), &expected_validation.address)) {
        return ProgramError.InvalidArgument;
    }
    if (!sol.pubkey.pubkeyEq(validation_account.owner(), hook_program_id)) {
        return ProgramError.IncorrectProgramId;
    }
    return unpackExecuteExtraAccountMetaList(validation_account.data());
}

pub const AccountKeyData = struct {
    key: *const Pubkey,
    data: ?[]const u8 = null,
};

const ResolvedExtraAccountMemo = struct {
    present: [max_indexed_extra_accounts]bool = .{false} ** max_indexed_extra_accounts,
    keys: [max_indexed_extra_accounts]Pubkey = undefined,
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

    var memo = ResolvedExtraAccountMemo{};
    for (0..extra_account_metas.len()) |i| {
        _ = try resolveExtraAccountMetaListEntry(
            extra_account_metas,
            i,
            instruction_data,
            hook_program_id,
            base_accounts,
            &memo,
        );
    }

    for (0..extra_account_metas.len()) |i| {
        const extra_account_meta = try extra_account_metas.get(i);
        out_keys[i] = try resolveExtraAccountMetaListEntry(
            extra_account_metas,
            i,
            instruction_data,
            hook_program_id,
            base_accounts,
            &memo,
        );

        out_metas[i] = .{
            .pubkey = &out_keys[i],
            .is_signer = extra_account_meta.is_signer,
            .is_writable = extra_account_meta.is_writable,
        };
    }

    return out_metas[0..extra_account_metas.len()];
}

pub fn validateResolvedExtraAccountInfos(
    expected_metas: []const AccountMeta,
    actual_accounts: []const sol.AccountInfo,
) ProgramError!void {
    return validateResolvedExtraAccountInfosWithPolicy(expected_metas, actual_accounts, .reject);
}

fn rejectProtectedDuplicates(
    actual_accounts: []const sol.AccountInfo,
    protected_accounts: []const AccountKeyData,
) ProgramError!void {
    for (actual_accounts, 0..) |actual_account, actual_index| {
        for (protected_accounts) |protected_account| {
            if (sol.pubkey.pubkeyEq(actual_account.key(), protected_account.key)) {
                return ProgramError.InvalidArgument;
            }
        }

        var prior_index: usize = 0;
        while (prior_index < actual_index) : (prior_index += 1) {
            if (sol.pubkey.pubkeyEq(actual_account.key(), actual_accounts[prior_index].key())) {
                return ProgramError.InvalidArgument;
            }
        }
    }
}

fn validateResolvedExtraAccountInfosInternal(
    expected_metas: []const AccountMeta,
    actual_accounts: []const sol.AccountInfo,
    protected_accounts: []const AccountKeyData,
    comptime duplicate_policy: DuplicatePolicy,
) ProgramError!void {
    if (actual_accounts.len < expected_metas.len) return ProgramError.NotEnoughAccountKeys;
    if (actual_accounts.len > expected_metas.len) return ProgramError.InvalidArgument;
    if (duplicate_policy == .reject) {
        try rejectProtectedDuplicates(actual_accounts, protected_accounts);
    }

    for (expected_metas, actual_accounts) |expected_meta, actual_account| {
        if (!sol.pubkey.pubkeyEq(actual_account.key(), expected_meta.pubkey)) {
            return ProgramError.InvalidArgument;
        }

        const actual_is_signer: u8 = @intFromBool(actual_account.isSigner());
        if (actual_is_signer != expected_meta.is_signer) {
            if (expected_meta.is_signer != 0) return ProgramError.MissingRequiredSignature;
            return ProgramError.InvalidArgument;
        }

        const actual_is_writable: u8 = @intFromBool(actual_account.isWritable());
        if (actual_is_writable != expected_meta.is_writable) {
            if (expected_meta.is_writable != 0) return ProgramError.ImmutableAccount;
            return ProgramError.InvalidArgument;
        }
    }
}

pub fn validateResolvedExtraAccountInfosWithPolicy(
    expected_metas: []const AccountMeta,
    actual_accounts: []const sol.AccountInfo,
    comptime duplicate_policy: DuplicatePolicy,
) ProgramError!void {
    return validateResolvedExtraAccountInfosInternal(expected_metas, actual_accounts, &.{}, duplicate_policy);
}

pub fn validateExecuteExtraAccountInfos(
    validation_account: sol.AccountInfo,
    mint: *const Pubkey,
    hook_program_id: *const Pubkey,
    instruction_data: []const u8,
    base_accounts: []const AccountKeyData,
    extra_accounts: []const sol.AccountInfo,
    out_metas: []AccountMeta,
    out_keys: []Pubkey,
) ProgramError![]const AccountMeta {
    return validateExecuteExtraAccountInfosWithPolicy(
        validation_account,
        mint,
        hook_program_id,
        instruction_data,
        base_accounts,
        extra_accounts,
        out_metas,
        out_keys,
        .reject,
    );
}

pub fn validateExecuteExtraAccountInfosWithPolicy(
    validation_account: sol.AccountInfo,
    mint: *const Pubkey,
    hook_program_id: *const Pubkey,
    instruction_data: []const u8,
    base_accounts: []const AccountKeyData,
    extra_accounts: []const sol.AccountInfo,
    out_metas: []AccountMeta,
    out_keys: []Pubkey,
    comptime duplicate_policy: DuplicatePolicy,
) ProgramError![]const AccountMeta {
    if (base_accounts.len < instruction.execute_with_extra_account_metas_prefix_len) {
        return ProgramError.NotEnoughAccountKeys;
    }
    if (base_accounts.len > instruction.execute_with_extra_account_metas_prefix_len) {
        return ProgramError.InvalidArgument;
    }
    if (!sol.pubkey.pubkeyEq(base_accounts[1].key, mint)) {
        return ProgramError.InvalidArgument;
    }
    if (!sol.pubkey.pubkeyEq(base_accounts[4].key, validation_account.key())) {
        return ProgramError.InvalidArgument;
    }

    const execute_base_accounts = [_]AccountKeyData{
        base_accounts[0],
        .{ .key = mint, .data = base_accounts[1].data },
        base_accounts[2],
        base_accounts[3],
        .{ .key = validation_account.key(), .data = validation_account.data() },
    };
    const extra_account_metas = try unpackExecuteExtraAccountMetaListFromAccount(
        validation_account,
        mint,
        hook_program_id,
    );
    const resolved = try resolveExtraAccountMetaList(
        extra_account_metas,
        instruction_data,
        hook_program_id,
        execute_base_accounts[0..],
        out_metas,
        out_keys,
    );
    try validateResolvedExtraAccountInfosInternal(
        resolved,
        extra_accounts,
        execute_base_accounts[0..],
        duplicate_policy,
    );
    return resolved;
}

fn resolveExtraAccountMetaListEntry(
    extra_account_metas: meta.ExtraAccountMetaSlice,
    extra_account_meta_index: usize,
    instruction_data: []const u8,
    hook_program_id: *const Pubkey,
    base_accounts: []const AccountKeyData,
    memo: *ResolvedExtraAccountMemo,
) ProgramError!Pubkey {
    if (extra_account_meta_index < memo.keys.len and memo.present[extra_account_meta_index]) {
        return memo.keys[extra_account_meta_index];
    }

    const extra_account_meta = try extra_account_metas.get(extra_account_meta_index);
    try extra_account_meta.validate();

    const resolved = switch (extra_account_meta.discriminator) {
        meta.ACCOUNT_META_DISCRIMINATOR => extra_account_meta.address_config,
        meta.HOOK_PROGRAM_PDA_DISCRIMINATOR => try resolveDynamicPdaFromMetaList(
            &extra_account_meta.address_config,
            instruction_data,
            hook_program_id,
            hook_program_id,
            extra_account_metas,
            extra_account_meta_index,
            base_accounts,
            memo,
        ),
        meta.PUBKEY_DATA_DISCRIMINATOR => try resolvePubkeyDataFromMetaList(
            &extra_account_meta.address_config,
            instruction_data,
            hook_program_id,
            extra_account_metas,
            extra_account_meta_index,
            base_accounts,
            memo,
        ),
        else => |discriminator| blk: {
            if (discriminator < meta.EXTERNAL_PDA_DISCRIMINATOR_MIN) return ProgramError.InvalidAccountData;
            const program_index = discriminator - meta.EXTERNAL_PDA_DISCRIMINATOR_MIN;
            const program_id = try lookupAccountFromMetaList(
                program_index,
                extra_account_metas,
                extra_account_meta_index,
                instruction_data,
                hook_program_id,
                base_accounts,
                memo,
            );
            break :blk try resolveDynamicPdaFromMetaList(
                &extra_account_meta.address_config,
                instruction_data,
                program_id.key,
                hook_program_id,
                extra_account_metas,
                extra_account_meta_index,
                base_accounts,
                memo,
            );
        },
    };

    if (extra_account_meta_index < memo.keys.len) {
        memo.keys[extra_account_meta_index] = resolved;
        memo.present[extra_account_meta_index] = true;
    }
    return resolved;
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

fn resolveDynamicPdaFromMetaList(
    address_config: *const [32]u8,
    instruction_data: []const u8,
    program_id: *const Pubkey,
    hook_program_id: *const Pubkey,
    extra_account_metas: meta.ExtraAccountMetaSlice,
    extra_account_meta_index: usize,
    base_accounts: []const AccountKeyData,
    memo: *ResolvedExtraAccountMemo,
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
                const account = try lookupAccountFromMetaList(
                    source.index,
                    extra_account_metas,
                    extra_account_meta_index,
                    instruction_data,
                    hook_program_id,
                    base_accounts,
                    memo,
                );
                break :blk account.key[0..];
            },
            .account_data => |source| blk: {
                const account = try lookupAccountFromMetaList(
                    source.account_index,
                    extra_account_metas,
                    extra_account_meta_index,
                    instruction_data,
                    hook_program_id,
                    base_accounts,
                    memo,
                );
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

fn resolvePubkeyDataFromMetaList(
    address_config: *const [32]u8,
    instruction_data: []const u8,
    hook_program_id: *const Pubkey,
    extra_account_metas: meta.ExtraAccountMetaSlice,
    extra_account_meta_index: usize,
    base_accounts: []const AccountKeyData,
    memo: *ResolvedExtraAccountMemo,
) ProgramError!Pubkey {
    return switch (try pubkey_data.unpackAddressConfig(address_config)) {
        .instruction_data => |source| try resolvePubkeyBytes(instruction_data, source.index),
        .account_data => |source| blk: {
            const account = try lookupAccountFromMetaList(
                source.account_index,
                extra_account_metas,
                extra_account_meta_index,
                instruction_data,
                hook_program_id,
                base_accounts,
                memo,
            );
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

fn lookupAccountFromMetaList(
    index: u8,
    extra_account_metas: meta.ExtraAccountMetaSlice,
    extra_account_meta_index: usize,
    instruction_data: []const u8,
    hook_program_id: *const Pubkey,
    base_accounts: []const AccountKeyData,
    memo: *ResolvedExtraAccountMemo,
) ProgramError!AccountKeyData {
    const idx: usize = index;
    if (idx < base_accounts.len) return base_accounts[idx];

    const resolved_index = idx - base_accounts.len;
    if (resolved_index >= extra_account_meta_index) return ProgramError.InvalidAccountData;
    if (resolved_index >= memo.keys.len) return ProgramError.InvalidAccountData;

    _ = try resolveExtraAccountMetaListEntry(
        extra_account_metas,
        resolved_index,
        instruction_data,
        hook_program_id,
        base_accounts,
        memo,
    );
    return .{
        .key = &memo.keys[resolved_index],
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

fn TestAccount(comptime data_len: usize) type {
    return extern struct {
        account: sol.Account,
        data: [data_len]u8,

        const Init = struct {
            key: Pubkey,
            owner: Pubkey,
            is_signer: bool = false,
            is_writable: bool = false,
            is_executable: bool = false,
            data: [data_len]u8 = .{0} ** data_len,
        };

        fn init(params: Init) @This() {
            return .{
                .account = .{
                    .borrow_state = 0xff,
                    .is_signer = @intFromBool(params.is_signer),
                    .is_writable = @intFromBool(params.is_writable),
                    .is_executable = @intFromBool(params.is_executable),
                    ._padding = .{0} ** 4,
                    .key = params.key,
                    .owner = params.owner,
                    .lamports = 0,
                    .data_len = data_len,
                },
                .data = params.data,
            };
        }

        fn info(self: *@This()) sol.AccountInfo {
            return .{ .raw = &self.account };
        }
    };
}

test "validation account trust is established before Execute TLV bytes are accepted" {
    const hook_program_id: Pubkey = .{0x91} ** 32;
    const other_program_id: Pubkey = .{0x73} ** 32;
    const mint: Pubkey = .{0x22} ** 32;

    const validation = findValidationAddress(&mint, &hook_program_id);
    const seed_extra: Pubkey = .{0x51} ** 32;

    const entries = [_]meta.ExtraAccountMeta{
        meta.ExtraAccountMeta.fixed(&seed_extra, false, true),
    };

    var meta_bytes: [entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (entries, 0..) |entry, i| {
        entry.write(meta_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }

    var value: [4 + meta_bytes.len]u8 = undefined;
    std.mem.writeInt(u32, value[0..4], entries.len, .little);
    @memcpy(value[4..], meta_bytes[0..]);

    var tlv_data: [tlv_entry_header_len + value.len]u8 = undefined;
    writeTestTlvEntry(&instruction.EXECUTE_DISCRIMINATOR, value[0..], tlv_data[0..]);

    var trusted_account = TestAccount(tlv_data.len).init(.{
        .key = validation.address,
        .owner = hook_program_id,
        .data = tlv_data,
    });
    const trusted_slice = try unpackExecuteExtraAccountMetaListFromAccount(
        trusted_account.info(),
        &mint,
        &hook_program_id,
    );
    try std.testing.expectEqual(@as(usize, 1), trusted_slice.len());

    var wrong_pda_account = TestAccount(tlv_data.len).init(.{
        .key = .{0xee} ** 32,
        .owner = hook_program_id,
        .data = tlv_data,
    });
    try std.testing.expectError(
        ProgramError.InvalidArgument,
        unpackExecuteExtraAccountMetaListFromAccount(
            wrong_pda_account.info(),
            &mint,
            &hook_program_id,
        ),
    );

    var wrong_owner_account = TestAccount(tlv_data.len).init(.{
        .key = validation.address,
        .owner = other_program_id,
        .data = tlv_data,
    });
    try std.testing.expectError(
        ProgramError.IncorrectProgramId,
        unpackExecuteExtraAccountMetaListFromAccount(
            wrong_owner_account.info(),
            &mint,
            &hook_program_id,
        ),
    );

    var malformed_account = TestAccount(1).init(.{
        .key = validation.address,
        .owner = hook_program_id,
        .data = .{0},
    });
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        unpackExecuteExtraAccountMetaListFromAccount(
            malformed_account.info(),
            &mint,
            &hook_program_id,
        ),
    );
}

test "account-consuming Execute validation enforces declared extra-account order and key presence" {
    const hook_program_id: Pubkey = .{0x63} ** 32;
    const mint: Pubkey = .{0x19} ** 32;
    const source: Pubkey = .{0x11} ** 32;
    const destination: Pubkey = .{0x33} ** 32;
    const authority: Pubkey = .{0x44} ** 32;
    const first_extra: Pubkey = .{0xa1} ** 32;

    const validation = findValidationAddress(&mint, &hook_program_id);
    const second_extra = (try sol.pda.findProgramAddress(
        &.{ "vault", &first_extra },
        &hook_program_id,
    )).address;

    const entries = [_]meta.ExtraAccountMeta{
        meta.ExtraAccountMeta.fixed(&first_extra, false, true),
        try meta.ExtraAccountMeta.hookProgramDerived(
            &.{
                .{ .literal = "vault" },
                .{ .account_key = .{ .index = 5 } },
            },
            false,
            false,
        ),
    };

    var meta_bytes: [entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (entries, 0..) |entry, i| {
        entry.write(meta_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }

    var value: [4 + meta_bytes.len]u8 = undefined;
    std.mem.writeInt(u32, value[0..4], entries.len, .little);
    @memcpy(value[4..], meta_bytes[0..]);

    var tlv_data: [tlv_entry_header_len + value.len]u8 = undefined;
    writeTestTlvEntry(&instruction.EXECUTE_DISCRIMINATOR, value[0..], tlv_data[0..]);

    var validation_account = TestAccount(tlv_data.len).init(.{
        .key = validation.address,
        .owner = hook_program_id,
        .data = tlv_data,
    });
    var first_account = TestAccount(0).init(.{
        .key = first_extra,
        .owner = .{0x01} ** 32,
        .is_writable = true,
    });
    var second_account = TestAccount(0).init(.{
        .key = second_extra,
        .owner = .{0x02} ** 32,
    });
    var wrong_second_account = TestAccount(0).init(.{
        .key = .{0xdd} ** 32,
        .owner = .{0x03} ** 32,
    });
    var unrelated_account = TestAccount(0).init(.{
        .key = .{0xee} ** 32,
        .owner = .{0x04} ** 32,
    });

    const base_accounts = [_]AccountKeyData{
        .{ .key = &source, .data = null },
        .{ .key = &mint, .data = null },
        .{ .key = &destination, .data = null },
        .{ .key = &authority, .data = null },
        .{ .key = validation_account.info().key(), .data = validation_account.info().data() },
    };
    var execute_data: instruction.ExecuteData = undefined;
    @memcpy(execute_data[0..sol.DISCRIMINATOR_LEN], &instruction.EXECUTE_DISCRIMINATOR);
    std.mem.writeInt(u64, execute_data[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u64)], 42, .little);

    var out_metas: [entries.len]AccountMeta = undefined;
    var out_keys: [entries.len]Pubkey = undefined;

    const validated = try validateExecuteExtraAccountInfos(
        validation_account.info(),
        &mint,
        &hook_program_id,
        execute_data[0..],
        base_accounts[0..],
        &.{ first_account.info(), second_account.info() },
        out_metas[0..],
        out_keys[0..],
    );
    try std.testing.expectEqual(@as(usize, 2), validated.len);
    try std.testing.expectEqualSlices(u8, &first_extra, validated[0].pubkey[0..]);
    try std.testing.expectEqual(@as(u8, 1), validated[0].is_writable);
    try std.testing.expectEqualSlices(u8, &second_extra, validated[1].pubkey[0..]);

    try std.testing.expectError(
        ProgramError.InvalidArgument,
        validateExecuteExtraAccountInfos(
            validation_account.info(),
            &mint,
            &hook_program_id,
            execute_data[0..],
            base_accounts[0..],
            &.{ second_account.info(), first_account.info() },
            out_metas[0..],
            out_keys[0..],
        ),
    );
    try std.testing.expectError(
        ProgramError.InvalidArgument,
        validateExecuteExtraAccountInfos(
            validation_account.info(),
            &mint,
            &hook_program_id,
            execute_data[0..],
            base_accounts[0..],
            &.{ first_account.info(), wrong_second_account.info() },
            out_metas[0..],
            out_keys[0..],
        ),
    );
    try std.testing.expectError(
        ProgramError.NotEnoughAccountKeys,
        validateExecuteExtraAccountInfos(
            validation_account.info(),
            &mint,
            &hook_program_id,
            execute_data[0..],
            base_accounts[0..],
            &.{first_account.info()},
            out_metas[0..],
            out_keys[0..],
        ),
    );
    try std.testing.expectError(
        ProgramError.InvalidArgument,
        validateExecuteExtraAccountInfos(
            validation_account.info(),
            &mint,
            &hook_program_id,
            execute_data[0..],
            base_accounts[0..],
            &.{ first_account.info(), second_account.info(), unrelated_account.info() },
            out_metas[0..],
            out_keys[0..],
        ),
    );
}

test "Execute validation requires the exact fixed Execute prefix and canonical validation slot" {
    const hook_program_id: Pubkey = .{0x5a} ** 32;
    const mint: Pubkey = .{0x19} ** 32;
    const source: Pubkey = .{0x11} ** 32;
    const destination: Pubkey = .{0x33} ** 32;
    const authority: Pubkey = .{0x44} ** 32;
    const extra: Pubkey = .{0xa1} ** 32;

    const validation = findValidationAddress(&mint, &hook_program_id);
    const entries = [_]meta.ExtraAccountMeta{
        meta.ExtraAccountMeta.fixed(&extra, false, false),
    };

    var meta_bytes: [entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (entries, 0..) |entry, i| {
        entry.write(meta_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }

    var value: [4 + meta_bytes.len]u8 = undefined;
    std.mem.writeInt(u32, value[0..4], entries.len, .little);
    @memcpy(value[4..], meta_bytes[0..]);

    var tlv_data: [tlv_entry_header_len + value.len]u8 = undefined;
    writeTestTlvEntry(&instruction.EXECUTE_DISCRIMINATOR, value[0..], tlv_data[0..]);

    var validation_account = TestAccount(tlv_data.len).init(.{
        .key = validation.address,
        .owner = hook_program_id,
        .data = tlv_data,
    });
    var extra_account = TestAccount(0).init(.{
        .key = extra,
        .owner = .{0x01} ** 32,
    });

    const canonical_base_accounts = [_]AccountKeyData{
        .{ .key = &source, .data = null },
        .{ .key = &mint, .data = null },
        .{ .key = &destination, .data = null },
        .{ .key = &authority, .data = null },
        .{ .key = validation_account.info().key(), .data = validation_account.info().data() },
    };
    const shifted_base_accounts = [_]AccountKeyData{
        .{ .key = &mint, .data = null },
        .{ .key = &destination, .data = null },
        .{ .key = &authority, .data = null },
        .{ .key = validation_account.info().key(), .data = validation_account.info().data() },
        .{ .key = &extra, .data = null },
    };
    const too_many_base_accounts = [_]AccountKeyData{
        canonical_base_accounts[0],
        canonical_base_accounts[1],
        canonical_base_accounts[2],
        canonical_base_accounts[3],
        canonical_base_accounts[4],
        .{ .key = &extra, .data = null },
    };

    var execute_data: instruction.ExecuteData = undefined;
    @memcpy(execute_data[0..sol.DISCRIMINATOR_LEN], &instruction.EXECUTE_DISCRIMINATOR);
    std.mem.writeInt(u64, execute_data[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u64)], 42, .little);

    var out_metas: [entries.len]AccountMeta = undefined;
    var out_keys: [entries.len]Pubkey = undefined;

    const validated = try validateExecuteExtraAccountInfos(
        validation_account.info(),
        &mint,
        &hook_program_id,
        execute_data[0..],
        canonical_base_accounts[0..],
        &.{extra_account.info()},
        out_metas[0..],
        out_keys[0..],
    );
    try std.testing.expectEqual(@as(usize, 1), validated.len);
    try std.testing.expectEqualSlices(u8, &extra, validated[0].pubkey[0..]);

    try std.testing.expectError(
        ProgramError.NotEnoughAccountKeys,
        validateExecuteExtraAccountInfos(
            validation_account.info(),
            &mint,
            &hook_program_id,
            execute_data[0..],
            canonical_base_accounts[0..4],
            &.{extra_account.info()},
            out_metas[0..],
            out_keys[0..],
        ),
    );
    try std.testing.expectError(
        ProgramError.InvalidArgument,
        validateExecuteExtraAccountInfos(
            validation_account.info(),
            &mint,
            &hook_program_id,
            execute_data[0..],
            too_many_base_accounts[0..],
            &.{extra_account.info()},
            out_metas[0..],
            out_keys[0..],
        ),
    );
    try std.testing.expectError(
        ProgramError.InvalidArgument,
        validateExecuteExtraAccountInfos(
            validation_account.info(),
            &mint,
            &hook_program_id,
            execute_data[0..],
            shifted_base_accounts[0..],
            &.{extra_account.info()},
            out_metas[0..],
            out_keys[0..],
        ),
    );
}

test "remaining-account resolver rejects self, forward, and cyclic dependencies" {
    const hook_program_id: Pubkey = .{0x62} ** 32;
    const base_program: Pubkey = .{0x17} ** 32;
    const previous_extra: Pubkey = .{0x83} ** 32;

    const base_accounts = [_]AccountKeyData{
        .{ .key = &base_program, .data = null },
    };

    const valid_entries = [_]meta.ExtraAccountMeta{
        meta.ExtraAccountMeta.fixed(&previous_extra, false, false),
        try meta.ExtraAccountMeta.hookProgramDerived(
            &.{
                .{ .literal = "prior" },
                .{ .account_key = .{ .index = 1 } },
            },
            false,
            false,
        ),
    };
    var valid_bytes: [valid_entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (valid_entries, 0..) |entry, i| {
        entry.write(valid_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }
    const valid_slice = try meta.ExtraAccountMetaSlice.init(valid_bytes[0..]);

    var valid_out_metas: [valid_entries.len]AccountMeta = undefined;
    var valid_out_keys: [valid_entries.len]Pubkey = undefined;
    const valid_resolved = try resolveExtraAccountMetaList(
        valid_slice,
        &.{},
        &hook_program_id,
        base_accounts[0..],
        valid_out_metas[0..],
        valid_out_keys[0..],
    );
    const expected_prior = (try sol.pda.findProgramAddress(
        &.{ "prior", &previous_extra },
        &hook_program_id,
    )).address;
    try std.testing.expectEqual(@as(usize, 2), valid_resolved.len);
    try std.testing.expectEqualSlices(u8, &expected_prior, valid_resolved[1].pubkey[0..]);

    const self_ref_entries = [_]meta.ExtraAccountMeta{
        try meta.ExtraAccountMeta.hookProgramDerived(
            &.{.{ .account_key = .{ .index = 1 } }},
            false,
            false,
        ),
    };
    var self_ref_bytes: [self_ref_entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (self_ref_entries, 0..) |entry, i| {
        entry.write(self_ref_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }
    const self_ref_slice = try meta.ExtraAccountMetaSlice.init(self_ref_bytes[0..]);
    var self_ref_out_metas: [self_ref_entries.len]AccountMeta = undefined;
    var self_ref_out_keys: [self_ref_entries.len]Pubkey = undefined;
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMetaList(
            self_ref_slice,
            &.{},
            &hook_program_id,
            base_accounts[0..],
            self_ref_out_metas[0..],
            self_ref_out_keys[0..],
        ),
    );

    const forward_ref_entries = [_]meta.ExtraAccountMeta{
        try meta.ExtraAccountMeta.hookProgramDerived(
            &.{.{ .account_key = .{ .index = 2 } }},
            false,
            false,
        ),
        meta.ExtraAccountMeta.fixed(&previous_extra, false, false),
    };
    var forward_ref_bytes: [forward_ref_entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (forward_ref_entries, 0..) |entry, i| {
        entry.write(forward_ref_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }
    const forward_ref_slice = try meta.ExtraAccountMetaSlice.init(forward_ref_bytes[0..]);
    var forward_ref_out_metas: [forward_ref_entries.len]AccountMeta = undefined;
    var forward_ref_out_keys: [forward_ref_entries.len]Pubkey = undefined;
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMetaList(
            forward_ref_slice,
            &.{},
            &hook_program_id,
            base_accounts[0..],
            forward_ref_out_metas[0..],
            forward_ref_out_keys[0..],
        ),
    );
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMetaList(
            forward_ref_slice,
            &.{},
            &hook_program_id,
            base_accounts[0..],
            forward_ref_out_metas[0..],
            forward_ref_out_keys[0..],
        ),
    );

    const cyclic_entries = [_]meta.ExtraAccountMeta{
        try meta.ExtraAccountMeta.hookProgramDerived(
            &.{.{ .account_key = .{ .index = 2 } }},
            false,
            false,
        ),
        try meta.ExtraAccountMeta.hookProgramDerived(
            &.{.{ .account_key = .{ .index = 1 } }},
            false,
            false,
        ),
    };
    var cyclic_bytes: [cyclic_entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (cyclic_entries, 0..) |entry, i| {
        entry.write(cyclic_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }
    const cyclic_slice = try meta.ExtraAccountMetaSlice.init(cyclic_bytes[0..]);
    var cyclic_out_metas: [cyclic_entries.len]AccountMeta = undefined;
    var cyclic_out_keys: [cyclic_entries.len]Pubkey = undefined;
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMetaList(
            cyclic_slice,
            &.{},
            &hook_program_id,
            base_accounts[0..],
            cyclic_out_metas[0..],
            cyclic_out_keys[0..],
        ),
    );
}

test "external PDA program-source handling is explicit, bounded, and rejects forward references" {
    const hook_program_id: Pubkey = .{0x72} ** 32;
    const base_account: Pubkey = .{0x24} ** 32;
    const external_program_id: Pubkey = .{0xb1} ** 32;
    const instruction_data = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
    const seeds = [_]Seed{.{ .instruction_data = .{ .index = 1, .length = 2 } }};

    const base_accounts = [_]AccountKeyData{
        .{ .key = &base_account, .data = null },
    };

    const valid_entries = [_]meta.ExtraAccountMeta{
        meta.ExtraAccountMeta.fixed(&external_program_id, false, false),
        try meta.ExtraAccountMeta.externalProgramDerived(1, &seeds, false, false),
    };
    var valid_bytes: [valid_entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (valid_entries, 0..) |entry, i| {
        entry.write(valid_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }
    const valid_slice = try meta.ExtraAccountMetaSlice.init(valid_bytes[0..]);

    var valid_out_metas: [valid_entries.len]AccountMeta = undefined;
    var valid_out_keys: [valid_entries.len]Pubkey = undefined;
    const valid_resolved = try resolveExtraAccountMetaList(
        valid_slice,
        instruction_data[0..],
        &hook_program_id,
        base_accounts[0..],
        valid_out_metas[0..],
        valid_out_keys[0..],
    );
    const expected_external = (try sol.pda.findProgramAddress(
        &.{instruction_data[1..3]},
        &external_program_id,
    )).address;
    try std.testing.expectEqual(@as(usize, 2), valid_resolved.len);
    try std.testing.expectEqualSlices(u8, &expected_external, valid_resolved[1].pubkey[0..]);

    const forward_entries = [_]meta.ExtraAccountMeta{
        try meta.ExtraAccountMeta.externalProgramDerived(2, &seeds, false, false),
        meta.ExtraAccountMeta.fixed(&external_program_id, false, false),
    };
    var forward_bytes: [forward_entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (forward_entries, 0..) |entry, i| {
        entry.write(forward_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }
    const forward_slice = try meta.ExtraAccountMetaSlice.init(forward_bytes[0..]);
    var forward_out_metas: [forward_entries.len]AccountMeta = undefined;
    var forward_out_keys: [forward_entries.len]Pubkey = undefined;
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMetaList(
            forward_slice,
            instruction_data[0..],
            &hook_program_id,
            base_accounts[0..],
            forward_out_metas[0..],
            forward_out_keys[0..],
        ),
    );

    const out_of_range_meta = try meta.ExtraAccountMeta.externalProgramDerived(3, &seeds, false, false);
    var single_resolved_key: Pubkey = undefined;
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMeta(
            &out_of_range_meta,
            instruction_data[0..],
            &hook_program_id,
            base_accounts[0..],
            &single_resolved_key,
        ),
    );
}

test "remaining-account resolution failures are side-effect-free and retry-stable" {
    const hook_program_id: Pubkey = .{0x79} ** 32;
    const base_key: Pubkey = .{0x31} ** 32;
    const first_extra: Pubkey = .{0xa3} ** 32;

    const base_accounts = [_]AccountKeyData{
        .{ .key = &base_key, .data = null },
    };

    const failing_entries = [_]meta.ExtraAccountMeta{
        meta.ExtraAccountMeta.fixed(&first_extra, false, true),
        try meta.ExtraAccountMeta.hookProgramDerived(
            &.{
                .{ .literal = "missing" },
                .{ .account_key = .{ .index = 3 } },
            },
            false,
            false,
        ),
    };
    var failing_bytes: [failing_entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (failing_entries, 0..) |entry, i| {
        entry.write(failing_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }
    const failing_slice = try meta.ExtraAccountMetaSlice.init(failing_bytes[0..]);

    var sentinel_meta_key_a: Pubkey = .{0xc4} ** 32;
    var sentinel_meta_key_b: Pubkey = .{0xd5} ** 32;
    const sentinel_out_key_a: Pubkey = .{0xe6} ** 32;
    const sentinel_out_key_b: Pubkey = .{0xf7} ** 32;

    var out_metas = [_]AccountMeta{
        .{ .pubkey = &sentinel_meta_key_a, .is_signer = 1, .is_writable = 0 },
        .{ .pubkey = &sentinel_meta_key_b, .is_signer = 0, .is_writable = 1 },
    };
    var out_keys = [_]Pubkey{ sentinel_out_key_a, sentinel_out_key_b };

    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMetaList(
            failing_slice,
            &.{},
            &hook_program_id,
            base_accounts[0..],
            out_metas[0..],
            out_keys[0..],
        ),
    );
    try std.testing.expectEqual(@intFromPtr(@as(*const Pubkey, @ptrCast(&sentinel_meta_key_a))), @intFromPtr(out_metas[0].pubkey));
    try std.testing.expectEqual(@as(u8, 1), out_metas[0].is_signer);
    try std.testing.expectEqual(@as(u8, 0), out_metas[0].is_writable);
    try std.testing.expectEqual(@intFromPtr(@as(*const Pubkey, @ptrCast(&sentinel_meta_key_b))), @intFromPtr(out_metas[1].pubkey));
    try std.testing.expectEqual(@as(u8, 0), out_metas[1].is_signer);
    try std.testing.expectEqual(@as(u8, 1), out_metas[1].is_writable);
    try std.testing.expectEqualSlices(u8, &sentinel_out_key_a, &out_keys[0]);
    try std.testing.expectEqualSlices(u8, &sentinel_out_key_b, &out_keys[1]);

    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        resolveExtraAccountMetaList(
            failing_slice,
            &.{},
            &hook_program_id,
            base_accounts[0..],
            out_metas[0..],
            out_keys[0..],
        ),
    );
    try std.testing.expectEqual(@intFromPtr(@as(*const Pubkey, @ptrCast(&sentinel_meta_key_a))), @intFromPtr(out_metas[0].pubkey));
    try std.testing.expectEqual(@as(u8, 1), out_metas[0].is_signer);
    try std.testing.expectEqual(@as(u8, 0), out_metas[0].is_writable);
    try std.testing.expectEqual(@intFromPtr(@as(*const Pubkey, @ptrCast(&sentinel_meta_key_b))), @intFromPtr(out_metas[1].pubkey));
    try std.testing.expectEqual(@as(u8, 0), out_metas[1].is_signer);
    try std.testing.expectEqual(@as(u8, 1), out_metas[1].is_writable);
    try std.testing.expectEqualSlices(u8, &sentinel_out_key_a, &out_keys[0]);
    try std.testing.expectEqualSlices(u8, &sentinel_out_key_b, &out_keys[1]);

    const success_entries = [_]meta.ExtraAccountMeta{
        meta.ExtraAccountMeta.fixed(&first_extra, false, true),
        try meta.ExtraAccountMeta.hookProgramDerived(
            &.{
                .{ .literal = "ok" },
                .{ .account_key = .{ .index = 1 } },
            },
            false,
            false,
        ),
    };
    var success_bytes: [success_entries.len * meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    inline for (success_entries, 0..) |entry, i| {
        entry.write(success_bytes[i * meta.EXTRA_ACCOUNT_META_LEN ..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    }
    const success_slice = try meta.ExtraAccountMetaSlice.init(success_bytes[0..]);

    const resolved = try resolveExtraAccountMetaList(
        success_slice,
        &.{},
        &hook_program_id,
        base_accounts[0..],
        out_metas[0..],
        out_keys[0..],
    );
    const expected_second = (try sol.pda.findProgramAddress(
        &.{ "ok", &first_extra },
        &hook_program_id,
    )).address;
    try std.testing.expectEqual(@as(usize, 2), resolved.len);
    try std.testing.expectEqualSlices(u8, &first_extra, resolved[0].pubkey[0..]);
    try std.testing.expectEqualSlices(u8, &expected_second, resolved[1].pubkey[0..]);
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

test "resolved extra-account validation enforces exact signer and writable privileges" {
    const signer_key: Pubkey = .{0x91} ** 32;
    const writable_key: Pubkey = .{0x92} ** 32;
    const readonly_key: Pubkey = .{0x93} ** 32;

    const expected = [_]AccountMeta{
        .{ .pubkey = &signer_key, .is_signer = 1, .is_writable = 0 },
        .{ .pubkey = &writable_key, .is_signer = 0, .is_writable = 1 },
        .{ .pubkey = &readonly_key, .is_signer = 0, .is_writable = 0 },
    };

    var signer_account = TestAccount(0).init(.{
        .key = signer_key,
        .owner = .{0x11} ** 32,
        .is_signer = true,
    });
    var writable_account = TestAccount(0).init(.{
        .key = writable_key,
        .owner = .{0x12} ** 32,
        .is_writable = true,
    });
    var readonly_account = TestAccount(0).init(.{
        .key = readonly_key,
        .owner = .{0x13} ** 32,
    });

    const matching_accounts = [_]sol.AccountInfo{
        signer_account.info(),
        writable_account.info(),
        readonly_account.info(),
    };
    try validateResolvedExtraAccountInfosWithPolicy(expected[0..], matching_accounts[0..], .reject);
    try validateResolvedExtraAccountInfos(expected[0..], matching_accounts[0..]);

    var missing_signer_account = TestAccount(0).init(.{
        .key = signer_key,
        .owner = .{0x14} ** 32,
    });
    const missing_signer_accounts = [_]sol.AccountInfo{
        missing_signer_account.info(),
        writable_account.info(),
        readonly_account.info(),
    };
    try std.testing.expectError(
        ProgramError.MissingRequiredSignature,
        validateResolvedExtraAccountInfosWithPolicy(expected[0..], missing_signer_accounts[0..], .reject),
    );

    var escalated_signer_account = TestAccount(0).init(.{
        .key = readonly_key,
        .owner = .{0x15} ** 32,
        .is_signer = true,
    });
    const escalated_signer_accounts = [_]sol.AccountInfo{
        signer_account.info(),
        writable_account.info(),
        escalated_signer_account.info(),
    };
    try std.testing.expectError(
        ProgramError.InvalidArgument,
        validateResolvedExtraAccountInfosWithPolicy(expected[0..], escalated_signer_accounts[0..], .reject),
    );

    var missing_writable_account = TestAccount(0).init(.{
        .key = writable_key,
        .owner = .{0x16} ** 32,
    });
    const missing_writable_accounts = [_]sol.AccountInfo{
        signer_account.info(),
        missing_writable_account.info(),
        readonly_account.info(),
    };
    try std.testing.expectError(
        ProgramError.ImmutableAccount,
        validateResolvedExtraAccountInfosWithPolicy(expected[0..], missing_writable_accounts[0..], .reject),
    );

    var escalated_writable_account = TestAccount(0).init(.{
        .key = readonly_key,
        .owner = .{0x17} ** 32,
        .is_writable = true,
    });
    const escalated_writable_accounts = [_]sol.AccountInfo{
        signer_account.info(),
        writable_account.info(),
        escalated_writable_account.info(),
    };
    try std.testing.expectError(
        ProgramError.InvalidArgument,
        validateResolvedExtraAccountInfosWithPolicy(expected[0..], escalated_writable_accounts[0..], .reject),
    );
}

test "duplicate policy APIs distinguish adjacent and non-adjacent duplicates" {
    const duplicate_key: Pubkey = .{0xa1} ** 32;
    const middle_key: Pubkey = .{0xb2} ** 32;

    const adjacent_expected = [_]AccountMeta{
        .{ .pubkey = &duplicate_key, .is_signer = 0, .is_writable = 0 },
        .{ .pubkey = &duplicate_key, .is_signer = 0, .is_writable = 0 },
    };
    const non_adjacent_expected = [_]AccountMeta{
        .{ .pubkey = &duplicate_key, .is_signer = 0, .is_writable = 0 },
        .{ .pubkey = &middle_key, .is_signer = 0, .is_writable = 0 },
        .{ .pubkey = &duplicate_key, .is_signer = 0, .is_writable = 0 },
    };

    var duplicate_account = TestAccount(0).init(.{
        .key = duplicate_key,
        .owner = .{0x21} ** 32,
    });
    var middle_account = TestAccount(0).init(.{
        .key = middle_key,
        .owner = .{0x22} ** 32,
    });

    const adjacent_actual = [_]sol.AccountInfo{
        duplicate_account.info(),
        duplicate_account.info(),
    };
    try validateResolvedExtraAccountInfosWithPolicy(adjacent_expected[0..], adjacent_actual[0..], .allow);
    try std.testing.expectError(
        ProgramError.InvalidArgument,
        validateResolvedExtraAccountInfosWithPolicy(adjacent_expected[0..], adjacent_actual[0..], .reject),
    );

    const non_adjacent_actual = [_]sol.AccountInfo{
        duplicate_account.info(),
        middle_account.info(),
        duplicate_account.info(),
    };
    try validateResolvedExtraAccountInfosWithPolicy(non_adjacent_expected[0..], non_adjacent_actual[0..], .allow);
    try std.testing.expectError(
        ProgramError.InvalidArgument,
        validateResolvedExtraAccountInfosWithPolicy(non_adjacent_expected[0..], non_adjacent_actual[0..], .reject),
    );
}

test "allowed duplicates still validate each role independently" {
    const duplicate_key: Pubkey = .{0xc7} ** 32;

    const signer_expected = [_]AccountMeta{
        .{ .pubkey = &duplicate_key, .is_signer = 0, .is_writable = 0 },
        .{ .pubkey = &duplicate_key, .is_signer = 1, .is_writable = 0 },
    };
    const writable_expected = [_]AccountMeta{
        .{ .pubkey = &duplicate_key, .is_signer = 0, .is_writable = 0 },
        .{ .pubkey = &duplicate_key, .is_signer = 0, .is_writable = 1 },
    };

    var readonly_duplicate = TestAccount(0).init(.{
        .key = duplicate_key,
        .owner = .{0x23} ** 32,
    });
    const duplicate_actual = [_]sol.AccountInfo{
        readonly_duplicate.info(),
        readonly_duplicate.info(),
    };

    try std.testing.expectError(
        ProgramError.MissingRequiredSignature,
        validateResolvedExtraAccountInfosWithPolicy(signer_expected[0..], duplicate_actual[0..], .allow),
    );
    try std.testing.expectError(
        ProgramError.ImmutableAccount,
        validateResolvedExtraAccountInfosWithPolicy(writable_expected[0..], duplicate_actual[0..], .allow),
    );
}

test "Execute duplicate policy rejects fixed-account reuse by default and allows explicit duplicates" {
    const hook_program_id: Pubkey = .{0xd1} ** 32;
    const mint: Pubkey = .{0xd2} ** 32;
    const source: Pubkey = .{0xd3} ** 32;
    const destination: Pubkey = .{0xd4} ** 32;
    const authority: Pubkey = .{0xd5} ** 32;

    const validation = findValidationAddress(&mint, &hook_program_id);

    var source_account = TestAccount(0).init(.{
        .key = source,
        .owner = .{0x31} ** 32,
    });
    var mint_account = TestAccount(0).init(.{
        .key = mint,
        .owner = .{0x32} ** 32,
    });
    var destination_account = TestAccount(0).init(.{
        .key = destination,
        .owner = .{0x33} ** 32,
    });
    var authority_account = TestAccount(0).init(.{
        .key = authority,
        .owner = .{0x34} ** 32,
    });

    var value: [4 + meta.EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    const tlv_data_len = tlv_entry_header_len + value.len;
    var validation_account = TestAccount(tlv_data_len).init(.{
        .key = validation.address,
        .owner = hook_program_id,
        .data = .{0} ** tlv_data_len,
    });

    const base_accounts = [_]AccountKeyData{
        .{ .key = &source, .data = null },
        .{ .key = &mint, .data = null },
        .{ .key = &destination, .data = null },
        .{ .key = &authority, .data = null },
        .{ .key = validation_account.info().key(), .data = validation_account.info().data() },
    };

    var execute_data: instruction.ExecuteData = undefined;
    @memcpy(execute_data[0..sol.DISCRIMINATOR_LEN], &instruction.EXECUTE_DISCRIMINATOR);
    std.mem.writeInt(u64, execute_data[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u64)], 77, .little);

    var out_metas: [1]AccountMeta = undefined;
    var out_keys: [1]Pubkey = undefined;

    const fixed_reuse_cases = [_]struct {
        key: *const Pubkey,
        info: sol.AccountInfo,
    }{
        .{ .key = &source, .info = source_account.info() },
        .{ .key = &mint, .info = mint_account.info() },
        .{ .key = &destination, .info = destination_account.info() },
        .{ .key = &authority, .info = authority_account.info() },
    };

    for (fixed_reuse_cases) |case| {
        const entry = meta.ExtraAccountMeta.fixed(case.key, false, false);
        std.mem.writeInt(u32, value[0..4], 1, .little);
        entry.write(value[4..][0..meta.EXTRA_ACCOUNT_META_LEN]);
        writeTestTlvEntry(&instruction.EXECUTE_DISCRIMINATOR, value[0..], validation_account.data[0..]);

        try std.testing.expectError(
            ProgramError.InvalidArgument,
            validateExecuteExtraAccountInfos(
                validation_account.info(),
                &mint,
                &hook_program_id,
                execute_data[0..],
                base_accounts[0..],
                &.{case.info},
                out_metas[0..],
                out_keys[0..],
            ),
        );
        const allowed = try validateExecuteExtraAccountInfosWithPolicy(
            validation_account.info(),
            &mint,
            &hook_program_id,
            execute_data[0..],
            base_accounts[0..],
            &.{case.info},
            out_metas[0..],
            out_keys[0..],
            .allow,
        );
        try std.testing.expectEqual(@as(usize, 1), allowed.len);
        try std.testing.expectEqualSlices(u8, case.key[0..], allowed[0].pubkey[0..]);
    }

    const validation_entry = meta.ExtraAccountMeta.fixed(validation_account.info().key(), false, false);
    std.mem.writeInt(u32, value[0..4], 1, .little);
    validation_entry.write(value[4..][0..meta.EXTRA_ACCOUNT_META_LEN]);
    writeTestTlvEntry(&instruction.EXECUTE_DISCRIMINATOR, value[0..], validation_account.data[0..]);

    try std.testing.expectError(
        ProgramError.InvalidArgument,
        validateExecuteExtraAccountInfos(
            validation_account.info(),
            &mint,
            &hook_program_id,
            execute_data[0..],
            base_accounts[0..],
            &.{validation_account.info()},
            out_metas[0..],
            out_keys[0..],
        ),
    );
    const allowed_validation = try validateExecuteExtraAccountInfosWithPolicy(
        validation_account.info(),
        &mint,
        &hook_program_id,
        execute_data[0..],
        base_accounts[0..],
        &.{validation_account.info()},
        out_metas[0..],
        out_keys[0..],
        .allow,
    );
    try std.testing.expectEqual(@as(usize, 1), allowed_validation.len);
    try std.testing.expectEqualSlices(u8, validation_account.info().key()[0..], allowed_validation[0].pubkey[0..]);
}
