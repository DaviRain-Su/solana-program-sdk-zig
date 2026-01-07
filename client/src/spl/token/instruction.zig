//! SPL Token instruction builders (Client)
//!
//! Rust source: https://github.com/solana-program/token/blob/master/interface/src/instruction.rs
//!
//! This module provides instruction builders for the SPL Token program (25 instructions).
//! Types (TokenInstruction, AuthorityType) are imported from the SDK.
//!
//! ## Instructions
//! - InitializeMint, InitializeMint2 - Create new token mints
//! - InitializeAccount, InitializeAccount2, InitializeAccount3 - Create token accounts
//! - InitializeMultisig, InitializeMultisig2 - Create multisig accounts
//! - Transfer, TransferChecked - Transfer tokens
//! - Approve, ApproveChecked - Delegate tokens
//! - Revoke - Remove delegation
//! - SetAuthority - Change authorities
//! - MintTo, MintToChecked - Mint new tokens
//! - Burn, BurnChecked - Burn tokens
//! - CloseAccount - Close token account
//! - FreezeAccount, ThawAccount - Freeze/thaw accounts
//! - SyncNative - Sync native SOL balance
//! - GetAccountDataSize, InitializeImmutableOwner, AmountToUiAmount, UiAmountToAmount

const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;
const AccountMeta = sdk.AccountMeta;

// Re-export types from SDK
const sdk_token = sdk.spl.token;
pub const TokenInstruction = sdk_token.TokenInstruction;
pub const AuthorityType = sdk_token.AuthorityType;
pub const TOKEN_PROGRAM_ID = sdk_token.TOKEN_PROGRAM_ID;
pub const MAX_SIGNERS = sdk_token.MAX_SIGNERS;

// ============================================================================
// Instruction Building Types
// ============================================================================

/// A Token program instruction.
///
/// This struct holds all the data needed to create a Solana instruction
/// for the SPL Token program.
pub const Instruction = struct {
    program_id: PublicKey,
    accounts: []const AccountMeta,
    data: []const u8,
};

// ============================================================================
// Instruction Data Buffers (Stack-allocated)
// ============================================================================

/// Maximum size of instruction data for token instructions
const MAX_INSTRUCTION_DATA_SIZE: usize = 67; // InitializeMint with freeze_authority

/// Instruction data buffer for stack allocation
pub const InstructionDataBuffer = struct {
    data: [MAX_INSTRUCTION_DATA_SIZE]u8,
    len: usize,

    pub fn slice(self: *const InstructionDataBuffer) []const u8 {
        return self.data[0..self.len];
    }
};

// ============================================================================
// Helper Functions
// ============================================================================

fn writeU64LE(buffer: []u8, value: u64) void {
    std.mem.writeInt(u64, buffer[0..8], value, .little);
}

// ============================================================================
// InitializeMint (ID=0)
// ============================================================================

/// Data for InitializeMint instruction.
pub const InitializeMintData = struct {
    /// Number of decimals in token amounts
    decimals: u8,
    /// The authority/multisig to mint tokens
    mint_authority: PublicKey,
    /// Optional freeze authority
    freeze_authority: ?PublicKey,

    /// Serialize to bytes
    pub fn serialize(self: InitializeMintData, buffer: *[67]u8) usize {
        buffer[0] = @intFromEnum(TokenInstruction.InitializeMint);
        buffer[1] = self.decimals;
        @memcpy(buffer[2..34], &self.mint_authority.bytes);

        if (self.freeze_authority) |fa| {
            buffer[34] = 1; // Some
            @memcpy(buffer[35..67], &fa.bytes);
            return 67;
        } else {
            buffer[34] = 0; // None
            return 35;
        }
    }
};

/// Creates an InitializeMint instruction.
///
/// Accounts:
/// 0. `[writable]` The mint to initialize
/// 1. `[]` Rent sysvar
pub fn initializeMint(
    mint: PublicKey,
    mint_authority: PublicKey,
    freeze_authority: ?PublicKey,
    decimals: u8,
) struct { accounts: [2]AccountMeta, data: [67]u8, data_len: usize } {
    const data_struct = InitializeMintData{
        .decimals = decimals,
        .mint_authority = mint_authority,
        .freeze_authority = freeze_authority,
    };

    var data: [67]u8 = undefined;
    const data_len = data_struct.serialize(&data);

    return .{
        .accounts = .{
            AccountMeta.newWritable(mint),
            AccountMeta.newReadonly(RENT_SYSVAR),
        },
        .data = data,
        .data_len = data_len,
    };
}

