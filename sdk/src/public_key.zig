//! Zig implementation of Solana SDK's pubkey module (SDK version - no syscalls)
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/pubkey/src/lib.rs
//!
//! This module provides the PublicKey type representing a Solana public key (Ed25519 32 bytes).
//! It includes utilities for creating, parsing, and manipulating public keys,
//! as well as Program Derived Address (PDA) generation using pure SHA256 computation.
//!
//! Note: This is the SDK version without syscall dependencies. For on-chain programs
//! that need syscall-optimized PDA derivation, use the program-sdk version.

const std = @import("std");
const base58 = @import("base58");
pub const base58_mod = base58;
const builtin = @import("builtin");

const mem = std.mem;
const testing = std.testing;

pub const ProgramDerivedAddress = struct {
    address: PublicKey,
    bump_seed: [1]u8,
};

pub const PublicKey = extern struct {
    pub const length: usize = 32;
    pub const base58_length: usize = 44;

    pub const max_num_seeds: usize = 16;
    pub const max_seed_length: usize = 32;

    bytes: [32]u8,

    /// Maximum string length of a base58 encoded public key
    pub const max_base58_len: usize = 44;

    /// Create a PublicKey from bytes
    pub fn from(bytes: [PublicKey.length]u8) PublicKey {
        return .{ .bytes = bytes };
    }

    /// Create a default (zero) public key
    pub fn default() PublicKey {
        return .{ .bytes = [_]u8{0} ** PublicKey.length };
    }

    /// Create a unique public key for tests
    /// Rust equivalent: `Address::new_unique()`
    /// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address/src/lib.rs#L128
    pub fn newUnique() PublicKey {
        var bytes: [PublicKey.length]u8 = undefined;
        std.crypto.random.bytes(&bytes);
        return .{ .bytes = bytes };
    }

    /// Parse from base58 string at runtime
    /// Rust equivalent: `Address::from_str()`
    /// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address/src/lib.rs#L88
    pub fn fromBase58(str: []const u8) !PublicKey {
        if (str.len > max_base58_len) {
            return error.WrongSize;
        }
        var buffer: [PublicKey.length]u8 = undefined;
        const decoded = base58.bitcoin.decode(&buffer, str) catch {
            return error.Invalid;
        };
        if (decoded.len != PublicKey.length) {
            return error.WrongSize;
        }
        return .{ .bytes = buffer };
    }

    /// Get a reference to the public key bytes array
    /// Rust equivalent: `Address::as_array()`
    /// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address/src/lib.rs#L169
    pub fn asArray(self: *const PublicKey) *const [PublicKey.length]u8 {
        return &self.bytes;
    }

    /// Get the public key bytes as a slice
    pub fn asBytes(self: *const PublicKey) []const u8 {
        return &self.bytes;
    }

    /// Convert to base58 string
    pub fn toBase58(self: PublicKey, buffer: *[max_base58_len]u8) []const u8 {
        return base58.bitcoin.encode(buffer, &self.bytes);
    }

    pub fn comptimeFromBase58(comptime encoded: []const u8) PublicKey {
        return PublicKey.from(base58.bitcoin.comptimeDecode(encoded));
    }

    pub fn comptimeCreateProgramAddress(comptime seeds: anytype, comptime program_id: PublicKey) PublicKey {
        comptime {
            return PublicKey.createProgramAddress(seeds, program_id) catch |err| {
                @compileError("Failed to create program address: " ++ @errorName(err));
            };
        }
    }

    pub fn comptimeFindProgramAddress(comptime seeds: anytype, comptime program_id: PublicKey) ProgramDerivedAddress {
        comptime {
            return PublicKey.findProgramAddress(seeds, program_id) catch |err| {
                @compileError("Failed to find program address: " ++ @errorName(err));
            };
        }
    }

    pub fn equals(self: PublicKey, other: PublicKey) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    pub fn isPointOnCurve(self: PublicKey) bool {
        const Y = std.crypto.ecc.Curve25519.Fe.fromBytes(self.bytes);
        const Z = std.crypto.ecc.Curve25519.Fe.one;
        const YY = Y.sq();
        const u = YY.sub(Z);
        const v = YY.mul(std.crypto.ecc.Curve25519.Fe.edwards25519d).add(Z);
        if (sqrtRatioM1(u, v) != 1) {
            return false;
        }
        return true;
    }

    fn sqrtRatioM1(u: std.crypto.ecc.Curve25519.Fe, v: std.crypto.ecc.Curve25519.Fe) u32 {
        const v3 = v.sq().mul(v); // v^3
        const x = v3.sq().mul(u).mul(v).pow2523().mul(v3).mul(u); // uv^3(uv^7)^((q-5)/8)
        const vxx = x.sq().mul(v); // vx^2
        const m_root_check = vxx.sub(u); // vx^2-u
        const p_root_check = vxx.add(u); // vx^2+u
        const has_m_root = m_root_check.isZero();
        const has_p_root = p_root_check.isZero();
        return @intFromBool(has_m_root) | @intFromBool(has_p_root);
    }

    /// Create a program address using pure SHA256 computation.
    /// This version works both at comptime and runtime without syscalls.
    ///
    /// Seeds can be `[]const u8` slices or `PublicKey` values - PublicKey seeds
    /// are automatically converted to their byte representation.
    ///
    /// Example:
    /// ```zig
    /// // Both of these work:
    /// const pda1 = try PublicKey.createProgramAddress(.{ &base_key.bytes, "seed" }, program_id);
    /// const pda2 = try PublicKey.createProgramAddress(.{ base_key, "seed" }, program_id);  // auto-converts
    /// ```
    pub fn createProgramAddress(seeds: anytype, program_id: PublicKey) !PublicKey {
        if (seeds.len > PublicKey.max_num_seeds) {
            return error.MaxSeedLengthExceeded;
        }

        // Storage for PublicKey bytes that need to be converted to slices
        // We need to store them separately because comptime values can't have
        // their addresses taken at runtime
        var pubkey_storage: [seeds.len][32]u8 = undefined;

        // Convert all seeds to []const u8 slices, validating lengths
        var seed_slices: [seeds.len][]const u8 = undefined;
        comptime var seeds_index = 0;
        inline while (seeds_index < seeds.len) : (seeds_index += 1) {
            const Seed = @TypeOf(seeds[seeds_index]);
            if (comptime Seed == PublicKey) {
                // Copy PublicKey bytes to storage and create slice from it
                pubkey_storage[seeds_index] = seeds[seeds_index].bytes;
                seed_slices[seeds_index] = &pubkey_storage[seeds_index];
            } else {
                const slice: []const u8 = seeds[seeds_index];
                if (slice.len > PublicKey.max_seed_length) {
                    return error.MaxSeedLengthExceeded;
                }
                seed_slices[seeds_index] = slice;
            }
        }

        var address: PublicKey = undefined;

        @setEvalBranchQuota(100_000_000);

        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        for (seed_slices) |seed| {
            hasher.update(seed);
        }
        hasher.update(&program_id.bytes);
        hasher.update("ProgramDerivedAddress");
        hasher.final(&address.bytes);

        if (address.isPointOnCurve()) {
            return error.InvalidSeeds;
        }

        return address;
    }

    /// Find a program address and bump seed using pure computation.
    /// This version works both at comptime and runtime without syscalls.
    pub fn findProgramAddress(seeds: anytype, program_id: PublicKey) !ProgramDerivedAddress {
        var pda: ProgramDerivedAddress = undefined;

        var seeds_with_bump: [seeds.len + 1][]const u8 = undefined;

        comptime var seeds_index = 0;
        inline while (seeds_index < seeds.len) : (seeds_index += 1) {
            const Seed = @TypeOf(seeds[seeds_index]);
            if (comptime Seed == PublicKey) {
                seeds_with_bump[seeds_index] = &seeds[seeds_index].bytes;
            } else {
                seeds_with_bump[seeds_index] = seeds[seeds_index];
            }
        }

        pda.bump_seed[0] = 255;
        seeds_with_bump[seeds.len] = &pda.bump_seed;

        while (pda.bump_seed[0] >= 0) : (pda.bump_seed[0] -= 1) {
            pda = ProgramDerivedAddress{
                .address = PublicKey.createProgramAddress(&seeds_with_bump, program_id) catch {
                    if (pda.bump_seed[0] == 0) {
                        return error.NoViableBumpSeed;
                    }
                    continue;
                },
                .bump_seed = pda.bump_seed,
            };

            break;
        }

        return pda;
    }

    /// Create a program address using pure SHA256 computation.
    /// Runtime version that accepts a slice of slices for seeds.
    pub fn createProgramAddressSlice(seeds: []const []const u8, program_id: PublicKey) !PublicKey {
        if (seeds.len > PublicKey.max_num_seeds) {
            return error.MaxSeedLengthExceeded;
        }

        for (seeds) |seed| {
            if (seed.len > PublicKey.max_seed_length) {
                return error.MaxSeedLengthExceeded;
            }
        }

        var address: PublicKey = undefined;

        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        for (seeds) |seed| {
            hasher.update(seed);
        }
        hasher.update(&program_id.bytes);
        hasher.update("ProgramDerivedAddress");
        hasher.final(&address.bytes);

        if (address.isPointOnCurve()) {
            return error.InvalidSeeds;
        }

        return address;
    }

    /// Find a program address and bump seed using pure computation.
    /// Runtime version that accepts a slice of slices for seeds.
    pub fn findProgramAddressSlice(seeds: []const []const u8, program_id: PublicKey) !ProgramDerivedAddress {
        if (seeds.len >= PublicKey.max_num_seeds) {
            return error.MaxSeedLengthExceeded;
        }

        // Create seeds array with space for bump seed
        var seeds_with_bump: [PublicKey.max_num_seeds][]const u8 = undefined;
        for (seeds, 0..) |seed, i| {
            seeds_with_bump[i] = seed;
        }

        var bump_seed: [1]u8 = .{255};
        seeds_with_bump[seeds.len] = &bump_seed;

        while (true) {
            const result = PublicKey.createProgramAddressSlice(seeds_with_bump[0 .. seeds.len + 1], program_id) catch {
                if (bump_seed[0] == 0) {
                    return error.NoViableBumpSeed;
                }
                bump_seed[0] -= 1;
                continue;
            };

            return ProgramDerivedAddress{
                .address = result,
                .bump_seed = bump_seed,
            };
        }
    }

    pub fn jsonStringify(self: PublicKey, options: anytype, writer: anytype) !void {
        _ = options;
        try writer.print("\"{f}\"", .{self});
    }

    /// Format for std.fmt (Zig 0.15+ signature)
    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        var buffer: [base58.bitcoin.getEncodedLengthUpperBound(PublicKey.length)]u8 = undefined;
        try writer.print("{s}", .{base58.bitcoin.encode(&buffer, &self.bytes)});
    }

    // ========================================================================
    // Rust API Compatibility Aliases
    // ========================================================================

    /// Alias for `from` - matches Rust `Address::new_from_array`
    /// Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/address/src/lib.rs
    pub const newFromArray = from;

    /// Get the bytes as a fixed-size array - matches Rust `Address::to_bytes`
    /// Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/address/src/lib.rs
    pub fn toBytes(self: PublicKey) [32]u8 {
        return self.bytes;
    }

    /// Alias for `from` - alternative name matching common Rust pattern
    pub const fromBytes = from;

    /// Alias for `asBytes` - matches Rust `AsRef<[u8]>` trait implementation
    pub const asRef = asBytes;

    // ========================================================================
    // CreateWithSeed
    // ========================================================================

    /// PDA marker used to detect illegal owner in createWithSeed
    const PDA_MARKER: []const u8 = "ProgramDerivedAddress";

    /// Create a derived address from a base address, seed string, and owner program.
    ///
    /// This is used by SystemProgram::CreateAccountWithSeed instruction.
    ///
    /// Rust equivalent: `Address::create_with_seed(base, seed, owner)`
    /// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address/src/lib.rs
    ///
    /// # Arguments
    /// * `base` - The base address (usually the funding account)
    /// * `seed` - A string seed (max 32 bytes)
    /// * `owner` - The program that will own the derived account
    ///
    /// # Returns
    /// The derived address, or error if:
    /// - seed exceeds MAX_SEED_LEN (32 bytes)
    /// - owner ends with PDA_MARKER (illegal owner)
    pub fn createWithSeed(base: PublicKey, seed: []const u8, owner: PublicKey) !PublicKey {
        // Check seed length
        if (seed.len > max_seed_length) {
            return error.MaxSeedLengthExceeded;
        }

        // Check for illegal owner (owner ending with PDA_MARKER)
        // This prevents using a PDA as owner, which would be confusing
        const owner_bytes = &owner.bytes;
        if (owner_bytes.len >= PDA_MARKER.len) {
            const suffix = owner_bytes[owner_bytes.len - PDA_MARKER.len ..];
            if (mem.eql(u8, suffix, PDA_MARKER)) {
                return error.IllegalOwner;
            }
        }

        // Hash: base + seed + owner
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(&base.bytes);
        hasher.update(seed);
        hasher.update(&owner.bytes);

        var result: PublicKey = undefined;
        hasher.final(&result.bytes);
        return result;
    }

    /// Comptime version of createWithSeed
    /// Note: Requires @setEvalBranchQuota for SHA256 computation at comptime.
    pub fn comptimeCreateWithSeed(comptime base: PublicKey, comptime seed: []const u8, comptime owner: PublicKey) PublicKey {
        @setEvalBranchQuota(100_000);
        comptime {
            return createWithSeed(base, seed, owner) catch |err| {
                @compileError("Failed to create address with seed: " ++ @errorName(err));
            };
        }
    }
};

