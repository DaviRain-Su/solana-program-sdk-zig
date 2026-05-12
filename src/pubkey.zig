const std = @import("std");
const bpf = @import("bpf.zig");

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
///
/// On BPF, Pubkeys handed out by the runtime (account keys, owners,
/// instruction program_id) are always 8-byte aligned, so we go straight
/// to the four-u64 fast path. On host targets we keep the runtime
/// alignment check to be safe against arbitrarily aligned callers.
pub inline fn pubkeyEq(a: *const Pubkey, b: *const Pubkey) bool {
    if (bpf.is_bpf_program) {
        return pubkeyEqAligned(a, b);
    }

    const a_addr = @intFromPtr(a);
    const b_addr = @intFromPtr(b);
    if (a_addr & 7 == 0 and b_addr & 7 == 0) {
        return pubkeyEqAligned(a, b);
    }

    // Fallback: byte-wise comparison (handles unaligned pointers)
    var i: usize = 0;
    while (i < PUBKEY_BYTES) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return true;
}

/// Compare two pubkeys for equality — assumes pointers are 8-byte aligned
///
/// ⚠️ SAFETY: Caller must ensure both pointers are 8-byte aligned.
///            Use this when comparing pubkeys from serialized account data
///            where alignment is guaranteed by the runtime.
///
/// This is ~33% faster than pubkeyEq when alignment is known.
pub inline fn pubkeyEqAligned(a: *const Pubkey, b: *const Pubkey) bool {
    const a_chunks: *const [4]u64 = @ptrCast(@alignCast(a));
    const b_chunks: *const [4]u64 = @ptrCast(@alignCast(b));
    // Kept as `and`-chain (not xor-or) — runtime-vs-runtime compares
    // benefit from BPFv2's cmp+jmp fusion that lets each pair be
    // `ldxdw + ldxdw + jne` (2 ALU + 1 cond branch = 3 inst/pair).
    // The xor-or shape costs +9 CU on `pubkey_cmp_unchecked` because
    // it forces a full materialization of all 4 differences. For
    // **comptime** RHS we use xor-or instead (see `pubkeyEqComptime`)
    // — there the immediate-load is the dominant cost so collapsing
    // 4 branches into 1 is a net win.
    return a_chunks[0] == b_chunks[0] and
        a_chunks[1] == b_chunks[1] and
        a_chunks[2] == b_chunks[2] and
        a_chunks[3] == b_chunks[3];
}

/// Compare a runtime pubkey against a compile-time-known pubkey.
///
/// The expected value is split into four `u64` immediates at compile
/// time, so the generated BPF code reads four `u64`s from the runtime
/// pubkey and compares each against an `imm64` — no second pointer to
/// dereference, no `&MY_ID` rodata load (which on BPF can land at an
/// invalid low address).
///
/// Prefer this over `pubkeyEq(a, &MY_PROGRAM_ID)` whenever the right
/// operand is a `pub const` / literal pubkey.
pub inline fn pubkeyEqComptime(
    a: *const Pubkey,
    comptime expected: Pubkey,
) bool {
    const e: [4]u64 = comptime blk: {
        var out: [4]u64 = undefined;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            out[i] = std.mem.readInt(u64, expected[i * 8 ..][0..8], .little);
        }
        break :blk out;
    };

    if (bpf.is_bpf_program) {
        const a_chunks: *const [4]u64 = @ptrCast(@alignCast(a));
        // XOR-OR shape: gives LLVM the option to use a single final
        // compare (one branch) instead of an `and`-chain that early-
        // outs on each mismatch. On BPFv2 the immediate-load cost
        // (`mov32`+`hor64`) is the same either way, so collapsing 4
        // branches into 1 saves ~3 CU on the happy path. Mirrors the
        // pattern used in Pinocchio's `Pubkey::eq` on Solana SBPF.
        const diff = (a_chunks[0] ^ e[0]) |
            (a_chunks[1] ^ e[1]) |
            (a_chunks[2] ^ e[2]) |
            (a_chunks[3] ^ e[3]);
        return diff == 0;
    }

    // Host: unaligned-safe path
    var buf: [4]u64 = undefined;
    @memcpy(std.mem.sliceAsBytes(buf[0..]), a[0..]);
    return buf[0] == e[0] and buf[1] == e[1] and buf[2] == e[2] and buf[3] == e[3];
}

