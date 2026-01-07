//! Solana RPC Response Types
//!
//! Rust source: https://github.com/anza-xyz/agave/blob/master/rpc-client-api/src/response.rs
//!
//! This module provides response types for RPC methods, including generic
//! response wrappers, account information, and transaction status types.

const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;
const Hash = sdk.Hash;
const Signature = sdk.Signature;
const Commitment = @import("commitment.zig").Commitment;

/// RPC response context
///
/// Contains metadata about the response, including the slot at which
/// the data was fetched.
///
/// Rust equivalent: `RpcResponseContext` from `rpc-client-api/src/response.rs`
pub const RpcResponseContext = struct {
    /// The slot at which the data was fetched
    slot: u64,
    /// API version (optional)
    api_version: ?[]const u8 = null,
};

/// Generic RPC response wrapper
///
/// Wraps a value with context information.
///
/// Rust equivalent: `Response<T>` from `rpc-client-api/src/response.rs`
pub fn Response(comptime T: type) type {
    return struct {
        context: RpcResponseContext,
        value: T,

        const Self = @This();

        /// Get the slot at which the data was fetched
        pub fn getSlot(self: Self) u64 {
            return self.context.slot;
        }

        /// Get the value
        pub fn getValue(self: Self) T {
            return self.value;
        }
    };
}

/// Account information returned by getAccountInfo
///
/// Rust equivalent: `UiAccount` from `account-decoder`
pub const AccountInfo = struct {
    /// Number of lamports in this account
    lamports: u64,
    /// Public key of the program that owns this account
    owner: PublicKey,
    /// Account data (base64 encoded in JSON)
    data: []const u8,
    /// Whether this account's data contains a loaded program
    executable: bool,
    /// The epoch at which this account will next owe rent
    rent_epoch: u64,
    /// Size of account data
    space: ?u64 = null,

    /// Check if account has any lamports
    pub fn hasBalance(self: AccountInfo) bool {
        return self.lamports > 0;
    }

    /// Check if account is empty (no data)
    pub fn isEmpty(self: AccountInfo) bool {
        return self.data.len == 0;
    }

    /// Get data length
    pub fn dataLen(self: AccountInfo) usize {
        return self.data.len;
    }
};

/// Latest blockhash response
///
/// Rust equivalent: `RpcBlockhash` from `rpc-client-api/src/response.rs`
pub const LatestBlockhash = struct {
    /// The blockhash
    blockhash: Hash,
    /// Last valid block height for this blockhash
    last_valid_block_height: u64,

    /// Check if blockhash might still be valid given current block height
    pub fn mightBeValid(self: LatestBlockhash, current_block_height: u64) bool {
        return current_block_height <= self.last_valid_block_height;
    }

    /// Get remaining blocks until expiration
    pub fn remainingBlocks(self: LatestBlockhash, current_block_height: u64) ?u64 {
        if (current_block_height > self.last_valid_block_height) {
            return null;
        }
        return self.last_valid_block_height - current_block_height;
    }
};

/// Transaction confirmation status
pub const ConfirmationStatus = enum {
    processed,
    confirmed,
    finalized,

    pub fn toJsonString(self: ConfirmationStatus) []const u8 {
        return switch (self) {
            .processed => "processed",
            .confirmed => "confirmed",
            .finalized => "finalized",
        };
    }

    pub fn fromJsonString(s: []const u8) ?ConfirmationStatus {
        if (std.mem.eql(u8, s, "processed")) return .processed;
        if (std.mem.eql(u8, s, "confirmed")) return .confirmed;
        if (std.mem.eql(u8, s, "finalized")) return .finalized;
        return null;
    }

    /// Convert to Commitment level
    pub fn toCommitment(self: ConfirmationStatus) Commitment {
        return switch (self) {
            .processed => .processed,
            .confirmed => .confirmed,
            .finalized => .finalized,
        };
    }
};

/// Transaction status returned by getSignatureStatuses
///
/// Rust equivalent: `TransactionStatus` from `rpc-client-api/src/response.rs`
pub const TransactionStatus = struct {
    /// The slot the transaction was processed
    slot: u64,
    /// Number of blocks since signature was confirmed, null if rooted
    confirmations: ?u64,
    /// Error if transaction failed
    err: ?TransactionErrorInfo,
    /// Cluster confirmation status
    confirmation_status: ?ConfirmationStatus,

    /// Check if transaction succeeded
    pub fn succeeded(self: TransactionStatus) bool {
        return self.err == null;
    }

    /// Check if transaction failed
    pub fn failed(self: TransactionStatus) bool {
        return self.err != null;
    }

    /// Check if transaction is finalized
    pub fn isFinalized(self: TransactionStatus) bool {
        if (self.confirmation_status) |status| {
            return status == .finalized;
        }
        // If confirmations is null, transaction is rooted (finalized)
        return self.confirmations == null;
    }

    /// Check if transaction is confirmed
    pub fn isConfirmed(self: TransactionStatus) bool {
        if (self.confirmation_status) |status| {
            return status == .confirmed or status == .finalized;
        }
        return false;
    }
};

