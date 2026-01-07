//! Zig implementation of SPL Token state types
//!
//! Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs
//!
//! This module provides state transition types for the SPL Token program:
//! - Mint: Token mint configuration
//! - Account: Token account holding tokens
//! - Multisig: Multi-signature account
//! - AccountState: Account state enum

const std = @import("std");
const PublicKey = @import("../../public_key.zig").PublicKey;
const instruction = @import("instruction.zig");

/// SPL Token Program ID
pub const TOKEN_PROGRAM_ID = instruction.TOKEN_PROGRAM_ID;

/// Maximum number of multisignature signers (max N)
pub const MAX_SIGNERS = instruction.MAX_SIGNERS;

// ============================================================================
// COption - Re-export from SDK
// ============================================================================

/// A C-compatible `Option<T>` type for Solana account state.
///
/// Re-exported from `sdk.c_option.COption`. See that module for full documentation.
///
/// Layout for COption<Pubkey> (36 bytes):
/// - bytes[0..4]: tag (0 = None, 1 = Some)
/// - bytes[4..36]: value (32 bytes for Pubkey, or zeros if None)
///
/// Layout for COption<u64> (12 bytes):
/// - bytes[0..4]: tag (0 = None, 1 = Some)
/// - bytes[4..12]: value (8 bytes for u64, or zeros if None)
pub const COption = @import("../../c_option.zig").COption;

// ============================================================================
// AccountState Enum
// ============================================================================

/// Account state.
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs#L172
pub const AccountState = enum(u8) {
    /// Account is not yet initialized
    Uninitialized = 0,
    /// Account is initialized; the account owner and/or delegate may perform
    /// permitted operations on this account
    Initialized = 1,
    /// Account has been frozen by the mint freeze authority. Neither the
    /// account owner nor the delegate are able to perform operations on
    /// this account.
    Frozen = 2,

    /// Convert from byte
    pub fn fromByte(byte: u8) ?AccountState {
        return std.meta.intToEnum(AccountState, byte) catch null;
    }
};

// ============================================================================
// Mint State
// ============================================================================

/// Mint data.
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs#L12
///
/// Layout (82 bytes):
/// - bytes[0..36]: mint_authority (COption<Pubkey>)
/// - bytes[36..44]: supply (u64, little-endian)
/// - bytes[44]: decimals (u8)
/// - bytes[45]: is_initialized (bool as u8)
/// - bytes[46..82]: freeze_authority (COption<Pubkey>)
pub const Mint = struct {
    /// Optional authority used to mint new tokens. The mint authority may only
    /// be provided during mint creation. If no mint authority is present
    /// then the mint has a fixed supply and no further tokens may be
    /// minted.
    mint_authority: COption(PublicKey),
    /// Total supply of tokens.
    supply: u64,
    /// Number of base 10 digits to the right of the decimal place.
    decimals: u8,
    /// Is `true` if this structure has been initialized
    is_initialized: bool,
    /// Optional authority to freeze token accounts.
    freeze_authority: COption(PublicKey),

    /// Size of Mint in bytes
    pub const SIZE: usize = 82;

    /// Unpack Mint from slice
    pub fn unpackFromSlice(data: []const u8) !Mint {
        if (data.len < SIZE) return error.InvalidAccountData;

        const mint_authority = try COption(PublicKey).unpack(data[0..36]);
        const supply = std.mem.readInt(u64, data[36..44], .little);
        const decimals = data[44];
        const is_initialized = data[45] == 1;
        const freeze_authority = try COption(PublicKey).unpack(data[46..82]);

        // Validate is_initialized byte
        if (data[45] != 0 and data[45] != 1) return error.InvalidAccountData;

        return Mint{
            .mint_authority = mint_authority,
            .supply = supply,
            .decimals = decimals,
            .is_initialized = is_initialized,
            .freeze_authority = freeze_authority,
        };
    }

    /// Pack Mint into slice
    pub fn packIntoSlice(self: Mint, dest: []u8) void {
        if (dest.len < SIZE) return;

        self.mint_authority.pack(dest[0..36]);
        std.mem.writeInt(u64, dest[36..44], self.supply, .little);
        dest[44] = self.decimals;
        dest[45] = if (self.is_initialized) 1 else 0;
        self.freeze_authority.pack(dest[46..82]);
    }

    /// Check if this Mint is initialized
    pub fn isInitialized(self: Mint) bool {
        return self.is_initialized;
    }
};

