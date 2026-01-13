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
            return account_mod.AccountField(Base, attr_mod.attr.account(config));
        }
    };
}

/// Typed attribute helper for account fields.
pub fn AttrsWith(comptime config: attr_mod.AccountAttrConfig, comptime Base: type) type {
    return Attrs(config).apply(Base);
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
        const auto_attrs = if (!explicit and enable_auto and auto_sysvar_type == null)
            autoProgramAttrs(field.name, field_type)
        else
            null;
        const merged_attrs = mergeAttrs(
            if (explicit)
                resolveAttrs(@field(config, field.name))
            else if (auto_attrs != null)
                auto_attrs.?
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
