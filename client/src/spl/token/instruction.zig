//! SPL Token program instruction builders (Client)
//!
//! Rust source: https://github.com/solana-program/token/blob/master/interface/src/instruction.rs
//!
//! This module re-exports instruction builders from the SDK.
//! All implementations are in `sdk/src/spl/token/instruction.zig`.

const sdk = @import("solana_sdk");
const sdk_token = sdk.spl.token;

// Re-export types from SDK
pub const TokenInstruction = sdk_token.TokenInstruction;
pub const AuthorityType = sdk_token.AuthorityType;
pub const TOKEN_PROGRAM_ID = sdk_token.TOKEN_PROGRAM_ID;
pub const MAX_SIGNERS = sdk_token.MAX_SIGNERS;
pub const MIN_SIGNERS = sdk_token.MIN_SIGNERS;
pub const RENT_SYSVAR = sdk_token.RENT_SYSVAR;

// Re-export instruction data types
pub const TransferData = sdk_token.TransferData;
pub const TransferCheckedData = sdk_token.TransferCheckedData;
pub const MintToData = sdk_token.MintToData;
pub const MintToCheckedData = sdk_token.MintToCheckedData;
pub const BurnData = sdk_token.BurnData;
pub const BurnCheckedData = sdk_token.BurnCheckedData;
pub const ApproveData = sdk_token.ApproveData;
pub const ApproveCheckedData = sdk_token.ApproveCheckedData;
pub const SetAuthorityData = sdk_token.SetAuthorityData;
pub const InitializeMintData = sdk_token.InitializeMintData;
pub const InitializeMultisigData = sdk_token.InitializeMultisigData;

// Re-export error types
pub const MultisigError = sdk_token.MultisigError;

// Re-export instruction builders
pub const initializeMint = sdk_token.initializeMint;
pub const initializeMint2 = sdk_token.initializeMint2;
pub const initializeAccount = sdk_token.initializeAccount;
pub const initializeAccount2 = sdk_token.initializeAccount2;
pub const initializeAccount3 = sdk_token.initializeAccount3;
pub const initializeMultisig = sdk_token.initializeMultisig;
pub const initializeMultisig2 = sdk_token.initializeMultisig2;
pub const transfer = sdk_token.transfer;
pub const transferMultisig = sdk_token.transferMultisig;
pub const transferChecked = sdk_token.transferChecked;
pub const approve = sdk_token.approve;
pub const approveChecked = sdk_token.approveChecked;
pub const revoke = sdk_token.revoke;
pub const setAuthority = sdk_token.setAuthority;
pub const mintTo = sdk_token.mintTo;
pub const mintToChecked = sdk_token.mintToChecked;
pub const burn = sdk_token.burn;
pub const burnChecked = sdk_token.burnChecked;
pub const closeAccount = sdk_token.closeAccount;
pub const freezeAccount = sdk_token.freezeAccount;
pub const thawAccount = sdk_token.thawAccount;
pub const syncNative = sdk_token.syncNative;
pub const getAccountDataSize = sdk_token.getAccountDataSize;
pub const initializeImmutableOwner = sdk_token.initializeImmutableOwner;
pub const amountToUiAmount = sdk_token.amountToUiAmount;
pub const uiAmountToAmount = sdk_token.uiAmountToAmount;

// Tests are in SDK - this module is just re-exports
