//! Zig implementation of Anchor-style comptime derives
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/syn/src/codegen/accounts/mod.rs
//!
//! This module provides lightweight comptime helpers that validate account and
//! event structs while keeping the original types intact.

const std = @import("std");
const sol = @import("solana_program_sdk");
const account_mod = @import("account.zig");
const attr_mod = @import("attr.zig");
const signer_mod = @import("signer.zig");
const program_mod = @import("program.zig");
const sysvar_account = @import("sysvar_account.zig");
const discriminator_mod = @import("discriminator.zig");
const seeds_mod = @import("seeds.zig");
const has_one_mod = @import("has_one.zig");

const AccountInfo = sol.account.Account.Info;
const Signer = signer_mod.Signer;
const SignerMut = signer_mod.SignerMut;
const UncheckedProgram = program_mod.UncheckedProgram;
const SeedSpec = seeds_mod.SeedSpec;

/// Validate Accounts struct and return it unchanged.
pub fn Accounts(comptime T: type) type {
    comptime validateAccounts(T);
    return T;
}

/// Validate Accounts struct and apply field-level attrs.
pub fn AccountsWith(comptime T: type, comptime config: anytype) type {
    comptime validateAccountsWith(T, config);
    return applyAccountAttrs(T, config, false);
}

/// Validate Accounts struct and apply field attrs from `T.attrs`.
pub fn AccountsDerive(comptime T: type) type {
    if (!@hasDecl(T, "attrs")) {
        return applyAccountAttrs(T, .{}, true);
    }
    return applyAccountAttrs(T, @field(T, "attrs"), true);
}

/// Typed attribute marker for account fields.
///
/// Use with `.apply(Base)` since Zig doesn't support custom type annotations.
pub fn Attrs(comptime config: attr_mod.AccountAttrConfig) type {
    return struct {
        pub fn apply(comptime Base: type) type {
            if (!@hasDecl(Base, "DataType")) {
                @compileError("Attrs can only be applied to Account types");
            }
            validateAttrConflicts(Base, config);
            return account_mod.AccountField(Base, attr_mod.attr.account(config));
        }
    };
}

/// Typed attribute helper for account fields.
pub fn AttrsWith(comptime config: attr_mod.AccountAttrConfig, comptime Base: type) type {
    return Attrs(config).apply(Base);
}

/// Typed attribute helper that resolves field enums into AccountAttrConfig.
pub fn AttrsFor(comptime AccountsType: type, comptime DataType: type, comptime config: anytype) type {
    const resolved = resolveTypedAttrConfig(AccountsType, DataType, config);
    return Attrs(resolved);
}

fn accountDefaultSpace(comptime DataType: type) usize {
    return discriminator_mod.DISCRIMINATOR_LENGTH + @sizeOf(DataType);
}

fn validateAttrConflicts(comptime Base: type, comptime config: attr_mod.AccountAttrConfig) void {
    if (config.mut and Base.HAS_MUT) {
        @compileError("Attrs conflict: mut already set on Account");
    }
    if (config.signer and Base.HAS_SIGNER) {
        @compileError("Attrs conflict: signer already set on Account");
    }
    if (config.zero and Base.IS_ZERO) {
        @compileError("Attrs conflict: zero already set on Account");
    }
    if (config.dup and Base.IS_DUP) {
        @compileError("Attrs conflict: dup already set on Account");
    }
    if (config.seeds != null and Base.SEEDS != null) {
        @compileError("Attrs conflict: seeds already set on Account");
    }
    if (config.bump and Base.HAS_BUMP) {
        @compileError("Attrs conflict: bump already set on Account");
    }
    if (config.bump_field != null and Base.BUMP_FIELD != null) {
        @compileError("Attrs conflict: bump_field already set on Account");
    }
    if (config.seeds_program != null and Base.SEEDS_PROGRAM != null) {
        @compileError("Attrs conflict: seeds_program already set on Account");
    }
    if (config.init and Base.IS_INIT) {
        @compileError("Attrs conflict: init already set on Account");
    }
    if (config.init_if_needed and Base.IS_INIT_IF_NEEDED) {
        @compileError("Attrs conflict: init_if_needed already set on Account");
    }
    if (config.payer != null and Base.PAYER != null) {
        @compileError("Attrs conflict: payer already set on Account");
    }
    if (config.close != null and Base.CLOSE != null) {
        @compileError("Attrs conflict: close already set on Account");
    }
    if ((config.has_one != null or config.has_one_fields != null) and Base.HAS_ONE != null) {
        @compileError("Attrs conflict: has_one already set on Account");
    }
    if (config.realloc != null and Base.REALLOC != null) {
        @compileError("Attrs conflict: realloc already set on Account");
    }
    if (config.rent_exempt and Base.RENT_EXEMPT) {
        @compileError("Attrs conflict: rent_exempt already set on Account");
    }
    if (config.constraint != null and Base.CONSTRAINT != null) {
        @compileError("Attrs conflict: constraint already set on Account");
    }
    if (config.owner != null and Base.OWNER != null) {
        @compileError("Attrs conflict: owner already set on Account");
    }
    if (config.owner_expr != null and Base.OWNER_EXPR != null) {
        @compileError("Attrs conflict: owner_expr already set on Account");
    }
    if (config.address != null and Base.ADDRESS != null) {
        @compileError("Attrs conflict: address already set on Account");
    }
    if (config.address_expr != null and Base.ADDRESS_EXPR != null) {
        @compileError("Attrs conflict: address_expr already set on Account");
    }
    if (config.executable and Base.EXECUTABLE) {
        @compileError("Attrs conflict: executable already set on Account");
    }
    if (config.space != null) {
        const default_space = accountDefaultSpace(Base.DataType);
        if (Base.SPACE_EXPR != null or Base.SPACE != default_space) {
            @compileError("Attrs conflict: space already set on Account");
        }
    }
    if (config.space_expr != null and Base.SPACE_EXPR != null) {
        @compileError("Attrs conflict: space_expr already set on Account");
    }
    if (config.associated_token_mint != null and Base.ASSOCIATED_TOKEN != null) {
        @compileError("Attrs conflict: associated_token already set on Account");
    }
    if (config.associated_token_authority != null and Base.ASSOCIATED_TOKEN != null) {
        @compileError("Attrs conflict: associated_token already set on Account");
    }
    if (config.associated_token_token_program != null and Base.ASSOCIATED_TOKEN != null) {
        @compileError("Attrs conflict: associated_token already set on Account");
    }
    if (config.token_mint != null and Base.TOKEN_MINT != null) {
        @compileError("Attrs conflict: token_mint already set on Account");
    }
    if (config.token_authority != null and Base.TOKEN_AUTHORITY != null) {
        @compileError("Attrs conflict: token_authority already set on Account");
    }
    if (config.token_program != null and Base.TOKEN_PROGRAM != null) {
        @compileError("Attrs conflict: token_program already set on Account");
    }
    if (config.mint_authority != null and Base.MINT_AUTHORITY != null) {
        @compileError("Attrs conflict: mint_authority already set on Account");
    }
    if (config.mint_freeze_authority != null and Base.MINT_FREEZE_AUTHORITY != null) {
        @compileError("Attrs conflict: mint_freeze_authority already set on Account");
    }
    if (config.mint_decimals != null and Base.MINT_DECIMALS != null) {
        @compileError("Attrs conflict: mint_decimals already set on Account");
    }
    if (config.mint_token_program != null and Base.MINT_TOKEN_PROGRAM != null) {
        @compileError("Attrs conflict: mint_token_program already set on Account");
    }
}

/// Typed seed spec for Accounts/Data field enums.
pub fn SeedSpecFor(comptime AccountsType: type, comptime DataType: type) type {
    return union(enum) {
        literal: []const u8,
        account: std.meta.FieldEnum(AccountsType),
        field: std.meta.FieldEnum(DataType),
        bump: std.meta.FieldEnum(AccountsType),
    };
}

/// Typed seed spec builder that resolves field enums.
pub fn seedSpecsFor(comptime AccountsType: type, comptime DataType: type, comptime specs: anytype) []const SeedSpec {
    return resolveSeedSpecs(AccountsType, DataType, specs);
}

/// Typed has_one spec for Accounts/Data field enums.
pub fn HasOneSpecFor(comptime AccountsType: type, comptime DataType: type) type {
    return struct {
        field: std.meta.FieldEnum(DataType),
        target: std.meta.FieldEnum(AccountsType),

        pub fn init(
            comptime field: std.meta.FieldEnum(DataType),
            comptime target: std.meta.FieldEnum(AccountsType),
        ) @This() {
            return .{ .field = field, .target = target };
        }
    };
}

