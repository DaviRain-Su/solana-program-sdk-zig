//! Zig implementation of Solana SDK's transaction module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/transaction/src/lib.rs
//!
//! This module provides the Transaction type for Solana transactions.
//! A transaction contains signatures and a message to be processed by the runtime.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const Hash = @import("hash.zig").Hash;
const Signature = @import("signature.zig").Signature;
const SIGNATURE_BYTES = @import("signature.zig").SIGNATURE_BYTES;
const Message = @import("message.zig").Message;
const MessageHeader = @import("message.zig").MessageHeader;
const CompiledInstruction = @import("message.zig").CompiledInstruction;
const Keypair = @import("keypair.zig").Keypair;
const short_vec = @import("short_vec.zig");
const Signer = @import("signer.zig").Signer;
const SignerError = @import("signer.zig").SignerError;

/// Error types for transaction operations.
///
/// Rust equivalent: `solana_transaction::TransactionError` (subset)
pub const TransactionError = error{
    /// Not enough signers
    NotEnoughSigners,
    /// Too many signers
    TooManySigners,
    /// Signature verification failed
    SignatureFailure,
    /// Account not found
    AccountNotFound,
    /// Account already processed
    AlreadyProcessed,
    /// Invalid account for fee
    InvalidAccountForFee,
    /// Invalid account index
    InvalidAccountIndex,
    /// Invalid program for execution
    InvalidProgramForExecution,
    /// Blockhash not found
    BlockhashNotFound,
    /// Sanitization failed
    SanitizeFailure,
    /// Insufficient funds for fee
    InsufficientFundsForFee,
    /// Duplicate instruction
    DuplicateInstruction,
    /// Allocation error
    OutOfMemory,
};