/// Simplified transaction error info
pub const TransactionErrorInfo = struct {
    /// Error type
    err_type: []const u8,
    /// Instruction index (if applicable)
    instruction_index: ?u8 = null,
};

/// Signature status (simplified version of TransactionStatus)
pub const SignatureStatus = struct {
    /// Whether the signature was found
    found: bool,
    /// The status if found
    status: ?TransactionStatus,

    /// Check if signature exists and transaction succeeded
    pub fn isSuccess(self: SignatureStatus) bool {
        if (self.status) |s| {
            return s.succeeded();
        }
        return false;
    }

    /// Check if signature exists and transaction is finalized
    pub fn isFinalized(self: SignatureStatus) bool {
        if (self.status) |s| {
            return s.isFinalized();
        }
        return false;
    }
};

/// Block production information
pub const BlockProduction = struct {
    /// Map of validator identity to (blocks produced, leader slots)
    by_identity: std.StringHashMap(BlockProductionEntry),
    /// Range of slots
    range: SlotRange,
};

/// Block production entry for a single validator
pub const BlockProductionEntry = struct {
    leader_slots: u64,
    blocks_produced: u64,
};

/// Slot range
pub const SlotRange = struct {
    first_slot: u64,
    last_slot: u64,
};

/// Version information
pub const RpcVersionInfo = struct {
    solana_core: []const u8,
    feature_set: ?u32 = null,
};

/// Node identity
pub const RpcIdentity = struct {
    identity: PublicKey,
};

/// Cluster node information
pub const RpcContactInfo = struct {
    pubkey: PublicKey,
    gossip: ?[]const u8 = null,
    tpu: ?[]const u8 = null,
    tpu_quic: ?[]const u8 = null,
    rpc: ?[]const u8 = null,
    pubsub: ?[]const u8 = null,
    version: ?[]const u8 = null,
    feature_set: ?u32 = null,
    shred_version: ?u16 = null,
};

/// Supply information
pub const RpcSupply = struct {
    total: u64,
    circulating: u64,
    non_circulating: u64,
    non_circulating_accounts: []const PublicKey,
};

/// Token balance
pub const TokenBalance = struct {
    amount: []const u8,
    decimals: u8,
    ui_amount: ?f64 = null,
    ui_amount_string: ?[]const u8 = null,
};

/// Token account information
pub const TokenAccountInfo = struct {
    pubkey: PublicKey,
    account: AccountInfo,
};

/// Simulation result
pub const SimulateTransactionResult = struct {
    err: ?TransactionErrorInfo = null,
    logs: ?[]const []const u8 = null,
    accounts: ?[]const ?AccountInfo = null,
    units_consumed: ?u64 = null,
    return_data: ?ReturnData = null,
};

/// Return data from transaction
pub const ReturnData = struct {
    program_id: PublicKey,
    data: []const u8,
};

/// Fee for message
pub const FeeForMessage = struct {
    value: ?u64,
};

/// Prioritization fee
pub const PrioritizationFee = struct {
    slot: u64,
    prioritization_fee: u64,
};

/// Block information returned by getBlock
pub const Block = struct {
    blockhash: Hash,
    previous_blockhash: Hash,
    parent_slot: u64,
    block_time: ?i64 = null,
    block_height: ?u64 = null,
    transactions: ?[]const TransactionWithMeta = null,
    rewards: ?[]const Reward = null,
};

/// Transaction with metadata
pub const TransactionWithMeta = struct {
    slot: u64,
    transaction: EncodedTransaction,
    meta: ?TransactionMeta = null,
    block_time: ?i64 = null,
};

/// Encoded transaction (can be base64 or JSON)
pub const EncodedTransaction = struct {
    /// Base64 encoded transaction data
    data: []const u8,
    /// Encoding format
    encoding: []const u8 = "base64",
};

/// Transaction metadata
pub const TransactionMeta = struct {
    err: ?TransactionErrorInfo = null,
    fee: u64,
    pre_balances: []const u64,
    post_balances: []const u64,
    inner_instructions: ?[]const InnerInstruction = null,
    log_messages: ?[]const []const u8 = null,
    pre_token_balances: ?[]const TokenBalanceInfo = null,
    post_token_balances: ?[]const TokenBalanceInfo = null,
    rewards: ?[]const Reward = null,
    compute_units_consumed: ?u64 = null,
};

