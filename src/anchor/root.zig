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
//!
//! ## Phase 2 Features (PDA Support)
//!
//! - Seed type system (literal, account, field references)
//! - PDA validation and derivation helpers
//! - Account initialization via CPI
//! - Bump seeds storage in context

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
// Phase 2: Seeds Module
// ============================================================================

/// Seed types for PDA derivation
pub const seeds = @import("seeds.zig");

/// Seed specification type
///
/// Defines how to obtain a seed value for PDA derivation.
pub const SeedSpec = seeds.SeedSpec;

/// Create a literal seed
///
/// Example:
/// ```zig
/// const my_seeds = &.{ anchor.seed("counter"), anchor.seed("v1") };
/// ```
pub const seed = seeds.seed;

/// Create an account reference seed
///
/// References another account's public key as a seed.
///
/// Example:
/// ```zig
/// const my_seeds = &.{ anchor.seed("user"), anchor.seedAccount("authority") };
/// ```
pub const seedAccount = seeds.seedAccount;

/// Create a field reference seed
///
/// References a field in the account data as a seed.
///
/// Example:
/// ```zig
/// const my_seeds = &.{ anchor.seed("owned_by"), anchor.seedField("owner") };
/// ```
pub const seedField = seeds.seedField;

/// Create a bump reference seed
pub const seedBump = seeds.seedBump;

/// Maximum number of seeds
pub const MAX_SEEDS = seeds.MAX_SEEDS;

/// Maximum seed length
pub const MAX_SEED_LEN = seeds.MAX_SEED_LEN;

/// Seed buffer for runtime resolution
pub const SeedBuffer = seeds.SeedBuffer;

/// Seed resolution errors
pub const SeedError = seeds.SeedError;

// ============================================================================
// Phase 2: PDA Module
// ============================================================================

/// PDA validation and derivation utilities
pub const pda = @import("pda.zig");

/// Validate that an account matches the expected PDA
///
/// Example:
/// ```zig
/// const bump = try anchor.validatePda(
///     counter_account.key(),
///     &.{ "counter", &authority.bytes },
///     program_id,
/// );
/// ```
pub const validatePda = pda.validatePda;

/// Validate PDA with known bump seed
pub const validatePdaWithBump = pda.validatePdaWithBump;

/// Derive a PDA address and bump seed
pub const derivePda = pda.derivePda;

/// Create a PDA address with known bump
pub const createPdaAddress = pda.createPdaAddress;

/// Check if an address is a valid PDA
pub const isPda = pda.isPda;

/// PDA validation errors
pub const PdaError = pda.PdaError;

// ============================================================================
// Phase 2: Init Module
// ============================================================================

/// Account initialization utilities
pub const init = @import("init.zig");

/// Configuration for account initialization
pub const InitConfig = init.InitConfig;

/// Get rent-exempt balance for an account
///
/// Example:
/// ```zig
/// const lamports = try anchor.rentExemptBalance(Counter.SPACE);
/// ```
pub const rentExemptBalance = init.rentExemptBalance;

/// Calculate rent-exempt balance using defaults
pub const rentExemptBalanceDefault = init.rentExemptBalanceDefault;

/// Create a new account via CPI
pub const createAccount = init.createAccount;

/// Create an account at a PDA via CPI
///
/// Example:
/// ```zig
/// try anchor.createAccountAtPda(
///     payer_info,
///     counter_info,
///     &my_program_id,
///     Counter.SPACE,
///     &.{ "counter", &authority.bytes },
///     bump,
///     &my_program_id,
///     system_program_info,
/// );
/// ```
pub const createAccountAtPda = init.createAccountAtPda;

/// Check if an account is uninitialized
pub const isUninitialized = init.isUninitialized;

/// Validate account is ready for initialization
pub const validateForInit = init.validateForInit;

/// Account initialization errors
pub const InitError = init.InitError;

// ============================================================================
// Tests
// ============================================================================

test "anchor module exports" {
    // Phase 1 exports
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

    // Phase 2 exports
    _ = SeedSpec;
    _ = seed;
    _ = seedAccount;
    _ = seedField;
    _ = validatePda;
    _ = derivePda;
    _ = rentExemptBalance;
    _ = InitError;
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

// Phase 2 submodule tests
test "seeds submodule" {
    _ = seeds;
}

test "pda submodule" {
    _ = pda;
}

test "init submodule" {
    _ = init;
}
