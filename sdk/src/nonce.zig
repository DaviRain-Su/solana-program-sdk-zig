//! Zig implementation of Solana SDK's nonce module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/nonce/src/lib.rs
//!
//! Durable transaction nonces allow transactions to be valid indefinitely,
//! rather than expiring after ~2 minutes like regular transactions.
//!
//! ## Key Types
//! - `DurableNonce` - A hash value used as recent_blockhash in durable transactions
//! - `Data` - Initialized nonce account data (authority, nonce, fee info)
//! - `State` - Nonce account state (Uninitialized or Initialized)
//! - `Versions` - Version wrapper supporting Legacy and Current formats
//!
//! ## Usage
//! Durable nonces are useful for:
//! - Offline transaction signing
//! - Multi-signature workflows
//! - Scheduled transactions
//!
//! The nonce account stores a `DurableNonce` value that replaces the
//! `recent_blockhash` field in transactions.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const Hash = @import("hash.zig").Hash;

// ============================================================================
// Constants
// ============================================================================

/// The size of a serialized nonce account state (80 bytes)
///
/// Rust equivalent: `State::size()`
pub const NONCE_ACCOUNT_LENGTH: usize = 80;

/// Index of the nonce instruction in a nonced transaction
///
/// In a durable nonce transaction, the first instruction must be
/// the `AdvanceNonceAccount` instruction.
pub const NONCED_TX_MARKER_IX_INDEX: u8 = 0;

/// Prefix used for deriving durable nonce from blockhash
const DURABLE_NONCE_HASH_PREFIX: []const u8 = "DURABLE_NONCE";

// ============================================================================
// DurableNonce
// ============================================================================

/// A durable nonce value derived from a blockhash.
///
/// This is used as the `recent_blockhash` field in durable transactions.
/// Unlike regular blockhashes, durable nonces don't expire.
///
/// Rust equivalent: `solana_nonce::state::DurableNonce`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/nonce/src/state.rs
pub const DurableNonce = struct {
    hash: Hash,

    /// Create a DurableNonce from a blockhash.
    ///
    /// The durable nonce is derived by hashing the prefix + blockhash.
    pub fn fromBlockhash(blockhash: Hash) DurableNonce {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(DURABLE_NONCE_HASH_PREFIX);
        hasher.update(&blockhash.bytes);
        const result = hasher.finalResult();
        return .{ .hash = Hash.from(result) };
    }

    /// Get the hash value used as recent_blockhash in transactions.
    pub fn asHash(self: DurableNonce) Hash {
        return self.hash;
    }

    /// Create from raw hash bytes
    pub fn from(hash: Hash) DurableNonce {
        return .{ .hash = hash };
    }

    /// Create default (zero) durable nonce
    pub fn default() DurableNonce {
        return .{ .hash = Hash.default() };
    }

    /// Check equality
    pub fn equals(self: DurableNonce, other: DurableNonce) bool {
        return std.mem.eql(u8, &self.hash.bytes, &other.hash.bytes);
    }
};

// ============================================================================
// FeeCalculator (simplified)
// ============================================================================

/// Fee calculator for nonce transactions.
///
/// This is a simplified version that only tracks lamports_per_signature.
///
/// Rust equivalent: `solana_fee_calculator::FeeCalculator`
pub const FeeCalculator = struct {
    /// The current cost of a signature in lamports.
    lamports_per_signature: u64,

    pub fn init(lamports_per_signature: u64) FeeCalculator {
        return .{ .lamports_per_signature = lamports_per_signature };
    }

    pub fn default() FeeCalculator {
        return .{ .lamports_per_signature = 0 };
    }
};

// ============================================================================
// Data
// ============================================================================

