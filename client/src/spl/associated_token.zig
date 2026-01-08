//! Zig implementation of SPL Associated Token Account
//!
//! Rust source: https://github.com/solana-program/associated-token-account/blob/master/interface/src/instruction.rs
//!
//! This module provides utilities for working with Associated Token Accounts (ATAs).
//! An ATA is a Program Derived Address (PDA) that deterministically maps a wallet
//! and mint to a token account address.
//!
//! ## Usage
//!
//! ```zig
//! const ata = @import("spl").associated_token;
//!
//! // Find ATA address
//! const result = ata.findAssociatedTokenAddress(wallet, mint);
//! const ata_address = result.address;
//!
//! // Create ATA instruction (idempotent - recommended)
//! const ix = ata.createIdempotent(payer, wallet, mint);
//! ```

const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;
const AccountMeta = sdk.AccountMeta;

const token = @import("token/root.zig");
const TOKEN_PROGRAM_ID = token.TOKEN_PROGRAM_ID;

// ============================================================================
// Program IDs
// ============================================================================

/// Associated Token Account Program ID
pub const ASSOCIATED_TOKEN_PROGRAM_ID = PublicKey.comptimeFromBase58("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL");

/// System Program ID
pub const SYSTEM_PROGRAM_ID = PublicKey.comptimeFromBase58("11111111111111111111111111111111");

// ============================================================================
// ATA Instruction Enum
// ============================================================================

/// Associated Token Account program instruction types.
///
/// Rust source: https://github.com/solana-program/associated-token-account/blob/master/interface/src/instruction.rs#L19
pub const AssociatedTokenInstruction = enum(u8) {
    /// Creates an associated token account for the given wallet address and token mint.
    /// Returns an error if the account exists.
    ///
    /// Accounts expected:
    /// 0. `[writeable,signer]` Funding account (must be a system account)
    /// 1. `[writeable]` Associated token account address to be created
    /// 2. `[]` Wallet address for the new associated token account
    /// 3. `[]` The token mint for the new associated token account
    /// 4. `[]` System program
    /// 5. `[]` SPL Token program
    Create = 0,

    /// Creates an associated token account for the given wallet address and token mint,
    /// if it doesn't already exist. Returns without error if the account exists.
    ///
    /// Accounts expected:
    /// 0. `[writeable,signer]` Funding account (must be a system account)
    /// 1. `[writeable]` Associated token account address to be created
    /// 2. `[]` Wallet address for the new associated token account
    /// 3. `[]` The token mint for the new associated token account
    /// 4. `[]` System program
    /// 5. `[]` SPL Token program
    CreateIdempotent = 1,

    /// Transfers from and closes a nested associated token account.
    ///
    /// Accounts expected:
    /// 0. `[writeable]` Nested associated token account
    /// 1. `[]` Token mint for the nested associated token account
    /// 2. `[writeable]` Wallet's associated token account
    /// 3. `[]` Owner associated token account address
    /// 4. `[]` Token mint for the owner associated token account
    /// 5. `[writeable,signer]` Wallet address for the owner associated token account
    /// 6. `[]` SPL Token program
    RecoverNested = 2,
};

// ============================================================================
// PDA Derivation
// ============================================================================

/// Result of findAssociatedTokenAddress
pub const AssociatedTokenAddressResult = struct {
    /// The derived associated token account address
    address: PublicKey,
    /// The bump seed used in derivation
    bump: u8,
};

/// Derives the associated token account address for the given wallet address and token mint.
///
/// The seeds used are (in order):
/// 1. wallet address (32 bytes)
/// 2. token program id (32 bytes)
/// 3. mint address (32 bytes)
///
/// Rust source: https://github.com/solana-program/associated-token-account/blob/master/interface/src/lib.rs#L43
pub fn findAssociatedTokenAddress(
    wallet: PublicKey,
    mint: PublicKey,
) AssociatedTokenAddressResult {
    const seeds = .{
        &wallet.bytes,
        &TOKEN_PROGRAM_ID.bytes,
        &mint.bytes,
    };

    const pda = PublicKey.findProgramAddress(seeds, ASSOCIATED_TOKEN_PROGRAM_ID) catch {
        // This should never happen with valid inputs
        @panic("Failed to find program address for ATA");
    };

    return .{
        .address = pda.address,
        .bump = pda.bump_seed[0],
    };
}