/// Creates an InitializeMint2 instruction (no rent sysvar required).
///
/// Accounts:
/// 0. `[writable]` The mint to initialize
pub fn initializeMint2(
    mint: PublicKey,
    mint_authority: PublicKey,
    freeze_authority: ?PublicKey,
    decimals: u8,
) struct { accounts: [1]AccountMeta, data: [67]u8, data_len: usize } {
    var data: [67]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.InitializeMint2);
    data[1] = decimals;
    @memcpy(data[2..34], &mint_authority.bytes);

    var data_len: usize = 35;
    if (freeze_authority) |fa| {
        data[34] = 1;
        @memcpy(data[35..67], &fa.bytes);
        data_len = 67;
    } else {
        data[34] = 0;
    }

    return .{
        .accounts = .{
            AccountMeta.newWritable(mint),
        },
        .data = data,
        .data_len = data_len,
    };
}

// ============================================================================
// InitializeAccount (ID=1)
// ============================================================================

/// Creates an InitializeAccount instruction.
///
/// Accounts:
/// 0. `[writable]` The account to initialize
/// 1. `[]` The mint
/// 2. `[]` The owner
/// 3. `[]` Rent sysvar
pub fn initializeAccount(
    account: PublicKey,
    mint: PublicKey,
    owner: PublicKey,
) struct { accounts: [4]AccountMeta, data: [1]u8 } {
    return .{
        .accounts = .{
            AccountMeta.newWritable(account),
            AccountMeta.newReadonly(mint),
            AccountMeta.newReadonly(owner),
            AccountMeta.newReadonly(RENT_SYSVAR),
        },
        .data = .{@intFromEnum(TokenInstruction.InitializeAccount)},
    };
}

/// Creates an InitializeAccount2 instruction.
///
/// Accounts:
/// 0. `[writable]` The account to initialize
/// 1. `[]` The mint
/// 2. `[]` Rent sysvar
pub fn initializeAccount2(
    account: PublicKey,
    mint: PublicKey,
    owner: PublicKey,
) struct { accounts: [3]AccountMeta, data: [33]u8 } {
    var data: [33]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.InitializeAccount2);
    @memcpy(data[1..33], &owner.bytes);

    return .{
        .accounts = .{
            AccountMeta.newWritable(account),
            AccountMeta.newReadonly(mint),
            AccountMeta.newReadonly(RENT_SYSVAR),
        },
        .data = data,
    };
}

/// Creates an InitializeAccount3 instruction (no rent sysvar required).
///
/// Accounts:
/// 0. `[writable]` The account to initialize
/// 1. `[]` The mint
pub fn initializeAccount3(
    account: PublicKey,
    mint: PublicKey,
    owner: PublicKey,
) struct { accounts: [2]AccountMeta, data: [33]u8 } {
    var data: [33]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.InitializeAccount3);
    @memcpy(data[1..33], &owner.bytes);

    return .{
        .accounts = .{
            AccountMeta.newWritable(account),
            AccountMeta.newReadonly(mint),
        },
        .data = data,
    };
}

// ============================================================================
// InitializeMultisig (ID=2)
// ============================================================================

/// Creates an InitializeMultisig instruction.
///
/// Accounts:
/// 0. `[writable]` The multisig account
/// 1. `[]` Rent sysvar
/// 2..2+N `[]` The signer accounts
pub fn initializeMultisig(
    multisig: PublicKey,
    signers: []const PublicKey,
    m: u8,
) struct { accounts: [13]AccountMeta, num_accounts: usize, data: [2]u8 } {
    var accounts: [13]AccountMeta = undefined; // 2 + MAX_SIGNERS
    accounts[0] = AccountMeta.newWritable(multisig);
    accounts[1] = AccountMeta.newReadonly(RENT_SYSVAR);

    const num_signers = @min(signers.len, state.MAX_SIGNERS);
    for (signers[0..num_signers], 0..) |signer, i| {
        accounts[2 + i] = AccountMeta.newReadonly(signer);
    }

    return .{
        .accounts = accounts,
        .num_accounts = 2 + num_signers,
        .data = .{
            @intFromEnum(TokenInstruction.InitializeMultisig),
            m,
        },
    };
}

