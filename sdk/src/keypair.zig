//! Zig implementation of Solana SDK's keypair module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/keypair/src/lib.rs
//!
//! This module provides the Keypair type for Ed25519 key pair management,
//! including key generation, signing, and serialization.

const std = @import("std");
const base58 = @import("base58");

const PublicKey = @import("public_key.zig").PublicKey;
const Signature = @import("signature.zig").Signature;
const SIGNATURE_BYTES = @import("signature.zig").SIGNATURE_BYTES;

const Ed25519 = std.crypto.sign.Ed25519;

/// Number of bytes in a keypair (secret key which includes seed + public key)
/// Rust equivalent: `KEYPAIR_LENGTH`
pub const KEYPAIR_LENGTH: usize = 64;

/// Number of bytes in a seed (used to derive the keypair)
/// Rust equivalent: `Keypair::SECRET_KEY_LENGTH`
pub const SECRET_KEY_LENGTH: usize = 32;

/// An Ed25519 key pair for signing Solana transactions
///
/// Rust equivalent: `solana_keypair::Keypair`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/keypair/src/lib.rs
pub const Keypair = struct {
    /// The Ed25519 key pair from Zig's crypto library
    inner: Ed25519.KeyPair,

    /// Constructs a new, random `Keypair` using system randomness
    /// Rust equivalent: `Keypair::new()`
    pub fn generate() Keypair {
        const kp = Ed25519.KeyPair.generate();
        return .{ .inner = kp };
    }

    /// Constructs a new `Keypair` from a 32-byte seed
    /// Rust equivalent: `Keypair::new_from_array()` / `keypair_from_seed()`
    pub fn fromSeed(seed_bytes: [SECRET_KEY_LENGTH]u8) !Keypair {
        const kp = Ed25519.KeyPair.generateDeterministic(seed_bytes) catch {
            return error.InvalidSeed;
        };
        return .{ .inner = kp };
    }

    /// Constructs a `Keypair` from a seed slice (first 32 bytes used)
    /// Rust equivalent: `keypair_from_seed()`
    pub fn fromSeedSlice(seed_slice: []const u8) !Keypair {
        if (seed_slice.len < SECRET_KEY_LENGTH) {
            return error.SeedTooShort;
        }
        var seed_array: [SECRET_KEY_LENGTH]u8 = undefined;
        @memcpy(&seed_array, seed_slice[0..SECRET_KEY_LENGTH]);
        return fromSeed(seed_array);
    }

    /// Constructs a `Keypair` from 64 bytes (seed + public key format)
    ///
    /// The 64 bytes are expected in Solana's standard format:
    /// - bytes[0..32]: seed (private key seed)
    /// - bytes[32..64]: public key
    ///
    /// This function validates that the public key in bytes[32..64] matches
    /// the public key derived from the seed in bytes[0..32]. This matches
    /// Rust's ed25519-dalek `Keypair::from_bytes` behavior which returns
    /// an error if the embedded public key doesn't match.
    ///
    /// Rust equivalent: `Keypair::try_from(&[u8])` / `Keypair::from_bytes()`
    pub fn fromBytes(bytes: []const u8) !Keypair {
        if (bytes.len != KEYPAIR_LENGTH) {
            return error.InvalidKeypairLength;
        }

        // Extract seed (first 32 bytes) and embedded public key (last 32 bytes)
        var seed_bytes: [SECRET_KEY_LENGTH]u8 = undefined;
        @memcpy(&seed_bytes, bytes[0..SECRET_KEY_LENGTH]);

        var embedded_pubkey: [32]u8 = undefined;
        @memcpy(&embedded_pubkey, bytes[SECRET_KEY_LENGTH..KEYPAIR_LENGTH]);

        // Generate keypair from seed
        const kp = Ed25519.KeyPair.generateDeterministic(seed_bytes) catch {
            return error.InvalidSeed;
        };

        // Validate that the embedded public key matches the derived public key
        // This is critical for security - matches Rust's ed25519-dalek behavior
        const derived_pubkey = kp.public_key.toBytes();
        if (!std.mem.eql(u8, &embedded_pubkey, &derived_pubkey)) {
            return error.PublicKeyMismatch;
        }

        return .{ .inner = kp };
    }

    /// Returns this `Keypair` as a 64-byte array (seed + public key)
    /// Rust equivalent: `Keypair::to_bytes()`
    pub fn toBytes(self: Keypair) [KEYPAIR_LENGTH]u8 {
        return self.inner.secret_key.toBytes();
    }

    /// Gets this `Keypair`'s seed (first 32 bytes of secret key)
    /// Rust equivalent: `Keypair::secret_bytes()` (returns seed portion)
    pub fn seed(self: Keypair) [SECRET_KEY_LENGTH]u8 {
        return self.inner.secret_key.seed();
    }

    /// Gets this `Keypair`'s public key as a `PublicKey`
    /// Rust equivalent: `Keypair::pubkey()`
    pub fn pubkey(self: Keypair) PublicKey {
        return PublicKey.from(self.inner.public_key.toBytes());
    }

    /// Signs a message with this keypair
    ///
    /// Returns a `Signature` on success, or an error if signing fails.
    /// In practice, signing only fails if the keypair is invalid (which shouldn't
    /// happen if the keypair was properly constructed).
    ///
    /// Rust equivalent: `Keypair::sign_message()` / `Signer::sign_message()`
    pub fn sign(self: Keypair, message: []const u8) !Signature {
        const sig = self.inner.sign(message, null) catch {
            return error.SigningFailed;
        };
        return Signature.from(sig.toBytes());
    }

    /// Recovers a `Keypair` from a base58-encoded string
    /// Rust equivalent: `Keypair::from_base58_string()`
    pub fn fromBase58(str: []const u8) !Keypair {
        var buffer: [KEYPAIR_LENGTH]u8 = undefined;
        const decoded = base58.bitcoin.decode(&buffer, str) catch {
            return error.InvalidBase58;
        };
        if (decoded.len != KEYPAIR_LENGTH) {
            return error.InvalidKeypairLength;
        }
        return fromBytes(&buffer);
    }

    /// Returns this `Keypair` as a base58-encoded string
    /// Rust equivalent: `Keypair::to_base58_string()`
    pub fn toBase58(self: Keypair, buffer: *[base58.bitcoin.getEncodedLengthUpperBound(KEYPAIR_LENGTH)]u8) []const u8 {
        const bytes = self.toBytes();
        return base58.bitcoin.encode(buffer, &bytes);
    }

    /// Allows Keypair cloning
    ///
    /// Note: Making a second copy of sensitive secret keys in memory is usually
    /// a bad idea. Only use this in tests or when strictly required.
    ///
    /// Rust equivalent: `Keypair::insecure_clone()`
    pub fn insecureClone(self: Keypair) Keypair {
        return .{ .inner = self.inner };
    }

    /// Securely zeroize the secret key memory
    /// Call this when done with the keypair to prevent secret key leakage
    pub fn zeroize(self: *Keypair) void {
        std.crypto.utils.secureZero(u8, &self.inner.secret_key.bytes);
    }

    // =========================================================================
    // Rust API compatibility aliases
    // =========================================================================

    /// Rust compatibility alias for `generate`
    /// Rust equivalent: `Keypair::new()`
    pub const new = generate;

    /// Rust compatibility alias for `fromSeed`
    /// Rust equivalent: `keypair_from_seed()`
    pub const fromSeedBytes = fromSeed;

    /// Rust compatibility alias for `fromBase58`
    /// Rust equivalent: `Keypair::from_base58_string()`
    pub const fromBase58String = fromBase58;

    /// Rust compatibility alias for `toBase58`
    /// Rust equivalent: `Keypair::to_base58_string()`
    pub const toBase58String = toBase58;

    /// Alias for secret() that returns the seed portion
    /// Rust equivalent: `Keypair::secret()` returns reference to secret key
    pub const secret = seed;

    /// Rust compatibility alias for `sign`
    /// Rust equivalent: `Keypair::sign_message()` / `Signer::sign_message()`
    pub const signMessage = sign;

    /// Rust compatibility alias: try_pubkey returns Result in Rust
    /// In Zig, pubkey() is infallible for valid keypairs
    pub const tryPubkey = pubkey;
};

