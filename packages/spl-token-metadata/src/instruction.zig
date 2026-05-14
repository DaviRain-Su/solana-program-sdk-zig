//! SPL Token Metadata instruction builders and parsers.

const std = @import("std");
const payloads = @import("instruction_payloads.zig");
const builders = @import("instruction_builders.zig");

pub const Pubkey = payloads.Pubkey;
pub const AccountMeta = payloads.AccountMeta;
pub const Instruction = payloads.Instruction;
pub const ProgramError = payloads.ProgramError;
pub const NAMESPACE = payloads.NAMESPACE;
pub const Field = payloads.Field;

pub const INITIALIZE_DISCRIMINATOR = payloads.INITIALIZE_DISCRIMINATOR;
pub const UPDATE_FIELD_DISCRIMINATOR = payloads.UPDATE_FIELD_DISCRIMINATOR;
pub const REMOVE_KEY_DISCRIMINATOR = payloads.REMOVE_KEY_DISCRIMINATOR;
pub const UPDATE_AUTHORITY_DISCRIMINATOR = payloads.UPDATE_AUTHORITY_DISCRIMINATOR;
pub const EMIT_DISCRIMINATOR = payloads.EMIT_DISCRIMINATOR;

pub const initialize_accounts_len = payloads.initialize_accounts_len;
pub const update_field_accounts_len = payloads.update_field_accounts_len;
pub const remove_key_accounts_len = payloads.remove_key_accounts_len;
pub const update_authority_accounts_len = payloads.update_authority_accounts_len;
pub const emit_accounts_len = payloads.emit_accounts_len;
pub const update_authority_data_len = payloads.update_authority_data_len;

pub const InitializeMetas = payloads.InitializeMetas;
pub const UpdateFieldMetas = payloads.UpdateFieldMetas;
pub const RemoveKeyMetas = payloads.RemoveKeyMetas;
pub const UpdateAuthorityMetas = payloads.UpdateAuthorityMetas;
pub const EmitMetas = payloads.EmitMetas;

pub const BuildError = payloads.BuildError;
pub const Initialize = payloads.Initialize;
pub const UpdateField = payloads.UpdateField;
pub const RemoveKey = payloads.RemoveKey;
pub const UpdateAuthority = payloads.UpdateAuthority;
pub const Emit = payloads.Emit;
pub const TokenMetadataInstruction = payloads.TokenMetadataInstruction;

pub const buildRawInstruction = builders.buildRawInstruction;
pub const initializeDataLen = builders.initializeDataLen;
pub const updateFieldDataLen = builders.updateFieldDataLen;
pub const removeKeyDataLen = builders.removeKeyDataLen;
pub const emitDataLen = builders.emitDataLen;
pub const initialize = builders.initialize;
pub const updateField = builders.updateField;
pub const removeKey = builders.removeKey;
pub const updateAuthority = builders.updateAuthority;
pub const emit = builders.emit;

test {
    std.testing.refAllDecls(payloads);
    std.testing.refAllDecls(builders);
    _ = @import("instruction_tests.zig");
}