/// Derives the associated token account address for the given wallet, mint, and token program.
///
/// This version allows specifying a custom token program (e.g., Token-2022).
pub fn findAssociatedTokenAddressWithProgram(
    wallet: PublicKey,
    mint: PublicKey,
    token_program_id: PublicKey,
) AssociatedTokenAddressResult {
    const seeds = .{
        &wallet.bytes,
        &token_program_id.bytes,
        &mint.bytes,
    };

    const pda = PublicKey.findProgramAddress(seeds, ASSOCIATED_TOKEN_PROGRAM_ID) catch {
        @panic("Failed to find program address for ATA");
    };

    return .{
        .address = pda.address,
        .bump = pda.bump_seed[0],
    };
}

/// Get the associated token account address (convenience function).
///
/// Same as findAssociatedTokenAddress but only returns the address.
pub fn getAssociatedTokenAddress(
    wallet: PublicKey,
    mint: PublicKey,
) PublicKey {
    return findAssociatedTokenAddress(wallet, mint).address;
}

// ============================================================================
// Instruction Builders
// ============================================================================

/// Creates an instruction to create an associated token account.
///
/// This instruction will fail if the account already exists.
/// For most use cases, prefer `createIdempotent` instead.
///
/// Accounts:
/// 0. `[writable, signer]` Funding account (payer)
/// 1. `[writable]` Associated token account to be created
/// 2. `[]` Wallet address for the new ATA
/// 3. `[]` Token mint
/// 4. `[]` System program
/// 5. `[]` SPL Token program
pub fn create(
    payer: PublicKey,
    wallet: PublicKey,
    mint: PublicKey,
) struct { accounts: [6]AccountMeta, data: [1]u8 } {
    const ata = findAssociatedTokenAddress(wallet, mint).address;

    return .{
        .accounts = .{
            AccountMeta.newWritableSigner(payer),
            AccountMeta.newWritable(ata),
            AccountMeta.newReadonly(wallet),
            AccountMeta.newReadonly(mint),
            AccountMeta.newReadonly(SYSTEM_PROGRAM_ID),
            AccountMeta.newReadonly(TOKEN_PROGRAM_ID),
        },
        .data = .{@intFromEnum(AssociatedTokenInstruction.Create)},
    };
}

/// Creates an instruction to create an associated token account with a custom token program.
///
/// This variant allows specifying a token program other than the standard SPL Token program
/// (e.g., for Token-2022 accounts). This instruction will fail if the account already exists.
///
/// For idempotent creation with a custom token program, use `createIdempotentWithProgram`.
///
/// Accounts:
/// 0. `[writable, signer]` Funding account (payer)
/// 1. `[writable]` Associated token account to be created
/// 2. `[]` Wallet address for the new ATA
/// 3. `[]` Token mint
/// 4. `[]` System program
/// 5. `[]` Custom token program (e.g., Token-2022)
pub fn createWithProgram(
    payer: PublicKey,
    wallet: PublicKey,
    mint: PublicKey,
    token_program_id: PublicKey,
) struct { accounts: [6]AccountMeta, data: [1]u8 } {
    const ata = findAssociatedTokenAddressWithProgram(wallet, mint, token_program_id).address;

    return .{
        .accounts = .{
            AccountMeta.newWritableSigner(payer),
            AccountMeta.newWritable(ata),
            AccountMeta.newReadonly(wallet),
            AccountMeta.newReadonly(mint),
            AccountMeta.newReadonly(SYSTEM_PROGRAM_ID),
            AccountMeta.newReadonly(token_program_id),
        },
        .data = .{@intFromEnum(AssociatedTokenInstruction.Create)},
    };
}