test "public_key: comptime create program address" {
    const id = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const address = comptime PublicKey.comptimeCreateProgramAddress(.{ "hello", &.{255} }, id);
    try testing.expectFmt("2PjSSVURwJV4o9wz1BDVwwddvcUCuF1NKFpcQBF9emYJ", "{f}", .{address});
}

test "public_key: create program address" {
    const id = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const address = try PublicKey.createProgramAddress(.{ "hello", &.{255} }, id);
    try testing.expectFmt("2PjSSVURwJV4o9wz1BDVwwddvcUCuF1NKFpcQBF9emYJ", "{f}", .{address});
}

test "public_key: comptime find program address" {
    const id = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const pda = comptime PublicKey.comptimeFindProgramAddress(.{"hello"}, id);
    try testing.expectFmt("2PjSSVURwJV4o9wz1BDVwwddvcUCuF1NKFpcQBF9emYJ", "{f}", .{pda.address});
    try comptime testing.expectEqual(@as(u8, 255), pda.bump_seed[0]);
}

test "public_key: find program address" {
    const id = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const pda = try PublicKey.findProgramAddress(.{"hello"}, id);
    try testing.expectFmt("2PjSSVURwJV4o9wz1BDVwwddvcUCuF1NKFpcQBF9emYJ", "{f}", .{pda.address});
    try testing.expectEqual(@as(u8, 255), pda.bump_seed[0]);
}

