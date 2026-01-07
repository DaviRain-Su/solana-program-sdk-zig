//! Zig implementation of SPL Token instruction types
//!
//! Rust source: https://github.com/solana-program/token/blob/master/interface/src/instruction.rs
//!
//! This module provides instruction type definitions and parsing for the SPL Token program.
//! It includes the TokenInstruction enum with all 25 instruction variants, the AuthorityType
//! enum, and data structures for parsing instruction data.

const std = @import("std");
const PublicKey = @import("../../public_key.zig").PublicKey;

/// Minimum number of multisignature signers (min N)
pub const MIN_SIGNERS: usize = 1;

/// Maximum number of multisignature signers (max N)
pub const MAX_SIGNERS: usize = 11;

/// SPL Token Program ID
pub const TOKEN_PROGRAM_ID = PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");

// ============================================================================
// Token Instruction Enum
// ============================================================================

/// Instructions supported by the token program.
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/instruction.rs#L20
pub const TokenInstruction = enum(u8) {
    /// Initializes a new mint and optionally deposits all the newly minted
    /// tokens in an account.
    ///
    /// The `InitializeMint` instruction requires no signers and MUST be
    /// included within the same Transaction as the system program's
    /// `CreateAccount` instruction that creates the account being initialized.
    /// Otherwise another party can acquire ownership of the uninitialized
    /// account.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The mint to initialize.
    ///   1. `[]` Rent sysvar
    InitializeMint = 0,

    /// Initializes a new account to hold tokens. If this account is associated
    /// with the native mint then the token balance of the initialized account
    /// will be equal to the amount of SOL in the account. If this account is
    /// associated with another mint, that mint must be initialized before this
    /// command can succeed.
    ///
    /// The `InitializeAccount` instruction requires no signers and MUST be
    /// included within the same Transaction as the system program's
    /// `CreateAccount` instruction that creates the account being initialized.
    /// Otherwise another party can acquire ownership of the uninitialized
    /// account.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The account to initialize.
    ///   1. `[]` The mint this account will be associated with.
    ///   2. `[]` The new account's owner/multisignature.
    ///   3. `[]` Rent sysvar
    InitializeAccount = 1,

    /// Initializes a multisignature account with N provided signers.
    ///
    /// Multisignature accounts can used in place of any single owner/delegate
    /// accounts in any token instruction that require an owner/delegate to be
    /// present. The variant field represents the number of signers (M)
    /// required to validate this multisignature account.
    ///
    /// The `InitializeMultisig` instruction requires no signers and MUST be
    /// included within the same Transaction as the system program's
    /// `CreateAccount` instruction that creates the account being initialized.
    /// Otherwise another party can acquire ownership of the uninitialized
    /// account.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The multisignature account to initialize.
    ///   1. `[]` Rent sysvar
    ///   2. ..`2+N`. `[]` The signer accounts, must equal to N where `1 <= N <= 11`.
    InitializeMultisig = 2,

    /// Transfers tokens from one account to another either directly or via a
    /// delegate. If this account is associated with the native mint then equal
    /// amounts of SOL and Tokens will be transferred to the destination
    /// account.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner/delegate
    ///   0. `[writable]` The source account.
    ///   1. `[writable]` The destination account.
    ///   2. `[signer]` The source account's owner/delegate.
    ///
    ///   * Multisignature owner/delegate
    ///   0. `[writable]` The source account.
    ///   1. `[writable]` The destination account.
    ///   2. `[]` The source account's multisignature owner/delegate.
    ///   3. ..`3+M` `[signer]` M signer accounts.
    Transfer = 3,

    /// Approves a delegate. A delegate is given the authority over tokens on
    /// behalf of the source account's owner.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The source account.
    ///   1. `[]` The delegate.
    ///   2. `[signer]` The source account owner.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The source account.
    ///   1. `[]` The delegate.
    ///   2. `[]` The source account's multisignature owner.
    ///   3. ..`3+M` `[signer]` M signer accounts
    Approve = 4,

    /// Revokes the delegate's authority.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The source account.
    ///   1. `[signer]` The source account owner.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The source account.
    ///   1. `[]` The source account's multisignature owner.
    ///   2. ..`2+M` `[signer]` M signer accounts
    Revoke = 5,

    /// Sets a new authority of a mint or account.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single authority
    ///   0. `[writable]` The mint or account to change the authority of.
    ///   1. `[signer]` The current authority of the mint or account.
    ///
    ///   * Multisignature authority
    ///   0. `[writable]` The mint or account to change the authority of.
    ///   1. `[]` The mint's or account's current multisignature authority.
    ///   2. ..`2+M` `[signer]` M signer accounts
    SetAuthority = 6,

    /// Mints new tokens to an account. The native mint does not support
    /// minting.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single authority
    ///   0. `[writable]` The mint.
    ///   1. `[writable]` The account to mint tokens to.
    ///   2. `[signer]` The mint's minting authority.
    ///
    ///   * Multisignature authority
    ///   0. `[writable]` The mint.
    ///   1. `[writable]` The account to mint tokens to.
    ///   2. `[]` The mint's multisignature mint-tokens authority.
    ///   3. ..`3+M` `[signer]` M signer accounts.
    MintTo = 7,

    /// Burns tokens by removing them from an account. `Burn` does not support
    /// accounts associated with the native mint, use `CloseAccount` instead.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner/delegate
    ///   0. `[writable]` The account to burn from.
    ///   1. `[writable]` The token mint.
    ///   2. `[signer]` The account's owner/delegate.
    ///
    ///   * Multisignature owner/delegate
    ///   0. `[writable]` The account to burn from.
    ///   1. `[writable]` The token mint.
    ///   2. `[]` The account's multisignature owner/delegate.
    ///   3. ..`3+M` `[signer]` M signer accounts.
    Burn = 8,

    /// Close an account by transferring all its SOL to the destination account.
    /// Non-native accounts may only be closed if its token amount is zero.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The account to close.
    ///   1. `[writable]` The destination account.
    ///   2. `[signer]` The account's owner.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The account to close.
    ///   1. `[writable]` The destination account.
    ///   2. `[]` The account's multisignature owner.
    ///   3. ..`3+M` `[signer]` M signer accounts.
    CloseAccount = 9,

    /// Freeze an Initialized account using the Mint's `freeze_authority` (if
    /// set).
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The account to freeze.
    ///   1. `[]` The token mint.
    ///   2. `[signer]` The mint freeze authority.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The account to freeze.
    ///   1. `[]` The token mint.
    ///   2. `[]` The mint's multisignature freeze authority.
    ///   3. ..`3+M` `[signer]` M signer accounts.
    FreezeAccount = 10,

    /// Thaw a Frozen account using the Mint's `freeze_authority` (if set).
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The account to freeze.
    ///   1. `[]` The token mint.
    ///   2. `[signer]` The mint freeze authority.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The account to freeze.
    ///   1. `[]` The token mint.
    ///   2. `[]` The mint's multisignature freeze authority.
    ///   3. ..`3+M` `[signer]` M signer accounts.
    ThawAccount = 11,

    /// Transfers tokens from one account to another either directly or via a
    /// delegate. If this account is associated with the native mint then equal
    /// amounts of SOL and Tokens will be transferred to the destination
    /// account.
    ///
    /// This instruction differs from Transfer in that the token mint and
    /// decimals value is checked by the caller. This may be useful when
    /// creating transactions offline or within a hardware wallet.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner/delegate
    ///   0. `[writable]` The source account.
    ///   1. `[]` The token mint.
    ///   2. `[writable]` The destination account.
    ///   3. `[signer]` The source account's owner/delegate.
    ///
    ///   * Multisignature owner/delegate
    ///   0. `[writable]` The source account.
    ///   1. `[]` The token mint.
    ///   2. `[writable]` The destination account.
    ///   3. `[]` The source account's multisignature owner/delegate.
    ///   4. ..`4+M` `[signer]` M signer accounts.
    TransferChecked = 12,

    /// Approves a delegate. A delegate is given the authority over tokens on
    /// behalf of the source account's owner.
    ///
    /// This instruction differs from Approve in that the token mint and
    /// decimals value is checked by the caller. This may be useful when
    /// creating transactions offline or within a hardware wallet.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The source account.
    ///   1. `[]` The token mint.
    ///   2. `[]` The delegate.
    ///   3. `[signer]` The source account owner.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The source account.
    ///   1. `[]` The token mint.
    ///   2. `[]` The delegate.
    ///   3. `[]` The source account's multisignature owner.
    ///   4. ..`4+M` `[signer]` M signer accounts
    ApproveChecked = 13,

    /// Mints new tokens to an account. The native mint does not support
    /// minting.
    ///
    /// This instruction differs from `MintTo` in that the decimals value is
    /// checked by the caller. This may be useful when creating transactions
    /// offline or within a hardware wallet.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single authority
    ///   0. `[writable]` The mint.
    ///   1. `[writable]` The account to mint tokens to.
    ///   2. `[signer]` The mint's minting authority.
    ///
    ///   * Multisignature authority
    ///   0. `[writable]` The mint.
    ///   1. `[writable]` The account to mint tokens to.
    ///   2. `[]` The mint's multisignature mint-tokens authority.
    ///   3. ..`3+M` `[signer]` M signer accounts.
    MintToChecked = 14,

    /// Burns tokens by removing them from an account. `BurnChecked` does not
    /// support accounts associated with the native mint, use `CloseAccount`
    /// instead.
    ///
    /// This instruction differs from Burn in that the decimals value is checked
    /// by the caller. This may be useful when creating transactions offline or
    /// within a hardware wallet.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner/delegate
    ///   0. `[writable]` The account to burn from.
    ///   1. `[writable]` The token mint.
    ///   2. `[signer]` The account's owner/delegate.
    ///
    ///   * Multisignature owner/delegate
    ///   0. `[writable]` The account to burn from.
    ///   1. `[writable]` The token mint.
    ///   2. `[]` The account's multisignature owner/delegate.
    ///   3. ..`3+M` `[signer]` M signer accounts.
    BurnChecked = 15,

    /// Like `InitializeAccount`, but the owner pubkey is passed via
    /// instruction data rather than the accounts list. This variant may be
    /// preferable when using Cross Program Invocation from an instruction
    /// that does not need the owner's `AccountInfo` otherwise.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The account to initialize.
    ///   1. `[]` The mint this account will be associated with.
    ///   2. `[]` Rent sysvar
    InitializeAccount2 = 16,

    /// Given a wrapped / native token account (a token account containing SOL)
    /// updates its amount field based on the account's underlying `lamports`.
    /// This is useful if a non-wrapped SOL account uses
    /// `system_instruction::transfer` to move lamports to a wrapped token
    /// account, and needs to have its token `amount` field updated.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The native token account to sync with its underlying lamports.
    SyncNative = 17,

    /// Like `InitializeAccount2`, but does not require the Rent sysvar to be
    /// provided.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The account to initialize.
    ///   1. `[]` The mint this account will be associated with.
    InitializeAccount3 = 18,

    /// Like `InitializeMultisig`, but does not require the Rent sysvar to be
    /// provided.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The multisignature account to initialize.
    ///   1. ..`1+N` `[]` The signer accounts, must equal to N where `1 <= N <= 11`.
    InitializeMultisig2 = 19,

    /// Like `InitializeMint`, but does not require the Rent sysvar to be
    /// provided.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The mint to initialize.
    InitializeMint2 = 20,

    /// Gets the required size of an account for the given mint as a
    /// little-endian `u64`.
    ///
    /// Return data can be fetched using `sol_get_return_data` and deserializing
    /// the return data as a little-endian `u64`.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[]` The mint to calculate for
    GetAccountDataSize = 21,

    /// Initialize the Immutable Owner extension for the given token account.
    ///
    /// Fails if the account has already been initialized, so must be called
    /// before `InitializeAccount`.
    ///
    /// No-ops in this version of the program, but is included for compatibility
    /// with the Associated Token Account program.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The account to initialize.
    ///
    /// Data expected by this instruction:
    ///   None
    InitializeImmutableOwner = 22,

    /// Convert an Amount of tokens to a `UiAmount` string, using the given
    /// mint. In this version of the program, the mint can only specify the
    /// number of decimals.
    ///
    /// Fails on an invalid mint.
    ///
    /// Return data can be fetched using `sol_get_return_data` and deserialized
    /// with `String::from_utf8`.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[]` The mint to calculate for
    AmountToUiAmount = 23,

    /// Convert a `UiAmount` of tokens to a little-endian `u64` raw Amount,
    /// using the given mint. In this version of the program, the mint can
    /// only specify the number of decimals.
    ///
    /// Return data can be fetched using `sol_get_return_data` and deserializing
    /// the return data as a little-endian `u64`.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[]` The mint to calculate for
    UiAmountToAmount = 24,

    /// Convert from byte to TokenInstruction
    pub fn fromByte(byte: u8) ?TokenInstruction {
        return std.meta.intToEnum(TokenInstruction, byte) catch null;
    }
};

