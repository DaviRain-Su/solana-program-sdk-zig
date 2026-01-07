//! Solana RPC Client
//!
//! Rust source: https://github.com/anza-xyz/agave/blob/master/rpc-client/src/rpc_client.rs
//!
//! This module provides the main RPC client for interacting with Solana nodes.
//! It implements all 52 HTTP RPC methods from the Solana JSON-RPC API.

const std = @import("std");
const Allocator = std.mem.Allocator;

const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;
const Hash = sdk.Hash;
const Signature = sdk.Signature;
const Keypair = sdk.Keypair;

pub const ClientError = @import("error.zig").ClientError;
const RpcError = @import("error.zig").RpcError;
const Commitment = @import("commitment.zig").Commitment;
const CommitmentConfig = @import("commitment.zig").CommitmentConfig;
const types = @import("types.zig");
const Response = types.Response;
const RpcResponseContext = types.RpcResponseContext;
const AccountInfo = types.AccountInfo;
const LatestBlockhash = types.LatestBlockhash;
const TransactionStatus = types.TransactionStatus;
const SignatureStatus = types.SignatureStatus;
const RpcVersionInfo = types.RpcVersionInfo;
const SimulateTransactionResult = types.SimulateTransactionResult;
const TokenBalance = types.TokenBalance;
const PrioritizationFee = types.PrioritizationFee;
const Block = types.Block;
const TransactionWithMeta = types.TransactionWithMeta;
const SignatureInfo = types.SignatureInfo;
const TokenSupply = types.TokenSupply;
const ProgramAccount = types.ProgramAccount;
const TokenAccount = types.TokenAccount;
const TransactionMeta = types.TransactionMeta;
const EncodedTransaction = types.EncodedTransaction;
const BlockCommitment = types.BlockCommitment;
const BlockProductionInfo = types.BlockProductionInfo;
const ClusterNode = types.ClusterNode;
const RpcEpochSchedule = types.RpcEpochSchedule;
const HighestSnapshotSlot = types.HighestSnapshotSlot;
const Identity = types.Identity;
const InflationGovernor = types.InflationGovernor;
const InflationRate = types.InflationRate;
const InflationReward = types.InflationReward;
const Supply = types.Supply;
const LargeAccount = types.LargeAccount;
const VoteAccounts = types.VoteAccounts;
const PerformanceSample = types.PerformanceSample;
const TokenLargestAccount = types.TokenLargestAccount;
const Reward = types.Reward;
const VoteAccountInfo = types.VoteAccountInfo;
const EpochCredit = types.EpochCredit;
const IdentityBlockProduction = types.IdentityBlockProduction;

const json_rpc = @import("json_rpc.zig");
const JsonRpcClient = json_rpc.JsonRpcClient;
const jsonString = json_rpc.jsonString;
const jsonInt = json_rpc.jsonInt;
const jsonBool = json_rpc.jsonBool;
const jsonArray = json_rpc.jsonArray;
const jsonObject = json_rpc.jsonObject;

