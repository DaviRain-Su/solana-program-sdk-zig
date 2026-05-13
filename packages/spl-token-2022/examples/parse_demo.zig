//! Parsing-only Token-2022 SBF demo.
//!
//! Built artifact name: `example_spl_token_2022_parse`
//!
//! ## Instruction ABI
//!
//! ```text
//! byte 0      route
//! bytes 1..2  extension_type, little-endian u16
//! bytes 3..4  expected_len, little-endian u16
//! bytes 5..   expected raw view bytes, length = expected_len
//! ```
//!
//! Route tags:
//! - `0`: verify mint extension bytes against account 0
//! - `1`: verify token-account extension bytes against account 0
//!
//! ## Stable failure mapping
//!
//! The demo preserves the architecture-defined categories as stable
//! custom errors:
//!
//! - `6100`: invalid_instruction_data
//! - `6101`: invalid_account_list
//! - `6102`: incorrect_program_id
//! - `6103`: wrong_account_type
//! - `6104`: invalid_account_data
//! - `6105`: extension_not_found
//! - `6106`: unsupported_extension
//! - `6107`: invalid_extension_length
//!
//! Success is returned only when the parsed raw extension-view bytes
//! match the instruction's expected bytes exactly.

const std = @import("std");
const sol = @import("solana_program_sdk");
const token2022 = @import("spl_token_2022");

pub const panic = sol.panic.Panic;

const DemoError = sol.ErrorCode(
    enum(u32) {
        InvalidInstructionData = 6100,
        InvalidAccountList = 6101,
        IncorrectProgramId = 6102,
        WrongAccountType = 6103,
        InvalidAccountData = 6104,
        ExtensionNotFound = 6105,
        UnsupportedExtension = 6106,
        InvalidExtensionLength = 6107,
    },
    error{
        InvalidInstructionData,
        InvalidAccountList,
        IncorrectProgramId,
        WrongAccountType,
        InvalidAccountData,
        ExtensionNotFound,
        UnsupportedExtension,
        InvalidExtensionLength,
    },
);

const Route = enum(u8) {
    mint = 0,
    account = 1,
};

const ParsedInstruction = struct {
    route: Route,
    extension_type: token2022.ExtensionType,
    expected_bytes: []const u8,
};

fn parseRoute(tag: u8) DemoError.Error!Route {
    return switch (tag) {
        0 => .mint,
        1 => .account,
        else => DemoError.toError(.InvalidInstructionData),
    };
}

fn parseExtensionType(raw: u16) DemoError.Error!token2022.ExtensionType {
    inline for (@typeInfo(token2022.ExtensionType).@"enum".fields) |field| {
        if (raw == field.value) {
            return @field(token2022.ExtensionType, field.name);
        }
    }
    return DemoError.toError(.InvalidInstructionData);
}

fn parseInstruction(data: []const u8) DemoError.Error!ParsedInstruction {
    if (data.len < 5) return DemoError.toError(.InvalidInstructionData);

    const route = try parseRoute(data[0]);
    const extension_type = try parseExtensionType(std.mem.readInt(u16, data[1..3], .little));
    const expected_len: usize = std.mem.readInt(u16, data[3..5], .little);
    const expected_bytes = data[5..];
    if (expected_bytes.len != expected_len) return DemoError.toError(.InvalidInstructionData);

    return .{
        .route = route,
        .extension_type = extension_type,
        .expected_bytes = expected_bytes,
    };
}

fn mapParserError(err: token2022.tlv.Error) DemoError.Error {
    return switch (err) {
        error.InvalidAccountData => DemoError.toError(.InvalidAccountData),
        error.WrongAccountType => DemoError.toError(.WrongAccountType),
        error.ExtensionNotFound => DemoError.toError(.ExtensionNotFound),
    };
}

