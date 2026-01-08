//! Zig implementation of Anchor Context
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/src/context.rs
//!
//! Context provides the instruction context for Anchor programs. It wraps
//! the parsed accounts struct and provides access to the program ID and
//! any remaining accounts not defined in the accounts struct.
//!
//! ## Example
//! ```zig
//! const MyAccounts = struct {
//!     authority: anchor.Signer,
//!     counter: anchor.Account(Counter, .{ .discriminator = ... }),
//! };
//!
//! fn initialize(ctx: anchor.Context(MyAccounts), initial_value: u64) !void {
//!     ctx.accounts.counter.data.value = initial_value;
//!     ctx.accounts.counter.data.authority = ctx.accounts.authority.key().*;
//! }
//! ```

const std = @import("std");
const seeds_mod = @import("seeds.zig");

// Import from parent SDK
const sdk_account = @import("../account.zig");
const PublicKey = @import("../public_key.zig").PublicKey;

const AccountInfo = sdk_account.Account.Info;
const SeedSpec = seeds_mod.SeedSpec;

/// Bump seeds storage for PDA accounts
///
/// Stores bump seeds discovered during account loading.
/// Keys are account field names, values are bump seeds.
pub const Bumps = struct {
    /// Storage for bump seeds (field name hash -> bump)
    data: [MAX_BUMPS]BumpEntry = undefined,
    len: usize = 0,

    const MAX_BUMPS = 16;

    const BumpEntry = struct {
        name_hash: u64,
        bump: u8,
    };

    /// Get bump seed for a field name
    pub fn get(self: *const Bumps, comptime name: []const u8) ?u8 {
        const hash = comptime hashName(name);
        for (self.data[0..self.len]) |entry| {
            if (entry.name_hash == hash) {
                return entry.bump;
            }
        }
        return null;
    }

    /// Set bump seed for a field name
    pub fn set(self: *Bumps, comptime name: []const u8, bump: u8) void {
        const hash = comptime hashName(name);

        // Check if already exists
        for (self.data[0..self.len]) |*entry| {
            if (entry.name_hash == hash) {
                entry.bump = bump;
                return;
            }
        }

        // Add new entry
        if (self.len < MAX_BUMPS) {
            self.data[self.len] = .{
                .name_hash = hash,
                .bump = bump,
            };
            self.len += 1;
        }
    }

    /// Get bump seed by runtime key (hash value)
    ///
    /// Use this when the field name is not known at compile time.
    pub fn getByKey(self: *const Bumps, key: u64) ?u8 {
        for (self.data[0..self.len]) |entry| {
            if (entry.name_hash == key) {
                return entry.bump;
            }
        }
        return null;
    }

    /// Set bump seed by runtime key (hash value)
    pub fn setByKey(self: *Bumps, key: u64, bump: u8) void {
        // Check if already exists
        for (self.data[0..self.len]) |*entry| {
            if (entry.name_hash == key) {
                entry.bump = bump;
                return;
            }
        }

        // Add new entry
        if (self.len < MAX_BUMPS) {
            self.data[self.len] = .{
                .name_hash = key,
                .bump = bump,
            };
            self.len += 1;
        }
    }

    /// Get the number of stored bumps
    pub fn count(self: *const Bumps) usize {
        return self.len;
    }

    /// Check if a bump exists for a field name
    pub fn contains(self: *const Bumps, comptime name: []const u8) bool {
        return self.get(name) != null;
    }

    /// Simple hash for field name lookup
    fn hashName(comptime name: []const u8) u64 {
        comptime {
            var hash: u64 = 0;
            for (name) |c| {
                hash = hash *% 31 +% c;
            }
            return hash;
        }
    }

    /// Runtime hash for field name lookup
    pub fn hashNameRuntime(name: []const u8) u64 {
        var hash: u64 = 0;
        for (name) |c| {
            hash = hash *% 31 +% c;
        }
        return hash;
    }
};