/// Creates an InitializeMultisig2 instruction (no rent sysvar).
///
/// Accounts:
/// 0. `[writable]` The multisig account
/// 1..1+N `[]` The signer accounts
pub fn initializeMultisig2(
    multisig: PublicKey,
    signers: []const PublicKey,
    m: u8,
) struct { accounts: [12]AccountMeta, num_accounts: usize, data: [2]u8 } {
    var accounts: [12]AccountMeta = undefined; // 1 + MAX_SIGNERS
    accounts[0] = AccountMeta.newWritable(multisig);

    const num_signers = @min(signers.len, MAX_SIGNERS);
    for (signers[0..num_signers], 0..) |signer, i| {
        accounts[1 + i] = AccountMeta.newReadonly(signer);
    }

    return .{
        .accounts = accounts,
        .num_accounts = 1 + num_signers,
        .data = .{
            @intFromEnum(TokenInstruction.InitializeMultisig2),
            m,
        },
    };
}

// ============================================================================
// Transfer (ID=3)
// ============================================================================

/// Creates a Transfer instruction.
///
/// Accounts:
/// 0. `[writable]` Source account
/// 1. `[writable]` Destination account
/// 2. `[signer]` Source account owner/delegate
pub fn transfer(
    source: PublicKey,
    destination: PublicKey,
    owner: PublicKey,
    amount: u64,
) struct { accounts: [3]AccountMeta, data: [9]u8 } {
    var data: [9]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.Transfer);
    writeU64LE(data[1..9], amount);

    return .{
        .accounts = .{
            AccountMeta.newWritable(source),
            AccountMeta.newWritable(destination),
            AccountMeta.newReadonlySigner(owner),
        },
        .data = data,
    };
}

/// Creates a Transfer instruction with multisig.
///
/// Accounts:
/// 0. `[writable]` Source account
/// 1. `[writable]` Destination account
/// 2. `[]` Source account owner (multisig)
/// 3..3+M `[signer]` Signers
pub fn transferMultisig(
    source: PublicKey,
    destination: PublicKey,
    owner: PublicKey,
    signers: []const PublicKey,
    amount: u64,
) struct { accounts: [14]AccountMeta, num_accounts: usize, data: [9]u8 } {
    var accounts: [14]AccountMeta = undefined;
    accounts[0] = AccountMeta.newWritable(source);
    accounts[1] = AccountMeta.newWritable(destination);
    accounts[2] = AccountMeta.newReadonly(owner);

    const num_signers = @min(signers.len, MAX_SIGNERS);
    for (signers[0..num_signers], 0..) |signer, i| {
        accounts[3 + i] = AccountMeta.newReadonlySigner(signer);
    }

    var data: [9]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.Transfer);
    writeU64LE(data[1..9], amount);

    return .{
        .accounts = accounts,
        .num_accounts = 3 + num_signers,
        .data = data,
    };
}

// ============================================================================
// TransferChecked (ID=12)
// ============================================================================

/// Creates a TransferChecked instruction.
///
/// Accounts:
/// 0. `[writable]` Source account
/// 1. `[]` Token mint
/// 2. `[writable]` Destination account
/// 3. `[signer]` Source account owner/delegate
pub fn transferChecked(
    source: PublicKey,
    mint: PublicKey,
    destination: PublicKey,
    owner: PublicKey,
    amount: u64,
    decimals: u8,
) struct { accounts: [4]AccountMeta, data: [10]u8 } {
    var data: [10]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.TransferChecked);
    writeU64LE(data[1..9], amount);
    data[9] = decimals;

    return .{
        .accounts = .{
            AccountMeta.newWritable(source),
            AccountMeta.newReadonly(mint),
            AccountMeta.newWritable(destination),
            AccountMeta.newReadonlySigner(owner),
        },
        .data = data,
    };
}

// ============================================================================
// Approve (ID=4)
// ============================================================================

/// Creates an Approve instruction.
///
/// Accounts:
/// 0. `[writable]` Source account
/// 1. `[]` Delegate
/// 2. `[signer]` Source account owner
pub fn approve(
    source: PublicKey,
    delegate: PublicKey,
    owner: PublicKey,
    amount: u64,
) struct { accounts: [3]AccountMeta, data: [9]u8 } {
    var data: [9]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.Approve);
    writeU64LE(data[1..9], amount);

    return .{
        .accounts = .{
            AccountMeta.newWritable(source),
            AccountMeta.newReadonly(delegate),
            AccountMeta.newReadonlySigner(owner),
        },
        .data = data,
    };
}