test "public_key: equality" {
    const id = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const id2 = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    try testing.expectEqual(id, id2);
    try testing.expect(id.equals(id2));
}

test "public_key: new_unique generates different keys" {
    const key1 = PublicKey.newUnique();
    const key2 = PublicKey.newUnique();
    try testing.expect(!key1.equals(key2));
}

test "public_key: fromBase58 parsing" {
    const original = PublicKey.from([_]u8{
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
    });

    var buffer: [PublicKey.max_base58_len]u8 = undefined;
    const encoded = original.toBase58(&buffer);

    const parsed = try PublicKey.fromBase58(encoded);
    try testing.expectEqualSlices(u8, &original.bytes, &parsed.bytes);

    var long_str: [PublicKey.max_base58_len * 2]u8 = undefined;
    @memcpy(long_str[0..encoded.len], encoded);
    @memcpy(long_str[encoded.len .. encoded.len * 2], encoded);
    try testing.expectError(error.WrongSize, PublicKey.fromBase58(long_str[0 .. encoded.len * 2]));

    try testing.expectError(error.Invalid, PublicKey.fromBase58("I am not base58"));
}

test "public_key: program addresses are off curve" {
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");

    const address = try PublicKey.createProgramAddress(.{ "", &.{1} }, program_id);
    try testing.expect(!address.isPointOnCurve());

    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        const addr = PublicKey.createProgramAddress(.{ &[_]u8{i}, &.{0} }, program_id) catch continue;
        try testing.expect(!addr.isPointOnCurve());
    }
}