/// Creates an instruction to create an associated token account (idempotent).
///
/// This instruction succeeds even if the account already exists.
/// This is the **recommended** instruction for creating ATAs.
///
/// Accounts:
/// 0. `[writable, signer]` Funding account (payer)
/// 1. `[writable]` Associated token account to be created
/// 2. `[]` Wallet address for the new ATA
/// 3. `[]` Token mint
/// 4. `[]` System program
/// 5. `[]` SPL Token program
pub fn createIdempotent(
    payer: PublicKey,
    wallet: PublicKey,
    mint: PublicKey,
) struct { accounts: [6]AccountMeta, data: [1]u8 } {
    const ata = findAssociatedTokenAddress(wallet, mint).address;

    return .{
        .accounts = .{
            AccountMeta.newWritableSigner(payer),
            AccountMeta.newWritable(ata),
            AccountMeta.newReadonly(wallet),
            AccountMeta.newReadonly(mint),
            AccountMeta.newReadonly(SYSTEM_PROGRAM_ID),
            AccountMeta.newReadonly(TOKEN_PROGRAM_ID),
        },
        .data = .{@intFromEnum(AssociatedTokenInstruction.CreateIdempotent)},
    };
}

/// Creates an instruction to create an associated token account with a custom token program.
///
/// This variant allows specifying a token program other than the standard SPL Token program
/// (e.g., for Token-2022 accounts).
pub fn createIdempotentWithProgram(
    payer: PublicKey,
    wallet: PublicKey,
    mint: PublicKey,
    token_program_id: PublicKey,
) struct { accounts: [6]AccountMeta, data: [1]u8 } {
    const ata = findAssociatedTokenAddressWithProgram(wallet, mint, token_program_id).address;

    return .{
        .accounts = .{
            AccountMeta.newWritableSigner(payer),
            AccountMeta.newWritable(ata),
            AccountMeta.newReadonly(wallet),
            AccountMeta.newReadonly(mint),
            AccountMeta.newReadonly(SYSTEM_PROGRAM_ID),
            AccountMeta.newReadonly(token_program_id),
        },
        .data = .{@intFromEnum(AssociatedTokenInstruction.CreateIdempotent)},
    };
}

/// Creates an instruction to recover nested associated token accounts.
///
/// This is used to recover tokens from a nested ATA (an ATA owned by another ATA).
///
/// Accounts:
/// 0. `[writable]` Nested associated token account
/// 1. `[]` Token mint for the nested ATA
/// 2. `[writable]` Wallet's associated token account
/// 3. `[]` Owner associated token account address
/// 4. `[]` Token mint for the owner ATA
/// 5. `[writable, signer]` Wallet address for the owner ATA
/// 6. `[]` SPL Token program
pub fn recoverNested(
    nested_ata: PublicKey,
    nested_mint: PublicKey,
    wallet_ata: PublicKey,
    owner_ata: PublicKey,
    owner_mint: PublicKey,
    wallet: PublicKey,
) struct { accounts: [7]AccountMeta, data: [1]u8 } {
    return .{
        .accounts = .{
            AccountMeta.newWritable(nested_ata),
            AccountMeta.newReadonly(nested_mint),
            AccountMeta.newWritable(wallet_ata),
            AccountMeta.newReadonly(owner_ata),
            AccountMeta.newReadonly(owner_mint),
            AccountMeta.newWritableSigner(wallet),
            AccountMeta.newReadonly(TOKEN_PROGRAM_ID),
        },
        .data = .{@intFromEnum(AssociatedTokenInstruction.RecoverNested)},
    };
}

/// Creates an instruction to recover nested associated token accounts with a custom token program.
///
/// This variant allows specifying a token program other than the standard SPL Token program
/// (e.g., for Token-2022 accounts).
///
/// Accounts:
/// 0. `[writable]` Nested associated token account
/// 1. `[]` Token mint for the nested ATA
/// 2. `[writable]` Wallet's associated token account
/// 3. `[]` Owner associated token account address
/// 4. `[]` Token mint for the owner ATA
/// 5. `[writable, signer]` Wallet address for the owner ATA
/// 6. `[]` Custom token program (e.g., Token-2022)
pub fn recoverNestedWithProgram(
    nested_ata: PublicKey,
    nested_mint: PublicKey,
    wallet_ata: PublicKey,
    owner_ata: PublicKey,
    owner_mint: PublicKey,
    wallet: PublicKey,
    token_program_id: PublicKey,
) struct { accounts: [7]AccountMeta, data: [1]u8 } {
    return .{
        .accounts = .{
            AccountMeta.newWritable(nested_ata),
            AccountMeta.newReadonly(nested_mint),
            AccountMeta.newWritable(wallet_ata),
            AccountMeta.newReadonly(owner_ata),
            AccountMeta.newReadonly(owner_mint),
            AccountMeta.newWritableSigner(wallet),
            AccountMeta.newReadonly(token_program_id),
        },
        .data = .{@intFromEnum(AssociatedTokenInstruction.RecoverNested)},
    };
}