// ============================================================================
// Tests - Matching Rust: https://github.com/anza-xyz/solana-sdk/blob/master/keypair/src/lib.rs
// ============================================================================

test "keypair: generate creates valid keypair" {
    const kp = Keypair.generate();
    const pubkey = kp.pubkey();

    // Public key should be 32 bytes
    try std.testing.expectEqual(@as(usize, 32), pubkey.bytes.len);

    // Keypair bytes should be 64 bytes
    const bytes = kp.toBytes();
    try std.testing.expectEqual(@as(usize, KEYPAIR_LENGTH), bytes.len);
}

test "keypair: generate creates unique keypairs" {
    const kp1 = Keypair.generate();
    const kp2 = Keypair.generate();

    // Two generated keypairs should be different
    try std.testing.expect(!kp1.pubkey().equals(kp2.pubkey()));
}

// Rust test: test_keypair_from_seed
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/keypair/src/lib.rs
test "keypair: from seed" {
    const good_seed = [_]u8{0} ** 32;
    const kp = try Keypair.fromSeed(good_seed);
    _ = kp.pubkey();

    // Too short seed should fail
    const too_short_seed = [_]u8{0} ** 31;
    try std.testing.expectError(error.SeedTooShort, Keypair.fromSeedSlice(&too_short_seed));
}

// Rust test: test_keypair
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/keypair/src/lib.rs
test "keypair: sign and verify" {
    const seed = [_]u8{0} ** 32;
    const kp = try Keypair.fromSeed(seed);
    const pubkey = kp.pubkey();

    const message = [_]u8{1};
    const sig = try kp.sign(&message);

    // Signature should be valid
    try sig.verify(&message, &pubkey.bytes);

    // Same keypair from same seed should produce same signature
    const kp2 = try Keypair.fromSeed(seed);
    const sig2 = try kp2.sign(&message);
    try std.testing.expectEqualSlices(u8, sig.asBytes(), sig2.asBytes());
}