// ============================================================================
// Authority Type Enum
// ============================================================================

/// Specifies the authority type for `SetAuthority` instructions.
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/instruction.rs#L544
pub const AuthorityType = enum(u8) {
    /// Authority to mint new tokens
    MintTokens = 0,
    /// Authority to freeze any account associated with the Mint
    FreezeAccount = 1,
    /// Owner of a given token account
    AccountOwner = 2,
    /// Authority to close a token account
    CloseAccount = 3,

    /// Convert from byte to AuthorityType
    pub fn fromByte(byte: u8) ?AuthorityType {
        return std.meta.intToEnum(AuthorityType, byte) catch null;
    }
};

// ============================================================================
// Instruction Data Parsing
// ============================================================================

/// Parsed Transfer instruction data
pub const TransferData = struct {
    /// The amount of tokens to transfer
    amount: u64,

    /// Pack Transfer instruction data into bytes
    pub fn pack(self: TransferData, dest: *[9]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.Transfer);
        std.mem.writeInt(u64, dest[1..9], self.amount, .little);
    }

    /// Unpack Transfer instruction data from bytes
    pub fn unpack(data: []const u8) !TransferData {
        if (data.len < 9) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.Transfer)) return error.InvalidInstructionData;
        return .{ .amount = std.mem.readInt(u64, data[1..9], .little) };
    }
};

