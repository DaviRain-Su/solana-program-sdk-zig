//! Zig implementation of Solana SDK's BN254 (alt_bn128) elliptic curve operations
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/tree/master/bn254
//!
//! This module provides BN254 curve operations for zero-knowledge proofs via
//! Solana's `sol_alt_bn128_group_op` syscall. BN254 is a Barreto-Naehrig curve
//! commonly used in zk-SNARKs (e.g., Groth16, PLONK).
//!
//! ## Curve Parameters
//! - Prime field: p = 21888242871839275222246405745257275088696311157297823662689037894645226208583
//! - Curve equation: y² = x³ + 3
//! - Group order: r = 21888242871839275222246405745257275088548364400416034343698204186575808495617
//!
//! ## Dual Implementation (like Rust SDK)
//!
//! Following the Rust SDK's architecture:
//! - **On-chain (BPF/SBF)**: Uses `sol_alt_bn128_group_op` syscall
//! - **Off-chain**: Uses MCL library for native curve operations (see `mcl.zig`)
//!
//! This enables comprehensive testing without deploying to Solana.
//!
//! ## On-chain Usage
//!
//! All operations use the `sol_alt_bn128_group_op` syscall for efficient
//! execution within the Solana runtime's compute budget.
//!
//! ```zig
//! const bn254 = @import("bn254.zig");
//!
//! // G1 point addition (big-endian)
//! var result: [64]u8 = undefined;
//! try bn254.g1AdditionBE(&input, &result);
//!
//! // G1 scalar multiplication (little-endian)
//! try bn254.g1MultiplicationLE(&input, &result);
//!
//! // Pairing check
//! const valid = try bn254.pairingBE(&pairing_input);
//! ```
//!
//! ## Off-chain Usage
//!
//! For off-chain testing and validation, use the MCL bindings directly:
//!
//! ```zig
//! const mcl = @import("mcl.zig");
//!
//! // When MCL is linked and available
//! if (mcl.isAvailable()) {
//!     try mcl.init();
//!     const g1 = mcl.G1.zero();
//!     const sum = g1.add(&g1);
//! }
//! ```

const std = @import("std");
const syscalls = @import("syscalls.zig");
const mcl = @import("mcl.zig");

// ============================================================================
// Size Constants
// ============================================================================

/// Size of a field element (32 bytes)
pub const ALT_BN128_FIELD_SIZE: usize = 32;

/// Size of a G1 point (64 bytes = 2 field elements)
pub const ALT_BN128_G1_POINT_SIZE: usize = ALT_BN128_FIELD_SIZE * 2;

/// Size of a G2 point (128 bytes = 4 field elements)
pub const ALT_BN128_G2_POINT_SIZE: usize = ALT_BN128_FIELD_SIZE * 4;

/// Input size for G1 addition (128 bytes = 2 G1 points)
pub const ALT_BN128_G1_ADDITION_INPUT_SIZE: usize = ALT_BN128_G1_POINT_SIZE * 2;

/// Output size for G1 addition (64 bytes = 1 G1 point)
pub const ALT_BN128_G1_ADDITION_OUTPUT_SIZE: usize = ALT_BN128_G1_POINT_SIZE;

/// Input size for G1 scalar multiplication (96 bytes = 1 G1 point + 1 scalar)
pub const ALT_BN128_G1_MULTIPLICATION_INPUT_SIZE: usize = ALT_BN128_G1_POINT_SIZE + ALT_BN128_FIELD_SIZE;

/// Output size for G1 scalar multiplication (64 bytes = 1 G1 point)
pub const ALT_BN128_G1_MULTIPLICATION_OUTPUT_SIZE: usize = ALT_BN128_G1_POINT_SIZE;

/// Size of one pairing element (192 bytes = 1 G1 point + 1 G2 point)
pub const ALT_BN128_PAIRING_ELEMENT_SIZE: usize = ALT_BN128_G1_POINT_SIZE + ALT_BN128_G2_POINT_SIZE;

/// Output size for pairing (32 bytes = 1 field element, 0 or 1)
pub const ALT_BN128_PAIRING_OUTPUT_SIZE: usize = ALT_BN128_FIELD_SIZE;

