//! Transaction Signing Utilities
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/signer/src/lib.rs
//!
//! This module provides utilities for signing Solana transactions.
//! It supports:
//! - Single signer transactions
//! - Multi-signer (partial signing) transactions
//! - Signature verification
//!
//! ## Usage
//!
//! ```zig
//! // Sign a transaction
//! const keypair = Keypair.generate();
//! var tx = try TransactionBuilder.init(allocator)
//!     .setFeePayer(keypair.pubkey())
//!     .addInstruction(instruction)
//!     .build();
//! try signTransaction(&tx, &[_]*const Keypair{&keypair}, blockhash);
//!
//! // Verify signatures
//! try verifyTransaction(tx);
//! ```

const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;
const Hash = sdk.Hash;
const Signature = sdk.Signature;
const Keypair = sdk.Keypair;

const builder = @import("builder.zig");
const BuiltTransaction = builder.BuiltTransaction;
const Message = builder.Message;

/// Signer error types
pub const SignerError = error{
    /// Not enough signers provided for the transaction
    NotEnoughSigners,
    /// A required signer is missing
    MissingSigner,
    /// Signature verification failed
    SignatureVerificationFailed,
    /// Invalid signature
    InvalidSignature,
    /// Key derivation failed
    KeyDerivationFailed,
    /// Memory allocation failed
    OutOfMemory,
};

/// A trait-like interface for types that can sign messages.
///
/// This mirrors Rust's `Signer` trait from solana-sdk.
pub const Signer = struct {
    /// The context pointer
    ctx: *anyopaque,

    /// Virtual function table
    vtable: *const VTable,

    const VTable = struct {
        /// Get the public key
        pubkey: *const fn (ctx: *anyopaque) PublicKey,
        /// Sign a message
        sign: *const fn (ctx: *anyopaque, message: []const u8) SignerError!Signature,
        /// Check if this is an interactive signer (e.g., hardware wallet)
        isInteractive: *const fn (ctx: *anyopaque) bool,
    };

    /// Get the public key of this signer.
    pub fn pubkey(self: Signer) PublicKey {
        return self.vtable.pubkey(self.ctx);
    }

    /// Sign a message.
    pub fn sign(self: Signer, message: []const u8) SignerError!Signature {
        return self.vtable.sign(self.ctx, message);
    }

    /// Check if this is an interactive signer.
    pub fn isInteractive(self: Signer) bool {
        return self.vtable.isInteractive(self.ctx);
    }

    /// Create a Signer from a Keypair.
    pub fn fromKeypair(kp: *const Keypair) Signer {
        const impl = struct {
            fn pubkeyFn(ctx: *anyopaque) PublicKey {
                const keypair: *const Keypair = @ptrCast(@alignCast(ctx));
                return keypair.pubkey();
            }

            fn signFn(ctx: *anyopaque, message: []const u8) SignerError!Signature {
                const keypair: *const Keypair = @ptrCast(@alignCast(ctx));
                return keypair.sign(message);
            }

            fn isInteractiveFn(_: *anyopaque) bool {
                return false;
            }

            const vtable = VTable{
                .pubkey = pubkeyFn,
                .sign = signFn,
                .isInteractive = isInteractiveFn,
            };
        };

        return .{
            .ctx = @ptrCast(@constCast(kp)),
            .vtable = &impl.vtable,
        };
    }
};

/// Sign a transaction with the provided keypairs.
///
/// All required signers must be provided. If the blockhash differs from
/// the transaction's current blockhash, existing signatures will be cleared.
///
/// ## Parameters
/// - `tx`: The transaction to sign
/// - `signers`: Array of keypair pointers to sign with
/// - `recent_blockhash`: The recent blockhash to use
///
/// ## Errors
/// - `NotEnoughSigners` if not all required signers are provided
/// - `MissingSigner` if a required signer's keypair is not in the array
pub fn signTransaction(
    tx: *BuiltTransaction,
    signers: []const *const Keypair,
    recent_blockhash: Hash,
) SignerError!void {
    // Check if blockhash changed
    if (!std.mem.eql(u8, &tx.message.recent_blockhash.bytes, &recent_blockhash.bytes)) {
        tx.message.recent_blockhash = recent_blockhash;
        // Clear existing signatures
        if (tx.signatures) |sigs| {
            for (sigs) |*sig| {
                sig.* = Signature.default();
            }
        }
    }

    // Perform partial sign
    try partialSignTransaction(tx, signers, recent_blockhash);

    // Verify all signatures are present
    if (!tx.isSigned()) {
        return SignerError.NotEnoughSigners;
    }
}