/// Parsed TransferChecked instruction data
pub const TransferCheckedData = struct {
    /// The amount of tokens to transfer
    amount: u64,
    /// Expected number of base 10 digits to the right of the decimal place
    decimals: u8,

    /// Pack TransferChecked instruction data into bytes
    pub fn pack(self: TransferCheckedData, dest: *[10]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.TransferChecked);
        std.mem.writeInt(u64, dest[1..9], self.amount, .little);
        dest[9] = self.decimals;
    }

    /// Unpack TransferChecked instruction data from bytes
    pub fn unpack(data: []const u8) !TransferCheckedData {
        if (data.len < 10) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.TransferChecked)) return error.InvalidInstructionData;
        return .{
            .amount = std.mem.readInt(u64, data[1..9], .little),
            .decimals = data[9],
        };
    }
};

/// Parsed MintTo instruction data
pub const MintToData = struct {
    /// The amount of new tokens to mint
    amount: u64,

    /// Pack MintTo instruction data into bytes
    pub fn pack(self: MintToData, dest: *[9]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.MintTo);
        std.mem.writeInt(u64, dest[1..9], self.amount, .little);
    }

    /// Unpack MintTo instruction data from bytes
    pub fn unpack(data: []const u8) !MintToData {
        if (data.len < 9) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.MintTo)) return error.InvalidInstructionData;
        return .{ .amount = std.mem.readInt(u64, data[1..9], .little) };
    }
};