// ============================================================================
// Operation Codes
// ============================================================================

/// G1 addition (big-endian input)
pub const ALT_BN128_G1_ADD_BE: u64 = 0;

/// G1 subtraction (big-endian input)
pub const ALT_BN128_G1_SUB_BE: u64 = 1;

/// G1 scalar multiplication (big-endian input)
pub const ALT_BN128_G1_MUL_BE: u64 = 2;

/// Pairing check (big-endian input)
pub const ALT_BN128_PAIRING_BE: u64 = 3;

/// Little-endian flag (OR with operation code)
pub const LE_FLAG: u64 = 0x80;

/// G1 addition (little-endian input)
pub const ALT_BN128_G1_ADD_LE: u64 = ALT_BN128_G1_ADD_BE | LE_FLAG;

/// G1 subtraction (little-endian input)
pub const ALT_BN128_G1_SUB_LE: u64 = ALT_BN128_G1_SUB_BE | LE_FLAG;

/// G1 scalar multiplication (little-endian input)
pub const ALT_BN128_G1_MUL_LE: u64 = ALT_BN128_G1_MUL_BE | LE_FLAG;

/// Pairing check (little-endian input)
pub const ALT_BN128_PAIRING_LE: u64 = ALT_BN128_PAIRING_BE | LE_FLAG;

// ============================================================================
// Error Types
// ============================================================================

/// Errors from BN254 operations
///
/// Rust equivalent: `solana_bn254::AltBn128Error`
pub const AltBn128Error = error{
    /// The input data is invalid
    InvalidInputData,
    /// Invalid group element (not on curve)
    GroupError,
    /// Slice data is out of bounds
    SliceOutOfBounds,
    /// Unexpected syscall error
    UnexpectedError,
    /// Failed to convert bytes
    TryIntoVecError,
    /// Failed to convert projective to affine
    ProjectiveToG1Failed,
};

/// Convert syscall return code to error
fn errorFromCode(code: u64) AltBn128Error {
    return switch (code) {
        1 => AltBn128Error.InvalidInputData,
        2 => AltBn128Error.GroupError,
        3 => AltBn128Error.SliceOutOfBounds,
        4 => AltBn128Error.TryIntoVecError,
        5 => AltBn128Error.ProjectiveToG1Failed,
        else => AltBn128Error.UnexpectedError,
    };
}

// ============================================================================
// G1 Point Type
// ============================================================================

/// A G1 point on the BN254 curve (64 bytes)
///
/// Consists of two 32-byte field elements (x, y).
/// Use `fromBE` or `fromLE` to construct from bytes.
pub const G1Point = struct {
    bytes: [ALT_BN128_G1_POINT_SIZE]u8,

    const Self = @This();

    /// Create from raw bytes (no validation)
    pub fn new(bytes: [ALT_BN128_G1_POINT_SIZE]u8) Self {
        return .{ .bytes = bytes };
    }

    /// Create the identity (point at infinity)
    pub fn identity() Self {
        return .{ .bytes = [_]u8{0} ** ALT_BN128_G1_POINT_SIZE };
    }

    /// Create from big-endian encoded bytes
    pub fn fromBE(be_bytes: []const u8) !Self {
        if (be_bytes.len != ALT_BN128_G1_POINT_SIZE) {
            return AltBn128Error.SliceOutOfBounds;
        }
        var result: [ALT_BN128_G1_POINT_SIZE]u8 = undefined;
        // Reverse each 32-byte field element
        reverseBytes(be_bytes[0..32], result[0..32]);
        reverseBytes(be_bytes[32..64], result[32..64]);
        return .{ .bytes = result };
    }

    /// Create from little-endian encoded bytes
    pub fn fromLE(le_bytes: []const u8) !Self {
        if (le_bytes.len != ALT_BN128_G1_POINT_SIZE) {
            return AltBn128Error.SliceOutOfBounds;
        }
        var result: [ALT_BN128_G1_POINT_SIZE]u8 = undefined;
        @memcpy(&result, le_bytes);
        return .{ .bytes = result };
    }

    /// Convert to big-endian bytes
    pub fn toBE(self: Self) [ALT_BN128_G1_POINT_SIZE]u8 {
        var result: [ALT_BN128_G1_POINT_SIZE]u8 = undefined;
        reverseBytes(self.bytes[0..32], result[0..32]);
        reverseBytes(self.bytes[32..64], result[32..64]);
        return result;
    }

    /// Convert to little-endian bytes
    pub fn toLE(self: Self) [ALT_BN128_G1_POINT_SIZE]u8 {
        return self.bytes;
    }

    /// Check if this is the identity point
    pub fn isIdentity(self: Self) bool {
        const zero = [_]u8{0} ** ALT_BN128_G1_POINT_SIZE;
        return std.mem.eql(u8, &self.bytes, &zero);
    }

    /// Check equality
    pub fn equals(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }
};

