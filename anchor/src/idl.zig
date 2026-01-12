//! Zig implementation of Anchor IDL generation
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/syn/src/idl.rs
//!
//! This module generates Anchor-compatible IDL JSON from comptime program
//! definitions. It focuses on instructions, accounts, args, and errors.

const std = @import("std");
const discriminator_mod = @import("discriminator.zig");
const signer_mod = @import("signer.zig");
const program_mod = @import("program.zig");
const seeds_mod = @import("seeds.zig");
const has_one_mod = @import("has_one.zig");
const realloc_mod = @import("realloc.zig");
const constraints_mod = @import("constraints.zig");

const Allocator = std.mem.Allocator;

const Signer = signer_mod.Signer;
const SignerMut = signer_mod.SignerMut;
const UncheckedProgram = program_mod.UncheckedProgram;
const SeedSpec = seeds_mod.SeedSpec;
const HasOneSpec = has_one_mod.HasOneSpec;
const ReallocConfig = realloc_mod.ReallocConfig;
const ConstraintExpr = constraints_mod.ConstraintExpr;

pub const IdlConfig = struct {
    /// Force mutable account names
    mut: ?[]const []const u8 = null,
    /// Force signer account names
    signer: ?[]const []const u8 = null,
};

pub const InstructionSpec = struct {
    Accounts: type,
    Args: type = void,
};

/// Instruction descriptor for comptime programs
pub fn Instruction(comptime spec: InstructionSpec) type {
    return struct {
        pub const Accounts = spec.Accounts;
        pub const Args = spec.Args;
    };
}

pub const AccountDescriptor = struct {
    name: []const u8,
    is_mut: bool,
    is_signer: bool,
    is_program: bool,
    constraints: ?ConstraintDescriptor = null,
};

pub const ConstraintDescriptor = struct {
    seeds: ?[]const SeedSpec = null,
    bump: bool = false,
    init: bool = false,
    payer: ?[]const u8 = null,
    close: ?[]const u8 = null,
    realloc: ?ReallocConfig = null,
    has_one: ?[]const HasOneSpec = null,
    rent_exempt: bool = false,
    constraint: ?ConstraintExpr = null,
};

/// Generate Anchor-compatible IDL JSON.
pub fn generateJson(allocator: Allocator, comptime program: anytype, comptime config: IdlConfig) ![]u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var type_registry = std.StringHashMap(void).init(a);
    var type_defs = std.json.Array.init(a);
    var account_registry = std.StringHashMap(void).init(a);
    var account_defs = std.json.Array.init(a);

    const name = shortTypeName(@typeName(@TypeOf(program)));
    var address_buffer: [44]u8 = undefined;
    const address = program.id.toBase58(&address_buffer);

    const instructions = try buildInstructionsJson(a, program, config, &type_registry, &type_defs, &account_registry, &account_defs);
    const errors = try buildErrorsJson(a, program);
    const constants = try buildConstantsJson(a, program, &type_registry, &type_defs);
    const events = try buildEventsJson(a, program, &type_registry, &type_defs);
    const metadata = try buildMetadataJson(a, program);

    var root = std.json.ObjectMap.init(a);
    try putString(a, &root, "version", "0.1.0");
    try putString(a, &root, "name", name);
    try putString(a, &root, "address", address);
    try root.put(try a.dupe(u8, "instructions"), instructions);
    try root.put(try a.dupe(u8, "accounts"), .{ .array = account_defs });
    try root.put(try a.dupe(u8, "types"), .{ .array = type_defs });
    try root.put(try a.dupe(u8, "errors"), errors);
    if (constants != null) {
        try root.put(try a.dupe(u8, "constants"), constants.?);
    }
    if (events != null) {
        try root.put(try a.dupe(u8, "events"), events.?);
    }
    if (metadata != null) {
        try root.put(try a.dupe(u8, "metadata"), metadata.?);
    }

    const json = std.json.Value{ .object = root };
    return std.json.stringifyAlloc(allocator, json, .{ .whitespace = .indent_2 });
}

/// Write Anchor IDL JSON to a file path.
pub fn writeJsonFile(
    allocator: Allocator,
    comptime program: anytype,
    comptime config: IdlConfig,
    output_path: []const u8,
) !void {
    const json = try generateJson(allocator, program, config);
    defer allocator.free(json);

    const dir = std.fs.path.dirname(output_path) orelse ".";
    try std.fs.cwd().makePath(dir);

    var file = try std.fs.cwd().createFile(output_path, .{ .truncate = true });
    defer file.close();

    try file.writeAll(json);
}

