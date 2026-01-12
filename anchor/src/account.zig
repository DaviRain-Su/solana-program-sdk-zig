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
const ConstraintExpr = constraints_mod.ConstraintExpr;
const attr_mod = @import("attr.zig");
const Attr = attr_mod.Attr;
const seeds_mod = @import("seeds.zig");
const pda_mod = @import("pda.zig");
const has_one_mod = @import("has_one.zig");
const realloc_mod = @import("realloc.zig");
const sol = @import("solana_program_sdk");

// Import from parent SDK
const sdk_account = sol.account;
const PublicKey = sol.PublicKey;

const Discriminator = discriminator_mod.Discriminator;
const DISCRIMINATOR_LENGTH = discriminator_mod.DISCRIMINATOR_LENGTH;
const AnchorError = anchor_error.AnchorError;
const Constraints = constraints_mod.Constraints;
const AccountInfo = sdk_account.Account.Info;
const SeedSpec = seeds_mod.SeedSpec;
const PdaError = pda_mod.PdaError;
const HasOneSpec = has_one_mod.HasOneSpec;
const ReallocConfig = realloc_mod.ReallocConfig;

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

    /// Account must be mutable (writable)
    mut: bool = false,

    /// Account must be signer
    signer: bool = false,

    /// Expected address (optional)
    address: ?PublicKey = null,

    /// Account must be executable
    executable: bool = false,

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

    // === Phase 3: Advanced Constraints ===

    /// has_one constraints - validate field matches account key
    ///
    /// Validates that a PublicKey field in account data matches another
    /// account's public key from the Accounts struct.
    ///
    /// Example:
    /// ```zig
    /// .has_one = &.{
    ///     .{ .field = "authority", .target = "authority" },
    ///     .{ .field = "mint", .target = "mint" },
    /// }
    /// ```
    has_one: ?[]const HasOneSpec = null,

    /// Close destination account field name
    ///
    /// When specified, the account can be closed by transferring all
    /// lamports to the named destination account and zeroing data.
    ///
    /// Example: `.close = "destination"`
    close: ?[]const u8 = null,

    /// Realloc configuration for dynamic account resizing
    ///
    /// Enables dynamic resizing of account data. The payer will pay
    /// for additional rent when growing, and receive refunds when shrinking.
    ///
    /// Example:
    /// ```zig
    /// .realloc = .{
    ///     .payer = "payer",
    ///     .zero_init = true,
    /// }
    /// ```
    realloc: ?ReallocConfig = null,

    /// Rent-exempt constraint hint (not validated yet)
    ///
    /// Anchor equivalent: `#[account(rent_exempt)]`
    rent_exempt: bool = false,

    /// Custom constraint expression (IDL only)
    ///
    /// Anchor equivalent: `#[account(constraint = <expr>)]`
    constraint: ?ConstraintExpr = null,

    /// Attribute DSL list (optional)
    attrs: ?[]const Attr = null,
};