/// Parsed MintToChecked instruction data
pub const MintToCheckedData = struct {
    /// The amount of new tokens to mint
    amount: u64,
    /// Expected number of base 10 digits to the right of the decimal place
    decimals: u8,

    /// Pack MintToChecked instruction data into bytes
    pub fn pack(self: MintToCheckedData, dest: *[10]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.MintToChecked);
        std.mem.writeInt(u64, dest[1..9], self.amount, .little);
        dest[9] = self.decimals;
    }

    /// Unpack MintToChecked instruction data from bytes
    pub fn unpack(data: []const u8) !MintToCheckedData {
        if (data.len < 10) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.MintToChecked)) return error.InvalidInstructionData;
        return .{
            .amount = std.mem.readInt(u64, data[1..9], .little),
            .decimals = data[9],
        };
    }
};

/// Parsed Burn instruction data
pub const BurnData = struct {
    /// The amount of tokens to burn
    amount: u64,

    /// Pack Burn instruction data into bytes
    pub fn pack(self: BurnData, dest: *[9]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.Burn);
        std.mem.writeInt(u64, dest[1..9], self.amount, .little);
    }

    /// Unpack Burn instruction data from bytes
    pub fn unpack(data: []const u8) !BurnData {
        if (data.len < 9) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.Burn)) return error.InvalidInstructionData;
        return .{ .amount = std.mem.readInt(u64, data[1..9], .little) };
    }
};

