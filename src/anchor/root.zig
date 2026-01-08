//! sol-anchor-zig: Anchor-like framework for Zig
//!
//! This module provides Anchor-compatible patterns for Solana program
//! development in Zig. It uses comptime metaprogramming instead of Rust
//! proc macros to achieve similar ergonomics.
//!
//! ## Overview
//!
//! The anchor module provides:
//! - **Discriminators**: 8-byte sighash identifiers for accounts and instructions
//! - **Account types**: Type-safe wrappers with automatic validation
//! - **Context**: Instruction context with parsed accounts
//! - **Constraints**: Declarative validation (mut, signer, owner, etc.)
//! - **Error codes**: Anchor-compatible error codes for client interop
//!
//! ## Example
//!
//! ```zig
//! const anchor = @import("sol").anchor;
//!
//! // Define account state
//! const CounterData = struct {
//!     count: u64,
//!     authority: PublicKey,
//! };
//!
//! // Create typed account wrapper
//! const Counter = anchor.Account(CounterData, .{
//!     .discriminator = anchor.accountDiscriminator("Counter"),
//! });
//!
//! // Define instruction accounts
//! const IncrementAccounts = struct {
//!     authority: anchor.Signer,
//!     counter: Counter,
//! };
//!
//! // Instruction handler
//! fn increment(ctx: anchor.Context(IncrementAccounts)) !void {
//!     ctx.accounts.counter.data.count += 1;
//! }
//! ```
//!
//! ## Phase 1 Features
//!
//! - Account discriminator generation (SHA256 sighash)
//! - Account(T) wrapper with discriminator validation
//! - Signer/SignerMut account types
//! - Program(ID) account type
//! - Context(Accounts) instruction context
//! - Constraint validation (mut, signer, owner, address)
//! - Anchor-compatible error codes

const std = @import("std");

// ============================================================================
// Discriminator Module
// ============================================================================

/// Discriminator generation using SHA256 sighash
pub const discriminator = @import("discriminator.zig");

/// Length of discriminator in bytes (8)
pub const DISCRIMINATOR_LENGTH = discriminator.DISCRIMINATOR_LENGTH;

/// Discriminator type (8 bytes)
pub const Discriminator = discriminator.Discriminator;

/// Generate account discriminator
///
/// Creates `sha256("account:<name>")[0..8]`
///
/// Example:
/// ```zig
/// const disc = anchor.accountDiscriminator("Counter");
/// ```
pub const accountDiscriminator = discriminator.accountDiscriminator;

/// Generate instruction discriminator
///
/// Creates `sha256("global:<name>")[0..8]`
///
/// Example:
/// ```zig
/// const disc = anchor.instructionDiscriminator("initialize");
/// ```
pub const instructionDiscriminator = discriminator.instructionDiscriminator;

/// Generate custom sighash discriminator
///
/// Creates `sha256("<namespace>:<name>")[0..8]`
pub const sighash = discriminator.sighash;

// ============================================================================
// Error Module
// ============================================================================

/// Anchor error types and codes
pub const error_mod = @import("error.zig");

/// Anchor framework errors (codes 100-3999)
///
/// Compatible with Anchor error codes for client interoperability.
pub const AnchorError = error_mod.AnchorError;

/// Custom error base (6000+)
pub const CUSTOM_ERROR_BASE = error_mod.CUSTOM_ERROR_BASE;

/// Create custom error code
///
/// Example:
/// ```zig
/// const MyError = enum(u32) {
///     InvalidAmount = anchor.customErrorCode(0),  // 6000
///     Unauthorized = anchor.customErrorCode(1),   // 6001
/// };
/// ```
pub const customErrorCode = error_mod.customErrorCode;

// ============================================================================
// Constraints Module
// ============================================================================

/// Constraint types and validation
pub const constraints = @import("constraints.zig");

/// Constraint specification for account validation
///
/// Example:
/// ```zig
/// const my_constraints = anchor.Constraints{
///     .mut = true,
///     .signer = true,
/// };
/// ```
pub const Constraints = constraints.Constraints;