/// Typed associated token config for Accounts field enums.
pub fn AssociatedTokenFor(comptime AccountsType: type) type {
    return struct {
        mint: std.meta.FieldEnum(AccountsType),
        authority: std.meta.FieldEnum(AccountsType),
        token_program: ?std.meta.FieldEnum(AccountsType) = null,

        pub fn init(
            comptime mint: std.meta.FieldEnum(AccountsType),
            comptime authority: std.meta.FieldEnum(AccountsType),
        ) @This() {
            return .{ .mint = mint, .authority = authority };
        }

        pub fn withTokenProgram(
            comptime mint: std.meta.FieldEnum(AccountsType),
            comptime authority: std.meta.FieldEnum(AccountsType),
            comptime token_program: std.meta.FieldEnum(AccountsType),
        ) @This() {
            return .{ .mint = mint, .authority = authority, .token_program = token_program };
        }
    };
}

/// Typed token constraint config for Accounts field enums.
pub fn TokenFor(comptime AccountsType: type) type {
    return struct {
        mint: std.meta.FieldEnum(AccountsType),
        authority: std.meta.FieldEnum(AccountsType),
        program: ?std.meta.FieldEnum(AccountsType) = null,

        pub fn init(
            comptime mint: std.meta.FieldEnum(AccountsType),
            comptime authority: std.meta.FieldEnum(AccountsType),
        ) @This() {
            return .{ .mint = mint, .authority = authority };
        }

        pub fn withProgram(
            comptime mint: std.meta.FieldEnum(AccountsType),
            comptime authority: std.meta.FieldEnum(AccountsType),
            comptime program: std.meta.FieldEnum(AccountsType),
        ) @This() {
            return .{ .mint = mint, .authority = authority, .program = program };
        }
    };
}

/// Typed mint constraint config for Accounts field enums.
pub fn MintFor(comptime AccountsType: type) type {
    return struct {
        authority: std.meta.FieldEnum(AccountsType),
        freeze_authority: ?std.meta.FieldEnum(AccountsType) = null,
        decimals: ?u8 = null,
        program: ?std.meta.FieldEnum(AccountsType) = null,

        pub fn init(
            comptime authority: std.meta.FieldEnum(AccountsType),
        ) @This() {
            return .{ .authority = authority };
        }

        pub fn withFreeze(
            comptime authority: std.meta.FieldEnum(AccountsType),
            comptime freeze_authority: std.meta.FieldEnum(AccountsType),
        ) @This() {
            return .{ .authority = authority, .freeze_authority = freeze_authority };
        }

        pub fn withProgram(
            comptime authority: std.meta.FieldEnum(AccountsType),
            comptime program: std.meta.FieldEnum(AccountsType),
        ) @This() {
            return .{ .authority = authority, .program = program };
        }
    };
}

/// Typed init/payer/space helper for Accounts field enums.
pub fn InitFor(comptime AccountsType: type) type {
    return struct {
        payer: std.meta.FieldEnum(AccountsType),
        space: ?usize = null,
        init_if_needed: bool = false,

        pub fn init(
            comptime payer: std.meta.FieldEnum(AccountsType),
        ) @This() {
            return .{ .payer = payer };
        }

        pub fn withSpace(
            comptime payer: std.meta.FieldEnum(AccountsType),
            comptime space: usize,
        ) @This() {
            return .{ .payer = payer, .space = space };
        }

        pub fn ifNeeded(
            comptime payer: std.meta.FieldEnum(AccountsType),
        ) @This() {
            return .{ .payer = payer, .init_if_needed = true };
        }
    };
}

/// Typed close helper for Accounts field enums.
pub fn CloseFor(comptime AccountsType: type) type {
    return struct {
        destination: std.meta.FieldEnum(AccountsType),

        pub fn init(comptime destination: std.meta.FieldEnum(AccountsType)) @This() {
            return .{ .destination = destination };
        }
    };
}

/// Typed realloc helper for Accounts field enums.
pub fn ReallocFor(comptime AccountsType: type) type {
    return struct {
        payer: std.meta.FieldEnum(AccountsType),
        zero_init: bool = false,

        pub fn init(comptime payer: std.meta.FieldEnum(AccountsType)) @This() {
            return .{ .payer = payer };
        }

        pub fn zeroed(comptime payer: std.meta.FieldEnum(AccountsType)) @This() {
            return .{ .payer = payer, .zero_init = true };
        }
    };
}

/// Typed owner/address/executable/space helper for Accounts field enums.
pub fn AccessFor(comptime AccountsType: type, comptime DataType: type) type {
    _ = DataType;
    return struct {
        owner: ?std.meta.FieldEnum(AccountsType) = null,
        address: ?std.meta.FieldEnum(AccountsType) = null,
        executable: bool = false,
        space: ?usize = null,

        pub fn ownerOnly(comptime owner: std.meta.FieldEnum(AccountsType)) @This() {
            return .{ .owner = owner };
        }

        pub fn addressOnly(comptime address: std.meta.FieldEnum(AccountsType)) @This() {
            return .{ .address = address };
        }

        pub fn executableOnly() @This() {
            return .{ .executable = true };
        }

        pub fn withSpace(comptime space: usize) @This() {
            return .{ .space = space };
        }

        pub fn ownerAndSpace(
            comptime owner: std.meta.FieldEnum(AccountsType),
            comptime space: usize,
        ) @This() {
            return .{ .owner = owner, .space = space };
        }

        pub fn addressAndSpace(
            comptime address: std.meta.FieldEnum(AccountsType),
            comptime space: usize,
        ) @This() {
            return .{ .address = address, .space = space };
        }
    };
}

/// Event field configuration.
pub const EventField = struct {
    /// Mark this field as indexed in the IDL.
    index: bool = false,
};

/// Wrap an indexed event field.
///
/// Example:
/// ```zig
/// amount: anchor.eventField(u64, .{ .index = true }),
/// ```
pub fn eventField(comptime T: type, comptime config: EventField) type {
    return struct {
        pub const FieldType = T;
        pub const FIELD_CONFIG = config;
    };
}

/// Validate Event struct and return it unchanged.
pub fn Event(comptime T: type) type {
    comptime validateEvent(T);
    return T;
}

fn validateAccounts(comptime T: type) void {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("Accounts must be a struct type");
    }

    const fields = info.@"struct".fields;
    if (fields.len == 0) {
        @compileError("Accounts struct must have at least one field");
    }

    inline for (fields) |field| {
        const FieldType = field.type;
        if (@hasDecl(FieldType, "load")) {
            continue;
        }
        if (FieldType == *const AccountInfo) {
            continue;
        }

        @compileError("Unsupported account field type: " ++ field.name);
    }
}

fn validateAccountsWith(comptime T: type, comptime config: anytype) void {
    validateAccounts(T);
    if (@typeInfo(@TypeOf(config)) != .@"struct") {
        @compileError("AccountsWith config must be a struct");
    }
}

fn unwrapOptionalType(comptime T: type) type {
    const info = @typeInfo(T);
    if (info == .optional) {
        return info.optional.child;
    }
    return T;
}

fn isAccountWrapper(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") return false;
    return @hasDecl(T, "DataType") and @hasDecl(T, "discriminator");
}

fn fieldIndexByName(comptime T: type, comptime name: []const u8) usize {
    return std.meta.fieldIndex(T, name) orelse {
        @compileError("account constraint references unknown Accounts field: " ++ name);
    };
}

fn resolveAccountFieldName(comptime AccountsType: type, comptime value: anytype) []const u8 {
    const ValueType = @TypeOf(value);
    if (ValueType == []const u8) return value;
    if (@typeInfo(ValueType) == .enum_literal) return @tagName(value);
    if (ValueType == std.meta.FieldEnum(AccountsType)) return @tagName(value);
    @compileError("expected account field name or field enum");
}

fn resolveAccountFieldNameOpt(comptime AccountsType: type, comptime value: anytype) ?[]const u8 {
    const ValueType = @TypeOf(value);
    if (ValueType == ?[]const u8) return value;
    if (@typeInfo(ValueType) == .optional) {
        if (value == null) return null;
        return resolveAccountFieldName(AccountsType, value.?);
    }
    return resolveAccountFieldName(AccountsType, value);
}