/// Parsed BurnChecked instruction data
pub const BurnCheckedData = struct {
    /// The amount of tokens to burn
    amount: u64,
    /// Expected number of base 10 digits to the right of the decimal place
    decimals: u8,

    /// Pack BurnChecked instruction data into bytes
    pub fn pack(self: BurnCheckedData, dest: *[10]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.BurnChecked);
        std.mem.writeInt(u64, dest[1..9], self.amount, .little);
        dest[9] = self.decimals;
    }

    /// Unpack BurnChecked instruction data from bytes
    pub fn unpack(data: []const u8) !BurnCheckedData {
        if (data.len < 10) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.BurnChecked)) return error.InvalidInstructionData;
        return .{
            .amount = std.mem.readInt(u64, data[1..9], .little),
            .decimals = data[9],
        };
    }
};

/// Parsed Approve instruction data
pub const ApproveData = struct {
    /// The amount of tokens the delegate is approved for
    amount: u64,

    /// Pack Approve instruction data into bytes
    pub fn pack(self: ApproveData, dest: *[9]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.Approve);
        std.mem.writeInt(u64, dest[1..9], self.amount, .little);
    }

    /// Unpack Approve instruction data from bytes
    pub fn unpack(data: []const u8) !ApproveData {
        if (data.len < 9) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.Approve)) return error.InvalidInstructionData;
        return .{ .amount = std.mem.readInt(u64, data[1..9], .little) };
    }
};

/// Parsed ApproveChecked instruction data
pub const ApproveCheckedData = struct {
    /// The amount of tokens the delegate is approved for
    amount: u64,
    /// Expected number of base 10 digits to the right of the decimal place
    decimals: u8,

    /// Pack ApproveChecked instruction data into bytes
    pub fn pack(self: ApproveCheckedData, dest: *[10]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.ApproveChecked);
        std.mem.writeInt(u64, dest[1..9], self.amount, .little);
        dest[9] = self.decimals;
    }

    /// Unpack ApproveChecked instruction data from bytes
    pub fn unpack(data: []const u8) !ApproveCheckedData {
        if (data.len < 10) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.ApproveChecked)) return error.InvalidInstructionData;
        return .{
            .amount = std.mem.readInt(u64, data[1..9], .little),
            .decimals = data[9],
        };
    }
};

/// Parsed SetAuthority instruction data
pub const SetAuthorityData = struct {
    /// The type of authority to update
    authority_type: AuthorityType,
    /// The new authority (None to remove authority)
    new_authority: ?PublicKey,

    /// Pack SetAuthority instruction data into bytes (with new authority)
    pub fn packWithAuthority(self: SetAuthorityData, dest: *[35]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.SetAuthority);
        dest[1] = @intFromEnum(self.authority_type);
        if (self.new_authority) |auth| {
            dest[2] = 1; // Some
            @memcpy(dest[3..35], &auth.bytes);
        } else {
            dest[2] = 0; // None
            @memset(dest[3..35], 0);
        }
    }

    /// Pack SetAuthority instruction data into bytes (without new authority)
    pub fn packWithoutAuthority(self: SetAuthorityData, dest: *[3]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.SetAuthority);
        dest[1] = @intFromEnum(self.authority_type);
        dest[2] = 0; // None
    }

    /// Unpack SetAuthority instruction data from bytes
    pub fn unpack(data: []const u8) !SetAuthorityData {
        if (data.len < 3) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.SetAuthority)) return error.InvalidInstructionData;

        const authority_type = AuthorityType.fromByte(data[1]) orelse return error.InvalidInstructionData;
        const new_authority: ?PublicKey = if (data.len >= 35 and data[2] == 1)
            PublicKey.from(data[3..35].*)
        else
            null;

        return .{ .authority_type = authority_type, .new_authority = new_authority };
    }
};