// Rust test: test_base58
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/keypair/src/lib.rs
test "keypair: base58 roundtrip" {
    const seed = [_]u8{0} ** 32;
    const kp = try Keypair.fromSeed(seed);

    var buffer: [base58.bitcoin.getEncodedLengthUpperBound(KEYPAIR_LENGTH)]u8 = undefined;
    const as_base58 = kp.toBase58(&buffer);

    const parsed = try Keypair.fromBase58(as_base58);

    // Should have same public key
    try std.testing.expect(kp.pubkey().equals(parsed.pubkey()));

    // Should have same bytes
    try std.testing.expectEqualSlices(u8, &kp.toBytes(), &parsed.toBytes());
}

test "keypair: from bytes roundtrip" {
    const kp = Keypair.generate();
    const bytes = kp.toBytes();

    const restored = try Keypair.fromBytes(&bytes);

    try std.testing.expect(kp.pubkey().equals(restored.pubkey()));
    try std.testing.expectEqualSlices(u8, &kp.toBytes(), &restored.toBytes());
}

test "keypair: from bytes with invalid length" {
    const short_bytes = [_]u8{0} ** 32;
    try std.testing.expectError(error.InvalidKeypairLength, Keypair.fromBytes(&short_bytes));
}

// Rust test: Keypair::from_bytes rejects mismatched public key
// This matches ed25519-dalek behavior where the embedded public key must match
// the public key derived from the seed
test "keypair: from bytes rejects mismatched public key" {
    // Create a valid keypair
    const valid_kp = Keypair.generate();
    var bytes = valid_kp.toBytes();

    // Corrupt the public key portion (last 32 bytes)
    bytes[63] ^= 0xFF;
    bytes[32] ^= 0x01;

    // Should fail with PublicKeyMismatch
    try std.testing.expectError(error.PublicKeyMismatch, Keypair.fromBytes(&bytes));
}

test "keypair: from bytes rejects completely wrong public key" {
    // Create bytes with valid seed but completely different public key
    const seed = [_]u8{42} ** 32;
    const wrong_pubkey = [_]u8{0} ** 32;

    var bytes: [KEYPAIR_LENGTH]u8 = undefined;
    @memcpy(bytes[0..32], &seed);
    @memcpy(bytes[32..64], &wrong_pubkey);

    // Should fail with PublicKeyMismatch
    try std.testing.expectError(error.PublicKeyMismatch, Keypair.fromBytes(&bytes));
}

test "keypair: fromBase58 rejects mismatched public key" {
    // Create valid keypair and get its bytes
    const valid_kp = Keypair.generate();
    var bytes = valid_kp.toBytes();

    // Corrupt the public key
    bytes[63] ^= 0xFF;

    // Encode corrupted bytes to base58
    var encode_buffer: [base58.bitcoin.getEncodedLengthUpperBound(KEYPAIR_LENGTH)]u8 = undefined;
    const corrupted_base58 = base58.bitcoin.encode(&encode_buffer, &bytes);

    // fromBase58 should fail with PublicKeyMismatch
    try std.testing.expectError(error.PublicKeyMismatch, Keypair.fromBase58(corrupted_base58));
}

test "keypair: insecure clone" {
    const original = Keypair.generate();
    const cloned = original.insecureClone();

    try std.testing.expect(original.pubkey().equals(cloned.pubkey()));
    try std.testing.expectEqualSlices(u8, &original.toBytes(), &cloned.toBytes());
}

test "keypair: seed accessor" {
    const seed = [_]u8{42} ** 32;
    const kp = try Keypair.fromSeed(seed);

    const retrieved_seed = kp.seed();
    try std.testing.expectEqualSlices(u8, &seed, &retrieved_seed);
}

// ============================================================================
// Rust API compatibility alias tests
// ============================================================================

test "keypair: Rust API aliases" {
    // Test new() alias for generate()
    const kp1 = Keypair.new();
    try std.testing.expect(kp1.pubkey().bytes.len == 32);

    // Test fromSeedBytes() alias
    const seed = [_]u8{1} ** 32;
    const kp2 = try Keypair.fromSeedBytes(seed);
    try std.testing.expectEqualSlices(u8, &seed, &kp2.seed());

    // Test secret() alias for seed()
    try std.testing.expectEqualSlices(u8, &kp2.seed(), &kp2.secret());

    // Test signMessage() alias for sign()
    const message = "test message";
    const sig1 = try kp2.sign(message);
    const sig2 = try kp2.signMessage(message);
    try std.testing.expectEqualSlices(u8, &sig1.bytes, &sig2.bytes);

    // Test tryPubkey() alias for pubkey()
    try std.testing.expect(kp2.pubkey().equals(kp2.tryPubkey()));

    // Test fromBase58String() and toBase58String() aliases
    var buffer: [base58.bitcoin.getEncodedLengthUpperBound(KEYPAIR_LENGTH)]u8 = undefined;
    const as_base58 = kp2.toBase58String(&buffer);
    const parsed = try Keypair.fromBase58String(as_base58);
    try std.testing.expect(kp2.pubkey().equals(parsed.pubkey()));
}
