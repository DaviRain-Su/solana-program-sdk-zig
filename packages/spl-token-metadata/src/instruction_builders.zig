//! High-level SPL Token Metadata instruction builders and length helpers.

const sol = @import("solana_program_sdk");
const payloads = @import("instruction_payloads.zig");
const MaybeNullPubkey = @import("maybe_null_pubkey.zig").MaybeNullPubkey;

/// Minimal raw instruction helper for interface consumers that already
/// own both the account-meta slice and exact data bytes.
pub inline fn buildRawInstruction(
    program_id: *const payloads.Pubkey,
    accounts: []const payloads.AccountMeta,
    data: []const u8,
) payloads.Instruction {
    return payloads.Instruction.init(program_id, accounts, data);
}

pub fn initializeDataLen(name: []const u8, symbol: []const u8, uri: []const u8) payloads.BuildError!usize {
    return (payloads.TokenMetadataInstruction{
        .initialize = .{
            .name = name,
            .symbol = symbol,
            .uri = uri,
        },
    }).packedLen();
}

pub fn updateFieldDataLen(field: payloads.Field, value: []const u8) payloads.BuildError!usize {
    return (payloads.TokenMetadataInstruction{
        .update_field = .{
            .field = field,
            .value = value,
        },
    }).packedLen();
}

pub fn removeKeyDataLen(key: []const u8) payloads.BuildError!usize {
    return (payloads.TokenMetadataInstruction{
        .remove_key = .{
            .idempotent = false,
            .key = key,
        },
    }).packedLen();
}

pub inline fn emitDataLen(start: ?u64, end: ?u64) usize {
    return sol.DISCRIMINATOR_LEN + optionU64Len(start) + optionU64Len(end);
}

fn optionU64Len(value: ?u64) usize {
    return if (value == null) 1 else 1 + @sizeOf(u64);
}

pub fn initialize(
    program_id: *const payloads.Pubkey,
    metadata_pubkey: *const payloads.Pubkey,
    update_authority_pubkey: *const payloads.Pubkey,
    mint_pubkey: *const payloads.Pubkey,
    mint_authority_pubkey: *const payloads.Pubkey,
    name: []const u8,
    symbol: []const u8,
    uri: []const u8,
    metas: *payloads.InitializeMetas,
    data: []u8,
) payloads.BuildError!payloads.Instruction {
    metas.* = .{
        payloads.AccountMeta.writable(metadata_pubkey),
        payloads.AccountMeta.readonly(update_authority_pubkey),
        payloads.AccountMeta.readonly(mint_pubkey),
        payloads.AccountMeta.signer(mint_authority_pubkey),
    };
    const data_slice = try (payloads.TokenMetadataInstruction{
        .initialize = .{
            .name = name,
            .symbol = symbol,
            .uri = uri,
        },
    }).pack(data);
    return payloads.Instruction.init(program_id, metas, data_slice);
}

pub fn updateField(
    program_id: *const payloads.Pubkey,
    metadata_pubkey: *const payloads.Pubkey,
    update_authority_pubkey: *const payloads.Pubkey,
    field: payloads.Field,
    value: []const u8,
    metas: *payloads.UpdateFieldMetas,
    data: []u8,
) payloads.BuildError!payloads.Instruction {
    metas.* = .{
        payloads.AccountMeta.writable(metadata_pubkey),
        payloads.AccountMeta.signer(update_authority_pubkey),
    };
    const data_slice = try (payloads.TokenMetadataInstruction{
        .update_field = .{
            .field = field,
            .value = value,
        },
    }).pack(data);
    return payloads.Instruction.init(program_id, metas, data_slice);
}

pub fn removeKey(
    program_id: *const payloads.Pubkey,
    metadata_pubkey: *const payloads.Pubkey,
    update_authority_pubkey: *const payloads.Pubkey,
    key: []const u8,
    idempotent: bool,
    metas: *payloads.RemoveKeyMetas,
    data: []u8,
) payloads.BuildError!payloads.Instruction {
    metas.* = .{
        payloads.AccountMeta.writable(metadata_pubkey),
        payloads.AccountMeta.signer(update_authority_pubkey),
    };
    const data_slice = try (payloads.TokenMetadataInstruction{
        .remove_key = .{
            .idempotent = idempotent,
            .key = key,
        },
    }).pack(data);
    return payloads.Instruction.init(program_id, metas, data_slice);
}

pub fn updateAuthority(
    program_id: *const payloads.Pubkey,
    metadata_pubkey: *const payloads.Pubkey,
    current_authority_pubkey: *const payloads.Pubkey,
    new_authority: MaybeNullPubkey,
    metas: *payloads.UpdateAuthorityMetas,
    data: []u8,
) payloads.BuildError!payloads.Instruction {
    metas.* = .{
        payloads.AccountMeta.writable(metadata_pubkey),
        payloads.AccountMeta.signer(current_authority_pubkey),
    };
    const data_slice = try (payloads.TokenMetadataInstruction{
        .update_authority = .{
            .new_authority = new_authority,
        },
    }).pack(data);
    return payloads.Instruction.init(program_id, metas, data_slice);
}

pub fn emit(
    program_id: *const payloads.Pubkey,
    metadata_pubkey: *const payloads.Pubkey,
    start: ?u64,
    end: ?u64,
    metas: *payloads.EmitMetas,
    data: []u8,
) payloads.BuildError!payloads.Instruction {
    metas.* = .{
        payloads.AccountMeta.readonly(metadata_pubkey),
    };
    const data_slice = try (payloads.TokenMetadataInstruction{
        .emit = .{
            .start = start,
            .end = end,
        },
    }).pack(data);
    return payloads.Instruction.init(program_id, metas, data_slice);
}