/// Validate constraints against an account
pub const validateConstraints = constraints.validateConstraints;

/// Validate constraints, returning error on failure
pub const validateConstraintsOrError = constraints.validateConstraintsOrError;

/// Constraint validation errors
pub const ConstraintError = constraints.ConstraintError;

// ============================================================================
// Account Module
// ============================================================================

/// Account wrapper with discriminator validation
pub const account = @import("account.zig");

/// Account configuration
pub const AccountConfig = account.AccountConfig;

/// Account wrapper type
///
/// Provides type-safe access to account data with automatic
/// discriminator verification.
///
/// Example:
/// ```zig
/// const Counter = anchor.Account(struct {
///     count: u64,
/// }, .{
///     .discriminator = anchor.accountDiscriminator("Counter"),
/// });
/// ```
pub const Account = account.Account;

/// Account loading errors
pub const AccountError = account.AccountError;

// ============================================================================
// Signer Module
// ============================================================================

/// Signer account types
pub const signer = @import("signer.zig");

/// Signer account type (read-only)
///
/// Validates that an account is a signer of the transaction.
///
/// Example:
/// ```zig
/// const MyAccounts = struct {
///     authority: anchor.Signer,
/// };
/// ```
pub const Signer = signer.Signer;

/// Mutable signer account type
///
/// Validates that an account is both a signer and writable.
/// Use for payer accounts.
///
/// Example:
/// ```zig
/// const MyAccounts = struct {
///     payer: anchor.SignerMut,
/// };
/// ```
pub const SignerMut = signer.SignerMut;

/// Configurable signer type
pub const SignerWith = signer.SignerWith;

/// Signer configuration
pub const SignerConfig = signer.SignerConfig;

/// Signer validation errors
pub const SignerError = signer.SignerError;

// ============================================================================
// Program Module
// ============================================================================

/// Program account types
pub const program = @import("program.zig");

/// Program account with expected ID validation
///
/// Validates that an account is an executable program with the expected ID.
///
/// Example:
/// ```zig
/// const MyAccounts = struct {
///     system_program: anchor.Program(system_program.ID),
/// };
/// ```
pub const Program = program.Program;

/// Unchecked program reference
///
/// Validates executable but not program ID.
pub const UncheckedProgram = program.UncheckedProgram;

/// Program validation errors
pub const ProgramError = program.ProgramError;

// ============================================================================
// Context Module
// ============================================================================

/// Instruction context types
pub const context = @import("context.zig");

/// Instruction context
///
/// Provides access to parsed accounts, program ID, and remaining accounts.
///
/// Example:
/// ```zig
/// fn initialize(ctx: anchor.Context(MyAccounts)) !void {
///     // Access accounts via ctx.accounts
///     // Access program ID via ctx.program_id
/// }
/// ```
pub const Context = context.Context;

/// Bump seeds storage
pub const Bumps = context.Bumps;

/// Load accounts from account info slice
pub const loadAccounts = context.loadAccounts;

/// Parse full context from program inputs
pub const parseContext = context.parseContext;

/// Context loading errors
pub const ContextError = context.ContextError;

// ============================================================================
// Tests
// ============================================================================

test "anchor module exports" {
    // Verify all exports are accessible
    _ = DISCRIMINATOR_LENGTH;
    _ = Discriminator;
    _ = accountDiscriminator;
    _ = instructionDiscriminator;
    _ = AnchorError;
    _ = Constraints;
    _ = Account;
    _ = Signer;
    _ = SignerMut;
    _ = Program;
    _ = Context;
}

test "discriminator submodule" {
    _ = discriminator;
}

test "error submodule" {
    _ = error_mod;
}

test "constraints submodule" {
    _ = constraints;
}

test "account submodule" {
    _ = account;
}

test "signer submodule" {
    _ = signer;
}

test "program submodule" {
    _ = program;
}

test "context submodule" {
    _ = context;
}
