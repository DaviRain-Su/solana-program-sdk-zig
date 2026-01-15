//! Type-Safe Simplified DSL for Solana Program Development
//!
//! This module provides a concise syntax with full compile-time type safety.
//! Field references use enum literals (`.payer`) instead of strings for
//! compile-time validation.
//!
//! ## Design Goals
//! 1. Concise syntax - minimal boilerplate
//! 2. Type-safe field references - `.payer` instead of `"payer"`
//! 3. Compile-time validation of all field references
//! 4. Auto-derive discriminators from type names
//!
//! ## Example Usage
//! ```zig
//! const dsl = anchor.typed;
//!
//! const CounterData = struct {
//!     count: u64,
//!     authority: PublicKey,
//! };
//!
//! // Type-safe instruction definition
//! const Initialize = dsl.Instr("initialize",
//!     // Accounts - field references validated at compile time
//!     dsl.Accounts(.{
//!         .payer = dsl.SignerMut,
//!         .counter = dsl.Init(CounterData, .{ .payer = .payer }),
//!         .system_program = dsl.Prog(SystemProgram.id),
//!     }),
//!     // Args
//!     struct { initial_value: u64 },
//! );
//!
//! // Handler with auto-generated Context type
//! pub fn initialize(ctx: Initialize.Ctx, args: Initialize.Args) !void {
//!     ctx.accounts.counter.data.count = args.initial_value;
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
const has_one_mod = @import("has_one.zig");

const PublicKey = sol.PublicKey;
const SeedSpec = seeds_mod.SeedSpec;
const AccountInfo = sol.account.Account.Info;

// ============================================================================
// Field Reference Resolution
// ============================================================================

/// Resolve a field reference to a string name.
/// Accepts both enum literals (.field) and strings ("field").
fn resolveFieldRef(comptime ref: anytype) []const u8 {
    const RefType = @TypeOf(ref);
    if (RefType == []const u8) return ref;
    if (RefType == @TypeOf(.enum_literal)) return @tagName(ref);
    if (@typeInfo(RefType) == .enum_literal) return @tagName(ref);
    @compileError("expected field name: use .field_name or \"field_name\"");
}

/// Resolve optional field reference.
fn resolveFieldRefOpt(comptime ref: anytype) ?[]const u8 {
    const RefType = @TypeOf(ref);
    if (RefType == ?[]const u8) return ref;
    if (@typeInfo(RefType) == .optional) {
        if (ref == null) return null;
        return resolveFieldRef(ref.?);
    }
    if (RefType == @TypeOf(null)) return null;
    return resolveFieldRef(ref);
}

// ============================================================================
// Account Type Markers (Zero-size types for DSL)
// ============================================================================

/// Immutable signer marker.
pub const Signer = struct {
    pub const IS_SIGNER = true;
    pub const IS_MUT = false;
    pub const AccountType = signer_mod.Signer;
};

/// Mutable signer marker.
pub const SignerMut = struct {
    pub const IS_SIGNER = true;
    pub const IS_MUT = true;
    pub const AccountType = signer_mod.SignerMut;
};

/// Program account marker.
pub fn Prog(comptime program_id: PublicKey) type {
    return struct {
        pub const IS_PROGRAM = true;
        pub const ID = program_id;
        pub const AccountType = program_mod.Program(program_id);
    };
}

/// Unchecked account marker.
pub const Unchecked = struct {
    pub const IS_UNCHECKED = true;
    pub const AccountType = *const AccountInfo;
};

// ============================================================================
// Data Account with Type-Safe Config
// ============================================================================

/// Data account configuration.
pub fn DataConfig(comptime AccountsType: type) type {
    const Fields = std.meta.FieldEnum(AccountsType);
    return struct {
        /// Account must be writable
        mut: bool = false,
        /// Expected owner (as field reference)
        owner: ?Fields = null,
        /// Expected owner (as PublicKey)
        owner_key: ?PublicKey = null,
        /// Custom constraint expression
        constraint: ?[]const u8 = null,
        /// PDA seeds
        seeds: ?[]const SeedSpec = null,
        /// Store bump
        bump: bool = false,
    };
}