fn applyAttrs(comptime base: AccountConfig, comptime attrs: []const Attr) AccountConfig {
    comptime var result = base;

    inline for (attrs) |attr| {
        switch (attr) {
            .mut => {
                if (result.mut) @compileError("mut already set");
                result.mut = true;
            },
            .signer => {
                if (result.signer) @compileError("signer already set");
                result.signer = true;
            },
            .seeds => |value| {
                if (result.seeds != null) @compileError("seeds already set");
                result.seeds = value;
            },
            .bump => {
                if (result.bump) @compileError("bump already set");
                result.bump = true;
            },
            .init => {
                if (result.init) @compileError("init already set");
                result.init = true;
            },
            .payer => |value| {
                if (result.payer != null) @compileError("payer already set");
                result.payer = value;
            },
            .close => |value| {
                if (result.close != null) @compileError("close already set");
                result.close = value;
            },
            .realloc => |value| {
                if (result.realloc != null) @compileError("realloc already set");
                result.realloc = value;
            },
            .has_one => |value| {
                if (result.has_one != null) @compileError("has_one already set");
                result.has_one = value;
            },
            .rent_exempt => {
                if (result.rent_exempt) @compileError("rent_exempt already set");
                result.rent_exempt = true;
            },
            .constraint => |value| {
                if (result.constraint != null) @compileError("constraint already set");
                result.constraint = value;
            },
            .owner => |value| {
                if (result.owner != null) @compileError("owner already set");
                result.owner = value;
            },
            .address => |value| {
                if (result.address != null) @compileError("address already set");
                result.address = value;
            },
            .executable => {
                if (result.executable) @compileError("executable already set");
                result.executable = true;
            },
            .space => |value| {
                if (result.space != null) @compileError("space already set");
                result.space = value;
            },
        }
    }

    return result;
}

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
    // Merge attribute DSL if provided
    comptime var merged = config;
    if (merged.attrs) |attrs| {
        merged = applyAttrs(merged, attrs);
    }

    // Validate config at compile time
    comptime {
        if (merged.bump and merged.seeds == null) {
            @compileError("bump requires seeds to be specified");
        }
        if (merged.init and merged.payer == null) {
            @compileError("init requires payer to be specified");
        }
        if (merged.seeds) |s| {
            seeds_mod.validateSeeds(s);
        }
    }

    return struct {
        const Self = @This();

        /// The discriminator for this account type
        pub const discriminator: Discriminator = merged.discriminator;

        /// Required space: discriminator + data
        pub const SPACE: usize = merged.space orelse (DISCRIMINATOR_LENGTH + @sizeOf(T));

        /// The inner data type
        pub const DataType = T;

        /// Whether this account type has PDA seeds
        pub const HAS_SEEDS: bool = merged.seeds != null;

        /// Whether this account stores a bump seed
        pub const HAS_BUMP: bool = merged.bump;

        /// Whether this account requires initialization
        pub const IS_INIT: bool = merged.init;

        /// Whether this account must be writable
        pub const HAS_MUT: bool = merged.mut;

        /// Whether this account must be signer
        pub const HAS_SIGNER: bool = merged.signer;

        /// The seeds specification (if any)
        pub const SEEDS: ?[]const SeedSpec = merged.seeds;

        /// The payer field name (if init is required)
        pub const PAYER: ?[]const u8 = merged.payer;

        // === Phase 3 constants ===

        /// Whether this account has has_one constraints
        pub const HAS_HAS_ONE: bool = merged.has_one != null;

        /// Whether this account has close constraint
        pub const HAS_CLOSE: bool = merged.close != null;

        /// Whether this account has realloc constraint
        pub const HAS_REALLOC: bool = merged.realloc != null;

        /// The has_one constraint specifications (if any)
        pub const HAS_ONE: ?[]const HasOneSpec = merged.has_one;

        /// The close destination field name (if any)
        pub const CLOSE: ?[]const u8 = merged.close;

        /// The realloc configuration (if any)
        pub const REALLOC: ?ReallocConfig = merged.realloc;

        /// Whether rent-exempt constraint is requested
        pub const RENT_EXEMPT: bool = merged.rent_exempt;

        /// Constraint expression (if any)
        pub const CONSTRAINT: ?ConstraintExpr = merged.constraint;

        /// Expected owner (if any)
        pub const OWNER: ?PublicKey = merged.owner;

        /// Expected address (if any)
        pub const ADDRESS: ?PublicKey = merged.address;

        /// Whether account must be executable
        pub const EXECUTABLE: bool = merged.executable;

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
            if (merged.owner) |expected_owner| {
                if (!info.owner_id.equals(expected_owner)) {
                    return error.ConstraintOwner;
                }
            }

            // Validate mut constraint if specified
            if (merged.mut and info.is_writable == 0) {
                return error.ConstraintMut;
            }

            // Validate signer constraint if specified
            if (merged.signer and info.is_signer == 0) {
                return error.ConstraintSigner;
            }

            // Validate address constraint if specified
            if (merged.address) |expected_address| {
                if (!info.id.equals(expected_address)) {
                    return error.ConstraintAddress;
                }
            }

            // Validate executable constraint if specified
            if (merged.executable and info.is_executable == 0) {
                return error.ConstraintExecutable;
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

        // === Phase 3: Constraint Validation Methods ===

        /// Validate has_one constraints against an accounts struct
        ///
        /// This method checks that each field specified in has_one config
        /// matches the corresponding target account's public key.
        ///
        /// Example:
        /// ```zig
        /// // After loading accounts
        /// try vault.validateHasOneConstraints(accounts);
        /// ```
        pub fn validateHasOneConstraints(self: Self, accounts: anytype) !void {
            if (config.has_one) |specs| {
                inline for (specs) |spec| {
                    // Get the target account from the accounts struct
                    const target = @field(accounts, spec.target);

                    // Get target's public key
                    const target_key: *const PublicKey = if (@hasDecl(@TypeOf(target), "key"))
                        target.key()
                    else if (@TypeOf(target) == *const AccountInfo)
                        target.id
                    else
                        @compileError("has_one target must have key() method or be AccountInfo");

                    // Validate the field matches
                    try has_one_mod.validateHasOne(T, self.data, spec.field, target_key);
                }
            }
        }

        /// Check if has_one constraints are satisfied (returns bool)
        pub fn checkHasOneConstraints(self: Self, accounts: anytype) bool {
            self.validateHasOneConstraints(accounts) catch return false;
            return true;
        }

        /// Validate close constraint preconditions
        ///
        /// Checks that the close destination account is writable.
        /// Call this before executing a close operation.
        pub fn validateCloseConstraint(self: Self, accounts: anytype) !void {
            if (config.close) |dest_field| {
                const dest = @field(accounts, dest_field);

                // Get destination AccountInfo
                const dest_info: *const AccountInfo = if (@hasDecl(@TypeOf(dest), "toAccountInfo"))
                    dest.toAccountInfo()
                else if (@TypeOf(dest) == *const AccountInfo)
                    dest
                else
                    @compileError("close target must have toAccountInfo() method or be AccountInfo");

                // Validate destination is writable
                if (dest_info.is_writable == 0) {
                    return error.ConstraintClose;
                }

                // Validate not closing to self
                if (self.info.id.equals(dest_info.id.*)) {
                    return error.ConstraintClose;
                }
            }
        }

        /// Validate realloc constraint preconditions
        ///
        /// Checks that the payer account is a signer (required for growing).
        pub fn validateReallocConstraint(self: Self, accounts: anytype) !void {
            if (config.realloc) |realloc_config| {
                if (realloc_config.payer) |payer_field| {
                    const payer = @field(accounts, payer_field);
                    const PayerType = @TypeOf(payer);

                    // Get payer AccountInfo - handle both struct types and pointer types
                    const payer_info: *const AccountInfo = blk: {
                        if (@typeInfo(PayerType) == .pointer) {
                            // It's a pointer - check if it's AccountInfo or has toAccountInfo
                            const ChildType = @typeInfo(PayerType).pointer.child;
                            if (ChildType == AccountInfo) {
                                break :blk payer;
                            } else if (@hasDecl(ChildType, "toAccountInfo")) {
                                break :blk payer.toAccountInfo();
                            } else {
                                @compileError("realloc payer pointer must point to AccountInfo or type with toAccountInfo()");
                            }
                        } else if (@hasDecl(PayerType, "toAccountInfo")) {
                            break :blk payer.toAccountInfo();
                        } else {
                            @compileError("realloc payer must have toAccountInfo() method or be *const AccountInfo");
                        }
                    };

                    // Validate payer is signer (needed for potential growth)
                    if (payer_info.is_signer == 0) {
                        return error.ConstraintRealloc;
                    }

                    // Validate payer is writable (for refunds)
                    if (payer_info.is_writable == 0) {
                        return error.ConstraintRealloc;
                    }
                }

                // Validate account is writable (required for realloc)
                if (self.info.is_writable == 0) {
                    return error.ConstraintRealloc;
                }
            }
        }

        /// Validate all Phase 3 constraints
        ///
        /// Convenience method to validate all configured constraints.
        pub fn validateAllConstraints(self: Self, accounts: anytype) !void {
            try self.validateHasOneConstraints(accounts);
            try self.validateCloseConstraint(accounts);
            try self.validateReallocConstraint(accounts);
        }

        /// Check if account requires constraint validation
        pub fn requiresConstraintValidation() bool {
            return HAS_HAS_ONE or HAS_CLOSE or HAS_REALLOC;
        }
    };
}