/// Creates an ApproveChecked instruction.
///
/// Accounts:
/// 0. `[writable]` Source account
/// 1. `[]` Token mint
/// 2. `[]` Delegate
/// 3. `[signer]` Source account owner
pub fn approveChecked(
    source: PublicKey,
    mint: PublicKey,
    delegate: PublicKey,
    owner: PublicKey,
    amount: u64,
    decimals: u8,
) struct { accounts: [4]AccountMeta, data: [10]u8 } {
    var data: [10]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.ApproveChecked);
    writeU64LE(data[1..9], amount);
    data[9] = decimals;

    return .{
        .accounts = .{
            AccountMeta.newWritable(source),
            AccountMeta.newReadonly(mint),
            AccountMeta.newReadonly(delegate),
            AccountMeta.newReadonlySigner(owner),
        },
        .data = data,
    };
}

// ============================================================================
// Revoke (ID=5)
// ============================================================================

/// Creates a Revoke instruction.
///
/// Accounts:
/// 0. `[writable]` Source account
/// 1. `[signer]` Source account owner
pub fn revoke(
    source: PublicKey,
    owner: PublicKey,
) struct { accounts: [2]AccountMeta, data: [1]u8 } {
    return .{
        .accounts = .{
            AccountMeta.newWritable(source),
            AccountMeta.newReadonlySigner(owner),
        },
        .data = .{@intFromEnum(TokenInstruction.Revoke)},
    };
}

// ============================================================================
// SetAuthority (ID=6)
// ============================================================================

/// Creates a SetAuthority instruction.
///
/// Accounts:
/// 0. `[writable]` The mint or account
/// 1. `[signer]` Current authority
pub fn setAuthority(
    account_or_mint: PublicKey,
    current_authority: PublicKey,
    authority_type: AuthorityType,
    new_authority: ?PublicKey,
) struct { accounts: [2]AccountMeta, data: [35]u8, data_len: usize } {
    var data: [35]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.SetAuthority);
    data[1] = @intFromEnum(authority_type);

    var data_len: usize = 3;
    if (new_authority) |na| {
        data[2] = 1; // Some
        @memcpy(data[3..35], &na.bytes);
        data_len = 35;
    } else {
        data[2] = 0; // None
    }

    return .{
        .accounts = .{
            AccountMeta.newWritable(account_or_mint),
            AccountMeta.newReadonlySigner(current_authority),
        },
        .data = data,
        .data_len = data_len,
    };
}

// ============================================================================
// MintTo (ID=7)
// ============================================================================

/// Creates a MintTo instruction.
///
/// Accounts:
/// 0. `[writable]` The mint
/// 1. `[writable]` The account to mint to
/// 2. `[signer]` The mint authority
pub fn mintTo(
    mint: PublicKey,
    destination: PublicKey,
    mint_authority: PublicKey,
    amount: u64,
) struct { accounts: [3]AccountMeta, data: [9]u8 } {
    var data: [9]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.MintTo);
    writeU64LE(data[1..9], amount);

    return .{
        .accounts = .{
            AccountMeta.newWritable(mint),
            AccountMeta.newWritable(destination),
            AccountMeta.newReadonlySigner(mint_authority),
        },
        .data = data,
    };
}

/// Creates a MintToChecked instruction.
///
/// Accounts:
/// 0. `[writable]` The mint
/// 1. `[writable]` The account to mint to
/// 2. `[signer]` The mint authority
pub fn mintToChecked(
    mint: PublicKey,
    destination: PublicKey,
    mint_authority: PublicKey,
    amount: u64,
    decimals: u8,
) struct { accounts: [3]AccountMeta, data: [10]u8 } {
    var data: [10]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.MintToChecked);
    writeU64LE(data[1..9], amount);
    data[9] = decimals;

    return .{
        .accounts = .{
            AccountMeta.newWritable(mint),
            AccountMeta.newWritable(destination),
            AccountMeta.newReadonlySigner(mint_authority),
        },
        .data = data,
    };
}

// ============================================================================
// Burn (ID=8)
// ============================================================================

