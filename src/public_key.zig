//! Zig implementation of Solana SDK's pubkey module (Program SDK version)
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/pubkey/src/lib.rs
//!
//! This module re-exports the SDK's PublicKey type and adds syscall-accelerated
//! PDA derivation functions for on-chain programs.
//!
//! For off-chain use, the SDK's pure SHA256-based PDA functions work identically.
//! For on-chain use, the syscall versions are more efficient.

const std = @import("std");
const sdk = @import("solana_sdk");

// Re-export the SDK's PublicKey type
pub const PublicKey = sdk.PublicKey;
pub const ProgramDerivedAddress = sdk.ProgramDerivedAddress;
pub const base58_mod = sdk.public_key.base58_mod;

// Syscalls for on-chain PDA derivation
const syscalls = @import("syscalls.zig");
const log = @import("log.zig");

/// Create a program address using syscall (on-chain) or pure computation (off-chain).
///
/// This function uses the Solana runtime syscall when running on-chain for efficiency,
/// and falls back to pure SHA256 computation for off-chain/testing use.
pub fn createProgramAddress(seeds: anytype, program_id: PublicKey) !PublicKey {
    if (seeds.len > PublicKey.max_num_seeds) {
        return error.MaxSeedLengthExceeded;
    }

    comptime var seeds_index = 0;
    inline while (seeds_index < seeds.len) : (seeds_index += 1) {
        if (@as([]const u8, seeds[seeds_index]).len > PublicKey.max_seed_length) {
            return error.MaxSeedLengthExceeded;
        }
    }

    var address: PublicKey = undefined;

    if (syscalls.is_bpf_program) {
        var seeds_array: [seeds.len][]const u8 = undefined;
        inline for (seeds, 0..) |seed, i| seeds_array[i] = seed;

        const result = syscalls.sol_create_program_address(
            @ptrCast(&seeds_array),
            seeds.len,
            &program_id.bytes,
            &address.bytes,
        );
        if (result != 0) {
            log.print("failed to create program address: error code {d}", .{result});
            return error.Unexpected;
        }

        return address;
    }

    // Off-chain: use SDK's pure implementation
    return sdk.PublicKey.createProgramAddress(seeds, program_id);
}

/// Find a program address and bump seed using syscall (on-chain) or pure computation (off-chain).
///
/// This function uses the Solana runtime syscall when running on-chain for efficiency,
/// and falls back to pure computation for off-chain/testing use.
pub fn findProgramAddress(seeds: anytype, program_id: PublicKey) !ProgramDerivedAddress {
    var pda: ProgramDerivedAddress = undefined;

    if (comptime syscalls.is_bpf_program) {
        var seeds_array: [seeds.len][]const u8 = undefined;

        comptime var seeds_index = 0;
        inline while (seeds_index < seeds.len) : (seeds_index += 1) {
            const Seed = @TypeOf(seeds[seeds_index]);
            if (comptime Seed == PublicKey) {
                seeds_array[seeds_index] = &seeds[seeds_index].bytes;
            } else {
                seeds_array[seeds_index] = seeds[seeds_index];
            }
        }

        const result = syscalls.sol_try_find_program_address(
            @ptrCast(&seeds_array),
            seeds.len,
            &program_id.bytes,
            &pda.address.bytes,
            &pda.bump_seed[0],
        );
        if (result != 0) {
            log.print("failed to find program address: error code {d}", .{result});
            return error.Unexpected;
        }

        return pda;
    }

    // Off-chain: use SDK's pure implementation
    return sdk.PublicKey.findProgramAddress(seeds, program_id);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "public_key: comptime create program address" {
    const id = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const address = comptime PublicKey.comptimeCreateProgramAddress(.{ "hello", &.{255} }, id);
    try testing.expectFmt("2PjSSVURwJV4o9wz1BDVwwddvcUCuF1NKFpcQBF9emYJ", "{f}", .{address});
}

test "public_key: create program address" {
    const id = comptime PublicKey.comptimeFromBase58("11111111111111111111111111111111");
    const address = try createProgramAddress(.{ "hello", &.{255} }, id);
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
    const pda = try findProgramAddress(.{"hello"}, id);
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

    const address = try createProgramAddress(.{ "", &.{1} }, program_id);
    try testing.expect(!address.isPointOnCurve());

    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        const addr = createProgramAddress(.{ &[_]u8{i}, &.{0} }, program_id) catch continue;
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
    const public_key_seed = comptime PublicKey.comptimeFromBase58("SeedPubey1111111111111111111111111111111111");

    const addr1 = try createProgramAddress(.{ "", &.{1} }, program_id);
    try testing.expectFmt("BwqrghZA2htAcqq8dzP1WDAhTXYTYWj7CHxF5j7TDBAe", "{f}", .{addr1});

    const addr2 = try createProgramAddress(.{ "☉", &.{0} }, program_id);
    try testing.expectFmt("13yWmRpaTR4r5nAktwLqMpRNr28tnVUZw26rTvPSSB19", "{f}", .{addr2});

    const addr3 = try createProgramAddress(.{ "Talking", "Squirrels" }, program_id);
    try testing.expectFmt("2fnQrngrQT4SeLcdToJAD96phoEjNL2man2kfRLCASVk", "{f}", .{addr3});

    const addr4 = try createProgramAddress(.{ &public_key_seed.bytes, &.{1} }, program_id);
    try testing.expectFmt("976ymqVnfE32QFe6NfGDctSvVa36LWnvYxhU6G2232YL", "{f}", .{addr4});

    const addr5 = try createProgramAddress(.{"Talking"}, program_id);
    try testing.expect(!addr3.equals(addr5));
}