/// Instruction context for Anchor programs
///
/// Provides type-safe access to parsed accounts and program metadata.
///
/// Type Parameters:
/// - `Accounts`: Struct type defining the expected accounts
///
/// Anchor equivalent: `Context<'_, '_, '_, 'info, T>`
pub fn Context(comptime Accounts: type) type {
    return struct {
        const Self = @This();

        /// Parsed and validated accounts
        accounts: Accounts,

        /// Program ID of the executing program
        program_id: *const PublicKey,

        /// Accounts not defined in the Accounts struct
        ///
        /// Used for dynamic account access (e.g., variable number of accounts)
        remaining_accounts: []const AccountInfo,

        /// Bump seeds for PDA accounts
        ///
        /// Populated when loading accounts with seeds constraints
        bumps: Bumps,

        /// Create a new context
        ///
        /// This is typically called by the framework, not user code.
        pub fn new(
            accounts: Accounts,
            program_id: *const PublicKey,
            remaining_accounts: []const AccountInfo,
            bumps: Bumps,
        ) Self {
            return Self{
                .accounts = accounts,
                .program_id = program_id,
                .remaining_accounts = remaining_accounts,
                .bumps = bumps,
            };
        }

        /// Create context with only accounts (no remaining accounts)
        pub fn fromAccounts(
            accounts: Accounts,
            program_id: *const PublicKey,
        ) Self {
            return Self{
                .accounts = accounts,
                .program_id = program_id,
                .remaining_accounts = &[_]AccountInfo{},
                .bumps = Bumps{},
            };
        }

        /// Get a specific bump seed by field name
        ///
        /// Returns null if the field has no associated bump.
        pub fn getBump(self: *const Self, comptime field_name: []const u8) ?u8 {
            return self.bumps.get(field_name);
        }
    };
}

/// Result of loading accounts with PDA validation
pub const LoadAccountsResult = struct {
    fn AccountsType(comptime Accounts: type) type {
        return struct {
            accounts: Accounts,
            bumps: Bumps,
        };
    }
};

/// Load accounts from account info slice
///
/// Iterates over struct fields and loads each account type.
/// This is the core deserialization logic for instruction contexts.
///
/// Note: This basic version does NOT validate PDA seeds. For PDA validation,
/// use `loadAccountsWithPda` which requires a program_id.
///
/// Example:
/// ```zig
/// const accounts = try loadAccounts(MyAccounts, account_infos);
/// ```
pub fn loadAccounts(comptime Accounts: type, infos: []const AccountInfo) !Accounts {
    const fields = @typeInfo(Accounts).@"struct".fields;

    if (infos.len < fields.len) {
        return error.AccountNotEnoughAccountKeys;
    }

    var accounts: Accounts = undefined;

    inline for (fields, 0..) |field, i| {
        const FieldType = field.type;
        const info = &infos[i];

        // Check if field type has a load function
        if (@hasDecl(FieldType, "load")) {
            @field(accounts, field.name) = try FieldType.load(info);
        } else {
            // For raw AccountInfo pointers
            @field(accounts, field.name) = info;
        }
    }

    return accounts;
}