/// Initialized data of a durable transaction nonce account.
///
/// Rust equivalent: `solana_nonce::state::Data`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/nonce/src/state.rs
pub const Data = struct {
    /// Address of the account that signs transactions using the nonce account.
    authority: PublicKey,

    /// Durable nonce value derived from a valid previous blockhash.
    durable_nonce: DurableNonce,

    /// The fee calculator associated with the blockhash.
    fee_calculator: FeeCalculator,

    /// Create new durable transaction nonce data.
    pub fn init(
        authority: PublicKey,
        durable_nonce: DurableNonce,
        lamports_per_signature: u64,
    ) Data {
        return .{
            .authority = authority,
            .durable_nonce = durable_nonce,
            .fee_calculator = FeeCalculator.init(lamports_per_signature),
        };
    }

    /// Create default (zero) data
    pub fn default() Data {
        return .{
            .authority = PublicKey.default(),
            .durable_nonce = DurableNonce.default(),
            .fee_calculator = FeeCalculator.default(),
        };
    }

    /// Hash value used as recent_blockhash field in Transactions.
    pub fn blockhash(self: Data) Hash {
        return self.durable_nonce.asHash();
    }

    /// Get the cost per signature for the next transaction to use this nonce.
    pub fn getLamportsPerSignature(self: Data) u64 {
        return self.fee_calculator.lamports_per_signature;
    }
};

// ============================================================================
// State
// ============================================================================

/// The state of a durable transaction nonce account.
///
/// Rust equivalent: `solana_nonce::state::State`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/nonce/src/state.rs
pub const State = union(enum) {
    /// Account is not initialized
    uninitialized: void,

    /// Account is initialized with nonce data
    initialized: Data,

    /// Create new initialized state.
    pub fn newInitialized(
        authority: PublicKey,
        durable_nonce: DurableNonce,
        lamports_per_signature: u64,
    ) State {
        return .{
            .initialized = Data.init(authority, durable_nonce, lamports_per_signature),
        };
    }

    /// Create default (uninitialized) state
    pub fn default() State {
        return .uninitialized;
    }

    /// Get the serialized size of the nonce state (always 80 bytes).
    pub fn size() usize {
        return NONCE_ACCOUNT_LENGTH;
    }

    /// Check if the state is initialized
    pub fn isInitialized(self: State) bool {
        return self == .initialized;
    }

    /// Get the data if initialized, null otherwise
    pub fn getData(self: State) ?Data {
        return switch (self) {
            .initialized => |data| data,
            .uninitialized => null,
        };
    }
};

// ============================================================================
// Versions
// ============================================================================

/// Versioned nonce state.
///
/// Supports both Legacy and Current nonce formats. Legacy nonces used
/// blockhashes directly, while Current nonces use derived durable nonces.
///
/// Rust equivalent: `solana_nonce::versions::Versions`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/nonce/src/versions.rs
pub const Versions = union(enum) {
    /// Legacy nonces (deprecated, cannot verify durable transactions)
    legacy: State,

    /// Current nonces with separate durable nonce domain
    current: State,

    /// Create a new Current version nonce
    pub fn init(state_data: State) Versions {
        return .{ .current = state_data };
    }

    /// Get the inner state regardless of version
    pub fn state(self: Versions) State {
        return switch (self) {
            .legacy => |s| s,
            .current => |s| s,
        };
    }

    /// Checks if the recent_blockhash field in Transaction verifies,
    /// and returns nonce account data if so.
    ///
    /// Legacy nonces always return null (cannot verify durable transactions).
    pub fn verifyRecentBlockhash(self: Versions, recent_blockhash: Hash) ?Data {
        return switch (self) {
            // Legacy durable nonces are invalid and should not
            // allow durable transactions.
            .legacy => null,
            .current => |s| switch (s) {
                .uninitialized => null,
                .initialized => |data| blk: {
                    if (std.mem.eql(u8, &recent_blockhash.bytes, &data.blockhash().bytes)) {
                        break :blk data;
                    }
                    break :blk null;
                },
            },
        };
    }

    /// Upgrades legacy nonces out of chain blockhash domains.
    ///
    /// Returns the upgraded version if successful, null if already current
    /// or if the legacy nonce is uninitialized.
    pub fn upgrade(self: Versions) ?Versions {
        return switch (self) {
            .legacy => |s| switch (s) {
                // An Uninitialized legacy nonce cannot verify a durable
                // transaction. No need to upgrade.
                .uninitialized => null,
                .initialized => |data| blk: {
                    // Re-derive the durable nonce from its own blockhash
                    const new_durable_nonce = DurableNonce.fromBlockhash(data.blockhash());
                    const new_data = Data.init(
                        data.authority,
                        new_durable_nonce,
                        data.getLamportsPerSignature(),
                    );
                    break :blk Versions{ .current = .{ .initialized = new_data } };
                },
            },
            .current => null, // Already current
        };
    }

    /// Check if this is a legacy version
    pub fn isLegacy(self: Versions) bool {
        return self == .legacy;
    }

    /// Check if this is a current version
    pub fn isCurrent(self: Versions) bool {
        return self == .current;
    }
};

