//! SPL Token on-chain state structs — zero-copy views over the
//! token program's account data buffers.
//!
//! Layouts mirror the canonical Rust `Mint` (82 B) and `Account`
//! (165 B) bincode-style encodings exactly: `Pubkey` is 32 raw
//! bytes, `COption<T>` is a 4-byte little-endian tag followed by
//! `T`'s bytes (whether or not the option is `Some`). Padding fields
//! are kept explicit so a `@bitCast`/pointer-cast from the runtime
//! account-data slice lands on the right bytes regardless of host
//! alignment rules.
//!
//! Use the `from*` constructors below to validate a slice's length
//! and obtain a typed pointer in one step — they're the only
//! supported way to materialise these structs.

const std = @import("std");
const sol = @import("solana_program_sdk");

const Pubkey = sol.Pubkey;

/// Size of the encoded `Mint` account — match the canonical Rust
/// `spl_token::state::Mint::LEN`.
pub const MINT_LEN: usize = 82;

/// Size of the encoded token `Account` — match the canonical Rust
/// `spl_token::state::Account::LEN`.
pub const ACCOUNT_LEN: usize = 165;

/// `COption<T>` discriminator tag — 4 little-endian bytes preceding
/// the optional payload. Matches Rust's bincode encoding.
pub const COPTION_SOME: u32 = 1;
pub const COPTION_NONE: u32 = 0;

/// Token account "state" byte (`Account::state`):
///   0 = Uninitialized
///   1 = Initialized
///   2 = Frozen
pub const AccountState = enum(u8) {
    uninitialized = 0,
    initialized = 1,
    frozen = 2,
    _,
};

/// Mint account — zero-copy view over `MINT_LEN` bytes.
///
/// Use `Mint.fromBytes(slice)` to obtain a typed pointer after the
/// runtime has handed you an `AccountInfo`'s `data` slice.
pub const Mint = extern struct {
    /// `COption<Pubkey>` — 4-byte tag + 32-byte pubkey. When the tag
    /// is `COPTION_NONE`, the pubkey bytes are zero-padding and
    /// must not be read.
    mint_authority_tag: u32 align(1),
    mint_authority: Pubkey align(1),

    /// Total supply currently in circulation (raw u64, no decimals
    /// adjustment).
    supply: u64 align(1),

    /// Number of decimal places — the on-chain `Amount` is
    /// `ui_amount * 10^decimals`.
    decimals: u8,

    /// 1 = `is_initialized`. Anything else means the buffer hasn't
    /// been initialised by the token program yet.
    is_initialized: u8,

    /// Optional freeze authority — same `COption` layout as
    /// `mint_authority` above.
    freeze_authority_tag: u32 align(1),
    freeze_authority: Pubkey align(1),

    pub inline fn mintAuthority(self: *const Mint) ?*const Pubkey {
        return if (self.mint_authority_tag == COPTION_SOME) &self.mint_authority else null;
    }

    pub inline fn freezeAuthority(self: *const Mint) ?*const Pubkey {
        return if (self.freeze_authority_tag == COPTION_SOME) &self.freeze_authority else null;
    }

    /// Parse a runtime data slice into a typed pointer. Returns an
    /// error if `bytes.len != MINT_LEN`.
    pub inline fn fromBytes(bytes: []const u8) sol.ProgramError!*const Mint {
        if (bytes.len != MINT_LEN) {
            return sol.program_error.fail(
                @src(),
                "mint:wrong_size",
                error.InvalidAccountData,
            );
        }
        return @ptrCast(@alignCast(bytes.ptr));
    }

    /// Mutable variant — same length check, returns a writable
    /// pointer so a program that owns the account (typically the
    /// token program itself; this helper is mainly for tests and
    /// account inspection inside test harnesses) can mutate the
    /// fields in place.
    pub inline fn fromBytesMut(bytes: []u8) sol.ProgramError!*Mint {
        if (bytes.len != MINT_LEN) {
            return sol.program_error.fail(
                @src(),
                "mint:wrong_size",
                error.InvalidAccountData,
            );
        }
        return @ptrCast(@alignCast(bytes.ptr));
    }
};