/// Load accounts with PDA validation for literal-only seeds
///
/// For each account type with HAS_SEEDS and literal-only seeds,
/// validates the PDA address and stores the bump in the returned Bumps.
///
/// For accounts with seedAccount/seedField references, you must call
/// loadWithPda manually after loading the referenced accounts.
///
/// Example:
/// ```zig
/// const result = try loadAccountsWithPda(MyAccounts, &program_id, account_infos);
/// const accounts = result.accounts;
/// const bumps = result.bumps;
/// ```
pub fn loadAccountsWithPda(
    comptime Accounts: type,
    program_id: *const PublicKey,
    infos: []const AccountInfo,
) !struct { accounts: Accounts, bumps: Bumps } {
    const fields = @typeInfo(Accounts).@"struct".fields;

    if (infos.len < fields.len) {
        return error.AccountNotEnoughAccountKeys;
    }

    var accounts: Accounts = undefined;
    var bumps = Bumps{};

    inline for (fields, 0..) |field, i| {
        const FieldType = field.type;
        const info = &infos[i];

        // Check if this field type has PDA seeds
        if (@hasDecl(FieldType, "HAS_SEEDS") and FieldType.HAS_SEEDS) {
            // Check if all seeds are literals (can be resolved at compile time)
            if (@hasDecl(FieldType, "SEEDS")) {
                if (FieldType.SEEDS) |seed_specs| {
                    if (seeds_mod.areAllLiteralSeeds(seed_specs)) {
                        // Resolve literal seeds at comptime
                        const resolved_seeds = seeds_mod.resolveComptimeSeeds(seed_specs);

                        // Load with PDA validation
                        if (@hasDecl(FieldType, "loadWithPda")) {
                            const result = try FieldType.loadWithPda(info, resolved_seeds, program_id);
                            @field(accounts, field.name) = result.account;
                            bumps.set(field.name, result.bump);
                        } else {
                            @field(accounts, field.name) = try FieldType.load(info);
                        }
                    } else {
                        // Non-literal seeds: load without PDA validation
                        // User must call loadWithPda manually with resolved seeds
                        if (@hasDecl(FieldType, "load")) {
                            @field(accounts, field.name) = try FieldType.load(info);
                        } else {
                            @field(accounts, field.name) = info;
                        }
                    }
                } else {
                    // No seeds defined, normal load
                    if (@hasDecl(FieldType, "load")) {
                        @field(accounts, field.name) = try FieldType.load(info);
                    } else {
                        @field(accounts, field.name) = info;
                    }
                }
            } else {
                // No SEEDS constant, normal load
                if (@hasDecl(FieldType, "load")) {
                    @field(accounts, field.name) = try FieldType.load(info);
                } else {
                    @field(accounts, field.name) = info;
                }
            }
        } else if (@hasDecl(FieldType, "load")) {
            // No PDA seeds, normal load
            @field(accounts, field.name) = try FieldType.load(info);
        } else {
            // For raw AccountInfo pointers
            @field(accounts, field.name) = info;
        }
    }

    return .{ .accounts = accounts, .bumps = bumps };
}

/// Parse full context from program inputs
///
/// This is the main entry point for instruction handling.
/// Parses accounts, validates PDAs (for literal-only seeds), and creates the full context.
///
/// For accounts with HAS_SEEDS and literal-only seeds, PDA validation is
/// performed automatically and bumps are stored in ctx.bumps.
///
/// For accounts with seedAccount/seedField references, you must:
/// 1. Use parseContextBasic() to skip PDA validation
/// 2. Manually validate PDAs using account.loadWithPda() with resolved seeds
///
/// Example:
/// ```zig
/// pub fn processInstruction(
///     program_id: *const PublicKey,
///     accounts: []const AccountInfo,
///     _: []const u8,
/// ) !void {
///     const ctx = try parseContext(MyAccounts, program_id, accounts);
///     // Access bumps: ctx.bumps.get("counter")
/// }
/// ```
pub fn parseContext(
    comptime Accounts: type,
    program_id: *const PublicKey,
    infos: []const AccountInfo,
) !Context(Accounts) {
    const fields = @typeInfo(Accounts).@"struct".fields;

    // Load accounts with PDA validation for literal-only seeds
    const result = try loadAccountsWithPda(Accounts, program_id, infos);

    // Remaining accounts are those beyond the defined fields
    const remaining = if (infos.len > fields.len)
        infos[fields.len..]
    else
        &[_]AccountInfo{};

    return Context(Accounts).new(
        result.accounts,
        program_id,
        remaining,
        result.bumps,
    );
}

/// Parse context without PDA validation
///
/// Use this when you need manual control over PDA validation,
/// such as when seeds reference other accounts.
///
/// Example:
/// ```zig
/// const ctx = try parseContextBasic(MyAccounts, program_id, accounts);
/// // Manually validate PDA after loading referenced accounts
/// ```
pub fn parseContextBasic(
    comptime Accounts: type,
    program_id: *const PublicKey,
    infos: []const AccountInfo,
) !Context(Accounts) {
    const fields = @typeInfo(Accounts).@"struct".fields;

    const accounts = try loadAccounts(Accounts, infos);

    // Remaining accounts are those beyond the defined fields
    const remaining = if (infos.len > fields.len)
        infos[fields.len..]
    else
        &[_]AccountInfo{};

    return Context(Accounts).new(
        accounts,
        program_id,
        remaining,
        Bumps{},
    );
}

/// Account loading errors
pub const ContextError = error{
    AccountNotEnoughAccountKeys,
};

// ============================================================================
// Tests
// ============================================================================

const signer_mod = @import("signer.zig");
const Signer = signer_mod.Signer;