/// Solana RPC Client
///
/// Provides methods to interact with Solana RPC nodes.
///
/// Rust equivalent: `RpcClient` from `rpc-client/src/rpc_client.rs`
pub const RpcClient = struct {
    allocator: Allocator,
    json_rpc: JsonRpcClient,
    commitment: CommitmentConfig,

    /// Initialize a new RPC client with default commitment (finalized)
    pub fn init(allocator: Allocator, endpoint: []const u8) RpcClient {
        return .{
            .allocator = allocator,
            .json_rpc = JsonRpcClient.init(allocator, endpoint),
            .commitment = CommitmentConfig.default,
        };
    }

    /// Initialize with custom commitment
    pub fn initWithCommitment(allocator: Allocator, endpoint: []const u8, commitment: CommitmentConfig) RpcClient {
        return .{
            .allocator = allocator,
            .json_rpc = JsonRpcClient.init(allocator, endpoint),
            .commitment = commitment,
        };
    }

    /// Initialize with custom timeout
    pub fn initWithTimeout(allocator: Allocator, endpoint: []const u8, timeout_ms: u32) RpcClient {
        return .{
            .allocator = allocator,
            .json_rpc = JsonRpcClient.initWithTimeout(allocator, endpoint, timeout_ms),
            .commitment = CommitmentConfig.default,
        };
    }

    /// Deinitialize the client
    pub fn deinit(self: *RpcClient) void {
        _ = self;
        // No resources to free currently
    }

    // ========================================================================
    // P0 Core Methods (6 methods)
    // ========================================================================

    /// Get the balance of an account
    ///
    /// RPC Method: `getBalance`
    pub fn getBalance(self: *RpcClient, pubkey: PublicKey) !u64 {
        const response = try self.getBalanceWithCommitment(pubkey, self.commitment.commitment);
        return response.value;
    }

    /// Get the balance with specific commitment
    pub fn getBalanceWithCommitment(self: *RpcClient, pubkey: PublicKey, commitment: Commitment) !Response(u64) {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        // Add pubkey
        var pubkey_buf: [PublicKey.max_base58_len]u8 = undefined;
        const pubkey_str = pubkey.toBase58(&pubkey_buf);
        params_arr.appendAssumeCapacity(jsonString(pubkey_str));

        // Add config object
        var config = jsonObject(self.allocator);
        defer config.deinit();
        try config.put("commitment", jsonString(commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = config });

        const result = try self.json_rpc.call(self.allocator, "getBalance", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseBalanceResponse(result);
    }

    /// Get account information
    ///
    /// RPC Method: `getAccountInfo`
    pub fn getAccountInfo(self: *RpcClient, pubkey: PublicKey) !?AccountInfo {
        const response = try self.getAccountInfoWithCommitment(pubkey, self.commitment.commitment);
        return response.value;
    }

    /// Get account information with specific commitment
    pub fn getAccountInfoWithCommitment(self: *RpcClient, pubkey: PublicKey, commitment: Commitment) !Response(?AccountInfo) {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        var pubkey_buf: [PublicKey.max_base58_len]u8 = undefined;
        const pubkey_str = pubkey.toBase58(&pubkey_buf);
        params_arr.appendAssumeCapacity(jsonString(pubkey_str));

        var config = jsonObject(self.allocator);
        defer config.deinit();
        try config.put("commitment", jsonString(commitment.toJsonString()));
        try config.put("encoding", jsonString("base64"));
        params_arr.appendAssumeCapacity(.{ .object = config });

        const result = try self.json_rpc.call(self.allocator, "getAccountInfo", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseAccountInfoResponse(result);
    }

    /// Get the latest blockhash
    ///
    /// RPC Method: `getLatestBlockhash`
    pub fn getLatestBlockhash(self: *RpcClient) !LatestBlockhash {
        const response = try self.getLatestBlockhashWithCommitment(self.commitment.commitment);
        return response.value;
    }

    /// Get the latest blockhash with specific commitment
    pub fn getLatestBlockhashWithCommitment(self: *RpcClient, commitment: Commitment) !Response(LatestBlockhash) {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var config = jsonObject(self.allocator);
        defer config.deinit();
        try config.put("commitment", jsonString(commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = config });

        const result = try self.json_rpc.call(self.allocator, "getLatestBlockhash", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseLatestBlockhashResponse(self.allocator, result);
    }

    /// Get minimum balance for rent exemption
    ///
    /// RPC Method: `getMinimumBalanceForRentExemption`
    pub fn getMinimumBalanceForRentExemption(self: *RpcClient, data_len: usize) !u64 {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        params_arr.appendAssumeCapacity(jsonInt(@intCast(data_len)));

        const result = try self.json_rpc.call(self.allocator, "getMinimumBalanceForRentExemption", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return @intCast(result.integer);
    }

    /// Send a signed transaction
    ///
    /// RPC Method: `sendTransaction`
    pub fn sendTransaction(self: *RpcClient, transaction: []const u8) !Signature {
        return self.sendTransactionWithConfig(transaction, .{});
    }

    /// Send transaction configuration
    pub const SendTransactionConfig = struct {
        skip_preflight: bool = false,
        preflight_commitment: ?Commitment = null,
        max_retries: ?u32 = null,
        min_context_slot: ?u64 = null,
    };

    /// Send transaction with configuration
    pub fn sendTransactionWithConfig(self: *RpcClient, transaction: []const u8, config: SendTransactionConfig) !Signature {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        // Base64 encode the transaction
        const encoded = try base64Encode(self.allocator, transaction);
        defer self.allocator.free(encoded);
        params_arr.appendAssumeCapacity(jsonString(encoded));

        // Add config
        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("encoding", jsonString("base64"));
        if (config.skip_preflight) {
            try cfg.put("skipPreflight", jsonBool(true));
        }
        if (config.preflight_commitment) |commitment| {
            try cfg.put("preflightCommitment", jsonString(commitment.toJsonString()));
        }
        if (config.max_retries) |retries| {
            try cfg.put("maxRetries", jsonInt(@intCast(retries)));
        }
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "sendTransaction", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        // Parse signature from result
        return Signature.fromBase58(result.string) catch ClientError.InvalidResponse;
    }

    /// Get signature statuses
    ///
    /// RPC Method: `getSignatureStatuses`
    pub fn getSignatureStatuses(self: *RpcClient, signatures: []const Signature) ![]?TransactionStatus {
        return self.getSignatureStatusesWithConfig(signatures, false);
    }

    /// Get signature statuses with history search
    pub fn getSignatureStatusesWithHistory(self: *RpcClient, signatures: []const Signature) ![]?TransactionStatus {
        return self.getSignatureStatusesWithConfig(signatures, true);
    }

    fn getSignatureStatusesWithConfig(self: *RpcClient, signatures: []const Signature, search_history: bool) ![]?TransactionStatus {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        // Build signatures array
        var sig_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, signatures.len);
        defer sig_arr.deinit();
        for (signatures) |sig| {
            var sig_buf: [sdk.signature.MAX_BASE58_LEN]u8 = undefined;
            const sig_str = sig.toBase58(&sig_buf);
            sig_arr.appendAssumeCapacity(jsonString(sig_str));
        }
        params_arr.appendAssumeCapacity(.{ .array = sig_arr });

        // Add config
        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        if (search_history) {
            try cfg.put("searchTransactionHistory", jsonBool(true));
        }
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getSignatureStatuses", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseSignatureStatusesResponse(self.allocator, result);
    }

    // ========================================================================
    // P1 Common Methods (18 methods)
    // ========================================================================

    /// Get multiple accounts
    ///
    /// RPC Method: `getMultipleAccounts`
    pub fn getMultipleAccounts(self: *RpcClient, pubkeys: []const PublicKey) ![]?AccountInfo {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        // Build pubkeys array
        var pk_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, pubkeys.len);
        defer pk_arr.deinit();
        for (pubkeys) |pk| {
            var pk_buf: [PublicKey.max_base58_len]u8 = undefined;
            const pk_str = pk.toBase58(&pk_buf);
            pk_arr.appendAssumeCapacity(jsonString(pk_str));
        }
        params_arr.appendAssumeCapacity(.{ .array = pk_arr });

        // Add config
        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("encoding", jsonString("base64"));
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getMultipleAccounts", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseMultipleAccountsResponse(self.allocator, result);
    }

    /// Simulate a transaction
    ///
    /// RPC Method: `simulateTransaction`
    pub fn simulateTransaction(self: *RpcClient, transaction: []const u8) !SimulateTransactionResult {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        const encoded = try base64Encode(self.allocator, transaction);
        defer self.allocator.free(encoded);
        params_arr.appendAssumeCapacity(jsonString(encoded));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("encoding", jsonString("base64"));
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "simulateTransaction", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseSimulateTransactionResponse(result);
    }

    /// Request airdrop (devnet/testnet only)
    ///
    /// RPC Method: `requestAirdrop`
    pub fn requestAirdrop(self: *RpcClient, pubkey: PublicKey, lamports: u64) !Signature {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        var pubkey_buf: [PublicKey.max_base58_len]u8 = undefined;
        const pubkey_str = pubkey.toBase58(&pubkey_buf);
        params_arr.appendAssumeCapacity(jsonString(pubkey_str));
        params_arr.appendAssumeCapacity(jsonInt(@intCast(lamports)));

        const result = try self.json_rpc.call(self.allocator, "requestAirdrop", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return Signature.fromBase58(result.string) catch ClientError.InvalidResponse;
    }

    /// Get current slot
    ///
    /// RPC Method: `getSlot`
    pub fn getSlot(self: *RpcClient) !u64 {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getSlot", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return @intCast(result.integer);
    }

    /// Get block height
    ///
    /// RPC Method: `getBlockHeight`
    pub fn getBlockHeight(self: *RpcClient) !u64 {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getBlockHeight", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return @intCast(result.integer);
    }

    /// Get epoch info
    ///
    /// RPC Method: `getEpochInfo`
    pub fn getEpochInfo(self: *RpcClient) !sdk.EpochInfo {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getEpochInfo", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseEpochInfoResponse(result);
    }

    /// Get version info
    ///
    /// RPC Method: `getVersion`
    pub fn getVersion(self: *RpcClient) !RpcVersionInfo {
        const result = try self.json_rpc.call(self.allocator, "getVersion", null);
        defer freeJsonValue(self.allocator, result);

        const obj = result.object;
        return .{
            .solana_core = obj.get("solana-core").?.string,
            .feature_set = if (obj.get("feature-set")) |fs| @intCast(fs.integer) else null,
        };
    }

    /// Get health status
    ///
    /// RPC Method: `getHealth`
    pub fn getHealth(self: *RpcClient) !void {
        const result = try self.json_rpc.call(self.allocator, "getHealth", null);
        defer freeJsonValue(self.allocator, result);

        // Returns "ok" if healthy, otherwise throws error
        if (result != .string or !std.mem.eql(u8, result.string, "ok")) {
            return ClientError.RpcError;
        }
    }

    /// Check if blockhash is valid
    ///
    /// RPC Method: `isBlockhashValid`
    pub fn isBlockhashValid(self: *RpcClient, blockhash: Hash) !bool {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        var hash_buf: [sdk.hash.MAX_BASE58_LEN]u8 = undefined;
        const hash_str = blockhash.toBase58(&hash_buf);
        params_arr.appendAssumeCapacity(jsonString(hash_str));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "isBlockhashValid", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        // Result is { context: {...}, value: bool }
        const obj = result.object;
        return obj.get("value").?.bool;
    }

    /// Get fee for message
    ///
    /// RPC Method: `getFeeForMessage`
    pub fn getFeeForMessage(self: *RpcClient, message: []const u8) !?u64 {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        const encoded = try base64Encode(self.allocator, message);
        defer self.allocator.free(encoded);
        params_arr.appendAssumeCapacity(jsonString(encoded));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getFeeForMessage", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        const obj = result.object;
        const value = obj.get("value") orelse return null;
        if (value == .null) return null;
        return @intCast(value.integer);
    }

    /// Get recent prioritization fees
    ///
    /// RPC Method: `getRecentPrioritizationFees`
    pub fn getRecentPrioritizationFees(self: *RpcClient, accounts: ?[]const PublicKey) ![]PrioritizationFee {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        if (accounts) |accts| {
            var pk_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, accts.len);
            defer pk_arr.deinit();
            for (accts) |pk| {
                var pk_buf: [PublicKey.max_base58_len]u8 = undefined;
                const pk_str = pk.toBase58(&pk_buf);
                pk_arr.appendAssumeCapacity(jsonString(pk_str));
            }
            params_arr.appendAssumeCapacity(.{ .array = pk_arr });
        }

        const result = try self.json_rpc.call(
            self.allocator,
            "getRecentPrioritizationFees",
            if (params_arr.items.len > 0) .{ .array = params_arr } else null,
        );
        defer freeJsonValue(self.allocator, result);

        return parsePrioritizationFeesResponse(self.allocator, result);
    }

    /// Get token account balance
    ///
    /// RPC Method: `getTokenAccountBalance`
    pub fn getTokenAccountBalance(self: *RpcClient, pubkey: PublicKey) !TokenBalance {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        var pubkey_buf: [PublicKey.max_base58_len]u8 = undefined;
        const pubkey_str = pubkey.toBase58(&pubkey_buf);
        params_arr.appendAssumeCapacity(jsonString(pubkey_str));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getTokenAccountBalance", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseTokenBalanceResponse(result);
    }

    /// Get program accounts
    ///
    /// RPC Method: `getProgramAccounts`
    pub fn getProgramAccounts(self: *RpcClient, program_id: PublicKey) ![]ProgramAccount {
        return self.getProgramAccountsWithConfig(program_id, .{});
    }

    /// Get program accounts configuration
    pub const GetProgramAccountsConfig = struct {
        data_slice: ?DataSlice = null,
        filters: ?[]const AccountFilter = null,
        with_context: bool = false,
    };

    /// Data slice for account queries
    pub const DataSlice = struct {
        offset: usize,
        length: usize,
    };

    /// Account filter for program account queries
    pub const AccountFilter = union(enum) {
        memcmp: MemcmpFilter,
        data_size: u64,
    };

    /// Memcmp filter
    pub const MemcmpFilter = struct {
        offset: usize,
        bytes: []const u8,
    };

    /// Get program accounts with configuration
    pub fn getProgramAccountsWithConfig(self: *RpcClient, program_id: PublicKey, config: GetProgramAccountsConfig) ![]ProgramAccount {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        var program_buf: [PublicKey.max_base58_len]u8 = undefined;
        const program_str = program_id.toBase58(&program_buf);
        params_arr.appendAssumeCapacity(jsonString(program_str));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("encoding", jsonString("base64"));
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));

        if (config.data_slice) |slice| {
            var slice_obj = jsonObject(self.allocator);
            try slice_obj.put("offset", jsonInt(@intCast(slice.offset)));
            try slice_obj.put("length", jsonInt(@intCast(slice.length)));
            try cfg.put("dataSlice", .{ .object = slice_obj });
        }

        if (config.filters) |filters| {
            var filters_arr = std.json.Array.init(self.allocator);
            for (filters) |filter| {
                var filter_obj = jsonObject(self.allocator);
                switch (filter) {
                    .memcmp => |m| {
                        var memcmp_obj = jsonObject(self.allocator);
                        try memcmp_obj.put("offset", jsonInt(@intCast(m.offset)));
                        try memcmp_obj.put("bytes", jsonString(m.bytes));
                        try filter_obj.put("memcmp", .{ .object = memcmp_obj });
                    },
                    .data_size => |size| {
                        try filter_obj.put("dataSize", jsonInt(@intCast(size)));
                    },
                }
                filters_arr.appendAssumeCapacity(.{ .object = filter_obj });
            }
            try cfg.put("filters", .{ .array = filters_arr });
        }

        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getProgramAccounts", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseProgramAccountsResponse(self.allocator, result);
    }

    /// Get transaction details
    ///
    /// RPC Method: `getTransaction`
    pub fn getTransaction(self: *RpcClient, signature: Signature) !?TransactionWithMeta {
        return self.getTransactionWithConfig(signature, .{});
    }

    /// Get transaction configuration
    pub const GetTransactionConfig = struct {
        max_supported_transaction_version: ?u8 = 0,
    };

    /// Get transaction with configuration
    pub fn getTransactionWithConfig(self: *RpcClient, signature: Signature, config: GetTransactionConfig) !?TransactionWithMeta {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        var sig_buf: [sdk.signature.MAX_BASE58_LEN]u8 = undefined;
        const sig_str = signature.toBase58(&sig_buf);
        params_arr.appendAssumeCapacity(jsonString(sig_str));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("encoding", jsonString("base64"));
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        if (config.max_supported_transaction_version) |v| {
            try cfg.put("maxSupportedTransactionVersion", jsonInt(@intCast(v)));
        }
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getTransaction", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseTransactionResponse(self.allocator, result);
    }

    /// Get token accounts by owner
    ///
    /// RPC Method: `getTokenAccountsByOwner`
    pub fn getTokenAccountsByOwner(self: *RpcClient, owner: PublicKey, filter: TokenAccountFilter) ![]TokenAccount {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 3);
        defer params_arr.deinit();

        var owner_buf: [PublicKey.max_base58_len]u8 = undefined;
        const owner_str = owner.toBase58(&owner_buf);
        params_arr.appendAssumeCapacity(jsonString(owner_str));

        // Filter object
        var filter_obj = jsonObject(self.allocator);
        defer filter_obj.deinit();
        switch (filter) {
            .mint => |mint| {
                var mint_buf: [PublicKey.max_base58_len]u8 = undefined;
                const mint_str = mint.toBase58(&mint_buf);
                try filter_obj.put("mint", jsonString(mint_str));
            },
            .program_id => |program| {
                var program_buf2: [PublicKey.max_base58_len]u8 = undefined;
                const program_str = program.toBase58(&program_buf2);
                try filter_obj.put("programId", jsonString(program_str));
            },
        }
        params_arr.appendAssumeCapacity(.{ .object = filter_obj });

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("encoding", jsonString("base64"));
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getTokenAccountsByOwner", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseTokenAccountsResponse(self.allocator, result);
    }

    /// Token account filter
    pub const TokenAccountFilter = union(enum) {
        mint: PublicKey,
        program_id: PublicKey,
    };

    /// Get signatures for address
    ///
    /// RPC Method: `getSignaturesForAddress`
    pub fn getSignaturesForAddress(self: *RpcClient, address: PublicKey) ![]SignatureInfo {
        return self.getSignaturesForAddressWithConfig(address, .{});
    }

    /// Get signatures for address configuration
    pub const GetSignaturesConfig = struct {
        limit: ?u32 = null,
        before: ?Signature = null,
        until: ?Signature = null,
        min_context_slot: ?u64 = null,
    };

    /// Get signatures for address with configuration
    pub fn getSignaturesForAddressWithConfig(self: *RpcClient, address: PublicKey, config: GetSignaturesConfig) ![]SignatureInfo {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        var addr_buf: [PublicKey.max_base58_len]u8 = undefined;
        const addr_str = address.toBase58(&addr_buf);
        params_arr.appendAssumeCapacity(jsonString(addr_str));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        if (config.limit) |limit| {
            try cfg.put("limit", jsonInt(@intCast(limit)));
        }
        if (config.before) |before| {
            var before_buf: [sdk.signature.MAX_BASE58_LEN]u8 = undefined;
            const before_str = before.toBase58(&before_buf);
            try cfg.put("before", jsonString(before_str));
        }
        if (config.until) |until| {
            var until_buf: [sdk.signature.MAX_BASE58_LEN]u8 = undefined;
            const until_str = until.toBase58(&until_buf);
            try cfg.put("until", jsonString(until_str));
        }
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getSignaturesForAddress", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseSignaturesForAddressResponse(self.allocator, result);
    }

    /// Get token supply
    ///
    /// RPC Method: `getTokenSupply`
    pub fn getTokenSupply(self: *RpcClient, mint: PublicKey) !TokenSupply {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        var mint_buf: [PublicKey.max_base58_len]u8 = undefined;
        const mint_str = mint.toBase58(&mint_buf);
        params_arr.appendAssumeCapacity(jsonString(mint_str));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getTokenSupply", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseTokenSupplyResponse(result);
    }

    /// Get block
    ///
    /// RPC Method: `getBlock`
    pub fn getBlock(self: *RpcClient, slot: u64) !?Block {
        return self.getBlockWithConfig(slot, .{});
    }

    /// Get block configuration
    pub const GetBlockConfig = struct {
        transaction_details: ?[]const u8 = "full",
        rewards: bool = true,
        max_supported_transaction_version: ?u8 = 0,
    };

    /// Get block with configuration
    pub fn getBlockWithConfig(self: *RpcClient, slot: u64, config: GetBlockConfig) !?Block {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        params_arr.appendAssumeCapacity(jsonInt(@intCast(slot)));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("encoding", jsonString("base64"));
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        if (config.transaction_details) |details| {
            try cfg.put("transactionDetails", jsonString(details));
        }
        try cfg.put("rewards", jsonBool(config.rewards));
        if (config.max_supported_transaction_version) |v| {
            try cfg.put("maxSupportedTransactionVersion", jsonInt(@intCast(v)));
        }
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getBlock", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseBlockResponse(self.allocator, result);
    }

    // ========================================================================
    // P2 Complete Methods (28 methods)
    // ========================================================================

    /// Get block commitment
    ///
    /// RPC Method: `getBlockCommitment`
    pub fn getBlockCommitment(self: *RpcClient, slot: u64) !BlockCommitment {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        params_arr.appendAssumeCapacity(jsonInt(@intCast(slot)));

        const result = try self.json_rpc.call(self.allocator, "getBlockCommitment", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        const obj = result.object;
        return .{
            .total_stake = @intCast(obj.get("totalStake").?.integer),
        };
    }

    /// Get blocks in range
    ///
    /// RPC Method: `getBlocks`
    pub fn getBlocks(self: *RpcClient, start_slot: u64, end_slot: ?u64) ![]u64 {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 3);
        defer params_arr.deinit();

        params_arr.appendAssumeCapacity(jsonInt(@intCast(start_slot)));
        if (end_slot) |end| {
            params_arr.appendAssumeCapacity(jsonInt(@intCast(end)));
        }

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getBlocks", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        const arr = result.array;
        var blocks = try self.allocator.alloc(u64, arr.items.len);
        for (arr.items, 0..) |item, i| {
            blocks[i] = @intCast(item.integer);
        }
        return blocks;
    }

    /// Get blocks with limit
    ///
    /// RPC Method: `getBlocksWithLimit`
    pub fn getBlocksWithLimit(self: *RpcClient, start_slot: u64, limit: u64) ![]u64 {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 3);
        defer params_arr.deinit();

        params_arr.appendAssumeCapacity(jsonInt(@intCast(start_slot)));
        params_arr.appendAssumeCapacity(jsonInt(@intCast(limit)));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getBlocksWithLimit", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        const arr = result.array;
        var blocks = try self.allocator.alloc(u64, arr.items.len);
        for (arr.items, 0..) |item, i| {
            blocks[i] = @intCast(item.integer);
        }
        return blocks;
    }

    /// Get block time
    ///
    /// RPC Method: `getBlockTime`
    pub fn getBlockTime(self: *RpcClient, slot: u64) !?i64 {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        params_arr.appendAssumeCapacity(jsonInt(@intCast(slot)));

        const result = try self.json_rpc.call(self.allocator, "getBlockTime", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        if (result == .null) return null;
        return @intCast(result.integer);
    }

    /// Get first available block
    ///
    /// RPC Method: `getFirstAvailableBlock`
    pub fn getFirstAvailableBlock(self: *RpcClient) !u64 {
        const result = try self.json_rpc.call(self.allocator, "getFirstAvailableBlock", null);
        defer freeJsonValue(self.allocator, result);

        return @intCast(result.integer);
    }

    /// Get largest accounts
    ///
    /// RPC Method: `getLargestAccounts`
    pub fn getLargestAccounts(self: *RpcClient) ![]LargeAccount {
        return self.getLargestAccountsWithConfig(.{});
    }

    /// Largest accounts configuration
    pub const LargestAccountsConfig = struct {
        filter: ?[]const u8 = null, // "circulating" or "nonCirculating"
    };

    /// Get largest accounts with configuration
    pub fn getLargestAccountsWithConfig(self: *RpcClient, config: LargestAccountsConfig) ![]LargeAccount {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        if (config.filter) |f| {
            try cfg.put("filter", jsonString(f));
        }
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getLargestAccounts", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseLargestAccountsResponse(self.allocator, result);
    }

    /// Get cluster nodes
    ///
    /// RPC Method: `getClusterNodes`
    pub fn getClusterNodes(self: *RpcClient) ![]ClusterNode {
        const result = try self.json_rpc.call(self.allocator, "getClusterNodes", null);
        defer freeJsonValue(self.allocator, result);

        return parseClusterNodesResponse(self.allocator, result);
    }

    /// Get epoch schedule
    ///
    /// RPC Method: `getEpochSchedule`
    pub fn getEpochSchedule(self: *RpcClient) !RpcEpochSchedule {
        const result = try self.json_rpc.call(self.allocator, "getEpochSchedule", null);
        defer freeJsonValue(self.allocator, result);

        const obj = result.object;
        return .{
            .slots_per_epoch = @intCast(obj.get("slotsPerEpoch").?.integer),
            .leader_schedule_slot_offset = @intCast(obj.get("leaderScheduleSlotOffset").?.integer),
            .warmup = obj.get("warmup").?.bool,
            .first_normal_epoch = @intCast(obj.get("firstNormalEpoch").?.integer),
            .first_normal_slot = @intCast(obj.get("firstNormalSlot").?.integer),
        };
    }

    /// Get genesis hash
    ///
    /// RPC Method: `getGenesisHash`
    pub fn getGenesisHash(self: *RpcClient) !Hash {
        const result = try self.json_rpc.call(self.allocator, "getGenesisHash", null);
        defer freeJsonValue(self.allocator, result);

        return Hash.fromBase58(result.string) catch ClientError.InvalidResponse;
    }

    /// Get highest snapshot slot
    ///
    /// RPC Method: `getHighestSnapshotSlot`
    pub fn getHighestSnapshotSlot(self: *RpcClient) !HighestSnapshotSlot {
        const result = try self.json_rpc.call(self.allocator, "getHighestSnapshotSlot", null);
        defer freeJsonValue(self.allocator, result);

        const obj = result.object;
        return .{
            .full = @intCast(obj.get("full").?.integer),
            .incremental = if (obj.get("incremental")) |inc| if (inc == .null) null else @intCast(inc.integer) else null,
        };
    }

    /// Get identity
    ///
    /// RPC Method: `getIdentity`
    pub fn getIdentity(self: *RpcClient) !PublicKey {
        const result = try self.json_rpc.call(self.allocator, "getIdentity", null);
        defer freeJsonValue(self.allocator, result);

        const obj = result.object;
        return PublicKey.fromBase58(obj.get("identity").?.string) catch ClientError.InvalidResponse;
    }

    /// Get slot leader
    ///
    /// RPC Method: `getSlotLeader`
    pub fn getSlotLeader(self: *RpcClient) !PublicKey {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getSlotLeader", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return PublicKey.fromBase58(result.string) catch ClientError.InvalidResponse;
    }

    /// Get slot leaders
    ///
    /// RPC Method: `getSlotLeaders`
    pub fn getSlotLeaders(self: *RpcClient, start_slot: u64, limit: u64) ![]PublicKey {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        params_arr.appendAssumeCapacity(jsonInt(@intCast(start_slot)));
        params_arr.appendAssumeCapacity(jsonInt(@intCast(limit)));

        const result = try self.json_rpc.call(self.allocator, "getSlotLeaders", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        const arr = result.array;
        var leaders = try self.allocator.alloc(PublicKey, arr.items.len);
        for (arr.items, 0..) |item, i| {
            leaders[i] = PublicKey.fromBase58(item.string) catch return ClientError.InvalidResponse;
        }
        return leaders;
    }

    /// Get inflation governor
    ///
    /// RPC Method: `getInflationGovernor`
    pub fn getInflationGovernor(self: *RpcClient) !InflationGovernor {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getInflationGovernor", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        const obj = result.object;
        return .{
            .initial = obj.get("initial").?.float,
            .terminal = obj.get("terminal").?.float,
            .taper = obj.get("taper").?.float,
            .foundation = obj.get("foundation").?.float,
            .foundation_term = obj.get("foundationTerm").?.float,
        };
    }

    /// Get inflation rate
    ///
    /// RPC Method: `getInflationRate`
    pub fn getInflationRate(self: *RpcClient) !InflationRate {
        const result = try self.json_rpc.call(self.allocator, "getInflationRate", null);
        defer freeJsonValue(self.allocator, result);

        const obj = result.object;
        return .{
            .total = obj.get("total").?.float,
            .validator = obj.get("validator").?.float,
            .foundation = obj.get("foundation").?.float,
            .epoch = @intCast(obj.get("epoch").?.integer),
        };
    }

    /// Get inflation reward
    ///
    /// RPC Method: `getInflationReward`
    pub fn getInflationReward(self: *RpcClient, addresses: []const PublicKey, epoch: ?u64) ![]?InflationReward {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        // Build addresses array
        var addr_arr = std.json.Array.init(self.allocator);
        defer addr_arr.deinit();
        for (addresses) |addr| {
            var addr_buf: [PublicKey.max_base58_len]u8 = undefined;
            const addr_str = addr.toBase58(&addr_buf);
            try addr_arr.append(jsonString(addr_str));
        }
        params_arr.appendAssumeCapacity(.{ .array = addr_arr });

        // Add config
        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        if (epoch) |e| {
            try cfg.put("epoch", jsonInt(@intCast(e)));
        }
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getInflationReward", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseInflationRewardResponse(self.allocator, result);
    }

    /// Get supply
    ///
    /// RPC Method: `getSupply`
    pub fn getSupply(self: *RpcClient) !Supply {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getSupply", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseSupplyResponse(self.allocator, result);
    }

    /// Get transaction count
    ///
    /// RPC Method: `getTransactionCount`
    pub fn getTransactionCount(self: *RpcClient) !u64 {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getTransactionCount", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return @intCast(result.integer);
    }

    /// Get stake minimum delegation
    ///
    /// RPC Method: `getStakeMinimumDelegation`
    pub fn getStakeMinimumDelegation(self: *RpcClient) !u64 {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getStakeMinimumDelegation", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        const obj = result.object;
        return @intCast(obj.get("value").?.integer);
    }

    /// Get vote accounts
    ///
    /// RPC Method: `getVoteAccounts`
    pub fn getVoteAccounts(self: *RpcClient) !VoteAccounts {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getVoteAccounts", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseVoteAccountsResponse(self.allocator, result);
    }

    /// Get recent performance samples
    ///
    /// RPC Method: `getRecentPerformanceSamples`
    pub fn getRecentPerformanceSamples(self: *RpcClient, limit: ?u64) ![]PerformanceSample {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        if (limit) |l| {
            params_arr.appendAssumeCapacity(jsonInt(@intCast(l)));
        }

        const result = try self.json_rpc.call(
            self.allocator,
            "getRecentPerformanceSamples",
            if (params_arr.items.len > 0) .{ .array = params_arr } else null,
        );
        defer freeJsonValue(self.allocator, result);

        return parsePerformanceSamplesResponse(self.allocator, result);
    }

    /// Get token largest accounts
    ///
    /// RPC Method: `getTokenLargestAccounts`
    pub fn getTokenLargestAccounts(self: *RpcClient, mint: PublicKey) ![]TokenLargestAccount {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        var mint_buf: [PublicKey.max_base58_len]u8 = undefined;
        const mint_str = mint.toBase58(&mint_buf);
        params_arr.appendAssumeCapacity(jsonString(mint_str));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getTokenLargestAccounts", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseTokenLargestAccountsResponse(self.allocator, result);
    }

    /// Get token accounts by delegate
    ///
    /// RPC Method: `getTokenAccountsByDelegate`
    pub fn getTokenAccountsByDelegate(self: *RpcClient, delegate: PublicKey, filter: TokenAccountFilter) ![]TokenAccount {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 3);
        defer params_arr.deinit();

        var delegate_buf: [PublicKey.max_base58_len]u8 = undefined;
        const delegate_str = delegate.toBase58(&delegate_buf);
        params_arr.appendAssumeCapacity(jsonString(delegate_str));

        // Filter object
        var filter_obj = jsonObject(self.allocator);
        defer filter_obj.deinit();
        switch (filter) {
            .mint => |mint| {
                var mint_buf: [PublicKey.max_base58_len]u8 = undefined;
                const mint_str = mint.toBase58(&mint_buf);
                try filter_obj.put("mint", jsonString(mint_str));
            },
            .program_id => |program| {
                var program_buf2: [PublicKey.max_base58_len]u8 = undefined;
                const program_str = program.toBase58(&program_buf2);
                try filter_obj.put("programId", jsonString(program_str));
            },
        }
        params_arr.appendAssumeCapacity(.{ .object = filter_obj });

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("encoding", jsonString("base64"));
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getTokenAccountsByDelegate", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseTokenAccountsResponse(self.allocator, result);
    }

    /// Get minimum ledger slot
    ///
    /// RPC Method: `minimumLedgerSlot`
    pub fn minimumLedgerSlot(self: *RpcClient) !u64 {
        const result = try self.json_rpc.call(self.allocator, "minimumLedgerSlot", null);
        defer freeJsonValue(self.allocator, result);

        return @intCast(result.integer);
    }

    /// Get max retransmit slot
    ///
    /// RPC Method: `getMaxRetransmitSlot`
    pub fn getMaxRetransmitSlot(self: *RpcClient) !u64 {
        const result = try self.json_rpc.call(self.allocator, "getMaxRetransmitSlot", null);
        defer freeJsonValue(self.allocator, result);

        return @intCast(result.integer);
    }

    /// Get max shred insert slot
    ///
    /// RPC Method: `getMaxShredInsertSlot`
    pub fn getMaxShredInsertSlot(self: *RpcClient) !u64 {
        const result = try self.json_rpc.call(self.allocator, "getMaxShredInsertSlot", null);
        defer freeJsonValue(self.allocator, result);

        return @intCast(result.integer);
    }

    /// Get block production
    ///
    /// RPC Method: `getBlockProduction`
    pub fn getBlockProduction(self: *RpcClient) !BlockProductionInfo {
        return self.getBlockProductionWithConfig(.{});
    }

    /// Block production configuration
    pub const BlockProductionConfig = struct {
        identity: ?PublicKey = null,
        first_slot: ?u64 = null,
        last_slot: ?u64 = null,
    };

    /// Get block production with configuration
    pub fn getBlockProductionWithConfig(self: *RpcClient, config: BlockProductionConfig) !BlockProductionInfo {
        var params_arr = try std.array_list.Managed(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        if (config.identity) |id| {
            var id_buf: [PublicKey.max_base58_len]u8 = undefined;
            const id_str = id.toBase58(&id_buf);
            try cfg.put("identity", jsonString(id_str));
        }
        if (config.first_slot) |slot| {
            var range_obj = jsonObject(self.allocator);
            try range_obj.put("firstSlot", jsonInt(@intCast(slot)));
            if (config.last_slot) |last| {
                try range_obj.put("lastSlot", jsonInt(@intCast(last)));
            }
            try cfg.put("range", .{ .object = range_obj });
        }
        params_arr.appendAssumeCapacity(.{ .object = cfg });

        const result = try self.json_rpc.call(self.allocator, "getBlockProduction", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return parseBlockProductionResponse(self.allocator, result);
    }

    // ========================================================================
    // Phase 5: Convenience Methods
    // ========================================================================

    /// Configuration for confirmation methods
    pub const ConfirmConfig = struct {
        /// Maximum time to wait for confirmation in milliseconds
        timeout_ms: u64 = 30_000,
        /// Polling interval in milliseconds
        poll_interval_ms: u64 = 500,
        /// Target commitment level for confirmation
        commitment: Commitment = .confirmed,
    };

    /// Send a transaction and wait for confirmation
    ///
    /// This is a convenience method that combines `sendTransaction` and `confirmTransaction`.
    /// It sends the transaction and polls until the transaction reaches the specified
    /// commitment level or times out.
    ///
    /// Returns the signature on success.
    pub fn sendAndConfirmTransaction(self: *RpcClient, transaction: []const u8) !Signature {
        return self.sendAndConfirmTransactionWithConfig(transaction, .{}, .{});
    }

    /// Send a transaction and wait for confirmation with configuration
    pub fn sendAndConfirmTransactionWithConfig(
        self: *RpcClient,
        transaction: []const u8,
        send_config: SendTransactionConfig,
        confirm_config: ConfirmConfig,
    ) !Signature {
        // Send the transaction
        const signature = try self.sendTransactionWithConfig(transaction, send_config);

        // Wait for confirmation
        try self.confirmTransaction(signature, confirm_config);

        return signature;
    }

    /// Wait for a transaction to be confirmed
    ///
    /// Polls the transaction status until it reaches the specified commitment level
    /// or times out.
    pub fn confirmTransaction(self: *RpcClient, signature: Signature, config: ConfirmConfig) !void {
        const result = try self.pollForSignatureStatus(signature, config);
        if (result == null) {
            return ClientError.Timeout;
        }
        if (result.?.err != null) {
            return ClientError.RpcError;
        }
    }

    /// Poll for signature status until confirmed or timeout
    ///
    /// Returns the transaction status if found, or null if timed out.
    pub fn pollForSignatureStatus(self: *RpcClient, signature: Signature, config: ConfirmConfig) !?TransactionStatus {
        const start_time = std.time.milliTimestamp();
        const timeout_time = start_time + @as(i64, @intCast(config.timeout_ms));

        while (std.time.milliTimestamp() < timeout_time) {
            const statuses = try self.getSignatureStatusesWithHistory(&.{signature});
            defer self.allocator.free(statuses);

            if (statuses.len > 0) {
                if (statuses[0]) |status| {
                    // Check if we've reached the desired commitment
                    if (status.confirmation_status) |cs| {
                        const reached = switch (config.commitment) {
                            .processed => true, // Any status is >= processed
                            .confirmed => cs == .confirmed or cs == .finalized,
                            .finalized => cs == .finalized,
                        };
                        if (reached) {
                            return status;
                        }
                    }
                    // If there's an error, return immediately
                    if (status.err != null) {
                        return status;
                    }
                }
            }

            // Sleep before next poll
            std.time.sleep(config.poll_interval_ms * std.time.ns_per_ms);
        }

        return null; // Timeout
    }

    /// Wait for a new blockhash
    ///
    /// Useful when you need a fresh blockhash for a new transaction.
    /// Polls until a blockhash different from the provided one is obtained.
    pub fn getNewBlockhash(self: *RpcClient, current_blockhash: ?Hash) !LatestBlockhash {
        const start_time = std.time.milliTimestamp();
        const timeout_time = start_time + 30_000; // 30 second timeout

        while (std.time.milliTimestamp() < timeout_time) {
            const latest = try self.getLatestBlockhash();

            // If no current blockhash provided, or if we got a different one
            if (current_blockhash == null or !std.mem.eql(u8, &latest.blockhash.data, &current_blockhash.?.data)) {
                return latest;
            }

            // Sleep before next poll
            std.time.sleep(500 * std.time.ns_per_ms);
        }

        return ClientError.Timeout;
    }

    /// Check if the RPC node is healthy
    ///
    /// Returns true if healthy, false otherwise.
    pub fn isHealthy(self: *RpcClient) bool {
        self.getHealth() catch return false;
        return true;
    }

    /// Get the current slot with default commitment
    pub fn getCurrentSlot(self: *RpcClient) !u64 {
        return self.getSlot();
    }

    /// Get account balance in SOL (as f64)
    ///
    /// Convenience method that returns balance as SOL instead of lamports.
    pub fn getBalanceInSol(self: *RpcClient, pubkey: PublicKey) !f64 {
        const lamports = try self.getBalance(pubkey);
        return @as(f64, @floatFromInt(lamports)) / 1_000_000_000.0;
    }
};

// ============================================================================
// Response Parsers
// ============================================================================

fn parseBalanceResponse(result: std.json.Value) !Response(u64) {
    const obj = result.object;
    const ctx = obj.get("context").?.object;
    const value = obj.get("value").?;

    return .{
        .context = .{
            .slot = @intCast(ctx.get("slot").?.integer),
        },
        .value = @intCast(value.integer),
    };
}

fn parseAccountInfoResponse(result: std.json.Value) !Response(?AccountInfo) {
    const obj = result.object;
    const ctx = obj.get("context").?.object;
    const value = obj.get("value");

    if (value == null or value.? == .null) {
        return .{
            .context = .{
                .slot = @intCast(ctx.get("slot").?.integer),
            },
            .value = null,
        };
    }

    const account = value.?.object;
    const data_arr = account.get("data").?.array;

    return .{
        .context = .{
            .slot = @intCast(ctx.get("slot").?.integer),
        },
        .value = .{
            .lamports = @intCast(account.get("lamports").?.integer),
            .owner = PublicKey.fromBase58(account.get("owner").?.string) catch return ClientError.InvalidResponse,
            .data = data_arr.items[0].string, // base64 encoded data
            .executable = account.get("executable").?.bool,
            .rent_epoch = @intCast(account.get("rentEpoch").?.integer),
        },
    };
}

fn parseLatestBlockhashResponse(allocator: Allocator, result: std.json.Value) !Response(LatestBlockhash) {
    _ = allocator;
    const obj = result.object;
    const ctx = obj.get("context").?.object;
    const value = obj.get("value").?.object;

    return .{
        .context = .{
            .slot = @intCast(ctx.get("slot").?.integer),
        },
        .value = .{
            .blockhash = Hash.fromBase58(value.get("blockhash").?.string) catch return ClientError.InvalidResponse,
            .last_valid_block_height = @intCast(value.get("lastValidBlockHeight").?.integer),
        },
    };
}

fn parseSignatureStatusesResponse(allocator: Allocator, result: std.json.Value) ![]?TransactionStatus {
    const obj = result.object;
    const value_arr = obj.get("value").?.array;

    var statuses = try allocator.alloc(?TransactionStatus, value_arr.items.len);

    for (value_arr.items, 0..) |item, i| {
        if (item == .null) {
            statuses[i] = null;
        } else {
            const status_obj = item.object;
            statuses[i] = .{
                .slot = @intCast(status_obj.get("slot").?.integer),
                .confirmations = if (status_obj.get("confirmations")) |c| if (c == .null) null else @intCast(c.integer) else null,
                .err = if (status_obj.get("err")) |e| if (e == .null) null else .{ .err_type = "Error" } else null,
                .confirmation_status = if (status_obj.get("confirmationStatus")) |cs| types.ConfirmationStatus.fromJsonString(cs.string) else null,
            };
        }
    }

    return statuses;
}

fn parseMultipleAccountsResponse(allocator: Allocator, result: std.json.Value) ![]?AccountInfo {
    const obj = result.object;
    const value_arr = obj.get("value").?.array;

    var accounts = try allocator.alloc(?AccountInfo, value_arr.items.len);

    for (value_arr.items, 0..) |item, i| {
        if (item == .null) {
            accounts[i] = null;
        } else {
            const account = item.object;
            const data_arr = account.get("data").?.array;
            accounts[i] = .{
                .lamports = @intCast(account.get("lamports").?.integer),
                .owner = PublicKey.fromBase58(account.get("owner").?.string) catch return ClientError.InvalidResponse,
                .data = data_arr.items[0].string,
                .executable = account.get("executable").?.bool,
                .rent_epoch = @intCast(account.get("rentEpoch").?.integer),
            };
        }
    }

    return accounts;
}

fn parseSimulateTransactionResponse(allocator: Allocator, result: std.json.Value) !SimulateTransactionResult {
    const obj = result.object;
    const value = obj.get("value").?.object;

    // Parse logs array
    var logs: ?[]const []const u8 = null;
    if (value.get("logs")) |logs_val| {
        if (logs_val != .null) {
            const logs_arr = logs_val.array;
            var parsed_logs = try allocator.alloc([]const u8, logs_arr.items.len);
            for (logs_arr.items, 0..) |log_item, i| {
                parsed_logs[i] = log_item.string;
            }
            logs = parsed_logs;
        }
    }

    return .{
        .err = if (value.get("err")) |e| if (e == .null) null else .{ .err_type = "Error" } else null,
        .logs = logs,
        .units_consumed = if (value.get("unitsConsumed")) |u| @intCast(u.integer) else null,
    };
}

fn parseEpochInfoResponse(result: std.json.Value) !sdk.EpochInfo {
    const obj = result.object;

    return sdk.EpochInfo.init(
        @intCast(obj.get("epoch").?.integer),
        @intCast(obj.get("slotIndex").?.integer),
        @intCast(obj.get("slotsInEpoch").?.integer),
        @intCast(obj.get("absoluteSlot").?.integer),
        @intCast(obj.get("blockHeight").?.integer),
        if (obj.get("transactionCount")) |tc| if (tc == .null) null else @intCast(tc.integer) else null,
    );
}

fn parsePrioritizationFeesResponse(allocator: Allocator, result: std.json.Value) ![]PrioritizationFee {
    const arr = result.array;
    var fees = try allocator.alloc(PrioritizationFee, arr.items.len);

    for (arr.items, 0..) |item, i| {
        const obj = item.object;
        fees[i] = .{
            .slot = @intCast(obj.get("slot").?.integer),
            .prioritization_fee = @intCast(obj.get("prioritizationFee").?.integer),
        };
    }

    return fees;
}

fn parseTokenBalanceResponse(result: std.json.Value) !TokenBalance {
    const obj = result.object;
    const value = obj.get("value").?.object;

    return .{
        .amount = value.get("amount").?.string,
        .decimals = @intCast(value.get("decimals").?.integer),
        .ui_amount = if (value.get("uiAmount")) |ua| if (ua == .null) null else ua.float else null,
        .ui_amount_string = if (value.get("uiAmountString")) |uas| uas.string else null,
    };
}

fn parseProgramAccountsResponse(allocator: Allocator, result: std.json.Value) ![]ProgramAccount {
    const arr = result.array;
    var accounts = try allocator.alloc(ProgramAccount, arr.items.len);

    for (arr.items, 0..) |item, i| {
        const obj = item.object;
        const account = obj.get("account").?.object;
        const data_arr = account.get("data").?.array;

        accounts[i] = .{
            .pubkey = PublicKey.fromBase58(obj.get("pubkey").?.string) catch return ClientError.InvalidResponse,
            .account = .{
                .lamports = @intCast(account.get("lamports").?.integer),
                .owner = PublicKey.fromBase58(account.get("owner").?.string) catch return ClientError.InvalidResponse,
                .data = data_arr.items[0].string,
                .executable = account.get("executable").?.bool,
                .rent_epoch = @intCast(account.get("rentEpoch").?.integer),
            },
        };
    }

    return accounts;
}

fn parseTransactionResponse(allocator: Allocator, result: std.json.Value) !?TransactionWithMeta {
    _ = allocator;

    if (result == .null) return null;

    const obj = result.object;
    const meta = obj.get("meta");

    return .{
        .slot = @intCast(obj.get("slot").?.integer),
        .transaction = .{
            .data = obj.get("transaction").?.array.items[0].string,
            .encoding = "base64",
        },
        .meta = if (meta != null and meta.? != .null) blk: {
            const meta_obj = meta.?.object;
            break :blk .{
                .err = if (meta_obj.get("err")) |e| if (e == .null) null else .{ .err_type = "Error" } else null,
                .fee = @intCast(meta_obj.get("fee").?.integer),
                .pre_balances = &.{},
                .post_balances = &.{},
            };
        } else null,
        .block_time = if (obj.get("blockTime")) |bt| if (bt == .null) null else @intCast(bt.integer) else null,
    };
}

fn parseTokenAccountsResponse(allocator: Allocator, result: std.json.Value) ![]TokenAccount {
    const obj = result.object;
    const value_arr = obj.get("value").?.array;

    var accounts = try allocator.alloc(TokenAccount, value_arr.items.len);

    for (value_arr.items, 0..) |item, i| {
        const acct_obj = item.object;
        const account = acct_obj.get("account").?.object;
        const data_arr = account.get("data").?.array;

        accounts[i] = .{
            .pubkey = PublicKey.fromBase58(acct_obj.get("pubkey").?.string) catch return ClientError.InvalidResponse,
            .account = .{
                .lamports = @intCast(account.get("lamports").?.integer),
                .owner = PublicKey.fromBase58(account.get("owner").?.string) catch return ClientError.InvalidResponse,
                .data = data_arr.items[0].string,
                .executable = account.get("executable").?.bool,
                .rent_epoch = @intCast(account.get("rentEpoch").?.integer),
            },
        };
    }

    return accounts;
}

fn parseSignaturesForAddressResponse(allocator: Allocator, result: std.json.Value) ![]SignatureInfo {
    const arr = result.array;
    var signatures = try allocator.alloc(SignatureInfo, arr.items.len);

    for (arr.items, 0..) |item, i| {
        const obj = item.object;
        signatures[i] = .{
            .signature = obj.get("signature").?.string,
            .slot = @intCast(obj.get("slot").?.integer),
            .block_time = if (obj.get("blockTime")) |bt| if (bt == .null) null else @intCast(bt.integer) else null,
            .err = if (obj.get("err")) |e| if (e == .null) null else .{ .err_type = "Error" } else null,
            .memo = if (obj.get("memo")) |m| if (m == .null) null else m.string else null,
            .confirmation_status = if (obj.get("confirmationStatus")) |cs| if (cs == .null) null else types.ConfirmationStatus.fromJsonString(cs.string) else null,
        };
    }

    return signatures;
}

fn parseTokenSupplyResponse(result: std.json.Value) !TokenSupply {
    const obj = result.object;
    const value = obj.get("value").?.object;

    return .{
        .amount = value.get("amount").?.string,
        .decimals = @intCast(value.get("decimals").?.integer),
        .ui_amount = if (value.get("uiAmount")) |ua| if (ua == .null) null else ua.float else null,
        .ui_amount_string = if (value.get("uiAmountString")) |uas| uas.string else null,
    };
}

fn parseBlockResponse(allocator: Allocator, result: std.json.Value) !?Block {
    if (result == .null) return null;

    const obj = result.object;

    // Parse transactions array
    var transactions: ?[]const TransactionWithMeta = null;
    if (obj.get("transactions")) |txs_val| {
        if (txs_val != .null) {
            const txs_arr = txs_val.array;
            var parsed_txs = try allocator.alloc(TransactionWithMeta, txs_arr.items.len);
            for (txs_arr.items, 0..) |tx_item, i| {
                const tx_obj = tx_item.object;
                const meta = tx_obj.get("meta");

                parsed_txs[i] = .{
                    .slot = 0, // Block transactions don't have individual slot
                    .transaction = .{
                        .data = if (tx_obj.get("transaction")) |tx| blk: {
                            if (tx == .array) {
                                break :blk tx.array.items[0].string;
                            } else if (tx == .string) {
                                break :blk tx.string;
                            } else {
                                break :blk "";
                            }
                        } else "",
                        .encoding = "base64",
                    },
                    .meta = if (meta != null and meta.? != .null) blk: {
                        const meta_obj = meta.?.object;
                        break :blk .{
                            .err = if (meta_obj.get("err")) |e| if (e == .null) null else .{ .err_type = "Error" } else null,
                            .fee = if (meta_obj.get("fee")) |f| @intCast(f.integer) else 0,
                            .pre_balances = &.{},
                            .post_balances = &.{},
                        };
                    } else null,
                    .block_time = null,
                };
            }
            transactions = parsed_txs;
        }
    }

    // Parse rewards array
    var rewards: ?[]const Reward = null;
    if (obj.get("rewards")) |rewards_val| {
        if (rewards_val != .null) {
            const rewards_arr = rewards_val.array;
            var parsed_rewards = try allocator.alloc(Reward, rewards_arr.items.len);
            for (rewards_arr.items, 0..) |reward_item, i| {
                const reward_obj = reward_item.object;
                parsed_rewards[i] = .{
                    .pubkey = reward_obj.get("pubkey").?.string,
                    .lamports = reward_obj.get("lamports").?.integer,
                    .post_balance = @intCast(reward_obj.get("postBalance").?.integer),
                    .reward_type = if (reward_obj.get("rewardType")) |rt| if (rt == .null) null else rt.string else null,
                    .commission = if (reward_obj.get("commission")) |c| if (c == .null) null else @intCast(c.integer) else null,
                };
            }
            rewards = parsed_rewards;
        }
    }

    return .{
        .blockhash = Hash.fromBase58(obj.get("blockhash").?.string) catch return ClientError.InvalidResponse,
        .previous_blockhash = Hash.fromBase58(obj.get("previousBlockhash").?.string) catch return ClientError.InvalidResponse,
        .parent_slot = @intCast(obj.get("parentSlot").?.integer),
        .block_time = if (obj.get("blockTime")) |bt| if (bt == .null) null else @intCast(bt.integer) else null,
        .block_height = if (obj.get("blockHeight")) |bh| if (bh == .null) null else @intCast(bh.integer) else null,
        .transactions = transactions,
        .rewards = rewards,
    };
}

fn parseLargestAccountsResponse(allocator: Allocator, result: std.json.Value) ![]LargeAccount {
    const obj = result.object;
    const value_arr = obj.get("value").?.array;

    var accounts = try allocator.alloc(LargeAccount, value_arr.items.len);

    for (value_arr.items, 0..) |item, i| {
        const acct = item.object;
        accounts[i] = .{
            .lamports = @intCast(acct.get("lamports").?.integer),
            .address = acct.get("address").?.string,
        };
    }

    return accounts;
}

fn parseClusterNodesResponse(allocator: Allocator, result: std.json.Value) ![]ClusterNode {
    const arr = result.array;
    var nodes = try allocator.alloc(ClusterNode, arr.items.len);

    for (arr.items, 0..) |item, i| {
        const obj = item.object;
        nodes[i] = .{
            .pubkey = obj.get("pubkey").?.string,
            .gossip = if (obj.get("gossip")) |g| if (g == .null) null else g.string else null,
            .tpu = if (obj.get("tpu")) |t| if (t == .null) null else t.string else null,
            .tpu_quic = if (obj.get("tpuQuic")) |t| if (t == .null) null else t.string else null,
            .rpc = if (obj.get("rpc")) |r| if (r == .null) null else r.string else null,
            .pubsub = if (obj.get("pubsub")) |p| if (p == .null) null else p.string else null,
            .version = if (obj.get("version")) |v| if (v == .null) null else v.string else null,
            .feature_set = if (obj.get("featureSet")) |f| if (f == .null) null else @intCast(f.integer) else null,
            .shred_version = if (obj.get("shredVersion")) |s| if (s == .null) null else @intCast(s.integer) else null,
        };
    }

    return nodes;
}

fn parseInflationRewardResponse(allocator: Allocator, result: std.json.Value) ![]?InflationReward {
    const arr = result.array;
    var rewards = try allocator.alloc(?InflationReward, arr.items.len);

    for (arr.items, 0..) |item, i| {
        if (item == .null) {
            rewards[i] = null;
        } else {
            const obj = item.object;
            rewards[i] = .{
                .epoch = @intCast(obj.get("epoch").?.integer),
                .effective_slot = @intCast(obj.get("effectiveSlot").?.integer),
                .amount = @intCast(obj.get("amount").?.integer),
                .post_balance = @intCast(obj.get("postBalance").?.integer),
                .commission = if (obj.get("commission")) |c| if (c == .null) null else @intCast(c.integer) else null,
            };
        }
    }

    return rewards;
}

fn parseSupplyResponse(allocator: Allocator, result: std.json.Value) !Supply {
    const obj = result.object;
    const value = obj.get("value").?.object;

    // Parse non_circulating_accounts array
    var non_circulating_accounts: []const []const u8 = &.{};
    if (value.get("nonCirculatingAccounts")) |nca_val| {
        if (nca_val != .null) {
            const nca_arr = nca_val.array;
            var parsed_accounts = try allocator.alloc([]const u8, nca_arr.items.len);
            for (nca_arr.items, 0..) |account_item, i| {
                parsed_accounts[i] = account_item.string;
            }
            non_circulating_accounts = parsed_accounts;
        }
    }

    return .{
        .total = @intCast(value.get("total").?.integer),
        .circulating = @intCast(value.get("circulating").?.integer),
        .non_circulating = @intCast(value.get("nonCirculating").?.integer),
        .non_circulating_accounts = non_circulating_accounts,
    };
}

fn parseVoteAccountsResponse(allocator: Allocator, result: std.json.Value) !VoteAccounts {
    const obj = result.object;

    // Helper function to parse vote account array
    const parseVoteAccountArray = struct {
        fn parse(alloc: Allocator, arr_val: ?std.json.Value) ![]const VoteAccountInfo {
            if (arr_val == null or arr_val.? == .null) return &.{};

            const arr = arr_val.?.array;
            var vote_accounts = try alloc.alloc(VoteAccountInfo, arr.items.len);

            for (arr.items, 0..) |item, i| {
                const va_obj = item.object;

                // Parse epoch_credits array: [[epoch, credits, previous_credits], ...]
                var epoch_credits: []const EpochCredit = &.{};
                if (va_obj.get("epochCredits")) |ec_val| {
                    if (ec_val != .null) {
                        const ec_arr = ec_val.array;
                        var parsed_credits = try alloc.alloc(EpochCredit, ec_arr.items.len);
                        for (ec_arr.items, 0..) |ec_item, j| {
                            const ec_tuple = ec_item.array;
                            parsed_credits[j] = .{
                                .epoch = @intCast(ec_tuple.items[0].integer),
                                .credits = @intCast(ec_tuple.items[1].integer),
                                .previous_credits = @intCast(ec_tuple.items[2].integer),
                            };
                        }
                        epoch_credits = parsed_credits;
                    }
                }

                vote_accounts[i] = .{
                    .vote_pubkey = va_obj.get("votePubkey").?.string,
                    .node_pubkey = va_obj.get("nodePubkey").?.string,
                    .activated_stake = @intCast(va_obj.get("activatedStake").?.integer),
                    .epoch_vote_account = va_obj.get("epochVoteAccount").?.bool,
                    .commission = @intCast(va_obj.get("commission").?.integer),
                    .last_vote = @intCast(va_obj.get("lastVote").?.integer),
                    .epoch_credits = epoch_credits,
                    .root_slot = if (va_obj.get("rootSlot")) |rs| if (rs == .null) null else @intCast(rs.integer) else null,
                };
            }
            return vote_accounts;
        }
    }.parse;

    return .{
        .current = try parseVoteAccountArray(allocator, obj.get("current")),
        .delinquent = try parseVoteAccountArray(allocator, obj.get("delinquent")),
    };
}

fn parsePerformanceSamplesResponse(allocator: Allocator, result: std.json.Value) ![]PerformanceSample {
    const arr = result.array;
    var samples = try allocator.alloc(PerformanceSample, arr.items.len);

    for (arr.items, 0..) |item, i| {
        const obj = item.object;
        samples[i] = .{
            .slot = @intCast(obj.get("slot").?.integer),
            .num_transactions = @intCast(obj.get("numTransactions").?.integer),
            .num_slots = @intCast(obj.get("numSlots").?.integer),
            .sample_period_secs = @intCast(obj.get("samplePeriodSecs").?.integer),
            .num_non_vote_transactions = if (obj.get("numNonVoteTransactions")) |n| if (n == .null) null else @intCast(n.integer) else null,
        };
    }

    return samples;
}

fn parseTokenLargestAccountsResponse(allocator: Allocator, result: std.json.Value) ![]TokenLargestAccount {
    const obj = result.object;
    const value_arr = obj.get("value").?.array;

    var accounts = try allocator.alloc(TokenLargestAccount, value_arr.items.len);

    for (value_arr.items, 0..) |item, i| {
        const acct = item.object;
        accounts[i] = .{
            .address = acct.get("address").?.string,
            .amount = acct.get("amount").?.string,
            .decimals = @intCast(acct.get("decimals").?.integer),
            .ui_amount = if (acct.get("uiAmount")) |ua| if (ua == .null) null else ua.float else null,
            .ui_amount_string = if (acct.get("uiAmountString")) |uas| uas.string else null,
        };
    }

    return accounts;
}

fn parseBlockProductionResponse(allocator: Allocator, result: std.json.Value) !BlockProductionInfo {
    const obj = result.object;
    const value = obj.get("value").?.object;
    const range = value.get("range").?.object;

    // Parse byIdentity map: { "pubkey": [leader_slots, blocks_produced], ... }
    var by_identity: []const IdentityBlockProduction = &.{};
    if (value.get("byIdentity")) |bi_val| {
        if (bi_val != .null) {
            const bi_obj = bi_val.object;
            var parsed_identities = try allocator.alloc(IdentityBlockProduction, bi_obj.count());
            var idx: usize = 0;
            var iter = bi_obj.iterator();
            while (iter.next()) |entry| {
                const identity_key = entry.key_ptr.*;
                const slots_arr = entry.value_ptr.*.array;
                parsed_identities[idx] = .{
                    .identity = identity_key,
                    .leader_slots = @intCast(slots_arr.items[0].integer),
                    .blocks_produced = @intCast(slots_arr.items[1].integer),
                };
                idx += 1;
            }
            by_identity = parsed_identities;
        }
    }

    return .{
        .by_identity = by_identity,
        .range = .{
            .first_slot = @intCast(range.get("firstSlot").?.integer),
            .last_slot = @intCast(range.get("lastSlot").?.integer),
        },
    };
}

// ============================================================================
// Helpers
// ============================================================================

fn base64Encode(allocator: Allocator, data: []const u8) ![]u8 {
    const encoder = std.base64.standard.Encoder;
    const size = encoder.calcSize(data.len);
    const buffer = try allocator.alloc(u8, size);
    _ = encoder.encode(buffer, data);
    return buffer;
}

fn freeJsonValue(allocator: Allocator, value: std.json.Value) void {
    // Free cloned JSON values (strings and keys that were duplicated in cloneJsonValue)
    switch (value) {
        .string => |s| {
            // Only free if it was allocated (cloned)
            // This is safe because cloneJsonValue always dupes strings
            allocator.free(s);
        },
        .array => |arr| {
            for (arr.items) |item| {
                freeJsonValue(allocator, item);
            }
            arr.deinit();
        },
        .object => |*obj| {
            var iter = obj.iterator();
            while (iter.next()) |entry| {
                // Free the duplicated key
                allocator.free(entry.key_ptr.*);
                // Free the value
                freeJsonValue(allocator, entry.value_ptr.*);
            }
            @constCast(obj).deinit();
        },
        else => {},
    }
}

// ============================================================================
// Tests
// ============================================================================

test "rpc_client: init" {
    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, "http://localhost:8899");
    defer client.deinit();

    try std.testing.expect(client.commitment.isFinalized());
}

test "rpc_client: initWithCommitment" {
    const allocator = std.testing.allocator;
    var client = RpcClient.initWithCommitment(
        allocator,
        "http://localhost:8899",
        CommitmentConfig.confirmed,
    );
    defer client.deinit();

    try std.testing.expect(client.commitment.isConfirmed());
}

test "rpc_client: base64Encode" {
    const allocator = std.testing.allocator;
    const data = "Hello, World!";
    const encoded = try base64Encode(allocator, data);
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings("SGVsbG8sIFdvcmxkIQ==", encoded);
}

test "rpc_client: ConfirmConfig defaults" {
    const config = RpcClient.ConfirmConfig{};
    try std.testing.expectEqual(@as(u64, 30_000), config.timeout_ms);
    try std.testing.expectEqual(@as(u64, 500), config.poll_interval_ms);
    try std.testing.expectEqual(Commitment.confirmed, config.commitment);
}

test "rpc_client: isHealthy returns bool type" {
    const allocator = std.testing.allocator;
    // Use an invalid port that definitely has no RPC server
    var client = RpcClient.init(allocator, "http://127.0.0.1:1");
    defer client.deinit();

    // isHealthy should return a bool (false for unreachable endpoint)
    const healthy = client.isHealthy();
    // Verify it returns false for unreachable endpoint
    try std.testing.expectEqual(false, healthy);
}

// ============================================================================
// Response Parser Tests
// ============================================================================

test "rpc_client: parseBalanceResponse" {
    const json_str =
        \\{"context":{"slot":12345},"value":1000000000}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_str, .{});
    defer parsed.deinit();

    const response = try parseBalanceResponse(parsed.value);
    try std.testing.expectEqual(@as(u64, 12345), response.context.slot);
    try std.testing.expectEqual(@as(u64, 1000000000), response.value);
}