/// Data account marker with type-safe configuration.
pub fn Data(comptime T: type, comptime config: anytype) type {
    return struct {
        pub const IS_DATA = true;
        pub const DataType = T;
        pub const CONFIG = config;

        pub fn AccountType(comptime AccountsType: type) type {
            const disc_name = if (@hasField(@TypeOf(config), "name"))
                config.name
            else
                @typeName(T);
            const discriminator = discriminator_mod.accountDiscriminator(disc_name);

            const owner_key: ?PublicKey = blk: {
                if (@hasField(@TypeOf(config), "owner_key") and config.owner_key != null) {
                    break :blk config.owner_key;
                }
                if (@hasField(@TypeOf(config), "owner") and config.owner != null) {
                    // Resolve from field - get program ID from field type
                    const field_name = @tagName(config.owner.?);
                    const field_idx = std.meta.fieldIndex(AccountsType, field_name) orelse
                        @compileError("owner field not found: " ++ field_name);
                    const FieldType = @typeInfo(AccountsType).@"struct".fields[field_idx].type;
                    if (@hasDecl(FieldType, "ID")) {
                        break :blk FieldType.ID;
                    }
                    @compileError("owner field must have ID: " ++ field_name);
                }
                break :blk null;
            };

            return account_mod.Account(T, .{
                .discriminator = discriminator,
                .mut = if (@hasField(@TypeOf(config), "mut")) config.mut else false,
                .owner = owner_key,
                .constraint = if (@hasField(@TypeOf(config), "constraint")) config.constraint else null,
                .seeds = if (@hasField(@TypeOf(config), "seeds")) config.seeds else null,
                .bump = if (@hasField(@TypeOf(config), "bump")) config.bump else false,
            });
        }
    };
}

// ============================================================================
// Init Account with Type-Safe Payer Reference
// ============================================================================

/// Init account marker with type-safe payer reference.
pub fn Init(comptime T: type, comptime config: anytype) type {
    return struct {
        pub const IS_INIT = true;
        pub const DataType = T;
        pub const CONFIG = config;

        pub fn AccountType(comptime AccountsType: type) type {
            // Validate payer field exists
            const payer_name = comptime blk: {
                if (@hasField(@TypeOf(config), "payer")) {
                    break :blk resolveFieldRef(config.payer);
                }
                @compileError("Init requires .payer field");
            };

            // Verify payer field exists in Accounts
            if (!@hasField(AccountsType, payer_name)) {
                @compileError("payer field '" ++ payer_name ++ "' not found in Accounts");
            }

            const disc_name = if (@hasField(@TypeOf(config), "name"))
                config.name
            else
                @typeName(T);
            const discriminator = discriminator_mod.accountDiscriminator(disc_name);
            const default_space = discriminator_mod.DISCRIMINATOR_LENGTH + @sizeOf(T);

            return account_mod.Account(T, .{
                .discriminator = discriminator,
                .mut = true,
                .init = if (@hasField(@TypeOf(config), "if_needed")) !config.if_needed else true,
                .init_if_needed = if (@hasField(@TypeOf(config), "if_needed")) config.if_needed else false,
                .payer = payer_name,
                .space = if (@hasField(@TypeOf(config), "space")) config.space else default_space,
                .seeds = if (@hasField(@TypeOf(config), "seeds")) config.seeds else null,
                .bump = if (@hasField(@TypeOf(config), "bump")) config.bump else false,
                .zero = true,
            });
        }
    };
}

// ============================================================================
// PDA Account with Type-Safe Seeds
// ============================================================================

/// PDA account marker.
pub fn PDA(comptime T: type, comptime config: anytype) type {
    return struct {
        pub const IS_PDA = true;
        pub const DataType = T;
        pub const CONFIG = config;

        pub fn AccountType(comptime AccountsType: type) type {
            _ = AccountsType;
            const disc_name = if (@hasField(@TypeOf(config), "name"))
                config.name
            else
                @typeName(T);
            const discriminator = discriminator_mod.accountDiscriminator(disc_name);

            return account_mod.Account(T, .{
                .discriminator = discriminator,
                .mut = if (@hasField(@TypeOf(config), "mut")) config.mut else false,
                .seeds = config.seeds,
                .bump = if (@hasField(@TypeOf(config), "bump")) config.bump else false,
                .bump_field = if (@hasField(@TypeOf(config), "bump_field")) config.bump_field else null,
            });
        }
    };
}

// ============================================================================
// Close Account with Type-Safe Destination
// ============================================================================

