//! Transaction Builder and Signer Integration Tests
//!
//! These tests require a running Solana validator (e.g., surfpool or solana-test-validator)
//! at localhost:8899.
//!
//! To run these tests:
//!   1. Start a local validator: `surfpool start --no-tui` or `solana-test-validator`
//!   2. Run tests: `../solana-zig/zig build integration-test`
//!
//! Note: Some tests require airdrop capability which may not be available on all validators.

const std = @import("std");
const rpc_client = @import("rpc_client");
const sdk = @import("solana_sdk");
const transaction = @import("transaction");

const RpcClient = rpc_client.RpcClient;
const ClientError = rpc_client.ClientError;
const PublicKey = sdk.PublicKey;
const Hash = sdk.Hash;
const Signature = sdk.Signature;
const Keypair = sdk.Keypair;
const AccountMeta = sdk.AccountMeta;

const TransactionBuilder = transaction.TransactionBuilder;
const BuiltTransaction = transaction.BuiltTransaction;
const InstructionInput = transaction.InstructionInput;

const LOCALNET_RPC = "http://127.0.0.1:8899";

/// Check if local RPC is available
fn isLocalRpcAvailable() bool {
    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();
    return client.isHealthy();
}

/// Request airdrop and wait for confirmation
fn requestAirdropAndConfirm(client: *RpcClient, pubkey: PublicKey, lamports: u64) !Signature {
    const sig = try client.requestAirdrop(pubkey, lamports);

    // Wait for confirmation (poll up to 30 seconds)
    var attempts: u32 = 0;
    while (attempts < 60) : (attempts += 1) {
        const statuses = try client.getSignatureStatuses(&.{sig});
        defer client.allocator.free(statuses);

        if (statuses.len > 0 and statuses[0] != null) {
            const status = statuses[0].?;
            if (status.confirmation_status) |cs| {
                if (cs == .confirmed or cs == .finalized) {
                    return sig;
                }
            }
        }
        std.Thread.sleep(500 * std.time.ns_per_ms);
    }

    return error.AirdropTimeout;
}

// ============================================================================
// Transaction Builder Integration Tests
// ============================================================================

test "integration: TransactionBuilder basic construction" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    // Generate a keypair for testing
    const kp = Keypair.generate();
    const pubkey = kp.pubkey();

    // Get recent blockhash
    const blockhash_result = try client.getLatestBlockhash();
    const blockhash = blockhash_result.blockhash;

    // Create a memo instruction (simplest possible instruction)
    const memo_program_id = try PublicKey.fromBase58("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");
    const memo_data = "Hello from Zig!";

    // Build transaction
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setFeePayer(pubkey);
    _ = builder.setRecentBlockhash(blockhash);
    _ = try builder.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = memo_data,
    });

    // Build unsigned transaction
    var tx = try builder.build();
    defer tx.deinit();

    // Verify transaction structure
    try std.testing.expectEqual(@as(u8, 1), tx.message.header.num_required_signatures);
    try std.testing.expectEqual(@as(usize, 2), tx.message.account_keys.len); // fee_payer + memo_program
    try std.testing.expect(!tx.isSigned());
}

test "integration: TransactionBuilder with signing" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    // Generate a keypair
    const kp = Keypair.generate();
    const pubkey = kp.pubkey();

    // Get recent blockhash
    const blockhash_result = try client.getLatestBlockhash();
    const blockhash = blockhash_result.blockhash;

    // Create a simple memo instruction
    const memo_program_id = try PublicKey.fromBase58("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");

    // Build and sign transaction
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setFeePayer(pubkey);
    _ = builder.setRecentBlockhash(blockhash);
    _ = try builder.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = "Test memo",
    });

    var tx = try builder.buildSigned(&[_]*const Keypair{&kp});
    defer tx.deinit();

    // Verify transaction is signed
    try std.testing.expect(tx.isSigned());

    // Verify signature is not zero
    const sig = tx.getSignature();
    try std.testing.expect(sig != null);
    try std.testing.expect(!std.mem.eql(u8, &sig.?.bytes, &[_]u8{0} ** 64));
}

