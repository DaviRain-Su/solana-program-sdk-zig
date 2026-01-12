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

const AccountInfo = sol.account.Account.Info;
const Signer = signer_mod.Signer;
const SignerMut = signer_mod.SignerMut;
const UncheckedProgram = program_mod.UncheckedProgram;

/// Validate Accounts struct and return it unchanged.
pub fn Accounts(comptime T: type) type {
    comptime validateAccounts(T);
    return T;
}

/// Validate Accounts struct and apply field-level attrs.
pub fn AccountsWith(comptime T: type, comptime config: anytype) type {
    comptime validateAccountsWith(T, config);
    return applyAccountAttrs(T, config);
}

/// Validate Accounts struct and apply field attrs from `T.attrs`.
pub fn AccountsDerive(comptime T: type) type {
    if (!@hasDecl(T, "attrs")) {
        return Accounts(T);
    }
    return AccountsWith(T, @field(T, "attrs"));
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

fn resolveAttrs(comptime value: anytype) []const attr_mod.Attr {
    const ValueType = @TypeOf(value);
    if (ValueType == []const attr_mod.Attr) {
        return value;
    }
    if (ValueType == attr_mod.AccountAttrConfig) {
        return attr_mod.attr.account(value);
    }
    if (ValueType == []const u8) {
        return attr_mod.attr.parseAccount(value);
    }
    if (@typeInfo(ValueType) == .pointer) {
        const child = @typeInfo(ValueType).pointer.child;
        if (@typeInfo(child) == .array and @typeInfo(child).array.child == u8) {
            return attr_mod.attr.parseAccount(value[0..]);
        }
    }
    if (ValueType == attr_mod.Attr) {
        const list = [_]attr_mod.Attr{value};
        return list[0..];
    }

    @compileError("AccountsWith expects Attr, []const Attr, AccountAttrConfig, or []const u8");
}

fn applyAccountAttrs(comptime T: type, comptime config: anytype) type {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("Accounts must be a struct type");
    }

    const fields = info.@"struct".fields;
    comptime var new_fields: [fields.len]std.builtin.Type.StructField = undefined;

    inline for (fields, 0..) |field, index| {
        var field_type = field.type;
        if (@hasField(@TypeOf(config), field.name)) {
            const attrs = resolveAttrs(@field(config, field.name));
            if (@hasDecl(field_type, "DataType")) {
                field_type = account_mod.AccountField(field_type, attrs);
            } else {
                @compileError("AccountsWith only supports Account wrapper fields");
            }
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

test "dsl: AccountsWith accepts macro string attrs" {
    const CounterData = struct {
        value: u64,
    };

    const Counter = account_mod.Account(CounterData, .{
        .discriminator = @import("discriminator.zig").accountDiscriminator("CounterStr"),
    });

    const AccountsType = AccountsWith(struct {
        authority: Signer,
        counter: Counter,
    }, .{
        .counter = "mut, signer",
    });

    const fields = @typeInfo(AccountsType).@"struct".fields;
    const counter_index = std.meta.fieldIndex(AccountsType, "counter") orelse
        @compileError("AccountsWith failed to produce counter field");
    try std.testing.expect(fields[counter_index].type.HAS_MUT);
    try std.testing.expect(fields[counter_index].type.HAS_SIGNER);
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