fn buildInstructionsJson(
    allocator: Allocator,
    comptime program: anytype,
    comptime config: IdlConfig,
    type_registry: *std.StringHashMap(void),
    type_defs: *std.json.Array,
    account_registry: *std.StringHashMap(void),
    account_defs: *std.json.Array,
) !std.json.Value {
    const fields = @typeInfo(@TypeOf(program.instructions)).@"struct".fields;
    var instructions = std.json.Array.init(allocator);
    try instructions.ensureTotalCapacity(fields.len);

    inline for (fields) |field| {
        const InstructionType = field.type;
        if (!@hasDecl(InstructionType, "Accounts")) {
            @compileError("Instruction type must define Accounts");
        }
        if (!@hasDecl(InstructionType, "Args")) {
            @compileError("Instruction type must define Args");
        }

        const Accounts = InstructionType.Accounts;
        const Args = InstructionType.Args;
        const accounts = extractAccounts(Accounts, config);

        var ix_obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &ix_obj, "name", field.name);
        try ix_obj.put(try allocator.dupe(u8, "discriminator"), try discriminatorJson(allocator, field.name));
        try ix_obj.put(try allocator.dupe(u8, "accounts"), try accountsJson(allocator, accounts));
        try ix_obj.put(try allocator.dupe(u8, "args"), try argsJson(allocator, Args, type_registry, type_defs));

        try appendAccountDefsForAccounts(allocator, Accounts, account_registry, account_defs, type_registry, type_defs);

        instructions.appendAssumeCapacity(.{ .object = ix_obj });
    }

    return .{ .array = instructions };
}

fn buildErrorsJson(allocator: Allocator, comptime program: anytype) !std.json.Value {
    if (!@hasDecl(program, "errors")) {
        return .{ .array = std.json.Array.init(allocator) };
    }

    const Errors = @TypeOf(program.errors);
    const info = @typeInfo(Errors);
    if (info != .@"enum") {
        return .{ .array = std.json.Array.init(allocator) };
    }

    const fields = info.@"enum".fields;
    var errors = std.json.Array.init(allocator);
    try errors.ensureTotalCapacity(fields.len);

    inline for (fields) |field| {
        const code = @intFromEnum(@field(Errors, field.name));
        var err_obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &err_obj, "name", field.name);
        try err_obj.put(try allocator.dupe(u8, "code"), .{ .integer = @intCast(code) });
        try putString(allocator, &err_obj, "msg", field.name);
        errors.appendAssumeCapacity(.{ .object = err_obj });
    }

    return .{ .array = errors };
}

fn buildConstantsJson(
    allocator: Allocator,
    comptime program: anytype,
    type_registry: *std.StringHashMap(void),
    type_defs: *std.json.Array,
) !?std.json.Value {
    if (!@hasDecl(program, "constants")) {
        return null;
    }

    const constants = program.constants;
    const info = @typeInfo(@TypeOf(constants));
    if (info != .@"struct") {
        @compileError("Program constants must be a struct literal");
    }

    const fields = info.@"struct".fields;
    var arr = std.json.Array.init(allocator);
    try arr.ensureTotalCapacity(fields.len);

    inline for (fields) |field| {
        var obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &obj, "name", field.name);
        const type_value = try typeToJson(allocator, field.type, type_registry, type_defs);
        const value = @field(constants, field.name);
        const value_json = try valueToJson(allocator, field.type, value);
        try obj.put(try allocator.dupe(u8, "type"), type_value);
        try obj.put(try allocator.dupe(u8, "value"), value_json);
        arr.appendAssumeCapacity(.{ .object = obj });
    }

    return .{ .array = arr };
}