test "integration: TransactionBuilder serialize and deserialize" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const kp = Keypair.generate();
    const pubkey = kp.pubkey();

    const blockhash_result = try client.getLatestBlockhash();
    const blockhash = blockhash_result.blockhash;

    const memo_program_id = try PublicKey.fromBase58("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");

    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setFeePayer(pubkey);
    _ = builder.setRecentBlockhash(blockhash);
    _ = try builder.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = "Serialize test",
    });

    var tx = try builder.buildSigned(&[_]*const Keypair{&kp});
    defer tx.deinit();

    // Serialize transaction
    const serialized = try tx.serialize();
    defer allocator.free(serialized);

    // Verify serialized data is valid
    try std.testing.expect(serialized.len > 0);

    // First byte should be signature count (1 for single signer)
    try std.testing.expectEqual(@as(u8, 1), serialized[0]);

    // Next 64 bytes should be the signature
    try std.testing.expect(!std.mem.eql(u8, serialized[1..65], &[_]u8{0} ** 64));
}

test "integration: createTransfer helper function" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const from_kp = Keypair.generate();
    const to_pk = Keypair.generate().pubkey();

    const blockhash_result = try client.getLatestBlockhash();
    const blockhash = blockhash_result.blockhash;

    // Create transfer transaction using convenience function
    var tx = try transaction.createTransfer(allocator, &from_kp, to_pk, 1000000, blockhash);
    defer tx.deinit();

    // Verify transaction structure
    try std.testing.expect(tx.isSigned());
    try std.testing.expectEqual(@as(u8, 1), tx.message.header.num_required_signatures);

    // Should have 3 accounts: from, to, system_program
    try std.testing.expectEqual(@as(usize, 3), tx.message.account_keys.len);

    // First account should be the signer (from)
    try std.testing.expectEqualSlices(u8, &from_kp.pubkey().bytes, &tx.message.account_keys[0].bytes);
}

test "integration: send memo transaction to localnet" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    // Generate a keypair and request airdrop
    const kp = Keypair.generate();
    const pubkey = kp.pubkey();

    // Request airdrop for fees
    _ = requestAirdropAndConfirm(&client, pubkey, 1_000_000_000) catch |err| {
        // Airdrop may not be available on all validators
        if (err == error.AirdropTimeout or err == ClientError.RpcError) {
            std.debug.print("Skipping test: airdrop not available\n", .{});
            return error.SkipZigTest;
        }
        return err;
    };

    // Get recent blockhash
    const blockhash_result = try client.getLatestBlockhash();
    const blockhash = blockhash_result.blockhash;

    // Create a memo transaction
    const memo_program_id = try PublicKey.fromBase58("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");

    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setFeePayer(pubkey);
    _ = builder.setRecentBlockhash(blockhash);
    _ = try builder.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = "Hello from Zig SDK!",
    });

    var tx = try builder.buildSigned(&[_]*const Keypair{&kp});
    defer tx.deinit();

    // Serialize and send
    const serialized = try tx.serialize();
    defer allocator.free(serialized);

    const signature = try client.sendTransaction(serialized);

    // Verify we got a valid signature back
    try std.testing.expect(!std.mem.eql(u8, &signature.bytes, &[_]u8{0} ** 64));

    // Wait for confirmation
    var attempts: u32 = 0;
    var confirmed = false;
    while (attempts < 30) : (attempts += 1) {
        const statuses = try client.getSignatureStatuses(&.{signature});
        defer allocator.free(statuses);

        if (statuses.len > 0 and statuses[0] != null) {
            confirmed = true;
            break;
        }
        std.Thread.sleep(500 * std.time.ns_per_ms);
    }

    try std.testing.expect(confirmed);
}