fn resolveAccountFieldKey(
    comptime AccountsType: type,
    comptime value: anytype,
) ?sol.PublicKey {
    const name = resolveAccountFieldNameOpt(AccountsType, value) orelse return null;
    const field_index = fieldIndexByName(AccountsType, name);
    const field_type = @typeInfo(AccountsType).@"struct".fields[field_index].type;
    const CleanType = unwrapOptionalType(field_type);
    if (@hasDecl(CleanType, "ID")) {
        return CleanType.ID;
    }
    @compileError("access helper requires field with static ID: " ++ name);
}

fn resolveDataFieldName(comptime DataType: type, comptime value: anytype) []const u8 {
    const ValueType = @TypeOf(value);
    if (ValueType == []const u8) return value;
    if (@typeInfo(ValueType) == .enum_literal) return @tagName(value);
    if (ValueType == std.meta.FieldEnum(DataType)) return @tagName(value);
    @compileError("expected data field name or field enum");
}

fn resolveDataFieldNameOpt(comptime DataType: type, comptime value: anytype) ?[]const u8 {
    const ValueType = @TypeOf(value);
    if (ValueType == ?[]const u8) return value;
    if (@typeInfo(ValueType) == .optional) {
        if (value == null) return null;
        return resolveDataFieldName(DataType, value.?);
    }
    return resolveDataFieldName(DataType, value);
}

fn resolveDataFieldList(comptime DataType: type, comptime value: anytype) []const []const u8 {
    const ValueType = @TypeOf(value);
    if (ValueType == []const []const u8) return value;
    if (ValueType == []const std.meta.FieldEnum(DataType)) {
        const names = comptime blk: {
            var tmp: [value.len][]const u8 = undefined;
            for (value, 0..) |field, index| {
                tmp[index] = @tagName(field);
            }
            break :blk tmp;
        };
        return names[0..];
    }
    const info = @typeInfo(ValueType);
    if (info == .pointer and info.pointer.size == .slice) {
        if (value.len > 0) {
            const elem_info = @typeInfo(@TypeOf(value[0]));
            if (elem_info == .enum_literal or elem_info == .@"enum") {
                const names = comptime blk: {
                    var tmp: [value.len][]const u8 = undefined;
                    for (value, 0..) |field, index| {
                        tmp[index] = @tagName(field);
                    }
                    break :blk tmp;
                };
                return names[0..];
            }
        }
    }
    if (info == .pointer and info.pointer.size == .one) {
        const child_info = @typeInfo(info.pointer.child);
        if (child_info == .array) {
            const elem_info = @typeInfo(child_info.array.child);
            if (elem_info == .enum_literal or elem_info == .@"enum") {
                const names = comptime blk: {
                    var tmp: [child_info.array.len][]const u8 = undefined;
                    for (value.*, 0..) |field, index| {
                        tmp[index] = @tagName(field);
                    }
                    break :blk tmp;
                };
                return names[0..];
            }
        }
    }
    if (info == .array) {
        const elem_info = @typeInfo(info.array.child);
        if (elem_info == .enum_literal or elem_info == .@"enum") {
            const names = comptime blk: {
                var tmp: [info.array.len][]const u8 = undefined;
                for (value, 0..) |field, index| {
                    tmp[index] = @tagName(field);
                }
                break :blk tmp;
            };
            return names[0..];
        }
    }
    @compileError("expected data field list or field enum list");
}

fn resolveDataFieldListOpt(comptime DataType: type, comptime value: anytype) ?[]const []const u8 {
    const ValueType = @TypeOf(value);
    if (ValueType == ?[]const []const u8) return value;
    if (@typeInfo(ValueType) == .optional) {
        if (value == null) return null;
        return resolveDataFieldList(DataType, value.?);
    }
    return resolveDataFieldList(DataType, value);
}

fn resolveTypedAttrConfig(
    comptime AccountsType: type,
    comptime DataType: type,
    comptime config: anytype,
) attr_mod.AccountAttrConfig {
    if (@typeInfo(@TypeOf(config)) != .@"struct") {
        @compileError("AttrsFor config must be a struct");
    }

    var resolved: attr_mod.AccountAttrConfig = .{};
    inline for (@typeInfo(@TypeOf(config)).@"struct".fields) |field| {
        const value = @field(config, field.name);
        if (std.mem.eql(u8, field.name, "payer")) {
            resolved.payer = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "close")) {
            resolved.close = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "bump_field")) {
            resolved.bump_field = resolveDataFieldNameOpt(DataType, value);
        } else if (std.mem.eql(u8, field.name, "has_one_fields")) {
            resolved.has_one_fields = resolveDataFieldListOpt(DataType, value);
        } else if (std.mem.eql(u8, field.name, "associated_token_mint")) {
            resolved.associated_token_mint = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "associated_token_authority")) {
            resolved.associated_token_authority = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "associated_token_token_program")) {
            resolved.associated_token_token_program = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "associated_token")) {
            resolved.associated_token_mint = resolveAccountFieldNameOpt(AccountsType, @field(value, "mint"));
            resolved.associated_token_authority = resolveAccountFieldNameOpt(AccountsType, @field(value, "authority"));
            resolved.associated_token_token_program = resolveAccountFieldNameOpt(AccountsType, @field(value, "token_program"));
        } else if (std.mem.eql(u8, field.name, "token_mint")) {
            resolved.token_mint = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "token_authority")) {
            resolved.token_authority = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "token_program")) {
            resolved.token_program = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "token")) {
            resolved.token_mint = resolveAccountFieldNameOpt(AccountsType, @field(value, "mint"));
            resolved.token_authority = resolveAccountFieldNameOpt(AccountsType, @field(value, "authority"));
            resolved.token_program = resolveAccountFieldNameOpt(AccountsType, @field(value, "program"));
        } else if (std.mem.eql(u8, field.name, "mint_authority")) {
            resolved.mint_authority = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "mint_freeze_authority")) {
            resolved.mint_freeze_authority = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "mint_token_program")) {
            resolved.mint_token_program = resolveAccountFieldNameOpt(AccountsType, value);
        } else if (std.mem.eql(u8, field.name, "mint")) {
            resolved.mint_authority = resolveAccountFieldNameOpt(AccountsType, @field(value, "authority"));
            resolved.mint_freeze_authority = resolveAccountFieldNameOpt(AccountsType, @field(value, "freeze_authority"));
            resolved.mint_decimals = @field(value, "decimals");
            resolved.mint_token_program = resolveAccountFieldNameOpt(AccountsType, @field(value, "program"));
        } else if (std.mem.eql(u8, field.name, "seeds_program")) {
            resolved.seeds_program = resolveSeedSpecSingle(AccountsType, DataType, value);
        } else if (std.mem.eql(u8, field.name, "seeds")) {
            resolved.seeds = resolveSeedSpecs(AccountsType, DataType, value);
        } else if (std.mem.eql(u8, field.name, "has_one")) {
            resolved.has_one = resolveHasOneSpecs(AccountsType, DataType, value);
        } else if (std.mem.eql(u8, field.name, "realloc")) {
            resolved.realloc = value;
        } else if (std.mem.eql(u8, field.name, "init")) {
            resolved.init = value;
        } else if (std.mem.eql(u8, field.name, "init_if_needed")) {
            resolved.init_if_needed = value;
        } else if (std.mem.eql(u8, field.name, "init_with")) {
            resolved.init = true;
            resolved.payer = resolveAccountFieldNameOpt(AccountsType, @field(value, "payer"));
            resolved.init_if_needed = @field(value, "init_if_needed");
            resolved.space = @field(value, "space");
        } else if (std.mem.eql(u8, field.name, "bump")) {
            resolved.bump = value;
        } else if (std.mem.eql(u8, field.name, "mut")) {
            resolved.mut = value;
        } else if (std.mem.eql(u8, field.name, "signer")) {
            resolved.signer = value;
        } else if (std.mem.eql(u8, field.name, "zero")) {
            resolved.zero = value;
        } else if (std.mem.eql(u8, field.name, "dup")) {
            resolved.dup = value;
        } else if (std.mem.eql(u8, field.name, "rent_exempt")) {
            resolved.rent_exempt = value;
        } else if (std.mem.eql(u8, field.name, "space")) {
            resolved.space = value;
        } else if (std.mem.eql(u8, field.name, "close_to")) {
            resolved.close = resolveAccountFieldNameOpt(AccountsType, @field(value, "destination"));
        } else if (std.mem.eql(u8, field.name, "space_expr")) {
            resolved.space_expr = value;
        } else if (std.mem.eql(u8, field.name, "constraint")) {
            resolved.constraint = value;
        } else if (std.mem.eql(u8, field.name, "owner")) {
            resolved.owner = value;
        } else if (std.mem.eql(u8, field.name, "owner_expr")) {
            resolved.owner_expr = value;
        } else if (std.mem.eql(u8, field.name, "address")) {
            resolved.address = value;
        } else if (std.mem.eql(u8, field.name, "address_expr")) {
            resolved.address_expr = value;
        } else if (std.mem.eql(u8, field.name, "executable")) {
            resolved.executable = value;
        } else if (std.mem.eql(u8, field.name, "realloc_with")) {
            resolved.realloc = .{
                .payer = resolveAccountFieldNameOpt(AccountsType, @field(value, "payer")),
                .zero_init = @field(value, "zero_init"),
            };
        } else if (std.mem.eql(u8, field.name, "access")) {
            resolved.owner = resolveAccountFieldKey(AccountsType, @field(value, "owner"));
            resolved.address = resolveAccountFieldKey(AccountsType, @field(value, "address"));
            resolved.executable = @field(value, "executable");
            resolved.space = @field(value, "space");
        } else {
            @compileError("unsupported AttrsFor field: " ++ field.name);
        }
    }

    return resolved;
}