test "rpc_client: parseAccountInfoResponse with data" {
    const json_str =
        \\{"context":{"slot":100},"value":{"lamports":5000000,"owner":"11111111111111111111111111111111","data":["SGVsbG8=","base64"],"executable":false,"rentEpoch":0}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_str, .{});
    defer parsed.deinit();

    const response = try parseAccountInfoResponse(parsed.value);
    try std.testing.expectEqual(@as(u64, 100), response.context.slot);
    try std.testing.expect(response.value != null);
    const account = response.value.?;
    try std.testing.expectEqual(@as(u64, 5000000), account.lamports);
    try std.testing.expectEqual(false, account.executable);
    try std.testing.expectEqualStrings("SGVsbG8=", account.data);
}

test "rpc_client: parseAccountInfoResponse with null value" {
    const json_str =
        \\{"context":{"slot":100},"value":null}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_str, .{});
    defer parsed.deinit();

    const response = try parseAccountInfoResponse(parsed.value);
    try std.testing.expectEqual(@as(u64, 100), response.context.slot);
    try std.testing.expect(response.value == null);
}

test "rpc_client: parseLatestBlockhashResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"context":{"slot":200},"value":{"blockhash":"4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZAMdL4VZHirAn","lastValidBlockHeight":12345}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const response = try parseLatestBlockhashResponse(allocator, parsed.value);
    try std.testing.expectEqual(@as(u64, 200), response.context.slot);
    try std.testing.expectEqual(@as(u64, 12345), response.value.last_valid_block_height);
}

