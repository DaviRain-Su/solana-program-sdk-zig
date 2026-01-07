//! Zig implementation of SPL Token state types
//!
//! Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs
//!
//! This module provides the state types for SPL Token program accounts:
//! - `Mint` - Token mint account (82 bytes)
//! - `Account` - Token account (165 bytes)
//! - `Multisig` - Multisig account (355 bytes)
//! - `COption` - C-style optional type for Solana compatibility
//! - `AccountState` - Token account state enum

const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;

// ============================================================================
// Constants
// ============================================================================

/// Maximum number of signers in a multisig
pub const MAX_SIGNERS: usize = 11;

/// Program IDs
pub const TOKEN_PROGRAM_ID = PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");

// ============================================================================
// COption<T> - C-style Optional Type
// ============================================================================

/// C-style optional type used in Solana for backward compatibility.
///
/// Unlike Zig's `?T` or Rust's `Option<T>`, COption uses a 4-byte tag for alignment.
///
/// Memory layout:
/// ```
/// [tag: u32 little-endian][value: T]
/// tag = 0 -> None (value bytes are zeroed)
/// tag = 1 -> Some(value)
/// ```
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs
pub fn COption(comptime T: type) type {
    return extern struct {
        const Self = @This();

        /// The tag indicating presence (0 = None, 1 = Some)
        tag: u32 align(1),
        /// The value (zeroed if tag == 0)
        value: T align(1),

        /// Size of the COption in bytes
        pub const LEN: usize = @sizeOf(Self);

        /// Create a None value
        pub const none: Self = .{
            .tag = 0,
            .value = std.mem.zeroes(T),
        };

        /// Create a Some value
        pub fn some(value: T) Self {
            return .{
                .tag = 1,
                .value = value,
            };
        }

        /// Check if this is Some
        pub fn isSome(self: Self) bool {
            return self.tag == 1;
        }

        /// Check if this is None
        pub fn isNone(self: Self) bool {
            return self.tag == 0;
        }

        /// Unwrap the value, returning null if None
        pub fn unwrap(self: Self) ?T {
            return if (self.tag == 1) self.value else null;
        }

        /// Unwrap the value, panicking if None
        pub fn unwrapOrPanic(self: Self) T {
            if (self.tag != 1) {
                @panic("COption.unwrapOrPanic called on None value");
            }
            return self.value;
        }

        /// Pack into bytes (little-endian)
        pub fn pack(self: Self, dst: []u8) void {
            std.debug.assert(dst.len >= LEN);
            std.mem.writeInt(u32, dst[0..4], self.tag, .little);
            if (T == PublicKey) {
                @memcpy(dst[4..][0..32], &self.value.bytes);
            } else if (T == u64) {
                std.mem.writeInt(u64, dst[4..12], self.value, .little);
            } else {
                @compileError("COption.pack not implemented for type " ++ @typeName(T));
            }
        }

        /// Unpack from bytes (little-endian)
        pub fn unpack(src: []const u8) Self {
            std.debug.assert(src.len >= LEN);
            const tag = std.mem.readInt(u32, src[0..4], .little);
            if (T == PublicKey) {
                var value: PublicKey = undefined;
                @memcpy(&value.bytes, src[4..][0..32]);
                return .{ .tag = tag, .value = value };
            } else if (T == u64) {
                const value = std.mem.readInt(u64, src[4..12], .little);
                return .{ .tag = tag, .value = value };
            } else {
                @compileError("COption.unpack not implemented for type " ++ @typeName(T));
            }
        }
    };
}

// ============================================================================
// AccountState Enum
// ============================================================================