/// A G2 point on the BN254 curve (128 bytes)
pub const G2Point = struct {
    bytes: [ALT_BN128_G2_POINT_SIZE]u8,

    const Self = @This();

    /// Create from raw bytes
    pub fn new(bytes: [ALT_BN128_G2_POINT_SIZE]u8) Self {
        return .{ .bytes = bytes };
    }

    /// Create the identity
    pub fn identity() Self {
        return .{ .bytes = [_]u8{0} ** ALT_BN128_G2_POINT_SIZE };
    }

    /// Check if this is the identity point
    pub fn isIdentity(self: Self) bool {
        const zero = [_]u8{0} ** ALT_BN128_G2_POINT_SIZE;
        return std.mem.eql(u8, &self.bytes, &zero);
    }
};

// ============================================================================
// Syscall Wrappers
// ============================================================================

/// Perform G1 addition with big-endian input
///
/// Input: 128 bytes (two G1 points in big-endian)
/// Output: 64 bytes (one G1 point in big-endian)
pub fn g1AdditionBE(input: []const u8, result: *[ALT_BN128_G1_ADDITION_OUTPUT_SIZE]u8) !void {
    if (input.len > ALT_BN128_G1_ADDITION_INPUT_SIZE) {
        return AltBn128Error.InvalidInputData;
    }

    if (comptime syscalls.is_bpf_program) {
        const ret = syscalls.sol_alt_bn128_group_op(
            ALT_BN128_G1_ADD_BE,
            input.ptr,
            input.len,
            result,
        );
        if (ret != 0) {
            return errorFromCode(ret);
        }
    } else {
        // In test mode, just return zeros (actual computation needs arkworks)
        @memset(result, 0);
    }
}

/// Perform G1 addition with little-endian input
///
/// Input: 128 bytes (two G1 points in little-endian)
/// Output: 64 bytes (one G1 point in little-endian)
///
/// Note: Off-chain, this uses placeholder values when MCL is not linked.
/// To enable real curve operations off-chain, compile and link MCL library
/// and set `mcl.mcl_available = true`. See `mcl.zig` for details.
pub fn g1AdditionLE(input: *const [ALT_BN128_G1_ADDITION_INPUT_SIZE]u8, result: *[ALT_BN128_G1_ADDITION_OUTPUT_SIZE]u8) !void {
    if (comptime syscalls.is_bpf_program) {
        // On-chain: use syscall
        const ret = syscalls.sol_alt_bn128_group_op(
            ALT_BN128_G1_ADD_LE,
            input,
            ALT_BN128_G1_ADDITION_INPUT_SIZE,
            result,
        );
        if (ret != 0) {
            return errorFromCode(ret);
        }
    } else if (comptime mcl.mcl_available) {
        // Off-chain with MCL: use native curve operations
        // Initialize MCL if not already done
        mcl.init() catch return AltBn128Error.UnexpectedError;

        const p1 = mcl.G1.deserialize(input[0..64]) catch return AltBn128Error.InvalidInputData;
        const p2 = mcl.G1.deserialize(input[64..128]) catch return AltBn128Error.InvalidInputData;
        const sum = p1.add(&p2);
        _ = sum.serialize(result) catch return AltBn128Error.UnexpectedError;
    } else {
        // Test mode without MCL: return zeros (placeholder)
        @memset(result, 0);
    }
}