fn resolveHasOneSpecs(
    comptime AccountsType: type,
    comptime DataType: type,
    comptime value: anytype,
) []const has_one_mod.HasOneSpec {
    const ValueType = @TypeOf(value);
    if (ValueType == []const has_one_mod.HasOneSpec) return value;
    const TypedHasOne = HasOneSpecFor(AccountsType, DataType);
    if (ValueType == []const TypedHasOne) {
        const specs = comptime blk: {
            var tmp: [value.len]has_one_mod.HasOneSpec = undefined;
            for (value, 0..) |spec, index| {
                tmp[index] = .{
                    .field = @tagName(spec.field),
                    .target = @tagName(spec.target),
                };
            }
            break :blk tmp;
        };
        return specs[0..];
    }
    const info = @typeInfo(ValueType);
    if (info == .pointer and info.pointer.size == .one) {
        const child_info = @typeInfo(info.pointer.child);
        if (child_info == .array and child_info.array.child == TypedHasOne) {
            const specs = comptime blk: {
                var tmp: [child_info.array.len]has_one_mod.HasOneSpec = undefined;
                for (value.*, 0..) |spec, index| {
                    tmp[index] = .{
                        .field = @tagName(spec.field),
                        .target = @tagName(spec.target),
                    };
                }
                break :blk tmp;
            };
            return specs[0..];
        }
    }
    if (info == .array and info.array.child == TypedHasOne) {
        const specs = comptime blk: {
            var tmp: [info.array.len]has_one_mod.HasOneSpec = undefined;
            for (value, 0..) |spec, index| {
                tmp[index] = .{
                    .field = @tagName(spec.field),
                    .target = @tagName(spec.target),
                };
            }
            break :blk tmp;
        };
        return specs[0..];
    }
    @compileError("expected HasOneSpec list or typed has_one spec list");
}

fn resolveSeedSpecSingle(
    comptime AccountsType: type,
    comptime DataType: type,
    comptime value: anytype,
) SeedSpec {
    const ValueType = @TypeOf(value);
    if (ValueType == SeedSpec) return value;
    const TypedSeed = SeedSpecFor(AccountsType, DataType);
    if (ValueType == TypedSeed) return seedSpecFromTyped(AccountsType, DataType, value);
    @compileError("expected SeedSpec or typed seed spec");
}

fn resolveSeedSpecs(
    comptime AccountsType: type,
    comptime DataType: type,
    comptime value: anytype,
) []const SeedSpec {
    const ValueType = @TypeOf(value);
    if (ValueType == []const SeedSpec) return value;
    const TypedSeed = SeedSpecFor(AccountsType, DataType);
    if (ValueType == []const TypedSeed) {
        const specs = comptime blk: {
            var tmp: [value.len]SeedSpec = undefined;
            for (value, 0..) |seed, index| {
                tmp[index] = seedSpecFromTyped(AccountsType, DataType, seed);
            }
            break :blk tmp;
        };
        return specs[0..];
    }
    const info = @typeInfo(ValueType);
    if (info == .pointer and info.pointer.size == .one) {
        const child_info = @typeInfo(info.pointer.child);
        if (child_info == .array and child_info.array.child == TypedSeed) {
            const specs = comptime blk: {
                var tmp: [child_info.array.len]SeedSpec = undefined;
                for (value.*, 0..) |seed, index| {
                    tmp[index] = seedSpecFromTyped(AccountsType, DataType, seed);
                }
                break :blk tmp;
            };
            return specs[0..];
        }
    }
    if (info == .array and info.array.child == TypedSeed) {
        const specs = comptime blk: {
            var tmp: [info.array.len]SeedSpec = undefined;
            for (value, 0..) |seed, index| {
                tmp[index] = seedSpecFromTyped(AccountsType, DataType, seed);
            }
            break :blk tmp;
        };
        return specs[0..];
    }
    @compileError("expected SeedSpec list or typed seed spec list");
}

fn seedSpecFromTyped(
    comptime AccountsType: type,
    comptime DataType: type,
    comptime seed: SeedSpecFor(AccountsType, DataType),
) SeedSpec {
    return switch (seed) {
        .literal => |value| seeds_mod.seed(value),
        .account => |field| seeds_mod.seedAccount(@tagName(field)),
        .field => |field| seeds_mod.seedField(@tagName(field)),
        .bump => |field| seeds_mod.seedBump(@tagName(field)),
    };
}

fn hasKeyOrAccountInfo(comptime T: type) bool {
    const Clean = unwrapOptionalType(T);
    if (Clean == *const AccountInfo) return true;
    return @hasDecl(Clean, "key");
}

fn validateKeyTarget(comptime AccountsType: type, comptime name: []const u8) void {
    const fields = @typeInfo(AccountsType).@"struct".fields;
    const target_index = fieldIndexByName(AccountsType, name);
    const target_type = fields[target_index].type;
    if (!hasKeyOrAccountInfo(target_type)) {
        @compileError("account constraint target must have key() or be AccountInfo: " ++ name);
    }
}

fn validateBumpTarget(comptime AccountsType: type, comptime name: []const u8) void {
    const fields = @typeInfo(AccountsType).@"struct".fields;
    const target_index = fieldIndexByName(AccountsType, name);
    const target_type = unwrapOptionalType(fields[target_index].type);
    if (!@hasDecl(target_type, "HAS_SEEDS") or !target_type.HAS_SEEDS) {
        @compileError("bump seed must reference an account with seeds: " ++ name);
    }
}

fn validateSeedRef(comptime AccountsType: type, seed: SeedSpec) void {
    switch (seed) {
        .account => |name| validateKeyTarget(AccountsType, name),
        .bump => |name| validateBumpTarget(AccountsType, name),
        else => {},
    }
}

fn validateDerivedRefs(comptime AccountsType: type) void {
    const fields = @typeInfo(AccountsType).@"struct".fields;

    inline for (fields) |field| {
        const FieldType = unwrapOptionalType(field.type);
        if (!isAccountWrapper(FieldType)) continue;

        if (FieldType.HAS_ONE) |list| {
            inline for (list) |spec| {
                validateKeyTarget(AccountsType, spec.target);
            }
        }
        if (FieldType.SEEDS) |seeds| {
            inline for (seeds) |seed| {
                validateSeedRef(AccountsType, seed);
            }
        }
        if (FieldType.SEEDS_PROGRAM) |seed| {
            validateSeedRef(AccountsType, seed);
        }
    }
}

fn resolveAttrs(comptime value: anytype) []const attr_mod.Attr {
    const ValueType = @TypeOf(value);
    if (ValueType == []const attr_mod.Attr) {
        return value;
    }
    if (ValueType == attr_mod.AccountAttrConfig) {
        return attr_mod.attr.account(value);
    }
    if (ValueType == attr_mod.Attr) {
        const list = [_]attr_mod.Attr{value};
        return list[0..];
    }

    @compileError("AccountsWith expects Attr, []const Attr, or AccountAttrConfig");
}

const DerivedFlags = struct {
    mut: []const bool,
    signer: []const bool,
};