test "Context creation" {
    const TestAccounts = struct {
        authority: Signer,
    };

    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;

    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1,
        .is_writable = 0,
        .is_executable = 0,
    };

    const signer = try Signer.load(&info);
    var program_id = PublicKey.default();

    const ctx = Context(TestAccounts).fromAccounts(
        TestAccounts{ .authority = signer },
        &program_id,
    );

    try std.testing.expectEqual(&program_id, ctx.program_id);
    try std.testing.expectEqual(@as(usize, 0), ctx.remaining_accounts.len);
}

test "Bumps storage and retrieval" {
    var bumps = Bumps{};

    bumps.set("counter", 255);
    bumps.set("authority", 254);

    try std.testing.expectEqual(@as(?u8, 255), bumps.get("counter"));
    try std.testing.expectEqual(@as(?u8, 254), bumps.get("authority"));
    try std.testing.expectEqual(@as(?u8, null), bumps.get("unknown"));
}

test "loadAccounts parses struct fields" {
    const TestAccounts = struct {
        signer1: Signer,
        signer2: Signer,
    };

    var id1 = PublicKey.default();
    var id2 = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    var owner = PublicKey.default();
    var lamports1: u64 = 1000;
    var lamports2: u64 = 2000;

    const infos = [_]AccountInfo{
        AccountInfo{
            .id = &id1,
            .owner_id = &owner,
            .lamports = &lamports1,
            .data_len = 0,
            .data = undefined,
            .is_signer = 1,
            .is_writable = 0,
            .is_executable = 0,
        },
        AccountInfo{
            .id = &id2,
            .owner_id = &owner,
            .lamports = &lamports2,
            .data_len = 0,
            .data = undefined,
            .is_signer = 1,
            .is_writable = 0,
            .is_executable = 0,
        },
    };

    const accounts = try loadAccounts(TestAccounts, &infos);
    try std.testing.expectEqual(&id1, accounts.signer1.key());
    try std.testing.expectEqual(&id2, accounts.signer2.key());
}

test "loadAccounts fails with insufficient accounts" {
    const TestAccounts = struct {
        signer1: Signer,
        signer2: Signer,
    };

    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;

    const infos = [_]AccountInfo{
        AccountInfo{
            .id = &id,
            .owner_id = &owner,
            .lamports = &lamports,
            .data_len = 0,
            .data = undefined,
            .is_signer = 1,
            .is_writable = 0,
            .is_executable = 0,
        },
    };

    try std.testing.expectError(error.AccountNotEnoughAccountKeys, loadAccounts(TestAccounts, &infos));
}

test "parseContext includes remaining accounts" {
    const TestAccounts = struct {
        authority: Signer,
    };

    var id1 = PublicKey.default();
    var id2 = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    var program_id = PublicKey.default();

    const infos = [_]AccountInfo{
        AccountInfo{
            .id = &id1,
            .owner_id = &owner,
            .lamports = &lamports,
            .data_len = 0,
            .data = undefined,
            .is_signer = 1,
            .is_writable = 0,
            .is_executable = 0,
        },
        AccountInfo{
            .id = &id2,
            .owner_id = &owner,
            .lamports = &lamports,
            .data_len = 0,
            .data = undefined,
            .is_signer = 0,
            .is_writable = 0,
            .is_executable = 0,
        },
    };

    const ctx = try parseContext(TestAccounts, &program_id, &infos);

    try std.testing.expectEqual(@as(usize, 1), ctx.remaining_accounts.len);
    try std.testing.expectEqual(&id2, ctx.remaining_accounts[0].id);
}

// ============================================================================
// Phase 2: Enhanced Bumps Tests
// ============================================================================

test "Bumps getByKey and setByKey" {
    var bumps = Bumps{};

    const key1 = Bumps.hashNameRuntime("counter");
    const key2 = Bumps.hashNameRuntime("vault");

    bumps.setByKey(key1, 255);
    bumps.setByKey(key2, 254);

    try std.testing.expectEqual(@as(?u8, 255), bumps.getByKey(key1));
    try std.testing.expectEqual(@as(?u8, 254), bumps.getByKey(key2));
    try std.testing.expectEqual(@as(?u8, null), bumps.getByKey(12345));
}