test "rpc_client: parseSignatureStatusesResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"context":{"slot":100},"value":[{"slot":50,"confirmations":10,"err":null,"confirmationStatus":"confirmed"},null,{"slot":60,"confirmations":null,"err":{"InstructionError":[0,"Custom"]},"confirmationStatus":"finalized"}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const statuses = try parseSignatureStatusesResponse(allocator, parsed.value);
    defer allocator.free(statuses);

    try std.testing.expectEqual(@as(usize, 3), statuses.len);
    // First status: confirmed
    try std.testing.expect(statuses[0] != null);
    try std.testing.expectEqual(@as(u64, 50), statuses[0].?.slot);
    try std.testing.expectEqual(@as(?u64, 10), statuses[0].?.confirmations);
    try std.testing.expect(statuses[0].?.err == null);
    try std.testing.expectEqual(types.ConfirmationStatus.confirmed, statuses[0].?.confirmation_status.?);
    // Second status: null
    try std.testing.expect(statuses[1] == null);
    // Third status: finalized with error
    try std.testing.expect(statuses[2] != null);
    try std.testing.expectEqual(@as(u64, 60), statuses[2].?.slot);
    try std.testing.expect(statuses[2].?.confirmations == null);
    try std.testing.expect(statuses[2].?.err != null);
    try std.testing.expectEqual(types.ConfirmationStatus.finalized, statuses[2].?.confirmation_status.?);
}