fn buildEventsJson(
    allocator: Allocator,
    comptime program: anytype,
    type_registry: *std.StringHashMap(void),
    type_defs: *std.json.Array,
) !?std.json.Value {
    if (!@hasDecl(program, "events")) {
        return null;
    }

    const events = program.events;
    const info = @typeInfo(@TypeOf(events));
    if (info != .@"struct") {
        @compileError("Program events must be a struct");
    }

    const fields = info.@"struct".fields;
    var arr = std.json.Array.init(allocator);
    try arr.ensureTotalCapacity(fields.len);

    inline for (fields) |field| {
        const EventType = field.type;
        if (@typeInfo(EventType) != .@"struct") {
            @compileError("Event types must be structs");
        }

        var obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &obj, "name", field.name);
        try obj.put(try allocator.dupe(u8, "discriminator"), try eventDiscriminatorJson(allocator, field.name));
        try obj.put(try allocator.dupe(u8, "fields"), try eventFieldsJson(allocator, EventType, type_registry, type_defs));
        arr.appendAssumeCapacity(.{ .object = obj });
    }

    return .{ .array = arr };
}

fn buildMetadataJson(allocator: Allocator, comptime program: anytype) !?std.json.Value {
    if (!@hasDecl(program, "metadata")) {
        return null;
    }

    const metadata = program.metadata;
    const info = @typeInfo(@TypeOf(metadata));
    if (info != .@"struct") {
        @compileError("Program metadata must be a struct literal");
    }

    const fields = info.@"struct".fields;
    var obj = std.json.ObjectMap.init(allocator);

    inline for (fields) |field| {
        const value = @field(metadata, field.name);
        if (@typeInfo(field.type) == .optional and value == null) {
            continue;
        }
        const value_json = try valueToJson(allocator, field.type, value);
        try obj.put(try allocator.dupe(u8, field.name), value_json);
    }

    return .{ .object = obj };
}

fn accountsJson(allocator: Allocator, accounts: []const AccountDescriptor) !std.json.Value {
    var arr = std.json.Array.init(allocator);
    try arr.ensureTotalCapacity(accounts.len);

    for (accounts) |account| {
        var obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &obj, "name", account.name);
        try obj.put(try allocator.dupe(u8, "isMut"), .{ .bool = account.is_mut });
        try obj.put(try allocator.dupe(u8, "isSigner"), .{ .bool = account.is_signer });
        if (account.constraints) |constraints| {
            if (try constraintsJson(allocator, constraints)) |value| {
                try obj.put(try allocator.dupe(u8, "constraints"), value);
            }
        }
        arr.appendAssumeCapacity(.{ .object = obj });
    }

    return .{ .array = arr };
}

fn argsJson(
    allocator: Allocator,
    comptime Args: type,
    type_registry: *std.StringHashMap(void),
    type_defs: *std.json.Array,
) !std.json.Value {
    if (Args == void) {
        return .{ .array = std.json.Array.init(allocator) };
    }

    const info = @typeInfo(Args);
    if (info != .@"struct") {
        @compileError("Instruction Args must be a struct or void");
    }

    const fields = info.@"struct".fields;
    var args = std.json.Array.init(allocator);
    try args.ensureTotalCapacity(fields.len);

    inline for (fields) |field| {
        var obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &obj, "name", field.name);
        const type_value = try typeToJson(allocator, field.type, type_registry, type_defs);
        try obj.put(try allocator.dupe(u8, "type"), type_value);
        args.appendAssumeCapacity(.{ .object = obj });
    }

    return .{ .array = args };
}

fn discriminatorJson(allocator: Allocator, comptime name: []const u8) !std.json.Value {
    const discriminator = discriminator_mod.instructionDiscriminator(name);
    var arr = std.json.Array.init(allocator);
    try arr.ensureTotalCapacity(discriminator.len);
    for (discriminator) |byte| {
        arr.appendAssumeCapacity(.{ .integer = byte });
    }
    return .{ .array = arr };
}

fn eventDiscriminatorJson(allocator: Allocator, comptime name: []const u8) !std.json.Value {
    const discriminator = discriminator_mod.eventDiscriminator(name);
    return discriminatorArrayJson(allocator, discriminator);
}