fn mintPayloadLen(extension_type: token2022.ExtensionType) DemoError.Error!usize {
    return switch (extension_type) {
        .transfer_fee_config => 108,
        .mint_close_authority => 32,
        .default_account_state => 1,
        .non_transferable => 0,
        .interest_bearing_config => 52,
        .permanent_delegate => 32,
        .transfer_hook => 64,
        .metadata_pointer => 64,
        .group_pointer => 64,
        .group_member_pointer => 64,
        .scaled_ui_amount => 56,
        .pausable => 33,

        .transfer_fee_amount,
        .immutable_owner,
        .memo_transfer,
        .cpi_guard,
        .non_transferable_account,
        .transfer_hook_account,
        .pausable_account,
        => DemoError.toError(.WrongAccountType),

        .confidential_transfer_mint,
        .confidential_transfer_account,
        .confidential_transfer_fee_config,
        .confidential_transfer_fee_amount,
        .token_metadata,
        .token_group,
        .token_group_member,
        .confidential_mint_burn,
        .permissioned_burn,
        .uninitialized,
        => DemoError.toError(.UnsupportedExtension),
    };
}

fn accountPayloadLen(extension_type: token2022.ExtensionType) DemoError.Error!usize {
    return switch (extension_type) {
        .transfer_fee_amount => 8,
        .immutable_owner => 0,
        .memo_transfer => 1,
        .cpi_guard => 1,
        .non_transferable_account => 0,
        .transfer_hook_account => 1,
        .pausable_account => 0,

        .transfer_fee_config,
        .mint_close_authority,
        .default_account_state,
        .non_transferable,
        .interest_bearing_config,
        .permanent_delegate,
        .transfer_hook,
        .metadata_pointer,
        .group_pointer,
        .group_member_pointer,
        .scaled_ui_amount,
        .pausable,
        => DemoError.toError(.WrongAccountType),

        .confidential_transfer_mint,
        .confidential_transfer_account,
        .confidential_transfer_fee_config,
        .confidential_transfer_fee_amount,
        .token_metadata,
        .token_group,
        .token_group_member,
        .confidential_mint_burn,
        .permissioned_burn,
        .uninitialized,
        => DemoError.toError(.UnsupportedExtension),
    };
}

fn findMintPayload(mint_bytes: []const u8, extension_type: token2022.ExtensionType) DemoError.Error![]const u8 {
    const expected_len = try mintPayloadLen(extension_type);
    const record = token2022.findMintExtension(mint_bytes, @intFromEnum(extension_type)) catch |err|
        return mapParserError(err);
    if (record.value.len != expected_len) return DemoError.toError(.InvalidExtensionLength);
    return record.value;
}

fn findAccountPayload(account_bytes: []const u8, extension_type: token2022.ExtensionType) DemoError.Error![]const u8 {
    const expected_len = try accountPayloadLen(extension_type);
    const record = token2022.findAccountExtension(account_bytes, @intFromEnum(extension_type)) catch |err|
        return mapParserError(err);
    if (record.value.len != expected_len) return DemoError.toError(.InvalidExtensionLength);
    return record.value;
}

fn process(ctx: *sol.InstructionContext) DemoError.Error!void {
    if (ctx.remainingAccounts() != 1) return DemoError.toError(.InvalidAccountList);

    const accs = ctx.parseAccountsUnchecked(.{"data"}) catch
        return DemoError.toError(.InvalidAccountList);
    const data_account = accs.data;

    if (data_account.isSigner() or data_account.isWritable()) {
        return DemoError.toError(.InvalidAccountList);
    }
    if (!data_account.isOwnedByComptime(token2022.PROGRAM_ID)) {
        return DemoError.toError(.IncorrectProgramId);
    }

    const ix = try parseInstruction(ctx.instructionData() catch
        return DemoError.toError(.InvalidInstructionData));

    const actual_bytes = switch (ix.route) {
        .mint => try findMintPayload(data_account.data(), ix.extension_type),
        .account => try findAccountPayload(data_account.data(), ix.extension_type),
    };

    if (actual_bytes.len != ix.expected_bytes.len) {
        return DemoError.toError(.InvalidInstructionData);
    }
    if (!std.mem.eql(u8, actual_bytes, ix.expected_bytes)) {
        return DemoError.toError(.InvalidInstructionData);
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointTyped(DemoError, process)(input);
}
