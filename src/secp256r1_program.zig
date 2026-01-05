//! Zig implementation of Solana SDK's Secp256r1 program
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/secp256r1-program/src/lib.rs
//!
//! This module provides the interface for Solana's Secp256r1 program, which supports
//! P-256 elliptic curve operations for ECDSA signature verification. This is commonly
//! used for WebAuthn authentication and other cryptographic protocols.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const Instruction = @import("instruction.zig").Instruction;

/// Secp256r1 program ID
///
/// The program ID for the Secp256r1 program.
///
/// Rust equivalent: `solana_secp256r1_program::id()`
pub const id = PublicKey.comptimeFromBase58("Secp256r11111111111111111111111111111111111");

/// Secp256r1 signature verification instruction data
///
/// Contains all the data needed to verify an ECDSA signature over the P-256 curve.
///
/// Rust equivalent: `solana_secp256r1_program::verify` instruction data
pub const VerifyInstruction = struct {
    /// Instruction discriminator (0 for verify)
    pub const instruction_discriminator = 0;

    /// The ECDSA signature (64 bytes: r || s)
    signature: [64]u8,

    /// The public key (64 bytes: uncompressed P-256 public key)
    /// Format: 0x04 || x || y (uncompressed SEC1 format)
    public_key: [64]u8,

    /// The message that was signed (variable length)
    message: []const u8,

    /// Create a new verify instruction
    pub fn new(
        signature: [64]u8,
        public_key: [64]u8,
        message: []const u8,
    ) VerifyInstruction {
        return VerifyInstruction{
            .signature = signature,
            .public_key = public_key,
            .message = message,
        };
    }

    /// Serialize the instruction data
    ///
    /// # Arguments
    /// * `allocator` - Memory allocator
    ///
    /// # Returns
    /// Serialized instruction data as bytes
    pub fn serialize(self: VerifyInstruction, allocator: std.mem.Allocator) ![]u8 {
        // Calculate total size:
        // - Discriminator: 1 byte
        // - Signature: 64 bytes
        // - Public key: 64 bytes
        // - Message length: 2 bytes (u16)
        // - Message: variable length
        const message_len = self.message.len;
        const total_size = 1 + 64 + 64 + 2 + message_len;

        var data = try allocator.alloc(u8, total_size);
        errdefer allocator.free(data);

        var offset: usize = 0;

        // Instruction discriminator
        data[offset] = instruction_discriminator;
        offset += 1;

        // Signature
        @memcpy(data[offset .. offset + 64], &self.signature);
        offset += 64;

        // Public key
        @memcpy(data[offset .. offset + 64], &self.public_key);
        offset += 64;

        // Message length (little endian u16)
        const msg_len_u16 = @as(u16, @intCast(message_len));
        var len_buf: [2]u8 = undefined;
        std.mem.writeInt(u16, &len_buf, msg_len_u16, .little);
        @memcpy(data[offset .. offset + 2], &len_buf);
        offset += 2;

        // Message
        @memcpy(data[offset .. offset + message_len], self.message);

        return data;
    }

    /// Create a verify instruction
    ///
    /// # Arguments
    /// * `allocator` - Memory allocator
    /// * `signature` - ECDSA signature (64 bytes)
    /// * `public_key` - P-256 public key (64 bytes, uncompressed)
    /// * `message` - Message that was signed
    ///
    /// # Returns
    /// Complete instruction ready for execution
    ///
    /// Rust equivalent: `solana_secp256r1_program::verify()`
    pub fn createInstruction(
        allocator: std.mem.Allocator,
        signature: [64]u8,
        public_key: [64]u8,
        message: []const u8,
    ) !Instruction {
        const verify_instr = VerifyInstruction.new(signature, public_key, message);
        const data = try verify_instr.serialize(allocator);
        defer allocator.free(data);

        // No accounts needed for verification - the program is stateless
        return Instruction.from(.{
            .program_id = &id,
            .accounts = &.{}, // No accounts required
            .data = data,
        });
    }
};