test "public_key: as_array" {
    const bytes = [_]u8{1} ** PublicKey.length;
    const key = PublicKey.from(bytes);

    try testing.expectEqualSlices(u8, &bytes, key.asArray());
    try testing.expectEqual(@intFromPtr(&key.bytes), @intFromPtr(key.asArray()));
}

test "public_key: equality matches byte comparison" {
    const p1 = PublicKey.from([_]u8{42} ** PublicKey.length);
    const p2 = PublicKey.from([_]u8{42} ** PublicKey.length);
    try testing.expect(p1.equals(p2));
    try testing.expectEqualSlices(u8, &p1.bytes, &p2.bytes);

    const p3 = PublicKey.from([_]u8{100} ** PublicKey.length);
    try testing.expect(!p1.equals(p3));
    try testing.expect(!std.mem.eql(u8, &p1.bytes, &p3.bytes));
}

test "public_key: create program address with various seeds" {
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");
    const public_key = comptime PublicKey.comptimeFromBase58("SeedPubey1111111111111111111111111111111111");

    const addr1 = try PublicKey.createProgramAddress(.{ "", &.{1} }, program_id);
    try testing.expectFmt("BwqrghZA2htAcqq8dzP1WDAhTXYTYWj7CHxF5j7TDBAe", "{f}", .{addr1});

    const addr2 = try PublicKey.createProgramAddress(.{ "☉", &.{0} }, program_id);
    try testing.expectFmt("13yWmRpaTR4r5nAktwLqMpRNr28tnVUZw26rTvPSSB19", "{f}", .{addr2});

    const addr3 = try PublicKey.createProgramAddress(.{ "Talking", "Squirrels" }, program_id);
    try testing.expectFmt("2fnQrngrQT4SeLcdToJAD96phoEjNL2man2kfRLCASVk", "{f}", .{addr3});

    const addr4 = try PublicKey.createProgramAddress(.{ &public_key.bytes, &.{1} }, program_id);
    try testing.expectFmt("976ymqVnfE32QFe6NfGDctSvVa36LWnvYxhU6G2232YL", "{f}", .{addr4});

    const addr5 = try PublicKey.createProgramAddress(.{"Talking"}, program_id);
    try testing.expect(!addr3.equals(addr5));
}