/// State of a token account.
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs#L92
pub const AccountState = enum(u8) {
    /// Account is not yet initialized
    Uninitialized = 0,
    /// Account is initialized; the account owner and/or delegate may perform
    /// permitted operations on this account
    Initialized = 1,
    /// Account has been frozen by the mint freeze authority. Neither the account
    /// owner nor the delegate are able to perform operations on this account.
    Frozen = 2,

    /// Pack to a single byte
    pub fn pack(self: AccountState) u8 {
        return @intFromEnum(self);
    }

    /// Unpack from a single byte
    pub fn unpack(byte: u8) !AccountState {
        return std.meta.intToEnum(AccountState, byte) catch {
            return error.InvalidAccountState;
        };
    }
};

// ============================================================================
// Mint - Token Mint Account (82 bytes)
// ============================================================================

/// Mint data structure.
///
/// Memory layout (82 bytes total):
/// ```
/// Offset 0:  mint_authority     (COption<PublicKey>, 36 bytes)
/// Offset 36: supply             (u64, 8 bytes)
/// Offset 44: decimals           (u8, 1 byte)
/// Offset 45: is_initialized     (bool, 1 byte)
/// Offset 46: freeze_authority   (COption<PublicKey>, 36 bytes)
/// ```
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs#L17-L35
pub const Mint = struct {
    /// Optional authority used to mint new tokens. The mint authority may only
    /// be provided during mint creation. If no mint authority is present
    /// then the mint has a fixed supply and no further tokens may be minted.
    mint_authority: COption(PublicKey),
    /// Total supply of tokens
    supply: u64,
    /// Number of base 10 digits to the right of the decimal place
    decimals: u8,
    /// Is `true` if this structure has been initialized
    is_initialized: bool,
    /// Optional authority to freeze token accounts
    freeze_authority: COption(PublicKey),

    /// Size of Mint account data in bytes
    pub const LEN: usize = 82;

    /// Pack Mint into a byte array
    pub fn pack(self: Mint, dst: *[LEN]u8) void {
        // mint_authority at offset 0 (36 bytes)
        self.mint_authority.pack(dst[0..36]);

        // supply at offset 36 (8 bytes)
        std.mem.writeInt(u64, dst[36..44], self.supply, .little);

        // decimals at offset 44 (1 byte)
        dst[44] = self.decimals;

        // is_initialized at offset 45 (1 byte)
        dst[45] = if (self.is_initialized) 1 else 0;

        // freeze_authority at offset 46 (36 bytes)
        self.freeze_authority.pack(dst[46..82]);
    }

    /// Unpack Mint from a byte array
    pub fn unpack(src: *const [LEN]u8) !Mint {
        return .{
            .mint_authority = COption(PublicKey).unpack(src[0..36]),
            .supply = std.mem.readInt(u64, src[36..44], .little),
            .decimals = src[44],
            .is_initialized = src[45] != 0,
            .freeze_authority = COption(PublicKey).unpack(src[46..82]),
        };
    }

    /// Unpack Mint from a slice (with length check)
    pub fn unpackFromSlice(src: []const u8) !Mint {
        if (src.len < LEN) {
            return error.InvalidAccountData;
        }
        return unpack(src[0..LEN]);
    }

    /// Check if the mint is initialized
    pub fn isInitialized(self: Mint) bool {
        return self.is_initialized;
    }
};

// ============================================================================
// Account - Token Account (165 bytes)
// ============================================================================

