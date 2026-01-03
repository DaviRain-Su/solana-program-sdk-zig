const std = @import("std");
const builtin = @import("builtin");

const crypto = std.crypto;
const Ed25519 = crypto.sign.Ed25519;
const hash = @import("hash.zig");

/// Number of bytes in a signature
pub const SIGNATURE_BYTES = 64;

/// A digital signature using Ed25519
pub const Signature = extern struct {
    /// The 64-byte signature data
    bytes: [SIGNATURE_BYTES]u8,

    /// Create a new signature from bytes
    pub fn from(bytes: [SIGNATURE_BYTES]u8) Signature {
        return Signature{ .bytes = bytes };
    }

    /// Create a signature from a byte slice
    pub fn tryFrom(bytes: []const u8) !Signature {
        if (bytes.len != SIGNATURE_BYTES) {
            return error.InvalidLength;
        }
        var sig_bytes: [SIGNATURE_BYTES]u8 = undefined;
        @memcpy(&sig_bytes, bytes);
        return Signature{ .bytes = sig_bytes };
    }

    /// Get the signature as bytes
    pub fn asBytes(self: *const Signature) []const u8 {
        return &self.bytes;
    }

    /// Get a reference to the signature bytes array
    pub fn asArray(self: *const Signature) *const [SIGNATURE_BYTES]u8 {
        return &self.bytes;
    }

    /// Create the default (zero) signature
    pub fn default() Signature {
        return Signature{ .bytes = [_]u8{0} ** SIGNATURE_BYTES };
    }

    /// Create a unique signature (for testing/mocking)
    pub fn newUnique() Signature {
        // Use current time and some randomness for uniqueness
        var bytes: [SIGNATURE_BYTES]u8 = undefined;
        std.crypto.random.bytes(&bytes);
        return Signature{ .bytes = bytes };
    }

    /// Verify the signature against a message and public key
    pub fn verify(
        self: *const Signature,
        message: []const u8,
        pubkey_bytes: []const u8,
    ) !void {
        if (pubkey_bytes.len != 32) {
            return error.InvalidPublicKeyLength;
        }

        // Convert to Zig crypto types
        const pubkey = try Ed25519.PublicKey.fromBytes(pubkey_bytes[0..32].*);

        // Convert signature from Solana format to Zig format
        // Solana uses 64 bytes directly, Zig uses structured format
        const sig = try Ed25519.Signature.fromBytes(self.bytes);

        // Verify using Zig's crypto
        try sig.verify(message, pubkey);
    }

    /// Check if the signature is valid (non-zero)
    pub fn isValid(self: *const Signature) bool {
        // A signature is considered valid if it's not all zeros
        for (self.bytes) |byte| {
            if (byte != 0) return true;
        }
        return false;
    }

    /// Format for display (base58 encoded)
    pub fn format(self: Signature, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        // Base58 encode the signature
        const base58 = @import("public_key.zig").base58_mod;
        var buffer: [base58.bitcoin.getEncodedLengthUpperBound(SIGNATURE_BYTES)]u8 = undefined;
        const encoded = base58.bitcoin.encode(&buffer, &self.bytes);
        try writer.writeAll(encoded);
    }

    /// Parse from base58 string
    pub fn fromBase58(str: []const u8) !Signature {
        const base58 = @import("public_key.zig").base58_mod;
        var buffer: [SIGNATURE_BYTES]u8 = undefined;
        const decoded = try base58.bitcoin.decode(&buffer, str);
        if (decoded.len != SIGNATURE_BYTES) {
            return error.InvalidLength;
        }
        return Signature{ .bytes = buffer };
    }
};

// Tests
test "signature: basic operations" {
    // Test default signature
    const default_sig = Signature.default();
    try std.testing.expect(!default_sig.isValid());

    // Test from bytes
    var bytes: [SIGNATURE_BYTES]u8 = [_]u8{1} ** SIGNATURE_BYTES;
    const sig = Signature.from(bytes);
    try std.testing.expect(sig.isValid());
    try std.testing.expect(std.mem.eql(u8, sig.asBytes(), &bytes));

    // Test tryFrom with correct length
    const sig2 = try Signature.tryFrom(&bytes);
    try std.testing.expect(std.mem.eql(u8, sig2.asBytes(), &bytes));

    // Test tryFrom with wrong length
    try std.testing.expectError(error.InvalidLength, Signature.tryFrom(&[_]u8{1, 2, 3}));
}

test "signature: unique generation" {
    const sig1 = Signature.newUnique();
    const sig2 = Signature.newUnique();
    try std.testing.expect(sig1.isValid());
    try std.testing.expect(sig2.isValid());
    // Very unlikely to be equal (but theoretically possible)
    try std.testing.expect(!std.mem.eql(u8, sig1.asBytes(), sig2.asBytes()));
}


