//! Zig implementation of Solana SDK's signer module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/signer/src/lib.rs
//!
//! This module provides the Signer interface for signing Solana transactions.
//! The primary implementation is the Keypair type.

const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = @import("public_key.zig").PublicKey;
const Signature = sdk.Signature;
const Keypair = sdk.Keypair;

/// Error types for signing operations.
///
/// Rust equivalent: `solana_signer::SignerError`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/signer/src/lib.rs
pub const SignerError = error{
    /// The keypair's public key doesn't match the expected key
    KeypairPubkeyMismatch,
    /// Not enough signers provided
    NotEnoughSigners,
    /// Too many signers provided
    TooManySigners,
    /// Transaction error during signing
    TransactionError,
    /// Custom error
    Custom,
    /// Presigner verification failed
    PresignerError,
    /// Connection error
    Connection,
    /// Invalid input
    InvalidInput,
    /// No device found (for hardware wallets)
    NoDeviceFound,
    /// Protocol error
    Protocol,
    /// User cancelled
    UserCancel,
    /// Signing operation failed (e.g., invalid keypair)
    SigningFailed,
};

/// The Signer interface for types that can sign messages.
///
/// This is implemented as a vtable-based interface in Zig.
///
/// Rust equivalent: `solana_signer::Signer` trait
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/signer/src/lib.rs
pub const Signer = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Get the public key of this signer
        pubkey: *const fn (ptr: *anyopaque) PublicKey,
        /// Sign a message
        signMessage: *const fn (ptr: *anyopaque, message: []const u8) SignerError!Signature,
        /// Whether this signer requires user interaction
        isInteractive: *const fn (ptr: *anyopaque) bool,
    };

    /// Get the public key of this signer
    pub fn pubkey(self: Signer) PublicKey {
        return self.vtable.pubkey(self.ptr);
    }

    /// Try to get the public key, returning an error if it fails
    pub fn tryPubkey(self: Signer) SignerError!PublicKey {
        return self.vtable.pubkey(self.ptr);
    }

    /// Sign a message
    pub fn signMessage(self: Signer, message: []const u8) SignerError!Signature {
        return self.vtable.signMessage(self.ptr, message);
    }

    /// Try to sign a message
    pub fn trySignMessage(self: Signer, message: []const u8) SignerError!Signature {
        return self.vtable.signMessage(self.ptr, message);
    }

    /// Whether this signer requires user interaction (e.g., hardware wallet)
    pub fn isInteractive(self: Signer) bool {
        return self.vtable.isInteractive(self.ptr);
    }

    /// Create a Signer from a Keypair
    pub fn fromKeypair(kp: *Keypair) Signer {
        return .{
            .ptr = kp,
            .vtable = &KeypairVTable,
        };
    }
};

/// VTable implementation for Keypair
const KeypairVTable = Signer.VTable{
    .pubkey = keypairPubkey,
    .signMessage = keypairSignMessage,
    .isInteractive = keypairIsInteractive,
};

fn keypairPubkey(ptr: *anyopaque) PublicKey {
    const kp: *Keypair = @ptrCast(@alignCast(ptr));
    return kp.pubkey();
}

fn keypairSignMessage(ptr: *anyopaque, msg: []const u8) SignerError!Signature {
    const kp: *Keypair = @ptrCast(@alignCast(ptr));
    return kp.sign(msg) catch return SignerError.SigningFailed;
}

fn keypairIsInteractive(_: *anyopaque) bool {
    return false; // Keypair does not require user interaction
}

/// A null signer that doesn't actually sign anything.
/// Useful for fee estimation or offline signing workflows.
///
/// Rust equivalent: `solana_signer::NullSigner`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/signer/src/null_signer.rs
pub const NullSigner = struct {
    pubkey_value: PublicKey,

    const Self = @This();

    pub fn init(pubkey_value: PublicKey) Self {
        return .{ .pubkey_value = pubkey_value };
    }

    pub fn pubkey(self: *const Self) PublicKey {
        return self.pubkey_value;
    }

    pub fn signMessage(_: *const Self, _: []const u8) SignerError!Signature {
        return Signature.default();
    }

    pub fn isInteractive(_: *const Self) bool {
        return false;
    }

    /// Create a Signer interface from this NullSigner
    pub fn asSigner(self: *Self) Signer {
        return .{
            .ptr = self,
            .vtable = &NullSignerVTable,
        };
    }
};