test "rpc_client: parseMultipleAccountsResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"context":{"slot":100},"value":[{"lamports":1000,"owner":"11111111111111111111111111111111","data":["","base64"],"executable":false,"rentEpoch":0},null]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const accounts = try parseMultipleAccountsResponse(allocator, parsed.value);
    defer allocator.free(accounts);

    try std.testing.expectEqual(@as(usize, 2), accounts.len);
    try std.testing.expect(accounts[0] != null);
    try std.testing.expectEqual(@as(u64, 1000), accounts[0].?.lamports);
    try std.testing.expect(accounts[1] == null);
}

test "rpc_client: parseSimulateTransactionResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"context":{"slot":100},"value":{"err":null,"logs":["Program log: Hello","Program log: World"],"unitsConsumed":5000}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const result = try parseSimulateTransactionResponse(allocator, parsed.value);

    try std.testing.expect(result.err == null);
    try std.testing.expect(result.logs != null);
    try std.testing.expectEqual(@as(usize, 2), result.logs.?.len);
    try std.testing.expectEqualStrings("Program log: Hello", result.logs.?[0]);
    try std.testing.expectEqualStrings("Program log: World", result.logs.?[1]);
    try std.testing.expectEqual(@as(?u64, 5000), result.units_consumed);

    if (result.logs) |logs| {
        allocator.free(logs);
    }
}

