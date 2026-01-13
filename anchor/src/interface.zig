//! Zig implementation of Anchor interface and CPI helpers.
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/src/interface.rs

const std = @import("std");
const sol = @import("solana_program_sdk");
const discriminator_mod = @import("discriminator.zig");

const AccountInfo = sol.account.Account.Info;
const PublicKey = sol.PublicKey;
const AccountMeta = sol.instruction.AccountMeta;
const Instruction = sol.instruction.Instruction;

const Discriminator = discriminator_mod.Discriminator;
const DISCRIMINATOR_LENGTH = discriminator_mod.DISCRIMINATOR_LENGTH;

/// Interface validation config
pub const InterfaceConfig = struct {
    program_ids: ?[]const PublicKey = null,
};

/// Interface program account type with multiple allowed IDs.
pub fn InterfaceProgram(comptime program_ids: []const PublicKey) type {
    if (program_ids.len == 0) {
        @compileError("InterfaceProgram requires at least one program id");
    }

    return struct {
        const Self = @This();

        info: *const AccountInfo,

        pub const IDS = program_ids;

        pub fn load(info: *const AccountInfo) !Self {
            if (info.is_executable == 0) {
                return error.ConstraintExecutable;
            }
            if (!isAllowedProgramId(program_ids, info.id.*)) {
                return error.InvalidProgramId;
            }
            return Self{ .info = info };
        }

        pub fn key(self: Self) *const PublicKey {
            return self.info.id;
        }

        pub fn toAccountInfo(self: Self) *const AccountInfo {
            return self.info;
        }
    };
}

/// Interface account configuration.
pub const InterfaceAccountConfig = struct {
    discriminator: ?Discriminator = null,
    owners: ?[]const PublicKey = null,
    address: ?PublicKey = null,
    mut: bool = false,
    signer: bool = false,
};

/// Interface account wrapper that accepts multiple owner programs.
pub fn InterfaceAccount(comptime T: type, comptime config: InterfaceAccountConfig) type {
    return struct {
        const Self = @This();

        info: *const AccountInfo,
        data: *T,

        pub const DataType = T;
        pub const DISCRIMINATOR: ?Discriminator = config.discriminator;
        pub const OWNERS: ?[]const PublicKey = config.owners;
        pub const ADDRESS: ?PublicKey = config.address;
        pub const HAS_MUT: bool = config.mut;
        pub const HAS_SIGNER: bool = config.signer;

        pub fn load(info: *const AccountInfo) !Self {
            if (config.owners) |owners| {
                if (!isAllowedProgramId(owners, info.owner_id.*)) {
                    return error.ConstraintOwner;
                }
            }
            if (config.address) |expected_address| {
                if (!info.id.equals(expected_address)) {
                    return error.ConstraintAddress;
                }
            }
            if (config.mut and info.is_writable == 0) {
                return error.ConstraintMut;
            }
            if (config.signer and info.is_signer == 0) {
                return error.ConstraintSigner;
            }

            const offset = if (config.discriminator != null) DISCRIMINATOR_LENGTH else 0;
            if (info.data_len < offset + @sizeOf(T)) {
                return error.AccountDiscriminatorNotFound;
            }

            if (config.discriminator) |expected| {
                const data_slice = info.data[0..DISCRIMINATOR_LENGTH];
                if (!std.mem.eql(u8, data_slice, &expected)) {
                    return error.AccountDiscriminatorMismatch;
                }
            }

            const data_ptr: *T = @ptrCast(@alignCast(info.data + offset));
            return Self{ .info = info, .data = data_ptr };
        }

        pub fn key(self: Self) *const PublicKey {
            return self.info.id;
        }

        pub fn toAccountInfo(self: Self) *const AccountInfo {
            return self.info;
        }
    };
}

