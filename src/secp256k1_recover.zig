//! Public key recovery from secp256k1 ECDSA signatures.
//!
//! Wrapper around the `sol_secp256k1_recover` syscall — the building
//! block for Ethereum-compatible `ecrecover`, oracle attestation
//! verification, and bridge / cross-chain message validation.
//!
//! ### Hashing requirement
//! ECDSA recovery operates on a 32-byte **cryptographic hash of the
//! message**, never the message itself. Pass `hash` already hashed by
//! the program (typically with `sol.keccak256` for Ethereum
//! compatibility). The runtime does NOT validate that the input is
//! actually a hash.
//!
//! ### Signature malleability
//! Solana's syscall does NOT reject high-`S` signatures. For
//! applications where unique signature representation matters (e.g.
//! anti-replay), the program must reject high-`S` values itself —
//! see the Rust SDK docs for the canonical pattern.
//!
//! ### On-chain length contract
//! On SBF the syscall does **not** validate that `hash` is 32 bytes
//! or `signature` is 64 bytes — it just reads from the pointers. The
//! caller must guarantee the buffer lengths before invoking.

const std = @import("std");
const builtin = @import("builtin");

/// 32 bytes — fixed size of the message hash.
pub const HASH_LEN: usize = 32;
/// 64 bytes — compact (r || s) secp256k1 signature.
pub const SIGNATURE_LEN: usize = 64;
/// 64 bytes — uncompressed public key (x || y), without the leading
/// `0x04` SEC1 prefix.
pub const PUBKEY_LEN: usize = 64;

/// Errors returned by `recover`. The numeric codes match the
/// `solana-program::secp256k1_recover::Secp256k1RecoverError` mapping
/// (`1` / `2` / `3`).
pub const Error = error{
    /// The hash buffer length isn't 32 (host-side check only).
    InvalidHash,
    /// `recovery_id` outside `[0, 3]` or signature is "overflowing".
    InvalidRecoveryId,
    /// Signature isn't 64 bytes, or is malformed.
    InvalidSignature,
    /// Catch-all for any future syscall error.
    Unexpected,
};

/// Recovered 64-byte secp256k1 public key. Use `.bytes` for raw
/// access; the type exists for self-documentation at call sites.
pub const RecoveredPubkey = struct {
    bytes: [PUBKEY_LEN]u8,
};

const is_solana = builtin.os.tag == .freestanding and builtin.cpu.arch == .bpfel;

extern fn sol_secp256k1_recover(
    hash: [*]const u8,
    recovery_id: u64,
    signature: [*]const u8,
    result: [*]u8,
) callconv(.c) u64;

/// Recover a secp256k1 public key from a message hash, recovery id,
/// and 64-byte (r || s) signature.
///
/// Returns the uncompressed (x || y) public key — drop the leading
/// `0x04` SEC1 prefix if you're interoperating with libraries that
/// produce 65-byte encodings.
///
/// To derive an Ethereum address: `keccak256(pubkey)[12..32]`.
pub fn recover(
    hash: []const u8,
    recovery_id: u8,
    signature: []const u8,
) Error!RecoveredPubkey {
    // On SBF the syscall doesn't validate lengths — do it ourselves so
    // host and BPF return the same error variants on the same inputs.
    if (hash.len != HASH_LEN) return error.InvalidHash;
    if (signature.len != SIGNATURE_LEN) return error.InvalidSignature;
    if (recovery_id > 3) return error.InvalidRecoveryId;

    if (comptime !is_solana) {
        // Host fallback: we can't actually recover without pulling in
        // a secp256k1 implementation. Return a deterministic stub so
        // host tests can at least exercise the call path; flag the
        // limitation in the error so production code doesn't rely on
        // host-side recovery.
        return error.Unexpected;
    }

    var out: RecoveredPubkey = .{ .bytes = undefined };
    const rc = sol_secp256k1_recover(
        hash.ptr,
        @intCast(recovery_id),
        signature.ptr,
        &out.bytes,
    );
    return switch (rc) {
        0 => out,
        1 => error.InvalidHash,
        2 => error.InvalidRecoveryId,
        3 => error.InvalidSignature,
        else => error.Unexpected,
    };
}

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

test "secp256k1_recover: length validation rejects wrong-size hash" {
    var sig: [SIGNATURE_LEN]u8 = .{0} ** SIGNATURE_LEN;
    try testing.expectError(error.InvalidHash, recover(&[_]u8{0} ** 31, 0, &sig));
}

test "secp256k1_recover: length validation rejects wrong-size signature" {
    var hash: [HASH_LEN]u8 = .{0} ** HASH_LEN;
    try testing.expectError(error.InvalidSignature, recover(&hash, 0, &[_]u8{0} ** 63));
}

test "secp256k1_recover: invalid recovery_id rejected" {
    var hash: [HASH_LEN]u8 = .{0} ** HASH_LEN;
    var sig: [SIGNATURE_LEN]u8 = .{0} ** SIGNATURE_LEN;
    try testing.expectError(error.InvalidRecoveryId, recover(&hash, 4, &sig));
    try testing.expectError(error.InvalidRecoveryId, recover(&hash, 255, &sig));
}

test "secp256k1_recover: host stub returns Unexpected" {
    var hash: [HASH_LEN]u8 = .{1} ** HASH_LEN;
    var sig: [SIGNATURE_LEN]u8 = .{2} ** SIGNATURE_LEN;
    // On host we cannot perform real recovery — the wrapper returns
    // Unexpected so callers know the operation didn't actually run.
    try testing.expectError(error.Unexpected, recover(&hash, 0, &sig));
}

test "secp256k1_recover: constants match Rust SDK" {
    try testing.expectEqual(@as(usize, 32), HASH_LEN);
    try testing.expectEqual(@as(usize, 64), SIGNATURE_LEN);
    try testing.expectEqual(@as(usize, 64), PUBKEY_LEN);
}