/// Token account data structure.
///
/// Memory layout (165 bytes total):
/// ```
/// Offset 0:   mint               (PublicKey, 32 bytes)
/// Offset 32:  owner              (PublicKey, 32 bytes)
/// Offset 64:  amount             (u64, 8 bytes)
/// Offset 72:  delegate           (COption<PublicKey>, 36 bytes)
/// Offset 108: state              (AccountState, 1 byte)
/// Offset 109: is_native          (COption<u64>, 12 bytes)
/// Offset 121: delegated_amount   (u64, 8 bytes)
/// Offset 129: close_authority    (COption<PublicKey>, 36 bytes)
/// ```
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs#L58-L90
pub const Account = struct {
    /// The mint associated with this account
    mint: PublicKey,
    /// The owner of this account
    owner: PublicKey,
    /// The amount of tokens this account holds
    amount: u64,
    /// If `delegate` is `Some` then `delegated_amount` represents
    /// the amount authorized by the delegate
    delegate: COption(PublicKey),
    /// The account's state
    state: AccountState,
    /// If is_native.isSome, this is a native token, and the value logs the
    /// rent-exempt reserve. An Account is required to be rent-exempt, so
    /// the value is used by the Processor to ensure that wrapped SOL
    /// accounts do not drop below this threshold.
    is_native: COption(u64),
    /// The amount delegated
    delegated_amount: u64,
    /// Optional authority to close the account
    close_authority: COption(PublicKey),

    /// Size of Account data in bytes
    pub const LEN: usize = 165;

    /// Index in account data where the state field is located
    /// Used for quick initialization checks without full deserialization
    pub const ACCOUNT_INITIALIZED_INDEX: usize = 108;

    /// Pack Account into a byte array
    pub fn pack(self: Account, dst: *[LEN]u8) void {
        // mint at offset 0 (32 bytes)
        @memcpy(dst[0..32], &self.mint.bytes);

        // owner at offset 32 (32 bytes)
        @memcpy(dst[32..64], &self.owner.bytes);

        // amount at offset 64 (8 bytes)
        std.mem.writeInt(u64, dst[64..72], self.amount, .little);

        // delegate at offset 72 (36 bytes)
        self.delegate.pack(dst[72..108]);

        // state at offset 108 (1 byte)
        dst[108] = self.state.pack();

        // is_native at offset 109 (12 bytes)
        self.is_native.pack(dst[109..121]);

        // delegated_amount at offset 121 (8 bytes)
        std.mem.writeInt(u64, dst[121..129], self.delegated_amount, .little);

        // close_authority at offset 129 (36 bytes)
        self.close_authority.pack(dst[129..165]);
    }

    /// Unpack Account from a byte array
    pub fn unpack(src: *const [LEN]u8) !Account {
        return .{
            .mint = PublicKey.from(src[0..32].*),
            .owner = PublicKey.from(src[32..64].*),
            .amount = std.mem.readInt(u64, src[64..72], .little),
            .delegate = COption(PublicKey).unpack(src[72..108]),
            .state = try AccountState.unpack(src[108]),
            .is_native = COption(u64).unpack(src[109..121]),
            .delegated_amount = std.mem.readInt(u64, src[121..129], .little),
            .close_authority = COption(PublicKey).unpack(src[129..165]),
        };
    }

    /// Unpack Account from a slice (with length check)
    pub fn unpackFromSlice(src: []const u8) !Account {
        if (src.len < LEN) {
            return error.InvalidAccountData;
        }
        return unpack(src[0..LEN]);
    }

    /// Check if the account is initialized
    pub fn isInitialized(self: Account) bool {
        return self.state != .Uninitialized;
    }

    /// Check if the account is frozen
    pub fn isFrozen(self: Account) bool {
        return self.state == .Frozen;
    }

    /// Check if the account is a native SOL account
    pub fn isNative(self: Account) bool {
        return self.is_native.isSome();
    }
};

// ============================================================================
// Multisig - Multisig Account (355 bytes)
// ============================================================================

