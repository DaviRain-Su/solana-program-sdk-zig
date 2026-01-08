//! Zig implementation of Solana SDK's system program interface
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/system-program/src/lib.rs
//!
//! The System Program is responsible for creating new accounts, allocating account
//! data, assigning accounts to owning programs, transferring lamports from System
//! Program owned accounts, and paying transaction fees.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const AccountMeta = @import("instruction.zig").AccountMeta;
const sysvar_id = @import("sysvar_id.zig");

/// Built instruction data for transaction building
/// This is used for off-chain instruction creation (not CPI)
pub const BuiltInstruction = struct {
    program_id: PublicKey,
    accounts: []AccountMeta,
    data: []u8,

    pub fn deinit(self: *BuiltInstruction, allocator: std.mem.Allocator) void {
        allocator.free(self.accounts);
        allocator.free(self.data);
    }
};

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
) !BuiltInstruction {
    // CreateAccount: 4 (index) + 8 (lamports) + 8 (space) + 32 (owner) = 52 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 52);
    errdefer data.deinit(allocator);

    // Instruction index: 0 = CreateAccount
    data.appendSliceAssumeCapacity(&[_]u8{ 0, 0, 0, 0 });
    // lamports (u64 little-endian)
    data.appendSliceAssumeCapacity(&std.mem.toBytes(lamports));
    // space (u64 little-endian)
    data.appendSliceAssumeCapacity(&std.mem.toBytes(space));
    // owner (32 bytes)
    data.appendSliceAssumeCapacity(&owner.bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 2);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(from_pubkey, true, true));
    accounts.appendAssumeCapacity(AccountMeta.init(to_pubkey, true, true));

    return BuiltInstruction{
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
) !BuiltInstruction {
    // Transfer: 4 (index) + 8 (lamports) = 12 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 12);
    errdefer data.deinit(allocator);

    // Instruction index: 2 = Transfer
    data.appendSliceAssumeCapacity(&[_]u8{ 2, 0, 0, 0 });
    // lamports (u64 little-endian)
    data.appendSliceAssumeCapacity(&std.mem.toBytes(lamports));

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 2);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(from_pubkey, true, true));
    accounts.appendAssumeCapacity(AccountMeta.init(to_pubkey, false, true));

    return BuiltInstruction{
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
) !BuiltInstruction {
    // Assign: 4 (index) + 32 (owner) = 36 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 36);
    errdefer data.deinit(allocator);

    // Instruction index: 1 = Assign
    data.appendSliceAssumeCapacity(&[_]u8{ 1, 0, 0, 0 });
    // owner (32 bytes)
    data.appendSliceAssumeCapacity(&owner.bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 1);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(pubkey, true, true));

    return BuiltInstruction{
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
) !BuiltInstruction {
    // Allocate: 4 (index) + 8 (space) = 12 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 12);
    errdefer data.deinit(allocator);

    // Instruction index: 8 = Allocate
    data.appendSliceAssumeCapacity(&[_]u8{ 8, 0, 0, 0 });
    // space (u64 little-endian)
    data.appendSliceAssumeCapacity(&std.mem.toBytes(space));

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 1);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(pubkey, true, true));

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create a CreateAccountWithSeed instruction
///
/// Rust equivalent: `system_instruction::create_account_with_seed`
pub fn createAccountWithSeed(
    allocator: std.mem.Allocator,
    from_pubkey: PublicKey,
    to_pubkey: PublicKey,
    base: PublicKey,
    seed: []const u8,
    lamports: u64,
    space: u64,
    owner: PublicKey,
) !BuiltInstruction {
    // CreateAccountWithSeed: 4 (index) + 32 (base) + 4 (seed len) + seed + 8 (lamports) + 8 (space) + 32 (owner)
    const data_len = 4 + 32 + 4 + seed.len + 8 + 8 + 32;
    var data = try std.ArrayList(u8).initCapacity(allocator, data_len);
    errdefer data.deinit(allocator);

    // Instruction index: 3 = CreateAccountWithSeed
    data.appendSliceAssumeCapacity(&[_]u8{ 3, 0, 0, 0 });
    // base (32 bytes)
    data.appendSliceAssumeCapacity(&base.bytes);
    // seed length (u32 little-endian) + seed bytes
    data.appendSliceAssumeCapacity(&std.mem.toBytes(@as(u32, @intCast(seed.len))));
    try data.appendSlice(allocator, seed);
    // lamports (u64 little-endian)
    try data.appendSlice(allocator, &std.mem.toBytes(lamports));
    // space (u64 little-endian)
    try data.appendSlice(allocator, &std.mem.toBytes(space));
    // owner (32 bytes)
    try data.appendSlice(allocator, &owner.bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 3);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(from_pubkey, true, true));
    accounts.appendAssumeCapacity(AccountMeta.init(to_pubkey, false, true));
    // Base account only needs to be signer if it's different from from_pubkey
    const base_is_signer = !base.equals(from_pubkey);
    accounts.appendAssumeCapacity(AccountMeta.init(base, base_is_signer, false));

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create an AdvanceNonceAccount instruction
///
/// Rust equivalent: `system_instruction::advance_nonce_account`
pub fn advanceNonceAccount(
    allocator: std.mem.Allocator,
    nonce_pubkey: PublicKey,
    authorized_pubkey: PublicKey,
) !BuiltInstruction {
    // AdvanceNonceAccount: 4 (index) = 4 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 4);
    errdefer data.deinit(allocator);

    // Instruction index: 4 = AdvanceNonceAccount
    data.appendSliceAssumeCapacity(&[_]u8{ 4, 0, 0, 0 });

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 3);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(nonce_pubkey, false, true));
    accounts.appendAssumeCapacity(AccountMeta.init(sysvar_id.RECENT_BLOCKHASHES, false, false));
    accounts.appendAssumeCapacity(AccountMeta.init(authorized_pubkey, true, false));

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create a WithdrawNonceAccount instruction
///
/// Rust equivalent: `system_instruction::withdraw_nonce_account`
pub fn withdrawNonceAccount(
    allocator: std.mem.Allocator,
    nonce_pubkey: PublicKey,
    authorized_pubkey: PublicKey,
    to_pubkey: PublicKey,
    lamports: u64,
) !BuiltInstruction {
    // WithdrawNonceAccount: 4 (index) + 8 (lamports) = 12 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 12);
    errdefer data.deinit(allocator);

    // Instruction index: 5 = WithdrawNonceAccount
    data.appendSliceAssumeCapacity(&[_]u8{ 5, 0, 0, 0 });
    // lamports (u64 little-endian)
    data.appendSliceAssumeCapacity(&std.mem.toBytes(lamports));

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 5);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(nonce_pubkey, false, true));
    accounts.appendAssumeCapacity(AccountMeta.init(to_pubkey, false, true));
    accounts.appendAssumeCapacity(AccountMeta.init(sysvar_id.RECENT_BLOCKHASHES, false, false));
    accounts.appendAssumeCapacity(AccountMeta.init(sysvar_id.RENT, false, false));
    accounts.appendAssumeCapacity(AccountMeta.init(authorized_pubkey, true, false));

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create an InitializeNonceAccount instruction
///
/// Rust equivalent: `system_instruction::initialize_nonce_account`
pub fn initializeNonceAccount(
    allocator: std.mem.Allocator,
    nonce_pubkey: PublicKey,
    authority: PublicKey,
) !BuiltInstruction {
    // InitializeNonceAccount: 4 (index) + 32 (authority) = 36 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 36);
    errdefer data.deinit(allocator);

    // Instruction index: 6 = InitializeNonceAccount
    data.appendSliceAssumeCapacity(&[_]u8{ 6, 0, 0, 0 });
    // authority (32 bytes)
    data.appendSliceAssumeCapacity(&authority.bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 3);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(nonce_pubkey, false, true));
    accounts.appendAssumeCapacity(AccountMeta.init(sysvar_id.RECENT_BLOCKHASHES, false, false));
    accounts.appendAssumeCapacity(AccountMeta.init(sysvar_id.RENT, false, false));

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create an AuthorizeNonceAccount instruction
///
/// Rust equivalent: `system_instruction::authorize_nonce_account`
pub fn authorizeNonceAccount(
    allocator: std.mem.Allocator,
    nonce_pubkey: PublicKey,
    authorized_pubkey: PublicKey,
    new_authority: PublicKey,
) !BuiltInstruction {
    // AuthorizeNonceAccount: 4 (index) + 32 (new authority) = 36 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 36);
    errdefer data.deinit(allocator);

    // Instruction index: 7 = AuthorizeNonceAccount
    data.appendSliceAssumeCapacity(&[_]u8{ 7, 0, 0, 0 });
    // new authority (32 bytes)
    data.appendSliceAssumeCapacity(&new_authority.bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 2);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(nonce_pubkey, false, true));
    accounts.appendAssumeCapacity(AccountMeta.init(authorized_pubkey, true, false));

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create an AllocateWithSeed instruction
///
/// Rust equivalent: `system_instruction::allocate_with_seed`
pub fn allocateWithSeed(
    allocator: std.mem.Allocator,
    address: PublicKey,
    base: PublicKey,
    seed: []const u8,
    space: u64,
    owner: PublicKey,
) !BuiltInstruction {
    // AllocateWithSeed: 4 (index) + 32 (base) + 4 (seed len) + seed + 8 (space) + 32 (owner)
    const data_len = 4 + 32 + 4 + seed.len + 8 + 32;
    var data = try std.ArrayList(u8).initCapacity(allocator, data_len);
    errdefer data.deinit(allocator);

    // Instruction index: 9 = AllocateWithSeed
    data.appendSliceAssumeCapacity(&[_]u8{ 9, 0, 0, 0 });
    // base (32 bytes)
    data.appendSliceAssumeCapacity(&base.bytes);
    // seed length (u32 little-endian) + seed bytes
    data.appendSliceAssumeCapacity(&std.mem.toBytes(@as(u32, @intCast(seed.len))));
    try data.appendSlice(allocator, seed);
    // space (u64 little-endian)
    try data.appendSlice(allocator, &std.mem.toBytes(space));
    // owner (32 bytes)
    try data.appendSlice(allocator, &owner.bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 2);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(address, false, true));
    accounts.appendAssumeCapacity(AccountMeta.init(base, true, false));

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create an AssignWithSeed instruction
///
/// Rust equivalent: `system_instruction::assign_with_seed`
pub fn assignWithSeed(
    allocator: std.mem.Allocator,
    address: PublicKey,
    base: PublicKey,
    seed: []const u8,
    owner: PublicKey,
) !BuiltInstruction {
    // AssignWithSeed: 4 (index) + 32 (base) + 4 (seed len) + seed + 32 (owner)
    const data_len = 4 + 32 + 4 + seed.len + 32;
    var data = try std.ArrayList(u8).initCapacity(allocator, data_len);
    errdefer data.deinit(allocator);

    // Instruction index: 10 = AssignWithSeed
    data.appendSliceAssumeCapacity(&[_]u8{ 10, 0, 0, 0 });
    // base (32 bytes)
    data.appendSliceAssumeCapacity(&base.bytes);
    // seed length (u32 little-endian) + seed bytes
    data.appendSliceAssumeCapacity(&std.mem.toBytes(@as(u32, @intCast(seed.len))));
    try data.appendSlice(allocator, seed);
    // owner (32 bytes)
    try data.appendSlice(allocator, &owner.bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 2);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(address, false, true));
    accounts.appendAssumeCapacity(AccountMeta.init(base, true, false));

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create a TransferWithSeed instruction
///
/// Rust equivalent: `system_instruction::transfer_with_seed`
pub fn transferWithSeed(
    allocator: std.mem.Allocator,
    from_pubkey: PublicKey,
    from_base: PublicKey,
    from_seed: []const u8,
    from_owner: PublicKey,
    to_pubkey: PublicKey,
    lamports: u64,
) !BuiltInstruction {
    // TransferWithSeed: 4 (index) + 8 (lamports) + 4 (seed len) + seed + 32 (owner)
    const data_len = 4 + 8 + 4 + from_seed.len + 32;
    var data = try std.ArrayList(u8).initCapacity(allocator, data_len);
    errdefer data.deinit(allocator);

    // Instruction index: 11 = TransferWithSeed
    data.appendSliceAssumeCapacity(&[_]u8{ 11, 0, 0, 0 });
    // lamports (u64 little-endian)
    data.appendSliceAssumeCapacity(&std.mem.toBytes(lamports));
    // seed length (u32 little-endian) + seed bytes
    data.appendSliceAssumeCapacity(&std.mem.toBytes(@as(u32, @intCast(from_seed.len))));
    try data.appendSlice(allocator, from_seed);
    // from_owner (32 bytes)
    try data.appendSlice(allocator, &from_owner.bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 3);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(from_pubkey, false, true));
    accounts.appendAssumeCapacity(AccountMeta.init(from_base, true, false));
    accounts.appendAssumeCapacity(AccountMeta.init(to_pubkey, false, true));

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = try data.toOwnedSlice(allocator),
    };
}