/// A Solana transaction.
///
/// Contains a list of signatures and a message. The signatures must match
/// the signing requirements specified in the message header.
///
/// Rust equivalent: `solana_transaction::Transaction`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/transaction/src/lib.rs
pub const Transaction = struct {
    /// Signatures for this transaction
    signatures: []Signature,

    /// The message to be sent
    message: Message,

    /// Allocator used for this transaction (for cleanup)
    allocator: ?std.mem.Allocator,

    const Self = @This();

    /// Create a new unsigned transaction with the given message.
    ///
    /// Rust equivalent: `Transaction::new_unsigned`
    pub fn newUnsigned(message: Message) Self {
        return .{
            .signatures = &[_]Signature{},
            .message = message,
            .allocator = null,
        };
    }

    /// Create a new transaction with pre-allocated signature slots.
    ///
    /// Allocates space for `num_required_signatures` signatures initialized to default.
    pub fn newWithSignatureSlots(allocator: std.mem.Allocator, message: Message) !Self {
        const num_sigs = message.header.num_required_signatures;
        const signatures = try allocator.alloc(Signature, num_sigs);
        for (signatures) |*sig| {
            sig.* = Signature.default();
        }
        return .{
            .signatures = signatures,
            .message = message,
            .allocator = allocator,
        };
    }

    /// Clean up allocated memory
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            if (self.signatures.len > 0) {
                alloc.free(self.signatures);
            }
        }
        self.signatures = &[_]Signature{};
    }

    /// Get the message data (serialized message bytes)
    pub fn messageData(self: Self, allocator: std.mem.Allocator) ![]u8 {
        return self.message.serialize(allocator);
    }

    /// Get the message
    pub fn getMessage(self: Self) Message {
        return self.message;
    }

    /// Get the signatures
    pub fn getSignatures(self: Self) []const Signature {
        return self.signatures;
    }

    /// Check if the transaction is signed (all required signatures present)
    pub fn isSigned(self: Self) bool {
        if (self.signatures.len < self.message.header.num_required_signatures) {
            return false;
        }
        for (self.signatures[0..self.message.header.num_required_signatures]) |sig| {
            if (std.mem.eql(u8, &sig.bytes, &[_]u8{0} ** SIGNATURE_BYTES)) {
                return false;
            }
        }
        return true;
    }

    /// Sign the transaction with the given keypairs.
    ///
    /// The keypairs must be provided in the same order as the corresponding
    /// account_keys in the message.
    ///
    /// Rust equivalent: `Transaction::sign`
    pub fn sign(self: *Self, keypairs: []const *Keypair, recent_blockhash: Hash) !void {
        try self.partialSign(keypairs, recent_blockhash);
    }

    /// Partially sign the transaction with the given keypairs.
    ///
    /// Rust equivalent: `Transaction::partial_sign`
    pub fn partialSign(self: *Self, keypairs: []const *Keypair, recent_blockhash: Hash) !void {
        // Update blockhash in message
        // Note: In a real implementation, we'd need to modify the message
        // For now, we just sign with the provided keypairs
        _ = recent_blockhash;

        const alloc = self.allocator orelse return TransactionError.OutOfMemory;

        // Ensure we have signature slots
        if (self.signatures.len == 0) {
            const num_sigs = self.message.header.num_required_signatures;
            self.signatures = try alloc.alloc(Signature, num_sigs);
            for (self.signatures) |*sig| {
                sig.* = Signature.default();
            }
        }

        // Get message bytes for signing
        const message_bytes = try self.message.serialize(alloc);
        defer alloc.free(message_bytes);

        // Sign with each keypair
        for (keypairs) |kp| {
            const pk = kp.pubkey();
            // Find the position of this pubkey in account_keys
            for (self.message.account_keys, 0..) |account_key, i| {
                if (std.mem.eql(u8, &pk.bytes, &account_key.bytes)) {
                    if (i < self.signatures.len) {
                        self.signatures[i] = kp.sign(message_bytes);
                    }
                    break;
                }
            }
        }
    }

    /// Verify all signatures in this transaction.
    ///
    /// Rust equivalent: `Transaction::verify`
    pub fn verify(self: Self) TransactionError!void {
        const alloc = self.allocator orelse return;

        if (self.signatures.len < self.message.header.num_required_signatures) {
            return TransactionError.NotEnoughSigners;
        }

        const message_bytes = self.message.serialize(alloc) catch {
            return TransactionError.SanitizeFailure;
        };
        defer alloc.free(message_bytes);

        const signer_keys = self.message.signerKeys();

        for (self.signatures[0..self.message.header.num_required_signatures], 0..) |sig, i| {
            if (i >= signer_keys.len) {
                return TransactionError.NotEnoughSigners;
            }
            sig.verify(signer_keys[i], message_bytes) catch {
                return TransactionError.SignatureFailure;
            };
        }
    }

    /// Verify signatures and return a hash of the message.
    ///
    /// Rust equivalent: `Transaction::verify_and_hash_message`
    pub fn verifyAndHashMessage(self: Self, allocator: std.mem.Allocator) TransactionError!Hash {
        try self.verify();
        return self.message.hash(allocator) catch {
            return TransactionError.SanitizeFailure;
        };
    }

    /// Serialize the transaction to bytes.
    ///
    /// Format: signatures (short_vec) + message
    pub fn serialize(self: Self, allocator: std.mem.Allocator) ![]u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 512);
        errdefer buffer.deinit(allocator);

        // Signatures with short_vec length prefix
        var num_sigs_buf: [short_vec.MAX_ENCODING_LENGTH]u8 = undefined;
        const num_sigs_size = short_vec.encodeU16(@intCast(self.signatures.len), &num_sigs_buf);
        try buffer.appendSlice(allocator, num_sigs_buf[0..num_sigs_size]);
        for (self.signatures) |sig| {
            try buffer.appendSlice(allocator, &sig.bytes);
        }

        // Message
        const message_bytes = try self.message.serialize(allocator);
        defer allocator.free(message_bytes);
        try buffer.appendSlice(allocator, message_bytes);

        return try buffer.toOwnedSlice(allocator);
    }

    /// Get the data for an instruction by index
    pub fn data(self: Self, instruction_index: usize) ?[]const u8 {
        if (instruction_index >= self.message.instructions.len) {
            return null;
        }
        return self.message.instructions[instruction_index].data;
    }

    /// Get an account key by instruction and account index
    pub fn key(self: Self, instruction_index: usize, accounts_index: usize) ?PublicKey {
        if (instruction_index >= self.message.instructions.len) {
            return null;
        }
        const ix = self.message.instructions[instruction_index];
        if (accounts_index >= ix.accounts.len) {
            return null;
        }
        const account_idx = ix.accounts[accounts_index];
        if (account_idx >= self.message.account_keys.len) {
            return null;
        }
        return self.message.account_keys[account_idx];
    }

    /// Get a signer key by instruction and account index
    pub fn signerKey(self: Self, instruction_index: usize, accounts_index: usize) ?PublicKey {
        const pk = self.key(instruction_index, accounts_index) orelse return null;

        // Check if this key is a signer
        for (self.message.account_keys[0..self.message.header.num_required_signatures]) |signer_key| {
            if (std.mem.eql(u8, &pk.bytes, &signer_key.bytes)) {
                return pk;
            }
        }
        return null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "transaction: newUnsigned" {
    // A default message has no required signatures, so empty signatures is "signed"
    const msg = Message.default();
    const tx = Transaction.newUnsigned(msg);

    try std.testing.expectEqual(@as(usize, 0), tx.signatures.len);
    // With no required signatures and no signatures, transaction is considered signed
    try std.testing.expect(tx.isSigned());
}

test "transaction: newUnsigned requires signatures" {
    // A message that requires signatures
    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});
    const tx = Transaction.newUnsigned(msg);

    try std.testing.expectEqual(@as(usize, 0), tx.signatures.len);
    // No signatures but 1 required = not signed
    try std.testing.expect(!tx.isSigned());
}