/// Close account marker.
pub fn Close(comptime T: type, comptime config: anytype) type {
    return struct {
        pub const IS_CLOSE = true;
        pub const DataType = T;
        pub const CONFIG = config;

        pub fn AccountType(comptime AccountsType: type) type {
            const dest_name = comptime blk: {
                if (@hasField(@TypeOf(config), "destination")) {
                    break :blk resolveFieldRef(config.destination);
                }
                @compileError("Close requires .destination field");
            };

            if (!@hasField(AccountsType, dest_name)) {
                @compileError("destination field '" ++ dest_name ++ "' not found in Accounts");
            }

            const disc_name = if (@hasField(@TypeOf(config), "name"))
                config.name
            else
                @typeName(T);
            const discriminator = discriminator_mod.accountDiscriminator(disc_name);

            return account_mod.Account(T, .{
                .discriminator = discriminator,
                .mut = true,
                .close = dest_name,
            });
        }
    };
}

// ============================================================================
// Token Accounts
// ============================================================================

/// Token account data.
pub const TokenAccountData = extern struct {
    mint: PublicKey,
    owner: PublicKey,
    amount: u64,
    delegate: ?PublicKey,
    state: u8,
    is_native: ?u64,
    delegated_amount: u64,
    close_authority: ?PublicKey,
};

const TOKEN_DISCRIMINATOR = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 };

/// Token account marker.
pub fn Token(comptime config: anytype) type {
    return struct {
        pub const IS_TOKEN = true;
        pub const CONFIG = config;

        pub fn AccountType(comptime AccountsType: type) type {
            const mint_name = resolveFieldRef(config.mint);
            const authority_name = resolveFieldRef(config.authority);

            if (!@hasField(AccountsType, mint_name)) {
                @compileError("mint field '" ++ mint_name ++ "' not found in Accounts");
            }
            if (!@hasField(AccountsType, authority_name)) {
                @compileError("authority field '" ++ authority_name ++ "' not found in Accounts");
            }

            return account_mod.Account(TokenAccountData, .{
                .discriminator = TOKEN_DISCRIMINATOR,
                .mut = if (@hasField(@TypeOf(config), "mut")) config.mut else false,
                .token_mint = mint_name,
                .token_authority = authority_name,
            });
        }
    };
}

/// Mint account data.
pub const MintData = extern struct {
    mint_authority: ?PublicKey,
    supply: u64,
    decimals: u8,
    is_initialized: bool,
    freeze_authority: ?PublicKey,
};

/// Mint account marker.
pub fn Mint(comptime config: anytype) type {
    return struct {
        pub const IS_MINT = true;
        pub const CONFIG = config;

        pub fn AccountType(comptime AccountsType: type) type {
            const authority_name = resolveFieldRef(config.authority);

            if (!@hasField(AccountsType, authority_name)) {
                @compileError("authority field '" ++ authority_name ++ "' not found in Accounts");
            }

            return account_mod.Account(MintData, .{
                .discriminator = TOKEN_DISCRIMINATOR,
                .mut = if (@hasField(@TypeOf(config), "mut")) config.mut else false,
                .mint_authority = authority_name,
                .mint_decimals = if (@hasField(@TypeOf(config), "decimals")) config.decimals else null,
            });
        }
    };
}

/// ATA account marker.
pub fn ATA(comptime config: anytype) type {
    return struct {
        pub const IS_ATA = true;
        pub const CONFIG = config;

        pub fn AccountType(comptime AccountsType: type) type {
            const mint_name = resolveFieldRef(config.mint);
            const authority_name = resolveFieldRef(config.authority);

            if (!@hasField(AccountsType, mint_name)) {
                @compileError("mint field '" ++ mint_name ++ "' not found in Accounts");
            }
            if (!@hasField(AccountsType, authority_name)) {
                @compileError("authority field '" ++ authority_name ++ "' not found in Accounts");
            }

            const payer_name = if (@hasField(@TypeOf(config), "payer"))
                resolveFieldRefOpt(config.payer)
            else
                null;

            return account_mod.Account(TokenAccountData, .{
                .discriminator = TOKEN_DISCRIMINATOR,
                .mut = if (@hasField(@TypeOf(config), "mut")) config.mut else false,
                .associated_token = .{
                    .mint = mint_name,
                    .authority = authority_name,
                    .token_program = null,
                },
                .init = if (@hasField(@TypeOf(config), "init")) config.init else false,
                .payer = payer_name,
            });
        }
    };
}

// ============================================================================
// Realloc Account - Dynamic Resizing
// ============================================================================

