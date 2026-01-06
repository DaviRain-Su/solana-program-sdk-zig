//! MCL library bindings for BN254 curve operations
//!
//! This module provides Zig bindings to the MCL (Multi-precision Crypto Library)
//! for performing BN254 elliptic curve operations off-chain.
//!
//! MCL source: https://github.com/herumi/mcl
//!
//! ## Building with MCL
//!
//! To enable MCL for off-chain BN254 operations:
//!
//! 1. Build MCL library with Clang and libc++ (required for Zig compatibility):
//!    ```bash
//!    cd vendor/mcl
//!    make CXX="clang++-20 -stdlib=libc++" CC=clang-20 MCL_FP_BIT=256 MCL_FR_BIT=256 lib/libmcl.a
//!    ```
//!
//! 2. Build/test with MCL linked:
//!    ```bash
//!    ./solana-zig/zig build test -Dmcl-lib=vendor/mcl/lib/libmcl.a
//!    ```
//!
//! ## On-Chain vs Off-Chain
//!
//! - **On-chain (BPF)**: Use `bn254.zig` syscalls directly
//! - **Off-chain with MCL**: Real curve operations for testing/validation
//! - **Off-chain without MCL**: Placeholder values (zeros)
//!
//! ## Note on C++ ABI
//!
//! MCL must be compiled with Clang and libc++ to be compatible with Zig's linker.
//! Using GCC or libstdc++ will result in undefined symbol errors.

const std = @import("std");
const syscalls = @import("syscalls.zig");
const build_options = @import("build_options");

// ============================================================================
// Constants
// ============================================================================

/// BN254 curve identifier in MCL
pub const MCL_BN254: c_int = 0;

/// Compiled time variable for BN254 (FR_UNIT_SIZE * 10 + FP_UNIT_SIZE)
/// For 256-bit with 64-bit units: (4 * 10 + 4) = 44
pub const MCLBN_COMPILED_TIME_VAR: c_int = 44;

/// Size of a field element in bytes (32 bytes for BN254)
pub const FIELD_SIZE: usize = 32;

/// Size of Fr element in 64-bit units
pub const FR_UNIT_SIZE: usize = 4;

/// Size of Fp element in 64-bit units
pub const FP_UNIT_SIZE: usize = 4;

/// Size of a G1 point serialized (64 bytes = 2 field elements in affine)
pub const G1_SERIALIZED_SIZE: usize = 64;

/// Size of a G2 point serialized (128 bytes = 4 field elements in affine)
pub const G2_SERIALIZED_SIZE: usize = 128;

// ============================================================================
// Error Types
// ============================================================================

pub const MclError = error{
    /// MCL initialization failed
    InitFailed,
    /// Invalid input data
    InvalidInput,
    /// Deserialization failed
    DeserializeFailed,
    /// Serialization failed
    SerializeFailed,
    /// Point not on curve
    InvalidPoint,
    /// MCL not available (on-chain mode or not linked)
    NotAvailable,
    /// Operation failed
    OperationFailed,
};

// ============================================================================
// MCL C API Types (extern declarations)
// ============================================================================

/// Fp field element (base field)
pub const MclBnFp = extern struct {
    d: [FP_UNIT_SIZE]u64,
};

/// Fp2 field element (extension field)
pub const MclBnFp2 = extern struct {
    d: [2]MclBnFp,
};

/// Fr field element (scalar field)
pub const MclBnFr = extern struct {
    d: [FR_UNIT_SIZE]u64,
};

/// G1 point (projective coordinates over Fp)
pub const MclBnG1 = extern struct {
    x: MclBnFp,
    y: MclBnFp,
    z: MclBnFp,
};

/// G2 point (projective coordinates over Fp2)
pub const MclBnG2 = extern struct {
    x: MclBnFp2,
    y: MclBnFp2,
    z: MclBnFp2,
};

/// GT element (target group, Fp12)
pub const MclBnGT = extern struct {
    d: [12]MclBnFp,
};

// ============================================================================
// MCL C API Functions (extern declarations)
// These are only resolved when MCL is linked
// ============================================================================

/// Whether MCL external functions are available
/// This is set by build.zig based on -Dmcl-lib option
pub const mcl_available: bool = if (@hasDecl(build_options, "mcl_linked"))
    build_options.mcl_linked