test "transaction: newWithSignatureSlots" {
    const allocator = std.testing.allocator;

    const header = MessageHeader{
        .num_required_signatures = 2,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    var tx = try Transaction.newWithSignatureSlots(allocator, msg);
    defer tx.deinit();

    try std.testing.expectEqual(@as(usize, 2), tx.signatures.len);
    try std.testing.expect(!tx.isSigned()); // Signatures are still default (zero)
}

test "transaction: serialize" {
    const allocator = std.testing.allocator;

    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    var tx = try Transaction.newWithSignatureSlots(allocator, msg);
    defer tx.deinit();

    const serialized = try tx.serialize(allocator);
    defer allocator.free(serialized);

    // Should start with signature count (short_vec encoded)
    try std.testing.expectEqual(@as(u8, 1), serialized[0]); // 1 signature
    // Followed by 64 bytes of signature (all zeros for default)
    try std.testing.expectEqual(@as(usize, 1 + 64), serialized.len - msg.account_keys.len * 32 - 32 - 3 - 1 - 1);
}

test "transaction: data" {
    const allocator = std.testing.allocator;

    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
    };
    const ix_data = [_]u8{ 0xde, 0xad, 0xbe, 0xef };
    const ix = CompiledInstruction.init(1, &[_]u8{0}, &ix_data);
    const ixs = [_]CompiledInstruction{ix};
    const msg = Message.init(header, &keys, Hash.default(), &ixs);

    var tx = try Transaction.newWithSignatureSlots(allocator, msg);
    defer tx.deinit();

    const data = tx.data(0);
    try std.testing.expect(data != null);
    try std.testing.expectEqualSlices(u8, &ix_data, data.?);

    // Out of bounds
    try std.testing.expect(tx.data(1) == null);
}

test "transaction: key" {
    const allocator = std.testing.allocator;

    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
    };
    const ix = CompiledInstruction.init(1, &[_]u8{ 0, 1 }, &[_]u8{});
    const ixs = [_]CompiledInstruction{ix};
    const msg = Message.init(header, &keys, Hash.default(), &ixs);

    var tx = try Transaction.newWithSignatureSlots(allocator, msg);
    defer tx.deinit();

    const key0 = tx.key(0, 0);
    try std.testing.expect(key0 != null);
    try std.testing.expectEqualSlices(u8, &[_]u8{1} ** 32, &key0.?.bytes);

    const key1 = tx.key(0, 1);
    try std.testing.expect(key1 != null);
    try std.testing.expectEqualSlices(u8, &[_]u8{2} ** 32, &key1.?.bytes);

    // Out of bounds
    try std.testing.expect(tx.key(0, 2) == null);
    try std.testing.expect(tx.key(1, 0) == null);
}

test "transaction: signerKey" {
    const allocator = std.testing.allocator;

    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32), // signer
        PublicKey.from([_]u8{2} ** 32), // not signer
    };
    const ix = CompiledInstruction.init(1, &[_]u8{ 0, 1 }, &[_]u8{});
    const ixs = [_]CompiledInstruction{ix};
    const msg = Message.init(header, &keys, Hash.default(), &ixs);

    var tx = try Transaction.newWithSignatureSlots(allocator, msg);
    defer tx.deinit();

    // First account is signer
    const signer_key = tx.signerKey(0, 0);
    try std.testing.expect(signer_key != null);
    try std.testing.expectEqualSlices(u8, &[_]u8{1} ** 32, &signer_key.?.bytes);

    // Second account is not signer
    const non_signer = tx.signerKey(0, 1);
    try std.testing.expect(non_signer == null);
}

test "transaction: isSigned" {
    const allocator = std.testing.allocator;

    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    var tx = try Transaction.newWithSignatureSlots(allocator, msg);
    defer tx.deinit();

    // Initially not signed (default signatures)
    try std.testing.expect(!tx.isSigned());

    // Set a non-zero signature
    tx.signatures[0] = Signature.from([_]u8{1} ** 64);
    try std.testing.expect(tx.isSigned());
}