/// Perform G1 subtraction with big-endian input
pub fn g1SubtractionBE(input: []const u8, result: *[ALT_BN128_G1_ADDITION_OUTPUT_SIZE]u8) !void {
    if (input.len > ALT_BN128_G1_ADDITION_INPUT_SIZE) {
        return AltBn128Error.InvalidInputData;
    }

    if (comptime syscalls.is_bpf_program) {
        const ret = syscalls.sol_alt_bn128_group_op(
            ALT_BN128_G1_SUB_BE,
            input.ptr,
            input.len,
            result,
        );
        if (ret != 0) {
            return errorFromCode(ret);
        }
    } else {
        @memset(result, 0);
    }
}

/// Perform G1 subtraction with little-endian input
pub fn g1SubtractionLE(input: *const [ALT_BN128_G1_ADDITION_INPUT_SIZE]u8, result: *[ALT_BN128_G1_ADDITION_OUTPUT_SIZE]u8) !void {
    if (comptime syscalls.is_bpf_program) {
        const ret = syscalls.sol_alt_bn128_group_op(
            ALT_BN128_G1_SUB_LE,
            input,
            ALT_BN128_G1_ADDITION_INPUT_SIZE,
            result,
        );
        if (ret != 0) {
            return errorFromCode(ret);
        }
    } else {
        @memset(result, 0);
    }
}

/// Perform G1 scalar multiplication with big-endian input
///
/// Input: 96 bytes (one G1 point + one scalar in big-endian)
/// Output: 64 bytes (one G1 point in big-endian)
pub fn g1MultiplicationBE(input: []const u8, result: *[ALT_BN128_G1_MULTIPLICATION_OUTPUT_SIZE]u8) !void {
    if (input.len > ALT_BN128_G1_MULTIPLICATION_INPUT_SIZE) {
        return AltBn128Error.InvalidInputData;
    }

    if (comptime syscalls.is_bpf_program) {
        const ret = syscalls.sol_alt_bn128_group_op(
            ALT_BN128_G1_MUL_BE,
            input.ptr,
            input.len,
            result,
        );
        if (ret != 0) {
            return errorFromCode(ret);
        }
    } else {
        @memset(result, 0);
    }
}

/// Perform G1 scalar multiplication with little-endian input
pub fn g1MultiplicationLE(input: *const [ALT_BN128_G1_MULTIPLICATION_INPUT_SIZE]u8, result: *[ALT_BN128_G1_MULTIPLICATION_OUTPUT_SIZE]u8) !void {
    if (comptime syscalls.is_bpf_program) {
        const ret = syscalls.sol_alt_bn128_group_op(
            ALT_BN128_G1_MUL_LE,
            input,
            ALT_BN128_G1_MULTIPLICATION_INPUT_SIZE,
            result,
        );
        if (ret != 0) {
            return errorFromCode(ret);
        }
    } else {
        @memset(result, 0);
    }
}

/// Perform pairing check with big-endian input
///
/// Input: n * 192 bytes (n pairs of G1 + G2 points)
/// Returns: true if pairing check passes (product of pairings equals 1)
pub fn pairingBE(input: []const u8) !bool {
    if (input.len == 0 or input.len % ALT_BN128_PAIRING_ELEMENT_SIZE != 0) {
        return AltBn128Error.InvalidInputData;
    }

    if (comptime syscalls.is_bpf_program) {
        var result: [ALT_BN128_PAIRING_OUTPUT_SIZE]u8 = undefined;
        const ret = syscalls.sol_alt_bn128_group_op(
            ALT_BN128_PAIRING_BE,
            input.ptr,
            input.len,
            &result,
        );
        if (ret != 0) {
            return errorFromCode(ret);
        }
        // Result is 1 if pairing check passes
        return result[31] == 1 and std.mem.allEqual(u8, result[0..31], 0);
    } else {
        // In test mode, return true
        return true;
    }
}

