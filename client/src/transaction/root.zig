//! Transaction Building and Signing Module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/transaction/src/lib.rs
//!
//! This module provides utilities for building and signing Solana transactions.
//!
//! ## Overview
//!
//! The transaction module provides:
//! - `TransactionBuilder` - Fluent API for constructing transactions
//! - `BuiltTransaction` - A complete transaction ready for signing/submission
//! - Signing utilities for single and multi-party signing
//! - Verification utilities
//!
//! ## Quick Start
//!
//! ```zig
//! const tx = @import("transaction");
//!
//! // Create a transaction builder
//! var builder = tx.TransactionBuilder.init(allocator);
//! defer builder.deinit();
//!
//! // Build the transaction
//! _ = builder.setFeePayer(payer_pubkey);
//! _ = builder.setRecentBlockhash(blockhash);
//! _ = try builder.addInstruction(.{
//!     .program_id = program_id,
//!     .accounts = &accounts,
//!     .data = &data,
//! });
//!
//! // Build and sign
//! var transaction = try builder.buildSigned(&[_]*const Keypair{&payer_kp});
//! defer transaction.deinit();
//!
//! // Serialize for submission
//! const bytes = try transaction.serialize();
//! defer allocator.free(bytes);
//! ```
//!
//! ## Multi-Party Signing
//!
//! For transactions requiring multiple signers:
//!
//! ```zig
//! // Party 1: Build and partially sign
//! var transaction = try builder.build();
//! try tx.signer.partialSignTransaction(&transaction, &[_]*const Keypair{&party1_kp}, blockhash);
//!
//! // Serialize and send to Party 2...
//!
//! // Party 2: Add their signature
//! try tx.signer.partialSignTransaction(&transaction, &[_]*const Keypair{&party2_kp}, blockhash);
//!
//! // Verify all signatures present
//! try tx.signer.verifyTransaction(transaction);
//! ```

const std = @import("std");

// Re-export SDK types for convenience
pub const sdk = @import("solana_sdk");
pub const PublicKey = sdk.PublicKey;
pub const Hash = sdk.Hash;
pub const Signature = sdk.Signature;
pub const Keypair = sdk.Keypair;

// ============================================================================
// Builder Module
// ============================================================================

pub const builder = @import("builder.zig");

/// Transaction builder for constructing Solana transactions.
pub const TransactionBuilder = builder.TransactionBuilder;

/// A built transaction ready for signing or submission.
pub const BuiltTransaction = builder.BuiltTransaction;

/// A transaction message.
pub const Message = builder.Message;

/// Message header containing signature and account type counts.
pub const MessageHeader = builder.MessageHeader;

/// A compiled instruction with account indices.
pub const CompiledInstruction = builder.CompiledInstruction;

/// Input for adding an instruction to the builder.
pub const InstructionInput = builder.InstructionInput;

/// Error types for transaction building.
pub const BuilderError = builder.BuilderError;

// ============================================================================
// Signer Module
// ============================================================================

pub const signer = @import("signer.zig");

/// A trait-like interface for types that can sign messages.
pub const Signer = signer.Signer;

/// Error types for signing operations.
pub const SignerError = signer.SignerError;

/// A presigner with a pre-computed signature.
pub const Presigner = signer.Presigner;

/// A null signer that returns zero signatures.
pub const NullSigner = signer.NullSigner;

/// Sign a transaction with the provided keypairs.
pub const signTransaction = signer.signTransaction;

/// Partially sign a transaction with a subset of required signers.
pub const partialSignTransaction = signer.partialSignTransaction;

/// Verify all signatures in a transaction.
pub const verifyTransaction = signer.verifyTransaction;

/// Get the positions of signers in the transaction's account keys.
pub const getSignerPositions = signer.getSignerPositions;

/// Sign a message with multiple keypairs.
pub const signMessage = signer.signMessage;

// ============================================================================
// Convenience Functions
// ============================================================================

/// Create a simple transfer transaction.
///
/// This is a convenience function for creating a basic SOL transfer.
///
/// ## Parameters
/// - `allocator`: Memory allocator
/// - `from`: The sender keypair
/// - `to`: The recipient public key
/// - `lamports`: Amount to transfer in lamports
/// - `recent_blockhash`: Recent blockhash for the transaction
///
/// ## Returns
/// A signed transaction ready for submission.
pub fn createTransfer(
    allocator: std.mem.Allocator,
    from: *const Keypair,
    to: PublicKey,
    lamports: u64,
    recent_blockhash: Hash,
) !BuiltTransaction {
    // System program ID (all zeros except last byte)
    const system_program_id = PublicKey.from([_]u8{0} ** 32);

    // Build transfer instruction data
    // Format: [4 bytes discriminant (2 = transfer)] + [8 bytes lamports]
    var data: [12]u8 = undefined;
    std.mem.writeInt(u32, data[0..4], 2, .little); // Transfer instruction
    std.mem.writeInt(u64, data[4..12], lamports, .little);

    const from_pubkey = from.pubkey();

    // Account metas for transfer
    const accounts = [_]sdk.AccountMeta{
        .{ .pubkey = from_pubkey, .is_signer = true, .is_writable = true },
        .{ .pubkey = to, .is_signer = false, .is_writable = true },
    };

    var tx_builder = TransactionBuilder.init(allocator);
    defer tx_builder.deinit();

    _ = tx_builder.setFeePayer(from_pubkey);
    _ = tx_builder.setRecentBlockhash(recent_blockhash);
    _ = try tx_builder.addInstruction(.{
        .program_id = system_program_id,
        .accounts = &accounts,
        .data = &data,
    });

    return try tx_builder.buildSigned(&[_]*const Keypair{from});
}

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all submodule tests
    std.testing.refAllDecls(@This());
}

test "transaction: module exports" {
    // Verify all expected types are exported
    _ = TransactionBuilder;
    _ = BuiltTransaction;
    _ = Message;
    _ = MessageHeader;
    _ = CompiledInstruction;
    _ = InstructionInput;
    _ = BuilderError;

    _ = Signer;
    _ = SignerError;
    _ = Presigner;
    _ = NullSigner;

    _ = signTransaction;
    _ = partialSignTransaction;
    _ = verifyTransaction;
    _ = getSignerPositions;
    _ = signMessage;
}

test "transaction: createTransfer" {
    const allocator = std.testing.allocator;

    const from_kp = Keypair.generate();
    const to_pk = PublicKey.from([_]u8{2} ** 32);
    const blockhash = Hash.from([_]u8{3} ** 32);

    var tx = try createTransfer(allocator, &from_kp, to_pk, 1000000, blockhash);
    defer tx.deinit();

    // Verify transaction is signed
    try std.testing.expect(tx.isSigned());

    // Verify message structure
    try std.testing.expectEqual(@as(u8, 1), tx.message.header.num_required_signatures);

    // Should have 3 accounts: from, to, system_program
    try std.testing.expectEqual(@as(usize, 3), tx.message.account_keys.len);

    // First account should be the signer (from)
    try std.testing.expectEqualSlices(u8, &from_kp.pubkey().bytes, &tx.message.account_keys[0].bytes);
}
