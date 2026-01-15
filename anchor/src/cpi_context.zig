//! Anchor-style CPI context builder.
//!
//! Rust source: https://github.com/coral-xyz/anchor/blob/master/lang/src/context.rs

const std = @import("std");
const sol = @import("solana_program_sdk");
const interface_mod = @import("interface.zig");

const AccountInfo = sol.account.Account.Info;
const Instruction = sol.instruction.Instruction;

fn toAccountInfo(value: anytype) *const AccountInfo {
    const T = @TypeOf(value);
    if (@typeInfo(T) == .pointer) {
        const ChildType = @typeInfo(T).pointer.child;
        if (ChildType == AccountInfo) {
            return value;
        }
        if (@hasDecl(ChildType, "toAccountInfo")) {
            return value.toAccountInfo();
        }
    }
    if (@hasDecl(T, "toAccountInfo")) {
        return value.toAccountInfo();
    }
    @compileError("program must be AccountInfo or type with toAccountInfo()");
}

/// CPI context builder.
pub fn CpiContext(comptime Program: type, comptime Accounts: type) type {
    return CpiContextWithConfig(Program, Accounts, .{});
}

/// CPI context builder with interface config.
pub fn CpiContextWithConfig(
    comptime Program: type,
    comptime Accounts: type,
    comptime config: interface_mod.InterfaceConfig,
) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        program: *const AccountInfo,
        accounts: Accounts,
        remaining: ?[]const AccountInfo = null,
        signer_seeds: ?[]const []const []const u8 = null,

        /// Create a new CPI context.
        pub fn init(allocator: std.mem.Allocator, program: anytype, accounts: Accounts) Self {
            return .{
                .allocator = allocator,
                .program = toAccountInfo(program),
                .accounts = accounts,
            };
        }

        /// Attach remaining accounts.
        pub fn withRemainingAccounts(self: Self, remaining: []const AccountInfo) Self {
            var next = self;
            next.remaining = remaining;
            return next;
        }

        /// Attach signer seeds.
        pub fn withSignerSeeds(self: Self, signer_seeds: []const []const []const u8) Self {
            var next = self;
            next.signer_seeds = signer_seeds;
            return next;
        }

        /// Build an instruction without args.
        pub fn instructionNoArgs(self: *const Self, comptime name: []const u8) !Instruction {
            var iface = try interface_mod.Interface(Program, config).init(
                self.allocator,
                self.program.id.*,
            );
            return try iface.instructionNoArgs(name, self.accounts, self.remaining);
        }

        /// Build an instruction with args.
        pub fn instruction(self: *const Self, comptime name: []const u8, args: anytype) !Instruction {
            var iface = try interface_mod.Interface(Program, config).init(
                self.allocator,
                self.program.id.*,
            );
            return try iface.instruction(name, self.accounts, args, self.remaining);
        }

        /// Invoke instruction without args.
        pub fn invokeNoArgs(self: *const Self, comptime name: []const u8) !sol.ProgramResult {
            var iface = try interface_mod.Interface(Program, config).init(
                self.allocator,
                self.program.id.*,
            );
            if (self.signer_seeds) |seeds| {
                return try iface.invokeSignedNoArgs(name, self.accounts, self.remaining, seeds);
            }
            return try iface.invokeNoArgs(name, self.accounts, self.remaining);
        }

        /// Invoke instruction with args.
        pub fn invoke(self: *const Self, comptime name: []const u8, args: anytype) !sol.ProgramResult {
            var iface = try interface_mod.Interface(Program, config).init(
                self.allocator,
                self.program.id.*,
            );
            if (self.signer_seeds) |seeds| {
                return try iface.invokeSigned(name, self.accounts, args, self.remaining, seeds);
            }
            return try iface.invoke(name, self.accounts, args, self.remaining);
        }
    };
}

test "CpiContext builds instruction" {
    const TestAccounts = struct {
        payer: *const AccountInfo,
    };

    const TestProgram = struct {
        pub const instructions = struct {
            pub const ping = @import("idl.zig").Instruction(.{
                .Accounts = TestAccounts,
                .Args = void,
            });
        };
    };

    var program_id = sol.PublicKey.default();
    var owner = sol.PublicKey.default();
    var lamports: u64 = 1;
    var data: [0]u8 = undefined;
    const program_info = AccountInfo{
        .id = &program_id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = &data,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 1,
        .rent_epoch = 0,
    };

    const payer_info = program_info;
    const accounts = TestAccounts{ .payer = &payer_info };

    const ctx = CpiContext(TestProgram, TestAccounts).init(std.testing.allocator, &program_info, accounts);
    const ix = try ctx.instructionNoArgs("ping");
    defer ix.deinit(std.testing.allocator);
    try std.testing.expect(ix.data_len == 8);
}