else
    false;

// When MCL is linked, these extern declarations will be resolved
extern "c" fn mclBn_init(curve: c_int, compiledTimeVar: c_int) c_int;
extern "c" fn mclBn_getVersion() c_int;
extern "c" fn mclBn_getCurveType() c_int;

extern "c" fn mclBnG1_clear(x: *MclBnG1) void;
extern "c" fn mclBnG1_isZero(x: *const MclBnG1) c_int;
extern "c" fn mclBnG1_isEqual(x: *const MclBnG1, y: *const MclBnG1) c_int;
extern "c" fn mclBnG1_isValid(x: *const MclBnG1) c_int;
extern "c" fn mclBnG1_neg(y: *MclBnG1, x: *const MclBnG1) void;
extern "c" fn mclBnG1_dbl(y: *MclBnG1, x: *const MclBnG1) void;
extern "c" fn mclBnG1_add(z: *MclBnG1, x: *const MclBnG1, y: *const MclBnG1) void;
extern "c" fn mclBnG1_sub(z: *MclBnG1, x: *const MclBnG1, y: *const MclBnG1) void;
extern "c" fn mclBnG1_mul(z: *MclBnG1, x: *const MclBnG1, y: *const MclBnFr) void;
extern "c" fn mclBnG1_normalize(y: *MclBnG1, x: *const MclBnG1) void;
extern "c" fn mclBnG1_serialize(buf: [*]u8, maxBufSize: usize, x: *const MclBnG1) usize;
extern "c" fn mclBnG1_deserialize(x: *MclBnG1, buf: [*]const u8, bufSize: usize) usize;

extern "c" fn mclBnG2_clear(x: *MclBnG2) void;
extern "c" fn mclBnG2_isZero(x: *const MclBnG2) c_int;
extern "c" fn mclBnG2_isValid(x: *const MclBnG2) c_int;
extern "c" fn mclBnG2_add(z: *MclBnG2, x: *const MclBnG2, y: *const MclBnG2) void;
extern "c" fn mclBnG2_sub(z: *MclBnG2, x: *const MclBnG2, y: *const MclBnG2) void;
extern "c" fn mclBnG2_mul(z: *MclBnG2, x: *const MclBnG2, y: *const MclBnFr) void;
extern "c" fn mclBnG2_serialize(buf: [*]u8, maxBufSize: usize, x: *const MclBnG2) usize;
extern "c" fn mclBnG2_deserialize(x: *MclBnG2, buf: [*]const u8, bufSize: usize) usize;

extern "c" fn mclBnGT_isOne(x: *const MclBnGT) c_int;
extern "c" fn mclBnGT_mul(z: *MclBnGT, x: *const MclBnGT, y: *const MclBnGT) void;

extern "c" fn mclBn_pairing(z: *MclBnGT, x: *const MclBnG1, y: *const MclBnG2) void;

extern "c" fn mclBnFr_clear(x: *MclBnFr) void;
extern "c" fn mclBnFr_setInt(y: *MclBnFr, x: i64) void;
extern "c" fn mclBnFr_setLittleEndian(x: *MclBnFr, buf: [*]const u8, bufSize: usize) c_int;
extern "c" fn mclBnFr_getLittleEndian(buf: [*]u8, maxBufSize: usize, x: *const MclBnFr) usize;

// ============================================================================
// High-Level Zig Wrapper Types
// ============================================================================

