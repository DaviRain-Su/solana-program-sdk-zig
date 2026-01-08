//! Zig implementation of Anchor Account wrapper
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/src/accounts/account.rs
//!
//! Account<T> is a wrapper that validates discriminators and provides
//! type-safe access to account data. It automatically checks the 8-byte
//! discriminator at the start of account data matches the expected value.
//!
//! ## Example
//! ```zig
//! const Counter = anchor.Account(struct {
//!     count: u64,
//!     authority: PublicKey,
//! }, .{
//!     .discriminator = anchor.accountDiscriminator("Counter"),
//! });
//!
//! // In instruction handler:
//! const counter = try Counter.load(&account_info);
//! counter.data.count += 1;
//! ```

const std = @import("std");
const discriminator_mod = @import("discriminator.zig");
const anchor_error = @import("error.zig");
const constraints_mod = @import("constraints.zig");
const seeds_mod = @import("seeds.zig");
const pda_mod = @import("pda.zig");

// Import from parent SDK
const sdk_account = @import("../account.zig");
const public_key_mod = @import("../public_key.zig");
const PublicKey = public_key_mod.PublicKey;

const Discriminator = discriminator_mod.Discriminator;
const DISCRIMINATOR_LENGTH = discriminator_mod.DISCRIMINATOR_LENGTH;
const AnchorError = anchor_error.AnchorError;
const Constraints = constraints_mod.Constraints;
const AccountInfo = sdk_account.Account.Info;
const SeedSpec = seeds_mod.SeedSpec;
const PdaError = pda_mod.PdaError;

/// Configuration for Account wrapper
pub const AccountConfig = struct {
    /// 8-byte discriminator (required)
    ///
    /// Generate using `accountDiscriminator("AccountName")`
    discriminator: Discriminator,

    /// Expected owner program (optional)
    ///
    /// If specified, account must be owned by this program
    owner: ?PublicKey = null,

    /// Required space override (optional)
    ///
    /// If not specified, calculated as DISCRIMINATOR_LENGTH + @sizeOf(T)
    space: ?usize = null,

    // === Phase 2: PDA Support ===

    /// PDA seeds specification (optional)
    ///
    /// Specify seeds for PDA validation during account loading.
    /// Example: `.seeds = &.{ anchor.seed("counter"), anchor.seedAccount("authority") }`
    seeds: ?[]const SeedSpec = null,

    /// Store bump seed in account data (optional)
    ///
    /// When true, the bump seed will be stored and validated.
    /// Requires seeds to be specified.
    bump: bool = false,

    /// Initialize new account (optional)
    ///
    /// When true, the account will be created if it doesn't exist.
    /// Requires payer field to be specified.
    init: bool = false,

    /// Payer account field name (for init)
    ///
    /// Required when init is true. References a field in the Accounts struct
    /// that will pay for account creation.
    payer: ?[]const u8 = null,
};