/// Partially sign a transaction with a subset of required signers.
///
/// This allows multi-party signing where different signers may sign
/// at different times.
///
/// ## Parameters
/// - `tx`: The transaction to sign
/// - `signers`: Array of keypair pointers to sign with (subset of required)
/// - `recent_blockhash`: The recent blockhash to use
pub fn partialSignTransaction(
    tx: *BuiltTransaction,
    signers: []const *const Keypair,
    recent_blockhash: Hash,
) SignerError!void {
    // Check if blockhash changed
    if (!std.mem.eql(u8, &tx.message.recent_blockhash.bytes, &recent_blockhash.bytes)) {
        tx.message.recent_blockhash = recent_blockhash;
        // Clear existing signatures
        if (tx.signatures) |sigs| {
            for (sigs) |*sig| {
                sig.* = Signature.default();
            }
        }
    }

    // Use the transaction's sign method
    tx.sign(signers) catch |err| {
        return switch (err) {
            error.OutOfMemory => SignerError.OutOfMemory,
        };
    };
}

/// Verify all signatures in a transaction.
///
/// Checks that:
/// 1. All required signatures are present (non-zero)
/// 2. Each signature is valid for the corresponding public key
///
/// ## Errors
/// - `NotEnoughSigners` if signatures are missing
/// - `SignatureVerificationFailed` if any signature is invalid
pub fn verifyTransaction(tx: BuiltTransaction) SignerError!void {
    const sigs = tx.signatures orelse return SignerError.NotEnoughSigners;
    const num_required = tx.message.header.num_required_signatures;

    if (sigs.len < num_required) {
        return SignerError.NotEnoughSigners;
    }

    // Serialize message for verification
    const message_bytes = tx.message.serialize(tx.allocator) catch {
        return SignerError.OutOfMemory;
    };
    defer tx.allocator.free(message_bytes);

    // Verify each required signature
    for (sigs[0..num_required], 0..) |sig, i| {
        // Check for default (zero) signature
        if (std.mem.eql(u8, &sig.bytes, &[_]u8{0} ** 64)) {
            return SignerError.NotEnoughSigners;
        }

        // Verify signature
        const pubkey = tx.message.account_keys[i];
        sig.verify(message_bytes, &pubkey.bytes) catch {
            return SignerError.SignatureVerificationFailed;
        };
    }
}

/// Get the positions of signers in the transaction's account keys.
///
/// Returns an array of indices into account_keys for each provided signer.
/// If a signer is not found, null is returned for that position.
pub fn getSignerPositions(
    allocator: std.mem.Allocator,
    message: Message,
    signers: []const *const Keypair,
) ![]?usize {
    var positions = try allocator.alloc(?usize, signers.len);
    errdefer allocator.free(positions);

    for (signers, 0..) |kp, i| {
        const pk = kp.pubkey();
        positions[i] = null;

        for (message.account_keys[0..message.header.num_required_signatures], 0..) |account_key, j| {
            if (std.mem.eql(u8, &pk.bytes, &account_key.bytes)) {
                positions[i] = j;
                break;
            }
        }
    }

    return positions;
}

/// Sign a message with multiple keypairs.
///
/// Returns an array of signatures corresponding to each keypair.
pub fn signMessage(
    allocator: std.mem.Allocator,
    message: []const u8,
    signers: []const *const Keypair,
) ![]Signature {
    var signatures = try allocator.alloc(Signature, signers.len);
    errdefer allocator.free(signatures);

    for (signers, 0..) |kp, i| {
        signatures[i] = kp.sign(message);
    }

    return signatures;
}

/// Presigner - a struct that holds a pre-computed signature.
///
/// Useful for:
/// - Offline signing workflows
/// - Multi-party signing where signatures are collected separately
/// - Testing with known signatures
pub const Presigner = struct {
    pubkey_val: PublicKey,
    signature: Signature,

    const Self = @This();

    /// Create a new presigner with a public key and pre-computed signature.
    pub fn init(pubkey_val: PublicKey, signature: Signature) Self {
        return .{
            .pubkey_val = pubkey_val,
            .signature = signature,
        };
    }

    /// Get the public key.
    pub fn pubkey(self: Self) PublicKey {
        return self.pubkey_val;
    }

    /// Return the pre-computed signature (ignores the message).
    pub fn sign(self: Self, _: []const u8) Signature {
        return self.signature;
    }
};