fn eventFieldsJson(
    allocator: Allocator,
    comptime EventType: type,
    type_registry: *std.StringHashMap(void),
    type_defs: *std.json.Array,
) !std.json.Value {
    const fields = @typeInfo(EventType).@"struct".fields;
    var arr = std.json.Array.init(allocator);
    try arr.ensureTotalCapacity(fields.len);

    inline for (fields) |field| {
        var obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &obj, "name", field.name);
        const field_type = @import("dsl.zig").unwrapEventField(field.type);
        const field_config = @import("dsl.zig").eventFieldConfig(field.type);
        const type_value = try typeToJson(allocator, field_type, type_registry, type_defs);
        try obj.put(try allocator.dupe(u8, "type"), type_value);
        try obj.put(try allocator.dupe(u8, "index"), .{ .bool = field_config.index });
        arr.appendAssumeCapacity(.{ .object = obj });
    }

    return .{ .array = arr };
}

fn constraintsJson(allocator: Allocator, constraints: ConstraintDescriptor) !?std.json.Value {
    var obj = std.json.ObjectMap.init(allocator);
    var has_entries = false;

    if (constraints.seeds) |seeds| {
        try obj.put(try allocator.dupe(u8, "seeds"), try seedsJson(allocator, seeds));
        has_entries = true;
    }
    if (constraints.bump) {
        try obj.put(try allocator.dupe(u8, "bump"), .{ .bool = true });
        has_entries = true;
    }
    if (constraints.init) {
        try obj.put(try allocator.dupe(u8, "init"), .{ .bool = true });
        has_entries = true;
    }
    if (constraints.payer) |payer| {
        try obj.put(try allocator.dupe(u8, "payer"), jsonString(allocator, payer));
        has_entries = true;
    }
    if (constraints.close) |close| {
        try obj.put(try allocator.dupe(u8, "close"), jsonString(allocator, close));
        has_entries = true;
    }
    if (constraints.realloc) |realloc| {
        var realloc_obj = std.json.ObjectMap.init(allocator);
        if (realloc.payer) |payer| {
            try realloc_obj.put(try allocator.dupe(u8, "payer"), jsonString(allocator, payer));
        }
        try realloc_obj.put(try allocator.dupe(u8, "zeroInit"), .{ .bool = realloc.zero_init });
        try obj.put(try allocator.dupe(u8, "realloc"), .{ .object = realloc_obj });
        has_entries = true;
    }
    if (constraints.has_one) |has_one| {
        var relations = std.json.Array.init(allocator);
        try relations.ensureTotalCapacity(has_one.len);
        for (has_one) |spec| {
            relations.appendAssumeCapacity(jsonString(allocator, spec.target));
        }
        try obj.put(try allocator.dupe(u8, "hasOne"), .{ .array = relations });
        has_entries = true;
    }
    if (constraints.rent_exempt) {
        try obj.put(try allocator.dupe(u8, "rentExempt"), .{ .bool = true });
        has_entries = true;
    }
    if (constraints.constraint) |expr| {
        try obj.put(try allocator.dupe(u8, "constraint"), jsonString(allocator, expr.expr));
        has_entries = true;
    }

    if (!has_entries) {
        return null;
    }

    return .{ .object = obj };
}

fn seedsJson(allocator: Allocator, seeds: []const SeedSpec) !std.json.Value {
    var arr = std.json.Array.init(allocator);
    try arr.ensureTotalCapacity(seeds.len);

    for (seeds) |spec| {
        var obj = std.json.ObjectMap.init(allocator);
        switch (spec) {
            .literal => |value| {
                try putString(allocator, &obj, "kind", "const");
                try obj.put(try allocator.dupe(u8, "value"), jsonString(allocator, value));
            },
            .account => |value| {
                try putString(allocator, &obj, "kind", "account");
                try obj.put(try allocator.dupe(u8, "value"), jsonString(allocator, value));
            },
            .field => |value| {
                try putString(allocator, &obj, "kind", "field");
                try obj.put(try allocator.dupe(u8, "value"), jsonString(allocator, value));
            },
            .bump => |value| {
                try putString(allocator, &obj, "kind", "bump");
                try obj.put(try allocator.dupe(u8, "value"), jsonString(allocator, value));
            },
        }
        arr.appendAssumeCapacity(.{ .object = obj });
    }

    return .{ .array = arr };
}