/// Create an UpgradeNonceAccount instruction
///
/// Rust equivalent: `system_instruction::upgrade_nonce_account`
pub fn upgradeNonceAccount(
    allocator: std.mem.Allocator,
    nonce_pubkey: PublicKey,
) !BuiltInstruction {
    // UpgradeNonceAccount: 4 (index) = 4 bytes
    var data = try std.ArrayList(u8).initCapacity(allocator, 4);
    errdefer data.deinit(allocator);

    // Instruction index: 12 = UpgradeNonceAccount
    data.appendSliceAssumeCapacity(&[_]u8{ 12, 0, 0, 0 });

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 1);
    errdefer accounts.deinit(allocator);
    accounts.appendAssumeCapacity(AccountMeta.init(nonce_pubkey, false, true));

    return BuiltInstruction{
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

    const from = PublicKey.from([_]u8{1} ** 32);
    const to = PublicKey.from([_]u8{2} ** 32);
    const owner = PublicKey.from([_]u8{3} ** 32);

    var ix = try createAccount(allocator, from, to, 1_000_000, 165, owner);
    defer ix.deinit(allocator);

    // Verify program ID (should be all zeros)
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

    const from = PublicKey.from([_]u8{1} ** 32);
    const to = PublicKey.from([_]u8{2} ** 32);

    var ix = try transfer(allocator, from, to, 1_000_000_000);
    defer ix.deinit(allocator);

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

    const pubkey = PublicKey.from([_]u8{1} ** 32);
    const owner = PublicKey.from([_]u8{2} ** 32);

    var ix = try assign(allocator, pubkey, owner);
    defer ix.deinit(allocator);

    // Verify instruction index (1 = Assign)
    try std.testing.expectEqual(@as(u8, 1), ix.data[0]);

    // Verify owner pubkey in data
    try std.testing.expectEqualSlices(u8, &owner.bytes, ix.data[4..36]);
}