/// Creates a Burn instruction.
///
/// Accounts:
/// 0. `[writable]` The account to burn from
/// 1. `[writable]` The token mint
/// 2. `[signer]` The account owner/delegate
pub fn burn(
    account: PublicKey,
    mint: PublicKey,
    owner: PublicKey,
    amount: u64,
) struct { accounts: [3]AccountMeta, data: [9]u8 } {
    var data: [9]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.Burn);
    writeU64LE(data[1..9], amount);

    return .{
        .accounts = .{
            AccountMeta.newWritable(account),
            AccountMeta.newWritable(mint),
            AccountMeta.newReadonlySigner(owner),
        },
        .data = data,
    };
}

/// Creates a BurnChecked instruction.
///
/// Accounts:
/// 0. `[writable]` The account to burn from
/// 1. `[writable]` The token mint
/// 2. `[signer]` The account owner/delegate
pub fn burnChecked(
    account: PublicKey,
    mint: PublicKey,
    owner: PublicKey,
    amount: u64,
    decimals: u8,
) struct { accounts: [3]AccountMeta, data: [10]u8 } {
    var data: [10]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.BurnChecked);
    writeU64LE(data[1..9], amount);
    data[9] = decimals;

    return .{
        .accounts = .{
            AccountMeta.newWritable(account),
            AccountMeta.newWritable(mint),
            AccountMeta.newReadonlySigner(owner),
        },
        .data = data,
    };
}

// ============================================================================
// CloseAccount (ID=9)
// ============================================================================

/// Creates a CloseAccount instruction.
///
/// Accounts:
/// 0. `[writable]` The account to close
/// 1. `[writable]` The destination account for remaining SOL
/// 2. `[signer]` The account owner
pub fn closeAccount(
    account: PublicKey,
    destination: PublicKey,
    owner: PublicKey,
) struct { accounts: [3]AccountMeta, data: [1]u8 } {
    return .{
        .accounts = .{
            AccountMeta.newWritable(account),
            AccountMeta.newWritable(destination),
            AccountMeta.newReadonlySigner(owner),
        },
        .data = .{@intFromEnum(TokenInstruction.CloseAccount)},
    };
}

// ============================================================================
// FreezeAccount (ID=10)
// ============================================================================

/// Creates a FreezeAccount instruction.
///
/// Accounts:
/// 0. `[writable]` The account to freeze
/// 1. `[]` The token mint
/// 2. `[signer]` The mint freeze authority
pub fn freezeAccount(
    account: PublicKey,
    mint: PublicKey,
    freeze_authority: PublicKey,
) struct { accounts: [3]AccountMeta, data: [1]u8 } {
    return .{
        .accounts = .{
            AccountMeta.newWritable(account),
            AccountMeta.newReadonly(mint),
            AccountMeta.newReadonlySigner(freeze_authority),
        },
        .data = .{@intFromEnum(TokenInstruction.FreezeAccount)},
    };
}

// ============================================================================
// ThawAccount (ID=11)
// ============================================================================

/// Creates a ThawAccount instruction.
///
/// Accounts:
/// 0. `[writable]` The account to thaw
/// 1. `[]` The token mint
/// 2. `[signer]` The mint freeze authority
pub fn thawAccount(
    account: PublicKey,
    mint: PublicKey,
    freeze_authority: PublicKey,
) struct { accounts: [3]AccountMeta, data: [1]u8 } {
    return .{
        .accounts = .{
            AccountMeta.newWritable(account),
            AccountMeta.newReadonly(mint),
            AccountMeta.newReadonlySigner(freeze_authority),
        },
        .data = .{@intFromEnum(TokenInstruction.ThawAccount)},
    };
}

// ============================================================================
// SyncNative (ID=17)
// ============================================================================

/// Creates a SyncNative instruction.
///
/// Accounts:
/// 0. `[writable]` The native token account to sync
pub fn syncNative(
    account: PublicKey,
) struct { accounts: [1]AccountMeta, data: [1]u8 } {
    return .{
        .accounts = .{
            AccountMeta.newWritable(account),
        },
        .data = .{@intFromEnum(TokenInstruction.SyncNative)},
    };
}

// ============================================================================
// GetAccountDataSize (ID=21)
// ============================================================================

/// Creates a GetAccountDataSize instruction.
///
/// Accounts:
/// 0. `[]` The mint
pub fn getAccountDataSize(
    mint: PublicKey,
) struct { accounts: [1]AccountMeta, data: [1]u8 } {
    return .{
        .accounts = .{
            AccountMeta.newReadonly(mint),
        },
        .data = .{@intFromEnum(TokenInstruction.GetAccountDataSize)},
    };
}