// ============================================================================
// Serialization
// ============================================================================

/// Serialize nonce Versions to bytes (bincode format).
///
/// Layout (80 bytes total):
/// - 4 bytes: version discriminant (0 = Legacy, 1 = Current)
/// - 4 bytes: state discriminant (0 = Uninitialized, 1 = Initialized)
/// - If initialized:
///   - 32 bytes: authority pubkey
///   - 32 bytes: durable_nonce hash
///   - 8 bytes: lamports_per_signature
///
/// Returns error.InvalidAccountData if buffer length is not exactly 80 bytes.
/// This matches Rust SDK behavior which requires exact size.
pub fn serialize(versions: Versions, buffer: []u8) !void {
    if (buffer.len != NONCE_ACCOUNT_LENGTH) {
        return error.InvalidAccountData;
    }

    var offset: usize = 0;

    // Version discriminant
    const version_tag: u32 = switch (versions) {
        .legacy => 0,
        .current => 1,
    };
    std.mem.writeInt(u32, buffer[offset..][0..4], version_tag, .little);
    offset += 4;

    // State
    const state = versions.state();

    // State discriminant
    const state_tag: u32 = switch (state) {
        .uninitialized => 0,
        .initialized => 1,
    };
    std.mem.writeInt(u32, buffer[offset..][0..4], state_tag, .little);
    offset += 4;

    // Data (if initialized)
    switch (state) {
        .uninitialized => {
            // Fill remaining with zeros
            @memset(buffer[offset..NONCE_ACCOUNT_LENGTH], 0);
        },
        .initialized => |data| {
            // Authority (32 bytes)
            @memcpy(buffer[offset..][0..32], &data.authority.bytes);
            offset += 32;

            // Durable nonce (32 bytes)
            @memcpy(buffer[offset..][0..32], &data.durable_nonce.hash.bytes);
            offset += 32;

            // Lamports per signature (8 bytes)
            std.mem.writeInt(u64, buffer[offset..][0..8], data.fee_calculator.lamports_per_signature, .little);
        },
    }
}