test "Bumps count" {
    var bumps = Bumps{};

    try std.testing.expectEqual(@as(usize, 0), bumps.count());

    bumps.set("a", 1);
    try std.testing.expectEqual(@as(usize, 1), bumps.count());

    bumps.set("b", 2);
    try std.testing.expectEqual(@as(usize, 2), bumps.count());

    // Setting existing key doesn't increase count
    bumps.set("a", 3);
    try std.testing.expectEqual(@as(usize, 2), bumps.count());
}

test "Bumps contains" {
    var bumps = Bumps{};

    bumps.set("counter", 255);

    try std.testing.expect(bumps.contains("counter"));
    try std.testing.expect(!bumps.contains("unknown"));
}

test "Bumps hashNameRuntime matches comptime hash" {
    // The runtime hash should match the comptime hash for the same string
    const runtime_hash = Bumps.hashNameRuntime("counter");
    var bumps = Bumps{};
    bumps.set("counter", 42);

    // If they match, getByKey should find the value set by comptime set
    try std.testing.expectEqual(@as(?u8, 42), bumps.getByKey(runtime_hash));
}

test "Context getBump delegates to bumps" {
    const TestAccounts = struct {
        authority: Signer,
    };

    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    var program_id = PublicKey.default();

    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1,
        .is_writable = 0,
        .is_executable = 0,
    };

    const signer = try Signer.load(&info);

    var bumps = Bumps{};
    bumps.set("pda_account", 254);

    const ctx = Context(TestAccounts).new(
        TestAccounts{ .authority = signer },
        &program_id,
        &[_]AccountInfo{},
        bumps,
    );

    try std.testing.expectEqual(@as(?u8, 254), ctx.getBump("pda_account"));
    try std.testing.expectEqual(@as(?u8, null), ctx.getBump("unknown"));
}

test "loadAccountsWithPda returns accounts and empty bumps for non-PDA accounts" {
    const TestAccounts = struct {
        signer1: Signer,
        signer2: Signer,
    };

    var id1 = PublicKey.default();
    var id2 = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    var owner = PublicKey.default();
    var lamports1: u64 = 1000;
    var lamports2: u64 = 2000;
    var program_id = PublicKey.default();

    const infos = [_]AccountInfo{
        AccountInfo{
            .id = &id1,
            .owner_id = &owner,
            .lamports = &lamports1,
            .data_len = 0,
            .data = undefined,
            .is_signer = 1,
            .is_writable = 0,
            .is_executable = 0,
        },
        AccountInfo{
            .id = &id2,
            .owner_id = &owner,
            .lamports = &lamports2,
            .data_len = 0,
            .data = undefined,
            .is_signer = 1,
            .is_writable = 0,
            .is_executable = 0,
        },
    };

    const result = try loadAccountsWithPda(TestAccounts, &program_id, &infos);

    // Check accounts loaded correctly
    try std.testing.expectEqual(&id1, result.accounts.signer1.key());
    try std.testing.expectEqual(&id2, result.accounts.signer2.key());

    // Check no bumps for non-PDA accounts
    try std.testing.expectEqual(@as(usize, 0), result.bumps.count());
}

test "parseContextBasic creates context without PDA validation" {
    const TestAccounts = struct {
        authority: Signer,
    };

    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    var program_id = PublicKey.default();

    const infos = [_]AccountInfo{
        AccountInfo{
            .id = &id,
            .owner_id = &owner,
            .lamports = &lamports,
            .data_len = 0,
            .data = undefined,
            .is_signer = 1,
            .is_writable = 0,
            .is_executable = 0,
        },
    };

    const ctx = try parseContextBasic(TestAccounts, &program_id, &infos);

    try std.testing.expectEqual(&id, ctx.accounts.authority.key());
    try std.testing.expectEqual(&program_id, ctx.program_id);
    try std.testing.expectEqual(@as(usize, 0), ctx.bumps.count());
}

test "LoadAccountsResult type is properly defined" {
    // Verify LoadAccountsResult helper type can be used
    const ResultType = LoadAccountsResult.AccountsType(struct {
        signer: Signer,
    });

    try std.testing.expect(@hasField(ResultType, "accounts"));
    try std.testing.expect(@hasField(ResultType, "bumps"));
}