// ============================================================================
// InitializeImmutableOwner (ID=22)
// ============================================================================

/// Creates an InitializeImmutableOwner instruction.
///
/// Accounts:
/// 0. `[writable]` The account to initialize
pub fn initializeImmutableOwner(
    account: PublicKey,
) struct { accounts: [1]AccountMeta, data: [1]u8 } {
    return .{
        .accounts = .{
            AccountMeta.newWritable(account),
        },
        .data = .{@intFromEnum(TokenInstruction.InitializeImmutableOwner)},
    };
}

// ============================================================================
// AmountToUiAmount (ID=23)
// ============================================================================

/// Creates an AmountToUiAmount instruction.
///
/// Accounts:
/// 0. `[]` The mint
pub fn amountToUiAmount(
    mint: PublicKey,
    amount: u64,
) struct { accounts: [1]AccountMeta, data: [9]u8 } {
    var data: [9]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.AmountToUiAmount);
    writeU64LE(data[1..9], amount);

    return .{
        .accounts = .{
            AccountMeta.newReadonly(mint),
        },
        .data = data,
    };
}

// ============================================================================
// UiAmountToAmount (ID=24)
// ============================================================================

/// Creates a UiAmountToAmount instruction.
///
/// Accounts:
/// 0. `[]` The mint
///
/// Note: ui_amount is passed as a string in the actual instruction.
/// This simplified version accepts a pre-encoded string.
pub fn uiAmountToAmount(
    mint: PublicKey,
    ui_amount_str: []const u8,
) struct { accounts: [1]AccountMeta, data: [128]u8, data_len: usize } {
    var data: [128]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.UiAmountToAmount);

    const str_len = @min(ui_amount_str.len, 127);
    @memcpy(data[1..][0..str_len], ui_amount_str[0..str_len]);

    return .{
        .accounts = .{
            AccountMeta.newReadonly(mint),
        },
        .data = data,
        .data_len = 1 + str_len,
    };
}

// ============================================================================
// System Program IDs
// ============================================================================

/// Rent sysvar program ID
pub const RENT_SYSVAR = PublicKey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");

// ============================================================================
// Tests
// ============================================================================

test "TokenInstruction: enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(TokenInstruction.InitializeMint));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(TokenInstruction.InitializeAccount));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(TokenInstruction.InitializeMultisig));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(TokenInstruction.Transfer));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(TokenInstruction.Approve));
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(TokenInstruction.Revoke));
    try std.testing.expectEqual(@as(u8, 6), @intFromEnum(TokenInstruction.SetAuthority));
    try std.testing.expectEqual(@as(u8, 7), @intFromEnum(TokenInstruction.MintTo));
    try std.testing.expectEqual(@as(u8, 8), @intFromEnum(TokenInstruction.Burn));
    try std.testing.expectEqual(@as(u8, 9), @intFromEnum(TokenInstruction.CloseAccount));
    try std.testing.expectEqual(@as(u8, 10), @intFromEnum(TokenInstruction.FreezeAccount));
    try std.testing.expectEqual(@as(u8, 11), @intFromEnum(TokenInstruction.ThawAccount));
    try std.testing.expectEqual(@as(u8, 12), @intFromEnum(TokenInstruction.TransferChecked));
    try std.testing.expectEqual(@as(u8, 13), @intFromEnum(TokenInstruction.ApproveChecked));
    try std.testing.expectEqual(@as(u8, 14), @intFromEnum(TokenInstruction.MintToChecked));
    try std.testing.expectEqual(@as(u8, 15), @intFromEnum(TokenInstruction.BurnChecked));
    try std.testing.expectEqual(@as(u8, 16), @intFromEnum(TokenInstruction.InitializeAccount2));
    try std.testing.expectEqual(@as(u8, 17), @intFromEnum(TokenInstruction.SyncNative));
    try std.testing.expectEqual(@as(u8, 18), @intFromEnum(TokenInstruction.InitializeAccount3));
    try std.testing.expectEqual(@as(u8, 19), @intFromEnum(TokenInstruction.InitializeMultisig2));
    try std.testing.expectEqual(@as(u8, 20), @intFromEnum(TokenInstruction.InitializeMint2));
    try std.testing.expectEqual(@as(u8, 21), @intFromEnum(TokenInstruction.GetAccountDataSize));
    try std.testing.expectEqual(@as(u8, 22), @intFromEnum(TokenInstruction.InitializeImmutableOwner));
    try std.testing.expectEqual(@as(u8, 23), @intFromEnum(TokenInstruction.AmountToUiAmount));
    try std.testing.expectEqual(@as(u8, 24), @intFromEnum(TokenInstruction.UiAmountToAmount));
}