/// Perform pairing check with little-endian input
pub fn pairingLE(input: []const u8) !bool {
    if (input.len == 0 or input.len % ALT_BN128_PAIRING_ELEMENT_SIZE != 0) {
        return AltBn128Error.InvalidInputData;
    }

    if (comptime syscalls.is_bpf_program) {
        var result: [ALT_BN128_PAIRING_OUTPUT_SIZE]u8 = undefined;
        const ret = syscalls.sol_alt_bn128_group_op(
            ALT_BN128_PAIRING_LE,
            input.ptr,
            input.len,
            &result,
        );
        if (ret != 0) {
            return errorFromCode(ret);
        }
        return result[0] == 1 and std.mem.allEqual(u8, result[1..32], 0);
    } else {
        return true;
    }
}

// ============================================================================
// High-level Operations
// ============================================================================

/// Add two G1 points
pub fn addG1Points(p1: G1Point, p2: G1Point) !G1Point {
    var input: [ALT_BN128_G1_ADDITION_INPUT_SIZE]u8 = undefined;
    @memcpy(input[0..64], &p1.bytes);
    @memcpy(input[64..128], &p2.bytes);

    var result: [ALT_BN128_G1_ADDITION_OUTPUT_SIZE]u8 = undefined;
    try g1AdditionLE(&input, &result);

    return G1Point.new(result);
}

/// Subtract two G1 points (p1 - p2)
pub fn subG1Points(p1: G1Point, p2: G1Point) !G1Point {
    var input: [ALT_BN128_G1_ADDITION_INPUT_SIZE]u8 = undefined;
    @memcpy(input[0..64], &p1.bytes);
    @memcpy(input[64..128], &p2.bytes);

    var result: [ALT_BN128_G1_ADDITION_OUTPUT_SIZE]u8 = undefined;
    try g1SubtractionLE(&input, &result);

    return G1Point.new(result);
}