/// Multisig account data structure.
///
/// Memory layout (355 bytes total):
/// ```
/// Offset 0:   m              (u8, required signers)
/// Offset 1:   n              (u8, valid signers)
/// Offset 2:   is_initialized (bool, 1 byte)
/// Offset 3:   signers        ([11]PublicKey, 352 bytes)
/// ```
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/state.rs#L125
pub const Multisig = struct {
    /// Number of signers required
    m: u8,
    /// Number of valid signers
    n: u8,
    /// Is `true` if this structure has been initialized
    is_initialized: bool,
    /// Signer public keys
    signers: [MAX_SIGNERS]PublicKey,

    /// Size of Multisig account data in bytes
    pub const LEN: usize = 355;

    /// Pack Multisig into a byte array
    pub fn pack(self: Multisig, dst: *[LEN]u8) void {
        // m at offset 0 (1 byte)
        dst[0] = self.m;

        // n at offset 1 (1 byte)
        dst[1] = self.n;

        // is_initialized at offset 2 (1 byte)
        dst[2] = if (self.is_initialized) 1 else 0;

        // signers at offset 3 (352 bytes = 11 * 32)
        var offset: usize = 3;
        for (self.signers) |signer| {
            @memcpy(dst[offset..][0..32], &signer.bytes);
            offset += 32;
        }
    }

    /// Unpack Multisig from a byte array
    pub fn unpack(src: *const [LEN]u8) !Multisig {
        var signers: [MAX_SIGNERS]PublicKey = undefined;
        var offset: usize = 3;
        for (&signers) |*signer| {
            signer.* = PublicKey.from(src[offset..][0..32].*);
            offset += 32;
        }

        return .{
            .m = src[0],
            .n = src[1],
            .is_initialized = src[2] != 0,
            .signers = signers,
        };
    }

    /// Unpack Multisig from a slice (with length check)
    pub fn unpackFromSlice(src: []const u8) !Multisig {
        if (src.len < LEN) {
            return error.InvalidAccountData;
        }
        return unpack(src[0..LEN]);
    }

    /// Check if the multisig is initialized
    pub fn isInitialized(self: Multisig) bool {
        return self.is_initialized;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "COption: none and some" {
    const COptionPubkey = COption(PublicKey);

    // Test None
    const none_val = COptionPubkey.none;
    try std.testing.expect(none_val.isNone());
    try std.testing.expect(!none_val.isSome());
    try std.testing.expect(none_val.unwrap() == null);

    // Test Some
    const test_pubkey = PublicKey.from([_]u8{1} ** 32);
    const some_val = COptionPubkey.some(test_pubkey);
    try std.testing.expect(some_val.isSome());
    try std.testing.expect(!some_val.isNone());
    try std.testing.expect(some_val.unwrap() != null);
    try std.testing.expectEqual(test_pubkey, some_val.unwrap().?);
}

test "COption<PublicKey>: pack and unpack" {
    const COptionPubkey = COption(PublicKey);

    // Test None
    {
        const none_val = COptionPubkey.none;
        var buffer: [36]u8 = undefined;
        none_val.pack(&buffer);

        // tag should be 0
        try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, buffer[0..4], .little));

        // Unpack and verify
        const unpacked = COptionPubkey.unpack(&buffer);
        try std.testing.expect(unpacked.isNone());
    }

    // Test Some
    {
        const test_pubkey = PublicKey.from([_]u8{0xAB} ** 32);
        const some_val = COptionPubkey.some(test_pubkey);
        var buffer: [36]u8 = undefined;
        some_val.pack(&buffer);

        // tag should be 1
        try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, buffer[0..4], .little));

        // value should match
        try std.testing.expectEqualSlices(u8, &test_pubkey.bytes, buffer[4..36]);

        // Unpack and verify
        const unpacked = COptionPubkey.unpack(&buffer);
        try std.testing.expect(unpacked.isSome());
        try std.testing.expectEqual(test_pubkey, unpacked.unwrap().?);
    }
}

test "COption<u64>: pack and unpack" {
    const COptionU64 = COption(u64);

    // Test None
    {
        const none_val = COptionU64.none;
        var buffer: [12]u8 = undefined;
        none_val.pack(&buffer);

        try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, buffer[0..4], .little));

        const unpacked = COptionU64.unpack(&buffer);
        try std.testing.expect(unpacked.isNone());
    }

    // Test Some
    {
        const value: u64 = 0x123456789ABCDEF0;
        const some_val = COptionU64.some(value);
        var buffer: [12]u8 = undefined;
        some_val.pack(&buffer);

        try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, buffer[0..4], .little));
        try std.testing.expectEqual(value, std.mem.readInt(u64, buffer[4..12], .little));

        const unpacked = COptionU64.unpack(&buffer);
        try std.testing.expect(unpacked.isSome());
        try std.testing.expectEqual(value, unpacked.unwrap().?);
    }
}