test "AuthorityType: enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AuthorityType.MintTokens));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(AuthorityType.FreezeAccount));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(AuthorityType.AccountOwner));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(AuthorityType.CloseAccount));
}

test "transfer: instruction data format" {
    const source = PublicKey.from([_]u8{1} ** 32);
    const dest = PublicKey.from([_]u8{2} ** 32);
    const owner = PublicKey.from([_]u8{3} ** 32);

    const ix = transfer(source, dest, owner, 1_000_000);

    // Check instruction type
    try std.testing.expectEqual(@as(u8, 3), ix.data[0]);

    // Check amount (little-endian)
    const amount = std.mem.readInt(u64, ix.data[1..9], .little);
    try std.testing.expectEqual(@as(u64, 1_000_000), amount);

    // Check accounts
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expectEqual(source, ix.accounts[0].pubkey);
    try std.testing.expect(ix.accounts[0].is_writable);
    try std.testing.expect(!ix.accounts[0].is_signer);

    try std.testing.expectEqual(dest, ix.accounts[1].pubkey);
    try std.testing.expect(ix.accounts[1].is_writable);

    try std.testing.expectEqual(owner, ix.accounts[2].pubkey);
    try std.testing.expect(ix.accounts[2].is_signer);
}

test "transferChecked: instruction data format" {
    const source = PublicKey.from([_]u8{1} ** 32);
    const mint = PublicKey.from([_]u8{2} ** 32);
    const dest = PublicKey.from([_]u8{3} ** 32);
    const owner = PublicKey.from([_]u8{4} ** 32);

    const ix = transferChecked(source, mint, dest, owner, 1_000_000, 9);

    // Check instruction type
    try std.testing.expectEqual(@as(u8, 12), ix.data[0]);

    // Check amount
    const amount = std.mem.readInt(u64, ix.data[1..9], .little);
    try std.testing.expectEqual(@as(u64, 1_000_000), amount);

    // Check decimals
    try std.testing.expectEqual(@as(u8, 9), ix.data[9]);

    // Check accounts
    try std.testing.expectEqual(@as(usize, 4), ix.accounts.len);
}

test "initializeMint: with freeze authority" {
    const mint = PublicKey.from([_]u8{1} ** 32);
    const mint_authority = PublicKey.from([_]u8{2} ** 32);
    const freeze_authority = PublicKey.from([_]u8{3} ** 32);

    const ix = initializeMint(mint, mint_authority, freeze_authority, 9);

    // Check instruction type
    try std.testing.expectEqual(@as(u8, 0), ix.data[0]);

    // Check decimals
    try std.testing.expectEqual(@as(u8, 9), ix.data[1]);

    // Check mint authority
    try std.testing.expectEqualSlices(u8, &mint_authority.bytes, ix.data[2..34]);

    // Check freeze authority option (1 = Some)
    try std.testing.expectEqual(@as(u8, 1), ix.data[34]);

    // Check freeze authority value
    try std.testing.expectEqualSlices(u8, &freeze_authority.bytes, ix.data[35..67]);

    // Check data length
    try std.testing.expectEqual(@as(usize, 67), ix.data_len);
}

test "initializeMint: without freeze authority" {
    const mint = PublicKey.from([_]u8{1} ** 32);
    const mint_authority = PublicKey.from([_]u8{2} ** 32);

    const ix = initializeMint(mint, mint_authority, null, 6);

    // Check instruction type
    try std.testing.expectEqual(@as(u8, 0), ix.data[0]);

    // Check decimals
    try std.testing.expectEqual(@as(u8, 6), ix.data[1]);

    // Check freeze authority option (0 = None)
    try std.testing.expectEqual(@as(u8, 0), ix.data[34]);

    // Check data length
    try std.testing.expectEqual(@as(usize, 35), ix.data_len);
}