/// Parsed InitializeMint instruction data
pub const InitializeMintData = struct {
    /// Number of base 10 digits to the right of the decimal place
    decimals: u8,
    /// The authority/multisignature to mint tokens
    mint_authority: PublicKey,
    /// The freeze authority/multisignature of the mint (optional)
    freeze_authority: ?PublicKey,

    /// Pack InitializeMint instruction data into bytes (with freeze authority)
    pub fn packWithFreeze(self: InitializeMintData, dest: *[67]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.InitializeMint);
        dest[1] = self.decimals;
        @memcpy(dest[2..34], &self.mint_authority.bytes);
        if (self.freeze_authority) |freeze| {
            dest[34] = 1; // Some
            @memcpy(dest[35..67], &freeze.bytes);
        } else {
            dest[34] = 0; // None
            @memset(dest[35..67], 0);
        }
    }

    /// Pack InitializeMint instruction data into bytes (without freeze authority)
    pub fn packWithoutFreeze(self: InitializeMintData, dest: *[35]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.InitializeMint);
        dest[1] = self.decimals;
        @memcpy(dest[2..34], &self.mint_authority.bytes);
        dest[34] = 0; // None
    }

    /// Unpack InitializeMint instruction data from bytes
    pub fn unpack(data: []const u8) !InitializeMintData {
        if (data.len < 35) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.InitializeMint)) return error.InvalidInstructionData;

        const decimals = data[1];
        const mint_authority = PublicKey.from(data[2..34].*);
        const freeze_authority: ?PublicKey = if (data.len >= 67 and data[34] == 1)
            PublicKey.from(data[35..67].*)
        else
            null;

        return .{
            .decimals = decimals,
            .mint_authority = mint_authority,
            .freeze_authority = freeze_authority,
        };
    }
};

/// Parsed InitializeMultisig instruction data
pub const InitializeMultisigData = struct {
    /// The number of signers (M) required to validate this multisignature account
    m: u8,

    /// Pack InitializeMultisig instruction data into bytes
    pub fn pack(self: InitializeMultisigData, dest: *[2]u8) void {
        dest[0] = @intFromEnum(TokenInstruction.InitializeMultisig);
        dest[1] = self.m;
    }

    /// Unpack InitializeMultisig instruction data from bytes
    pub fn unpack(data: []const u8) !InitializeMultisigData {
        if (data.len < 2) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.InitializeMultisig)) return error.InvalidInstructionData;
        return .{ .m = data[1] };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TokenInstruction: enum values match Rust SDK" {
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

test "AuthorityType: enum values match Rust SDK" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AuthorityType.MintTokens));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(AuthorityType.FreezeAccount));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(AuthorityType.AccountOwner));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(AuthorityType.CloseAccount));
}

test "TransferData: unpack" {
    var data: [9]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.Transfer);
    std.mem.writeInt(u64, data[1..9], 1_000_000, .little);

    const parsed = try TransferData.unpack(&data);
    try std.testing.expectEqual(@as(u64, 1_000_000), parsed.amount);
}

test "TransferCheckedData: unpack" {
    var data: [10]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.TransferChecked);
    std.mem.writeInt(u64, data[1..9], 5_000_000, .little);
    data[9] = 9;

    const parsed = try TransferCheckedData.unpack(&data);
    try std.testing.expectEqual(@as(u64, 5_000_000), parsed.amount);
    try std.testing.expectEqual(@as(u8, 9), parsed.decimals);
}

test "SetAuthorityData: unpack with new authority" {
    var data: [35]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.SetAuthority);
    data[1] = @intFromEnum(AuthorityType.MintTokens);
    data[2] = 1; // Some
    @memset(data[3..35], 0xAB);

    const parsed = try SetAuthorityData.unpack(&data);
    try std.testing.expectEqual(AuthorityType.MintTokens, parsed.authority_type);
    try std.testing.expect(parsed.new_authority != null);
}

test "SetAuthorityData: unpack remove authority" {
    var data: [3]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.SetAuthority);
    data[1] = @intFromEnum(AuthorityType.FreezeAccount);
    data[2] = 0; // None

    const parsed = try SetAuthorityData.unpack(&data);
    try std.testing.expectEqual(AuthorityType.FreezeAccount, parsed.authority_type);
    try std.testing.expect(parsed.new_authority == null);
}

