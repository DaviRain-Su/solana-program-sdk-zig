//! Zig implementation of Solana SDK's system program interface
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/system-program/src/lib.rs
//!
//! The System Program is responsible for creating new accounts, allocating account
//! data, assigning accounts to owning programs, transferring lamports from System
//! Program owned accounts, and paying transaction fees.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const Instruction = @import("instruction.zig").Instruction;
const AccountMeta = @import("instruction.zig").AccountMeta;

/// System program ID
///
/// Rust equivalent: `solana_system_program::id()`
pub const id = PublicKey.comptimeFromBase58("11111111111111111111111111111111");

/// Maximum permitted size of account data (10 MiB)
pub const MAX_PERMITTED_DATA_LENGTH: u64 = 10 * 1024 * 1024;

/// System program instruction types
///
/// Rust equivalent: `solana_system_program::SystemInstruction`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/system-program/src/lib.rs
pub const SystemInstruction = union(enum) {
    /// Create a new account
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Funding account
    ///   1. `[WRITE, SIGNER]` New account
    create_account: CreateAccountParams,

    /// Assign account to a program
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Assigned account public key
    assign: AssignParams,

    /// Transfer lamports
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Funding account
    ///   1. `[WRITE]` Recipient account
    transfer: TransferParams,

    /// Create a new account at an address derived from a base pubkey and a seed
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Funding account
    ///   1. `[WRITE]` Created account
    ///   2. `[SIGNER]` Base account
    create_account_with_seed: CreateAccountWithSeedParams,

    /// Consumes a stored nonce, replacing it with a successor
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[]` RecentBlockhashes sysvar
    ///   2. `[SIGNER]` Nonce authority
    advance_nonce_account,

    /// Withdraw funds from a nonce account
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[WRITE]` Recipient account
    ///   2. `[]` RecentBlockhashes sysvar
    ///   3. `[]` Rent sysvar
    ///   4. `[SIGNER]` Nonce authority
    withdraw_nonce_account: WithdrawNonceParams,

    /// Drive state of Uninitialized nonce account to Initialized, setting the nonce value
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[]` RecentBlockhashes sysvar
    ///   2. `[]` Rent sysvar
    initialize_nonce_account: InitializeNonceParams,

    /// Change the entity authorized to execute nonce instructions on the account
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[SIGNER]` Nonce authority
    authorize_nonce_account: AuthorizeNonceParams,

    /// Allocate space in a (possibly new) account without funding
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` New account
    allocate: AllocateParams,

    /// Allocate space for and assign an account at an address derived from a base pubkey and a seed
    ///
    /// # Account references
    ///   0. `[WRITE]` Allocated account
    ///   1. `[SIGNER]` Base account
    allocate_with_seed: AllocateWithSeedParams,

    /// Assign account to a program based on a seed
    ///
    /// # Account references
    ///   0. `[WRITE]` Assigned account
    ///   1. `[SIGNER]` Base account
    assign_with_seed: AssignWithSeedParams,

    /// Transfer lamports from a derived address
    ///
    /// # Account references
    ///   0. `[WRITE]` Funding account
    ///   1. `[SIGNER]` Base for funding account
    ///   2. `[WRITE]` Recipient account
    transfer_with_seed: TransferWithSeedParams,

    /// Upgrade a nonce account from legacy to durable
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    upgrade_nonce_account,
};

/// Parameters for CreateAccount instruction
pub const CreateAccountParams = struct {
    /// Number of lamports to transfer to the new account
    lamports: u64,
    /// Number of bytes of memory to allocate
    space: u64,
    /// Owner program account address
    owner: PublicKey,
};

/// Parameters for Assign instruction
pub const AssignParams = struct {
    /// Owner program account
    owner: PublicKey,
};

/// Parameters for Transfer instruction
pub const TransferParams = struct {
    /// Amount of lamports to transfer
    lamports: u64,
};

/// Parameters for CreateAccountWithSeed instruction
pub const CreateAccountWithSeedParams = struct {
    /// Base public key
    base: PublicKey,
    /// String of ASCII chars, no longer than PublicKey.max_seed_len
    seed: []const u8,
    /// Number of lamports to transfer to the new account
    lamports: u64,
    /// Number of bytes of memory to allocate
    space: u64,
    /// Owner program account address
    owner: PublicKey,
};

/// Parameters for WithdrawNonceAccount instruction
pub const WithdrawNonceParams = struct {
    /// Amount of lamports to withdraw
    lamports: u64,
};

/// Parameters for InitializeNonceAccount instruction
pub const InitializeNonceParams = struct {
    /// Nonce authority pubkey
    authority: PublicKey,
};

/// Parameters for AuthorizeNonceAccount instruction
pub const AuthorizeNonceParams = struct {
    /// New nonce authority pubkey
    authority: PublicKey,
};

/// Parameters for Allocate instruction
pub const AllocateParams = struct {
    /// Number of bytes of memory to allocate
    space: u64,
};

/// Parameters for AllocateWithSeed instruction
pub const AllocateWithSeedParams = struct {
    /// Base public key
    base: PublicKey,
    /// String of ASCII chars, no longer than PublicKey.max_seed_len
    seed: []const u8,
    /// Number of bytes of memory to allocate
    space: u64,
    /// Owner program account address
    owner: PublicKey,
};

/// Parameters for AssignWithSeed instruction
pub const AssignWithSeedParams = struct {
    /// Base public key
    base: PublicKey,
    /// String of ASCII chars, no longer than PublicKey.max_seed_len
    seed: []const u8,
    /// Owner program account address
    owner: PublicKey,
};

/// Parameters for TransferWithSeed instruction
pub const TransferWithSeedParams = struct {
    /// Amount of lamports to transfer
    lamports: u64,
    /// Seed to use to derive the funding account address
    from_seed: []const u8,
    /// Owner to use to derive the funding account address
    from_owner: PublicKey,
};

// ============================================================================
// Instruction Builders
// ============================================================================

/// Create a CreateAccount instruction
pub fn createAccount(
    allocator: std.mem.Allocator,
    from_pubkey: PublicKey,
    to_pubkey: PublicKey,
    lamports: u64,
    space: u64,
    owner: PublicKey,
) !Instruction {
    // CreateAccount: 4 (index) + 8 (lamports) + 8 (space) + 32 (owner) = 52 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 52);
    errdefer data.deinit();

    // Instruction index: 0 = CreateAccount
    data.appendSliceAssumeCapacity(&[_]u8{ 0, 0, 0, 0 });
    // lamports (u64 little-endian)
    data.appendSliceAssumeCapacity(&std.mem.toBytes(lamports));
    // space (u64 little-endian)
    data.appendSliceAssumeCapacity(&std.mem.toBytes(space));
    // owner (32 bytes)
    data.appendSliceAssumeCapacity(&owner.bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 2);
    errdefer accounts.deinit();
    accounts.appendAssumeCapacity(AccountMeta.init(from_pubkey, true, true));
    accounts.appendAssumeCapacity(AccountMeta.init(to_pubkey, true, true));

    return Instruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create a Transfer instruction
pub fn transfer(
    allocator: std.mem.Allocator,
    from_pubkey: PublicKey,
    to_pubkey: PublicKey,
    lamports: u64,
) !Instruction {
    // Transfer: 4 (index) + 8 (lamports) = 12 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 12);
    errdefer data.deinit();

    // Instruction index: 2 = Transfer
    data.appendSliceAssumeCapacity(&[_]u8{ 2, 0, 0, 0 });
    // lamports (u64 little-endian)
    data.appendSliceAssumeCapacity(&std.mem.toBytes(lamports));

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 2);
    errdefer accounts.deinit();
    accounts.appendAssumeCapacity(AccountMeta.init(from_pubkey, true, true));
    accounts.appendAssumeCapacity(AccountMeta.init(to_pubkey, true, false));

    return Instruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create an Assign instruction
pub fn assign(
    allocator: std.mem.Allocator,
    pubkey: PublicKey,
    owner: PublicKey,
) !Instruction {
    // Assign: 4 (index) + 32 (owner) = 36 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 36);
    errdefer data.deinit();

    // Instruction index: 1 = Assign
    data.appendSliceAssumeCapacity(&[_]u8{ 1, 0, 0, 0 });
    // owner (32 bytes)
    data.appendSliceAssumeCapacity(&owner.bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 1);
    errdefer accounts.deinit();
    accounts.appendAssumeCapacity(AccountMeta.init(pubkey, true, true));

    return Instruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create an Allocate instruction
pub fn allocate(
    allocator: std.mem.Allocator,
    pubkey: PublicKey,
    space: u64,
) !Instruction {
    // Allocate: 4 (index) + 8 (space) = 12 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 12);
    errdefer data.deinit();

    // Instruction index: 8 = Allocate
    data.appendSliceAssumeCapacity(&[_]u8{ 8, 0, 0, 0 });
    // space (u64 little-endian)
    data.appendSliceAssumeCapacity(&std.mem.toBytes(space));

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 1);
    errdefer accounts.deinit();
    accounts.appendAssumeCapacity(AccountMeta.init(pubkey, true, true));

    return Instruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

// ============================================================================
// Tests
// ============================================================================

test "system_program: program id is correct" {
    // System program ID is all zeros in byte form, base58 encodes to all 1s
    const expected = [_]u8{0} ** 32;
    try std.testing.expectEqualSlices(u8, &expected, &id.bytes);
}

test "system_program: create account instruction" {
    const allocator = std.testing.allocator;

    const from = PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const to = PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    const owner = PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");

    var ix = try createAccount(allocator, from, to, 1_000_000, 165, owner);
    defer {
        allocator.free(ix.accounts);
        allocator.free(ix.data);
    }

    // Verify program ID
    try std.testing.expectEqualSlices(u8, &id.bytes, &ix.program_id.bytes);

    // Verify accounts
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_signer);
    try std.testing.expect(ix.accounts[0].is_writable);
    try std.testing.expect(ix.accounts[1].is_signer);
    try std.testing.expect(ix.accounts[1].is_writable);

    // Verify instruction index (0 = CreateAccount)
    try std.testing.expectEqual(@as(u8, 0), ix.data[0]);
}

test "system_program: transfer instruction" {
    const allocator = std.testing.allocator;

    const from = PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const to = PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");

    var ix = try transfer(allocator, from, to, 1_000_000_000);
    defer {
        allocator.free(ix.accounts);
        allocator.free(ix.data);
    }

    // Verify instruction index (2 = Transfer)
    try std.testing.expectEqual(@as(u8, 2), ix.data[0]);

    // Verify lamports
    const lamports = std.mem.readInt(u64, ix.data[4..12], .little);
    try std.testing.expectEqual(@as(u64, 1_000_000_000), lamports);

    // Verify accounts
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_signer);
    try std.testing.expect(ix.accounts[0].is_writable);
    try std.testing.expect(!ix.accounts[1].is_signer);
    try std.testing.expect(ix.accounts[1].is_writable);
}

test "system_program: assign instruction" {
    const allocator = std.testing.allocator;

    const pubkey = PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const owner = PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");

    var ix = try assign(allocator, pubkey, owner);
    defer {
        allocator.free(ix.accounts);
        allocator.free(ix.data);
    }

    // Verify instruction index (1 = Assign)
    try std.testing.expectEqual(@as(u8, 1), ix.data[0]);

    // Verify owner pubkey in data
    try std.testing.expectEqualSlices(u8, &owner.bytes, ix.data[4..36]);
}

test "system_program: allocate instruction" {
    const allocator = std.testing.allocator;

    const pubkey = PublicKey.comptimeFromBase58("11111111111111111111111111111111");

    var ix = try allocate(allocator, pubkey, 1024);
    defer {
        allocator.free(ix.accounts);
        allocator.free(ix.data);
    }

    // Verify instruction index (8 = Allocate)
    try std.testing.expectEqual(@as(u8, 8), ix.data[0]);

    // Verify space
    const space = std.mem.readInt(u64, ix.data[4..12], .little);
    try std.testing.expectEqual(@as(u64, 1024), space);
}

test "system_program: max permitted data length" {
    try std.testing.expectEqual(@as(u64, 10 * 1024 * 1024), MAX_PERMITTED_DATA_LENGTH);
}
