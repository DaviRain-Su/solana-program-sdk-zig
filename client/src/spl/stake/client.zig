//! SPL Stake Program RPC Client Wrapper
//!
//! This module provides high-level RPC methods for stake program operations.
//! It combines instruction builders from SDK with transaction building and RPC sending.
//!
//! ## Usage
//!
//! ```zig
//! var client = StakeClient.init(allocator, rpc_client);
//!
//! // Initialize a stake account
//! const sig = try client.initialize(
//!     stake_account,
//!     authorized,
//!     lockup,
//!     &.{&fee_payer_kp, &stake_kp},
//! );
//!
//! // Delegate stake
//! const sig2 = try client.delegate(
//!     stake_account,
//!     vote_account,
//!     authority,
//!     &.{&fee_payer_kp, &authority_kp},
//! );
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;
const Hash = sdk.Hash;
const Signature = sdk.Signature;
const Keypair = sdk.Keypair;
const AccountMeta = sdk.AccountMeta;

// Import stake instruction builders from SDK
const stake = sdk.spl.stake;
const Authorized = stake.Authorized;
const Lockup = stake.Lockup;
const LockupArgs = stake.LockupArgs;
const StakeAuthorize = stake.StakeAuthorize;
const STAKE_PROGRAM_ID = stake.STAKE_PROGRAM_ID;

// Client modules
const client_root = @import("../../root.zig");
const RpcClient = client_root.RpcClient;
const TransactionBuilder = client_root.TransactionBuilder;
const InstructionInput = client_root.InstructionInput;
const ClientError = client_root.ClientError;