fn valueToJson(allocator: Allocator, comptime T: type, value: T) !std.json.Value {
    const info = @typeInfo(T);

    if (info == .optional) {
        if (value == null) {
            return .{ .null = {} };
        }
        return valueToJson(allocator, info.optional.child, value.?);
    }

    if (isPublicKeyType(T)) {
        var buffer: [44]u8 = undefined;
        const encoded = value.toBase58(&buffer);
        return jsonString(allocator, encoded);
    }

    switch (info) {
        .bool => return .{ .bool = value },
        .int => return .{ .integer = @intCast(value) },
        .float => return .{ .float = @floatCast(value) },
        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                return jsonString(allocator, value);
            }
        },
        else => {},
    }

    @compileError("Unsupported constant type for IDL: " ++ @typeName(T));
}

fn appendAccountDefsForAccounts(
    allocator: Allocator,
    comptime Accounts: type,
    account_registry: *std.StringHashMap(void),
    account_defs: *std.json.Array,
    type_registry: *std.StringHashMap(void),
    type_defs: *std.json.Array,
) !void {
    const fields = @typeInfo(Accounts).@"struct".fields;

    inline for (fields) |field| {
        const FieldType = field.type;
        if (!isAccountWrapper(FieldType)) continue;

        const data_type = FieldType.DataType;
        const name = accountTypeName(FieldType, data_type);
        if (account_registry.contains(name)) continue;
        try account_registry.put(try allocator.dupe(u8, name), {});

        var account_obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &account_obj, "name", name);
        try account_obj.put(try allocator.dupe(u8, "discriminator"), try discriminatorArrayJson(allocator, FieldType.discriminator));
        const type_value = try structTypeJson(allocator, data_type, type_registry, type_defs);
        try account_obj.put(try allocator.dupe(u8, "type"), type_value);

        account_defs.appendAssumeCapacity(.{ .object = account_obj });
    }
}

fn typeToJson(
    allocator: Allocator,
    comptime T: type,
    type_registry: *std.StringHashMap(void),
    type_defs: *std.json.Array,
) !std.json.Value {
    const info = @typeInfo(T);

    if (isPublicKeyType(T)) {
        return jsonString(allocator, "publicKey");
    }

    switch (info) {
        .bool => return jsonString(allocator, "bool"),
        .int => |int_info| {
            if (int_info.bits != 8 and int_info.bits != 16 and int_info.bits != 32 and int_info.bits != 64) {
                @compileError("Unsupported integer size for IDL: " ++ @typeName(T));
            }
            const tag = if (int_info.signedness == .signed) "i" else "u";
            const type_name = try std.fmt.allocPrint(allocator, "{s}{d}", .{ tag, int_info.bits });
            return jsonString(allocator, type_name);
        },
        .float => |float_info| {
            const type_name = try std.fmt.allocPrint(allocator, "f{d}", .{float_info.bits});
            return jsonString(allocator, type_name);
        },
        .optional => |opt| {
            const child = try typeToJson(allocator, opt.child, type_registry, type_defs);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put(try allocator.dupe(u8, "option"), child);
            return .{ .object = obj };
        },
        .array => |arr| {
            const child = try typeToJson(allocator, arr.child, type_registry, type_defs);
            var list = std.json.Array.init(allocator);
            try list.ensureTotalCapacity(2);
            list.appendAssumeCapacity(child);
            list.appendAssumeCapacity(.{ .integer = @intCast(arr.len) });
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put(try allocator.dupe(u8, "array"), .{ .array = list });
            return .{ .object = obj };
        },
        .pointer => |ptr| {
            if (ptr.size != .slice) {
                @compileError("IDL only supports slices for pointer types");
            }
            if (ptr.child == u8) {
                return jsonString(allocator, "bytes");
            }
            const child = try typeToJson(allocator, ptr.child, type_registry, type_defs);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put(try allocator.dupe(u8, "vec"), child);
            return .{ .object = obj };
        },
        .@"struct" => {
            const name = shortTypeName(@typeName(T));
            try ensureTypeDef(allocator, T, name, type_registry, type_defs);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put(try allocator.dupe(u8, "defined"), jsonString(allocator, name));
            return .{ .object = obj };
        },
        .@"enum" => {
            const name = shortTypeName(@typeName(T));
            try ensureEnumTypeDef(allocator, T, name, type_registry, type_defs);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put(try allocator.dupe(u8, "defined"), jsonString(allocator, name));
            return .{ .object = obj };
        },
        else => @compileError("Unsupported IDL type: " ++ @typeName(T)),
    }
}

