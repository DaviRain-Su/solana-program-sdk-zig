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
const PublicKey = @import("../../public_key.zig").PublicKey;

// ============================================================================
// Constants
// ============================================================================

/// Maximum number of signers in a multisig
pub const MAX_SIGNERS: usize = 11;

/// SPL Token Program ID
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
pub fn COption(comptime T: type) type {
    return extern struct {
        const Self = @This();

        tag: u32 align(1),
        value: T align(1),

        pub const LEN: usize = @sizeOf(Self);

        pub const none: Self = .{
            .tag = 0,
            .value = std.mem.zeroes(T),
        };

        pub fn some(value: T) Self {
            return .{ .tag = 1, .value = value };
        }

        pub fn isSome(self: Self) bool {
            return self.tag == 1;
        }

        pub fn isNone(self: Self) bool {
            return self.tag == 0;
        }

        pub fn unwrap(self: Self) ?T {
            return if (self.tag == 1) self.value else null;
        }

        pub fn unwrapOrPanic(self: Self) T {
            if (self.tag != 1) @panic("COption.unwrapOrPanic called on None");
            return self.value;
        }

        pub fn pack(self: Self, dst: []u8) void {
            std.debug.assert(dst.len >= LEN);
            std.mem.writeInt(u32, dst[0..4], self.tag, .little);
            if (T == PublicKey) {
                @memcpy(dst[4..][0..32], &self.value.bytes);
            } else if (T == u64) {
                std.mem.writeInt(u64, dst[4..12], self.value, .little);
            } else {
                @compileError("COption.pack not implemented for " ++ @typeName(T));
            }
        }

        pub fn unpack(src: []const u8) Self {
            std.debug.assert(src.len >= LEN);
            const tag = std.mem.readInt(u32, src[0..4], .little);
            if (T == PublicKey) {
                var value: PublicKey = undefined;
                @memcpy(&value.bytes, src[4..][0..32]);
                return .{ .tag = tag, .value = value };
            } else if (T == u64) {
                return .{ .tag = tag, .value = std.mem.readInt(u64, src[4..12], .little) };
            } else {
                @compileError("COption.unpack not implemented for " ++ @typeName(T));
            }
        }
    };
}

// ============================================================================
// AccountState Enum
// ============================================================================

/// State of a token account.
pub const AccountState = enum(u8) {
    Uninitialized = 0,
    Initialized = 1,
    Frozen = 2,

    pub fn pack(self: AccountState) u8 {
        return @intFromEnum(self);
    }

    pub fn unpack(byte: u8) !AccountState {
        return std.meta.intToEnum(AccountState, byte) catch error.InvalidAccountState;
    }
};

// ============================================================================
// Mint - Token Mint Account (82 bytes)
// ============================================================================

/// Mint data structure (82 bytes).
pub const Mint = struct {
    mint_authority: COption(PublicKey),
    supply: u64,
    decimals: u8,
    is_initialized: bool,
    freeze_authority: COption(PublicKey),

    pub const LEN: usize = 82;

    pub fn pack(self: Mint, dst: *[LEN]u8) void {
        self.mint_authority.pack(dst[0..36]);
        std.mem.writeInt(u64, dst[36..44], self.supply, .little);
        dst[44] = self.decimals;
        dst[45] = if (self.is_initialized) 1 else 0;
        self.freeze_authority.pack(dst[46..82]);
    }

    pub fn unpack(src: *const [LEN]u8) !Mint {
        return .{
            .mint_authority = COption(PublicKey).unpack(src[0..36]),
            .supply = std.mem.readInt(u64, src[36..44], .little),
            .decimals = src[44],
            .is_initialized = src[45] != 0,
            .freeze_authority = COption(PublicKey).unpack(src[46..82]),
        };
    }

    pub fn unpackFromSlice(src: []const u8) !Mint {
        if (src.len < LEN) return error.InvalidAccountData;
        return unpack(src[0..LEN]);
    }

    pub fn isInitialized(self: Mint) bool {
        return self.is_initialized;
    }
};

// ============================================================================
// Account - Token Account (165 bytes)
// ============================================================================

/// Token account data structure (165 bytes).
pub const Account = struct {
    mint: PublicKey,
    owner: PublicKey,
    amount: u64,
    delegate: COption(PublicKey),
    state: AccountState,
    is_native: COption(u64),
    delegated_amount: u64,
    close_authority: COption(PublicKey),

    pub const LEN: usize = 165;
    pub const ACCOUNT_INITIALIZED_INDEX: usize = 108;

    pub fn pack(self: Account, dst: *[LEN]u8) void {
        @memcpy(dst[0..32], &self.mint.bytes);
        @memcpy(dst[32..64], &self.owner.bytes);
        std.mem.writeInt(u64, dst[64..72], self.amount, .little);
        self.delegate.pack(dst[72..108]);
        dst[108] = self.state.pack();
        self.is_native.pack(dst[109..121]);
        std.mem.writeInt(u64, dst[121..129], self.delegated_amount, .little);
        self.close_authority.pack(dst[129..165]);
    }

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

    pub fn unpackFromSlice(src: []const u8) !Account {
        if (src.len < LEN) return error.InvalidAccountData;
        return unpack(src[0..LEN]);
    }

    pub fn isInitialized(self: Account) bool {
        return self.state != .Uninitialized;
    }

    pub fn isFrozen(self: Account) bool {
        return self.state == .Frozen;
    }

    pub fn isNative(self: Account) bool {
        return self.is_native.isSome();
    }
};