/// Stake Program RPC Client
///
/// Provides high-level methods for interacting with the Solana Stake program
/// via RPC. Handles transaction building, signing, and sending automatically.
pub const StakeClient = struct {
    allocator: Allocator,
    rpc: *RpcClient,

    const Self = @This();

    /// Initialize a new StakeClient
    pub fn init(allocator: Allocator, rpc: *RpcClient) Self {
        return .{
            .allocator = allocator,
            .rpc = rpc,
        };
    }

    // ========================================================================
    // Initialize Instructions
    // ========================================================================

    /// Initialize a stake account with authorized staker and withdrawer.
    ///
    /// Creates and sends a transaction to initialize a stake account.
    /// The stake account must already be created (via system program createAccount).
    ///
    /// Signers required:
    /// - Fee payer
    pub fn initialize(
        self: *Self,
        stake_account: PublicKey,
        authorized: Authorized,
        lockup: Lockup,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.initialize(stake_account, authorized, lockup);
        return self.sendInstruction(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Initialize a stake account with checked authorization (both authorities must sign).
    ///
    /// Signers required:
    /// - Fee payer
    /// - Staker authority
    /// - Withdrawer authority
    pub fn initializeChecked(
        self: *Self,
        stake_account: PublicKey,
        staker: PublicKey,
        withdrawer: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.initializeChecked(stake_account, staker, withdrawer);
        return self.sendInstruction(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Delegate Instructions
    // ========================================================================

    /// Delegate stake to a vote account.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Stake authority
    pub fn delegate(
        self: *Self,
        stake_account: PublicKey,
        vote_account: PublicKey,
        authority: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.delegateStake(stake_account, vote_account, authority);
        return self.sendInstruction(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Authorize Instructions
    // ========================================================================

    /// Change the stake or withdraw authority.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Current authority
    /// - Custodian (if lockup is in effect and changing withdrawer)
    pub fn authorize(
        self: *Self,
        stake_account: PublicKey,
        authority: PublicKey,
        new_authority: PublicKey,
        stake_authorize: StakeAuthorize,
        custodian: ?PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.authorize(stake_account, authority, new_authority, stake_authorize, custodian);
        return self.sendInstructionWithNumAccounts(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            ix.num_accounts,
            &ix.data,
            signers,
        );
    }

    /// Change authority with new authority signing (checked variant).
    ///
    /// Signers required:
    /// - Fee payer
    /// - Current authority
    /// - New authority
    /// - Custodian (if lockup is in effect and changing withdrawer)
    pub fn authorizeChecked(
        self: *Self,
        stake_account: PublicKey,
        authority: PublicKey,
        new_authority: PublicKey,
        stake_authorize: StakeAuthorize,
        custodian: ?PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.authorizeChecked(stake_account, authority, new_authority, stake_authorize, custodian);
        return self.sendInstructionWithNumAccounts(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            ix.num_accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Deactivate/Withdraw Instructions
    // ========================================================================

    /// Deactivate the stake (begin cooldown period).
    ///
    /// Signers required:
    /// - Fee payer
    /// - Stake authority
    pub fn deactivate(
        self: *Self,
        stake_account: PublicKey,
        authority: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.deactivate(stake_account, authority);
        return self.sendInstruction(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Withdraw unstaked lamports from the stake account.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Withdraw authority
    /// - Custodian (if lockup is in effect)
    pub fn withdraw(
        self: *Self,
        stake_account: PublicKey,
        recipient: PublicKey,
        authority: PublicKey,
        lamports: u64,
        custodian: ?PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.withdraw(stake_account, recipient, authority, lamports, custodian);
        return self.sendInstructionWithNumAccounts(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            ix.num_accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Split/Merge Instructions
    // ========================================================================

    /// Split stake into a new stake account.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Stake authority
    pub fn split(
        self: *Self,
        stake_account: PublicKey,
        split_stake_account: PublicKey,
        authority: PublicKey,
        lamports: u64,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.split(stake_account, split_stake_account, authority, lamports);
        return self.sendInstruction(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Merge two stake accounts.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Stake authority
    pub fn merge(
        self: *Self,
        destination_stake: PublicKey,
        source_stake: PublicKey,
        authority: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.merge(destination_stake, source_stake, authority);
        return self.sendInstruction(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Lockup Instructions
    // ========================================================================

    /// Set lockup parameters on a stake account.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Lockup authority or withdraw authority
    pub fn setLockup(
        self: *Self,
        stake_account: PublicKey,
        authority: PublicKey,
        lockup_args: LockupArgs,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.setLockup(stake_account, authority, lockup_args);
        return self.sendInstructionWithDataLen(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            ix.data_len,
            signers,
        );
    }

    // ========================================================================
    // Delinquent/Move Instructions
    // ========================================================================

    /// Deactivate stake delegated to a delinquent vote account.
    ///
    /// Signers required:
    /// - Fee payer (no authority required)
    pub fn deactivateDelinquent(
        self: *Self,
        stake_account: PublicKey,
        delinquent_vote_account: PublicKey,
        reference_vote_account: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.deactivateDelinquent(stake_account, delinquent_vote_account, reference_vote_account);
        return self.sendInstruction(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Move stake between accounts with the same authorities and lockups.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Stake authority
    pub fn moveStake(
        self: *Self,
        source_stake: PublicKey,
        destination_stake: PublicKey,
        authority: PublicKey,
        lamports: u64,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.moveStake(source_stake, destination_stake, authority, lamports);
        return self.sendInstruction(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Move unstaked lamports between accounts with the same authorities and lockups.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Stake authority
    pub fn moveLamports(
        self: *Self,
        source_stake: PublicKey,
        destination_stake: PublicKey,
        authority: PublicKey,
        lamports: u64,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = stake.moveLamports(source_stake, destination_stake, authority, lamports);
        return self.sendInstruction(
            STAKE_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Internal Helpers
    // ========================================================================

    /// Build, sign, and send a transaction with a single instruction.
    fn sendInstruction(
        self: *Self,
        program_id: PublicKey,
        accounts: []const AccountMeta,
        data: []const u8,
        signers: []const *const Keypair,
    ) !Signature {
        // Get recent blockhash
        const blockhash = try self.rpc.getLatestBlockhash();

        // Build transaction
        var builder = TransactionBuilder.init(self.allocator);
        defer builder.deinit();

        // Set fee payer (first signer)
        if (signers.len == 0) return error.NoSigners;
        _ = builder.setFeePayer(signers[0].pubkey());
        _ = builder.setRecentBlockhash(blockhash.value.blockhash);

        _ = try builder.addInstruction(.{
            .program_id = program_id,
            .accounts = accounts,
            .data = data,
        });

        // Build and sign
        var tx = try builder.buildSigned(signers);
        defer tx.deinit();

        // Serialize and send
        const serialized = try tx.serialize();
        defer self.allocator.free(serialized);

        return self.rpc.sendAndConfirmTransaction(serialized);
    }

    /// Build, sign, and send with explicit num_accounts (for variable-length account arrays).
    fn sendInstructionWithNumAccounts(
        self: *Self,
        program_id: PublicKey,
        accounts: []const AccountMeta,
        num_accounts: usize,
        data: []const u8,
        signers: []const *const Keypair,
    ) !Signature {
        return self.sendInstruction(program_id, accounts[0..num_accounts], data, signers);
    }

    /// Build, sign, and send with explicit data_len (for variable-length data).
    fn sendInstructionWithDataLen(
        self: *Self,
        program_id: PublicKey,
        accounts: []const AccountMeta,
        data: []const u8,
        data_len: usize,
        signers: []const *const Keypair,
    ) !Signature {
        return self.sendInstruction(program_id, accounts, data[0..data_len], signers);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StakeClient: struct size" {
    // Verify StakeClient is small (just pointers)
    try std.testing.expect(@sizeOf(StakeClient) <= 24);
}