test "public_key: createProgramAddress with PublicKey seed auto-conversion" {
    // Test that PublicKey seeds are automatically converted to bytes
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");
    const seed_key = comptime PublicKey.comptimeFromBase58("SeedPubey1111111111111111111111111111111111");

    // Method 1: Manual conversion (old way)
    const addr_manual = try PublicKey.createProgramAddress(.{ &seed_key.bytes, &.{1} }, program_id);

    // Method 2: Auto conversion (new way - PublicKey directly)
    const addr_auto = try PublicKey.createProgramAddress(.{ seed_key, &.{1} }, program_id);

    // Both should produce the same result
    try testing.expect(addr_manual.equals(addr_auto));
    try testing.expectFmt("976ymqVnfE32QFe6NfGDctSvVa36LWnvYxhU6G2232YL", "{f}", .{addr_auto});
}

test "public_key: createProgramAddress with mixed seed types" {
    // Test mixing PublicKey and []const u8 seeds
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");
    const seed_key = comptime PublicKey.comptimeFromBase58("SeedPubey1111111111111111111111111111111111");

    // Mixed seeds: PublicKey + string + bump byte
    // Using bump=254 which produces a valid off-curve address
    const addr = try PublicKey.createProgramAddress(.{ seed_key, "Talking", &.{254} }, program_id);

    // Verify it matches manual conversion
    const addr_manual = try PublicKey.createProgramAddress(.{ &seed_key.bytes, "Talking", &.{254} }, program_id);
    try testing.expect(addr.equals(addr_manual));
}

test "public_key: createProgramAddress with multiple PublicKey seeds" {
    const program_id = comptime PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");
    const key1 = comptime PublicKey.comptimeFromBase58("SeedPubey1111111111111111111111111111111111");
    const key2 = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111112");

    // Two PublicKey seeds
    const addr = try PublicKey.createProgramAddress(.{ key1, key2 }, program_id);

    // Verify it matches manual conversion
    const addr_manual = try PublicKey.createProgramAddress(.{ &key1.bytes, &key2.bytes }, program_id);
    try testing.expect(addr.equals(addr_manual));
}

// ============================================================================
// CreateWithSeed Tests
// ============================================================================

test "public_key: createWithSeed basic" {
    // Test case from Rust: create_with_seed(&Address::default(), "limber chicken: 4/45", &Address::default())
    // Expected: "9h1HyLCW5dZnBVap8C5egQ9Z6pHyjsh5MNy83iPqqRuq"
    const base = PublicKey.default();
    const owner = PublicKey.default();
    const seed = "limber chicken: 4/45";

    const result = try PublicKey.createWithSeed(base, seed, owner);
    try testing.expectFmt("9h1HyLCW5dZnBVap8C5egQ9Z6pHyjsh5MNy83iPqqRuq", "{f}", .{result});
}