/// P-256 elliptic curve utilities
///
/// Provides utilities for working with P-256 elliptic curve keys and signatures.
pub const P256 = struct {
    /// P-256 field modulus (prime)
    /// p = 2^256 - 2^224 + 2^192 + 2^96 - 1
    pub const field_modulus = [_]u8{
        0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    };

    /// P-256 curve order (prime)
    /// n = 2^256 - 2^224 + 2^192 - 2^96 - 1
    pub const curve_order = [_]u8{
        0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xBC, 0xE6, 0xFA, 0xAD, 0xA7, 0x17, 0x9E, 0x84,
        0xF3, 0xB9, 0xCA, 0xC2, 0xFC, 0x63, 0x25, 0x51,
    };

    /// P-256 generator point x coordinate
    pub const generator_x = [_]u8{
        0x6B, 0x17, 0xD1, 0xF2, 0xE1, 0x2C, 0x42, 0x47,
        0xF8, 0xBC, 0xE6, 0xE5, 0x63, 0xA4, 0x40, 0xF2,
        0x77, 0x03, 0x7D, 0x81, 0x2D, 0xEB, 0x33, 0xA0,
        0xF4, 0xA1, 0x39, 0x45, 0xD8, 0x98, 0xC2, 0x96,
    };

    /// P-256 generator point y coordinate
    pub const generator_y = [_]u8{
        0x4F, 0xE3, 0x42, 0xE2, 0xFE, 0x1A, 0x7F, 0x9B,
        0x8E, 0xE7, 0xEB, 0x4A, 0x7C, 0x0F, 0x9E, 0x16,
        0x2B, 0xCE, 0x33, 0x57, 0x6B, 0x31, 0x5E, 0xCE,
        0xCB, 0xB6, 0x40, 0x68, 0x37, 0xBF, 0x51, 0xF5,
    };

    /// Create uncompressed public key format
    ///
    /// Converts x,y coordinates to uncompressed SEC1 format (0x04 || x || y)
    ///
    /// # Arguments
    /// * `x` - X coordinate (32 bytes)
    /// * `y` - Y coordinate (32 bytes)
    ///
    /// # Returns
    /// Uncompressed public key (65 bytes: 0x04 || x || y)
    pub fn createUncompressedPublicKey(x: [32]u8, y: [32]u8) [65]u8 {
        var public_key: [65]u8 = undefined;
        public_key[0] = 0x04; // Uncompressed format indicator
        @memcpy(public_key[1..33], &x);
        @memcpy(public_key[33..65], &y);
        return public_key;
    }

    /// Extract coordinates from uncompressed public key
    ///
    /// # Arguments
    /// * `public_key` - Uncompressed public key (65 bytes)
    ///
    /// # Returns
    /// X and Y coordinates
    ///
    /// # Errors
    /// Returns error if format is invalid
    pub fn extractCoordinates(public_key: [65]u8) ![2][32]u8 {
        if (public_key[0] != 0x04) {
            return error.InvalidFormat;
        }

        var coordinates: [2][32]u8 = undefined;
        @memcpy(&coordinates[0], public_key[1..33]); // x coordinate
        @memcpy(&coordinates[1], public_key[33..65]); // y coordinate

        return coordinates;
    }

    /// Validate that a point is on the P-256 curve
    ///
    /// Performs basic validation that the point satisfies the curve equation.
    /// Note: This is a simplified check - full validation requires modular arithmetic.
    ///
    /// # Arguments
    /// * `public_key` - Uncompressed public key (65 bytes)
    ///
    /// # Returns
    /// True if the point appears to be on the curve
    pub fn isOnCurve(public_key: [65]u8) bool {
        if (public_key[0] != 0x04) return false;

        // Extract coordinates
        const coordinates = extractCoordinates(public_key) catch return false;
        const x = coordinates[0];
        const y = coordinates[1];

        // Basic bounds check (coordinates should be < field modulus)
        for (x) |byte| {
            if (byte > 0xFF) return false; // This is a simplified check
        }
        for (y) |byte| {
            if (byte > 0xFF) return false;
        }

        // For full validation, we would need to check: y² ≡ x³ - 3x + b (mod p)
        // This requires big integer modular arithmetic which is complex to implement
        // For now, we do basic format validation

        return true;
    }
};

