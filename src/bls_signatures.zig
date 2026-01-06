//! Zig implementation of Solana SDK's BLS signatures module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/tree/master/bls-signatures
//!
//! This module provides BLS12-381 signature types for Solana validator consensus.
//! BLS (Boneh-Lynn-Shacham) signatures enable efficient signature aggregation
//! and are used in Solana's consensus mechanism.
//!
//! ## On-chain Limitations
//!
//! This module only provides byte representations of BLS cryptographic types.
//! Actual cryptographic operations (key generation, signing, verification)
//! must be performed off-chain using the Rust SDK or other BLS libraries.
//!
//! ## Type Sizes
//!
//! | Type | Compressed | Affine | Description |
//! |------|------------|--------|-------------|
//! | Public Key | 48 bytes | 96 bytes | G1 point |
//! | Signature | 96 bytes | 192 bytes | G2 point |
//! | Proof of Possession | 96 bytes | 192 bytes | G2 point |
//!
//! ## Usage
//!
//! ```zig
//! const bls = @import("bls_signatures.zig");
//!
//! // Store a BLS public key received from off-chain
//! var pubkey = bls.Pubkey.default();
//! @memcpy(&pubkey.bytes, received_pubkey_bytes);
//!
//! // Store a compressed signature
//! var sig = bls.SignatureCompressed.new(signature_bytes);
//! ```

const std = @import("std");

// ============================================================================
// Size Constants
// ============================================================================

/// Size of a BLS public key in compressed point representation (G1 point)
pub const BLS_PUBLIC_KEY_COMPRESSED_SIZE: usize = 48;

/// Size of a BLS public key in affine point representation (G1 point)
pub const BLS_PUBLIC_KEY_AFFINE_SIZE: usize = 96;

/// Size of a BLS signature in compressed point representation (G2 point)
pub const BLS_SIGNATURE_COMPRESSED_SIZE: usize = 96;

/// Size of a BLS signature in affine point representation (G2 point)
pub const BLS_SIGNATURE_AFFINE_SIZE: usize = 192;

/// Size of a BLS proof of possession in compressed point representation (G2 point)
pub const BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE: usize = 96;

/// Size of a BLS proof of possession in affine point representation (G2 point)
pub const BLS_PROOF_OF_POSSESSION_AFFINE_SIZE: usize = 192;

/// Domain separation tag used when hashing public keys to G2 in the proof of
/// possession signing and verification functions.
/// See: https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-bls-signature-05#section-4.2.3
pub const POP_DST: []const u8 = "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_";

// ============================================================================
// Error Types
// ============================================================================

/// Errors that can occur during BLS operations
///
/// Rust equivalent: `solana_bls_signatures::BlsError`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/bls-signatures/src/error.rs
pub const BlsError = error{
    /// Field element decoding failed
    FieldDecode,
    /// Attempted to aggregate an empty set of elements
    EmptyAggregation,
    /// Key derivation failed
    KeyDerivation,
    /// Point representation conversion failed
    PointConversion,
    /// Failed to parse from string representation
    ParseFromString,
    /// Failed to parse from byte representation
    ParseFromBytes,
    /// The lengths of input iterators do not match
    InputLengthMismatch,
};

// ============================================================================
// Base64 Encoding (for Display)
// ============================================================================

const base64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

fn base64Encode(input: []const u8, output: []u8) usize {
    var out_idx: usize = 0;
    var i: usize = 0;

    while (i + 3 <= input.len) : (i += 3) {
        const b0 = input[i];
        const b1 = input[i + 1];
        const b2 = input[i + 2];

        output[out_idx] = base64_alphabet[b0 >> 2];
        output[out_idx + 1] = base64_alphabet[((b0 & 0x03) << 4) | (b1 >> 4)];
        output[out_idx + 2] = base64_alphabet[((b1 & 0x0F) << 2) | (b2 >> 6)];
        output[out_idx + 3] = base64_alphabet[b2 & 0x3F];
        out_idx += 4;
    }

    const remaining = input.len - i;
    if (remaining == 1) {
        const b0 = input[i];
        output[out_idx] = base64_alphabet[b0 >> 2];
        output[out_idx + 1] = base64_alphabet[(b0 & 0x03) << 4];
        output[out_idx + 2] = '=';
        output[out_idx + 3] = '=';
        out_idx += 4;
    } else if (remaining == 2) {
        const b0 = input[i];
        const b1 = input[i + 1];
        output[out_idx] = base64_alphabet[b0 >> 2];
        output[out_idx + 1] = base64_alphabet[((b0 & 0x03) << 4) | (b1 >> 4)];
        output[out_idx + 2] = base64_alphabet[(b1 & 0x0F) << 2];
        output[out_idx + 3] = '=';
        out_idx += 4;
    }

    return out_idx;
}