test "setAuthority: with new authority" {
    const account = PublicKey.from([_]u8{1} ** 32);
    const current_authority = PublicKey.from([_]u8{2} ** 32);
    const new_authority = PublicKey.from([_]u8{3} ** 32);

    const ix = setAuthority(account, current_authority, .MintTokens, new_authority);

    try std.testing.expectEqual(@as(u8, 6), ix.data[0]); // SetAuthority
    try std.testing.expectEqual(@as(u8, 0), ix.data[1]); // MintTokens
    try std.testing.expectEqual(@as(u8, 1), ix.data[2]); // Some
    try std.testing.expectEqual(@as(usize, 35), ix.data_len);
}

test "setAuthority: remove authority" {
    const account = PublicKey.from([_]u8{1} ** 32);
    const current_authority = PublicKey.from([_]u8{2} ** 32);

    const ix = setAuthority(account, current_authority, .FreezeAccount, null);

    try std.testing.expectEqual(@as(u8, 6), ix.data[0]); // SetAuthority
    try std.testing.expectEqual(@as(u8, 1), ix.data[1]); // FreezeAccount
    try std.testing.expectEqual(@as(u8, 0), ix.data[2]); // None
    try std.testing.expectEqual(@as(usize, 3), ix.data_len);
}

test "mintTo: instruction data format" {
    const mint = PublicKey.from([_]u8{1} ** 32);
    const dest = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);

    const ix = mintTo(mint, dest, authority, 5_000_000);

    try std.testing.expectEqual(@as(u8, 7), ix.data[0]);
    const amount = std.mem.readInt(u64, ix.data[1..9], .little);
    try std.testing.expectEqual(@as(u64, 5_000_000), amount);
}

test "burn: instruction data format" {
    const account = PublicKey.from([_]u8{1} ** 32);
    const mint = PublicKey.from([_]u8{2} ** 32);
    const owner = PublicKey.from([_]u8{3} ** 32);

    const ix = burn(account, mint, owner, 100_000);

    try std.testing.expectEqual(@as(u8, 8), ix.data[0]);
    const amount = std.mem.readInt(u64, ix.data[1..9], .little);
    try std.testing.expectEqual(@as(u64, 100_000), amount);
}

test "closeAccount: instruction format" {
    const account = PublicKey.from([_]u8{1} ** 32);
    const dest = PublicKey.from([_]u8{2} ** 32);
    const owner = PublicKey.from([_]u8{3} ** 32);

    const ix = closeAccount(account, dest, owner);

    try std.testing.expectEqual(@as(u8, 9), ix.data[0]);
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
}

test "freezeAccount: instruction format" {
    const account = PublicKey.from([_]u8{1} ** 32);
    const mint = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);

    const ix = freezeAccount(account, mint, authority);

    try std.testing.expectEqual(@as(u8, 10), ix.data[0]);
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
}

test "thawAccount: instruction format" {
    const account = PublicKey.from([_]u8{1} ** 32);
    const mint = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);

    const ix = thawAccount(account, mint, authority);

    try std.testing.expectEqual(@as(u8, 11), ix.data[0]);
}

test "syncNative: instruction format" {
    const account = PublicKey.from([_]u8{1} ** 32);

    const ix = syncNative(account);

    try std.testing.expectEqual(@as(u8, 17), ix.data[0]);
    try std.testing.expectEqual(@as(usize, 1), ix.accounts.len);
}

test "approve: instruction format" {
    const source = PublicKey.from([_]u8{1} ** 32);
    const delegate = PublicKey.from([_]u8{2} ** 32);
    const owner = PublicKey.from([_]u8{3} ** 32);

    const ix = approve(source, delegate, owner, 500_000);

    try std.testing.expectEqual(@as(u8, 4), ix.data[0]);
    const amount = std.mem.readInt(u64, ix.data[1..9], .little);
    try std.testing.expectEqual(@as(u64, 500_000), amount);
}

test "revoke: instruction format" {
    const source = PublicKey.from([_]u8{1} ** 32);
    const owner = PublicKey.from([_]u8{2} ** 32);

    const ix = revoke(source, owner);

    try std.testing.expectEqual(@as(u8, 5), ix.data[0]);
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
}

test "initializeAccount3: instruction format" {
    const account = PublicKey.from([_]u8{1} ** 32);
    const mint = PublicKey.from([_]u8{2} ** 32);
    const owner = PublicKey.from([_]u8{3} ** 32);

    const ix = initializeAccount3(account, mint, owner);

    try std.testing.expectEqual(@as(u8, 18), ix.data[0]);
    try std.testing.expectEqualSlices(u8, &owner.bytes, ix.data[1..33]);
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
}
