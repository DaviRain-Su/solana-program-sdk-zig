//! Simplified DSL for Solana Program Development
//!
//! This module provides a more concise syntax for defining accounts and instructions,
//! reducing boilerplate while maintaining full type safety via Zig's comptime.
//!
//! ## Design Goals
//! 1. Minimize boilerplate - developers focus on business logic
//! 2. Auto-derive discriminators from type names
//! 3. Inline constraint definitions at field level
//! 4. Type-safe constraint validation at compile time
//!
//! ## Example Usage
//! ```zig
//! const dsl = anchor.simple;
//!
//! // Define account data (discriminator auto-derived from "Counter")
//! const CounterData = struct {
//!     count: u64,
//!     authority: PublicKey,
//! };
//!
//! // Define instruction with inline constraints
//! const Initialize = dsl.Instruction("initialize", struct {
//!     // Signer who pays for account creation
//!     payer: dsl.Signer(.mut),
//!     // Counter account to initialize (mut + init + payer)
//!     counter: dsl.Init(CounterData, .{ .payer = "payer" }),
//!     // System program for CPI
//!     system_program: dsl.Program(SystemProgram.id),
//! }, struct {
//!     initial_value: u64,
//! });
//!
//! // Handler - just business logic!
//! pub fn initialize(ctx: Initialize.Context, args: Initialize.Args) !void {
//!     ctx.accounts.counter.data.count = args.initial_value;
//!     ctx.accounts.counter.data.authority = ctx.accounts.payer.key().*;
//! }
//! ```

const std = @import("std");
const sol = @import("solana_program_sdk");
const account_mod = @import("account.zig");
const signer_mod = @import("signer.zig");
const program_mod = @import("program.zig");
const context_mod = @import("context.zig");
const discriminator_mod = @import("discriminator.zig");
const seeds_mod = @import("seeds.zig");
const attr_mod = @import("attr.zig");
const constraints_mod = @import("constraints.zig");

const PublicKey = sol.PublicKey;
const SeedSpec = seeds_mod.SeedSpec;
const AccountInfo = sol.account.Account.Info;

// ============================================================================
// Simplified Account Types
// ============================================================================

/// Signer account with optional mutability.
///
/// Usage:
/// ```zig
/// payer: Signer(.mut),      // Mutable signer
/// authority: Signer(.{}),   // Immutable signer
/// ```
pub fn Signer(comptime config: SignerConfig) type {
    if (config.mut) {
        return signer_mod.SignerMut;
    }
    return signer_mod.Signer;
}

pub const SignerConfig = struct {
    mut: bool = false,

    pub const mut = SignerConfig{ .mut = true };
};

/// Program account for CPI.
///
/// Usage:
/// ```zig
/// system_program: Program(SystemProgram.id),
/// token_program: Program(TokenProgram.id),
/// ```
pub const Program = program_mod.Program;

/// Unchecked account - raw AccountInfo without validation.
///
/// Usage:
/// ```zig
/// unchecked: UncheckedAccount,
/// ```
pub const UncheckedAccount = *const AccountInfo;

// ============================================================================
// Data Account with Auto-Discriminator
// ============================================================================

/// Account with auto-derived discriminator from type name.
///
/// Usage:
/// ```zig
/// // Basic usage - discriminator derived from "CounterData"
/// counter: Data(CounterData, .{ .mut = true }),
///
/// // With custom discriminator name
/// counter: Data(CounterData, .{ .mut = true, .name = "Counter" }),
///
/// // With owner constraint
/// counter: Data(CounterData, .{ .owner = my_program_id }),
/// ```
pub fn Data(comptime T: type, comptime config: DataConfig) type {
    const disc_name = config.name orelse @typeName(T);
    const discriminator = discriminator_mod.accountDiscriminator(disc_name);

    return account_mod.Account(T, .{
        .discriminator = discriminator,
        .mut = config.mut,
        .signer = config.signer,
        .owner = config.owner,
        .owner_expr = config.owner_expr,
        .address = config.address,
        .address_expr = config.address_expr,
        .executable = config.executable,
        .zero = config.zero,
        .dup = config.dup,
        .seeds = config.seeds,
        .bump = config.bump,
        .bump_field = config.bump_field,
        .seeds_program = config.seeds_program,
        .constraint = config.constraint,
    });
}

