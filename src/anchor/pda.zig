//! Zig implementation of Anchor PDA validation utilities
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/src/accounts/account.rs
//!
//! PDA (Program Derived Address) utilities for validating and deriving
//! deterministic addresses from seeds.
//!
//! ## Example
//! ```zig
//! // Validate a PDA during account loading
//! const bump = try pda.validatePda(
//!     account.key(),
//!     &.{ "counter", &authority.bytes },
//!     program_id,
//! );
//! ```

const std = @import("std");
const public_key_mod = @import("../public_key.zig");
const seeds_mod = @import("seeds.zig");

const PublicKey = public_key_mod.PublicKey;
const ProgramDerivedAddress = public_key_mod.ProgramDerivedAddress;
const SeedSpec = seeds_mod.SeedSpec;
const SeedBuffer = seeds_mod.SeedBuffer;
const MAX_SEEDS = seeds_mod.MAX_SEEDS;

/// PDA validation and derivation errors
pub const PdaError = error{
    /// The account address does not match the expected PDA
    InvalidPda,
    /// Seeds array exceeds maximum length
    SeedsTooLong,
    /// Bump seed does not produce valid PDA
    BumpMismatch,
    /// Seeds contain invalid data
    InvalidSeeds,
    /// PDA derivation failed
    DerivationFailed,
    /// Account not found for seed resolution
    AccountNotFound,
    /// Maximum seed length exceeded
    MaxSeedLengthExceeded,
    /// Unexpected error
    Unexpected,
};

/// Validate that an account matches the expected PDA
///
/// Given an account's public key and the seeds used to derive it,
/// this function verifies the address matches and returns the bump seed.
///
/// Example:
/// ```zig
/// const bump = try validatePda(
///     counter_account.key(),
///     &.{ "counter", &authority.bytes },
///     program_id,
/// );
/// ```
pub fn validatePda(
    account_key: *const PublicKey,
    seeds: anytype,
    program_id: *const PublicKey,
) PdaError!u8 {
    // Derive the expected PDA
    const pda = public_key_mod.findProgramAddress(seeds, program_id.*) catch {
        return PdaError.DerivationFailed;
    };

    // Compare addresses
    if (!account_key.equals(pda.address)) {
        return PdaError.InvalidPda;
    }

    return pda.bump_seed[0];
}

/// Validate PDA with known bump seed
///
/// More efficient than validatePda when the bump is already known,
/// as it only needs to create the address once rather than searching.
///
/// Example:
/// ```zig
/// try validatePdaWithBump(
///     counter_account.key(),
///     &.{ "counter", &authority.bytes },
///     bump,
///     program_id,
/// );
/// ```
pub fn validatePdaWithBump(
    account_key: *const PublicKey,
    seeds: anytype,
    bump: u8,
    program_id: *const PublicKey,
) PdaError!void {
    // Create PDA address with the known bump and compare
    const expected = createPdaAddress(seeds, bump, program_id) catch {
        return PdaError.DerivationFailed;
    };

    if (!account_key.equals(expected)) {
        return PdaError.BumpMismatch;
    }
}

/// Derive a PDA address and bump seed
///
/// Returns the derived address and the canonical bump seed.
///
/// Example:
/// ```zig
/// const result = try derivePda(&.{ "counter", &authority.bytes }, program_id);
/// const address = result.address;
/// const bump = result.bump_seed[0];
/// ```
pub fn derivePda(
    seeds: anytype,
    program_id: *const PublicKey,
) PdaError!ProgramDerivedAddress {
    return public_key_mod.findProgramAddress(seeds, program_id.*) catch {
        return PdaError.DerivationFailed;
    };
}

/// Create a PDA address with known bump (no search)
///
/// Use this when you already know the bump seed to avoid
/// the expensive bump search.
///
/// Example:
/// ```zig
/// const address = try createPdaAddress(
///     &.{ "counter", &authority.bytes },
///     bump,
///     program_id,
/// );
/// ```
pub fn createPdaAddress(
    seeds: anytype,
    bump: u8,
    program_id: *const PublicKey,
) PdaError!PublicKey {
    // Create seeds array with bump appended
    const SeedsType = @TypeOf(seeds);
    const seeds_len = @typeInfo(SeedsType).@"struct".fields.len;

    if (seeds_len >= MAX_SEEDS) {
        return PdaError.SeedsTooLong;
    }

    // Build new seeds tuple with bump
    var seeds_with_bump: [seeds_len + 1][]const u8 = undefined;

    comptime var i = 0;
    inline while (i < seeds_len) : (i += 1) {
        seeds_with_bump[i] = seeds[i];
    }

    const bump_bytes = [_]u8{bump};
    seeds_with_bump[seeds_len] = &bump_bytes;

    // Use a runtime call since we have a runtime array
    return createProgramAddressFromSlice(&seeds_with_bump, program_id);
}

/// Create program address from a slice of seeds
fn createProgramAddressFromSlice(
    seeds: []const []const u8,
    program_id: *const PublicKey,
) PdaError!PublicKey {
    // Use the SDK's createProgramAddressSlice for runtime slice-based PDA creation
    return PublicKey.createProgramAddressSlice(seeds, program_id.*) catch |err| {
        return switch (err) {
            error.InvalidSeeds => PdaError.InvalidSeeds,
            error.MaxSeedLengthExceeded => PdaError.MaxSeedLengthExceeded,
        };
    };
}

/// Check if an address is a valid PDA (off the ed25519 curve)
pub fn isPda(address: *const PublicKey) bool {
    return !address.isPointOnCurve();
}

// ============================================================================
// Tests
// ============================================================================

test "derivePda returns correct address and bump" {
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");
    const result = try derivePda(.{"hello"}, &program_id);

    // The bump should be valid (0-255)
    try std.testing.expect(result.bump_seed[0] <= 255);

    // The address should be off curve (valid PDA)
    try std.testing.expect(!result.address.isPointOnCurve());
}

test "validatePda succeeds for valid PDA" {
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");

    // First derive the PDA
    const pda = try derivePda(.{"test_seed"}, &program_id);

    // Then validate it
    const bump = try validatePda(&pda.address, .{"test_seed"}, &program_id);

    try std.testing.expectEqual(pda.bump_seed[0], bump);
}

test "validatePda fails for wrong address" {
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");

    // Use a random address that's not the PDA
    var wrong_address = PublicKey.default();
    wrong_address.bytes[0] = 0xFF;

    const result = validatePda(&wrong_address, .{"test_seed"}, &program_id);
    try std.testing.expectError(PdaError.InvalidPda, result);
}

test "isPda returns true for valid PDA" {
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");
    const pda = try derivePda(.{"pda_test"}, &program_id);

    try std.testing.expect(isPda(&pda.address));
}

test "derivePda with multiple seeds" {
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");
    const authority = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");

    const result = try derivePda(.{ "counter", &authority.bytes }, &program_id);

    try std.testing.expect(!result.address.isPointOnCurve());
}

test "validatePda with multiple seeds" {
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");
    const user = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");

    // Derive PDA
    const pda = try derivePda(.{ "user_data", &user.bytes }, &program_id);

    // Validate it
    const bump = try validatePda(&pda.address, .{ "user_data", &user.bytes }, &program_id);

    try std.testing.expectEqual(pda.bump_seed[0], bump);
}