/// Account wrapper with discriminator validation
///
/// Provides type-safe access to account data with automatic
/// discriminator verification on load.
///
/// Type Parameters:
/// - `T`: The account data struct type
/// - `config`: AccountConfig with discriminator and optional constraints
///
/// Example:
/// ```zig
/// const Counter = anchor.Account(struct {
///     count: u64,
///     authority: PublicKey,
/// }, .{ .discriminator = anchor.accountDiscriminator("Counter") });
/// ```
pub fn Account(comptime T: type, comptime config: AccountConfig) type {
    // Validate config at compile time
    comptime {
        if (config.bump and config.seeds == null) {
            @compileError("bump requires seeds to be specified");
        }
        if (config.init and config.payer == null) {
            @compileError("init requires payer to be specified");
        }
        if (config.seeds) |s| {
            seeds_mod.validateSeeds(s);
        }
    }

    return struct {
        const Self = @This();

        /// The discriminator for this account type
        pub const discriminator: Discriminator = config.discriminator;

        /// Required space: discriminator + data
        pub const SPACE: usize = config.space orelse (DISCRIMINATOR_LENGTH + @sizeOf(T));

        /// The inner data type
        pub const DataType = T;

        /// Whether this account type has PDA seeds
        pub const HAS_SEEDS: bool = config.seeds != null;

        /// Whether this account stores a bump seed
        pub const HAS_BUMP: bool = config.bump;

        /// Whether this account requires initialization
        pub const IS_INIT: bool = config.init;

        /// The seeds specification (if any)
        pub const SEEDS: ?[]const SeedSpec = config.seeds;

        /// The payer field name (if init is required)
        pub const PAYER: ?[]const u8 = config.payer;

        /// The account info from runtime
        info: *const AccountInfo,

        /// Typed access to account data (after discriminator)
        data: *T,

        /// Load and validate an account from AccountInfo
        ///
        /// Validates:
        /// - Account size is sufficient
        /// - Discriminator matches expected value
        /// - Owner matches (if specified in config)
        ///
        /// Returns error if validation fails.
        pub fn load(info: *const AccountInfo) !Self {
            // Check minimum size
            if (info.data_len < SPACE) {
                return error.AccountDiscriminatorNotFound;
            }

            // Validate discriminator
            const data_slice = info.data[0..DISCRIMINATOR_LENGTH];
            if (!std.mem.eql(u8, data_slice, &discriminator)) {
                return error.AccountDiscriminatorMismatch;
            }

            // Validate owner constraint if specified
            if (config.owner) |expected_owner| {
                if (!info.owner_id.equals(expected_owner)) {
                    return error.ConstraintOwner;
                }
            }

            // Get typed pointer to data (after discriminator)
            const data_ptr: *T = @ptrCast(@alignCast(info.data + DISCRIMINATOR_LENGTH));

            return Self{
                .info = info,
                .data = data_ptr,
            };
        }

        /// Load account without discriminator validation
        ///
        /// Use with caution - only for accounts where discriminator
        /// validation is handled elsewhere.
        pub fn loadUnchecked(info: *const AccountInfo) !Self {
            if (info.data_len < SPACE) {
                return error.AccountDiscriminatorNotFound;
            }

            const data_ptr: *T = @ptrCast(@alignCast(info.data + DISCRIMINATOR_LENGTH));

            return Self{
                .info = info,
                .data = data_ptr,
            };
        }

        /// Result of loading an account with PDA validation
        pub const LoadPdaResult = struct {
            account: Self,
            bump: u8,
        };

        /// Load and validate an account with PDA constraint
        ///
        /// Validates:
        /// - Account address matches expected PDA derived from seeds
        /// - Discriminator matches
        /// - Owner matches (if specified)
        ///
        /// Returns the account and the canonical bump seed.
        ///
        /// Example:
        /// ```zig
        /// const result = try Counter.loadWithPda(
        ///     &counter_info,
        ///     .{ "counter", &authority.bytes },
        ///     &program_id,
        /// );
        /// const counter = result.account;
        /// const bump = result.bump;
        /// ```
        pub fn loadWithPda(
            info: *const AccountInfo,
            seeds: anytype,
            program_id: *const PublicKey,
        ) !LoadPdaResult {
            // First validate PDA - this checks the address matches
            const bump = pda_mod.validatePda(info.id, seeds, program_id) catch {
                return error.ConstraintSeeds;
            };

            // Then do normal load (discriminator, owner checks)
            const account = try load(info);

            return LoadPdaResult{
                .account = account,
                .bump = bump,
            };
        }

        /// Load with PDA validation using known bump
        ///
        /// More efficient when bump is already known (e.g., stored in account data).
        /// Uses createProgramAddress instead of findProgramAddress.
        pub fn loadWithPdaBump(
            info: *const AccountInfo,
            seeds: anytype,
            bump: u8,
            program_id: *const PublicKey,
        ) !Self {
            // Validate PDA with known bump
            pda_mod.validatePdaWithBump(info.id, seeds, bump, program_id) catch {
                return error.ConstraintSeeds;
            };

            // Then do normal load
            return try load(info);
        }

        /// Check if this account type requires PDA validation
        pub fn requiresPdaValidation() bool {
            return HAS_SEEDS;
        }

        /// Check if this account type requires initialization
        pub fn requiresInit() bool {
            return IS_INIT;
        }

        /// Initialize a new account with discriminator
        ///
        /// Writes the discriminator and zero-initializes data.
        /// Use this when creating a new account.
        pub fn init(info: *const AccountInfo) !Self {
            if (info.data_len < SPACE) {
                return error.AccountDiscriminatorNotFound;
            }

            // Check account is writable
            if (info.is_writable == 0) {
                return error.ConstraintMut;
            }

            // Write discriminator
            @memcpy(info.data[0..DISCRIMINATOR_LENGTH], &discriminator);

            // Zero initialize data
            const data_ptr: *T = @ptrCast(@alignCast(info.data + DISCRIMINATOR_LENGTH));
            data_ptr.* = std.mem.zeroes(T);

            return Self{
                .info = info,
                .data = data_ptr,
            };
        }

        /// Get the public key of this account
        pub fn key(self: Self) *const PublicKey {
            return self.info.id;
        }

        /// Get the owner program of this account
        pub fn owner(self: Self) *const PublicKey {
            return self.info.owner_id;
        }

        /// Get the lamports balance
        pub fn lamports(self: Self) u64 {
            return self.info.lamports.*;
        }

        /// Check if account is writable
        pub fn isMut(self: Self) bool {
            return self.info.is_writable != 0;
        }

        /// Check if account is signer
        pub fn isSigner(self: Self) bool {
            return self.info.is_signer != 0;
        }

        /// Check if account is executable
        pub fn isExecutable(self: Self) bool {
            return self.info.is_executable != 0;
        }

        /// Get underlying account info
        pub fn toAccountInfo(self: Self) *const AccountInfo {
            return self.info;
        }

        /// Get raw data slice (including discriminator)
        pub fn rawData(self: Self) []u8 {
            return self.info.data[0..self.info.data_len];
        }
    };
}