fn deriveAccountFlags(comptime T: type) DerivedFlags {
    const fields = @typeInfo(T).@"struct".fields;
    comptime var mut_flags: [fields.len]bool = [_]bool{false} ** fields.len;
    comptime var signer_flags: [fields.len]bool = [_]bool{false} ** fields.len;

    inline for (fields, 0..) |field, index| {
        const FieldType = unwrapOptionalType(field.type);
        if (!isAccountWrapper(FieldType)) continue;

        if (FieldType.IS_INIT or FieldType.IS_INIT_IF_NEEDED or FieldType.HAS_REALLOC or FieldType.CLOSE != null) {
            mut_flags[index] = true;
        }

        if (FieldType.PAYER) |name| {
            const target = fieldIndexByName(T, name);
            mut_flags[target] = true;
            signer_flags[target] = true;
        }

        if (FieldType.REALLOC) |cfg| {
            if (cfg.payer) |name| {
                const target = fieldIndexByName(T, name);
                mut_flags[target] = true;
                signer_flags[target] = true;
            }
        }

        if (FieldType.CLOSE) |name| {
            const target = fieldIndexByName(T, name);
            mut_flags[target] = true;
        }
    }

    return .{
        .mut = &mut_flags,
        .signer = &signer_flags,
    };
}

fn hasAttrMut(comptime attrs: []const attr_mod.Attr) bool {
    inline for (attrs) |attr| {
        if (attr == .mut) return true;
    }
    return false;
}

fn hasAttrSigner(comptime attrs: []const attr_mod.Attr) bool {
    inline for (attrs) |attr| {
        if (attr == .signer) return true;
    }
    return false;
}

fn mergeAttrs(
    comptime base: ?[]const attr_mod.Attr,
    comptime derived: []const attr_mod.Attr,
) ?[]const attr_mod.Attr {
    if (base == null and derived.len == 0) return null;
    if (base == null) return derived;
    if (derived.len == 0) return base;

    const base_attrs = base.?;
    const skip_mut = hasAttrMut(base_attrs);
    const skip_signer = hasAttrSigner(base_attrs);

    comptime var merged: [base_attrs.len + derived.len]attr_mod.Attr = undefined;
    comptime var index: usize = 0;

    inline for (base_attrs) |attr| {
        merged[index] = attr;
        index += 1;
    }

    inline for (derived) |attr| {
        switch (attr) {
            .mut => if (skip_mut) continue,
            .signer => if (skip_signer) continue,
            else => {},
        }
        merged[index] = attr;
        index += 1;
    }

    return merged[0..index];
}

fn derivedAttrsForField(
    comptime FieldType: type,
    comptime needs_mut: bool,
    comptime needs_signer: bool,
) []const attr_mod.Attr {
    if (!needs_mut and !needs_signer) return &.{};

    if (needs_signer and FieldType != Signer and FieldType != SignerMut) {
        @compileError("payer/realloc payer fields must be Signer or SignerMut");
    }

    if (needs_signer and needs_mut) {
        return &.{ attr_mod.attr.signer(), attr_mod.attr.mut() };
    }
    if (needs_signer) {
        return &.{attr_mod.attr.signer()};
    }
    return &.{attr_mod.attr.mut()};
}

fn applyFieldAttrs(
    comptime FieldType: type,
    comptime attrs: []const attr_mod.Attr,
) type {
    if (@hasDecl(FieldType, "DataType")) {
        return account_mod.AccountField(FieldType, attrs);
    }
    if (FieldType == Signer or FieldType == SignerMut) {
        return applySignerAttrs(FieldType, attrs);
    }

    @compileError("Derived attrs only support Account or Signer fields");
}

fn applyAccountAttrs(comptime T: type, comptime config: anytype, comptime enable_auto: bool) type {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("Accounts must be a struct type");
    }

    const fields = info.@"struct".fields;
    const derived_flags: ?DerivedFlags = if (enable_auto) blk: {
        validateDerivedRefs(T);
        break :blk deriveAccountFlags(T);
    } else null;
    comptime var new_fields: [fields.len]std.builtin.Type.StructField = undefined;

    inline for (fields, 0..) |field, index| {
        var field_type = field.type;
        const derived_target_type = unwrapOptionalType(field_type);
        const derived_attrs = if (derived_flags) |flags|
            derivedAttrsForField(
                derived_target_type,
                flags.mut[index],
                flags.signer[index],
            )
        else
            &.{};
        const explicit = @hasField(@TypeOf(config), field.name);
        const auto_sysvar_type = if (!explicit and enable_auto) autoSysvarType(field.name, field_type) else null;
        if (auto_sysvar_type) |sysvar_type| {
            field_type = sysvar_type;
        }
        const auto_program_attrs = if (!explicit and enable_auto and auto_sysvar_type == null)
            autoProgramAttrs(field.name, field_type)
        else
            null;
        const auto_account_attrs = if (!explicit and enable_auto and auto_sysvar_type == null)
            autoAccountAttrs(T, field_type)
        else
            null;
        const merged_attrs = mergeAttrs(
            if (explicit)
                resolveAttrs(@field(config, field.name))
            else if (auto_program_attrs != null)
                auto_program_attrs.?
            else if (auto_account_attrs != null)
                auto_account_attrs.?
            else
                null,
            derived_attrs,
        );
        if (merged_attrs) |attrs| {
            if (@hasDecl(field_type, "DataType")) {
                field_type = account_mod.AccountField(field_type, attrs);
            } else if (field_type == UncheckedProgram or @hasDecl(field_type, "ID")) {
                field_type = program_mod.ProgramField(field_type, attrs);
            } else if (field_type == Signer or field_type == SignerMut) {
                field_type = applySignerAttrs(field_type, attrs);
            } else {
                @compileError("AccountsWith only supports Account, Program, or Signer fields");
            }
        } else if (derived_attrs.len != 0) {
            if (field_type != derived_target_type) {
                @compileError("Derived attrs do not support optional fields");
            }
            field_type = applyFieldAttrs(derived_target_type, derived_attrs);
        }

        new_fields[index] = .{
            .name = field.name,
            .type = field_type,
            .default_value_ptr = field.default_value_ptr,
            .is_comptime = field.is_comptime,
            .alignment = field.alignment,
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = info.@"struct".layout,
            .fields = &new_fields,
            .decls = &.{},
            .is_tuple = info.@"struct".is_tuple,
        },
    });
}

fn applySignerAttrs(comptime FieldType: type, comptime attrs: []const attr_mod.Attr) type {
    comptime var wants_mut = false;
    inline for (attrs) |attr| {
        switch (attr) {
            .mut => wants_mut = true,
            .signer => {},
            else => @compileError("Signer fields only support mut/signer attrs"),
        }
    }

    if (FieldType == SignerMut) return SignerMut;
    if (wants_mut) return SignerMut;
    return Signer;
}

fn autoProgramAttrs(comptime name: []const u8, comptime FieldType: type) ?[]const attr_mod.Attr {
    if (FieldType != UncheckedProgram) return null;
    if (std.mem.eql(u8, name, "system_program")) {
        return &.{ attr_mod.attr.address(sol.system_program.id), attr_mod.attr.executable() };
    }
    if (std.mem.eql(u8, name, "token_program")) {
        return &.{ attr_mod.attr.address(sol.spl.TOKEN_PROGRAM_ID), attr_mod.attr.executable() };
    }
    if (std.mem.eql(u8, name, "associated_token_program")) {
        const program_id = sol.PublicKey.comptimeFromBase58("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL");
        return &.{ attr_mod.attr.address(program_id), attr_mod.attr.executable() };
    }
    if (std.mem.eql(u8, name, "memo_program")) {
        return &.{ attr_mod.attr.address(sol.spl.MEMO_PROGRAM_ID), attr_mod.attr.executable() };
    }
    if (std.mem.eql(u8, name, "stake_program")) {
        return &.{ attr_mod.attr.address(sol.spl.STAKE_PROGRAM_ID), attr_mod.attr.executable() };
    }
    if (std.mem.eql(u8, name, "stake_config_program")) {
        return &.{ attr_mod.attr.address(sol.spl.stake.STAKE_CONFIG_PROGRAM_ID), attr_mod.attr.executable() };
    }
    return null;
}