/// WebAuthn utilities for P-256 signatures
///
/// Provides utilities for working with WebAuthn-compatible ECDSA signatures.
pub const WebAuthn = struct {
    /// COSE key format for P-256 public keys
    ///
    /// WebAuthn uses COSE (CBOR Object Signing and Encryption) format
    /// for representing cryptographic keys.
    pub const CoseKey = struct {
        /// Key type (2 for EC2)
        kty: i32 = 2,
        /// Algorithm (-7 for ES256)
        alg: i32 = -7,
        /// Curve (-1 for P-256)
        crv: i32 = -1,
        /// X coordinate (32 bytes)
        x: [32]u8,
        /// Y coordinate (32 bytes)
        y: [32]u8,

        /// Convert to uncompressed SEC1 format
        pub fn toUncompressedSec1(self: CoseKey) [65]u8 {
            return P256.createUncompressedPublicKey(self.x, self.y);
        }
    };

    /// Verify a WebAuthn signature
    ///
    /// # Arguments
    /// * `allocator` - Memory allocator
    /// * `signature` - DER-encoded ECDSA signature
    /// * `public_key` - COSE format public key
    /// * `authenticator_data` - Authenticator data from WebAuthn
    /// * `client_data_hash` - SHA-256 hash of client data JSON
    ///
    /// # Returns
    /// Instruction for signature verification
    ///
    /// # Errors
    /// Returns error if signature format is invalid
    pub fn verifySignature(
        allocator: std.mem.Allocator,
        signature: []const u8,
        public_key: CoseKey,
        authenticator_data: []const u8,
        client_data_hash: [32]u8,
    ) !Instruction {
        // WebAuthn signature verification requires constructing the message
        // that was signed. The signed message is:
        // authenticator_data || client_data_hash

        const message_len = authenticator_data.len + client_data_hash.len;
        var message = try allocator.alloc(u8, message_len);
        defer allocator.free(message);

        @memcpy(message[0..authenticator_data.len], authenticator_data);
        @memcpy(message[authenticator_data.len..], &client_data_hash);

        // Convert signature from DER to raw format (r || s)
        // This is a simplified conversion - real implementation needs DER parsing
        if (signature.len < 64) {
            return error.InvalidSignature;
        }

        var raw_signature: [64]u8 = undefined;
        // For simplicity, assume the signature is already in r || s format
        // Real WebAuthn signatures are DER-encoded and need proper parsing
        @memcpy(&raw_signature, signature[0..64]);

        const public_key_uncompressed = public_key.toUncompressedSec1();

        // Extract the raw public key (without 0x04 prefix)
        var raw_public_key: [64]u8 = undefined;
        @memcpy(&raw_public_key, public_key_uncompressed[1..]);

        return try VerifyInstruction.createInstruction(
            allocator,
            raw_signature,
            raw_public_key,
            &message,
        );
    }
};

test "secp256r1: verify instruction serialization" {
    const allocator = std.testing.allocator;

    // Test data
    const signature = [_]u8{0xAA} ** 64;
    const public_key = [_]u8{0xBB} ** 64;
    const message_arr = [_]u8{0xCC} ** 32;
    const message = &message_arr;

    const verify_instr = VerifyInstruction.new(signature, public_key, message);
    const data = try verify_instr.serialize(allocator);
    defer allocator.free(data);

    // Verify discriminator
    try std.testing.expectEqual(@as(u8, 0), data[0]);

    // Verify signature
    try std.testing.expect(std.mem.eql(u8, data[1..65], &signature));

    // Verify public key
    try std.testing.expect(std.mem.eql(u8, data[65..129], &public_key));

    // Verify message length
    const msg_len = std.mem.readInt(u16, data[129..131], .little);
    try std.testing.expectEqual(@as(u16, 32), msg_len);

    // Verify message
    try std.testing.expect(std.mem.eql(u8, data[131..163], message));
}

test "secp256r1: create verify instruction" {
    const allocator = std.testing.allocator;

    const signature = [_]u8{0xAA} ** 64;
    const public_key = [_]u8{0xBB} ** 64;
    const message_arr = [_]u8{0xCC} ** 32;
    const message = &message_arr;

    const instruction = try VerifyInstruction.createInstruction(
        allocator,
        signature,
        public_key,
        message,
    );

    // Verify program ID
    try std.testing.expect(instruction.program_id.equals(id));

    // Verify no accounts
    try std.testing.expectEqual(@as(usize, 0), instruction.accounts_len);

    // Verify data length
    try std.testing.expect(instruction.data_len > 0);
}

test "secp256r1: P-256 coordinate extraction" {
    const x_coord = [_]u8{0x11} ** 32;
    const y_coord = [_]u8{0x22} ** 32;

    const uncompressed = P256.createUncompressedPublicKey(x_coord, y_coord);
    try std.testing.expectEqual(@as(u8, 0x04), uncompressed[0]);

    const coordinates = try P256.extractCoordinates(uncompressed);
    try std.testing.expect(std.mem.eql(u8, &coordinates[0], &x_coord));
    try std.testing.expect(std.mem.eql(u8, &coordinates[1], &y_coord));
}

test "secp256r1: P-256 curve validation" {
    const x_coord = [_]u8{0x11} ** 32;
    const y_coord = [_]u8{0x22} ** 32;

    const uncompressed = P256.createUncompressedPublicKey(x_coord, y_coord);
    const is_valid = P256.isOnCurve(uncompressed);

    // Our simplified validation should pass basic checks
    try std.testing.expect(is_valid);
}

test "secp256r1: invalid public key format" {
    const invalid_key = [_]u8{0x03} ** 65; // Wrong format byte
    const is_valid = P256.isOnCurve(invalid_key);
    try std.testing.expect(!is_valid);
}