/// NullSigner - a signer that returns default (zero) signatures.
///
/// Useful for:
/// - Placeholder signers in transaction construction
/// - Fee estimation where actual signatures aren't needed
/// - Testing transaction structure without valid signatures
pub const NullSigner = struct {
    pubkey_val: PublicKey,

    const Self = @This();

    /// Create a new null signer with the given public key.
    pub fn init(pubkey_val: PublicKey) Self {
        return .{
            .pubkey_val = pubkey_val,
        };
    }

    /// Get the public key.
    pub fn pubkey(self: Self) PublicKey {
        return self.pubkey_val;
    }

    /// Return a default (zero) signature.
    pub fn sign(_: Self, _: []const u8) Signature {
        return Signature.default();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "signer: Signer interface from Keypair" {
    const kp = Keypair.generate();
    const signer = Signer.fromKeypair(&kp);

    // Test pubkey
    const pk = signer.pubkey();
    try std.testing.expectEqualSlices(u8, &kp.pubkey().bytes, &pk.bytes);

    // Test isInteractive
    try std.testing.expect(!signer.isInteractive());

    // Test sign
    const message = "test message";
    const sig = try signer.sign(message);
    try std.testing.expect(!std.mem.eql(u8, &sig.bytes, &[_]u8{0} ** 64));
}

test "signer: Presigner" {
    const pk = PublicKey.from([_]u8{1} ** 32);
    const sig = Signature.from([_]u8{2} ** 64);

    const presigner = Presigner.init(pk, sig);

    try std.testing.expectEqualSlices(u8, &pk.bytes, &presigner.pubkey().bytes);

    const returned_sig = presigner.sign("any message");
    try std.testing.expectEqualSlices(u8, &sig.bytes, &returned_sig.bytes);
}

test "signer: NullSigner" {
    const pk = PublicKey.from([_]u8{1} ** 32);
    const null_signer = NullSigner.init(pk);

    try std.testing.expectEqualSlices(u8, &pk.bytes, &null_signer.pubkey().bytes);

    const sig = null_signer.sign("any message");
    try std.testing.expectEqualSlices(u8, &[_]u8{0} ** 64, &sig.bytes);
}

test "signer: signMessage" {
    const allocator = std.testing.allocator;

    const kp1 = Keypair.generate();
    const kp2 = Keypair.generate();

    const message = "test message to sign";
    const signers = [_]*const Keypair{ &kp1, &kp2 };

    const signatures = try signMessage(allocator, message, &signers);
    defer allocator.free(signatures);

    try std.testing.expectEqual(@as(usize, 2), signatures.len);

    // Both signatures should be non-zero
    try std.testing.expect(!std.mem.eql(u8, &signatures[0].bytes, &[_]u8{0} ** 64));
    try std.testing.expect(!std.mem.eql(u8, &signatures[1].bytes, &[_]u8{0} ** 64));

    // Signatures should be different
    try std.testing.expect(!std.mem.eql(u8, &signatures[0].bytes, &signatures[1].bytes));
}

test "signer: getSignerPositions" {
    const allocator = std.testing.allocator;

    const kp1 = Keypair.generate();
    const kp2 = Keypair.generate();
    const kp3 = Keypair.generate();

    const account_keys = [_]PublicKey{
        kp1.pubkey(),
        kp2.pubkey(),
        PublicKey.from([_]u8{0xFF} ** 32), // non-signer
    };

    const message = builder.Message{
        .header = builder.MessageHeader{
            .num_required_signatures = 2,
            .num_readonly_signed_accounts = 0,
            .num_readonly_unsigned_accounts = 0,
        },
        .account_keys = &account_keys,
        .recent_blockhash = Hash.default(),
        .instructions = &[_]builder.CompiledInstruction{},
    };

    // kp3 is not in the account_keys
    const signers = [_]*const Keypair{ &kp1, &kp3, &kp2 };

    const positions = try getSignerPositions(allocator, message, &signers);
    defer allocator.free(positions);

    try std.testing.expectEqual(@as(?usize, 0), positions[0]); // kp1 at position 0
    try std.testing.expectEqual(@as(?usize, null), positions[1]); // kp3 not found
    try std.testing.expectEqual(@as(?usize, 1), positions[2]); // kp2 at position 1
}