/// Account load errors
pub const AccountError = error{
    AccountDiscriminatorNotFound,
    AccountDiscriminatorMismatch,
    ConstraintOwner,
    ConstraintMut,
    ConstraintSigner,
    ConstraintAddress,
    ConstraintExecutable,
    // Phase 2: PDA errors
    ConstraintSeeds,
    InvalidPda,
    // Phase 3: Advanced constraint errors
    ConstraintHasOne,
    ConstraintClose,
    ConstraintRealloc,
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

// ============================================================================
// Phase 3: Advanced Constraints Tests
// ============================================================================

test "Account with has_one has HAS_HAS_ONE true" {
    const VaultData = struct {
        authority: PublicKey,
        balance: u64,
    };

    const Vault = Account(VaultData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Vault"),
        .has_one = &.{
            .{ .field = "authority", .target = "authority" },
        },
    });

    try std.testing.expect(Vault.HAS_HAS_ONE);
    try std.testing.expect(!Vault.HAS_CLOSE);
    try std.testing.expect(!Vault.HAS_REALLOC);
}

test "Account without has_one has HAS_HAS_ONE false" {
    try std.testing.expect(!TestAccount.HAS_HAS_ONE);
}

test "Account HAS_ONE constant is accessible" {
    const VaultData = struct {
        authority: PublicKey,
        mint: PublicKey,
    };

    const Vault = Account(VaultData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Vault"),
        .has_one = &.{
            .{ .field = "authority", .target = "authority" },
            .{ .field = "mint", .target = "token_mint" },
        },
    });

    try std.testing.expect(Vault.HAS_ONE != null);
    try std.testing.expectEqual(@as(usize, 2), Vault.HAS_ONE.?.len);
}

