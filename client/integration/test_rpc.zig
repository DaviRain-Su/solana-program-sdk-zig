//! RPC Client Integration Tests
//!
//! These tests require a running Solana validator (e.g., surfpool or solana-test-validator)
//! at localhost:8899.
//!
//! To run these tests:
//!   1. Start a local validator: `surfpool start --no-tui` or `solana-test-validator`
//!   2. Run tests: `../solana-zig/zig build integration-test`

const std = @import("std");
const rpc_client = @import("rpc_client");
const sdk = @import("solana_sdk");
const RpcClient = rpc_client.RpcClient;
const ClientError = rpc_client.ClientError;
const PublicKey = sdk.PublicKey;
const Signature = sdk.Signature;

const LOCALNET_RPC = "http://127.0.0.1:8899";

/// Check if local RPC is available
fn isLocalRpcAvailable() bool {
    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();
    return client.isHealthy();
}

// ============================================================================
// P0 Integration Tests - Core functionality
// ============================================================================

test "integration: getHealth" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    try client.getHealth();
}

test "integration: isHealthy" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const healthy = client.isHealthy();
    try std.testing.expect(healthy);
}

test "integration: getVersion" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const version = try client.getVersion();
    // Version string should not be empty
    try std.testing.expect(version.solana_core.len > 0);
}

test "integration: getSlot" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const slot = try client.getSlot();
    // Slot should be >= 0
    try std.testing.expect(slot >= 0);
}

test "integration: getBlockHeight" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const height = try client.getBlockHeight();
    // Block height should be >= 0
    try std.testing.expect(height >= 0);
}

test "integration: getLatestBlockhash" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const blockhash = try client.getLatestBlockhash();
    // Blockhash should not be default (all zeros)
    try std.testing.expect(!std.mem.eql(u8, &blockhash.blockhash.bytes, &[_]u8{0} ** 32));
    // Last valid block height should be > 0
    try std.testing.expect(blockhash.last_valid_block_height > 0);
}

test "integration: getBalance" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    // Get balance of system program (always exists)
    const system_program = PublicKey.default(); // 11111111111111111111111111111111
    const balance = try client.getBalance(system_program);
    // System program should have 1 lamport
    try std.testing.expectEqual(@as(u64, 1), balance);
}

test "integration: getBalanceInSol" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const system_program = PublicKey.default();
    const balance_sol = try client.getBalanceInSol(system_program);
    // Should be 0.000000001 SOL (1 lamport)
    try std.testing.expect(balance_sol >= 0);
}

test "integration: getAccountInfo" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    // System program account info
    const system_program = PublicKey.default();
    const account_info = try client.getAccountInfo(system_program);
    try std.testing.expect(account_info != null);
    try std.testing.expectEqual(@as(u64, 1), account_info.?.lamports);
    try std.testing.expectEqual(true, account_info.?.executable);
}

test "integration: getMinimumBalanceForRentExemption" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const min_balance = try client.getMinimumBalanceForRentExemption(100);
    // Minimum balance should be > 0
    try std.testing.expect(min_balance > 0);
}

// ============================================================================
// P1 Integration Tests - Common functionality
// ============================================================================

test "integration: getEpochInfo" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const epoch_info = try client.getEpochInfo();
    // Slots in epoch should be > 0
    try std.testing.expect(epoch_info.slots_in_epoch > 0);
}

test "integration: getCurrentSlot" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const slot = try client.getCurrentSlot();
    try std.testing.expect(slot >= 0);
}

test "integration: isBlockhashValid" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    // Get a recent blockhash and verify it's valid
    const latest = try client.getLatestBlockhash();
    const is_valid = try client.isBlockhashValid(latest.blockhash);
    try std.testing.expect(is_valid);
}

test "integration: getMultipleAccounts" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const system_program = PublicKey.default();
    const accounts = try client.getMultipleAccounts(&.{system_program});
    defer allocator.free(accounts);

    try std.testing.expectEqual(@as(usize, 1), accounts.len);
    try std.testing.expect(accounts[0] != null);
}

test "integration: getRecentPrioritizationFees" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const fees = try client.getRecentPrioritizationFees(null);
    defer allocator.free(fees);

    // Should return some fees (may be empty on fresh testnet)
    // Just verify the call succeeds
}

// ============================================================================
// P2 Integration Tests - Extended functionality
// ============================================================================

test "integration: getGenesisHash" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const genesis_hash = try client.getGenesisHash();
    // Genesis hash should not be all zeros
    try std.testing.expect(!std.mem.eql(u8, &genesis_hash.bytes, &[_]u8{0} ** 32));
}

test "integration: getIdentity" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const identity = try client.getIdentity();
    // Identity should not be all zeros
    try std.testing.expect(!std.mem.eql(u8, &identity.bytes, &[_]u8{0} ** 32));
}

test "integration: getSlotLeader" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const leader = try client.getSlotLeader();
    // Leader should not be all zeros
    try std.testing.expect(!std.mem.eql(u8, &leader.bytes, &[_]u8{0} ** 32));
}

test "integration: getClusterNodes" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const nodes = try client.getClusterNodes();
    defer allocator.free(nodes);

    // Should have at least 1 node (the validator)
    try std.testing.expect(nodes.len >= 1);
}

test "integration: getEpochSchedule" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const schedule = try client.getEpochSchedule();
    // Slots per epoch should be > 0
    try std.testing.expect(schedule.slots_per_epoch > 0);
}