test "integration: send SOL transfer to localnet" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    // Generate sender and receiver keypairs
    const sender_kp = Keypair.generate();
    const sender_pubkey = sender_kp.pubkey();
    const receiver_kp = Keypair.generate();
    const receiver_pubkey = receiver_kp.pubkey();

    // Request airdrop to sender
    _ = requestAirdropAndConfirm(&client, sender_pubkey, 2_000_000_000) catch |err| {
        if (err == error.AirdropTimeout or err == ClientError.RpcError) {
            std.debug.print("Skipping test: airdrop not available\n", .{});
            return error.SkipZigTest;
        }
        return err;
    };

    // Get initial balances
    const sender_balance_before = try client.getBalance(sender_pubkey);
    const receiver_balance_before = try client.getBalance(receiver_pubkey);

    // Get recent blockhash
    const blockhash_result = try client.getLatestBlockhash();
    const blockhash = blockhash_result.blockhash;

    // Create transfer transaction
    const transfer_amount: u64 = 500_000_000; // 0.5 SOL
    var tx = try transaction.createTransfer(allocator, &sender_kp, receiver_pubkey, transfer_amount, blockhash);
    defer tx.deinit();

    // Send transaction
    const serialized = try tx.serialize();
    defer allocator.free(serialized);

    const signature = try client.sendTransaction(serialized);

    // Wait for confirmation
    var attempts: u32 = 0;
    var confirmed = false;
    while (attempts < 30) : (attempts += 1) {
        const statuses = try client.getSignatureStatuses(&.{signature});
        defer allocator.free(statuses);

        if (statuses.len > 0 and statuses[0] != null) {
            const status = statuses[0].?;
            if (status.err == null) {
                confirmed = true;
                break;
            }
        }
        std.Thread.sleep(500 * std.time.ns_per_ms);
    }

    try std.testing.expect(confirmed);

    // Verify balances changed
    const sender_balance_after = try client.getBalance(sender_pubkey);
    const receiver_balance_after = try client.getBalance(receiver_pubkey);

    // Sender should have less (transfer + fees)
    try std.testing.expect(sender_balance_after < sender_balance_before);

    // Receiver should have exactly transfer_amount more
    try std.testing.expectEqual(receiver_balance_before + transfer_amount, receiver_balance_after);
}

test "integration: multi-instruction transaction" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const kp = Keypair.generate();
    const pubkey = kp.pubkey();

    // Request airdrop
    _ = requestAirdropAndConfirm(&client, pubkey, 1_000_000_000) catch |err| {
        if (err == error.AirdropTimeout or err == ClientError.RpcError) {
            std.debug.print("Skipping test: airdrop not available\n", .{});
            return error.SkipZigTest;
        }
        return err;
    };

    const blockhash_result = try client.getLatestBlockhash();
    const blockhash = blockhash_result.blockhash;

    const memo_program_id = try PublicKey.fromBase58("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");

    // Build transaction with multiple memo instructions
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setFeePayer(pubkey);
    _ = builder.setRecentBlockhash(blockhash);

    // Add first memo
    _ = try builder.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = "First memo",
    });

    // Add second memo
    _ = try builder.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = "Second memo",
    });

    // Add third memo
    _ = try builder.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = "Third memo",
    });

    var tx = try builder.buildSigned(&[_]*const Keypair{&kp});
    defer tx.deinit();

    // Verify 3 instructions
    try std.testing.expectEqual(@as(usize, 3), tx.message.instructions.len);

    // Send transaction
    const serialized = try tx.serialize();
    defer allocator.free(serialized);

    const signature = try client.sendTransaction(serialized);

    // Wait for confirmation
    var attempts: u32 = 0;
    var confirmed = false;
    while (attempts < 30) : (attempts += 1) {
        const statuses = try client.getSignatureStatuses(&.{signature});
        defer allocator.free(statuses);

        if (statuses.len > 0 and statuses[0] != null) {
            confirmed = true;
            break;
        }
        std.Thread.sleep(500 * std.time.ns_per_ms);
    }

    try std.testing.expect(confirmed);
}

test "integration: account deduplication in transaction" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const kp = Keypair.generate();
    const pubkey = kp.pubkey();

    const blockhash_result = try client.getLatestBlockhash();
    const blockhash = blockhash_result.blockhash;

    const memo_program_id = try PublicKey.fromBase58("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");

    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setFeePayer(pubkey);
    _ = builder.setRecentBlockhash(blockhash);

    // Add multiple instructions that reference the same accounts
    _ = try builder.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = "Memo 1",
    });

    _ = try builder.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = "Memo 2",
    });

    var tx = try builder.build();
    defer tx.deinit();

    // Should have only 2 unique accounts: fee_payer/signer and memo_program
    // (pubkey appears in both instructions but should be deduplicated)
    try std.testing.expectEqual(@as(usize, 2), tx.message.account_keys.len);
}