pub const DataConfig = struct {
    /// Custom discriminator name (default: type name)
    name: ?[]const u8 = null,
    /// Account must be writable
    mut: bool = false,
    /// Account must be signer
    signer: bool = false,
    /// Expected owner program
    owner: ?PublicKey = null,
    /// Owner expression
    owner_expr: ?[]const u8 = null,
    /// Expected address
    address: ?PublicKey = null,
    /// Address expression
    address_expr: ?[]const u8 = null,
    /// Account must be executable
    executable: bool = false,
    /// Account data must be zeroed
    zero: bool = false,
    /// Allow duplicate accounts
    dup: bool = false,
    /// PDA seeds
    seeds: ?[]const SeedSpec = null,
    /// Store bump in account
    bump: bool = false,
    /// Bump field name
    bump_field: ?[]const u8 = null,
    /// Seeds program override
    seeds_program: ?SeedSpec = null,
    /// Custom constraint expression
    constraint: ?[]const u8 = null,

    // Convenience presets
    pub const mut = DataConfig{ .mut = true };
    pub const readonly = DataConfig{};
};

// ============================================================================
// Init Account - For Account Creation
// ============================================================================

/// Account initialization with automatic space calculation.
///
/// Usage:
/// ```zig
/// // Initialize with payer
/// counter: Init(CounterData, .{ .payer = "payer" }),
///
/// // With custom space
/// counter: Init(CounterData, .{ .payer = "payer", .space = 256 }),
///
/// // Init if needed (idempotent)
/// counter: Init(CounterData, .{ .payer = "payer", .if_needed = true }),
/// ```
pub fn Init(comptime T: type, comptime config: InitConfig) type {
    const disc_name = config.name orelse @typeName(T);
    const discriminator = discriminator_mod.accountDiscriminator(disc_name);
    const default_space = discriminator_mod.DISCRIMINATOR_LENGTH + @sizeOf(T);

    return account_mod.Account(T, .{
        .discriminator = discriminator,
        .mut = true, // init always requires mut
        .init = !config.if_needed,
        .init_if_needed = config.if_needed,
        .payer = config.payer,
        .space = config.space orelse default_space,
        .seeds = config.seeds,
        .bump = config.bump,
        .bump_field = config.bump_field,
        .owner = config.owner,
        .zero = true, // init accounts are zero-initialized
    });
}

pub const InitConfig = struct {
    /// Payer account field name (required)
    payer: []const u8,
    /// Custom discriminator name
    name: ?[]const u8 = null,
    /// Custom space (default: discriminator + sizeof(T))
    space: ?usize = null,
    /// Init if needed (idempotent)
    if_needed: bool = false,
    /// PDA seeds for init
    seeds: ?[]const SeedSpec = null,
    /// Store bump in account
    bump: bool = false,
    /// Bump field name
    bump_field: ?[]const u8 = null,
    /// Expected owner (for init_if_needed validation)
    owner: ?PublicKey = null,
};

// ============================================================================
// PDA Account - Program Derived Address
// ============================================================================

/// PDA account with seed validation.
///
/// Usage:
/// ```zig
/// // PDA with literal seeds
/// config: PDA(ConfigData, .{
///     .seeds = &.{ seed("config"), seedAccount("authority") },
/// }),
///
/// // PDA with bump storage
/// vault: PDA(VaultData, .{
///     .seeds = &.{ seed("vault"), seedField("user") },
///     .bump = true,
/// }),
/// ```
pub fn PDA(comptime T: type, comptime config: PDAConfig) type {
    const disc_name = config.name orelse @typeName(T);
    const discriminator = discriminator_mod.accountDiscriminator(disc_name);

    return account_mod.Account(T, .{
        .discriminator = discriminator,
        .mut = config.mut,
        .seeds = config.seeds,
        .bump = config.bump,
        .bump_field = config.bump_field,
        .seeds_program = config.seeds_program,
        .owner = config.owner,
        .constraint = config.constraint,
    });
}