fn ensureTypeDef(
    allocator: Allocator,
    comptime T: type,
    name: []const u8,
    registry: *std.StringHashMap(void),
    type_defs: *std.json.Array,
) !void {
    if (registry.contains(name)) return;
    try registry.put(try allocator.dupe(u8, name), {});

    const info = @typeInfo(T).@"struct".fields;
    var fields = std.json.Array.init(allocator);
    try fields.ensureTotalCapacity(info.len);

    inline for (info) |field| {
        var obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &obj, "name", field.name);
        const value = try typeToJson(allocator, field.type, registry, type_defs);
        try obj.put(try allocator.dupe(u8, "type"), value);
        fields.appendAssumeCapacity(.{ .object = obj });
    }

    var type_obj = std.json.ObjectMap.init(allocator);
    try putString(allocator, &type_obj, "kind", "struct");
    try type_obj.put(try allocator.dupe(u8, "fields"), .{ .array = fields });

    var def_obj = std.json.ObjectMap.init(allocator);
    try putString(allocator, &def_obj, "name", name);
    try def_obj.put(try allocator.dupe(u8, "type"), .{ .object = type_obj });

    type_defs.appendAssumeCapacity(.{ .object = def_obj });
}

fn ensureEnumTypeDef(
    allocator: Allocator,
    comptime T: type,
    name: []const u8,
    registry: *std.StringHashMap(void),
    type_defs: *std.json.Array,
) !void {
    if (registry.contains(name)) return;
    try registry.put(try allocator.dupe(u8, name), {});

    const info = @typeInfo(T).@"enum".fields;
    var variants = std.json.Array.init(allocator);
    try variants.ensureTotalCapacity(info.len);

    inline for (info) |field| {
        var obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &obj, "name", field.name);
        variants.appendAssumeCapacity(.{ .object = obj });
    }

    var type_obj = std.json.ObjectMap.init(allocator);
    try putString(allocator, &type_obj, "kind", "enum");
    try type_obj.put(try allocator.dupe(u8, "variants"), .{ .array = variants });

    var def_obj = std.json.ObjectMap.init(allocator);
    try putString(allocator, &def_obj, "name", name);
    try def_obj.put(try allocator.dupe(u8, "type"), .{ .object = type_obj });

    type_defs.appendAssumeCapacity(.{ .object = def_obj });
}

fn jsonString(allocator: Allocator, value: []const u8) std.json.Value {
    _ = allocator;
    return .{ .string = value };
}

fn putString(allocator: Allocator, obj: *std.json.ObjectMap, key: []const u8, value: []const u8) !void {
    try obj.put(try allocator.dupe(u8, key), jsonString(allocator, value));
}

fn discriminatorArrayJson(allocator: Allocator, discriminator: [8]u8) !std.json.Value {
    var arr = std.json.Array.init(allocator);
    try arr.ensureTotalCapacity(discriminator.len);
    for (discriminator) |byte| {
        arr.appendAssumeCapacity(.{ .integer = byte });
    }
    return .{ .array = arr };
}

fn structTypeJson(
    allocator: Allocator,
    comptime T: type,
    type_registry: *std.StringHashMap(void),
    type_defs: *std.json.Array,
) !std.json.Value {
    const info = @typeInfo(T).@"struct".fields;
    var fields = std.json.Array.init(allocator);
    try fields.ensureTotalCapacity(info.len);

    inline for (info) |field| {
        var obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &obj, "name", field.name);
        const value = try typeToJson(allocator, field.type, type_registry, type_defs);
        try obj.put(try allocator.dupe(u8, "type"), value);
        fields.appendAssumeCapacity(.{ .object = obj });
    }

    var type_obj = std.json.ObjectMap.init(allocator);
    try putString(allocator, &type_obj, "kind", "struct");
    try type_obj.put(try allocator.dupe(u8, "fields"), .{ .array = fields });

    return .{ .object = type_obj };
}

fn accountTypeName(comptime AccountType: type, comptime DataType: type) []const u8 {
    const name = shortTypeName(@typeName(AccountType));
    if (std.mem.indexOf(u8, name, "Account(") != null or std.mem.eql(u8, name, "Account")) {
        return shortTypeName(@typeName(DataType));
    }
    return name;
}

fn isPublicKeyType(comptime T: type) bool {
    return std.mem.endsWith(u8, @typeName(T), "PublicKey");
}