test "AccountState: pack and unpack" {
    // Test all variants
    try std.testing.expectEqual(@as(u8, 0), AccountState.Uninitialized.pack());
    try std.testing.expectEqual(@as(u8, 1), AccountState.Initialized.pack());
    try std.testing.expectEqual(@as(u8, 2), AccountState.Frozen.pack());

    try std.testing.expectEqual(AccountState.Uninitialized, try AccountState.unpack(0));
    try std.testing.expectEqual(AccountState.Initialized, try AccountState.unpack(1));
    try std.testing.expectEqual(AccountState.Frozen, try AccountState.unpack(2));

    // Invalid value should error
    try std.testing.expectError(error.InvalidAccountState, AccountState.unpack(3));
}

test "Mint: size constant" {
    try std.testing.expectEqual(@as(usize, 82), Mint.LEN);
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

    var buffer: [Mint.LEN]u8 = undefined;
    mint.pack(&buffer);

    const unpacked = try Mint.unpack(&buffer);
    try std.testing.expect(unpacked.mint_authority.isSome());
    try std.testing.expectEqual(mint_authority, unpacked.mint_authority.unwrap().?);
    try std.testing.expectEqual(@as(u64, 1_000_000_000), unpacked.supply);
    try std.testing.expectEqual(@as(u8, 9), unpacked.decimals);
    try std.testing.expect(unpacked.is_initialized);
    try std.testing.expect(unpacked.freeze_authority.isSome());
    try std.testing.expectEqual(freeze_authority, unpacked.freeze_authority.unwrap().?);
}

test "Mint: pack and unpack with None authorities" {
    const mint = Mint{
        .mint_authority = COption(PublicKey).none,
        .supply = 21_000_000,
        .decimals = 8,
        .is_initialized = true,
        .freeze_authority = COption(PublicKey).none,
    };

    var buffer: [Mint.LEN]u8 = undefined;
    mint.pack(&buffer);

    const unpacked = try Mint.unpack(&buffer);
    try std.testing.expect(unpacked.mint_authority.isNone());
    try std.testing.expectEqual(@as(u64, 21_000_000), unpacked.supply);
    try std.testing.expectEqual(@as(u8, 8), unpacked.decimals);
    try std.testing.expect(unpacked.is_initialized);
    try std.testing.expect(unpacked.freeze_authority.isNone());
}

test "Account: size constant" {
    try std.testing.expectEqual(@as(usize, 165), Account.LEN);
}

test "Account: pack and unpack roundtrip" {
    const mint = PublicKey.from([_]u8{1} ** 32);
    const owner = PublicKey.from([_]u8{2} ** 32);
    const delegate = PublicKey.from([_]u8{3} ** 32);
    const close_authority = PublicKey.from([_]u8{4} ** 32);

    const account = Account{
        .mint = mint,
        .owner = owner,
        .amount = 100_000,
        .delegate = COption(PublicKey).some(delegate),
        .state = .Initialized,
        .is_native = COption(u64).none,
        .delegated_amount = 50_000,
        .close_authority = COption(PublicKey).some(close_authority),
    };

    var buffer: [Account.LEN]u8 = undefined;
    account.pack(&buffer);

    const unpacked = try Account.unpack(&buffer);
    try std.testing.expectEqual(mint, unpacked.mint);
    try std.testing.expectEqual(owner, unpacked.owner);
    try std.testing.expectEqual(@as(u64, 100_000), unpacked.amount);
    try std.testing.expect(unpacked.delegate.isSome());
    try std.testing.expectEqual(delegate, unpacked.delegate.unwrap().?);
    try std.testing.expectEqual(AccountState.Initialized, unpacked.state);
    try std.testing.expect(unpacked.is_native.isNone());
    try std.testing.expectEqual(@as(u64, 50_000), unpacked.delegated_amount);
    try std.testing.expect(unpacked.close_authority.isSome());
    try std.testing.expectEqual(close_authority, unpacked.close_authority.unwrap().?);
}