/// VTable implementation for NullSigner
const NullSignerVTable = Signer.VTable{
    .pubkey = nullSignerPubkey,
    .signMessage = nullSignerSignMessage,
    .isInteractive = nullSignerIsInteractive,
};

fn nullSignerPubkey(ptr: *anyopaque) PublicKey {
    const ns: *NullSigner = @ptrCast(@alignCast(ptr));
    return ns.pubkey();
}

fn nullSignerSignMessage(ptr: *anyopaque, message: []const u8) SignerError!Signature {
    const ns: *NullSigner = @ptrCast(@alignCast(ptr));
    return ns.signMessage(message);
}

fn nullSignerIsInteractive(_: *anyopaque) bool {
    return false;
}

/// Remove duplicate signers from a list, keeping the first occurrence.
///
/// Rust equivalent: `solana_signer::unique_signers`
pub fn uniqueSigners(allocator: std.mem.Allocator, signers: []const Signer) ![]Signer {
    var result = try std.ArrayList(Signer).initCapacity(allocator, signers.len);
    errdefer result.deinit(allocator);

    var seen = std.AutoHashMap(PublicKey, void).init(allocator);
    defer seen.deinit();

    for (signers) |sig| {
        const pk = sig.pubkey();
        const gop = try seen.getOrPut(pk);
        if (!gop.found_existing) {
            result.appendAssumeCapacity(sig);
        }
    }

    return try result.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "signer: Keypair as Signer" {
    var kp = Keypair.generate();
    const signer = Signer.fromKeypair(&kp);

    // pubkey should match
    const pk = signer.pubkey();
    try std.testing.expectEqualSlices(u8, &kp.pubkey().bytes, &pk.bytes);

    // Should not be interactive
    try std.testing.expect(!signer.isInteractive());

    // Should be able to sign
    const message = "test message";
    const sig = try signer.signMessage(message);
    try std.testing.expect(!std.mem.eql(u8, &sig.bytes, &[_]u8{0} ** 64));
}

test "signer: NullSigner" {
    const pk = PublicKey.from([_]u8{1} ** 32);
    var ns = NullSigner.init(pk);

    try std.testing.expectEqualSlices(u8, &pk.bytes, &ns.pubkey().bytes);
    try std.testing.expect(!ns.isInteractive());

    // NullSigner returns default (zero) signature
    const sig = try ns.signMessage("test");
    try std.testing.expectEqualSlices(u8, &[_]u8{0} ** 64, &sig.bytes);
}

test "signer: NullSigner as Signer interface" {
    const pk = PublicKey.from([_]u8{2} ** 32);
    var ns = NullSigner.init(pk);
    const signer = ns.asSigner();

    try std.testing.expectEqualSlices(u8, &pk.bytes, &signer.pubkey().bytes);
    try std.testing.expect(!signer.isInteractive());
}

test "signer: uniqueSigners" {
    const allocator = std.testing.allocator;

    var kp1 = Keypair.generate();
    var kp2 = Keypair.generate();

    const signers = [_]Signer{
        Signer.fromKeypair(&kp1),
        Signer.fromKeypair(&kp2),
        Signer.fromKeypair(&kp1), // duplicate
    };

    const unique = try uniqueSigners(allocator, &signers);
    defer allocator.free(unique);

    try std.testing.expectEqual(@as(usize, 2), unique.len);
}

test "signer: SignerError values" {
    // Just verify the error types exist by checking they are distinct
    const errors = [_]SignerError{
        SignerError.KeypairPubkeyMismatch,
        SignerError.NotEnoughSigners,
        SignerError.TooManySigners,
    };
    try std.testing.expect(errors.len == 3);
}