// ============================================================================
// Token Account State
// ============================================================================

/// Account data.
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs#L86
///
/// Layout (165 bytes):
/// - bytes[0..32]: mint (Pubkey)
/// - bytes[32..64]: owner (Pubkey)
/// - bytes[64..72]: amount (u64, little-endian)
/// - bytes[72..108]: delegate (COption<Pubkey>)
/// - bytes[108]: state (AccountState as u8)
/// - bytes[109..121]: is_native (COption<u64>)
/// - bytes[121..129]: delegated_amount (u64, little-endian)
/// - bytes[129..165]: close_authority (COption<Pubkey>)
pub const Account = struct {
    /// The mint associated with this account
    mint: PublicKey,
    /// The owner of this account.
    owner: PublicKey,
    /// The amount of tokens this account holds.
    amount: u64,
    /// If `delegate` is `Some` then `delegated_amount` represents
    /// the amount authorized by the delegate
    delegate: COption(PublicKey),
    /// The account's state
    state: AccountState,
    /// If `is_native.is_some`, this is a native token, and the value logs the
    /// rent-exempt reserve. An Account is required to be rent-exempt, so
    /// the value is used by the Processor to ensure that wrapped SOL
    /// accounts do not drop below this threshold.
    is_native: COption(u64),
    /// The amount delegated
    delegated_amount: u64,
    /// Optional authority to close the account.
    close_authority: COption(PublicKey),

    /// Size of Account in bytes
    pub const SIZE: usize = 165;

    /// The offset of state field in Account's C representation
    pub const STATE_OFFSET: usize = 108;

    /// Unpack Account from slice
    pub fn unpackFromSlice(data: []const u8) !Account {
        if (data.len < SIZE) return error.InvalidAccountData;

        const mint = PublicKey.from(data[0..32].*);
        const owner = PublicKey.from(data[32..64].*);
        const amount = std.mem.readInt(u64, data[64..72], .little);
        const delegate = try COption(PublicKey).unpack(data[72..108]);
        const state = AccountState.fromByte(data[108]) orelse return error.InvalidAccountData;
        const is_native = try COption(u64).unpack(data[109..121]);
        const delegated_amount = std.mem.readInt(u64, data[121..129], .little);
        const close_authority = try COption(PublicKey).unpack(data[129..165]);

        return Account{
            .mint = mint,
            .owner = owner,
            .amount = amount,
            .delegate = delegate,
            .state = state,
            .is_native = is_native,
            .delegated_amount = delegated_amount,
            .close_authority = close_authority,
        };
    }

    /// Pack Account into slice
    pub fn packIntoSlice(self: Account, dest: []u8) void {
        if (dest.len < SIZE) return;

        @memcpy(dest[0..32], &self.mint.bytes);
        @memcpy(dest[32..64], &self.owner.bytes);
        std.mem.writeInt(u64, dest[64..72], self.amount, .little);
        self.delegate.pack(dest[72..108]);
        dest[108] = @intFromEnum(self.state);
        self.is_native.pack(dest[109..121]);
        std.mem.writeInt(u64, dest[121..129], self.delegated_amount, .little);
        self.close_authority.pack(dest[129..165]);
    }

    /// Checks if account is frozen
    pub fn isFrozen(self: Account) bool {
        return self.state == .Frozen;
    }

    /// Checks if account is native (wrapped SOL)
    pub fn isNative(self: Account) bool {
        return self.is_native.isSome();
    }

    /// Checks if account is initialized
    pub fn isInitialized(self: Account) bool {
        return self.state != .Uninitialized;
    }
};

// ============================================================================
// Multisig State
// ============================================================================

