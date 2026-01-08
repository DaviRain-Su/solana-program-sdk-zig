//! SPL Token Program RPC Client Wrapper
//!
//! This module provides high-level RPC methods for token program operations.
//! It combines instruction builders from SDK with transaction building and RPC sending.
//!
//! ## Usage
//!
//! ```zig
//! var client = TokenClient.init(allocator, rpc_client);
//!
//! // Create and initialize a mint
//! const sig = try client.initializeMint(
//!     mint_account,
//!     decimals,
//!     mint_authority,
//!     freeze_authority,
//!     &.{&fee_payer_kp, &mint_kp},
//! );
//!
//! // Transfer tokens
//! const sig2 = try client.transfer(
//!     source,
//!     destination,
//!     owner,
//!     amount,
//!     &.{&fee_payer_kp, &owner_kp},
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

// Import token instruction builders from SDK
const token = sdk.spl.token;
const AuthorityType = token.AuthorityType;
const TOKEN_PROGRAM_ID = token.TOKEN_PROGRAM_ID;

// Client modules
const client_root = @import("../../root.zig");
const RpcClient = client_root.RpcClient;
const TransactionBuilder = client_root.TransactionBuilder;
const InstructionInput = client_root.InstructionInput;
const ClientError = client_root.ClientError;

/// Token Program RPC Client
///
/// Provides high-level methods for interacting with the Solana Token program
/// via RPC. Handles transaction building, signing, and sending automatically.
pub const TokenClient = struct {
    allocator: Allocator,
    rpc: *RpcClient,

    const Self = @This();

    /// Initialize a new TokenClient
    pub fn init(allocator: Allocator, rpc: *RpcClient) Self {
        return .{
            .allocator = allocator,
            .rpc = rpc,
        };
    }

    // ========================================================================
    // Mint Instructions
    // ========================================================================

    /// Initialize a new mint.
    ///
    /// The mint account must already be created (via system program createAccount).
    ///
    /// Signers required:
    /// - Fee payer
    pub fn initializeMint(
        self: *Self,
        mint: PublicKey,
        decimals: u8,
        mint_authority: PublicKey,
        freeze_authority: ?PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.initializeMint(mint, decimals, mint_authority, freeze_authority);
        return self.sendInstructionWithNumAccounts(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            ix.num_accounts,
            &ix.data,
            signers,
        );
    }

    /// Initialize a new mint (without rent sysvar - preferred).
    ///
    /// Signers required:
    /// - Fee payer
    pub fn initializeMint2(
        self: *Self,
        mint: PublicKey,
        decimals: u8,
        mint_authority: PublicKey,
        freeze_authority: ?PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.initializeMint2(mint, decimals, mint_authority, freeze_authority);
        return self.sendInstructionWithNumAccounts(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            ix.num_accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Account Instructions
    // ========================================================================

    /// Initialize a new token account.
    ///
    /// Signers required:
    /// - Fee payer
    pub fn initializeAccount(
        self: *Self,
        account: PublicKey,
        mint: PublicKey,
        owner: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.initializeAccount(account, mint, owner);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Initialize a new token account (owner in instruction data).
    ///
    /// Signers required:
    /// - Fee payer
    pub fn initializeAccount2(
        self: *Self,
        account: PublicKey,
        mint: PublicKey,
        owner: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.initializeAccount2(account, mint, owner);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Initialize a new token account (no rent sysvar, owner in data).
    ///
    /// Signers required:
    /// - Fee payer
    pub fn initializeAccount3(
        self: *Self,
        account: PublicKey,
        mint: PublicKey,
        owner: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.initializeAccount3(account, mint, owner);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Close a token account and transfer remaining lamports.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Account owner
    pub fn closeAccount(
        self: *Self,
        account: PublicKey,
        destination: PublicKey,
        owner: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.closeAccount(account, destination, owner);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Transfer Instructions
    // ========================================================================

    /// Transfer tokens from one account to another.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Source owner
    pub fn transfer(
        self: *Self,
        source: PublicKey,
        destination: PublicKey,
        owner: PublicKey,
        amount: u64,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.transfer(source, destination, owner, amount);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Transfer tokens with decimals check.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Source owner
    pub fn transferChecked(
        self: *Self,
        source: PublicKey,
        mint: PublicKey,
        destination: PublicKey,
        owner: PublicKey,
        amount: u64,
        decimals: u8,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.transferChecked(source, mint, destination, owner, amount, decimals);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Approve/Revoke Instructions
    // ========================================================================

    /// Approve a delegate to transfer tokens.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Source owner
    pub fn approve(
        self: *Self,
        source: PublicKey,
        delegate: PublicKey,
        owner: PublicKey,
        amount: u64,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.approve(source, delegate, owner, amount);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Approve delegate with decimals check.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Source owner
    pub fn approveChecked(
        self: *Self,
        source: PublicKey,
        mint: PublicKey,
        delegate: PublicKey,
        owner: PublicKey,
        amount: u64,
        decimals: u8,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.approveChecked(source, mint, delegate, owner, amount, decimals);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Revoke a delegate's authority.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Source owner
    pub fn revoke(
        self: *Self,
        source: PublicKey,
        owner: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.revoke(source, owner);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Authority Instructions
    // ========================================================================

    /// Set a new authority on a mint or account.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Current authority
    pub fn setAuthority(
        self: *Self,
        account_or_mint: PublicKey,
        current_authority: PublicKey,
        authority_type: AuthorityType,
        new_authority: ?PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.setAuthority(account_or_mint, current_authority, authority_type, new_authority);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Mint/Burn Instructions
    // ========================================================================

    /// Mint new tokens to an account.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Mint authority
    pub fn mintTo(
        self: *Self,
        mint: PublicKey,
        destination: PublicKey,
        mint_authority: PublicKey,
        amount: u64,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.mintTo(mint, destination, mint_authority, amount);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Mint new tokens with decimals check.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Mint authority
    pub fn mintToChecked(
        self: *Self,
        mint: PublicKey,
        destination: PublicKey,
        mint_authority: PublicKey,
        amount: u64,
        decimals: u8,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.mintToChecked(mint, destination, mint_authority, amount, decimals);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Burn tokens from an account.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Account owner
    pub fn burn(
        self: *Self,
        account: PublicKey,
        mint: PublicKey,
        owner: PublicKey,
        amount: u64,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.burn(account, mint, owner, amount);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Burn tokens with decimals check.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Account owner
    pub fn burnChecked(
        self: *Self,
        account: PublicKey,
        mint: PublicKey,
        owner: PublicKey,
        amount: u64,
        decimals: u8,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.burnChecked(account, mint, owner, amount, decimals);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Freeze/Thaw Instructions
    // ========================================================================

    /// Freeze a token account (prevent transfers).
    ///
    /// Signers required:
    /// - Fee payer
    /// - Freeze authority
    pub fn freezeAccount(
        self: *Self,
        account: PublicKey,
        mint: PublicKey,
        freeze_authority: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.freezeAccount(account, mint, freeze_authority);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Thaw a frozen token account.
    ///
    /// Signers required:
    /// - Fee payer
    /// - Freeze authority
    pub fn thawAccount(
        self: *Self,
        account: PublicKey,
        mint: PublicKey,
        freeze_authority: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.thawAccount(account, mint, freeze_authority);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    // ========================================================================
    // Utility Instructions
    // ========================================================================

    /// Sync native SOL balance to token balance.
    ///
    /// Signers required:
    /// - Fee payer
    pub fn syncNative(
        self: *Self,
        native_account: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.syncNative(native_account);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
            &ix.accounts,
            &ix.data,
            signers,
        );
    }

    /// Initialize immutable owner extension.
    ///
    /// Signers required:
    /// - Fee payer
    pub fn initializeImmutableOwner(
        self: *Self,
        account: PublicKey,
        signers: []const *const Keypair,
    ) !Signature {
        const ix = token.initializeImmutableOwner(account);
        return self.sendInstruction(
            TOKEN_PROGRAM_ID,
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
};

// ============================================================================
// Tests
// ============================================================================

test "TokenClient: struct size" {
    // Verify TokenClient is small (just pointers)
    try std.testing.expect(@sizeOf(TokenClient) <= 24);
}