pub const PDAConfig = struct {
    /// PDA seeds (required)
    seeds: []const SeedSpec,
    /// Custom discriminator name
    name: ?[]const u8 = null,
    /// Account must be writable
    mut: bool = false,
    /// Store bump in account data
    bump: bool = false,
    /// Bump field name in data
    bump_field: ?[]const u8 = null,
    /// Program for seeds derivation
    seeds_program: ?SeedSpec = null,
    /// Expected owner
    owner: ?PublicKey = null,
    /// Custom constraint
    constraint: ?[]const u8 = null,

    pub const mut = PDAConfig{ .seeds = &.{}, .mut = true };
};

// ============================================================================
// Close Account - For Account Deletion
// ============================================================================

/// Account that will be closed (lamports transferred to destination).
///
/// Usage:
/// ```zig
/// // Close account, send lamports to "receiver"
/// to_close: Close(MyData, .{ .destination = "receiver" }),
/// ```
pub fn Close(comptime T: type, comptime config: CloseConfig) type {
    const disc_name = config.name orelse @typeName(T);
    const discriminator = discriminator_mod.accountDiscriminator(disc_name);

    return account_mod.Account(T, .{
        .discriminator = discriminator,
        .mut = true, // close requires mut
        .close = config.destination,
        .owner = config.owner,
        .constraint = config.constraint,
    });
}

pub const CloseConfig = struct {
    /// Destination account field name for lamports
    destination: []const u8,
    /// Custom discriminator name
    name: ?[]const u8 = null,
    /// Expected owner
    owner: ?PublicKey = null,
    /// Custom constraint
    constraint: ?[]const u8 = null,
};

// ============================================================================
// Seed Helpers
// ============================================================================

/// Literal seed bytes.
pub fn seed(comptime literal: []const u8) SeedSpec {
    return .{ .literal = literal };
}

/// Seed from another account's pubkey.
pub fn seedAccount(comptime account_field: []const u8) SeedSpec {
    return .{ .account = account_field };
}

/// Seed from a data field value.
pub fn seedField(comptime data_field: []const u8) SeedSpec {
    return .{ .field = data_field };
}

/// Bump seed marker.
pub fn seedBump(comptime account_field: []const u8) SeedSpec {
    return .{ .bump = account_field };
}

// ============================================================================
// Instruction Definition
// ============================================================================

/// Define a complete instruction with accounts and arguments.
///
/// Usage:
/// ```zig
/// const Transfer = Instruction("transfer", struct {
///     from: Data(TokenAccount, .mut),
///     to: Data(TokenAccount, .mut),
///     authority: Signer(.{}),
/// }, struct {
///     amount: u64,
/// });
///
/// pub fn transfer(ctx: Transfer.Context, args: Transfer.Args) !void {
///     // Business logic here
/// }
/// ```
pub fn Instruction(
    comptime name: []const u8,
    comptime AccountsType: type,
    comptime ArgsType: type,
) type {
    return struct {
        pub const instruction_name = name;
        pub const Accounts = AccountsType;
        pub const Args = ArgsType;
        pub const Context = context_mod.Context(Accounts);
        pub const discriminator = discriminator_mod.instructionDiscriminator(name);

        /// Check if this instruction matches the given data discriminator.
        pub fn matches(data: []const u8) bool {
            if (data.len < discriminator_mod.DISCRIMINATOR_LENGTH) return false;
            return std.mem.eql(u8, data[0..discriminator_mod.DISCRIMINATOR_LENGTH], &discriminator);
        }
    };
}

/// Define an instruction with no arguments.
pub fn InstructionNoArgs(
    comptime name: []const u8,
    comptime AccountsType: type,
) type {
    return Instruction(name, AccountsType, void);
}

// ============================================================================
// Program Definition
// ============================================================================