/// Multisignature data.
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs#L182
///
/// Layout (355 bytes):
/// - bytes[0]: m (u8) - Number of signers required
/// - bytes[1]: n (u8) - Number of valid signers
/// - bytes[2]: is_initialized (bool as u8)
/// - bytes[3..355]: signers (11 * 32 bytes = 352 bytes)
pub const Multisig = struct {
    /// Number of signers required
    m: u8,
    /// Number of valid signers
    n: u8,
    /// Is `true` if this structure has been initialized
    is_initialized: bool,
    /// Signer public keys
    signers: [MAX_SIGNERS]PublicKey,

    /// Size of Multisig in bytes
    pub const SIZE: usize = 355;

    /// Unpack Multisig from slice
    pub fn unpackFromSlice(data: []const u8) !Multisig {
        if (data.len < SIZE) return error.InvalidAccountData;

        const m = data[0];
        const n = data[1];
        const is_initialized = switch (data[2]) {
            0 => false,
            1 => true,
            else => return error.InvalidAccountData,
        };

        var signers: [MAX_SIGNERS]PublicKey = undefined;
        for (0..MAX_SIGNERS) |i| {
            const start = 3 + i * 32;
            signers[i] = PublicKey.from(data[start..][0..32].*);
        }

        return Multisig{
            .m = m,
            .n = n,
            .is_initialized = is_initialized,
            .signers = signers,
        };
    }

    /// Pack Multisig into slice
    pub fn packIntoSlice(self: Multisig, dest: []u8) void {
        if (dest.len < SIZE) return;

        dest[0] = self.m;
        dest[1] = self.n;
        dest[2] = if (self.is_initialized) 1 else 0;

        for (0..MAX_SIGNERS) |i| {
            const start = 3 + i * 32;
            @memcpy(dest[start..][0..32], &self.signers[i].bytes);
        }
    }

    /// Check if this Multisig is initialized
    pub fn isInitialized(self: Multisig) bool {
        return self.is_initialized;
    }
};

// ============================================================================
// Helper Functions
// ============================================================================

/// Check if the account data buffer represents an initialized account.
/// This is checking the `state` (`AccountState`) field of an Account object.
pub fn isInitializedAccount(account_data: []const u8) bool {
    if (account_data.len <= Account.STATE_OFFSET) return false;
    return account_data[Account.STATE_OFFSET] != @intFromEnum(AccountState.Uninitialized);
}

// ============================================================================
// Tests
// ============================================================================

test "COption<PublicKey>: pack and unpack" {
    const pubkey = PublicKey.from([_]u8{0xAB} ** 32);

    // Test Some
    const some_opt = COption(PublicKey).some(pubkey);
    var buffer: [36]u8 = undefined;
    some_opt.pack(&buffer);

    const unpacked = try COption(PublicKey).unpack(&buffer);
    try std.testing.expect(unpacked.isSome());
    try std.testing.expectEqual(pubkey, unpacked.unwrap());

    // Test None
    const none_opt = COption(PublicKey).none();
    none_opt.pack(&buffer);

    const unpacked_none = try COption(PublicKey).unpack(&buffer);
    try std.testing.expect(unpacked_none.isNone());
}

test "COption<u64>: pack and unpack" {
    // Test Some
    const some_opt = COption(u64).some(12345678);
    var buffer: [12]u8 = undefined;
    some_opt.pack(&buffer);

    const unpacked = try COption(u64).unpack(&buffer);
    try std.testing.expect(unpacked.isSome());
    try std.testing.expectEqual(@as(u64, 12345678), unpacked.unwrap());

    // Test None
    const none_opt = COption(u64).none();
    none_opt.pack(&buffer);

    const unpacked_none = try COption(u64).unpack(&buffer);
    try std.testing.expect(unpacked_none.isNone());
}

test "AccountState: enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AccountState.Uninitialized));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(AccountState.Initialized));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(AccountState.Frozen));
}

test "Mint: SIZE matches Rust SDK" {
    try std.testing.expectEqual(@as(usize, 82), Mint.SIZE);
}

test "Mint: unpack from zeroed data" {
    const data: [82]u8 = [_]u8{0} ** 82;
    const mint = try Mint.unpackFromSlice(&data);
    try std.testing.expect(!mint.is_initialized);
    try std.testing.expect(mint.mint_authority.isNone());
    try std.testing.expect(mint.freeze_authority.isNone());
}