fn isSignerType(comptime T: type) bool {
    return T == Signer;
}

fn isSignerMutType(comptime T: type) bool {
    return T == SignerMut;
}

fn isProgramType(comptime T: type) bool {
    return T == UncheckedProgram or std.mem.indexOf(u8, @typeName(T), "Program(") != null;
}

fn isAccountWrapper(comptime T: type) bool {
    return @hasDecl(T, "DataType") and @hasDecl(T, "discriminator");
}

fn accountConstraints(comptime T: type) ?ConstraintDescriptor {
    if (!isAccountWrapper(T)) return null;

    const constraints = ConstraintDescriptor{
        .seeds = T.SEEDS,
        .bump = T.HAS_BUMP,
        .init = T.IS_INIT,
        .payer = T.PAYER,
        .close = T.CLOSE,
        .realloc = T.REALLOC,
        .has_one = T.HAS_ONE,
        .rent_exempt = T.RENT_EXEMPT,
        .constraint = T.CONSTRAINT,
    };

    if (constraints.seeds == null and !constraints.bump and !constraints.init and constraints.payer == null and constraints.close == null and constraints.realloc == null and constraints.has_one == null and !constraints.rent_exempt and constraints.constraint == null) {
        return null;
    }

    return constraints;
}

pub fn extractAccounts(comptime Accounts: type, comptime config: IdlConfig) []const AccountDescriptor {
    const fields = @typeInfo(Accounts).@"struct".fields;
    comptime var result: [fields.len]AccountDescriptor = undefined;

    inline for (fields, 0..) |field, index| {
        const FieldType = field.type;
        var is_signer = isSignerType(FieldType) or isSignerMutType(FieldType);
        var is_mut = isSignerMutType(FieldType);

        if (nameInList(config.signer, field.name)) {
            is_signer = true;
        }
        if (nameInList(config.mut, field.name)) {
            is_mut = true;
        }

        result[index] = .{
            .name = field.name,
            .is_mut = is_mut,
            .is_signer = is_signer,
            .is_program = isProgramType(FieldType),
            .constraints = accountConstraints(FieldType),
        };
    }

    return result[0..];
}

fn nameInList(comptime list: ?[]const []const u8, comptime name: []const u8) bool {
    if (list == null) return false;
    inline for (list.?) |item| {
        if (std.mem.eql(u8, item, name)) return true;
    }
    return false;
}

pub fn shortTypeName(full: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, full, '.')) |index| {
        return full[index + 1 ..];
    }
    return full;
}

pub const ExampleProgram = struct {
    pub const id = @import("solana_program_sdk").PublicKey.comptimeFromBase58("11111111111111111111111111111111");

    pub const metadata = .{
        .name = "example",
        .version = "0.1.0",
        .spec = "0.1.0",
        .description = "Example program",
        .repository = "https://example.com",
    };

    pub const constants = .{
        .fee_bps = @as(u16, 5),
        .enabled = true,
        .label = "counter",
    };

    pub const events = struct {
        pub const CounterEvent = struct {
            amount: @import("dsl.zig").eventField(u64, .{ .index = true }),
            owner: @import("solana_program_sdk").PublicKey,
        };
    };

    pub const instructions = struct {
        pub const initialize = Instruction(.{ .Accounts = InitializeAccounts, .Args = InitializeArgs });
        pub const close = Instruction(.{ .Accounts = CloseAccounts, .Args = void });
    };

    pub const errors = enum(u32) {
        InvalidAmount = 6000,
    };
};

const CounterData = struct {
    amount: u64,
    authority: @import("solana_program_sdk").PublicKey,
};

const Counter = @import("account.zig").Account(CounterData, .{
    .discriminator = discriminator_mod.accountDiscriminator("Counter"),
    .seeds = &.{ seeds_mod.seed("counter"), seeds_mod.seedAccount("authority") },
    .bump = true,
    .has_one = &.{.{ .field = "authority", .target = "authority" }},
    .close = "authority",
    .realloc = .{ .payer = "payer", .zero_init = true },
    .rent_exempt = true,
    .constraint = constraints_mod.constraint("authority.key() == counter.authority"),
});

const InitializeAccounts = struct {
    authority: Signer,
    payer: SignerMut,
    counter: Counter,
};