/// Account load errors
pub const AccountError = error{
    AccountDiscriminatorNotFound,
    AccountDiscriminatorMismatch,
    ConstraintOwner,
    ConstraintMut,
    // Phase 2: PDA errors
    ConstraintSeeds,
    InvalidPda,
};

// ============================================================================
// Tests
// ============================================================================

const TestData = struct {
    value: u64,
    flag: bool,
};

const TestAccount = Account(TestData, .{
    .discriminator = discriminator_mod.accountDiscriminator("TestAccount"),
});

test "Account SPACE calculation" {
    // 8 bytes discriminator + 9 bytes data (u64 + bool)
    try std.testing.expectEqual(@as(usize, 8 + @sizeOf(TestData)), TestAccount.SPACE);
}

test "Account.load validates discriminator" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;

    // Create properly aligned data buffer with correct discriminator
    // Align to 8 bytes (u64 alignment) for TestData
    var data: [32]u8 align(@alignOf(TestData)) = undefined;
    @memcpy(data[0..8], &TestAccount.discriminator);

    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = data.len,
        .data = &data,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    const account = try TestAccount.load(&info);
    try std.testing.expectEqual(&id, account.key());
}

test "Account.load rejects wrong discriminator" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;

    // Create data buffer with wrong discriminator
    var data: [32]u8 = undefined;
    @memset(data[0..8], 0xFF);

    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = data.len,
        .data = &data,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    try std.testing.expectError(error.AccountDiscriminatorMismatch, TestAccount.load(&info));
}

test "Account.load rejects too small account" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;

    var data: [4]u8 = undefined; // Too small

    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = data.len,
        .data = &data,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    try std.testing.expectError(error.AccountDiscriminatorNotFound, TestAccount.load(&info));
}

test "Account.init writes discriminator" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;

    // Properly aligned data buffer
    var data: [32]u8 align(@alignOf(TestData)) = undefined;
    @memset(&data, 0);

    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = data.len,
        .data = &data,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    const account = try TestAccount.init(&info);

    // Check discriminator was written
    try std.testing.expectEqualSlices(u8, &TestAccount.discriminator, data[0..8]);

    // Check data was zero initialized
    try std.testing.expectEqual(@as(u64, 0), account.data.value);
    try std.testing.expectEqual(false, account.data.flag);
}

test "Account.init fails on non-writable" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;

    var data: [32]u8 = undefined;

    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = data.len,
        .data = &data,
        .is_signer = 0,
        .is_writable = 0, // Not writable
        .is_executable = 0,
    };

    try std.testing.expectError(error.ConstraintMut, TestAccount.init(&info));
}