test "Account with close has HAS_CLOSE true" {
    const CloseableData = struct {
        value: u64,
    };

    const Closeable = Account(CloseableData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Closeable"),
        .close = "destination",
    });

    try std.testing.expect(Closeable.HAS_CLOSE);
    try std.testing.expect(std.mem.eql(u8, Closeable.CLOSE.?, "destination"));
}

test "Account without close has HAS_CLOSE false" {
    try std.testing.expect(!TestAccount.HAS_CLOSE);
    try std.testing.expect(TestAccount.CLOSE == null);
}

test "Account with realloc has HAS_REALLOC true" {
    const DynamicData = struct {
        len: u32,
    };

    const Dynamic = Account(DynamicData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Dynamic"),
        .realloc = .{
            .payer = "payer",
            .zero_init = true,
        },
    });

    try std.testing.expect(Dynamic.HAS_REALLOC);
    try std.testing.expect(Dynamic.REALLOC != null);
    try std.testing.expect(std.mem.eql(u8, Dynamic.REALLOC.?.payer.?, "payer"));
    try std.testing.expect(Dynamic.REALLOC.?.zero_init);
}

test "Account without realloc has HAS_REALLOC false" {
    try std.testing.expect(!TestAccount.HAS_REALLOC);
    try std.testing.expect(TestAccount.REALLOC == null);
}