test "public_key: createWithSeed empty seed" {
    const base = PublicKey.newUnique();
    const owner = PublicKey.newUnique();

    // Empty seed should work
    const result = PublicKey.createWithSeed(base, "", owner);
    try testing.expect(result != error.MaxSeedLengthExceeded);
}

test "public_key: createWithSeed max length seed" {
    const base = PublicKey.newUnique();
    const owner = PublicKey.newUnique();

    // Max length seed (32 bytes) should work
    const max_seed = [_]u8{0} ** PublicKey.max_seed_length;
    const result = PublicKey.createWithSeed(base, &max_seed, owner);
    try testing.expect(result != error.MaxSeedLengthExceeded);
}

test "public_key: createWithSeed rejects seed too long" {
    const base = PublicKey.newUnique();
    const owner = PublicKey.newUnique();

    // Seed exceeding 32 bytes should fail
    const long_seed = [_]u8{127} ** (PublicKey.max_seed_length + 1);
    try testing.expectError(error.MaxSeedLengthExceeded, PublicKey.createWithSeed(base, &long_seed, owner));
}

test "public_key: createWithSeed unicode seed" {
    const base = PublicKey.newUnique();
    const owner = PublicKey.newUnique();

    // Unicode seed should work (as long as byte length <= 32)
    const result = PublicKey.createWithSeed(base, "☉", owner);
    try testing.expect(result != error.MaxSeedLengthExceeded);
}

test "public_key: createWithSeed rejects illegal owner (PDA marker)" {
    const base = PublicKey.newUnique();

    // Create an owner that ends with PDA_MARKER - this should be rejected
    // PDA_MARKER is "ProgramDerivedAddress" (21 bytes)
    // We need to create a 32-byte pubkey that ends with this marker
    var illegal_owner_bytes: [32]u8 = undefined;
    @memset(&illegal_owner_bytes, 0);
    const marker = "ProgramDerivedAddress";
    @memcpy(illegal_owner_bytes[32 - marker.len ..], marker);
    const illegal_owner = PublicKey.from(illegal_owner_bytes);

    try testing.expectError(error.IllegalOwner, PublicKey.createWithSeed(base, "test", illegal_owner));
}

test "public_key: createWithSeed accepts owner not ending with PDA marker" {
    const base = PublicKey.newUnique();

    // Owner that doesn't end with PDA marker should work
    // Use a partial marker suffix - should be accepted
    var owner_bytes: [32]u8 = undefined;
    @memset(&owner_bytes, 0);
    const partial_marker = "rogramDerivedAddress"; // Missing first char
    @memcpy(owner_bytes[32 - partial_marker.len ..], partial_marker);
    const owner = PublicKey.from(owner_bytes);

    const result = PublicKey.createWithSeed(base, "test", owner);
    try testing.expect(result != error.IllegalOwner);
}

test "public_key: comptimeCreateWithSeed" {
    const base = comptime PublicKey.default();
    const owner = comptime PublicKey.default();
    const result = comptime PublicKey.comptimeCreateWithSeed(base, "limber chicken: 4/45", owner);
    try testing.expectFmt("9h1HyLCW5dZnBVap8C5egQ9Z6pHyjsh5MNy83iPqqRuq", "{f}", .{result});
}

// ============================================================================
// API Alias Tests
// ============================================================================

test "public_key: toBytes returns copy of bytes" {
    const bytes = [_]u8{42} ** PublicKey.length;
    const key = PublicKey.from(bytes);
    const result = key.toBytes();
    try testing.expectEqualSlices(u8, &bytes, &result);
}

test "public_key: newFromArray alias works" {
    const bytes = [_]u8{123} ** PublicKey.length;
    const key1 = PublicKey.from(bytes);
    const key2 = PublicKey.newFromArray(bytes);
    try testing.expect(key1.equals(key2));
}

test "public_key: fromBytes alias works" {
    const bytes = [_]u8{99} ** PublicKey.length;
    const key1 = PublicKey.from(bytes);
    const key2 = PublicKey.fromBytes(bytes);
    try testing.expect(key1.equals(key2));
}

test "public_key: asRef alias works" {
    const bytes = [_]u8{77} ** PublicKey.length;
    const key = PublicKey.from(bytes);
    const slice1 = key.asBytes();
    const slice2 = key.asRef();
    try testing.expectEqualSlices(u8, slice1, slice2);
}
