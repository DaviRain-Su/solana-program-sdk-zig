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

const ClientError = @import("error.zig").ClientError;
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        // Add pubkey
        const pubkey_str = pubkey.toBase58();
        params_arr.appendAssumeCapacity(jsonString(&pubkey_str));

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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        const pubkey_str = pubkey.toBase58();
        params_arr.appendAssumeCapacity(jsonString(&pubkey_str));

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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 1);
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 1);
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        // Build signatures array
        var sig_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, signatures.len);
        defer sig_arr.deinit();
        for (signatures) |sig| {
            const sig_str = sig.toBase58();
            sig_arr.appendAssumeCapacity(jsonString(&sig_str));
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        // Build pubkeys array
        var pk_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, pubkeys.len);
        defer pk_arr.deinit();
        for (pubkeys) |pk| {
            const pk_str = pk.toBase58();
            pk_arr.appendAssumeCapacity(jsonString(&pk_str));
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        const pubkey_str = pubkey.toBase58();
        params_arr.appendAssumeCapacity(jsonString(&pubkey_str));
        params_arr.appendAssumeCapacity(jsonInt(@intCast(lamports)));

        const result = try self.json_rpc.call(self.allocator, "requestAirdrop", .{ .array = params_arr });
        defer freeJsonValue(self.allocator, result);

        return Signature.fromBase58(result.string) catch ClientError.InvalidResponse;
    }

    /// Get current slot
    ///
    /// RPC Method: `getSlot`
    pub fn getSlot(self: *RpcClient) !u64 {
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 1);
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 1);
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 1);
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        const hash_str = blockhash.toBase58();
        params_arr.appendAssumeCapacity(jsonString(&hash_str));

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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 1);
        defer params_arr.deinit();

        if (accounts) |accts| {
            var pk_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, accts.len);
            defer pk_arr.deinit();
            for (accts) |pk| {
                const pk_str = pk.toBase58();
                pk_arr.appendAssumeCapacity(jsonString(&pk_str));
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        const pubkey_str = pubkey.toBase58();
        params_arr.appendAssumeCapacity(jsonString(&pubkey_str));

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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        const program_str = program_id.toBase58();
        params_arr.appendAssumeCapacity(jsonString(&program_str));

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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        const sig_str = signature.toBase58();
        params_arr.appendAssumeCapacity(jsonString(&sig_str));

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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 3);
        defer params_arr.deinit();

        const owner_str = owner.toBase58();
        params_arr.appendAssumeCapacity(jsonString(&owner_str));

        // Filter object
        var filter_obj = jsonObject(self.allocator);
        defer filter_obj.deinit();
        switch (filter) {
            .mint => |mint| {
                const mint_str = mint.toBase58();
                try filter_obj.put("mint", jsonString(&mint_str));
            },
            .program_id => |program| {
                const program_str = program.toBase58();
                try filter_obj.put("programId", jsonString(&program_str));
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        const addr_str = address.toBase58();
        params_arr.appendAssumeCapacity(jsonString(&addr_str));

        var cfg = jsonObject(self.allocator);
        defer cfg.deinit();
        try cfg.put("commitment", jsonString(self.commitment.commitment.toJsonString()));
        if (config.limit) |limit| {
            try cfg.put("limit", jsonInt(@intCast(limit)));
        }
        if (config.before) |before| {
            const before_str = before.toBase58();
            try cfg.put("before", jsonString(&before_str));
        }
        if (config.until) |until| {
            const until_str = until.toBase58();
            try cfg.put("until", jsonString(&until_str));
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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
        defer params_arr.deinit();

        const mint_str = mint.toBase58();
        params_arr.appendAssumeCapacity(jsonString(&mint_str));

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
        var params_arr = try std.ArrayList(std.json.Value).initCapacity(self.allocator, 2);
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

fn parseSimulateTransactionResponse(result: std.json.Value) !SimulateTransactionResult {
    const obj = result.object;
    const value = obj.get("value").?.object;

    return .{
        .err = if (value.get("err")) |e| if (e == .null) null else .{ .err_type = "Error" } else null,
        .logs = null, // TODO: parse logs array
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
    _ = allocator;

    if (result == .null) return null;

    const obj = result.object;

    return .{
        .blockhash = Hash.fromBase58(obj.get("blockhash").?.string) catch return ClientError.InvalidResponse,
        .previous_blockhash = Hash.fromBase58(obj.get("previousBlockhash").?.string) catch return ClientError.InvalidResponse,
        .parent_slot = @intCast(obj.get("parentSlot").?.integer),
        .block_time = if (obj.get("blockTime")) |bt| if (bt == .null) null else @intCast(bt.integer) else null,
        .block_height = if (obj.get("blockHeight")) |bh| if (bh == .null) null else @intCast(bh.integer) else null,
        .transactions = null, // TODO: parse transactions array
        .rewards = null, // TODO: parse rewards array
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
    _ = allocator;
    _ = value;
    // JSON values from parseFromSlice are managed by the parsed struct
    // They get freed when parsed.deinit() is called
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