/// Deserialize nonce Versions from bytes.
///
/// Returns error.InvalidAccountData if buffer length is not exactly 80 bytes.
/// This matches Rust SDK behavior which requires exact size to prevent
/// misinterpreting extended account data or truncated data.
pub fn deserialize(buffer: []const u8) !Versions {
    if (buffer.len != NONCE_ACCOUNT_LENGTH) {
        return error.InvalidAccountData;
    }

    var offset: usize = 0;

    // Version discriminant
    const version_tag = std.mem.readInt(u32, buffer[offset..][0..4], .little);
    offset += 4;

    // State discriminant
    const state_tag = std.mem.readInt(u32, buffer[offset..][0..4], .little);
    offset += 4;

    const state: State = switch (state_tag) {
        0 => .uninitialized,
        1 => blk: {
            // Authority
            var authority_bytes: [32]u8 = undefined;
            @memcpy(&authority_bytes, buffer[offset..][0..32]);
            const authority = PublicKey.from(authority_bytes);
            offset += 32;

            // Durable nonce
            var nonce_bytes: [32]u8 = undefined;
            @memcpy(&nonce_bytes, buffer[offset..][0..32]);
            const durable_nonce = DurableNonce.from(Hash.from(nonce_bytes));
            offset += 32;

            // Lamports per signature
            const lamports = std.mem.readInt(u64, buffer[offset..][0..8], .little);

            break :blk State{
                .initialized = Data.init(authority, durable_nonce, lamports),
            };
        },
        else => return error.InvalidAccountData,
    };

    return switch (version_tag) {
        0 => Versions{ .legacy = state },
        1 => Versions{ .current = state },
        else => error.InvalidAccountData,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "nonce: NONCE_ACCOUNT_LENGTH constant" {
    try std.testing.expectEqual(@as(usize, 80), NONCE_ACCOUNT_LENGTH);
    try std.testing.expectEqual(@as(usize, 80), State.size());
}

test "nonce: DurableNonce from blockhash" {
    const blockhash = Hash.from([_]u8{0xAB} ** 32);
    const durable_nonce = DurableNonce.fromBlockhash(blockhash);

    // The derived nonce should be different from the original blockhash
    try std.testing.expect(!std.mem.eql(u8, &blockhash.bytes, &durable_nonce.hash.bytes));

    // Should be deterministic
    const durable_nonce2 = DurableNonce.fromBlockhash(blockhash);
    try std.testing.expect(durable_nonce.equals(durable_nonce2));
}

test "nonce: Data creation and accessors" {
    const authority = PublicKey.from([_]u8{1} ** 32);
    const blockhash = Hash.from([_]u8{2} ** 32);
    const durable_nonce = DurableNonce.fromBlockhash(blockhash);

    const data = Data.init(authority, durable_nonce, 5000);

    try std.testing.expect(data.authority.equals(authority));
    try std.testing.expectEqual(@as(u64, 5000), data.getLamportsPerSignature());
    try std.testing.expect(std.mem.eql(u8, &data.blockhash().bytes, &durable_nonce.hash.bytes));
}

test "nonce: State default is uninitialized" {
    const state = State.default();
    try std.testing.expect(!state.isInitialized());
    try std.testing.expect(state.getData() == null);
}

test "nonce: State initialized" {
    const authority = PublicKey.from([_]u8{1} ** 32);
    const durable_nonce = DurableNonce.default();

    const state = State.newInitialized(authority, durable_nonce, 1000);

    try std.testing.expect(state.isInitialized());
    const data = state.getData().?;
    try std.testing.expect(data.authority.equals(authority));
}

test "nonce: Versions creation" {
    const state = State.default();
    const versions = Versions.init(state);

    try std.testing.expect(versions.isCurrent());
    try std.testing.expect(!versions.isLegacy());
}

test "nonce: Versions verify_recent_blockhash" {
    const authority = PublicKey.from([_]u8{1} ** 32);
    const blockhash = Hash.from([_]u8{2} ** 32);
    const durable_nonce = DurableNonce.fromBlockhash(blockhash);

    const state = State.newInitialized(authority, durable_nonce, 1000);

    // Legacy versions should not verify
    const legacy = Versions{ .legacy = state };
    try std.testing.expect(legacy.verifyRecentBlockhash(durable_nonce.asHash()) == null);

    // Current versions should verify with matching blockhash
    const current = Versions{ .current = state };
    const verified = current.verifyRecentBlockhash(durable_nonce.asHash());
    try std.testing.expect(verified != null);
    try std.testing.expect(verified.?.authority.equals(authority));

    // Should not verify with wrong blockhash
    const wrong_hash = Hash.from([_]u8{0xFF} ** 32);
    try std.testing.expect(current.verifyRecentBlockhash(wrong_hash) == null);
}

test "nonce: Versions upgrade" {
    const authority = PublicKey.from([_]u8{1} ** 32);
    const blockhash = Hash.from([_]u8{2} ** 32);
    const durable_nonce = DurableNonce.from(blockhash); // Legacy uses blockhash directly

    const state = State.newInitialized(authority, durable_nonce, 1000);

    // Uninitialized legacy cannot be upgraded
    const uninit_legacy = Versions{ .legacy = .uninitialized };
    try std.testing.expect(uninit_legacy.upgrade() == null);

    // Initialized legacy can be upgraded
    const init_legacy = Versions{ .legacy = state };
    const upgraded = init_legacy.upgrade();
    try std.testing.expect(upgraded != null);
    try std.testing.expect(upgraded.?.isCurrent());

    // Current cannot be upgraded
    const current = Versions{ .current = state };
    try std.testing.expect(current.upgrade() == null);
}

test "nonce: serialize and deserialize" {
    const authority = PublicKey.from([_]u8{0xAA} ** 32);
    const blockhash = Hash.from([_]u8{0xBB} ** 32);
    const durable_nonce = DurableNonce.fromBlockhash(blockhash);

    const state = State.newInitialized(authority, durable_nonce, 12345);
    const versions = Versions.init(state);

    var buffer: [NONCE_ACCOUNT_LENGTH]u8 = undefined;
    try serialize(versions, &buffer);

    const deserialized = try deserialize(&buffer);

    try std.testing.expect(deserialized.isCurrent());
    const data = deserialized.state().getData().?;
    try std.testing.expect(data.authority.equals(authority));
    try std.testing.expect(data.durable_nonce.equals(durable_nonce));
    try std.testing.expectEqual(@as(u64, 12345), data.getLamportsPerSignature());
}

test "nonce: serialize and deserialize uninitialized" {
    const state = State.default();
    const versions = Versions.init(state);

    var buffer: [NONCE_ACCOUNT_LENGTH]u8 = undefined;
    try serialize(versions, &buffer);

    const deserialized = try deserialize(&buffer);

    try std.testing.expect(deserialized.isCurrent());
    try std.testing.expect(!deserialized.state().isInitialized());
}

test "nonce: serialize legacy version" {
    const authority = PublicKey.from([_]u8{0x11} ** 32);
    const durable_nonce = DurableNonce.default();

    const state = State.newInitialized(authority, durable_nonce, 999);
    const versions = Versions{ .legacy = state };

    var buffer: [NONCE_ACCOUNT_LENGTH]u8 = undefined;
    try serialize(versions, &buffer);

    const deserialized = try deserialize(&buffer);

    try std.testing.expect(deserialized.isLegacy());
    const data = deserialized.state().getData().?;
    try std.testing.expect(data.authority.equals(authority));
}

test "nonce: serialize rejects wrong buffer size" {
    const state = State.default();
    const versions = Versions.init(state);

    // Buffer too small
    var small_buffer: [NONCE_ACCOUNT_LENGTH - 1]u8 = undefined;
    try std.testing.expectError(error.InvalidAccountData, serialize(versions, &small_buffer));

    // Buffer too large
    var large_buffer: [NONCE_ACCOUNT_LENGTH + 1]u8 = undefined;
    try std.testing.expectError(error.InvalidAccountData, serialize(versions, &large_buffer));

    // Exact size should work
    var exact_buffer: [NONCE_ACCOUNT_LENGTH]u8 = undefined;
    try serialize(versions, &exact_buffer);
}

test "nonce: deserialize rejects wrong buffer size" {
    // Create valid serialized data first
    const state = State.default();
    const versions = Versions.init(state);
    var valid_buffer: [NONCE_ACCOUNT_LENGTH]u8 = undefined;
    try serialize(versions, &valid_buffer);

    // Buffer too small
    try std.testing.expectError(error.InvalidAccountData, deserialize(valid_buffer[0 .. NONCE_ACCOUNT_LENGTH - 1]));

    // Buffer too large (with extra trailing data)
    var large_buffer: [NONCE_ACCOUNT_LENGTH + 10]u8 = undefined;
    @memcpy(large_buffer[0..NONCE_ACCOUNT_LENGTH], &valid_buffer);
    @memset(large_buffer[NONCE_ACCOUNT_LENGTH..], 0xFF); // trailing garbage
    try std.testing.expectError(error.InvalidAccountData, deserialize(&large_buffer));

    // Exact size should work
    _ = try deserialize(&valid_buffer);
}