// ============================================================================
// Multisig - Multisig Account (355 bytes)
// ============================================================================

/// Multisig account data structure (355 bytes).
pub const Multisig = struct {
    m: u8,
    n: u8,
    is_initialized: bool,
    signers: [MAX_SIGNERS]PublicKey,

    pub const LEN: usize = 355;

    pub fn pack(self: Multisig, dst: *[LEN]u8) void {
        dst[0] = self.m;
        dst[1] = self.n;
        dst[2] = if (self.is_initialized) 1 else 0;
        var offset: usize = 3;
        for (self.signers) |signer| {
            @memcpy(dst[offset..][0..32], &signer.bytes);
            offset += 32;
        }
    }

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

    pub fn unpackFromSlice(src: []const u8) !Multisig {
        if (src.len < LEN) return error.InvalidAccountData;
        return unpack(src[0..LEN]);
    }

    pub fn isInitialized(self: Multisig) bool {
        return self.is_initialized;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "COption: basic operations" {
    const COptionPubkey = COption(PublicKey);

    const none_val = COptionPubkey.none;
    try std.testing.expect(none_val.isNone());
    try std.testing.expect(none_val.unwrap() == null);

    const test_pubkey = PublicKey.from([_]u8{1} ** 32);
    const some_val = COptionPubkey.some(test_pubkey);
    try std.testing.expect(some_val.isSome());
    try std.testing.expectEqual(test_pubkey, some_val.unwrap().?);
}

test "COption<PublicKey>: pack and unpack" {
    const COptionPubkey = COption(PublicKey);
    const test_pubkey = PublicKey.from([_]u8{0xAB} ** 32);
    const some_val = COptionPubkey.some(test_pubkey);

    var buffer: [36]u8 = undefined;
    some_val.pack(&buffer);

    const unpacked = COptionPubkey.unpack(&buffer);
    try std.testing.expect(unpacked.isSome());
    try std.testing.expectEqual(test_pubkey, unpacked.unwrap().?);
}

test "AccountState: pack and unpack" {
    try std.testing.expectEqual(@as(u8, 0), AccountState.Uninitialized.pack());
    try std.testing.expectEqual(@as(u8, 1), AccountState.Initialized.pack());
    try std.testing.expectEqual(@as(u8, 2), AccountState.Frozen.pack());
    try std.testing.expectError(error.InvalidAccountState, AccountState.unpack(3));
}

test "Mint: size and roundtrip" {
    try std.testing.expectEqual(@as(usize, 82), Mint.LEN);

    const mint = Mint{
        .mint_authority = COption(PublicKey).some(PublicKey.from([_]u8{1} ** 32)),
        .supply = 1_000_000_000,
        .decimals = 9,
        .is_initialized = true,
        .freeze_authority = COption(PublicKey).none,
    };

    var buffer: [Mint.LEN]u8 = undefined;
    mint.pack(&buffer);

    const unpacked = try Mint.unpack(&buffer);
    try std.testing.expectEqual(@as(u64, 1_000_000_000), unpacked.supply);
    try std.testing.expectEqual(@as(u8, 9), unpacked.decimals);
    try std.testing.expect(unpacked.is_initialized);
}

test "Account: size and roundtrip" {
    try std.testing.expectEqual(@as(usize, 165), Account.LEN);

    const account = Account{
        .mint = PublicKey.from([_]u8{1} ** 32),
        .owner = PublicKey.from([_]u8{2} ** 32),
        .amount = 100_000,
        .delegate = COption(PublicKey).none,
        .state = .Initialized,
        .is_native = COption(u64).none,
        .delegated_amount = 0,
        .close_authority = COption(PublicKey).none,
    };

    var buffer: [Account.LEN]u8 = undefined;
    account.pack(&buffer);

    const unpacked = try Account.unpack(&buffer);
    try std.testing.expectEqual(@as(u64, 100_000), unpacked.amount);
    try std.testing.expect(unpacked.isInitialized());
}

test "Multisig: size and roundtrip" {
    try std.testing.expectEqual(@as(usize, 355), Multisig.LEN);

    var signers: [MAX_SIGNERS]PublicKey = undefined;
    for (&signers, 0..) |*s, i| {
        s.* = PublicKey.from([_]u8{@as(u8, @intCast(i + 1))} ** 32);
    }

    const multisig = Multisig{ .m = 2, .n = 3, .is_initialized = true, .signers = signers };

    var buffer: [Multisig.LEN]u8 = undefined;
    multisig.pack(&buffer);

    const unpacked = try Multisig.unpack(&buffer);
    try std.testing.expectEqual(@as(u8, 2), unpacked.m);
    try std.testing.expectEqual(@as(u8, 3), unpacked.n);
}