fn autoSysvarType(comptime name: []const u8, comptime FieldType: type) ?type {
    if (FieldType != *const AccountInfo) return null;
    if (std.mem.eql(u8, name, "clock")) {
        return sysvar_account.Sysvar(sol.clock.Clock);
    }
    if (std.mem.eql(u8, name, "rent")) {
        return sysvar_account.Sysvar(sol.rent.Rent);
    }
    if (std.mem.eql(u8, name, "slot_hashes")) {
        return sysvar_account.Sysvar(sol.slot_hashes.SlotHashes);
    }
    if (std.mem.eql(u8, name, "slot_history")) {
        return sysvar_account.Sysvar(sol.slot_history.SlotHistory);
    }
    if (std.mem.eql(u8, name, "stake_history")) {
        return sysvar_account.Sysvar(sysvar_account.StakeHistory);
    }
    if (std.mem.eql(u8, name, "instructions") or std.mem.eql(u8, name, "instructions_sysvar")) {
        return sysvar_account.Sysvar(sysvar_account.Instructions);
    }
    if (std.mem.eql(u8, name, "epoch_rewards")) {
        return sysvar_account.Sysvar(sysvar_account.SysvarId(sol.EPOCH_REWARDS_ID));
    }
    if (std.mem.eql(u8, name, "last_restart_slot")) {
        return sysvar_account.Sysvar(sysvar_account.SysvarId(sol.LAST_RESTART_SLOT_ID));
    }
    return null;
}

fn isProgramFieldType(comptime FieldType: type) bool {
    const CleanType = unwrapOptionalType(FieldType);
    return CleanType == UncheckedProgram or @hasDecl(CleanType, "ID");
}

fn autoTokenProgramName(comptime AccountsType: type) ?[]const u8 {
    const index = std.meta.fieldIndex(AccountsType, "token_program") orelse return null;
    const fields = @typeInfo(AccountsType).@"struct".fields;
    if (!isProgramFieldType(fields[index].type)) return null;
    return "token_program";
}

fn autoAccountAttrs(comptime AccountsType: type, comptime FieldType: type) ?[]const attr_mod.Attr {
    const CleanType = unwrapOptionalType(FieldType);
    if (!isAccountWrapper(CleanType)) return null;
    if (CleanType != FieldType) return null;

    const token_program = autoTokenProgramName(AccountsType) orelse return null;

    comptime var config: attr_mod.AccountAttrConfig = .{};
    comptime var has_any = false;

    if (CleanType.ASSOCIATED_TOKEN) |cfg| {
        if (cfg.token_program == null) {
            config.associated_token_token_program = token_program;
            has_any = true;
        }
    }
    if ((CleanType.TOKEN_MINT != null or CleanType.TOKEN_AUTHORITY != null) and CleanType.TOKEN_PROGRAM == null) {
        config.token_program = token_program;
        has_any = true;
    }
    if ((CleanType.MINT_AUTHORITY != null or
        CleanType.MINT_FREEZE_AUTHORITY != null or
        CleanType.MINT_DECIMALS != null) and CleanType.MINT_TOKEN_PROGRAM == null)
    {
        config.mint_token_program = token_program;
        has_any = true;
    }

    if (!has_any) return null;
    return attr_mod.attr.account(config);
}

fn isEventFieldWrapper(comptime T: type) bool {
    return @hasDecl(T, "FieldType") and @hasDecl(T, "FIELD_CONFIG");
}

pub fn unwrapEventField(comptime T: type) type {
    if (isEventFieldWrapper(T)) {
        return T.FieldType;
    }
    return T;
}

pub fn eventFieldConfig(comptime T: type) EventField {
    if (isEventFieldWrapper(T)) {
        return T.FIELD_CONFIG;
    }
    return .{};
}

fn validateEvent(comptime T: type) void {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("Event must be a struct type");
    }

    const fields = info.@"struct".fields;
    if (fields.len == 0) {
        @compileError("Event struct must have at least one field");
    }

    comptime var index_count: usize = 0;
    inline for (fields) |field| {
        const field_type = unwrapEventField(field.type);
        const config = eventFieldConfig(field.type);
        if (config.index) {
            if (!isIndexableEventFieldType(field_type)) {
                @compileError("Indexed event fields must be scalar or PublicKey types");
            }
            index_count += 1;
        }
    }

    if (index_count > 4) {
        @compileError("Event struct cannot have more than 4 indexed fields");
    }
}

fn isIndexableEventFieldType(comptime T: type) bool {
    const info = @typeInfo(T);
    switch (info) {
        .bool => return true,
        .int => return true,
        else => {},
    }
    return T == sol.PublicKey;
}

// Ensure account wrappers expose load()
test "dsl: accounts validation accepts anchor account types" {
    const CounterData = struct {
        value: u64,
    };

    const Counter = account_mod.Account(CounterData, .{
        .discriminator = @import("discriminator.zig").accountDiscriminator("Counter"),
    });

    const AccountsType = Accounts(struct {
        authority: Signer,
        payer: SignerMut,
        counter: Counter,
    });

    const AccountsValue = AccountsType{
        .authority = undefined,
        .payer = undefined,
        .counter = undefined,
    };

    try std.testing.expectEqualStrings(@typeName(AccountsType), @typeName(@TypeOf(AccountsValue)));
}