/// Token `Account` — zero-copy view over `ACCOUNT_LEN` bytes.
pub const Account = extern struct {
    mint: Pubkey align(1),
    owner: Pubkey align(1),
    amount: u64 align(1),

    delegate_tag: u32 align(1),
    delegate: Pubkey align(1),

    state: u8,

    is_native_tag: u32 align(1),
    is_native_rent_exempt_reserve: u64 align(1),

    delegated_amount: u64 align(1),

    close_authority_tag: u32 align(1),
    close_authority: Pubkey align(1),

    pub inline fn accountState(self: *const Account) AccountState {
        return @enumFromInt(self.state);
    }

    pub inline fn isFrozen(self: *const Account) bool {
        return self.state == @intFromEnum(AccountState.frozen);
    }

    pub inline fn isInitialized(self: *const Account) bool {
        return self.state != @intFromEnum(AccountState.uninitialized);
    }

    pub inline fn delegateKey(self: *const Account) ?*const Pubkey {
        return if (self.delegate_tag == COPTION_SOME) &self.delegate else null;
    }

    pub inline fn closeAuthority(self: *const Account) ?*const Pubkey {
        return if (self.close_authority_tag == COPTION_SOME) &self.close_authority else null;
    }

    /// `true` if the account is a wrapped-SOL holder. The token
    /// program uses the `is_native` `COption` to flag this and the
    /// inner `u64` carries the rent-exempt reserve.
    pub inline fn isNative(self: *const Account) bool {
        return self.is_native_tag == COPTION_SOME;
    }

    pub inline fn fromBytes(bytes: []const u8) sol.ProgramError!*const Account {
        if (bytes.len != ACCOUNT_LEN) {
            return sol.program_error.fail(
                @src(),
                "token_account:wrong_size",
                error.InvalidAccountData,
            );
        }
        return @ptrCast(@alignCast(bytes.ptr));
    }

    pub inline fn fromBytesMut(bytes: []u8) sol.ProgramError!*Account {
        if (bytes.len != ACCOUNT_LEN) {
            return sol.program_error.fail(
                @src(),
                "token_account:wrong_size",
                error.InvalidAccountData,
            );
        }
        return @ptrCast(@alignCast(bytes.ptr));
    }
};

// =============================================================================
// Tests
// =============================================================================

comptime {
    std.debug.assert(@sizeOf(Mint) == MINT_LEN);
    std.debug.assert(@sizeOf(Account) == ACCOUNT_LEN);

    // Spot-check critical field offsets so any silent regression
    // (e.g. someone removes an `align(1)`) trips at build time.
    std.debug.assert(@offsetOf(Mint, "mint_authority_tag") == 0);
    std.debug.assert(@offsetOf(Mint, "supply") == 36);
    std.debug.assert(@offsetOf(Mint, "decimals") == 44);
    std.debug.assert(@offsetOf(Mint, "is_initialized") == 45);
    std.debug.assert(@offsetOf(Mint, "freeze_authority_tag") == 46);

    std.debug.assert(@offsetOf(Account, "mint") == 0);
    std.debug.assert(@offsetOf(Account, "owner") == 32);
    std.debug.assert(@offsetOf(Account, "amount") == 64);
    std.debug.assert(@offsetOf(Account, "delegate_tag") == 72);
    std.debug.assert(@offsetOf(Account, "state") == 108);
    std.debug.assert(@offsetOf(Account, "is_native_tag") == 109);
    std.debug.assert(@offsetOf(Account, "delegated_amount") == 121);
    std.debug.assert(@offsetOf(Account, "close_authority_tag") == 129);
}

test "mint: fromBytes rejects wrong length" {
    const buf = [_]u8{0} ** (MINT_LEN - 1);
    try std.testing.expectError(error.InvalidAccountData, Mint.fromBytes(&buf));
}

test "mint: round-trip authority decoding" {
    var buf: [MINT_LEN]u8 = [_]u8{0} ** MINT_LEN;
    // mint_authority = Some(0x01..01), freeze_authority = None
    std.mem.writeInt(u32, buf[0..4], COPTION_SOME, .little);
    @memset(buf[4..36], 0x01);
    std.mem.writeInt(u64, buf[36..44], 1_000_000_000, .little);
    buf[44] = 9; // decimals
    buf[45] = 1; // is_initialized
    std.mem.writeInt(u32, buf[46..50], COPTION_NONE, .little);

    const mint = try Mint.fromBytes(&buf);
    try std.testing.expectEqual(@as(u64, 1_000_000_000), mint.supply);
    try std.testing.expectEqual(@as(u8, 9), mint.decimals);
    try std.testing.expect(mint.mintAuthority() != null);
    try std.testing.expect(mint.freezeAuthority() == null);
    const expected: Pubkey = .{0x01} ** 32;
    try std.testing.expectEqualSlices(u8, &expected, mint.mintAuthority().?);
}

test "account: fromBytes rejects wrong length" {
    const buf = [_]u8{0} ** (ACCOUNT_LEN + 1);
    try std.testing.expectError(error.InvalidAccountData, Account.fromBytes(&buf));
}

test "account: state + isNative round-trip" {
    var buf: [ACCOUNT_LEN]u8 = [_]u8{0} ** ACCOUNT_LEN;
    @memset(buf[0..32], 0xAA); // mint
    @memset(buf[32..64], 0xBB); // owner
    std.mem.writeInt(u64, buf[64..72], 42, .little); // amount
    std.mem.writeInt(u32, buf[72..76], COPTION_NONE, .little); // delegate
    buf[108] = @intFromEnum(AccountState.frozen);
    std.mem.writeInt(u32, buf[109..113], COPTION_SOME, .little);
    std.mem.writeInt(u64, buf[113..121], 2_039_280, .little); // wSOL rent reserve

    const acc = try Account.fromBytes(&buf);
    try std.testing.expectEqual(@as(u64, 42), acc.amount);
    try std.testing.expect(acc.isFrozen());
    try std.testing.expect(acc.isNative());
    try std.testing.expectEqual(@as(u64, 2_039_280), acc.is_native_rent_exempt_reserve);
    try std.testing.expect(acc.delegateKey() == null);
}