const InitializeArgs = struct {
    amount: u64,
    flag: bool,
    owner: @import("solana_program_sdk").PublicKey,
};

const CloseAccounts = struct {
    authority: Signer,
};

test "idl: discriminator json size" {
    const allocator = std.testing.allocator;
    const json = try discriminatorJson(allocator, "initialize");
    try std.testing.expect(json.array.items.len == 8);
}

test "idl: json generation has core sections" {
    const allocator = std.testing.allocator;
    const json_bytes = try generateJson(allocator, ExampleProgram, .{});
    defer allocator.free(json_bytes);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_bytes, .{});
    defer parsed.deinit();

    const root = parsed.value.object;
    try std.testing.expect(root.contains("name"));
    try std.testing.expect(root.contains("address"));
    try std.testing.expect(root.contains("instructions"));
    try std.testing.expect(root.contains("accounts"));
    try std.testing.expect(root.contains("types"));
    try std.testing.expect(root.contains("errors"));
    try std.testing.expect(root.contains("constants"));
    try std.testing.expect(root.contains("events"));
    try std.testing.expect(root.contains("metadata"));
}

test "idl: instruction args types" {
    const allocator = std.testing.allocator;
    const json_bytes = try generateJson(allocator, ExampleProgram, .{});
    defer allocator.free(json_bytes);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_bytes, .{});
    defer parsed.deinit();

    const instructions = parsed.value.object.get("instructions").?.array;
    var initialize: ?std.json.ObjectMap = null;
    for (instructions.items) |item| {
        const obj = item.object;
        if (std.mem.eql(u8, obj.get("name").?.string, "initialize")) {
            initialize = obj;
            break;
        }
    }
    try std.testing.expect(initialize != null);
    const args = initialize.?.get("args").?.array;

    try std.testing.expectEqualStrings("amount", args.items[0].object.get("name").?.string);
    try std.testing.expectEqualStrings("u64", args.items[0].object.get("type").?.string);

    try std.testing.expectEqualStrings("flag", args.items[1].object.get("name").?.string);
    try std.testing.expectEqualStrings("bool", args.items[1].object.get("type").?.string);

    try std.testing.expectEqualStrings("owner", args.items[2].object.get("name").?.string);
    try std.testing.expectEqualStrings("publicKey", args.items[2].object.get("type").?.string);
}

test "idl: event and constraints details" {
    const allocator = std.testing.allocator;
    const json_bytes = try generateJson(allocator, ExampleProgram, .{});
    defer allocator.free(json_bytes);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_bytes, .{});
    defer parsed.deinit();

    const root = parsed.value.object;
    const events = root.get("events").?.array;
    const event_fields = events.items[0].object.get("fields").?.array;
    try std.testing.expectEqualStrings("CounterEvent", events.items[0].object.get("name").?.string);
    try std.testing.expect(event_fields.items[0].object.get("index").?.bool);

    const constants = root.get("constants").?.array;
    try std.testing.expectEqualStrings("fee_bps", constants.items[0].object.get("name").?.string);

    const metadata = root.get("metadata").?.object;
    try std.testing.expectEqualStrings("example", metadata.get("name").?.string);

    const instructions = root.get("instructions").?.array;
    var initialize: ?std.json.ObjectMap = null;
    for (instructions.items) |item| {
        const obj = item.object;
        if (std.mem.eql(u8, obj.get("name").?.string, "initialize")) {
            initialize = obj;
            break;
        }
    }
    try std.testing.expect(initialize != null);
    const accounts = initialize.?.get("accounts").?.array;
    var counter_account: ?std.json.ObjectMap = null;
    for (accounts.items) |item| {
        const obj = item.object;
        if (std.mem.eql(u8, obj.get("name").?.string, "counter")) {
            counter_account = obj;
            break;
        }
    }
    try std.testing.expect(counter_account != null);
    const constraints = counter_account.?.get("constraints").?.object;
    try std.testing.expect(constraints.contains("seeds"));
    try std.testing.expect(constraints.contains("bump"));
    try std.testing.expect(constraints.contains("close"));
    try std.testing.expect(constraints.contains("realloc"));
    try std.testing.expect(constraints.contains("rentExempt"));
    try std.testing.expect(constraints.contains("constraint"));
    try std.testing.expectEqualStrings("authority.key() == counter.authority", constraints.get("constraint").?.string);
}