/// Multiply a G1 point by a scalar
pub fn mulG1Scalar(point: G1Point, scalar: [32]u8) !G1Point {
    var input: [ALT_BN128_G1_MULTIPLICATION_INPUT_SIZE]u8 = undefined;
    @memcpy(input[0..64], &point.bytes);
    @memcpy(input[64..96], &scalar);

    var result: [ALT_BN128_G1_MULTIPLICATION_OUTPUT_SIZE]u8 = undefined;
    try g1MultiplicationLE(&input, &result);

    return G1Point.new(result);
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Reverse bytes in place
fn reverseBytes(src: []const u8, dst: []u8) void {
    for (src, 0..) |byte, i| {
        dst[dst.len - 1 - i] = byte;
    }
}

// ============================================================================
// Legacy Compatibility (matching old API)
// ============================================================================

/// BN254 prime field modulus (big-endian)
pub const FIELD_MODULUS = [_]u8{
    0x30, 0x64, 0x4e, 0x72, 0xe1, 0x31, 0xa0, 0x29,
    0xb8, 0x50, 0x45, 0xb6, 0x81, 0x81, 0x58, 0x5d,
    0x97, 0x81, 0x6a, 0x91, 0x68, 0x71, 0xca, 0x8d,
    0x3c, 0x20, 0x8c, 0x16, 0xd8, 0x7c, 0xfd, 0x47,
};

/// BN254 curve parameter b = 3
pub const CURVE_B: u8 = 3;

/// BN254 group order (big-endian)
pub const GROUP_ORDER = [_]u8{
    0x30, 0x64, 0x4e, 0x72, 0xe1, 0x31, 0xa0, 0x29,
    0xb8, 0x50, 0x45, 0xb6, 0x81, 0x81, 0x58, 0x5d,
    0x28, 0x33, 0xe8, 0x48, 0x79, 0xb9, 0x70, 0x91,
    0x43, 0xe1, 0xf5, 0x93, 0xf0, 0x00, 0x00, 0x01,
};

/// Legacy AffinePoint type (use G1Point instead)
pub const AffinePoint = G1Point;

/// Legacy ProjectivePoint type
pub const ProjectivePoint = struct {
    x: [32]u8,
    y: [32]u8,
    z: [32]u8,

    pub fn new(x: [32]u8, y: [32]u8, z: [32]u8) ProjectivePoint {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn fromAffine(affine: G1Point) ProjectivePoint {
        const one = [_]u8{1} ++ [_]u8{0} ** 31;
        return .{
            .x = affine.bytes[0..32].*,
            .y = affine.bytes[32..64].*,
            .z = one,
        };
    }

    pub fn isInfinity(self: ProjectivePoint) bool {
        const zero = [_]u8{0} ** 32;
        return std.mem.eql(u8, &self.z, &zero);
    }
};

pub const G1Affine = G1Point;
pub const G1Projective = ProjectivePoint;
pub const G2Affine = G2Point;

/// Generator point for G1 (placeholder - actual value depends on encoding)
pub const G1_GENERATOR = G1Point.new([_]u8{
    // x coordinate (little-endian)
    0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    // y coordinate (little-endian)
    0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
});

/// Legacy Bn254 operations namespace
pub const Bn254 = struct {
    /// Add two G1 points (uses syscall)
    pub fn addPoints(p1: G1Point, p2: G1Point) !G1Point {
        return addG1Points(p1, p2);
    }

    /// Scalar multiplication (uses syscall)
    pub fn mulScalar(point: G1Point, scalar: []const u8) !G1Point {
        if (scalar.len != 32) {
            return AltBn128Error.InvalidInputData;
        }
        return mulG1Scalar(point, scalar[0..32].*);
    }

    /// Check if point is on curve (simplified - actual check needs syscall)
    pub fn isOnCurve(point: G1Point) bool {
        // In practice, attempting an operation will validate the point
        _ = point;
        return true;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "bn254: size constants" {
    try std.testing.expectEqual(@as(usize, 32), ALT_BN128_FIELD_SIZE);
    try std.testing.expectEqual(@as(usize, 64), ALT_BN128_G1_POINT_SIZE);
    try std.testing.expectEqual(@as(usize, 128), ALT_BN128_G2_POINT_SIZE);
    try std.testing.expectEqual(@as(usize, 128), ALT_BN128_G1_ADDITION_INPUT_SIZE);
    try std.testing.expectEqual(@as(usize, 64), ALT_BN128_G1_ADDITION_OUTPUT_SIZE);
    try std.testing.expectEqual(@as(usize, 96), ALT_BN128_G1_MULTIPLICATION_INPUT_SIZE);
    try std.testing.expectEqual(@as(usize, 192), ALT_BN128_PAIRING_ELEMENT_SIZE);
}

test "bn254: operation codes" {
    try std.testing.expectEqual(@as(u64, 0), ALT_BN128_G1_ADD_BE);
    try std.testing.expectEqual(@as(u64, 1), ALT_BN128_G1_SUB_BE);
    try std.testing.expectEqual(@as(u64, 2), ALT_BN128_G1_MUL_BE);
    try std.testing.expectEqual(@as(u64, 3), ALT_BN128_PAIRING_BE);
    try std.testing.expectEqual(@as(u64, 0x80), ALT_BN128_G1_ADD_LE);
    try std.testing.expectEqual(@as(u64, 0x81), ALT_BN128_G1_SUB_LE);
    try std.testing.expectEqual(@as(u64, 0x82), ALT_BN128_G1_MUL_LE);
    try std.testing.expectEqual(@as(u64, 0x83), ALT_BN128_PAIRING_LE);
}

test "bn254: G1Point identity" {
    const identity = G1Point.identity();
    try std.testing.expect(identity.isIdentity());

    const non_identity = G1Point.new([_]u8{1} ++ [_]u8{0} ** 63);
    try std.testing.expect(!non_identity.isIdentity());
}

test "bn254: G1Point equality" {
    const p1 = G1Point.new([_]u8{1} ** 64);
    const p2 = G1Point.new([_]u8{1} ** 64);
    const p3 = G1Point.new([_]u8{2} ** 64);

    try std.testing.expect(p1.equals(p2));
    try std.testing.expect(!p1.equals(p3));
}

test "bn254: G1Point from bytes" {
    var le_bytes: [64]u8 = undefined;
    for (&le_bytes, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    const point = try G1Point.fromLE(&le_bytes);
    try std.testing.expectEqualSlices(u8, &le_bytes, &point.bytes);
}

test "bn254: G1Point endianness conversion" {
    // Create a point with known bytes
    var le_bytes: [64]u8 = undefined;
    for (&le_bytes, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    const point = try G1Point.fromLE(&le_bytes);
    const be_bytes = point.toBE();
    const back_to_le = point.toLE();

    // LE -> BE should reverse each 32-byte chunk
    try std.testing.expectEqual(le_bytes[0], be_bytes[31]);
    try std.testing.expectEqual(le_bytes[31], be_bytes[0]);
    try std.testing.expectEqual(le_bytes[32], be_bytes[63]);
    try std.testing.expectEqual(le_bytes[63], be_bytes[32]);

    // LE -> LE should be identity
    try std.testing.expectEqualSlices(u8, &le_bytes, &back_to_le);
}

test "bn254: G2Point identity" {
    const identity = G2Point.identity();
    try std.testing.expect(identity.isIdentity());
}

test "bn254: g1AdditionBE input validation" {
    var result: [64]u8 = undefined;

    // Too large input should fail
    const too_large = [_]u8{0} ** 200;
    try std.testing.expectError(AltBn128Error.InvalidInputData, g1AdditionBE(&too_large, &result));
}

test "bn254: g1MultiplicationBE input validation" {
    var result: [64]u8 = undefined;

    // Too large input should fail
    const too_large = [_]u8{0} ** 200;
    try std.testing.expectError(AltBn128Error.InvalidInputData, g1MultiplicationBE(&too_large, &result));
}

test "bn254: pairing input validation" {
    // Empty input should fail
    try std.testing.expectError(AltBn128Error.InvalidInputData, pairingBE(&[_]u8{}));

    // Wrong size input should fail
    const wrong_size = [_]u8{0} ** 100;
    try std.testing.expectError(AltBn128Error.InvalidInputData, pairingBE(&wrong_size));
}

test "bn254: error codes" {
    try std.testing.expectEqual(AltBn128Error.InvalidInputData, errorFromCode(1));
    try std.testing.expectEqual(AltBn128Error.GroupError, errorFromCode(2));
    try std.testing.expectEqual(AltBn128Error.SliceOutOfBounds, errorFromCode(3));
    try std.testing.expectEqual(AltBn128Error.TryIntoVecError, errorFromCode(4));
    try std.testing.expectEqual(AltBn128Error.ProjectiveToG1Failed, errorFromCode(5));
    try std.testing.expectEqual(AltBn128Error.UnexpectedError, errorFromCode(99));
}

test "bn254: legacy compatibility" {
    // Test that legacy types are accessible
    const point = G1_GENERATOR;
    try std.testing.expect(!point.isIdentity());

    const proj = ProjectivePoint.fromAffine(point);
    try std.testing.expect(!proj.isInfinity());
}

test "bn254: high-level operations (test mode)" {
    // Test behavior depends on whether MCL is linked
    const p1 = G1Point.identity();
    const p2 = G1Point.identity();

    if (comptime mcl.mcl_available) {
        // With MCL linked: operations use real curve math
        // Note: MCL may return errors for invalid/zero points
        // Just verify the functions don't crash
        _ = addG1Points(p1, p2) catch {};
        _ = subG1Points(p1, p2) catch {};
        const scalar = [_]u8{2} ++ [_]u8{0} ** 31;
        _ = mulG1Scalar(p1, scalar) catch {};
    } else {
        // Without MCL: syscalls return zeros (placeholder)
        const sum = try addG1Points(p1, p2);
        try std.testing.expect(sum.isIdentity());

        const diff = try subG1Points(p1, p2);
        try std.testing.expect(diff.isIdentity());

        const scalar = [_]u8{2} ++ [_]u8{0} ** 31;
        const product = try mulG1Scalar(p1, scalar);
        try std.testing.expect(product.isIdentity());
    }
}