test "rpc_client: parseSimulateTransactionResponse with error" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"context":{"slot":100},"value":{"err":{"InstructionError":[0,"Custom"]},"logs":null,"unitsConsumed":1000}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const result = try parseSimulateTransactionResponse(allocator, parsed.value);

    try std.testing.expect(result.err != null);
    try std.testing.expect(result.logs == null);
    try std.testing.expectEqual(@as(?u64, 1000), result.units_consumed);
}

test "rpc_client: parseEpochInfoResponse" {
    const json_str =
        \\{"epoch":100,"slotIndex":500,"slotsInEpoch":432000,"absoluteSlot":43200500,"blockHeight":12345678,"transactionCount":1000000}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_str, .{});
    defer parsed.deinit();

    const epoch_info = try parseEpochInfoResponse(parsed.value);
    try std.testing.expectEqual(@as(u64, 100), epoch_info.epoch);
    try std.testing.expectEqual(@as(u64, 500), epoch_info.slot_index);
    try std.testing.expectEqual(@as(u64, 432000), epoch_info.slots_in_epoch);
    try std.testing.expectEqual(@as(u64, 43200500), epoch_info.absolute_slot);
    try std.testing.expectEqual(@as(u64, 12345678), epoch_info.block_height);
    try std.testing.expectEqual(@as(?u64, 1000000), epoch_info.transaction_count);
}