/// Realloc account marker for dynamic resizing.
pub fn Realloc(comptime T: type, comptime config: anytype) type {
    return struct {
        pub const IS_REALLOC = true;
        pub const DataType = T;
        pub const CONFIG = config;

        pub fn AccountType(comptime AccountsType: type) type {
            const payer_name = if (@hasField(@TypeOf(config), "payer"))
                resolveFieldRefOpt(config.payer)
            else
                null;

            if (payer_name) |name| {
                if (!@hasField(AccountsType, name)) {
                    @compileError("payer field '" ++ name ++ "' not found in Accounts");
                }
            }

            const disc_name = if (@hasField(@TypeOf(config), "name"))
                config.name
            else
                @typeName(T);
            const discriminator = discriminator_mod.accountDiscriminator(disc_name);

            const realloc_config = if (payer_name) |name| blk: {
                break :blk @import("realloc.zig").ReallocConfig{
                    .payer = name,
                    .zero_init = if (@hasField(@TypeOf(config), "zero_init")) config.zero_init else false,
                };
            } else null;

            return account_mod.Account(T, .{
                .discriminator = discriminator,
                .mut = true,
                .realloc = realloc_config,
                .space = if (@hasField(@TypeOf(config), "space")) config.space else null,
            });
        }
    };
}

// ============================================================================
// Optional Account Wrapper
// ============================================================================

/// Optional account that may or may not be present.
///
/// Usage:
/// ```zig
/// .co_signer = Opt(Signer),
/// .config = Opt(Data(ConfigData, .{})),
/// ```
pub fn Opt(comptime MarkerType: type) type {
    return struct {
        pub const IS_OPTIONAL = true;
        pub const InnerType = MarkerType;

        pub fn AccountType(comptime AccountsType: type) type {
            const InnerAccountType = resolveMarkerType(MarkerType, AccountsType);
            return ?InnerAccountType;
        }
    };
}

// ============================================================================
// System Account - Lamport-only Account
// ============================================================================

/// System-owned account (no data, just lamports).
pub const SystemAccount = struct {
    pub const IS_SYSTEM = true;
    pub const IS_MUT = false;
    pub const AccountType = *const AccountInfo;
};

/// Mutable system account.
pub const SystemAccountMut = struct {
    pub const IS_SYSTEM = true;
    pub const IS_MUT = true;
    pub const AccountType = signer_mod.SignerMut;
};

// ============================================================================
// Seed Helpers (Type-Safe)
// ============================================================================

/// Literal seed.
pub fn seed(comptime literal: []const u8) SeedSpec {
    return .{ .literal = literal };
}

/// Account field seed (type-safe).
pub fn seedFrom(comptime field: anytype) SeedSpec {
    return .{ .account = resolveFieldRef(field) };
}

/// Data field seed.
pub fn seedData(comptime field: []const u8) SeedSpec {
    return .{ .field = field };
}

/// Bump seed marker.
pub fn seedBump(comptime field: anytype) SeedSpec {
    return .{ .bump = resolveFieldRef(field) };
}

// ============================================================================
// Constraint Helpers
// ============================================================================

/// Build a constraint expression string.
pub fn constraint(comptime expr: []const u8) []const u8 {
    return expr;
}

/// Has-one constraint shorthand (field == field).
pub fn hasOne(comptime field: anytype) []const u8 {
    const name = resolveFieldRef(field);
    return name ++ " == " ++ name;
}

/// Build has_one constraint list.
pub fn hasOneList(comptime fields: anytype) []const has_one_mod.HasOneSpec {
    const fields_arr = if (@TypeOf(fields) == []const []const u8)
        fields
    else blk: {
        // Convert enum literals to strings
        comptime var names: [fields.len][]const u8 = undefined;
        inline for (fields, 0..) |f, i| {
            names[i] = resolveFieldRef(f);
        }
        break :blk &names;
    };

    comptime var specs: [fields_arr.len]has_one_mod.HasOneSpec = undefined;
    inline for (fields_arr, 0..) |field, i| {
        specs[i] = .{ .field = field, .target = field };
    }
    return specs[0..];
}

/// Build has_one constraint with different target.
pub fn hasOneTarget(comptime field: anytype, comptime target: anytype) has_one_mod.HasOneSpec {
    return .{
        .field = resolveFieldRef(field),
        .target = resolveFieldRef(target),
    };
}

// ============================================================================
// Convenience Type Aliases
// ============================================================================

/// Read-only data account (shorthand).
pub fn ReadOnly(comptime T: type) type {
    return Data(T, .{});
}