test "Account with all Phase 3 constraints" {
    const FullData = struct {
        authority: PublicKey,
        value: u64,
    };

    const Full = Account(FullData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Full"),
        .has_one = &.{
            .{ .field = "authority", .target = "authority" },
        },
        .close = "destination",
        .realloc = .{
            .payer = "payer",
            .zero_init = false,
        },
    });

    try std.testing.expect(Full.HAS_HAS_ONE);
    try std.testing.expect(Full.HAS_CLOSE);
    try std.testing.expect(Full.HAS_REALLOC);
}

test "Account attributes DSL merges config" {
    const FullData = struct {
        authority: PublicKey,
        value: u64,
    };

    const Full = Account(FullData, .{
        .discriminator = discriminator_mod.accountDiscriminator("FullAttr"),
        .attrs = &.{
            attr_mod.attr.mut(),
            attr_mod.attr.signer(),
            attr_mod.attr.seeds(&.{ seeds_mod.seed("full"), seeds_mod.seedAccount("authority") }),
            attr_mod.attr.bump(),
            attr_mod.attr.init(),
            attr_mod.attr.payer("payer"),
            attr_mod.attr.hasOne(&.{.{ .field = "authority", .target = "authority" }}),
            attr_mod.attr.close("destination"),
            attr_mod.attr.realloc(.{ .payer = "payer", .zero_init = true }),
            attr_mod.attr.rentExempt(),
            attr_mod.attr.constraint("authority.key() == full.authority"),
            attr_mod.attr.owner(PublicKey.default()),
            attr_mod.attr.address(PublicKey.default()),
            attr_mod.attr.executable(),
            attr_mod.attr.space(128),
        },
    });

    try std.testing.expect(Full.HAS_SEEDS);
    try std.testing.expect(Full.HAS_BUMP);
    try std.testing.expect(Full.IS_INIT);
    try std.testing.expect(Full.HAS_MUT);
    try std.testing.expect(Full.HAS_SIGNER);
    try std.testing.expect(Full.PAYER != null);
    try std.testing.expect(Full.HAS_HAS_ONE);
    try std.testing.expect(Full.HAS_CLOSE);
    try std.testing.expect(Full.HAS_REALLOC);
    try std.testing.expect(Full.RENT_EXEMPT);
    try std.testing.expect(Full.CONSTRAINT != null);
    try std.testing.expect(Full.OWNER != null);
    try std.testing.expect(Full.ADDRESS != null);
    try std.testing.expect(Full.EXECUTABLE);
    try std.testing.expectEqual(@as(usize, 128), Full.SPACE);
}

test "Account attribute sugar maps macro fields" {
    const FullData = struct {
        authority: PublicKey,
        value: u64,
    };

    const Full = Account(FullData, .{
        .discriminator = discriminator_mod.accountDiscriminator("FullAttrSugar"),
        .attrs = attr_mod.attr.account(.{
            .mut = true,
            .signer = true,
            .seeds = &.{ seeds_mod.seed("full"), seeds_mod.seedAccount("authority") },
            .bump = true,
            .init = true,
            .payer = "payer",
            .has_one_fields = &.{ "authority" },
            .close = "destination",
            .realloc = .{ .payer = "payer", .zero_init = true },
            .rent_exempt = true,
            .constraint = "authority.key() == full.authority",
            .owner = PublicKey.default(),
            .address = PublicKey.default(),
            .executable = true,
            .space = 128,
        }),
    });

    try std.testing.expect(Full.HAS_SEEDS);
    try std.testing.expect(Full.HAS_BUMP);
    try std.testing.expect(Full.IS_INIT);
    try std.testing.expect(Full.HAS_MUT);
    try std.testing.expect(Full.HAS_SIGNER);
    try std.testing.expect(Full.PAYER != null);
    try std.testing.expect(Full.HAS_HAS_ONE);
    try std.testing.expect(Full.HAS_CLOSE);
    try std.testing.expect(Full.HAS_REALLOC);
    try std.testing.expect(Full.RENT_EXEMPT);
    try std.testing.expect(Full.CONSTRAINT != null);
    try std.testing.expect(Full.OWNER != null);
    try std.testing.expect(Full.ADDRESS != null);
    try std.testing.expect(Full.EXECUTABLE);
    try std.testing.expectEqual(@as(usize, 128), Full.SPACE);
    try std.testing.expect(std.mem.eql(u8, Full.HAS_ONE.?[0].field, "authority"));
    try std.testing.expect(std.mem.eql(u8, Full.HAS_ONE.?[0].target, "authority"));
}

