//! Solana SDK - Shared Core Types
//!
//! This module provides the core types used by both on-chain programs and off-chain clients.
//! It contains no syscall dependencies and can be used in any environment.
//!
//! ## Modules
//!
//! ### Core Types
//! - `public_key` - PublicKey type and PDA derivation
//! - `hash` - SHA-256 hash type
//! - `signature` - Ed25519 signature type
//! - `keypair` - Ed25519 key pair management
//!
//! ### Instruction Types
//! - `instruction` - Instruction and AccountMeta types
//!
//! ### Serialization
//! - `bincode` - Bincode serialization
//! - `borsh` - Borsh serialization
//! - `short_vec` - Short vector encoding
//!
//! ### Other
//! - `error` - ProgramError type
//! - `native_token` - SOL token constants
//! - `nonce` - Durable nonce types

const std = @import("std");

// ============================================================================
// Core Types
// ============================================================================

pub const public_key = @import("public_key.zig");
pub const PublicKey = public_key.PublicKey;
pub const ProgramDerivedAddress = public_key.ProgramDerivedAddress;

pub const hash = @import("hash.zig");
pub const Hash = hash.Hash;

pub const signature = @import("signature.zig");
pub const Signature = signature.Signature;
pub const SIGNATURE_BYTES = signature.SIGNATURE_BYTES;

pub const keypair = @import("keypair.zig");
pub const Keypair = keypair.Keypair;

// ============================================================================
// Instruction Types
// ============================================================================

pub const instruction = @import("instruction.zig");
pub const AccountMeta = instruction.AccountMeta;
pub const CompiledInstruction = instruction.CompiledInstruction;
pub const InstructionData = instruction.InstructionData;
pub const ReturnData = instruction.ReturnData;
pub const ProcessedSiblingInstruction = instruction.ProcessedSiblingInstruction;
pub const TRANSACTION_LEVEL_STACK_HEIGHT = instruction.TRANSACTION_LEVEL_STACK_HEIGHT;
pub const MAX_RETURN_DATA = instruction.MAX_RETURN_DATA;

// ============================================================================
// Serialization
// ============================================================================

pub const bincode = @import("bincode.zig");
pub const borsh = @import("borsh.zig");
pub const short_vec = @import("short_vec.zig");

// ============================================================================
// Error Types
// ============================================================================

pub const @"error" = @import("error.zig");
pub const ProgramError = @"error".ProgramError;

pub const instruction_error = @import("instruction_error.zig");
pub const InstructionError = instruction_error.InstructionError;
pub const LamportsError = instruction_error.LamportsError;

pub const transaction_error = @import("transaction_error.zig");
pub const TransactionError = transaction_error.TransactionError;
pub const AddressLoaderError = transaction_error.AddressLoaderError;
pub const SanitizeMessageError = transaction_error.SanitizeMessageError;

// ============================================================================
// Epoch Info
// ============================================================================

pub const epoch_info = @import("epoch_info.zig");
pub const EpochInfo = epoch_info.EpochInfo;

// ============================================================================
// Native Token
// ============================================================================

pub const native_token = @import("native_token.zig");
pub const LAMPORTS_PER_SOL = native_token.LAMPORTS_PER_SOL;
pub const Sol = native_token.Sol;

// ============================================================================
// Nonce
// ============================================================================

pub const nonce = @import("nonce.zig");
pub const DurableNonce = nonce.DurableNonce;

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all module tests
    std.testing.refAllDecls(@This());
}