// Rust test: test_instruction_packing
// Source: https://github.com/solana-program/token/blob/master/interface/src/instruction.rs#L1443
test "instruction packing: Transfer pack and unpack roundtrip" {
    const original = TransferData{ .amount = 12345678 };
    var buffer: [9]u8 = undefined;
    original.pack(&buffer);

    // Verify packed bytes
    try std.testing.expectEqual(@as(u8, 3), buffer[0]); // Transfer = 3

    const unpacked = try TransferData.unpack(&buffer);
    try std.testing.expectEqual(original.amount, unpacked.amount);
}

test "instruction packing: TransferChecked pack and unpack roundtrip" {
    const original = TransferCheckedData{ .amount = 1, .decimals = 2 };
    var buffer: [10]u8 = undefined;
    original.pack(&buffer);

    try std.testing.expectEqual(@as(u8, 12), buffer[0]); // TransferChecked = 12

    const unpacked = try TransferCheckedData.unpack(&buffer);
    try std.testing.expectEqual(original.amount, unpacked.amount);
    try std.testing.expectEqual(original.decimals, unpacked.decimals);
}

test "instruction packing: MintTo pack and unpack roundtrip" {
    const original = MintToData{ .amount = 1 };
    var buffer: [9]u8 = undefined;
    original.pack(&buffer);

    try std.testing.expectEqual(@as(u8, 7), buffer[0]); // MintTo = 7

    const unpacked = try MintToData.unpack(&buffer);
    try std.testing.expectEqual(original.amount, unpacked.amount);
}

test "instruction packing: MintToChecked pack and unpack roundtrip" {
    const original = MintToCheckedData{ .amount = 1, .decimals = 2 };
    var buffer: [10]u8 = undefined;
    original.pack(&buffer);

    try std.testing.expectEqual(@as(u8, 14), buffer[0]); // MintToChecked = 14

    const unpacked = try MintToCheckedData.unpack(&buffer);
    try std.testing.expectEqual(original.amount, unpacked.amount);
    try std.testing.expectEqual(original.decimals, unpacked.decimals);
}

test "instruction packing: Burn pack and unpack roundtrip" {
    const original = BurnData{ .amount = 1 };
    var buffer: [9]u8 = undefined;
    original.pack(&buffer);

    try std.testing.expectEqual(@as(u8, 8), buffer[0]); // Burn = 8

    const unpacked = try BurnData.unpack(&buffer);
    try std.testing.expectEqual(original.amount, unpacked.amount);
}

test "instruction packing: BurnChecked pack and unpack roundtrip" {
    const original = BurnCheckedData{ .amount = 1, .decimals = 2 };
    var buffer: [10]u8 = undefined;
    original.pack(&buffer);

    try std.testing.expectEqual(@as(u8, 15), buffer[0]); // BurnChecked = 15

    const unpacked = try BurnCheckedData.unpack(&buffer);
    try std.testing.expectEqual(original.amount, unpacked.amount);
    try std.testing.expectEqual(original.decimals, unpacked.decimals);
}

test "instruction packing: Approve pack and unpack roundtrip" {
    const original = ApproveData{ .amount = 1 };
    var buffer: [9]u8 = undefined;
    original.pack(&buffer);

    try std.testing.expectEqual(@as(u8, 4), buffer[0]); // Approve = 4

    const unpacked = try ApproveData.unpack(&buffer);
    try std.testing.expectEqual(original.amount, unpacked.amount);
}

test "instruction packing: ApproveChecked pack and unpack roundtrip" {
    const original = ApproveCheckedData{ .amount = 1, .decimals = 2 };
    var buffer: [10]u8 = undefined;
    original.pack(&buffer);

    try std.testing.expectEqual(@as(u8, 13), buffer[0]); // ApproveChecked = 13

    const unpacked = try ApproveCheckedData.unpack(&buffer);
    try std.testing.expectEqual(original.amount, unpacked.amount);
    try std.testing.expectEqual(original.decimals, unpacked.decimals);
}

test "instruction packing: InitializeMultisig pack and unpack roundtrip" {
    const original = InitializeMultisigData{ .m = 1 };
    var buffer: [2]u8 = undefined;
    original.pack(&buffer);

    try std.testing.expectEqual(@as(u8, 2), buffer[0]); // InitializeMultisig = 2

    const unpacked = try InitializeMultisigData.unpack(&buffer);
    try std.testing.expectEqual(original.m, unpacked.m);
}