// ============================================================================
// Phase 3: Constraint Enforcement Tests
// ============================================================================

const signer_mod = @import("signer.zig");
const Signer = signer_mod.Signer;
const SignerMut = signer_mod.SignerMut;

test "validateHasOneConstraints succeeds when field matches target" {
    // Use extern struct to ensure predictable layout
    const VaultData = extern struct {
        authority: PublicKey,
        balance: u64,
    };

    const Vault = Account(VaultData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Vault"),
        .has_one = &.{
            .{ .field = "authority", .target = "authority" },
        },
    });

    // Create test data
    const authority_key = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var vault_id = comptime PublicKey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");
    var owner = PublicKey.default();
    var vault_lamports: u64 = 1_000_000;
    var authority_lamports: u64 = 500_000;

    // Use proper struct layout
    const DataWithDisc = extern struct {
        disc: [8]u8,
        data: VaultData,
    };
    var vault_buffer: DataWithDisc = undefined;
    vault_buffer.disc = Vault.discriminator;
    vault_buffer.data.authority = authority_key;
    vault_buffer.data.balance = 0;

    const vault_data_ptr: [*]u8 = @ptrCast(&vault_buffer);

    const vault_info = AccountInfo{
        .id = &vault_id,
        .owner_id = &owner,
        .lamports = &vault_lamports,
        .data_len = @sizeOf(DataWithDisc),
        .data = vault_data_ptr,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    var authority_id = authority_key;
    const authority_info = AccountInfo{
        .id = &authority_id,
        .owner_id = &owner,
        .lamports = &authority_lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1,
        .is_writable = 0,
        .is_executable = 0,
    };

    // Load accounts
    const vault = try Vault.load(&vault_info);
    const authority = try Signer.load(&authority_info);

    // Create accounts struct
    const Accounts = struct {
        vault: Vault,
        authority: Signer,
    };
    const accounts = Accounts{ .vault = vault, .authority = authority };

    // Should succeed - authority matches
    try vault.validateHasOneConstraints(accounts);
}

test "validateHasOneConstraints fails when field does not match target" {
    // Use extern struct to ensure predictable layout
    const VaultData = extern struct {
        authority: PublicKey,
        balance: u64,
    };

    const Vault = Account(VaultData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Vault2"),
        .has_one = &.{
            .{ .field = "authority", .target = "authority" },
        },
    });

    // Create test data with DIFFERENT keys
    const stored_authority = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    const actual_authority = comptime PublicKey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");

    var vault_id = PublicKey.default();
    var owner = PublicKey.default();
    var vault_lamports: u64 = 1_000_000;
    var authority_lamports: u64 = 500_000;

    // Use proper struct layout
    const DataWithDisc = extern struct {
        disc: [8]u8,
        data: VaultData,
    };
    var vault_buffer: DataWithDisc = undefined;
    vault_buffer.disc = Vault.discriminator;
    vault_buffer.data.authority = stored_authority; // Store different authority
    vault_buffer.data.balance = 0;

    const vault_data_ptr: [*]u8 = @ptrCast(&vault_buffer);

    const vault_info = AccountInfo{
        .id = &vault_id,
        .owner_id = &owner,
        .lamports = &vault_lamports,
        .data_len = @sizeOf(DataWithDisc),
        .data = vault_data_ptr,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    var authority_id = actual_authority;
    const authority_info = AccountInfo{
        .id = &authority_id,
        .owner_id = &owner,
        .lamports = &authority_lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1,
        .is_writable = 0,
        .is_executable = 0,
    };

    const vault = try Vault.load(&vault_info);
    const authority = try Signer.load(&authority_info);

    const Accounts = struct {
        vault: Vault,
        authority: Signer,
    };
    const accounts = Accounts{ .vault = vault, .authority = authority };

    // Should fail - authority doesn't match stored value
    try std.testing.expectError(error.ConstraintHasOne, vault.validateHasOneConstraints(accounts));
}