// ============================================================================
// BLS Public Key Types
// ============================================================================

/// A BLS public key in affine point representation (96 bytes)
///
/// This is a G1 point on the BLS12-381 curve, stored as two 48-byte
/// field elements (x, y coordinates).
///
/// Rust equivalent: `solana_bls_signatures::Pubkey`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/bls-signatures/src/pubkey/bytes.rs
pub const Pubkey = struct {
    bytes: [BLS_PUBLIC_KEY_AFFINE_SIZE]u8,

    const Self = @This();

    /// Create a new public key from bytes
    pub fn new(bytes: [BLS_PUBLIC_KEY_AFFINE_SIZE]u8) Self {
        return .{ .bytes = bytes };
    }

    /// Create a zero-initialized public key
    pub fn default() Self {
        return .{ .bytes = [_]u8{0} ** BLS_PUBLIC_KEY_AFFINE_SIZE };
    }

    /// Get the underlying bytes
    pub fn toBytes(self: Self) [BLS_PUBLIC_KEY_AFFINE_SIZE]u8 {
        return self.bytes;
    }

    /// Check if two public keys are equal
    pub fn equals(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    /// Check if this is a zero/default public key
    pub fn isZero(self: Self) bool {
        const zero = [_]u8{0} ** BLS_PUBLIC_KEY_AFFINE_SIZE;
        return std.mem.eql(u8, &self.bytes, &zero);
    }

    /// Format as base64 string
    pub fn format(self: Self, writer: anytype) !void {
        var buf: [128]u8 = undefined;
        const len = base64Encode(&self.bytes, &buf);
        try writer.writeAll(buf[0..len]);
    }
};

/// A BLS public key in compressed point representation (48 bytes)
///
/// This is a compressed G1 point on the BLS12-381 curve, storing only
/// the x coordinate with a sign bit for the y coordinate.
///
/// Rust equivalent: `solana_bls_signatures::PubkeyCompressed`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/bls-signatures/src/pubkey/bytes.rs
pub const PubkeyCompressed = struct {
    bytes: [BLS_PUBLIC_KEY_COMPRESSED_SIZE]u8,

    const Self = @This();

    /// Create a new compressed public key from bytes
    pub fn new(bytes: [BLS_PUBLIC_KEY_COMPRESSED_SIZE]u8) Self {
        return .{ .bytes = bytes };
    }

    /// Create a zero-initialized compressed public key
    pub fn default() Self {
        return .{ .bytes = [_]u8{0} ** BLS_PUBLIC_KEY_COMPRESSED_SIZE };
    }

    /// Get the underlying bytes
    pub fn toBytes(self: Self) [BLS_PUBLIC_KEY_COMPRESSED_SIZE]u8 {
        return self.bytes;
    }

    /// Check if two compressed public keys are equal
    pub fn equals(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    /// Check if this is a zero/default compressed public key
    pub fn isZero(self: Self) bool {
        const zero = [_]u8{0} ** BLS_PUBLIC_KEY_COMPRESSED_SIZE;
        return std.mem.eql(u8, &self.bytes, &zero);
    }

    /// Format as base64 string
    pub fn format(self: Self, writer: anytype) !void {
        var buf: [64]u8 = undefined;
        const len = base64Encode(&self.bytes, &buf);
        try writer.writeAll(buf[0..len]);
    }
};

// ============================================================================
// BLS Signature Types
// ============================================================================

/// A BLS signature in affine point representation (192 bytes)
///
/// This is a G2 point on the BLS12-381 curve, stored as four 48-byte
/// field elements representing the x and y coordinates in the extension field.
///
/// Rust equivalent: `solana_bls_signatures::Signature`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/bls-signatures/src/signature/bytes.rs
pub const Signature = struct {
    bytes: [BLS_SIGNATURE_AFFINE_SIZE]u8,

    const Self = @This();

    /// Create a new signature from bytes
    pub fn new(bytes: [BLS_SIGNATURE_AFFINE_SIZE]u8) Self {
        return .{ .bytes = bytes };
    }

    /// Create a zero-initialized signature
    pub fn default() Self {
        return .{ .bytes = [_]u8{0} ** BLS_SIGNATURE_AFFINE_SIZE };
    }

    /// Get the underlying bytes
    pub fn toBytes(self: Self) [BLS_SIGNATURE_AFFINE_SIZE]u8 {
        return self.bytes;
    }

    /// Check if two signatures are equal
    pub fn equals(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    /// Check if this is a zero/default signature
    pub fn isZero(self: Self) bool {
        const zero = [_]u8{0} ** BLS_SIGNATURE_AFFINE_SIZE;
        return std.mem.eql(u8, &self.bytes, &zero);
    }

    /// Format as base64 string
    pub fn format(self: Self, writer: anytype) !void {
        var buf: [256]u8 = undefined;
        const len = base64Encode(&self.bytes, &buf);
        try writer.writeAll(buf[0..len]);
    }
};

/// A BLS signature in compressed point representation (96 bytes)
///
/// This is a compressed G2 point on the BLS12-381 curve.
///
/// Rust equivalent: `solana_bls_signatures::SignatureCompressed`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/bls-signatures/src/signature/bytes.rs
pub const SignatureCompressed = struct {
    bytes: [BLS_SIGNATURE_COMPRESSED_SIZE]u8,

    const Self = @This();

    /// Create a new compressed signature from bytes
    pub fn new(bytes: [BLS_SIGNATURE_COMPRESSED_SIZE]u8) Self {
        return .{ .bytes = bytes };
    }

    /// Create a zero-initialized compressed signature
    pub fn default() Self {
        return .{ .bytes = [_]u8{0} ** BLS_SIGNATURE_COMPRESSED_SIZE };
    }

    /// Get the underlying bytes
    pub fn toBytes(self: Self) [BLS_SIGNATURE_COMPRESSED_SIZE]u8 {
        return self.bytes;
    }

    /// Check if two compressed signatures are equal
    pub fn equals(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    /// Check if this is a zero/default compressed signature
    pub fn isZero(self: Self) bool {
        const zero = [_]u8{0} ** BLS_SIGNATURE_COMPRESSED_SIZE;
        return std.mem.eql(u8, &self.bytes, &zero);
    }

    /// Format as base64 string
    pub fn format(self: Self, writer: anytype) !void {
        var buf: [128]u8 = undefined;
        const len = base64Encode(&self.bytes, &buf);
        try writer.writeAll(buf[0..len]);
    }
};

// ============================================================================
// Proof of Possession Types
// ============================================================================

/// A BLS proof of possession in affine point representation (192 bytes)
///
/// A proof of possession (PoP) is a signature over the public key itself,
/// proving that the holder of the public key also possesses the corresponding
/// secret key. This prevents rogue key attacks in aggregation schemes.
///
/// Rust equivalent: `solana_bls_signatures::ProofOfPossession`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/bls-signatures/src/proof_of_possession/bytes.rs
pub const ProofOfPossession = struct {
    bytes: [BLS_PROOF_OF_POSSESSION_AFFINE_SIZE]u8,

    const Self = @This();

    /// Create a new proof of possession from bytes
    pub fn new(bytes: [BLS_PROOF_OF_POSSESSION_AFFINE_SIZE]u8) Self {
        return .{ .bytes = bytes };
    }

    /// Create a zero-initialized proof of possession
    pub fn default() Self {
        return .{ .bytes = [_]u8{0} ** BLS_PROOF_OF_POSSESSION_AFFINE_SIZE };
    }

    /// Get the underlying bytes
    pub fn toBytes(self: Self) [BLS_PROOF_OF_POSSESSION_AFFINE_SIZE]u8 {
        return self.bytes;
    }

    /// Check if two proofs of possession are equal
    pub fn equals(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    /// Check if this is a zero/default proof of possession
    pub fn isZero(self: Self) bool {
        const zero = [_]u8{0} ** BLS_PROOF_OF_POSSESSION_AFFINE_SIZE;
        return std.mem.eql(u8, &self.bytes, &zero);
    }

    /// Format as base64 string
    pub fn format(self: Self, writer: anytype) !void {
        var buf: [256]u8 = undefined;
        const len = base64Encode(&self.bytes, &buf);
        try writer.writeAll(buf[0..len]);
    }
};

/// A BLS proof of possession in compressed point representation (96 bytes)
///
/// Rust equivalent: `solana_bls_signatures::ProofOfPossessionCompressed`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/bls-signatures/src/proof_of_possession/bytes.rs
pub const ProofOfPossessionCompressed = struct {
    bytes: [BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE]u8,

    const Self = @This();

    /// Create a new compressed proof of possession from bytes
    pub fn new(bytes: [BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE]u8) Self {
        return .{ .bytes = bytes };
    }

    /// Create a zero-initialized compressed proof of possession
    pub fn default() Self {
        return .{ .bytes = [_]u8{0} ** BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE };
    }

    /// Get the underlying bytes
    pub fn toBytes(self: Self) [BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE]u8 {
        return self.bytes;
    }

    /// Check if two compressed proofs of possession are equal
    pub fn equals(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    /// Check if this is a zero/default compressed proof of possession
    pub fn isZero(self: Self) bool {
        const zero = [_]u8{0} ** BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE;
        return std.mem.eql(u8, &self.bytes, &zero);
    }

    /// Format as base64 string
    pub fn format(self: Self, writer: anytype) !void {
        var buf: [128]u8 = undefined;
        const len = base64Encode(&self.bytes, &buf);
        try writer.writeAll(buf[0..len]);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "bls: size constants" {
    // Verify size constants match BLS12-381 curve parameters
    try std.testing.expectEqual(@as(usize, 48), BLS_PUBLIC_KEY_COMPRESSED_SIZE);
    try std.testing.expectEqual(@as(usize, 96), BLS_PUBLIC_KEY_AFFINE_SIZE);
    try std.testing.expectEqual(@as(usize, 96), BLS_SIGNATURE_COMPRESSED_SIZE);
    try std.testing.expectEqual(@as(usize, 192), BLS_SIGNATURE_AFFINE_SIZE);
    try std.testing.expectEqual(@as(usize, 96), BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE);
    try std.testing.expectEqual(@as(usize, 192), BLS_PROOF_OF_POSSESSION_AFFINE_SIZE);
}

test "bls: pop dst constant" {
    try std.testing.expectEqualStrings(
        "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_",
        POP_DST,
    );
}

test "bls: pubkey default is zero" {
    const pubkey = Pubkey.default();
    try std.testing.expect(pubkey.isZero());

    const pubkey_compressed = PubkeyCompressed.default();
    try std.testing.expect(pubkey_compressed.isZero());
}

test "bls: pubkey new and equals" {
    var bytes: [BLS_PUBLIC_KEY_AFFINE_SIZE]u8 = undefined;
    for (&bytes, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    const pubkey1 = Pubkey.new(bytes);
    const pubkey2 = Pubkey.new(bytes);
    const pubkey3 = Pubkey.default();

    try std.testing.expect(pubkey1.equals(pubkey2));
    try std.testing.expect(!pubkey1.equals(pubkey3));
    try std.testing.expect(!pubkey1.isZero());
}

test "bls: pubkey compressed new and equals" {
    var bytes: [BLS_PUBLIC_KEY_COMPRESSED_SIZE]u8 = undefined;
    for (&bytes, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    const pubkey1 = PubkeyCompressed.new(bytes);
    const pubkey2 = PubkeyCompressed.new(bytes);
    const pubkey3 = PubkeyCompressed.default();

    try std.testing.expect(pubkey1.equals(pubkey2));
    try std.testing.expect(!pubkey1.equals(pubkey3));
    try std.testing.expect(!pubkey1.isZero());
}

test "bls: signature default is zero" {
    const sig = Signature.default();
    try std.testing.expect(sig.isZero());

    const sig_compressed = SignatureCompressed.default();
    try std.testing.expect(sig_compressed.isZero());
}

test "bls: signature new and equals" {
    var bytes: [BLS_SIGNATURE_AFFINE_SIZE]u8 = undefined;
    for (&bytes, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    const sig1 = Signature.new(bytes);
    const sig2 = Signature.new(bytes);
    const sig3 = Signature.default();

    try std.testing.expect(sig1.equals(sig2));
    try std.testing.expect(!sig1.equals(sig3));
    try std.testing.expect(!sig1.isZero());
}

test "bls: signature compressed new and equals" {
    var bytes: [BLS_SIGNATURE_COMPRESSED_SIZE]u8 = undefined;
    for (&bytes, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    const sig1 = SignatureCompressed.new(bytes);
    const sig2 = SignatureCompressed.new(bytes);
    const sig3 = SignatureCompressed.default();

    try std.testing.expect(sig1.equals(sig2));
    try std.testing.expect(!sig1.equals(sig3));
    try std.testing.expect(!sig1.isZero());
}

test "bls: proof of possession default is zero" {
    const pop = ProofOfPossession.default();
    try std.testing.expect(pop.isZero());

    const pop_compressed = ProofOfPossessionCompressed.default();
    try std.testing.expect(pop_compressed.isZero());
}

test "bls: proof of possession new and equals" {
    var bytes: [BLS_PROOF_OF_POSSESSION_AFFINE_SIZE]u8 = undefined;
    for (&bytes, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    const pop1 = ProofOfPossession.new(bytes);
    const pop2 = ProofOfPossession.new(bytes);
    const pop3 = ProofOfPossession.default();

    try std.testing.expect(pop1.equals(pop2));
    try std.testing.expect(!pop1.equals(pop3));
    try std.testing.expect(!pop1.isZero());
}

test "bls: proof of possession compressed new and equals" {
    var bytes: [BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE]u8 = undefined;
    for (&bytes, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    const pop1 = ProofOfPossessionCompressed.new(bytes);
    const pop2 = ProofOfPossessionCompressed.new(bytes);
    const pop3 = ProofOfPossessionCompressed.default();

    try std.testing.expect(pop1.equals(pop2));
    try std.testing.expect(!pop1.equals(pop3));
    try std.testing.expect(!pop1.isZero());
}

test "bls: toBytes roundtrip" {
    // Test Pubkey
    var pubkey_bytes: [BLS_PUBLIC_KEY_AFFINE_SIZE]u8 = undefined;
    for (&pubkey_bytes, 0..) |*b, i| {
        b.* = @truncate(i * 2);
    }
    const pubkey = Pubkey.new(pubkey_bytes);
    try std.testing.expectEqualSlices(u8, &pubkey_bytes, &pubkey.toBytes());

    // Test PubkeyCompressed
    var pubkey_c_bytes: [BLS_PUBLIC_KEY_COMPRESSED_SIZE]u8 = undefined;
    for (&pubkey_c_bytes, 0..) |*b, i| {
        b.* = @truncate(i * 3);
    }
    const pubkey_c = PubkeyCompressed.new(pubkey_c_bytes);
    try std.testing.expectEqualSlices(u8, &pubkey_c_bytes, &pubkey_c.toBytes());

    // Test Signature
    var sig_bytes: [BLS_SIGNATURE_AFFINE_SIZE]u8 = undefined;
    for (&sig_bytes, 0..) |*b, i| {
        b.* = @truncate(i * 4);
    }
    const sig = Signature.new(sig_bytes);
    try std.testing.expectEqualSlices(u8, &sig_bytes, &sig.toBytes());

    // Test SignatureCompressed
    var sig_c_bytes: [BLS_SIGNATURE_COMPRESSED_SIZE]u8 = undefined;
    for (&sig_c_bytes, 0..) |*b, i| {
        b.* = @truncate(i * 5);
    }
    const sig_c = SignatureCompressed.new(sig_c_bytes);
    try std.testing.expectEqualSlices(u8, &sig_c_bytes, &sig_c.toBytes());

    // Test ProofOfPossession
    var pop_bytes: [BLS_PROOF_OF_POSSESSION_AFFINE_SIZE]u8 = undefined;
    for (&pop_bytes, 0..) |*b, i| {
        b.* = @truncate(i * 6);
    }
    const pop = ProofOfPossession.new(pop_bytes);
    try std.testing.expectEqualSlices(u8, &pop_bytes, &pop.toBytes());

    // Test ProofOfPossessionCompressed
    var pop_c_bytes: [BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE]u8 = undefined;
    for (&pop_c_bytes, 0..) |*b, i| {
        b.* = @truncate(i * 7);
    }
    const pop_c = ProofOfPossessionCompressed.new(pop_c_bytes);
    try std.testing.expectEqualSlices(u8, &pop_c_bytes, &pop_c.toBytes());
}

test "bls: base64 encoding" {
    // Test with known value - all 1s
    const pubkey_compressed = PubkeyCompressed.new([_]u8{1} ** BLS_PUBLIC_KEY_COMPRESSED_SIZE);

    var buf: [128]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try pubkey_compressed.format(stream.writer());
    const result = stream.getWritten();

    // Base64 of 48 bytes of 0x01 should be "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB"
    try std.testing.expectEqual(@as(usize, 64), result.len);
    try std.testing.expect(result[0] == 'A');
    try std.testing.expect(result[1] == 'Q');
}

test "bls: pubkey format" {
    const pubkey = Pubkey.new([_]u8{0} ** BLS_PUBLIC_KEY_AFFINE_SIZE);

    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try pubkey.format(stream.writer());
    const result = stream.getWritten();

    // Base64 of 96 zeros should be all 'A's with padding
    try std.testing.expectEqual(@as(usize, 128), result.len);
}

test "bls: signature format" {
    const sig = Signature.new([_]u8{0xFF} ** BLS_SIGNATURE_AFFINE_SIZE);

    var buf: [512]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try sig.format(stream.writer());
    const result = stream.getWritten();

    // Base64 of 192 bytes should be 256 characters
    try std.testing.expectEqual(@as(usize, 256), result.len);
}

test "bls: struct sizes match constants" {
    try std.testing.expectEqual(BLS_PUBLIC_KEY_AFFINE_SIZE, @sizeOf(Pubkey));
    try std.testing.expectEqual(BLS_PUBLIC_KEY_COMPRESSED_SIZE, @sizeOf(PubkeyCompressed));
    try std.testing.expectEqual(BLS_SIGNATURE_AFFINE_SIZE, @sizeOf(Signature));
    try std.testing.expectEqual(BLS_SIGNATURE_COMPRESSED_SIZE, @sizeOf(SignatureCompressed));
    try std.testing.expectEqual(BLS_PROOF_OF_POSSESSION_AFFINE_SIZE, @sizeOf(ProofOfPossession));
    try std.testing.expectEqual(BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE, @sizeOf(ProofOfPossessionCompressed));
}

test "bls: different types are not conflated" {
    // Signature and ProofOfPossession have same size but are different types
    var bytes: [BLS_SIGNATURE_AFFINE_SIZE]u8 = undefined;
    for (&bytes, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    const sig = Signature.new(bytes);
    const pop = ProofOfPossession.new(bytes);

    // They have the same bytes but are different types
    try std.testing.expectEqualSlices(u8, &sig.bytes, &pop.bytes);

    // Type system prevents mixing them
    // (compile error if you try: sig.equals(pop))
}

test "bls: compressed types have correct sizes" {
    // G1 compressed = 48 bytes (x coordinate + sign bit)
    try std.testing.expectEqual(@as(usize, 48), BLS_PUBLIC_KEY_COMPRESSED_SIZE);

    // G2 compressed = 96 bytes (x coordinate in extension field + sign bit)
    try std.testing.expectEqual(@as(usize, 96), BLS_SIGNATURE_COMPRESSED_SIZE);
    try std.testing.expectEqual(@as(usize, 96), BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE);
}

test "bls: affine types have correct sizes" {
    // G1 affine = 96 bytes (x + y, each 48 bytes)
    try std.testing.expectEqual(@as(usize, 96), BLS_PUBLIC_KEY_AFFINE_SIZE);

    // G2 affine = 192 bytes (x + y in extension field, each 96 bytes)
    try std.testing.expectEqual(@as(usize, 192), BLS_SIGNATURE_AFFINE_SIZE);
    try std.testing.expectEqual(@as(usize, 192), BLS_PROOF_OF_POSSESSION_AFFINE_SIZE);
}