// ============================================================================
// Tests
// ============================================================================

test "AssociatedTokenInstruction: enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AssociatedTokenInstruction.Create));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(AssociatedTokenInstruction.CreateIdempotent));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(AssociatedTokenInstruction.RecoverNested));
}

test "ASSOCIATED_TOKEN_PROGRAM_ID: correct value" {
    // Verify the program ID is the expected value
    var buffer: [44]u8 = undefined;
    const str = ASSOCIATED_TOKEN_PROGRAM_ID.toBase58(&buffer);
    try std.testing.expectEqualStrings("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL", str);
}

test "findAssociatedTokenAddress: deterministic" {
    const wallet = PublicKey.from([_]u8{1} ** 32);
    const mint = PublicKey.from([_]u8{2} ** 32);

    // Call twice and verify same result
    const result1 = findAssociatedTokenAddress(wallet, mint);
    const result2 = findAssociatedTokenAddress(wallet, mint);

    try std.testing.expectEqual(result1.address, result2.address);
    try std.testing.expectEqual(result1.bump, result2.bump);
}

test "findAssociatedTokenAddress: different inputs produce different addresses" {
    const wallet1 = PublicKey.from([_]u8{1} ** 32);
    const wallet2 = PublicKey.from([_]u8{2} ** 32);
    const mint = PublicKey.from([_]u8{3} ** 32);

    const result1 = findAssociatedTokenAddress(wallet1, mint);
    const result2 = findAssociatedTokenAddress(wallet2, mint);

    try std.testing.expect(!std.mem.eql(u8, &result1.address.bytes, &result2.address.bytes));
}

test "getAssociatedTokenAddress: same as findAssociatedTokenAddress" {
    const wallet = PublicKey.from([_]u8{1} ** 32);
    const mint = PublicKey.from([_]u8{2} ** 32);

    const full_result = findAssociatedTokenAddress(wallet, mint);
    const address_only = getAssociatedTokenAddress(wallet, mint);

    try std.testing.expectEqual(full_result.address, address_only);
}

test "create: instruction format" {
    const payer = PublicKey.from([_]u8{1} ** 32);
    const wallet = PublicKey.from([_]u8{2} ** 32);
    const mint = PublicKey.from([_]u8{3} ** 32);

    const ix = create(payer, wallet, mint);

    // Check instruction type
    try std.testing.expectEqual(@as(u8, 0), ix.data[0]);

    // Check account count
    try std.testing.expectEqual(@as(usize, 6), ix.accounts.len);

    // Check payer is writable signer
    try std.testing.expectEqual(payer, ix.accounts[0].pubkey);
    try std.testing.expect(ix.accounts[0].is_signer);
    try std.testing.expect(ix.accounts[0].is_writable);

    // Check wallet is readonly
    try std.testing.expectEqual(wallet, ix.accounts[2].pubkey);
    try std.testing.expect(!ix.accounts[2].is_signer);
    try std.testing.expect(!ix.accounts[2].is_writable);

    // Check mint is readonly
    try std.testing.expectEqual(mint, ix.accounts[3].pubkey);

    // Check system program
    try std.testing.expectEqual(SYSTEM_PROGRAM_ID, ix.accounts[4].pubkey);

    // Check token program
    try std.testing.expectEqual(TOKEN_PROGRAM_ID, ix.accounts[5].pubkey);
}

test "createIdempotent: instruction format" {
    const payer = PublicKey.from([_]u8{1} ** 32);
    const wallet = PublicKey.from([_]u8{2} ** 32);
    const mint = PublicKey.from([_]u8{3} ** 32);

    const ix = createIdempotent(payer, wallet, mint);

    // Check instruction type (1 = CreateIdempotent)
    try std.testing.expectEqual(@as(u8, 1), ix.data[0]);

    // Check account count
    try std.testing.expectEqual(@as(usize, 6), ix.accounts.len);
}

test "createIdempotent: ATA address is derived correctly" {
    const payer = PublicKey.from([_]u8{1} ** 32);
    const wallet = PublicKey.from([_]u8{2} ** 32);
    const mint = PublicKey.from([_]u8{3} ** 32);

    const ix = createIdempotent(payer, wallet, mint);
    const expected_ata = findAssociatedTokenAddress(wallet, mint).address;

    // Account[1] should be the derived ATA
    try std.testing.expectEqual(expected_ata, ix.accounts[1].pubkey);
}