test "Account with owner constraint" {
    // Use Token Program ID as expected owner - different from default (all zeros)
    const expected_owner = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");

    const OwnedAccount = Account(TestData, .{
        .discriminator = discriminator_mod.accountDiscriminator("OwnedAccount"),
        .owner = expected_owner,
    });

    var id = PublicKey.default();
    var wrong_owner = PublicKey.default(); // Different from expected_owner
    var lamports: u64 = 1000;

    // Properly aligned data buffer
    var data: [32]u8 align(@alignOf(TestData)) = undefined;
    @memcpy(data[0..8], &OwnedAccount.discriminator);

    const info = AccountInfo{
        .id = &id,
        .owner_id = &wrong_owner,
        .lamports = &lamports,
        .data_len = data.len,
        .data = &data,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    try std.testing.expectError(error.ConstraintOwner, OwnedAccount.load(&info));
}

// ============================================================================
// Phase 2: PDA Tests
// ============================================================================

test "Account with seeds has HAS_SEEDS true" {
    const PdaData = struct {
        value: u64,
        bump: u8,
    };

    const PdaAccount = Account(PdaData, .{
        .discriminator = discriminator_mod.accountDiscriminator("PdaAccount"),
        .seeds = &.{
            seeds_mod.seed("counter"),
        },
    });

    try std.testing.expect(PdaAccount.HAS_SEEDS);
    try std.testing.expect(!PdaAccount.HAS_BUMP);
    try std.testing.expect(!PdaAccount.IS_INIT);
}

test "Account without seeds has HAS_SEEDS false" {
    try std.testing.expect(!TestAccount.HAS_SEEDS);
    try std.testing.expect(!TestAccount.HAS_BUMP);
}

test "Account with bump has HAS_BUMP true" {
    const BumpData = struct {
        value: u64,
        bump: u8,
    };

    const BumpAccount = Account(BumpData, .{
        .discriminator = discriminator_mod.accountDiscriminator("BumpAccount"),
        .seeds = &.{
            seeds_mod.seed("counter"),
        },
        .bump = true,
    });

    try std.testing.expect(BumpAccount.HAS_SEEDS);
    try std.testing.expect(BumpAccount.HAS_BUMP);
}

test "Account SEEDS constant is accessible" {
    const SeedData = struct {
        value: u64,
    };

    const SeedAccount = Account(SeedData, .{
        .discriminator = discriminator_mod.accountDiscriminator("SeedAccount"),
        .seeds = &.{
            seeds_mod.seed("prefix"),
            seeds_mod.seedAccount("authority"),
        },
    });

    try std.testing.expect(SeedAccount.SEEDS != null);
    try std.testing.expectEqual(@as(usize, 2), SeedAccount.SEEDS.?.len);
}

test "Account with init has IS_INIT true" {
    const InitData = struct {
        value: u64,
    };

    const InitAccount = Account(InitData, .{
        .discriminator = discriminator_mod.accountDiscriminator("InitAccount"),
        .init = true,
        .payer = "payer",
    });

    try std.testing.expect(InitAccount.IS_INIT);
    try std.testing.expect(std.mem.eql(u8, InitAccount.PAYER.?, "payer"));
}

test "LoadPdaResult struct is accessible" {
    const PdaData = struct {
        value: u64,
    };

    const PdaAccount = Account(PdaData, .{
        .discriminator = discriminator_mod.accountDiscriminator("PdaAccount"),
        .seeds = &.{
            seeds_mod.seed("test"),
        },
    });

    // Verify the LoadPdaResult type exists and has correct fields
    const ResultType = PdaAccount.LoadPdaResult;
    try std.testing.expect(@hasField(ResultType, "account"));
    try std.testing.expect(@hasField(ResultType, "bump"));
}

test "loadWithPda returns error for non-PDA address" {
    const PdaData = struct {
        value: u64,
    };

    const PdaAccount = Account(PdaData, .{
        .discriminator = discriminator_mod.accountDiscriminator("PdaAccount"),
        .seeds = &.{
            seeds_mod.seed("counter"),
        },
    });

    var id = PublicKey.default(); // Not a valid PDA for these seeds
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    var data: [32]u8 align(@alignOf(PdaData)) = undefined;
    @memcpy(data[0..8], &PdaAccount.discriminator);

    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = data.len,
        .data = &data,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    const program_id = PublicKey.default();
    const seeds = .{"counter"};

    // Should return ConstraintSeeds because address doesn't match PDA
    try std.testing.expectError(error.ConstraintSeeds, PdaAccount.loadWithPda(&info, seeds, &program_id));
}

test "loadWithPdaBump returns error for wrong bump" {
    const PdaData = struct {
        value: u64,
    };

    const PdaAccount = Account(PdaData, .{
        .discriminator = discriminator_mod.accountDiscriminator("PdaAccount"),
        .seeds = &.{
            seeds_mod.seed("counter"),
        },
    });

    var id = PublicKey.default(); // Not a valid PDA for these seeds
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    var data: [32]u8 align(@alignOf(PdaData)) = undefined;
    @memcpy(data[0..8], &PdaAccount.discriminator);

    const info = AccountInfo{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = data.len,
        .data = &data,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    const program_id = PublicKey.default();
    const seeds = .{"counter"};

    // Should return ConstraintSeeds because address doesn't match PDA with this bump
    try std.testing.expectError(error.ConstraintSeeds, PdaAccount.loadWithPdaBump(&info, seeds, 255, &program_id));
}

test "requiresPdaValidation returns true for accounts with seeds" {
    const PdaData = struct {
        value: u64,
    };

    const PdaAccount = Account(PdaData, .{
        .discriminator = discriminator_mod.accountDiscriminator("PdaAccount"),
        .seeds = &.{
            seeds_mod.seed("counter"),
        },
    });

    try std.testing.expect(PdaAccount.requiresPdaValidation());
    try std.testing.expect(!TestAccount.requiresPdaValidation());
}

test "requiresInit returns true for accounts with init" {
    const InitData = struct {
        value: u64,
    };

    const InitAccount = Account(InitData, .{
        .discriminator = discriminator_mod.accountDiscriminator("InitAccount"),
        .init = true,
        .payer = "payer",
    });

    try std.testing.expect(InitAccount.requiresInit());
    try std.testing.expect(!TestAccount.requiresInit());
}
