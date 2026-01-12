//! Zig implementation of Anchor client code generation
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/syn/src/codegen/mod.rs
//!
//! Generates Zig client modules from comptime program definitions.

const std = @import("std");
const discriminator_mod = @import("discriminator.zig");
const idl_mod = @import("idl.zig");

const Allocator = std.mem.Allocator;
const IdlConfig = idl_mod.IdlConfig;

/// Generate Zig client source code for a program.
pub fn generateZigClient(allocator: Allocator, comptime program: anytype, comptime config: IdlConfig) ![]u8 {
    var output = std.ArrayList(u8).init(allocator);
    errdefer output.deinit();

    const program_name = idl_mod.shortTypeName(@typeName(@TypeOf(program)));
    var address_buffer: [44]u8 = undefined;
    const address = program.id.toBase58(&address_buffer);

    try output.appendSlice("const std = @import(\"std\");\n");
    try output.appendSlice("const sdk = @import(\"solana_sdk\");\n\n");
    try output.appendSlice("pub const PublicKey = sdk.PublicKey;\n");
    try output.appendSlice("pub const AccountMeta = sdk.AccountMeta;\n");
    try output.appendSlice("pub const Instruction = sdk.instruction.Instruction;\n\n");

    try appendFmt(&output, allocator, "pub const PROGRAM_ID = sdk.PublicKey.comptimeFromBase58(\"{s}\");\n\n", .{address});
    try appendFmt(&output, allocator, "/// Client for {s}\n", .{program_name});
    try output.appendSlice("pub const Client = struct {\n");
    try output.appendSlice("    allocator: std.mem.Allocator,\n\n");
    try output.appendSlice("    pub fn init(allocator: std.mem.Allocator) Client {\n");
    try output.appendSlice("        return .{ .allocator = allocator };\n");
    try output.appendSlice("    }\n\n");

    const fields = @typeInfo(@TypeOf(program.instructions)).@"struct".fields;
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
        const accounts = idl_mod.extractAccounts(Accounts, config);

        try appendFmt(&output, allocator, "    pub fn {s}(self: *Client", .{field.name});
        for (accounts) |account| {
            try appendFmt(&output, allocator, ", {s}: PublicKey", .{account.name});
        }
        if (!isVoidArgs(Args)) {
            try output.appendSlice(", args: anytype");
        }
        try output.appendSlice(") !Instruction {\n");

        try output.appendSlice("        _ = self;\n");
        try output.appendSlice("        const accounts = [_]AccountMeta{\n");
        for (accounts) |account| {
            try appendFmt(
                &output,
                allocator,
                "            AccountMeta.init({s}, {s}, {s}),\n",
                .{ account.name, boolLiteral(account.is_signer), boolLiteral(account.is_mut) },
            );
        }
        try output.appendSlice("        };\n\n");

        const discriminator = discriminator_mod.instructionDiscriminator(field.name);
        if (isVoidArgs(Args)) {
            try output.appendSlice("        const data = ");
            try appendDiscriminator(&output, allocator, discriminator);
            try output.appendSlice(";\n");
            try output.appendSlice("        return try Instruction.newWithBytes(self.allocator, PROGRAM_ID, data[0..], &accounts);\n");
        } else {
            try output.appendSlice("        const args_bytes = try sdk.borsh.serializeAlloc(self.allocator, @TypeOf(args), args);\n");
            try output.appendSlice("        defer self.allocator.free(args_bytes);\n");
            try output.appendSlice("        var data = try self.allocator.alloc(u8, 8 + args_bytes.len);\n");
            try output.appendSlice("        defer self.allocator.free(data);\n\n");
            try output.appendSlice("        const discriminator = ");
            try appendDiscriminator(&output, allocator, discriminator);
            try output.appendSlice(";\n");
            try output.appendSlice("        @memcpy(data[0..8], discriminator[0..]);\n");
            try output.appendSlice("        @memcpy(data[8..], args_bytes);\n");
            try output.appendSlice("        return try Instruction.newWithBytes(self.allocator, PROGRAM_ID, data, &accounts);\n");
        }

        try output.appendSlice("    }\n\n");
    }

    try output.appendSlice("};\n");

    return output.toOwnedSlice(allocator);
}

fn isVoidArgs(comptime T: type) bool {
    if (T == void) return true;
    const info = @typeInfo(T);
    return info == .@"struct" and info.@"struct".fields.len == 0;
}

fn appendFmt(list: *std.ArrayList(u8), allocator: Allocator, comptime fmt: []const u8, args: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try list.appendSlice(text);
}

fn appendDiscriminator(list: *std.ArrayList(u8), allocator: Allocator, discriminator: [8]u8) !void {
    try list.appendSlice("[_]u8{");
    for (discriminator, 0..) |byte, index| {
        if (index != 0) {
            try list.appendSlice(", ");
        }
        try appendFmt(list, allocator, "{d}", .{byte});
    }
    try list.appendSlice("}");
}

fn boolLiteral(value: bool) []const u8 {
    return if (value) "true" else "false";
}

const ExampleProgram = idl_mod.ExampleProgram;

test "codegen: emits program id and instruction builder" {
    const allocator = std.testing.allocator;
    const client_src = try generateZigClient(allocator, ExampleProgram, .{});
    defer allocator.free(client_src);

    try std.testing.expect(std.mem.indexOf(u8, client_src, "PROGRAM_ID") != null);
    try std.testing.expect(std.mem.indexOf(u8, client_src, "Instruction.newWithBytes") != null);
    try std.testing.expect(std.mem.indexOf(u8, client_src, "borsh.serializeAlloc") != null);
}