test "Account: native SOL account" {
    const mint = PublicKey.from([_]u8{1} ** 32);
    const owner = PublicKey.from([_]u8{2} ** 32);

    const account = Account{
        .mint = mint,
        .owner = owner,
        .amount = 1_000_000_000, // 1 SOL in lamports
        .delegate = COption(PublicKey).none,
        .state = .Initialized,
        .is_native = COption(u64).some(890880), // rent-exempt reserve
        .delegated_amount = 0,
        .close_authority = COption(PublicKey).none,
    };

    var buffer: [Account.LEN]u8 = undefined;
    account.pack(&buffer);

    const unpacked = try Account.unpack(&buffer);
    try std.testing.expect(unpacked.isNative());
    try std.testing.expectEqual(@as(u64, 890880), unpacked.is_native.unwrap().?);
}

test "Account: state checks" {
    const mint = PublicKey.from([_]u8{1} ** 32);
    const owner = PublicKey.from([_]u8{2} ** 32);

    // Uninitialized account
    {
        const account = Account{
            .mint = mint,
            .owner = owner,
            .amount = 0,
            .delegate = COption(PublicKey).none,
            .state = .Uninitialized,
            .is_native = COption(u64).none,
            .delegated_amount = 0,
            .close_authority = COption(PublicKey).none,
        };
        try std.testing.expect(!account.isInitialized());
        try std.testing.expect(!account.isFrozen());
    }

    // Initialized account
    {
        const account = Account{
            .mint = mint,
            .owner = owner,
            .amount = 100,
            .delegate = COption(PublicKey).none,
            .state = .Initialized,
            .is_native = COption(u64).none,
            .delegated_amount = 0,
            .close_authority = COption(PublicKey).none,
        };
        try std.testing.expect(account.isInitialized());
        try std.testing.expect(!account.isFrozen());
    }

    // Frozen account
    {
        const account = Account{
            .mint = mint,
            .owner = owner,
            .amount = 100,
            .delegate = COption(PublicKey).none,
            .state = .Frozen,
            .is_native = COption(u64).none,
            .delegated_amount = 0,
            .close_authority = COption(PublicKey).none,
        };
        try std.testing.expect(account.isInitialized());
        try std.testing.expect(account.isFrozen());
    }
}

test "Multisig: size constant" {
    try std.testing.expectEqual(@as(usize, 355), Multisig.LEN);
}

test "Multisig: pack and unpack roundtrip" {
    var signers: [MAX_SIGNERS]PublicKey = undefined;
    for (&signers, 0..) |*signer, i| {
        signer.* = PublicKey.from([_]u8{@as(u8, @intCast(i + 1))} ** 32);
    }

    const multisig = Multisig{
        .m = 2,
        .n = 3,
        .is_initialized = true,
        .signers = signers,
    };

    var buffer: [Multisig.LEN]u8 = undefined;
    multisig.pack(&buffer);

    const unpacked = try Multisig.unpack(&buffer);
    try std.testing.expectEqual(@as(u8, 2), unpacked.m);
    try std.testing.expectEqual(@as(u8, 3), unpacked.n);
    try std.testing.expect(unpacked.is_initialized);

    for (unpacked.signers, 0..) |signer, i| {
        try std.testing.expectEqual(signers[i], signer);
    }
}

test "Multisig: not initialized" {
    var signers: [MAX_SIGNERS]PublicKey = undefined;
    for (&signers) |*signer| {
        signer.* = PublicKey.default();
    }

    const multisig = Multisig{
        .m = 0,
        .n = 0,
        .is_initialized = false,
        .signers = signers,
    };

    try std.testing.expect(!multisig.isInitialized());
}