/// G1 point wrapper with Zig-friendly interface
pub const G1 = struct {
    inner: MclBnG1,

    const Self = @This();

    /// Create zero/identity point
    pub fn zero() Self {
        var result: Self = undefined;
        if (comptime mcl_available) {
            mclBnG1_clear(&result.inner);
        } else {
            result.inner = std.mem.zeroes(MclBnG1);
        }
        return result;
    }

    /// Check if point is zero/identity
    pub fn isZero(self: *const Self) bool {
        if (comptime mcl_available) {
            return mclBnG1_isZero(&self.inner) == 1;
        }
        return true; // Placeholder
    }

    /// Check if point is valid (on curve)
    pub fn isValid(self: *const Self) bool {
        if (comptime mcl_available) {
            return mclBnG1_isValid(&self.inner) == 1;
        }
        return true; // Placeholder
    }

    /// Add two points: self + other
    pub fn add(self: *const Self, other: *const Self) Self {
        var result: Self = undefined;
        if (comptime mcl_available) {
            mclBnG1_add(&result.inner, &self.inner, &other.inner);
        } else {
            result.inner = std.mem.zeroes(MclBnG1);
        }
        return result;
    }

    /// Subtract: self - other
    pub fn sub(self: *const Self, other: *const Self) Self {
        var result: Self = undefined;
        if (comptime mcl_available) {
            mclBnG1_sub(&result.inner, &self.inner, &other.inner);
        } else {
            result.inner = std.mem.zeroes(MclBnG1);
        }
        return result;
    }

    /// Negate point
    pub fn neg(self: *const Self) Self {
        var result: Self = undefined;
        if (comptime mcl_available) {
            mclBnG1_neg(&result.inner, &self.inner);
        } else {
            result.inner = std.mem.zeroes(MclBnG1);
        }
        return result;
    }

    /// Scalar multiplication: self * scalar
    pub fn mul(self: *const Self, scalar: *const Fr) Self {
        var result: Self = undefined;
        if (comptime mcl_available) {
            mclBnG1_mul(&result.inner, &self.inner, &scalar.inner);
        } else {
            result.inner = std.mem.zeroes(MclBnG1);
        }
        return result;
    }

    /// Serialize to bytes
    pub fn serialize(self: *const Self, buf: []u8) MclError!usize {
        if (comptime !mcl_available) return MclError.NotAvailable;
        const size = mclBnG1_serialize(buf.ptr, buf.len, &self.inner);
        if (size == 0) return MclError.SerializeFailed;
        return size;
    }

    /// Deserialize from bytes
    pub fn deserialize(buf: []const u8) MclError!Self {
        if (comptime !mcl_available) return MclError.NotAvailable;
        var result: Self = undefined;
        const size = mclBnG1_deserialize(&result.inner, buf.ptr, buf.len);
        if (size == 0) return MclError.DeserializeFailed;
        return result;
    }
};

/// G2 point wrapper
pub const G2 = struct {
    inner: MclBnG2,

    const Self = @This();

    pub fn zero() Self {
        var result: Self = undefined;
        if (comptime mcl_available) {
            mclBnG2_clear(&result.inner);
        } else {
            result.inner = std.mem.zeroes(MclBnG2);
        }
        return result;
    }

    pub fn isZero(self: *const Self) bool {
        if (comptime mcl_available) {
            return mclBnG2_isZero(&self.inner) == 1;
        }
        return true;
    }

    pub fn add(self: *const Self, other: *const Self) Self {
        var result: Self = undefined;
        if (comptime mcl_available) {
            mclBnG2_add(&result.inner, &self.inner, &other.inner);
        } else {
            result.inner = std.mem.zeroes(MclBnG2);
        }
        return result;
    }

    pub fn serialize(self: *const Self, buf: []u8) MclError!usize {
        if (comptime !mcl_available) return MclError.NotAvailable;
        const size = mclBnG2_serialize(buf.ptr, buf.len, &self.inner);
        if (size == 0) return MclError.SerializeFailed;
        return size;
    }

    pub fn deserialize(buf: []const u8) MclError!Self {
        if (comptime !mcl_available) return MclError.NotAvailable;
        var result: Self = undefined;
        const size = mclBnG2_deserialize(&result.inner, buf.ptr, buf.len);
        if (size == 0) return MclError.DeserializeFailed;
        return result;
    }
};

/// GT element wrapper (pairing target group)
pub const GT = struct {
    inner: MclBnGT,

    const Self = @This();

    pub fn isOne(self: *const Self) bool {
        if (comptime mcl_available) {
            return mclBnGT_isOne(&self.inner) == 1;
        }
        return true;
    }

    pub fn mul(self: *const Self, other: *const Self) Self {
        var result: Self = undefined;
        if (comptime mcl_available) {
            mclBnGT_mul(&result.inner, &self.inner, &other.inner);
        } else {
            result.inner = std.mem.zeroes(MclBnGT);
        }
        return result;
    }
};

