const std = @import("std");

/// Number of bytes in a pubkey
pub const PUBKEY_BYTES: usize = 32;

/// Public key type — 32 byte array
pub const Pubkey = [PUBKEY_BYTES]u8;

/// Maximum number of seeds for PDA derivation
pub const MAX_SEEDS: usize = 16;

/// Maximum length of a seed for PDA derivation
pub const MAX_SEED_LEN: usize = 32;

/// Base58 alphabet (Bitcoin)
const BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

/// Base58 decode table: maps ASCII code to value, 255 = invalid
const BASE58_DECODE_TABLE = blk: {
    var table: [256]u8 = undefined;
    @memset(&table, 255);
    for (BASE58_ALPHABET, 0..) |c, i| {
        table[c] = @intCast(i);
    }
    break :blk table;
};

/// Compile-time Base58 decode
pub fn comptimeFromBase58(comptime encoded: []const u8) Pubkey {
    return comptime blk: {
        var result: Pubkey = .{0} ** PUBKEY_BYTES;
        // Decode base58 to big integer
        var num: u256 = 0;
        for (encoded) |c| {
            const digit = BASE58_DECODE_TABLE[c];
            if (digit == 255) {
                @compileError("Invalid Base58 character: " ++ .{c});
            }
            num = num * 58 + digit;
        }

        // Convert to bytes (big endian)
        var i: usize = PUBKEY_BYTES;
        while (i > 0) : (i -= 1) {
            result[i - 1] = @truncate(num);
            num >>= 8;
        }

        if (num != 0) {
            @compileError("Base58 string too long for Pubkey");
        }

        break :blk result;
    };
}

/// Runtime Base58 encode
pub fn encodeBase58(bytes: *const Pubkey, out: *[44]u8) usize {
    // Count leading zeros
    var leading_zeros: usize = 0;
    while (leading_zeros < PUBKEY_BYTES and bytes[leading_zeros] == 0) : (leading_zeros += 1) {}

    var num: u256 = 0;
    for (bytes) |b| {
        num = (num << 8) | b;
    }

    var i: usize = 0;

    // Output leading '1's for each leading zero byte
    while (i < leading_zeros) : (i += 1) {
        out[i] = '1';
    }

    if (num == 0) {
        return i;
    }

    const start = i;
    while (num > 0) : (i += 1) {
        out[i] = BASE58_ALPHABET[@intCast(num % 58)];
        num /= 58;
    }

    // Reverse the non-leading-zero part
    var j = start;
    var k = i - 1;
    while (j < k) {
        const tmp = out[j];
        out[j] = out[k];
        out[k] = tmp;
        j += 1;
        k -= 1;
    }

    return i;
}

/// Compare two pubkeys for equality
/// Uses 8-byte chunks for optimal performance on 64-bit targets
/// Falls back to byte-wise comparison if alignment is insufficient
pub inline fn pubkeyEq(a: *const Pubkey, b: *const Pubkey) bool {
    // Check if both pointers are 8-byte aligned
    const a_addr = @intFromPtr(a);
    const b_addr = @intFromPtr(b);

    if (a_addr & 7 == 0 and b_addr & 7 == 0) {
        // Fast path: 8-byte aligned, compare as four u64 chunks
        const a_chunks: *const [4]u64 = @ptrCast(@alignCast(a));
        const b_chunks: *const [4]u64 = @ptrCast(@alignCast(b));

        return a_chunks[0] == b_chunks[0] and
            a_chunks[1] == b_chunks[1] and
            a_chunks[2] == b_chunks[2] and
            a_chunks[3] == b_chunks[3];
    }

    // Fallback: byte-wise comparison (handles unaligned pointers)
    var i: usize = 0;
    while (i < PUBKEY_BYTES) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return true;
}

/// Check if a pubkey is on the Curve25519 curve
/// Used for PDA validation (PDAs must NOT be on the curve)
pub fn isPointOnCurve(pubkey: *const Pubkey) bool {
    const Y = std.crypto.ecc.Curve25519.Fe.fromBytes(pubkey.*);
    const Z = std.crypto.ecc.Curve25519.Fe.one;
    const YY = Y.sq();
    const u = YY.sub(Z);
    const v = YY.mul(std.crypto.ecc.Curve25519.Fe.edwards25519d).add(Z);

    const v3 = v.sq().mul(v);
    const x = v3.sq().mul(u).mul(v).pow2523().mul(v3).mul(u);
    const vxx = x.sq().mul(v);

    const has_m_root = vxx.sub(u).isZero();
    const has_p_root = vxx.add(u).isZero();

    return has_m_root or has_p_root;
}

/// Format pubkey as Base58
pub fn formatPubkey(
    pubkey: *const Pubkey,
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    var buffer: [44]u8 = undefined;
    const len = encodeBase58(pubkey, &buffer);
    try writer.print("{s}", .{buffer[0..len]});
}

// =============================================================================
// Tests
// =============================================================================

test "pubkey: comptimeFromBase58" {
    const id = comptimeFromBase58("11111111111111111111111111111111");
    const expected: Pubkey = .{0} ** PUBKEY_BYTES;
    try std.testing.expectEqual(expected, id);
}

test "pubkey: encodeBase58 roundtrip" {
    const original = comptimeFromBase58("11111111111111111111111111111111");
    var encoded: [44]u8 = undefined;
    const len = encodeBase58(&original, &encoded);
    try std.testing.expectEqualStrings("11111111111111111111111111111111", encoded[0..len]);
}

test "pubkey: equality" {
    const a = comptimeFromBase58("11111111111111111111111111111111");
    const b = comptimeFromBase58("11111111111111111111111111111111");
    try std.testing.expect(pubkeyEq(&a, &b));
}

test "pubkey: isPointOnCurve" {
    // A normal pubkey should be on the curve
    const on_curve = comptimeFromBase58("11111111111111111111111111111111");
    try std.testing.expect(isPointOnCurve(&on_curve));
}
