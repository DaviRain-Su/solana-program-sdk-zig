//! Zig implementation of Anchor constraints
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/syn/src/codegen/accounts/constraints.rs
//!
//! Constraints define validation rules for accounts. In Anchor, these are
//! specified via `#[account(...)]` attributes. In sol-anchor-zig, they are
//! defined as struct fields with compile-time configuration.
//!
//! ## Phase 1 Constraints (implemented)
//! - `mut`: Account must be writable
//! - `signer`: Account must sign the transaction
//! - `owner`: Account must be owned by specified program
//! - `address`: Account must have exact public key
//! - `executable`: Account must be executable (for program accounts)
//!
//! ## Future Phases
//! - `rent_exempt`: Rent exemption check (requires Rent sysvar)
//! - `seeds`, `bump`: PDA derivation (Phase 2)
//! - `has_one`, `constraint`: Field validation (Phase 3)
//! - `close`, `realloc`: Account lifecycle (Phase 3)

const std = @import("std");
const anchor_error = @import("error.zig");
const AnchorError = anchor_error.AnchorError;

// Import from parent SDK
const Account = @import("../account.zig").Account;
const PublicKey = @import("../public_key.zig").PublicKey;

/// Constraint specification for account validation
///
/// Used to define validation rules for accounts in an instruction context.
/// Each field corresponds to an Anchor constraint attribute.
///
/// Example:
/// ```zig
/// const my_constraints = Constraints{
///     .mut = true,
///     .signer = true,
///     .owner = my_program_id,
/// };
/// ```
pub const Constraints = struct {
    /// Account must be mutable (writable)
    ///
    /// Anchor equivalent: `#[account(mut)]`
    mut: bool = false,

    /// Account must be a signer of the transaction
    ///
    /// Anchor equivalent: `#[account(signer)]`
    signer: bool = false,

    /// Account must be owned by specified program
    ///
    /// Anchor equivalent: `#[account(owner = <program>)]`
    owner: ?PublicKey = null,

    /// Account must have exact public key address
    ///
    /// Anchor equivalent: `#[account(address = <pubkey>)]`
    address: ?PublicKey = null,

    /// Account must be executable (for program accounts)
    ///
    /// Anchor equivalent: `#[account(executable)]`
    executable: bool = false,

    // Note: rent_exempt constraint is planned for future phases.
    // It requires access to the Rent sysvar for proper validation.
};

/// Validate constraints against an account
///
/// Checks all specified constraints and returns the first violation found.
/// Returns null if all constraints pass.
///
/// Example:
/// ```zig
/// const constraints = Constraints{ .mut = true, .signer = true };
/// if (validateConstraints(&account_info, constraints)) |err| {
///     return err;
/// }
/// ```
pub fn validateConstraints(info: *const Account.Info, constraints: Constraints) ?AnchorError {
    // Check mut constraint
    if (constraints.mut and info.is_writable == 0) {
        return AnchorError.ConstraintMut;
    }

    // Check signer constraint
    if (constraints.signer and info.is_signer == 0) {
        return AnchorError.ConstraintSigner;
    }

    // Check owner constraint
    if (constraints.owner) |expected_owner| {
        if (!info.owner_id.equals(expected_owner)) {
            return AnchorError.ConstraintOwner;
        }
    }

    // Check address constraint
    if (constraints.address) |expected_address| {
        if (!info.id.equals(expected_address)) {
            return AnchorError.ConstraintAddress;
        }
    }

    // Check executable constraint
    if (constraints.executable and info.is_executable == 0) {
        return AnchorError.ConstraintExecutable;
    }

    // All constraints passed
    return null;
}

/// Validate constraints, returning error union for try/catch usage
///
/// Example:
/// ```zig
/// try validateConstraintsOrError(&account_info, constraints);
/// ```
pub fn validateConstraintsOrError(info: *const Account.Info, constraints: Constraints) !void {
    if (validateConstraints(info, constraints)) |err| {
        return switch (err) {
            .ConstraintMut => error.ConstraintMut,
            .ConstraintSigner => error.ConstraintSigner,
            .ConstraintOwner => error.ConstraintOwner,
            .ConstraintAddress => error.ConstraintAddress,
            .ConstraintExecutable => error.ConstraintExecutable,
            else => error.ConstraintRaw,
        };
    }
}

/// Constraint validation errors
pub const ConstraintError = error{
    ConstraintMut,
    ConstraintSigner,
    ConstraintOwner,
    ConstraintAddress,
    ConstraintExecutable,
    ConstraintRaw,
    // Reserved for future phases:
    ConstraintSeeds, // Phase 2: PDA validation
    ConstraintHasOne, // Phase 3: Field validation
    ConstraintRentExempt, // Future: Requires Rent sysvar
};

// ============================================================================
// Tests
// ============================================================================

test "validateConstraints passes with no constraints" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{};
    try std.testing.expect(validateConstraints(&info, constraints) == null);
}

test "validateConstraints fails mut when not writable" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .mut = true };
    try std.testing.expectEqual(AnchorError.ConstraintMut, validateConstraints(&info, constraints).?);
}

test "validateConstraints passes mut when writable" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    const constraints = Constraints{ .mut = true };
    try std.testing.expect(validateConstraints(&info, constraints) == null);
}

test "validateConstraints fails signer when not signing" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .signer = true };
    try std.testing.expectEqual(AnchorError.ConstraintSigner, validateConstraints(&info, constraints).?);
}

test "validateConstraints passes signer when signing" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .signer = true };
    try std.testing.expect(validateConstraints(&info, constraints) == null);
}

test "validateConstraints fails owner mismatch" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    // Use TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA (Token Program) - different from default (all zeros)
    const expected_owner = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .owner = expected_owner };
    try std.testing.expectEqual(AnchorError.ConstraintOwner, validateConstraints(&info, constraints).?);
}

test "validateConstraints passes owner match" {
    var id = PublicKey.default();
    // Use Token Program ID for both owner and expected to test matching
    var owner = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .owner = owner };
    try std.testing.expect(validateConstraints(&info, constraints) == null);
}

test "validateConstraints fails address mismatch" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    // Use Token Program ID as expected address - different from default (all zeros)
    const expected_address = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .address = expected_address };
    try std.testing.expectEqual(AnchorError.ConstraintAddress, validateConstraints(&info, constraints).?);
}

test "validateConstraints checks multiple constraints" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
    };

    const constraints = Constraints{
        .mut = true,
        .signer = true,
    };
    try std.testing.expect(validateConstraints(&info, constraints) == null);
}