/// Compare a runtime pubkey against multiple comptime-known pubkeys.
///
/// Returns `true` if `a` matches **any** of the entries in
/// `comptime allowed`. Each comparison uses the same 4×u64 immediate
/// shape as `pubkeyEqComptime`, so a 2-way check is ~2× the CU of a
/// single `pubkeyEqComptime` call.
///
/// Typical use: a program accepting either SPL Token or Token-2022 as
/// the mint/account owner:
///
/// ```zig
/// if (!sol.pubkey.pubkeyEqAny(mint.owner(), &.{
///     sol.spl_token_program_id,
///     sol.spl_token_2022_program_id,
/// })) return error.IncorrectProgramId;
/// ```
///
/// The `inline for` unrolls at compile time; for N == 1 this folds to
/// `pubkeyEqComptime` exactly.
pub inline fn pubkeyEqAny(
    a: *const Pubkey,
    comptime allowed: []const Pubkey,
) bool {
    inline for (allowed) |expected| {
        if (pubkeyEqComptime(a, expected)) return true;
    }
    return false;
}

/// Check if a pubkey is on the Ed25519 curve.
/// Used for PDA validation (PDAs must NOT be on the curve, so this must
/// agree with the Solana runtime's `is_on_curve` for safety).
///
/// Implemented via `std.crypto.ecc.Edwards25519.fromBytes`, which
/// performs full point decompression and rejects encodings that don't
/// decompress to a valid curve point (including the all-zero pubkey
/// used by the System Program — not on curve).
pub fn isPointOnCurve(pk: *const Pubkey) bool {
    const point = std.crypto.ecc.Edwards25519.fromBytes(pk.*) catch return false;
    point.rejectIdentity() catch {};
    return true;
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

test "pubkey: pubkeyEqComptime matches/mismatches" {
    const same = comptimeFromBase58("SysvarRent111111111111111111111111111111111");
    try std.testing.expect(pubkeyEqComptime(
        &same,
        comptime comptimeFromBase58("SysvarRent111111111111111111111111111111111"),
    ));

    const different = comptimeFromBase58("SysvarC1ock11111111111111111111111111111111");
    try std.testing.expect(!pubkeyEqComptime(
        &different,
        comptime comptimeFromBase58("SysvarRent111111111111111111111111111111111"),
    ));

    // Smoke-test the all-zero (System Program) case
    const zero: Pubkey = .{0} ** PUBKEY_BYTES;
    try std.testing.expect(pubkeyEqComptime(&zero, comptime .{0} ** PUBKEY_BYTES));
}

test "pubkey: pubkeyEqAny matches first / second / none" {
    const k1: Pubkey = .{1} ** PUBKEY_BYTES;
    const k2: Pubkey = .{2} ** PUBKEY_BYTES;
    const k3: Pubkey = .{3} ** PUBKEY_BYTES;
    const allowed = comptime [_]Pubkey{ k1, k2 };

    try std.testing.expect(pubkeyEqAny(&k1, &allowed));
    try std.testing.expect(pubkeyEqAny(&k2, &allowed));
    try std.testing.expect(!pubkeyEqAny(&k3, &allowed));
}

test "pubkey: pubkeyEqAny single-element collapses to pubkeyEqComptime" {
    const k1: Pubkey = .{42} ** PUBKEY_BYTES;
    const k2: Pubkey = .{99} ** PUBKEY_BYTES;
    const allowed = comptime [_]Pubkey{k1};

    try std.testing.expect(pubkeyEqAny(&k1, &allowed));
    try std.testing.expect(!pubkeyEqAny(&k2, &allowed));
}

test "pubkey: pubkeyEqAny empty list always returns false" {
    const k: Pubkey = .{0} ** PUBKEY_BYTES;
    try std.testing.expect(!pubkeyEqAny(&k, &.{}));
}

test "pubkey: isPointOnCurve" {
    // Ed25519's identity element y=1 (encoded as 01 00 ... 00) is a
    // canonical on-curve point.
    var identity: Pubkey = .{0} ** PUBKEY_BYTES;
    identity[0] = 1;
    try std.testing.expect(isPointOnCurve(&identity));

    // The y-coordinate of an Ed25519 point is a field element mod
    // 2^255 - 19, so the encoding with the low bits set to 2^255-18
    // (i.e. p = 2^255 - 19 reduced to 0 but with a non-canonical
    // representation) does not decompress to a valid point. We use a
    // value that fails `fromBytes`: a non-canonical y whose squared
    // value yields a non-square `u/v` ratio.
    var not_on_curve: Pubkey = .{0} ** PUBKEY_BYTES;
    not_on_curve[0] = 2; // y=2 is not on Edwards25519 (no x exists).
    try std.testing.expect(!isPointOnCurve(&not_on_curve));
}