test "validateCloseConstraint succeeds when destination is writable" {
    const CloseableData = struct {
        value: u64,
    };

    const Closeable = Account(CloseableData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Closeable"),
        .close = "destination",
    });

    var closeable_id = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var dest_id = comptime PublicKey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");
    var owner = PublicKey.default();
    var closeable_lamports: u64 = 1_000_000;
    var dest_lamports: u64 = 500_000;

    var closeable_data: [16]u8 align(@alignOf(CloseableData)) = undefined;
    @memcpy(closeable_data[0..8], &Closeable.discriminator);

    const closeable_info = AccountInfo{
        .id = &closeable_id,
        .owner_id = &owner,
        .lamports = &closeable_lamports,
        .data_len = closeable_data.len,
        .data = &closeable_data,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    const dest_info = AccountInfo{
        .id = &dest_id,
        .owner_id = &owner,
        .lamports = &dest_lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1,
        .is_writable = 1, // Writable
        .is_executable = 0,
    };

    const closeable = try Closeable.load(&closeable_info);
    const destination = try SignerMut.load(&dest_info);

    const Accounts = struct {
        closeable: Closeable,
        destination: SignerMut,
    };
    const accounts = Accounts{ .closeable = closeable, .destination = destination };

    // Should succeed
    try closeable.validateCloseConstraint(accounts);
}

test "validateCloseConstraint fails when destination is not writable" {
    const CloseableData = struct {
        value: u64,
    };

    const Closeable = Account(CloseableData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Closeable2"),
        .close = "destination",
    });

    var closeable_id = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var dest_id = comptime PublicKey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");
    var owner = PublicKey.default();
    var closeable_lamports: u64 = 1_000_000;
    var dest_lamports: u64 = 500_000;

    var closeable_data: [16]u8 align(@alignOf(CloseableData)) = undefined;
    @memcpy(closeable_data[0..8], &Closeable.discriminator);

    const closeable_info = AccountInfo{
        .id = &closeable_id,
        .owner_id = &owner,
        .lamports = &closeable_lamports,
        .data_len = closeable_data.len,
        .data = &closeable_data,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    const dest_info = AccountInfo{
        .id = &dest_id,
        .owner_id = &owner,
        .lamports = &dest_lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1,
        .is_writable = 0, // NOT writable
        .is_executable = 0,
    };

    const closeable = try Closeable.load(&closeable_info);
    const destination = try Signer.load(&dest_info); // Signer (not SignerMut)

    const Accounts = struct {
        closeable: Closeable,
        destination: Signer,
    };
    const accounts = Accounts{ .closeable = closeable, .destination = destination };

    // Should fail - destination not writable
    try std.testing.expectError(error.ConstraintClose, closeable.validateCloseConstraint(accounts));
}