test "dsl: AccountsWith applies field attrs" {
    const CounterData = struct {
        value: u64,
    };

    const Counter = account_mod.Account(CounterData, .{
        .discriminator = @import("discriminator.zig").accountDiscriminator("Counter"),
    });

    const AccountsType = AccountsWith(struct {
        authority: Signer,
        counter: Counter,
    }, .{
        .counter = attr_mod.attr.mut(),
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const counter_index = std.meta.fieldIndex(AccountsType, "counter") orelse
        @compileError("AccountsWith failed to produce counter field");
    try std.testing.expect(fields[counter_index].type.HAS_MUT);
}

test "dsl: AccountsDerive applies typed attrs" {
    const CounterData = struct {
        value: u64,
    };

    const Counter = account_mod.Account(CounterData, .{
        .discriminator = @import("discriminator.zig").accountDiscriminator("CounterDerive"),
    });

    const AccountsType = AccountsDerive(struct {
        authority: Signer,
        counter: Counter,

        pub const attrs = .{
            .counter = attr_mod.attr.account(.{
                .mut = true,
                .signer = true,
            }),
        };
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const counter_index = std.meta.fieldIndex(AccountsType, "counter") orelse
        @compileError("AccountsDerive failed to produce counter field");
    try std.testing.expect(fields[counter_index].type.HAS_MUT);
    try std.testing.expect(fields[counter_index].type.HAS_SIGNER);
}

test "dsl: AccountsDerive applies signer mut attrs" {
    const AccountsType = AccountsDerive(struct {
        authority: Signer,
        payer: Signer,

        pub const attrs = .{
            .payer = attr_mod.attr.mut(),
        };
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const payer_index = std.meta.fieldIndex(AccountsType, "payer") orelse
        @compileError("AccountsDerive failed to produce payer field");
    try std.testing.expect(fields[payer_index].type == SignerMut);
}

test "dsl: AccountsDerive applies program attrs" {
    const program_id = comptime sol.PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const SystemProgram = program_mod.Program(program_id);

    const AccountsType = AccountsDerive(struct {
        system_program: SystemProgram,
        unchecked: UncheckedProgram,

        pub const attrs = .{
            .system_program = attr_mod.attr.executable(),
            .unchecked = attr_mod.attr.owner(program_id),
        };
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const system_index = std.meta.fieldIndex(AccountsType, "system_program") orelse
        @compileError("AccountsDerive failed to produce system_program field");
    const unchecked_index = std.meta.fieldIndex(AccountsType, "unchecked") orelse
        @compileError("AccountsDerive failed to produce unchecked field");
    _ = fields[system_index];
    _ = fields[unchecked_index];
}

test "dsl: AccountsDerive auto-binds common program/sysvar fields" {
    const AccountsType = AccountsDerive(struct {
        system_program: UncheckedProgram,
        token_program: UncheckedProgram,
        associated_token_program: UncheckedProgram,
        memo_program: UncheckedProgram,
        stake_program: UncheckedProgram,
        stake_config_program: UncheckedProgram,
        rent: *const AccountInfo,
        clock: *const AccountInfo,
        slot_hashes: *const AccountInfo,
        slot_history: *const AccountInfo,
        stake_history: *const AccountInfo,
        instructions: *const AccountInfo,
        epoch_rewards: *const AccountInfo,
        last_restart_slot: *const AccountInfo,
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const system_index = std.meta.fieldIndex(AccountsType, "system_program") orelse
        @compileError("AccountsDerive failed to produce system_program field");
    const token_index = std.meta.fieldIndex(AccountsType, "token_program") orelse
        @compileError("AccountsDerive failed to produce token_program field");
    const ata_index = std.meta.fieldIndex(AccountsType, "associated_token_program") orelse
        @compileError("AccountsDerive failed to produce associated_token_program field");
    const memo_index = std.meta.fieldIndex(AccountsType, "memo_program") orelse
        @compileError("AccountsDerive failed to produce memo_program field");
    const stake_program_index = std.meta.fieldIndex(AccountsType, "stake_program") orelse
        @compileError("AccountsDerive failed to produce stake_program field");
    const stake_config_program_index = std.meta.fieldIndex(AccountsType, "stake_config_program") orelse
        @compileError("AccountsDerive failed to produce stake_config_program field");
    const rent_index = std.meta.fieldIndex(AccountsType, "rent") orelse
        @compileError("AccountsDerive failed to produce rent field");
    const clock_index = std.meta.fieldIndex(AccountsType, "clock") orelse
        @compileError("AccountsDerive failed to produce clock field");
    const slot_hashes_index = std.meta.fieldIndex(AccountsType, "slot_hashes") orelse
        @compileError("AccountsDerive failed to produce slot_hashes field");
    const slot_history_index = std.meta.fieldIndex(AccountsType, "slot_history") orelse
        @compileError("AccountsDerive failed to produce slot_history field");
    const stake_history_index = std.meta.fieldIndex(AccountsType, "stake_history") orelse
        @compileError("AccountsDerive failed to produce stake_history field");
    const instructions_index = std.meta.fieldIndex(AccountsType, "instructions") orelse
        @compileError("AccountsDerive failed to produce instructions field");
    const epoch_rewards_index = std.meta.fieldIndex(AccountsType, "epoch_rewards") orelse
        @compileError("AccountsDerive failed to produce epoch_rewards field");
    const last_restart_slot_index = std.meta.fieldIndex(AccountsType, "last_restart_slot") orelse
        @compileError("AccountsDerive failed to produce last_restart_slot field");
    if (!@hasField(fields[system_index].type, "base")) {
        @compileError("system_program was not wrapped with ProgramField");
    }
    if (!@hasField(fields[token_index].type, "base")) {
        @compileError("token_program was not wrapped with ProgramField");
    }
    if (!@hasField(fields[ata_index].type, "base")) {
        @compileError("associated_token_program was not wrapped with ProgramField");
    }
    if (!@hasField(fields[memo_index].type, "base")) {
        @compileError("memo_program was not wrapped with ProgramField");
    }
    if (!@hasField(fields[stake_program_index].type, "base")) {
        @compileError("stake_program was not wrapped with ProgramField");
    }
    if (!@hasField(fields[stake_config_program_index].type, "base")) {
        @compileError("stake_config_program was not wrapped with ProgramField");
    }
    if (!@hasDecl(fields[rent_index].type, "SYSVAR_TYPE")) {
        @compileError("rent was not wrapped with Sysvar");
    }
    if (fields[rent_index].type.SYSVAR_TYPE != sol.rent.Rent) {
        @compileError("rent sysvar type mismatch");
    }
    if (!@hasDecl(fields[clock_index].type, "SYSVAR_TYPE") or
        fields[clock_index].type.SYSVAR_TYPE != sol.clock.Clock)
    {
        @compileError("clock sysvar type mismatch");
    }
    if (!@hasDecl(fields[slot_hashes_index].type, "SYSVAR_TYPE") or
        fields[slot_hashes_index].type.SYSVAR_TYPE != sol.slot_hashes.SlotHashes)
    {
        @compileError("slot_hashes sysvar type mismatch");
    }
    if (!@hasDecl(fields[slot_history_index].type, "SYSVAR_TYPE") or
        fields[slot_history_index].type.SYSVAR_TYPE != sol.slot_history.SlotHistory)
    {
        @compileError("slot_history sysvar type mismatch");
    }
    if (!@hasDecl(fields[stake_history_index].type, "ID")) {
        @compileError("stake_history was not wrapped with Sysvar");
    }
    if (!@hasDecl(fields[instructions_index].type, "ID")) {
        @compileError("instructions was not wrapped with Sysvar");
    }
    if (!@hasDecl(fields[epoch_rewards_index].type, "ID")) {
        @compileError("epoch_rewards was not wrapped with Sysvar");
    }
    if (!@hasDecl(fields[last_restart_slot_index].type, "ID")) {
        @compileError("last_restart_slot was not wrapped with Sysvar");
    }
    try std.testing.expect(fields[stake_history_index].type.ID.equals(sol.STAKE_HISTORY_ID));
    try std.testing.expect(fields[instructions_index].type.ID.equals(sol.INSTRUCTIONS_ID));
    try std.testing.expect(fields[epoch_rewards_index].type.ID.equals(sol.EPOCH_REWARDS_ID));
    try std.testing.expect(fields[last_restart_slot_index].type.ID.equals(sol.LAST_RESTART_SLOT_ID));
}

test "dsl: AccountsDerive auto-fills token program for token/mint/ata" {
    const TokenData = struct {
        mint: sol.PublicKey,
        authority: sol.PublicKey,
    };

    const MintData = struct {
        authority: sol.PublicKey,
        decimals: u8,
    };

    const TokenAccount = account_mod.Account(TokenData, .{
        .discriminator = discriminator_mod.accountDiscriminator("TokenAccountAutoProgram"),
        .token_mint = "mint",
        .token_authority = "authority",
    });

    const MintAccount = account_mod.Account(MintData, .{
        .discriminator = discriminator_mod.accountDiscriminator("MintAccountAutoProgram"),
        .mint_authority = "authority",
        .mint_decimals = 6,
    });

    const AtaAccount = account_mod.Account(TokenData, .{
        .discriminator = discriminator_mod.accountDiscriminator("AtaAccountAutoProgram"),
        .associated_token = .{ .mint = "mint", .authority = "authority" },
    });

    const AccountsType = AccountsDerive(struct {
        authority: Signer,
        mint: MintAccount,
        token_program: UncheckedProgram,
        token_account: TokenAccount,
        mint_account: MintAccount,
        ata_account: AtaAccount,
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const token_index = std.meta.fieldIndex(AccountsType, "token_account") orelse
        @compileError("AccountsDerive failed to produce token_account field");
    const mint_index = std.meta.fieldIndex(AccountsType, "mint_account") orelse
        @compileError("AccountsDerive failed to produce mint_account field");
    const ata_index = std.meta.fieldIndex(AccountsType, "ata_account") orelse
        @compileError("AccountsDerive failed to produce ata_account field");

    try std.testing.expect(fields[token_index].type.TOKEN_PROGRAM != null);
    try std.testing.expect(fields[mint_index].type.MINT_TOKEN_PROGRAM != null);
    try std.testing.expect(fields[ata_index].type.ASSOCIATED_TOKEN.?.token_program != null);
}

test "dsl: AccountsDerive infers init/payer/realloc mut/signer" {
    const Data = struct {
        value: u64,
    };

    const Counter = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("Counter"),
        .init = true,
        .payer = "payer",
    });

    const Dynamic = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("Dynamic"),
        .realloc = .{ .payer = "payer", .zero_init = true },
    });

    const AccountsType = AccountsDerive(struct {
        payer: Signer,
        counter: Counter,
        dynamic: Dynamic,
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const payer_index = std.meta.fieldIndex(AccountsType, "payer") orelse
        @compileError("AccountsDerive failed to produce payer field");
    const counter_index = std.meta.fieldIndex(AccountsType, "counter") orelse
        @compileError("AccountsDerive failed to produce counter field");
    const dynamic_index = std.meta.fieldIndex(AccountsType, "dynamic") orelse
        @compileError("AccountsDerive failed to produce dynamic field");

    try std.testing.expect(fields[payer_index].type == SignerMut);
    try std.testing.expect(fields[counter_index].type.HAS_MUT);
    try std.testing.expect(fields[dynamic_index].type.HAS_MUT);
}

test "dsl: AccountsDerive validates has_one/seeds references" {
    const Data = struct {
        authority: sol.PublicKey,
    };

    const Vault = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("Vault"),
        .seeds = &.{
            seeds_mod.seed("vault"),
            seeds_mod.seedAccount("authority"),
            seeds_mod.seedBump("vault"),
        },
        .bump = true,
        .has_one = &.{.{ .field = "authority", .target = "authority" }},
    });

    const AccountsType = AccountsDerive(struct {
        authority: Signer,
        vault: Vault,
    });

    _ = AccountsType;
}

test "dsl: AccountsDerive supports Attrs marker" {
    const Data = struct {
        value: u64,
    };

    const Counter = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("Counter"),
    });

    const AccountsType = AccountsDerive(struct {
        payer: Signer,
        counter: Attrs(.{ .init = true, .payer = "payer" }).apply(Counter),
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const payer_index = std.meta.fieldIndex(AccountsType, "payer") orelse
        @compileError("AccountsDerive failed to produce payer field");
    const counter_index = std.meta.fieldIndex(AccountsType, "counter") orelse
        @compileError("AccountsDerive failed to produce counter field");

    try std.testing.expect(fields[payer_index].type == SignerMut);
    try std.testing.expect(fields[counter_index].type.IS_INIT);
}

test "dsl: AttrsFor resolves typed field enums" {
    const Data = struct {
        authority: sol.PublicKey,
    };

    const Counter = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("Counter"),
    });

    const AccountsRef = struct {
        payer: Signer,
        authority: Signer,
        counter: Counter,
    };

    const has_one_fields = &[_]std.meta.FieldEnum(Data){ .authority };

    const AccountsType = AccountsDerive(struct {
        payer: Signer,
        authority: Signer,
        counter: AttrsFor(AccountsRef, Data, .{
            .init = true,
            .payer = .payer,
            .has_one_fields = has_one_fields[0..],
        }).apply(Counter),
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const payer_index = std.meta.fieldIndex(AccountsType, "payer") orelse
        @compileError("AccountsDerive failed to produce payer field");
    const counter_index = std.meta.fieldIndex(AccountsType, "counter") orelse
        @compileError("AccountsDerive failed to produce counter field");

    try std.testing.expect(fields[payer_index].type == SignerMut);
    try std.testing.expect(fields[counter_index].type.HAS_ONE != null);
}

test "dsl: AttrsFor resolves typed seed specs" {
    const Data = struct {
        authority: sol.PublicKey,
    };

    const Counter = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("CounterSeeds"),
    });

    const AccountsRef = struct {
        payer: Signer,
        authority: Signer,
        counter: Counter,
    };

    const TypedSeed = SeedSpecFor(AccountsRef, Data);
    const seeds = &[_]TypedSeed{
        .{ .literal = "counter" },
        .{ .account = .authority },
        .{ .field = .authority },
        .{ .bump = .counter },
    };

    const AccountsType = AccountsDerive(struct {
        payer: Signer,
        authority: Signer,
        counter: AttrsFor(AccountsRef, Data, .{
            .seeds = seeds,
            .bump = true,
        }).apply(Counter),
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const counter_index = std.meta.fieldIndex(AccountsType, "counter") orelse
        @compileError("AccountsDerive failed to produce counter field");

    try std.testing.expect(fields[counter_index].type.HAS_SEEDS);
}

test "dsl: AttrsFor resolves typed has_one specs" {
    const Data = struct {
        authority: sol.PublicKey,
    };

    const Counter = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("CounterHasOne"),
    });

    const AccountsRef = struct {
        authority: Signer,
        counter: Counter,
    };

    const AccountsType = AccountsDerive(struct {
        authority: Signer,
        counter: AttrsFor(AccountsRef, Data, .{
            .has_one = &[_]HasOneSpecFor(AccountsRef, Data){
                HasOneSpecFor(AccountsRef, Data).init(.authority, .authority),
            },
        }).apply(Counter),
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const counter_index = std.meta.fieldIndex(AccountsType, "counter") orelse
        @compileError("AccountsDerive failed to produce counter field");

    try std.testing.expect(fields[counter_index].type.HAS_HAS_ONE);
}

test "dsl: AttrsFor resolves typed token configs" {
    const Data = struct {
        authority: sol.PublicKey,
    };

    const TokenAccount = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("TokenAccountTyped"),
    });

    const AccountsRef = struct {
        mint: *const AccountInfo,
        authority: Signer,
        token_program: UncheckedProgram,
        token_account: TokenAccount,
    };

    const AccountsType = AccountsDerive(struct {
        mint: *const AccountInfo,
        authority: Signer,
        token_program: UncheckedProgram,
        token_account: AttrsFor(AccountsRef, Data, .{
            .token = TokenFor(AccountsRef).withProgram(.mint, .authority, .token_program),
            .associated_token = AssociatedTokenFor(AccountsRef).withTokenProgram(.mint, .authority, .token_program),
        }).apply(TokenAccount),
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const token_index = std.meta.fieldIndex(AccountsType, "token_account") orelse
        @compileError("AccountsDerive failed to produce token_account field");

    try std.testing.expect(fields[token_index].type.TOKEN_MINT != null);
    try std.testing.expect(fields[token_index].type.ASSOCIATED_TOKEN != null);
}

test "dsl: AttrsFor resolves typed mint configs" {
    const Data = struct {
        authority: sol.PublicKey,
    };

    const MintAccount = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("MintAccountTyped"),
    });

    const AccountsRef = struct {
        authority: Signer,
        mint_program: UncheckedProgram,
        mint_account: MintAccount,
    };

    const AccountsType = AccountsDerive(struct {
        authority: Signer,
        mint_program: UncheckedProgram,
        mint_account: AttrsFor(AccountsRef, Data, .{
            .mint = MintFor(AccountsRef).withProgram(.authority, .mint_program),
        }).apply(MintAccount),
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const mint_index = std.meta.fieldIndex(AccountsType, "mint_account") orelse
        @compileError("AccountsDerive failed to produce mint_account field");

    try std.testing.expect(fields[mint_index].type.MINT_AUTHORITY != null);
    try std.testing.expect(fields[mint_index].type.MINT_TOKEN_PROGRAM != null);
}

test "dsl: AttrsFor resolves init/close/realloc helpers" {
    const Data = struct {
        value: u64,
    };

    const AccountType = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("InitCloseRealloc"),
    });

    const AccountsRef = struct {
        payer: Signer,
        destination: Signer,
        account: AccountType,
    };

    const AccountsType = AccountsDerive(struct {
        payer: Signer,
        destination: Signer,
        account: AttrsFor(AccountsRef, Data, .{
            .init_with = InitFor(AccountsRef).init(.payer),
            .close_to = CloseFor(AccountsRef).init(.destination),
            .realloc_with = ReallocFor(AccountsRef).zeroed(.payer),
        }).apply(AccountType),
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const account_index = std.meta.fieldIndex(AccountsType, "account") orelse
        @compileError("AccountsDerive failed to produce account field");

    try std.testing.expect(fields[account_index].type.IS_INIT);
    try std.testing.expect(fields[account_index].type.HAS_CLOSE);
    try std.testing.expect(fields[account_index].type.HAS_REALLOC);
}

test "dsl: AttrsFor resolves access helper" {
    const owner_id = comptime sol.PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const address_id = comptime sol.PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    const OwnerProgram = program_mod.Program(owner_id);
    const AddressProgram = program_mod.Program(address_id);

    const Data = struct {
        value: u64,
    };

    const AccountType = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("AccessTyped"),
    });

    const AccountsRef = struct {
        owner: OwnerProgram,
        address: AddressProgram,
        account: AccountType,
    };

    const AccountsType = AccountsDerive(struct {
        owner: Signer,
        address: Signer,
        account: AttrsFor(AccountsRef, Data, .{
            .access = AccessFor(AccountsRef, Data).ownerAndSpace(.owner, AccountType.SPACE),
        }).apply(AccountType),
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const account_index = std.meta.fieldIndex(AccountsType, "account") orelse
        @compileError("AccountsDerive failed to produce account field");

    try std.testing.expect(fields[account_index].type.OWNER != null);
    try std.testing.expect(fields[account_index].type.SPACE == AccountType.SPACE);
}

test "dsl: event validation accepts struct" {
    const EventType = Event(struct {
        amount: eventField(u64, .{ .index = true }),
        owner: sol.PublicKey,
    });

    _ = EventType;
}

test "dsl: event supports multiple indexed fields" {
    const EventType = Event(struct {
        amount: eventField(u64, .{ .index = true }),
        owner: eventField(sol.PublicKey, .{ .index = true }),
        slot: eventField(u64, .{ .index = true }),
        nonce: eventField(u64, .{ .index = true }),
    });

    _ = EventType;
}