/// Fr (scalar field) wrapper
pub const Fr = struct {
    inner: MclBnFr,

    const Self = @This();

    pub fn zero() Self {
        var result: Self = undefined;
        if (comptime mcl_available) {
            mclBnFr_clear(&result.inner);
        } else {
            result.inner = std.mem.zeroes(MclBnFr);
        }
        return result;
    }

    pub fn fromInt(value: i64) Self {
        var result: Self = undefined;
        if (comptime mcl_available) {
            mclBnFr_setInt(&result.inner, value);
        } else {
            result.inner = std.mem.zeroes(MclBnFr);
            if (value >= 0) {
                result.inner.d[0] = @intCast(value);
            }
        }
        return result;
    }

    pub fn fromLittleEndian(buf: []const u8) MclError!Self {
        if (comptime !mcl_available) return MclError.NotAvailable;
        var result: Self = undefined;
        const ret = mclBnFr_setLittleEndian(&result.inner, buf.ptr, buf.len);
        if (ret != 0) return MclError.InvalidInput;
        return result;
    }

    pub fn toLittleEndian(self: *const Self, buf: []u8) MclError!usize {
        if (comptime !mcl_available) return MclError.NotAvailable;
        const size = mclBnFr_getLittleEndian(buf.ptr, buf.len, &self.inner);
        if (size == 0) return MclError.SerializeFailed;
        return size;
    }
};

// ============================================================================
// Initialization
// ============================================================================

var initialized: bool = false;

/// Initialize MCL library for BN254 curve
pub fn init() MclError!void {
    if (comptime !mcl_available) return MclError.NotAvailable;
    if (initialized) return;

    const ret = mclBn_init(MCL_BN254, MCLBN_COMPILED_TIME_VAR);
    if (ret != 0) {
        return MclError.InitFailed;
    }
    initialized = true;
}

/// Check if MCL is initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Check if MCL is available (compiled and linked)
pub fn isAvailable() bool {
    return mcl_available;
}

// ============================================================================
// Pairing
// ============================================================================

/// Compute pairing: e(g1, g2)
pub fn pairing(g1: *const G1, g2: *const G2) GT {
    var result: GT = undefined;
    if (comptime mcl_available) {
        mclBn_pairing(&result.inner, &g1.inner, &g2.inner);
    } else {
        result.inner = std.mem.zeroes(MclBnGT);
    }
    return result;
}

/// Check if product of pairings equals 1
/// Used for BLS signature verification and zk-SNARK verification
pub fn pairingCheck(pairs: []const struct { g1: *const G1, g2: *const G2 }) bool {
    if (comptime !mcl_available) return true; // Placeholder

    if (pairs.len == 0) return true;

    var accumulated = pairing(pairs[0].g1, pairs[0].g2);
    for (pairs[1..]) |pair| {
        const p = pairing(pair.g1, pair.g2);
        accumulated = accumulated.mul(&p);
    }

    return accumulated.isOne();
}

// ============================================================================
// Tests
// ============================================================================

test "mcl: type sizes" {
    // Verify struct sizes match MCL expectations
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(MclBnFr));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(MclBnFp));
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(MclBnFp2));
    try std.testing.expectEqual(@as(usize, 96), @sizeOf(MclBnG1));
    try std.testing.expectEqual(@as(usize, 192), @sizeOf(MclBnG2));
    try std.testing.expectEqual(@as(usize, 384), @sizeOf(MclBnGT));
}

test "mcl: G1 zero" {
    const zero = G1.zero();
    try std.testing.expect(zero.isZero());
}

test "mcl: G1 add identity" {
    const zero1 = G1.zero();
    const zero2 = G1.zero();
    const sum = zero1.add(&zero2);
    try std.testing.expect(sum.isZero());
}

test "mcl: Fr from int" {
    const fr = Fr.fromInt(42);
    if (comptime !mcl_available) {
        try std.testing.expectEqual(@as(u64, 42), fr.inner.d[0]);
    }
}

test "mcl: availability check" {
    // mcl_available is set by build options (-Dmcl-lib=...)
    // This test just verifies the function works
    const available = isAvailable();
    if (available) {
        // If MCL is available, it should be possible to initialize
        try init();
        try std.testing.expect(isInitialized());
    }
}