test "instruction packing: SetAuthority with FreezeAccount type" {
    const pubkey = PublicKey.from([_]u8{0xAB} ** 32);
    const original = SetAuthorityData{
        .authority_type = .FreezeAccount,
        .new_authority = pubkey,
    };
    var buffer: [35]u8 = undefined;
    original.packWithAuthority(&buffer);

    try std.testing.expectEqual(@as(u8, 6), buffer[0]); // SetAuthority = 6
    try std.testing.expectEqual(@as(u8, 1), buffer[1]); // FreezeAccount = 1
    try std.testing.expectEqual(@as(u8, 1), buffer[2]); // Some

    const unpacked = try SetAuthorityData.unpack(&buffer);
    try std.testing.expectEqual(original.authority_type, unpacked.authority_type);
    try std.testing.expectEqual(pubkey, unpacked.new_authority.?);
}

test "instruction packing: InitializeMint with freeze authority" {
    const mint_authority = PublicKey.from([_]u8{0x11} ** 32);
    const freeze_authority = PublicKey.from([_]u8{0x22} ** 32);
    const original = InitializeMintData{
        .decimals = 9,
        .mint_authority = mint_authority,
        .freeze_authority = freeze_authority,
    };
    var buffer: [67]u8 = undefined;
    original.packWithFreeze(&buffer);

    try std.testing.expectEqual(@as(u8, 0), buffer[0]); // InitializeMint = 0
    try std.testing.expectEqual(@as(u8, 9), buffer[1]); // decimals
    try std.testing.expectEqual(@as(u8, 1), buffer[34]); // Some

    const unpacked = try InitializeMintData.unpack(&buffer);
    try std.testing.expectEqual(original.decimals, unpacked.decimals);
    try std.testing.expectEqual(mint_authority, unpacked.mint_authority);
    try std.testing.expectEqual(freeze_authority, unpacked.freeze_authority.?);
}

test "instruction packing: InitializeMint without freeze authority" {
    const mint_authority = PublicKey.from([_]u8{0x11} ** 32);
    const original = InitializeMintData{
        .decimals = 6,
        .mint_authority = mint_authority,
        .freeze_authority = null,
    };
    var buffer: [35]u8 = undefined;
    original.packWithoutFreeze(&buffer);

    try std.testing.expectEqual(@as(u8, 0), buffer[0]); // InitializeMint = 0
    try std.testing.expectEqual(@as(u8, 6), buffer[1]); // decimals
    try std.testing.expectEqual(@as(u8, 0), buffer[34]); // None

    const unpacked = try InitializeMintData.unpack(&buffer);
    try std.testing.expectEqual(original.decimals, unpacked.decimals);
    try std.testing.expectEqual(mint_authority, unpacked.mint_authority);
    try std.testing.expect(unpacked.freeze_authority == null);
}

// Rust test: test_instruction_unpack_panic
// Source: https://github.com/solana-program/token/blob/master/interface/src/instruction.rs#L1684
// Fuzz test to ensure unpack never panics on invalid input
test "instruction unpacking: never panics on invalid input" {
    // Test all possible first bytes (instruction tags)
    var i: u16 = 0;
    while (i < 256) : (i += 1) {
        const tag: u8 = @intCast(i);

        // Test with various data lengths (1-10 bytes)
        var len: usize = 1;
        while (len <= 10) : (len += 1) {
            var data: [10]u8 = [_]u8{tag} ++ [_]u8{0} ** 9;

            // These should either succeed or return error, but never panic
            _ = TransferData.unpack(data[0..len]) catch {};
            _ = TransferCheckedData.unpack(data[0..len]) catch {};
            _ = MintToData.unpack(data[0..len]) catch {};
            _ = BurnData.unpack(data[0..len]) catch {};
            _ = ApproveData.unpack(data[0..len]) catch {};
            _ = SetAuthorityData.unpack(data[0..len]) catch {};
            _ = InitializeMintData.unpack(data[0..len]) catch {};
            _ = InitializeMultisigData.unpack(data[0..len]) catch {};
        }
    }
}