test "rpc_client: parsePrioritizationFeesResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\[{"slot":100,"prioritizationFee":5000},{"slot":101,"prioritizationFee":6000}]
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const fees = try parsePrioritizationFeesResponse(allocator, parsed.value);
    defer allocator.free(fees);

    try std.testing.expectEqual(@as(usize, 2), fees.len);
    try std.testing.expectEqual(@as(u64, 100), fees[0].slot);
    try std.testing.expectEqual(@as(u64, 5000), fees[0].prioritization_fee);
    try std.testing.expectEqual(@as(u64, 101), fees[1].slot);
    try std.testing.expectEqual(@as(u64, 6000), fees[1].prioritization_fee);
}

test "rpc_client: parseTokenBalanceResponse" {
    const json_str =
        \\{"context":{"slot":100},"value":{"amount":"1000000000","decimals":9,"uiAmount":1.0,"uiAmountString":"1"}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_str, .{});
    defer parsed.deinit();

    const balance = try parseTokenBalanceResponse(parsed.value);
    try std.testing.expectEqualStrings("1000000000", balance.amount);
    try std.testing.expectEqual(@as(u8, 9), balance.decimals);
    try std.testing.expectEqual(@as(?f64, 1.0), balance.ui_amount);
    try std.testing.expectEqualStrings("1", balance.ui_amount_string.?);
}

test "rpc_client: parseProgramAccountsResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\[{"pubkey":"11111111111111111111111111111111","account":{"lamports":5000,"owner":"11111111111111111111111111111111","data":["","base64"],"executable":false,"rentEpoch":0}}]
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const accounts = try parseProgramAccountsResponse(allocator, parsed.value);
    defer allocator.free(accounts);

    try std.testing.expectEqual(@as(usize, 1), accounts.len);
    try std.testing.expectEqual(@as(u64, 5000), accounts[0].account.lamports);
}

test "rpc_client: parseTransactionResponse with data" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"slot":100,"transaction":["SGVsbG8=","base64"],"meta":{"err":null,"fee":5000,"preBalances":[100,200],"postBalances":[95,205]},"blockTime":1234567890}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const tx = try parseTransactionResponse(allocator, parsed.value);
    try std.testing.expect(tx != null);
    try std.testing.expectEqual(@as(u64, 100), tx.?.slot);
    try std.testing.expectEqualStrings("SGVsbG8=", tx.?.transaction.data);
    try std.testing.expect(tx.?.meta != null);
    try std.testing.expectEqual(@as(u64, 5000), tx.?.meta.?.fee);
    try std.testing.expectEqual(@as(?i64, 1234567890), tx.?.block_time);
}

test "rpc_client: parseTransactionResponse null" {
    const allocator = std.testing.allocator;
    const json_str = "null";
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const tx = try parseTransactionResponse(allocator, parsed.value);
    try std.testing.expect(tx == null);
}

test "rpc_client: parseSignaturesForAddressResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\[{"signature":"5VERv8NMvzbJMEkV8xnrLkEaWRtSz9CosKDYjCJjBRnbJLgp8uirBgmQpjKhoR4tjF3ZpRzrFmBV6UjKdiSZkQUW","slot":100,"blockTime":1234567890,"err":null,"memo":null,"confirmationStatus":"finalized"}]
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const sigs = try parseSignaturesForAddressResponse(allocator, parsed.value);
    defer allocator.free(sigs);

    try std.testing.expectEqual(@as(usize, 1), sigs.len);
    try std.testing.expectEqual(@as(u64, 100), sigs[0].slot);
    try std.testing.expectEqual(@as(?i64, 1234567890), sigs[0].block_time);
    try std.testing.expect(sigs[0].err == null);
    try std.testing.expectEqual(types.ConfirmationStatus.finalized, sigs[0].confirmation_status.?);
}

test "rpc_client: parseTokenSupplyResponse" {
    const json_str =
        \\{"context":{"slot":100},"value":{"amount":"1000000000000","decimals":6,"uiAmount":1000000.0,"uiAmountString":"1000000"}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_str, .{});
    defer parsed.deinit();

    const supply = try parseTokenSupplyResponse(parsed.value);
    try std.testing.expectEqualStrings("1000000000000", supply.amount);
    try std.testing.expectEqual(@as(u8, 6), supply.decimals);
}