/// CPI interface builder for programs without fixed IDs.
pub fn Interface(comptime Program: type, comptime config: InterfaceConfig) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        program_id: PublicKey,

        pub fn init(allocator: std.mem.Allocator, program_id: PublicKey) !Self {
            if (config.program_ids) |ids| {
                if (!isAllowedProgramId(ids, program_id)) {
                    return error.InvalidProgramId;
                }
            }
            return Self{ .allocator = allocator, .program_id = program_id };
        }

        pub fn instructionNoArgs(
            self: *Self,
            comptime name: []const u8,
            accounts: anytype,
        ) !Instruction {
            const instr = getInstructionType(name);
            if (instr.Args != void) {
                @compileError("instructionNoArgs used with non-void Args");
            }
            return try buildInstruction(self, name, accounts, null);
        }

        pub fn instruction(
            self: *Self,
            comptime name: []const u8,
            accounts: anytype,
            args: anytype,
        ) !Instruction {
            const instr = getInstructionType(name);
            if (instr.Args == void) {
                @compileError("instruction used with void Args; use instructionNoArgs");
            }
            if (@TypeOf(args) != instr.Args) {
                @compileError("instruction args must match instruction Args");
            }
            return try buildInstruction(self, name, accounts, args);
        }

        fn getInstructionType(comptime name: []const u8) type {
            if (!@hasDecl(Program, "instructions")) {
                @compileError("Program is missing instructions");
            }
            if (!@hasField(Program.instructions, name)) {
                @compileError("Program is missing instruction: " ++ name);
            }
            return @field(Program.instructions, name);
        }

        fn buildInstruction(
            self: *Self,
            comptime name: []const u8,
            accounts: anytype,
            args: anytype,
        ) !Instruction {
            const instr = getInstructionType(name);
            if (@TypeOf(accounts) != instr.Accounts) {
                @compileError("instruction accounts must match instruction Accounts");
            }

            var metas = std.ArrayList(AccountMeta).init(self.allocator);
            defer metas.deinit();
            try buildAccountMetas(instr.Accounts, accounts, &metas);

            const disc = discriminator_mod.instructionDiscriminator(name);
            if (instr.Args == void) {
                return Instruction.newWithBytes(self.allocator, self.program_id, disc[0..], metas.items);
            }

            const args_bytes = try sol.borsh.serializeAlloc(self.allocator, instr.Args, args);
            defer self.allocator.free(args_bytes);
            var data = try self.allocator.alloc(u8, DISCRIMINATOR_LENGTH + args_bytes.len);
            defer self.allocator.free(data);
            @memcpy(data[0..DISCRIMINATOR_LENGTH], &disc);
            @memcpy(data[DISCRIMINATOR_LENGTH..], args_bytes);
            return Instruction.newWithBytes(self.allocator, self.program_id, data, metas.items);
        }
    };
}

fn buildAccountMetas(
    comptime Accounts: type,
    accounts: Accounts,
    metas: *std.ArrayList(AccountMeta),
) !void {
    const fields = @typeInfo(Accounts).@"struct".fields;
    inline for (fields) |field| {
        const value = @field(accounts, field.name);
        if (try accountInfoFromValue(value)) |info| {
            try metas.append(AccountMeta.init(info.id.*, info.is_signer != 0, info.is_writable != 0));
        }
    }
}

fn accountInfoFromValue(value: anytype) !?*const AccountInfo {
    const T = @TypeOf(value);
    if (@typeInfo(T) == .optional) {
        if (value == null) return null;
        return try accountInfoFromValue(value.?);
    }
    if (T == *AccountInfo) {
        return value;
    }
    if (T == *const AccountInfo) {
        return value;
    }
    if (@hasDecl(T, "toAccountInfo")) {
        return value.toAccountInfo();
    }
    @compileError("interface accounts must provide toAccountInfo() or AccountInfo");
}

fn isAllowedProgramId(comptime ids: []const PublicKey, program_id: PublicKey) bool {
    inline for (ids) |id| {
        if (id.equals(program_id)) return true;
    }
    return false;
}

test "InterfaceProgram accepts allowed ids" {
    const allowed = [_]PublicKey{
        PublicKey.comptimeFromBase58("11111111111111111111111111111111"),
        PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"),
    };
    const ProgramType = InterfaceProgram(allowed[0..]);

    var owner = PublicKey.default();
    var id = allowed[1];
    var lamports: u64 = 1;
    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 1,
        .rent_epoch = 0,
    };

    _ = try ProgramType.load(&info);
}

test "InterfaceAccount validates owner list" {
    const owners = [_]PublicKey{
        PublicKey.comptimeFromBase58("11111111111111111111111111111111"),
    };
    const Data = struct { value: u64 };
    const disc = discriminator_mod.accountDiscriminator("Iface");
    const Iface = InterfaceAccount(Data, .{ .discriminator = disc, .owners = owners[0..] });

    var owner = owners[0];
    var id = PublicKey.default();
    var lamports: u64 = 1;
    var buffer: [DISCRIMINATOR_LENGTH + @sizeOf(Data)]u8 = undefined;
    @memcpy(buffer[0..DISCRIMINATOR_LENGTH], &disc);
    const data_ptr: *Data = @ptrCast(@alignCast(buffer[DISCRIMINATOR_LENGTH..].ptr));
    data_ptr.* = .{ .value = 1 };

    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = buffer.len,
        .data = buffer[0..].ptr,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        .rent_epoch = 0,
    };

    _ = try Iface.load(&info);
}

test "Interface builds CPI instruction" {
    const Accounts = struct {
        authority: *const sol.account.Account.Info,
    };
    const Args = struct { amount: u64 };

    const Program = struct {
        pub const instructions = struct {
            pub const deposit = @import("idl.zig").Instruction(.{ .Accounts = Accounts, .Args = Args });
        };
    };

    const allocator = std.testing.allocator;
    var key = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1;
    var data: [0]u8 = .{};
    const info = AccountInfo{
        .id = &key,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = data.len,
        .data = data[0..].ptr,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
        .rent_epoch = 0,
    };
    const accounts = Accounts{ .authority = &info };

    var iface = try Interface(Program, .{}).init(allocator, PublicKey.default());
    const ix = try iface.instruction("deposit", accounts, Args{ .amount = 7 });
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), ix.accounts.len);
}