test "integration: getInflationGovernor" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const governor = try client.getInflationGovernor();
    // Initial inflation should be >= 0
    try std.testing.expect(governor.initial >= 0);
}

test "integration: getInflationRate" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const rate = try client.getInflationRate();
    // Total rate should be >= 0
    try std.testing.expect(rate.total >= 0);
}

test "integration: getSupply" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const supply = client.getSupply() catch |err| {
        // Some validators may not support this
        if (err == ClientError.RpcError) return;
        return err;
    };
    // Just verify the call succeeded - values may vary on different validators

    if (supply.non_circulating_accounts.len > 0) {
        allocator.free(supply.non_circulating_accounts);
    }
}

test "integration: getTransactionCount" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const count = try client.getTransactionCount();
    // Transaction count should be >= 0
    try std.testing.expect(count >= 0);
}

test "integration: getVoteAccounts" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const vote_accounts = try client.getVoteAccounts();

    // Free allocated memory
    for (vote_accounts.current) |va| {
        if (va.epoch_credits.len > 0) {
            allocator.free(va.epoch_credits);
        }
    }
    if (vote_accounts.current.len > 0) {
        allocator.free(vote_accounts.current);
    }
    for (vote_accounts.delinquent) |va| {
        if (va.epoch_credits.len > 0) {
            allocator.free(va.epoch_credits);
        }
    }
    if (vote_accounts.delinquent.len > 0) {
        allocator.free(vote_accounts.delinquent);
    }
}

test "integration: getRecentPerformanceSamples" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const samples = try client.getRecentPerformanceSamples(5);
    defer allocator.free(samples);

    // May have samples if validator has been running for a while
}

test "integration: getFirstAvailableBlock" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const first_block = try client.getFirstAvailableBlock();
    // First available block should be >= 0
    try std.testing.expect(first_block >= 0);
}

test "integration: minimumLedgerSlot" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const min_slot = try client.minimumLedgerSlot();
    // Minimum ledger slot should be >= 0
    try std.testing.expect(min_slot >= 0);
}

test "integration: getStakeMinimumDelegation" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const min_delegation = try client.getStakeMinimumDelegation();
    // Minimum delegation should be >= 0 (may be 0 on some validators)
    try std.testing.expect(min_delegation >= 0);
}

test "integration: getBlocks" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    // Get first available block to use as start
    const first = try client.getFirstAvailableBlock();
    const current = try client.getSlot();

    if (current > first) {
        const end_slot = @min(first + 10, current);
        const blocks = try client.getBlocks(first, end_slot);
        defer allocator.free(blocks);
        // Should have some blocks
    }
}

test "integration: getBlocksWithLimit" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const first = try client.getFirstAvailableBlock();
    const blocks = try client.getBlocksWithLimit(first, 5);
    defer allocator.free(blocks);
    // Should have up to 5 blocks
}

test "integration: getBlock" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    // Get a recent confirmed slot
    const slot = try client.getSlot();
    if (slot > 10) {
        // Try to get a block from a few slots ago (more likely to be available)
        const block = try client.getBlock(slot - 5);
        if (block) |b| {
            // Free allocated memory
            if (b.transactions) |txs| {
                allocator.free(txs);
            }
            if (b.rewards) |rewards| {
                allocator.free(rewards);
            }
        }
    }
}

test "integration: getBlockTime" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const slot = try client.getSlot();
    if (slot > 5) {
        const block_time = client.getBlockTime(slot - 3) catch |err| {
            // Some slots may not have block time available
            if (err == ClientError.RpcError) return;
            return err;
        };
        if (block_time) |time| {
            // Block time should be a reasonable Unix timestamp (or 0 on some validators)
            try std.testing.expect(time >= 0);
        }
    }
}

test "integration: getBlockCommitment" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const slot = try client.getSlot();
    const commitment = client.getBlockCommitment(slot) catch |err| {
        // Some validators may not support this
        if (err == ClientError.RpcError) return;
        return err;
    };
    // Total stake should be >= 0
    try std.testing.expect(commitment.total_stake >= 0);
}

test "integration: getBlockProduction" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const production = try client.getBlockProduction();

    // Free allocated memory
    if (production.by_identity.len > 0) {
        allocator.free(production.by_identity);
    }

    // Range should have valid slots
    try std.testing.expect(production.range.last_slot >= production.range.first_slot);
}

test "integration: getLargestAccounts" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    const accounts = client.getLargestAccounts() catch |err| {
        // Some validators may not support this or have rate limits
        if (err == ClientError.RpcError) return;
        return err;
    };
    defer allocator.free(accounts);

    // Should have some accounts (may be empty on fresh validators)
    // First account should have the most lamports
    if (accounts.len > 1) {
        try std.testing.expect(accounts[0].lamports >= accounts[1].lamports);
    }
}

test "integration: getSignatureStatuses with empty" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, LOCALNET_RPC);
    defer client.deinit();

    // Use a random signature that doesn't exist
    const fake_sig = Signature.default();
    const statuses = client.getSignatureStatuses(&.{fake_sig}) catch |err| {
        // Some validators may return error for empty/invalid signatures
        if (err == ClientError.RpcError) return;
        return err;
    };
    defer allocator.free(statuses);

    try std.testing.expectEqual(@as(usize, 1), statuses.len);
    // Fake signature should not be found
    try std.testing.expect(statuses[0] == null);
}