/// Inner instruction
pub const InnerInstruction = struct {
    index: u8,
    instructions: []const CompiledInstruction,
};

/// Compiled instruction
pub const CompiledInstruction = struct {
    program_id_index: u8,
    accounts: []const u8,
    data: []const u8,
};

/// Token balance info in transaction meta
pub const TokenBalanceInfo = struct {
    account_index: u8,
    mint: []const u8,
    ui_token_amount: TokenBalance,
    owner: ?[]const u8 = null,
    program_id: ?[]const u8 = null,
};

/// Reward information
pub const Reward = struct {
    pubkey: []const u8,
    lamports: i64,
    post_balance: u64,
    reward_type: ?[]const u8 = null,
    commission: ?u8 = null,
};

/// Signature information for getSignaturesForAddress
pub const SignatureInfo = struct {
    signature: []const u8,
    slot: u64,
    block_time: ?i64 = null,
    err: ?TransactionErrorInfo = null,
    memo: ?[]const u8 = null,
    confirmation_status: ?ConfirmationStatus = null,
};

/// Token supply information
pub const TokenSupply = struct {
    amount: []const u8,
    decimals: u8,
    ui_amount: ?f64 = null,
    ui_amount_string: ?[]const u8 = null,
};

/// Program account with keyed account info
pub const ProgramAccount = struct {
    pubkey: PublicKey,
    account: AccountInfo,
};

/// Token account with parsed data
pub const TokenAccount = struct {
    pubkey: PublicKey,
    account: AccountInfo,
    /// Parsed token account data
    parsed: ?ParsedTokenAccount = null,
};

/// Parsed token account data
pub const ParsedTokenAccount = struct {
    mint: []const u8,
    owner: []const u8,
    token_amount: TokenBalance,
    delegate: ?[]const u8 = null,
    state: []const u8 = "initialized",
    is_native: bool = false,
    delegated_amount: ?TokenBalance = null,
    close_authority: ?[]const u8 = null,
};

// ============================================================================
// P2 Response Types
// ============================================================================

/// Block commitment information
pub const BlockCommitment = struct {
    commitment: ?[]const u64 = null,
    total_stake: u64,
};

/// Block production information
pub const BlockProductionInfo = struct {
    by_identity: []const IdentityBlockProduction,
    range: SlotRange,
};

/// Identity block production entry
pub const IdentityBlockProduction = struct {
    identity: []const u8,
    leader_slots: u64,
    blocks_produced: u64,
};

/// Cluster node information
pub const ClusterNode = struct {
    pubkey: []const u8,
    gossip: ?[]const u8 = null,
    tpu: ?[]const u8 = null,
    tpu_quic: ?[]const u8 = null,
    rpc: ?[]const u8 = null,
    pubsub: ?[]const u8 = null,
    version: ?[]const u8 = null,
    feature_set: ?u32 = null,
    shred_version: ?u16 = null,
};

/// Epoch schedule information (from RPC, different from sysvar)
pub const RpcEpochSchedule = struct {
    slots_per_epoch: u64,
    leader_schedule_slot_offset: u64,
    warmup: bool,
    first_normal_epoch: u64,
    first_normal_slot: u64,
};

/// Highest snapshot slot information
pub const HighestSnapshotSlot = struct {
    full: u64,
    incremental: ?u64 = null,
};

/// Identity information
pub const Identity = struct {
    identity: []const u8,
};

/// Inflation governor information
pub const InflationGovernor = struct {
    initial: f64,
    terminal: f64,
    taper: f64,
    foundation: f64,
    foundation_term: f64,
};

/// Inflation rate information
pub const InflationRate = struct {
    total: f64,
    validator: f64,
    foundation: f64,
    epoch: u64,
};

/// Inflation reward information
pub const InflationReward = struct {
    epoch: u64,
    effective_slot: u64,
    amount: u64,
    post_balance: u64,
    commission: ?u8 = null,
};

/// Supply information
pub const Supply = struct {
    total: u64,
    circulating: u64,
    non_circulating: u64,
    non_circulating_accounts: []const []const u8,
};

/// Large account information
pub const LargeAccount = struct {
    lamports: u64,
    address: []const u8,
};

/// Vote account information
pub const VoteAccountInfo = struct {
    vote_pubkey: []const u8,
    node_pubkey: []const u8,
    activated_stake: u64,
    epoch_vote_account: bool,
    commission: u8,
    last_vote: u64,
    epoch_credits: []const EpochCredit,
    root_slot: ?u64 = null,
};

/// Epoch credit entry
pub const EpochCredit = struct {
    epoch: u64,
    credits: u64,
    previous_credits: u64,
};

/// Vote accounts response
pub const VoteAccounts = struct {
    current: []const VoteAccountInfo,
    delinquent: []const VoteAccountInfo,
};