test "createWithProgram: instruction format" {
    const payer = PublicKey.from([_]u8{1} ** 32);
    const wallet = PublicKey.from([_]u8{2} ** 32);
    const mint = PublicKey.from([_]u8{3} ** 32);
    // Custom token program ID (e.g., Token-2022)
    const custom_token_program = PublicKey.from([_]u8{4} ** 32);

    const ix = createWithProgram(payer, wallet, mint, custom_token_program);

    // Check instruction type (0 = Create, non-idempotent)
    try std.testing.expectEqual(@as(u8, 0), ix.data[0]);

    // Check account count
    try std.testing.expectEqual(@as(usize, 6), ix.accounts.len);

    // Check token program is the custom one
    try std.testing.expectEqual(custom_token_program, ix.accounts[5].pubkey);

    // Verify ATA is derived with custom token program
    const expected_ata = findAssociatedTokenAddressWithProgram(wallet, mint, custom_token_program).address;
    try std.testing.expectEqual(expected_ata, ix.accounts[1].pubkey);
}

test "createIdempotentWithProgram: instruction format" {
    const payer = PublicKey.from([_]u8{1} ** 32);
    const wallet = PublicKey.from([_]u8{2} ** 32);
    const mint = PublicKey.from([_]u8{3} ** 32);
    const custom_token_program = PublicKey.from([_]u8{4} ** 32);

    const ix = createIdempotentWithProgram(payer, wallet, mint, custom_token_program);

    // Check instruction type (1 = CreateIdempotent)
    try std.testing.expectEqual(@as(u8, 1), ix.data[0]);

    // Check token program is the custom one
    try std.testing.expectEqual(custom_token_program, ix.accounts[5].pubkey);

    // Verify ATA is derived with custom token program
    const expected_ata = findAssociatedTokenAddressWithProgram(wallet, mint, custom_token_program).address;
    try std.testing.expectEqual(expected_ata, ix.accounts[1].pubkey);
}

test "recoverNested: instruction format" {
    const nested_ata = PublicKey.from([_]u8{1} ** 32);
    const nested_mint = PublicKey.from([_]u8{2} ** 32);
    const wallet_ata = PublicKey.from([_]u8{3} ** 32);
    const owner_ata = PublicKey.from([_]u8{4} ** 32);
    const owner_mint = PublicKey.from([_]u8{5} ** 32);
    const wallet = PublicKey.from([_]u8{6} ** 32);

    const ix = recoverNested(nested_ata, nested_mint, wallet_ata, owner_ata, owner_mint, wallet);

    // Check instruction type (2 = RecoverNested)
    try std.testing.expectEqual(@as(u8, 2), ix.data[0]);

    // Check account count
    try std.testing.expectEqual(@as(usize, 7), ix.accounts.len);

    // Check wallet is writable signer
    try std.testing.expectEqual(wallet, ix.accounts[5].pubkey);
    try std.testing.expect(ix.accounts[5].is_signer);
    try std.testing.expect(ix.accounts[5].is_writable);
}

test "recoverNestedWithProgram: instruction format" {
    const nested_ata = PublicKey.from([_]u8{1} ** 32);
    const nested_mint = PublicKey.from([_]u8{2} ** 32);
    const wallet_ata = PublicKey.from([_]u8{3} ** 32);
    const owner_ata = PublicKey.from([_]u8{4} ** 32);
    const owner_mint = PublicKey.from([_]u8{5} ** 32);
    const wallet = PublicKey.from([_]u8{6} ** 32);
    const custom_token_program = PublicKey.from([_]u8{7} ** 32);

    const ix = recoverNestedWithProgram(nested_ata, nested_mint, wallet_ata, owner_ata, owner_mint, wallet, custom_token_program);

    // Check instruction type (2 = RecoverNested)
    try std.testing.expectEqual(@as(u8, 2), ix.data[0]);

    // Check account count
    try std.testing.expectEqual(@as(usize, 7), ix.accounts.len);

    // Check token program is the custom one
    try std.testing.expectEqual(custom_token_program, ix.accounts[6].pubkey);
}