test "system_program: allocate instruction" {
    const allocator = std.testing.allocator;

    const pubkey = PublicKey.from([_]u8{1} ** 32);

    var ix = try allocate(allocator, pubkey, 1024);
    defer ix.deinit(allocator);

    // Verify instruction index (8 = Allocate)
    try std.testing.expectEqual(@as(u8, 8), ix.data[0]);

    // Verify space
    const space = std.mem.readInt(u64, ix.data[4..12], .little);
    try std.testing.expectEqual(@as(u64, 1024), space);
}

test "system_program: max permitted data length" {
    try std.testing.expectEqual(@as(u64, 10 * 1024 * 1024), MAX_PERMITTED_DATA_LENGTH);
}

test "system_program: create account with seed instruction" {
    const allocator = std.testing.allocator;

    const from = PublicKey.from([_]u8{1} ** 32);
    const to = PublicKey.from([_]u8{2} ** 32);
    const base = PublicKey.from([_]u8{3} ** 32);
    const owner = PublicKey.from([_]u8{4} ** 32);
    const seed = "test_seed";

    var ix = try createAccountWithSeed(allocator, from, to, base, seed, 1_000_000, 165, owner);
    defer ix.deinit(allocator);

    // Verify instruction index (3 = CreateAccountWithSeed)
    try std.testing.expectEqual(@as(u8, 3), ix.data[0]);

    // Verify accounts (from, to, base)
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_signer); // from
    try std.testing.expect(ix.accounts[0].is_writable);
    try std.testing.expect(!ix.accounts[1].is_signer); // to (not signer)
    try std.testing.expect(ix.accounts[1].is_writable);
    try std.testing.expect(ix.accounts[2].is_signer); // base (signer when different from from)
}