test "rpc_client: parseBlockResponse with transactions and rewards" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"blockhash":"4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZAMdL4VZHirAn","previousBlockhash":"4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZAMdL4VZHirAn","parentSlot":99,"blockTime":1234567890,"blockHeight":12345,"transactions":[{"transaction":["SGVsbG8=","base64"],"meta":{"err":null,"fee":5000}}],"rewards":[{"pubkey":"11111111111111111111111111111111","lamports":1000,"postBalance":5000,"rewardType":"voting","commission":null}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const block = try parseBlockResponse(allocator, parsed.value);
    try std.testing.expect(block != null);
    try std.testing.expectEqual(@as(u64, 99), block.?.parent_slot);
    try std.testing.expectEqual(@as(?i64, 1234567890), block.?.block_time);
    try std.testing.expectEqual(@as(?u64, 12345), block.?.block_height);

    // Check transactions
    try std.testing.expect(block.?.transactions != null);
    try std.testing.expectEqual(@as(usize, 1), block.?.transactions.?.len);

    // Check rewards
    try std.testing.expect(block.?.rewards != null);
    try std.testing.expectEqual(@as(usize, 1), block.?.rewards.?.len);
    try std.testing.expectEqual(@as(i64, 1000), block.?.rewards.?[0].lamports);

    // Free allocated memory
    if (block.?.transactions) |txs| {
        allocator.free(txs);
    }
    if (block.?.rewards) |rewards| {
        allocator.free(rewards);
    }
}

test "rpc_client: parseBlockResponse null" {
    const allocator = std.testing.allocator;
    const json_str = "null";
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const block = try parseBlockResponse(allocator, parsed.value);
    try std.testing.expect(block == null);
}

test "rpc_client: parseLargestAccountsResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"context":{"slot":100},"value":[{"lamports":1000000000000,"address":"11111111111111111111111111111111"},{"lamports":500000000000,"address":"22222222222222222222222222222222"}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const accounts = try parseLargestAccountsResponse(allocator, parsed.value);
    defer allocator.free(accounts);

    try std.testing.expectEqual(@as(usize, 2), accounts.len);
    try std.testing.expectEqual(@as(u64, 1000000000000), accounts[0].lamports);
    try std.testing.expectEqualStrings("11111111111111111111111111111111", accounts[0].address);
}

test "rpc_client: parseClusterNodesResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\[{"pubkey":"11111111111111111111111111111111","gossip":"127.0.0.1:8001","tpu":"127.0.0.1:8002","tpuQuic":"127.0.0.1:8003","rpc":"http://127.0.0.1:8899","version":"1.14.0","featureSet":12345,"shredVersion":100}]
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const nodes = try parseClusterNodesResponse(allocator, parsed.value);
    defer allocator.free(nodes);

    try std.testing.expectEqual(@as(usize, 1), nodes.len);
    try std.testing.expectEqualStrings("11111111111111111111111111111111", nodes[0].pubkey);
    try std.testing.expectEqualStrings("127.0.0.1:8001", nodes[0].gossip.?);
    try std.testing.expectEqualStrings("1.14.0", nodes[0].version.?);
}

test "rpc_client: parseInflationRewardResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\[{"epoch":100,"effectiveSlot":43200000,"amount":5000000,"postBalance":1000000000,"commission":5},null]
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const rewards = try parseInflationRewardResponse(allocator, parsed.value);
    defer allocator.free(rewards);

    try std.testing.expectEqual(@as(usize, 2), rewards.len);
    try std.testing.expect(rewards[0] != null);
    try std.testing.expectEqual(@as(u64, 100), rewards[0].?.epoch);
    try std.testing.expectEqual(@as(u64, 5000000), rewards[0].?.amount);
    try std.testing.expectEqual(@as(?u8, 5), rewards[0].?.commission);
    try std.testing.expect(rewards[1] == null);
}

test "rpc_client: parseSupplyResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"context":{"slot":100},"value":{"total":1000000000000000,"circulating":800000000000000,"nonCirculating":200000000000000,"nonCirculatingAccounts":["11111111111111111111111111111111","22222222222222222222222222222222"]}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const supply = try parseSupplyResponse(allocator, parsed.value);

    try std.testing.expectEqual(@as(u64, 1000000000000000), supply.total);
    try std.testing.expectEqual(@as(u64, 800000000000000), supply.circulating);
    try std.testing.expectEqual(@as(u64, 200000000000000), supply.non_circulating);
    try std.testing.expectEqual(@as(usize, 2), supply.non_circulating_accounts.len);
    try std.testing.expectEqualStrings("11111111111111111111111111111111", supply.non_circulating_accounts[0]);

    allocator.free(supply.non_circulating_accounts);
}

test "rpc_client: parseVoteAccountsResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"current":[{"votePubkey":"Vote111111111111111111111111111111111111111","nodePubkey":"Node111111111111111111111111111111111111111","activatedStake":1000000000,"epochVoteAccount":true,"commission":10,"lastVote":12345,"epochCredits":[[100,1000,900],[101,1100,1000]],"rootSlot":12340}],"delinquent":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const vote_accounts = try parseVoteAccountsResponse(allocator, parsed.value);

    try std.testing.expectEqual(@as(usize, 1), vote_accounts.current.len);
    try std.testing.expectEqual(@as(usize, 0), vote_accounts.delinquent.len);

    const va = vote_accounts.current[0];
    try std.testing.expectEqualStrings("Vote111111111111111111111111111111111111111", va.vote_pubkey);
    try std.testing.expectEqual(@as(u64, 1000000000), va.activated_stake);
    try std.testing.expectEqual(true, va.epoch_vote_account);
    try std.testing.expectEqual(@as(u8, 10), va.commission);
    try std.testing.expectEqual(@as(u64, 12345), va.last_vote);
    try std.testing.expectEqual(@as(?u64, 12340), va.root_slot);

    // Check epoch credits
    try std.testing.expectEqual(@as(usize, 2), va.epoch_credits.len);
    try std.testing.expectEqual(@as(u64, 100), va.epoch_credits[0].epoch);
    try std.testing.expectEqual(@as(u64, 1000), va.epoch_credits[0].credits);
    try std.testing.expectEqual(@as(u64, 900), va.epoch_credits[0].previous_credits);

    // Free allocated memory
    allocator.free(va.epoch_credits);
    allocator.free(vote_accounts.current);
}

test "rpc_client: parsePerformanceSamplesResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\[{"slot":100,"numTransactions":5000,"numSlots":60,"samplePeriodSecs":60,"numNonVoteTransactions":3000}]
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const samples = try parsePerformanceSamplesResponse(allocator, parsed.value);
    defer allocator.free(samples);

    try std.testing.expectEqual(@as(usize, 1), samples.len);
    try std.testing.expectEqual(@as(u64, 100), samples[0].slot);
    try std.testing.expectEqual(@as(u64, 5000), samples[0].num_transactions);
    try std.testing.expectEqual(@as(u64, 60), samples[0].num_slots);
    try std.testing.expectEqual(@as(u16, 60), samples[0].sample_period_secs);
    try std.testing.expectEqual(@as(?u64, 3000), samples[0].num_non_vote_transactions);
}

test "rpc_client: parseTokenLargestAccountsResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"context":{"slot":100},"value":[{"address":"11111111111111111111111111111111","amount":"1000000000","decimals":9,"uiAmount":1.0,"uiAmountString":"1"}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const accounts = try parseTokenLargestAccountsResponse(allocator, parsed.value);
    defer allocator.free(accounts);

    try std.testing.expectEqual(@as(usize, 1), accounts.len);
    try std.testing.expectEqualStrings("11111111111111111111111111111111", accounts[0].address);
    try std.testing.expectEqualStrings("1000000000", accounts[0].amount);
    try std.testing.expectEqual(@as(u8, 9), accounts[0].decimals);
}

test "rpc_client: parseBlockProductionResponse" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{"context":{"slot":100},"value":{"byIdentity":{"Validator1111111111111111111111111111111111":[100,95],"Validator2222222222222222222222222222222222":[50,48]},"range":{"firstSlot":0,"lastSlot":100}}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const production = try parseBlockProductionResponse(allocator, parsed.value);

    try std.testing.expectEqual(@as(u64, 0), production.range.first_slot);
    try std.testing.expectEqual(@as(u64, 100), production.range.last_slot);
    try std.testing.expectEqual(@as(usize, 2), production.by_identity.len);

    allocator.free(production.by_identity);
}

// ============================================================================
// Configuration Tests
// ============================================================================

test "rpc_client: SendTransactionConfig defaults" {
    const config = RpcClient.SendTransactionConfig{};
    try std.testing.expectEqual(false, config.skip_preflight);
    try std.testing.expect(config.preflight_commitment == null);
    try std.testing.expect(config.max_retries == null);
    try std.testing.expect(config.min_context_slot == null);
}

test "rpc_client: GetProgramAccountsConfig defaults" {
    const config = RpcClient.GetProgramAccountsConfig{};
    try std.testing.expect(config.filters == null);
    try std.testing.expectEqual(false, config.with_context);
}

test "rpc_client: GetTransactionConfig defaults" {
    const config = RpcClient.GetTransactionConfig{};
    try std.testing.expectEqual(@as(?u8, 0), config.max_supported_transaction_version);
}

test "rpc_client: GetSignaturesConfig defaults" {
    const config = RpcClient.GetSignaturesConfig{};
    try std.testing.expect(config.limit == null);
    try std.testing.expect(config.before == null);
    try std.testing.expect(config.until == null);
}

test "rpc_client: GetBlockConfig defaults" {
    const config = RpcClient.GetBlockConfig{};
    try std.testing.expectEqualStrings("full", config.transaction_details.?);
    try std.testing.expectEqual(true, config.rewards);
    try std.testing.expectEqual(@as(?u8, 0), config.max_supported_transaction_version);
}

test "rpc_client: LargestAccountsConfig defaults" {
    const config = RpcClient.LargestAccountsConfig{};
    try std.testing.expect(config.filter == null);
}

test "rpc_client: BlockProductionConfig defaults" {
    const config = RpcClient.BlockProductionConfig{};
    try std.testing.expect(config.identity == null);
    try std.testing.expect(config.first_slot == null);
    try std.testing.expect(config.last_slot == null);
}

test "rpc_client: TokenAccountFilter mint variant" {
    const mint = PublicKey.default();
    const filter = RpcClient.TokenAccountFilter{ .mint = mint };
    // Check active variant is mint
    switch (filter) {
        .mint => |m| try std.testing.expectEqual(mint, m),
        .program_id => unreachable,
    }
}

test "rpc_client: TokenAccountFilter programId variant" {
    const program_id = PublicKey.default();
    const filter = RpcClient.TokenAccountFilter{ .program_id = program_id };
    // Check active variant is program_id
    switch (filter) {
        .mint => unreachable,
        .program_id => |p| try std.testing.expectEqual(program_id, p),
    }
}

// ============================================================================
// Helper Function Tests
// ============================================================================

test "rpc_client: base64Encode empty" {
    const allocator = std.testing.allocator;
    const encoded = try base64Encode(allocator, "");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("", encoded);
}

test "rpc_client: base64Encode binary data" {
    const allocator = std.testing.allocator;
    const data = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0xFF };
    const encoded = try base64Encode(allocator, &data);
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("AAECA/8=", encoded);
}