/// Define a complete program with all instructions.
///
/// Usage:
/// ```zig
/// const MyProgram = DefineProgram(.{
///     .id = my_program_id,
///     .instructions = .{
///         .initialize = Initialize,
///         .transfer = Transfer,
///         .close = CloseInstruction,
///     },
/// });
///
/// // Entry point
/// pub const entry = MyProgram.entrypoint;
/// ```
pub fn DefineProgram(comptime config: ProgramConfig) type {
    return struct {
        pub const id = config.id;
        pub const instructions = config.instructions;

        /// Process instruction entrypoint.
        pub fn entrypoint(
            program_id: *PublicKey,
            accounts: []sol.Account,
            data: []const u8,
        ) sol.ProgramResult {
            // Convert to AccountInfo slice
            var infos: [32]AccountInfo = undefined;
            const count = @min(accounts.len, 32);
            for (accounts[0..count], 0..) |*acc, i| {
                infos[i] = acc.info().*;
            }

            dispatch(program_id, infos[0..count], data) catch |err| {
                return .{ .err = mapError(err) };
            };
            return .ok;
        }

        fn dispatch(
            program_id: *const PublicKey,
            accounts: []const AccountInfo,
            data: []const u8,
        ) !void {
            _ = program_id;
            if (data.len < discriminator_mod.DISCRIMINATOR_LENGTH) {
                return error.InstructionMissing;
            }

            const disc = data[0..discriminator_mod.DISCRIMINATOR_LENGTH];

            inline for (@typeInfo(@TypeOf(config.instructions)).@"struct".fields) |field| {
                const InstrType = @field(config.instructions, field.name);
                if (@TypeOf(InstrType) != type) continue;
                if (!@hasDecl(InstrType, "discriminator")) continue;

                if (std.mem.eql(u8, disc, &InstrType.discriminator)) {
                    // Found matching instruction
                    const ctx = try context_mod.parseContext(InstrType.Accounts, &id, accounts);

                    if (InstrType.Args == void) {
                        // Call handler from config.handlers
                        if (@hasField(@TypeOf(config.handlers), field.name)) {
                            const handler = @field(config.handlers, field.name);
                            return handler(ctx);
                        }
                    } else {
                        const args_data = data[discriminator_mod.DISCRIMINATOR_LENGTH..];
                        const args = try sol.borsh.deserialize(InstrType.Args, args_data);
                        if (@hasField(@TypeOf(config.handlers), field.name)) {
                            const handler = @field(config.handlers, field.name);
                            return handler(ctx, args);
                        }
                    }
                    return error.HandlerNotFound;
                }
            }

            return error.InstructionNotFound;
        }

        fn mapError(err: anyerror) sol.ProgramError {
            _ = err;
            return .InvalidInstructionData;
        }
    };
}

pub const ProgramConfig = struct {
    id: PublicKey,
    instructions: anytype,
    handlers: anytype = .{},
};

// ============================================================================
// Constraint Expression Helpers
// ============================================================================

/// Build a constraint expression string.
///
/// Usage:
/// ```zig
/// counter: Data(CounterData, .{
///     .mut = true,
///     .constraint = constraint("counter.authority == authority"),
/// }),
/// ```
pub fn constraint(comptime expr: []const u8) []const u8 {
    return expr;
}

/// Has-one constraint shorthand.
///
/// Usage:
/// ```zig
/// counter: Data(CounterData, .{
///     .constraint = hasOne("authority"),
/// }),
/// ```
pub fn hasOne(comptime field: []const u8) []const u8 {
    return field ++ " == " ++ field;
}

// ============================================================================
// Tests
// ============================================================================

test "Signer config" {
    const MutSigner = Signer(.mut);
    const ImmutSigner = Signer(.{});

    try std.testing.expect(MutSigner == signer_mod.SignerMut);
    try std.testing.expect(ImmutSigner == signer_mod.Signer);
}

test "seed helpers" {
    const s1 = seed("counter");
    const s2 = seedAccount("authority");
    const s3 = seedField("user");

    try std.testing.expect(s1 == .literal);
    try std.testing.expect(s2 == .account);
    try std.testing.expect(s3 == .field);
}

test "Instruction definition" {
    const TestAccounts = struct {
        payer: signer_mod.SignerMut,
    };

    const TestArgs = struct {
        value: u64,
    };

    const TestInstr = Instruction("test_instruction", TestAccounts, TestArgs);

    try std.testing.expect(TestInstr.Accounts == TestAccounts);
    try std.testing.expect(TestInstr.Args == TestArgs);
    try std.testing.expectEqualStrings("test_instruction", TestInstr.instruction_name);
}