test "system_program: advance nonce account instruction" {
    const allocator = std.testing.allocator;

    const nonce = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);

    var ix = try advanceNonceAccount(allocator, nonce, authority);
    defer ix.deinit(allocator);

    // Verify instruction index (4 = AdvanceNonceAccount)
    try std.testing.expectEqual(@as(u8, 4), ix.data[0]);

    // Verify accounts (nonce, recent_blockhashes, authority)
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expect(!ix.accounts[0].is_signer); // nonce
    try std.testing.expect(ix.accounts[0].is_writable);
    try std.testing.expect(!ix.accounts[1].is_signer); // recent_blockhashes sysvar
    try std.testing.expect(!ix.accounts[1].is_writable);
    try std.testing.expect(ix.accounts[2].is_signer); // authority
}

test "system_program: withdraw nonce account instruction" {
    const allocator = std.testing.allocator;

    const nonce = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);
    const to = PublicKey.from([_]u8{3} ** 32);

    var ix = try withdrawNonceAccount(allocator, nonce, authority, to, 500_000);
    defer ix.deinit(allocator);

    // Verify instruction index (5 = WithdrawNonceAccount)
    try std.testing.expectEqual(@as(u8, 5), ix.data[0]);

    // Verify lamports
    const lamports = std.mem.readInt(u64, ix.data[4..12], .little);
    try std.testing.expectEqual(@as(u64, 500_000), lamports);

    // Verify accounts (nonce, to, recent_blockhashes, rent, authority)
    try std.testing.expectEqual(@as(usize, 5), ix.accounts.len);
}

