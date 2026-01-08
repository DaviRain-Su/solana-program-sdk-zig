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

// Import from parent SDK
const sdk_account = @import("../account.zig");
const PublicKey = @import("../public_key.zig").PublicKey;

const Discriminator = discriminator_mod.Discriminator;
const DISCRIMINATOR_LENGTH = discriminator_mod.DISCRIMINATOR_LENGTH;
const AnchorError = anchor_error.AnchorError;
const Constraints = constraints_mod.Constraints;
const AccountInfo = sdk_account.Account.Info;

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
    return struct {
        const Self = @This();

        /// The discriminator for this account type
        pub const discriminator: Discriminator = config.discriminator;

        /// Required space: discriminator + data
        pub const SPACE: usize = config.space orelse (DISCRIMINATOR_LENGTH + @sizeOf(T));

        /// The inner data type
        pub const DataType = T;

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