test "integration: Signer interface" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const kp = Keypair.generate();

    // Test Signer interface from Keypair
    const signer = transaction.Signer.fromKeypair(&kp);

    // Verify pubkey matches
    try std.testing.expectEqualSlices(u8, &kp.pubkey().bytes, &signer.pubkey().bytes);

    // Verify not interactive
    try std.testing.expect(!signer.isInteractive());

    // Verify signing works
    const message = "test message";
    const sig = try signer.sign(message);
    try std.testing.expect(!std.mem.eql(u8, &sig.bytes, &[_]u8{0} ** 64));
}

test "integration: Presigner" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    // Create a presigner with known values
    const pubkey = PublicKey.from([_]u8{1} ** 32);
    const signature = Signature.from([_]u8{2} ** 64);

    const presigner = transaction.Presigner.init(pubkey, signature);

    // Verify pubkey
    try std.testing.expectEqualSlices(u8, &pubkey.bytes, &presigner.pubkey().bytes);

    // Verify sign returns the pre-computed signature regardless of message
    const sig1 = presigner.sign("any message");
    const sig2 = presigner.sign("different message");

    try std.testing.expectEqualSlices(u8, &signature.bytes, &sig1.bytes);
    try std.testing.expectEqualSlices(u8, &signature.bytes, &sig2.bytes);
}

test "integration: NullSigner" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const pubkey = PublicKey.from([_]u8{1} ** 32);
    const null_signer = transaction.NullSigner.init(pubkey);

    // Verify pubkey
    try std.testing.expectEqualSlices(u8, &pubkey.bytes, &null_signer.pubkey().bytes);

    // Verify sign returns zero signature
    const sig = null_signer.sign("any message");
    try std.testing.expectEqualSlices(u8, &[_]u8{0} ** 64, &sig.bytes);
}

test "integration: signMessage utility" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;

    const kp1 = Keypair.generate();
    const kp2 = Keypair.generate();

    const message = "test message to sign";
    const signers = [_]*const Keypair{ &kp1, &kp2 };

    const signatures = try transaction.signMessage(allocator, message, &signers);
    defer allocator.free(signatures);

    // Should have 2 signatures
    try std.testing.expectEqual(@as(usize, 2), signatures.len);

    // Both should be non-zero and different
    try std.testing.expect(!std.mem.eql(u8, &signatures[0].bytes, &[_]u8{0} ** 64));
    try std.testing.expect(!std.mem.eql(u8, &signatures[1].bytes, &[_]u8{0} ** 64));
    try std.testing.expect(!std.mem.eql(u8, &signatures[0].bytes, &signatures[1].bytes));
}

test "integration: transaction with fresh blockhash" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const kp = Keypair.generate();
    const pubkey = kp.pubkey();

    // Get blockhash twice to verify they change
    const blockhash1 = try client.getLatestBlockhash();

    // Wait a bit for potential blockhash change
    std.Thread.sleep(500 * std.time.ns_per_ms);

    const blockhash2 = try client.getLatestBlockhash();

    // Build two transactions with different blockhashes
    const memo_program_id = try PublicKey.fromBase58("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");

    var builder1 = TransactionBuilder.init(allocator);
    defer builder1.deinit();

    _ = builder1.setFeePayer(pubkey);
    _ = builder1.setRecentBlockhash(blockhash1.blockhash);
    _ = try builder1.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = "tx1",
    });

    var tx1 = try builder1.buildSigned(&[_]*const Keypair{&kp});
    defer tx1.deinit();

    var builder2 = TransactionBuilder.init(allocator);
    defer builder2.deinit();

    _ = builder2.setFeePayer(pubkey);
    _ = builder2.setRecentBlockhash(blockhash2.blockhash);
    _ = try builder2.addInstruction(.{
        .program_id = memo_program_id,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = pubkey, .is_signer = true, .is_writable = false },
        },
        .data = "tx1", // Same data
    });

    var tx2 = try builder2.buildSigned(&[_]*const Keypair{&kp});
    defer tx2.deinit();

    // Serialize both
    const ser1 = try tx1.serialize();
    defer allocator.free(ser1);

    const ser2 = try tx2.serialize();
    defer allocator.free(ser2);

    // The serialized transactions should be different (different blockhash/signature)
    // unless blockhash hasn't changed
    if (!std.mem.eql(u8, &blockhash1.blockhash.bytes, &blockhash2.blockhash.bytes)) {
        try std.testing.expect(!std.mem.eql(u8, ser1, ser2));
    }
}