test "system_program: initialize nonce account instruction" {
    const allocator = std.testing.allocator;

    const nonce = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);

    var ix = try initializeNonceAccount(allocator, nonce, authority);
    defer ix.deinit(allocator);

    // Verify instruction index (6 = InitializeNonceAccount)
    try std.testing.expectEqual(@as(u8, 6), ix.data[0]);

    // Verify authority in data
    try std.testing.expectEqualSlices(u8, &authority.bytes, ix.data[4..36]);

    // Verify accounts (nonce, recent_blockhashes, rent)
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
}

test "system_program: authorize nonce account instruction" {
    const allocator = std.testing.allocator;

    const nonce = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);
    const new_authority = PublicKey.from([_]u8{3} ** 32);

    var ix = try authorizeNonceAccount(allocator, nonce, authority, new_authority);
    defer ix.deinit(allocator);

    // Verify instruction index (7 = AuthorizeNonceAccount)
    try std.testing.expectEqual(@as(u8, 7), ix.data[0]);

    // Verify new authority in data
    try std.testing.expectEqualSlices(u8, &new_authority.bytes, ix.data[4..36]);

    // Verify accounts (nonce, authority)
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expect(ix.accounts[1].is_signer); // authority must sign
}

test "system_program: allocate with seed instruction" {
    const allocator = std.testing.allocator;

    const address = PublicKey.from([_]u8{1} ** 32);
    const base = PublicKey.from([_]u8{2} ** 32);
    const owner = PublicKey.from([_]u8{3} ** 32);
    const seed = "allocate_seed";

    var ix = try allocateWithSeed(allocator, address, base, seed, 2048, owner);
    defer ix.deinit(allocator);

    // Verify instruction index (9 = AllocateWithSeed)
    try std.testing.expectEqual(@as(u8, 9), ix.data[0]);

    // Verify accounts (address, base)
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expect(ix.accounts[1].is_signer); // base must sign
}

test "system_program: assign with seed instruction" {
    const allocator = std.testing.allocator;

    const address = PublicKey.from([_]u8{1} ** 32);
    const base = PublicKey.from([_]u8{2} ** 32);
    const owner = PublicKey.from([_]u8{3} ** 32);
    const seed = "assign_seed";

    var ix = try assignWithSeed(allocator, address, base, seed, owner);
    defer ix.deinit(allocator);

    // Verify instruction index (10 = AssignWithSeed)
    try std.testing.expectEqual(@as(u8, 10), ix.data[0]);

    // Verify accounts (address, base)
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expect(ix.accounts[1].is_signer); // base must sign
}

test "system_program: transfer with seed instruction" {
    const allocator = std.testing.allocator;

    const from = PublicKey.from([_]u8{1} ** 32);
    const from_base = PublicKey.from([_]u8{2} ** 32);
    const from_owner = PublicKey.from([_]u8{3} ** 32);
    const to = PublicKey.from([_]u8{4} ** 32);
    const seed = "transfer_seed";

    var ix = try transferWithSeed(allocator, from, from_base, seed, from_owner, to, 1_000_000);
    defer ix.deinit(allocator);

    // Verify instruction index (11 = TransferWithSeed)
    try std.testing.expectEqual(@as(u8, 11), ix.data[0]);

    // Verify lamports
    const lamports = std.mem.readInt(u64, ix.data[4..12], .little);
    try std.testing.expectEqual(@as(u64, 1_000_000), lamports);

    // Verify accounts (from, from_base, to)
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expect(ix.accounts[1].is_signer); // from_base must sign
}

test "system_program: upgrade nonce account instruction" {
    const allocator = std.testing.allocator;

    const nonce = PublicKey.from([_]u8{1} ** 32);

    var ix = try upgradeNonceAccount(allocator, nonce);
    defer ix.deinit(allocator);

    // Verify instruction index (12 = UpgradeNonceAccount)
    try std.testing.expectEqual(@as(u8, 12), ix.data[0]);

    // Verify accounts (nonce only)
    try std.testing.expectEqual(@as(usize, 1), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_writable);
}
