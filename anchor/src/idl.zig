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

const Allocator = std.mem.Allocator;

const Signer = signer_mod.Signer;
const SignerMut = signer_mod.SignerMut;
const UncheckedProgram = program_mod.UncheckedProgram;

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

    var root = std.json.ObjectMap.init(a);
    try putString(a, &root, "version", "0.1.0");
    try putString(a, &root, "name", name);
    try putString(a, &root, "address", address);
    try root.put(try a.dupe(u8, "instructions"), instructions);
    try root.put(try a.dupe(u8, "accounts"), .{ .array = account_defs });
    try root.put(try a.dupe(u8, "types"), .{ .array = type_defs });
    try root.put(try a.dupe(u8, "errors"), errors);

    const json = std.json.Value{ .object = root };
    return std.json.stringifyAlloc(allocator, json, .{ .whitespace = .indent_2 });
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

fn accountsJson(allocator: Allocator, accounts: []const AccountDescriptor) !std.json.Value {
    var arr = std.json.Array.init(allocator);
    try arr.ensureTotalCapacity(accounts.len);

    for (accounts) |account| {
        var obj = std.json.ObjectMap.init(allocator);
        try putString(allocator, &obj, "name", account.name);
        try obj.put(try allocator.dupe(u8, "isMut"), .{ .bool = account.is_mut });
        try obj.put(try allocator.dupe(u8, "isSigner"), .{ .bool = account.is_signer });
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

    pub const instructions = struct {
        pub const initialize = Instruction(.{ .Accounts = InitializeAccounts, .Args = InitializeArgs });
        pub const close = Instruction(.{ .Accounts = CloseAccounts, .Args = void });
    };

    pub const errors = enum(u32) {
        InvalidAmount = 6000,
    };
};

const InitializeAccounts = struct {
    authority: Signer,
    payer: SignerMut,
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
}

test "idl: instruction args types" {
    const allocator = std.testing.allocator;
    const json_bytes = try generateJson(allocator, ExampleProgram, .{});
    defer allocator.free(json_bytes);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_bytes, .{});
    defer parsed.deinit();

    const instructions = parsed.value.object.get("instructions").?.array;
    const initialize = instructions.items[0].object;
    const args = initialize.get("args").?.array;

    try std.testing.expectEqualStrings("amount", args.items[0].object.get("name").?.string);
    try std.testing.expectEqualStrings("u64", args.items[0].object.get("type").?.string);

    try std.testing.expectEqualStrings("flag", args.items[1].object.get("name").?.string);
    try std.testing.expectEqualStrings("bool", args.items[1].object.get("type").?.string);

    try std.testing.expectEqualStrings("owner", args.items[2].object.get("name").?.string);
    try std.testing.expectEqualStrings("publicKey", args.items[2].object.get("type").?.string);
}