/// Mutable data account (shorthand).
pub fn Mut(comptime T: type) type {
    return Data(T, .{ .mut = true });
}

/// Mutable PDA account (shorthand).
pub fn MutPDA(comptime T: type, comptime seeds: []const SeedSpec) type {
    return PDA(T, .{ .seeds = seeds, .mut = true });
}

// ============================================================================
// Accounts Builder - Transforms DSL markers to real types
// ============================================================================

/// Build actual Accounts struct from DSL markers.
pub fn Accounts(comptime spec: anytype) type {
    const SpecType = @TypeOf(spec);
    const spec_fields = @typeInfo(SpecType).@"struct".fields;

    // First pass: create intermediate type to get field names
    const IntermediateFields = comptime blk: {
        var fields: [spec_fields.len]std.builtin.Type.StructField = undefined;
        for (spec_fields, 0..) |field, i| {
            const MarkerType = field.type;
            const ActualType = resolveMarkerType(MarkerType, SpecType);
            fields[i] = .{
                .name = field.name,
                .type = ActualType,
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            };
        }
        break :blk fields;
    };

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &IntermediateFields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

fn resolveMarkerType(comptime MarkerType: type, comptime AccountsSpec: type) type {
    // Direct account types
    if (MarkerType == Signer) return signer_mod.Signer;
    if (MarkerType == SignerMut) return signer_mod.SignerMut;
    if (MarkerType == Unchecked) return *const AccountInfo;
    if (MarkerType == SystemAccount) return *const AccountInfo;
    if (MarkerType == SystemAccountMut) return signer_mod.SignerMut;

    // Program type
    if (@hasDecl(MarkerType, "IS_PROGRAM") and MarkerType.IS_PROGRAM) {
        return MarkerType.AccountType;
    }

    // Optional type
    if (@hasDecl(MarkerType, "IS_OPTIONAL") and MarkerType.IS_OPTIONAL) {
        const ActualAccountsType = buildAccountsTypeForValidation(AccountsSpec);
        return MarkerType.AccountType(ActualAccountsType);
    }

    // Types with AccountType function
    if (@hasDecl(MarkerType, "AccountType")) {
        // For Data, Init, PDA, Close, Token, Mint, ATA, Realloc
        // We need to build the actual Accounts type first to validate
        const ActualAccountsType = buildAccountsTypeForValidation(AccountsSpec);
        return MarkerType.AccountType(ActualAccountsType);
    }

    @compileError("Unknown account marker type");
}

fn buildAccountsTypeForValidation(comptime AccountsSpec: type) type {
    // Build a simple struct with just field names for validation
    const spec_fields = @typeInfo(AccountsSpec).@"struct".fields;

    const ValidationFields = comptime blk: {
        var fields: [spec_fields.len]std.builtin.Type.StructField = undefined;
        for (spec_fields, 0..) |field, i| {
            // Use a placeholder type - we just need field names
            fields[i] = .{
                .name = field.name,
                .type = void,
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            };
        }
        break :blk fields;
    };

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &ValidationFields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

// ============================================================================
// Instruction Definition
// ============================================================================

/// Define a type-safe instruction.
///
/// Usage:
/// ```zig
/// const Initialize = Instr("initialize",
///     Accounts(.{
///         .payer = SignerMut,
///         .counter = Init(CounterData, .{ .payer = .payer }),
///     }),
///     struct { initial_value: u64 },
/// );
/// ```
pub fn Instr(
    comptime name: []const u8,
    comptime AccountsType: type,
    comptime ArgsType: type,
) type {
    return struct {
        pub const instruction_name = name;
        pub const Accs = AccountsType;
        pub const Args = ArgsType;
        pub const Ctx = context_mod.Context(AccountsType);
        pub const discriminator = discriminator_mod.instructionDiscriminator(name);

        /// Check if data matches this instruction's discriminator.
        pub fn matches(data: []const u8) bool {
            if (data.len < discriminator_mod.DISCRIMINATOR_LENGTH) return false;
            return std.mem.eql(u8, data[0..discriminator_mod.DISCRIMINATOR_LENGTH], &discriminator);
        }
    };
}

/// Instruction with no arguments.
pub fn InstrNoArgs(
    comptime name: []const u8,
    comptime AccountsType: type,
) type {
    return Instr(name, AccountsType, void);
}

// ============================================================================
// Tests
// ============================================================================

test "resolveFieldRef with enum literal" {
    const name1 = resolveFieldRef(.payer);
    const name2 = resolveFieldRef("authority");

    try std.testing.expectEqualStrings("payer", name1);
    try std.testing.expectEqualStrings("authority", name2);
}

test "resolveFieldRefOpt with null" {
    const name1 = resolveFieldRefOpt(null);
    const name2 = resolveFieldRefOpt(.payer);

    try std.testing.expect(name1 == null);
    try std.testing.expectEqualStrings("payer", name2.?);
}

test "Signer markers" {
    try std.testing.expect(Signer.IS_SIGNER == true);
    try std.testing.expect(Signer.IS_MUT == false);
    try std.testing.expect(SignerMut.IS_SIGNER == true);
    try std.testing.expect(SignerMut.IS_MUT == true);
}

test "Prog marker" {
    const TestProg = Prog(sol.system_program.ID);
    try std.testing.expect(TestProg.IS_PROGRAM == true);
    try std.testing.expect(TestProg.ID.equals(sol.system_program.ID));
}

test "seed helpers" {
    const s1 = seed("prefix");
    const s2 = seedFrom(.authority);
    const s3 = seedData("user_id");

    try std.testing.expect(s1 == .literal);
    try std.testing.expect(s2 == .account);
    try std.testing.expect(s3 == .field);
}

test "Data marker" {
    const TestData = struct { value: u64 };
    const DataMarker = Data(TestData, .{ .mut = true });

    try std.testing.expect(DataMarker.IS_DATA == true);
    try std.testing.expect(DataMarker.DataType == TestData);
}

test "Init marker" {
    const TestData = struct { value: u64 };
    const InitMarker = Init(TestData, .{ .payer = .payer });

    try std.testing.expect(InitMarker.IS_INIT == true);
    try std.testing.expect(InitMarker.DataType == TestData);
}

test "Accounts builder with Signer" {
    const TestAccounts = Accounts(.{
        .payer = SignerMut,
        .authority = Signer,
    });

    const fields = @typeInfo(TestAccounts).@"struct".fields;
    try std.testing.expect(fields.len == 2);
    try std.testing.expectEqualStrings("payer", fields[0].name);
    try std.testing.expectEqualStrings("authority", fields[1].name);
}

test "Instr definition" {
    const TestAccounts = Accounts(.{
        .payer = SignerMut,
    });

    const TestInstr = Instr("test", TestAccounts, struct { value: u64 });

    try std.testing.expectEqualStrings("test", TestInstr.instruction_name);
    try std.testing.expect(TestInstr.Accs == TestAccounts);
}

test "SystemAccount markers" {
    try std.testing.expect(SystemAccount.IS_SYSTEM == true);
    try std.testing.expect(SystemAccount.IS_MUT == false);
    try std.testing.expect(SystemAccountMut.IS_SYSTEM == true);
    try std.testing.expect(SystemAccountMut.IS_MUT == true);
}

test "Opt marker" {
    const OptSigner = Opt(Signer);
    try std.testing.expect(OptSigner.IS_OPTIONAL == true);
}

test "constraint helper" {
    const expr = constraint("account.owner == authority");
    try std.testing.expectEqualStrings("account.owner == authority", expr);
}

test "hasOne helper" {
    const expr = hasOne(.authority);
    try std.testing.expectEqualStrings("authority == authority", expr);
}

test "hasOneTarget helper" {
    const spec = hasOneTarget(.owner, .authority);
    try std.testing.expectEqualStrings("owner", spec.field);
    try std.testing.expectEqualStrings("authority", spec.target);
}

test "ReadOnly and Mut shortcuts" {
    const TestData = struct { value: u64 };

    const ROMarker = ReadOnly(TestData);
    const MutMarker = Mut(TestData);

    try std.testing.expect(ROMarker.IS_DATA == true);
    try std.testing.expect(MutMarker.IS_DATA == true);
}

test "Realloc marker" {
    const TestData = struct { value: u64 };
    const ReallocMarker = Realloc(TestData, .{ .payer = .payer, .space = 256 });

    try std.testing.expect(ReallocMarker.IS_REALLOC == true);
    try std.testing.expect(ReallocMarker.DataType == TestData);
}

test "Accounts with SystemAccount" {
    const TestAccounts = Accounts(.{
        .payer = SignerMut,
        .recipient = SystemAccount,
    });

    const fields = @typeInfo(TestAccounts).@"struct".fields;
    try std.testing.expect(fields.len == 2);
}