test "Mint: pack and unpack roundtrip" {
    const mint_authority = PublicKey.from([_]u8{1} ** 32);
    const freeze_authority = PublicKey.from([_]u8{2} ** 32);

    const mint = Mint{
        .mint_authority = COption(PublicKey).some(mint_authority),
        .supply = 1_000_000_000,
        .decimals = 9,
        .is_initialized = true,
        .freeze_authority = COption(PublicKey).some(freeze_authority),
    };

    var buffer: [Mint.SIZE]u8 = undefined;
    mint.packIntoSlice(&buffer);

    const unpacked = try Mint.unpackFromSlice(&buffer);
    try std.testing.expect(unpacked.is_initialized);
    try std.testing.expectEqual(@as(u64, 1_000_000_000), unpacked.supply);
    try std.testing.expectEqual(@as(u8, 9), unpacked.decimals);
    try std.testing.expectEqual(mint_authority, unpacked.mint_authority.unwrap());
    try std.testing.expectEqual(freeze_authority, unpacked.freeze_authority.unwrap());
}

test "Account: SIZE matches Rust SDK" {
    try std.testing.expectEqual(@as(usize, 165), Account.SIZE);
}

test "Account: unpack and pack roundtrip" {
    const mint = PublicKey.from([_]u8{1} ** 32);
    const owner = PublicKey.from([_]u8{2} ** 32);

    const account = Account{
        .mint = mint,
        .owner = owner,
        .amount = 500_000,
        .delegate = COption(PublicKey).none(),
        .state = .Initialized,
        .is_native = COption(u64).none(),
        .delegated_amount = 0,
        .close_authority = COption(PublicKey).none(),
    };

    var buffer: [Account.SIZE]u8 = undefined;
    account.packIntoSlice(&buffer);

    const unpacked = try Account.unpackFromSlice(&buffer);
    try std.testing.expectEqual(mint, unpacked.mint);
    try std.testing.expectEqual(owner, unpacked.owner);
    try std.testing.expectEqual(@as(u64, 500_000), unpacked.amount);
    try std.testing.expectEqual(AccountState.Initialized, unpacked.state);
}

test "Account: isFrozen and isNative" {
    const account_normal = Account{
        .mint = PublicKey.default(),
        .owner = PublicKey.default(),
        .amount = 0,
        .delegate = COption(PublicKey).none(),
        .state = .Initialized,
        .is_native = COption(u64).none(),
        .delegated_amount = 0,
        .close_authority = COption(PublicKey).none(),
    };
    try std.testing.expect(!account_normal.isFrozen());
    try std.testing.expect(!account_normal.isNative());

    const account_frozen = Account{
        .mint = PublicKey.default(),
        .owner = PublicKey.default(),
        .amount = 0,
        .delegate = COption(PublicKey).none(),
        .state = .Frozen,
        .is_native = COption(u64).some(1000000),
        .delegated_amount = 0,
        .close_authority = COption(PublicKey).none(),
    };
    try std.testing.expect(account_frozen.isFrozen());
    try std.testing.expect(account_frozen.isNative());
}

test "Multisig: SIZE matches Rust SDK" {
    try std.testing.expectEqual(@as(usize, 355), Multisig.SIZE);
}

test "Multisig: unpack from zeroed data" {
    const data: [355]u8 = [_]u8{0} ** 355;
    const multisig = try Multisig.unpackFromSlice(&data);
    try std.testing.expect(!multisig.is_initialized);
    try std.testing.expectEqual(@as(u8, 0), multisig.m);
    try std.testing.expectEqual(@as(u8, 0), multisig.n);
}

test "Multisig: unpack with initialized data" {
    var data: [355]u8 = [_]u8{0} ** 355;
    data[0] = 2; // m = 2
    data[1] = 3; // n = 3
    data[2] = 1; // is_initialized = true

    const multisig = try Multisig.unpackFromSlice(&data);
    try std.testing.expect(multisig.is_initialized);
    try std.testing.expectEqual(@as(u8, 2), multisig.m);
    try std.testing.expectEqual(@as(u8, 3), multisig.n);
}

test "isInitializedAccount: checks state field" {
    var data: [Account.SIZE]u8 = [_]u8{0} ** Account.SIZE;

    // Uninitialized
    try std.testing.expect(!isInitializedAccount(&data));

    // Initialized
    data[Account.STATE_OFFSET] = @intFromEnum(AccountState.Initialized);
    try std.testing.expect(isInitializedAccount(&data));

    // Frozen
    data[Account.STATE_OFFSET] = @intFromEnum(AccountState.Frozen);
    try std.testing.expect(isInitializedAccount(&data));
}