/// Leader schedule entry
pub const LeaderScheduleEntry = struct {
    pubkey: []const u8,
    slots: []const u64,
};

/// Performance sample
pub const PerformanceSample = struct {
    slot: u64,
    num_transactions: u64,
    num_slots: u64,
    sample_period_secs: u16,
    num_non_vote_transactions: ?u64 = null,
};

/// Token largest account
pub const TokenLargestAccount = struct {
    address: []const u8,
    amount: []const u8,
    decimals: u8,
    ui_amount: ?f64 = null,
    ui_amount_string: ?[]const u8 = null,
};

/// Stake minimum delegation
pub const StakeMinimumDelegation = struct {
    value: u64,
};

// ============================================================================
// Tests
// ============================================================================

test "types: Response wrapper" {
    const BalanceResponse = Response(u64);
    const response = BalanceResponse{
        .context = .{ .slot = 12345 },
        .value = 1000000000,
    };

    try std.testing.expectEqual(@as(u64, 12345), response.getSlot());
    try std.testing.expectEqual(@as(u64, 1000000000), response.getValue());
}

test "types: LatestBlockhash mightBeValid" {
    const blockhash = LatestBlockhash{
        .blockhash = Hash.default(),
        .last_valid_block_height = 1000,
    };

    try std.testing.expect(blockhash.mightBeValid(500));
    try std.testing.expect(blockhash.mightBeValid(1000));
    try std.testing.expect(!blockhash.mightBeValid(1001));
}

test "types: LatestBlockhash remainingBlocks" {
    const blockhash = LatestBlockhash{
        .blockhash = Hash.default(),
        .last_valid_block_height = 1000,
    };

    try std.testing.expectEqual(@as(?u64, 500), blockhash.remainingBlocks(500));
    try std.testing.expectEqual(@as(?u64, 0), blockhash.remainingBlocks(1000));
    try std.testing.expect(blockhash.remainingBlocks(1001) == null);
}

test "types: TransactionStatus succeeded" {
    const success_status = TransactionStatus{
        .slot = 100,
        .confirmations = 10,
        .err = null,
        .confirmation_status = .confirmed,
    };

    try std.testing.expect(success_status.succeeded());
    try std.testing.expect(!success_status.failed());

    const failed_status = TransactionStatus{
        .slot = 100,
        .confirmations = 10,
        .err = .{ .err_type = "InstructionError" },
        .confirmation_status = .confirmed,
    };

    try std.testing.expect(!failed_status.succeeded());
    try std.testing.expect(failed_status.failed());
}

test "types: TransactionStatus finalization" {
    const finalized = TransactionStatus{
        .slot = 100,
        .confirmations = null, // null = rooted/finalized
        .err = null,
        .confirmation_status = .finalized,
    };

    try std.testing.expect(finalized.isFinalized());
    try std.testing.expect(finalized.isConfirmed());

    const confirmed = TransactionStatus{
        .slot = 100,
        .confirmations = 10,
        .err = null,
        .confirmation_status = .confirmed,
    };

    try std.testing.expect(!confirmed.isFinalized());
    try std.testing.expect(confirmed.isConfirmed());
}

test "types: ConfirmationStatus conversion" {
    try std.testing.expectEqualStrings("processed", ConfirmationStatus.processed.toJsonString());
    try std.testing.expectEqual(ConfirmationStatus.confirmed, ConfirmationStatus.fromJsonString("confirmed").?);
    try std.testing.expectEqual(Commitment.finalized, ConfirmationStatus.finalized.toCommitment());
}

test "types: AccountInfo methods" {
    const account = AccountInfo{
        .lamports = 1000000000,
        .owner = PublicKey.default(),
        .data = "test data",
        .executable = false,
        .rent_epoch = 0,
    };

    try std.testing.expect(account.hasBalance());
    try std.testing.expect(!account.isEmpty());
    try std.testing.expectEqual(@as(usize, 9), account.dataLen());

    const empty_account = AccountInfo{
        .lamports = 0,
        .owner = PublicKey.default(),
        .data = "",
        .executable = false,
        .rent_epoch = 0,
    };

    try std.testing.expect(!empty_account.hasBalance());
    try std.testing.expect(empty_account.isEmpty());
}

test "types: SignatureStatus" {
    const found_success = SignatureStatus{
        .found = true,
        .status = .{
            .slot = 100,
            .confirmations = null,
            .err = null,
            .confirmation_status = .finalized,
        },
    };

    try std.testing.expect(found_success.isSuccess());
    try std.testing.expect(found_success.isFinalized());

    const not_found = SignatureStatus{
        .found = false,
        .status = null,
    };

    try std.testing.expect(!not_found.isSuccess());
    try std.testing.expect(!not_found.isFinalized());
}