test "validateReallocConstraint succeeds when payer is signer and writable" {
    const DynamicData = struct {
        len: u32,
    };

    const Dynamic = Account(DynamicData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Dynamic2"),
        .realloc = .{
            .payer = "payer",
            .zero_init = true,
        },
    });

    var dynamic_id = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var payer_id = comptime PublicKey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");
    var owner = PublicKey.default();
    var dynamic_lamports: u64 = 1_000_000;
    var payer_lamports: u64 = 5_000_000;

    var dynamic_data: [16]u8 align(@alignOf(DynamicData)) = undefined;
    @memcpy(dynamic_data[0..8], &Dynamic.discriminator);

    const dynamic_info = AccountInfo{
        .id = &dynamic_id,
        .owner_id = &owner,
        .lamports = &dynamic_lamports,
        .data_len = dynamic_data.len,
        .data = &dynamic_data,
        .is_signer = 0,
        .is_writable = 1, // Must be writable
        .is_executable = 0,
    };

    const payer_info = AccountInfo{
        .id = &payer_id,
        .owner_id = &owner,
        .lamports = &payer_lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1, // Is signer
        .is_writable = 1, // Is writable
        .is_executable = 0,
    };

    const dynamic = try Dynamic.load(&dynamic_info);
    const payer = try SignerMut.load(&payer_info);

    const Accounts = struct {
        dynamic: Dynamic,
        payer: SignerMut,
    };
    const accounts = Accounts{ .dynamic = dynamic, .payer = payer };

    // Should succeed
    try dynamic.validateReallocConstraint(accounts);
}

test "validateReallocConstraint fails when payer is not signer" {
    const DynamicData = struct {
        len: u32,
    };

    const Dynamic = Account(DynamicData, .{
        .discriminator = discriminator_mod.accountDiscriminator("Dynamic3"),
        .realloc = .{
            .payer = "payer",
            .zero_init = true,
        },
    });

    var dynamic_id = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var payer_id = comptime PublicKey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");
    var owner = PublicKey.default();
    var dynamic_lamports: u64 = 1_000_000;
    var payer_lamports: u64 = 5_000_000;

    var dynamic_data: [16]u8 align(@alignOf(DynamicData)) = undefined;
    @memcpy(dynamic_data[0..8], &Dynamic.discriminator);

    const dynamic_info = AccountInfo{
        .id = &dynamic_id,
        .owner_id = &owner,
        .lamports = &dynamic_lamports,
        .data_len = dynamic_data.len,
        .data = &dynamic_data,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    const payer_info = AccountInfo{
        .id = &payer_id,
        .owner_id = &owner,
        .lamports = &payer_lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0, // NOT a signer
        .is_writable = 1,
        .is_executable = 0,
    };

    const dynamic = try Dynamic.load(&dynamic_info);

    // Can't use SignerMut here because payer is not a signer, so use raw AccountInfo
    const Accounts = struct {
        dynamic: Dynamic,
        payer: *const AccountInfo,
    };
    const accounts = Accounts{ .dynamic = dynamic, .payer = &payer_info };

    // Should fail - payer not signer
    try std.testing.expectError(error.ConstraintRealloc, dynamic.validateReallocConstraint(accounts));
}

test "requiresConstraintValidation returns correct value" {
    // Reuse existing discriminators to avoid comptime branch limit
    const base_disc = TestAccount.discriminator;

    const NoConstraints = Account(TestData, .{
        .discriminator = base_disc,
    });

    const WithHasOne = Account(struct { authority: PublicKey }, .{
        .discriminator = base_disc,
        .has_one = &.{.{ .field = "authority", .target = "authority" }},
    });

    const WithClose = Account(TestData, .{
        .discriminator = base_disc,
        .close = "dest",
    });

    const WithRealloc = Account(TestData, .{
        .discriminator = base_disc,
        .realloc = .{ .payer = "payer" },
    });

    try std.testing.expect(!NoConstraints.requiresConstraintValidation());
    try std.testing.expect(WithHasOne.requiresConstraintValidation());
    try std.testing.expect(WithClose.requiresConstraintValidation());
    try std.testing.expect(WithRealloc.requiresConstraintValidation());
}
