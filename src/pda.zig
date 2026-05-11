//! Program Derived Address (PDA) computation
//!
//! Provides functions for creating and finding program derived addresses.

const std = @import("std");
const pubkey = @import("pubkey.zig");
const program_error = @import("program_error.zig");
const bpf = @import("bpf.zig");

const Pubkey = pubkey.Pubkey;
const ProgramError = program_error.ProgramError;
const ProgramResult = program_error.ProgramResult;

/// Maximum number of seeds for PDA derivation
pub const MAX_SEEDS: usize = 16;

/// Maximum length of a seed for PDA derivation
pub const MAX_SEED_LEN: usize = 32;

/// PDA computation result
pub const ProgramDerivedAddress = struct {
    address: Pubkey,
    bump_seed: u8,
};

// =============================================================================
// Syscalls (only available in BPF runtime)
// =============================================================================

extern fn sol_create_program_address(
    seeds_ptr: [*]const []const u8,
    seeds_len: u64,
    program_id_ptr: *const Pubkey,
    address_ptr: *Pubkey,
) callconv(.c) u64;

extern fn sol_try_find_program_address(
    seeds_ptr: [*]const []const u8,
    seeds_len: u64,
    program_id_ptr: *const Pubkey,
    address_ptr: *Pubkey,
    bump_seed_ptr: *u8,
) callconv(.c) u64;

// =============================================================================
// PDA Functions
// =============================================================================

/// Create a program address from seeds and a program ID
///
/// Returns error.InvalidSeeds if the address is on the Curve25519 curve
/// (i.e., not a valid PDA).
pub fn createProgramAddress(
    seeds: []const []const u8,
    program_id: *const Pubkey,
) ProgramError!Pubkey {
    if (seeds.len > MAX_SEEDS) {
        return ProgramError.MaxSeedLengthExceeded;
    }
    for (seeds) |seed| {
        if (seed.len > MAX_SEED_LEN) {
            return ProgramError.MaxSeedLengthExceeded;
        }
    }

    if (bpf.is_bpf_program) {
        // `seeds.len` is runtime, so we cannot size the local array with
        // it. Use a fixed-size stack buffer of MAX_SEEDS and slice it.
        var seeds_array: [MAX_SEEDS][]const u8 = undefined;
        for (seeds, 0..) |seed, i| {
            seeds_array[i] = seed;
        }
        var address: Pubkey = undefined;

        const result = sol_create_program_address(
            seeds_array[0..seeds.len].ptr,
            seeds.len,
            program_id,
            &address,
        );
        if (result != 0) {
            return ProgramError.InvalidSeeds;
        }
        return address;
    }

    // Host implementation using SHA-256
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    for (seeds) |seed| {
        hasher.update(seed);
    }
    hasher.update(program_id);
    hasher.update("ProgramDerivedAddress");

    var address: Pubkey = undefined;
    hasher.final(&address);

    if (pubkey.isPointOnCurve(&address)) {
        return ProgramError.InvalidSeeds;
    }

    return address;
}

/// Find a valid program address with a bump seed
///
/// Iterates through bump seeds 255..0 to find one that produces
/// a valid PDA (not on the Curve25519 curve).
pub fn findProgramAddress(
    seeds: []const []const u8,
    program_id: *const Pubkey,
) ProgramError!ProgramDerivedAddress {
    if (bpf.is_bpf_program) {
        if (seeds.len > MAX_SEEDS) {
            return ProgramError.MaxSeedLengthExceeded;
        }
        var seeds_array: [MAX_SEEDS][]const u8 = undefined;
        for (seeds, 0..) |seed, i| {
            seeds_array[i] = seed;
        }
        var pda: ProgramDerivedAddress = undefined;

        const result = sol_try_find_program_address(
            seeds_array[0..seeds.len].ptr,
            seeds.len,
            program_id,
            &pda.address,
            &pda.bump_seed,
        );
        if (result != 0) {
            return ProgramError.InvalidSeeds;
        }
        return pda;
    }

    // Host implementation
    var bump_seed: u8 = 255;
    while (true) : (bump_seed -= 1) {
        const bump_seed_slice: []const u8 = &.{bump_seed};

        var seeds_with_bump: [16][]const u8 = undefined;
        for (seeds, 0..) |seed, i| {
            seeds_with_bump[i] = seed;
        }
        seeds_with_bump[seeds.len] = bump_seed_slice;

        const address = createProgramAddress(
            seeds_with_bump[0 .. seeds.len + 1],
            program_id,
        ) catch {
            if (bump_seed == 0) {
                return ProgramError.InvalidSeeds;
            }
            continue;
        };

        return ProgramDerivedAddress{
            .address = address,
            .bump_seed = bump_seed,
        };
    }
}

/// Create a program address with a specific seed string
pub fn createWithSeed(
    base: *const Pubkey,
    seed: []const u8,
    program_id: *const Pubkey,
) ProgramError!Pubkey {
    if (seed.len > MAX_SEED_LEN) {
        return ProgramError.MaxSeedLengthExceeded;
    }

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(base);
    hasher.update(seed);
    hasher.update(program_id);

    var address: Pubkey = undefined;
    hasher.final(&address);

    return address;
}

/// Compile-time `createWithSeed`.
///
/// Computes `SHA-256(base || seed || program_id)` at build time, when
/// all three inputs are compile-time-known. Useful for fixed
/// `create_account_with_seed` derivations (e.g. nonce accounts owned
/// by a known base pubkey).
///
/// No bump search is involved — the result is unconditionally returned.
pub fn comptimeCreateWithSeed(
    comptime base: Pubkey,
    comptime seed: []const u8,
    comptime program_id: Pubkey,
) Pubkey {
    return comptime blk: {
        if (seed.len > MAX_SEED_LEN) {
            @compileError("seed exceeds MAX_SEED_LEN");
        }
        @setEvalBranchQuota(1_000_000);
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(&base);
        hasher.update(seed);
        hasher.update(&program_id);

        var address: Pubkey = undefined;
        hasher.final(&address);
        break :blk address;
    };
}

/// Compile-time `createProgramAddress`.
///
/// Computes the PDA at compile time from a tuple of byte-slice seeds
/// and a fixed `program_id`. Emits a `@compileError` if the derived
/// address lands on the Ed25519 curve (i.e. is not a valid PDA — pass
/// a different bump or use `comptimeFindProgramAddress`).
///
/// All seeds must be comptime-known. Typical use:
/// ```zig
/// const VAULT_PDA = pda.comptimeCreateProgramAddress(
///     .{ "vault", &[_]u8{bump} },
///     MY_PROGRAM_ID,
/// );
/// ```
pub fn comptimeCreateProgramAddress(
    comptime seeds: anytype,
    comptime program_id: Pubkey,
) Pubkey {
    return comptime blk: {
        @setEvalBranchQuota(10_000_000);
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        for (seeds) |seed| {
            hasher.update(seed);
        }
        hasher.update(&program_id);
        hasher.update("ProgramDerivedAddress");

        var address: Pubkey = undefined;
        hasher.final(&address);

        if (pubkey.isPointOnCurve(&address)) {
            @compileError("Address is on curve, not a valid PDA");
        }

        break :blk address;
    };
}

/// Compile-time `findProgramAddress`.
///
/// Walks `bump = 255..0` until the SHA-256 of `seeds || bump ||
/// program_id || "ProgramDerivedAddress"` is off-curve, all at compile
/// time. Returns `{ address, bump_seed }` as plain constants.
///
/// This completely eliminates the `sol_try_find_program_address`
/// syscall (~1500 CU) when the PDA's seeds are statically known —
/// common for "self-owned" PDAs like a singleton vault.
///
/// All seeds must be comptime-known. Typical use:
/// ```zig
/// const VAULT = pda.comptimeFindProgramAddress(.{ "vault" }, MY_PROGRAM_ID);
/// // VAULT.address and VAULT.bump_seed are plain compile-time values.
/// ```
pub fn comptimeFindProgramAddress(
    comptime seeds: anytype,
    comptime program_id: Pubkey,
) ProgramDerivedAddress {
    return comptime blk: {
        @setEvalBranchQuota(10_000_000);
        var bump_seed: u8 = 255;
        while (true) : (bump_seed -= 1) {
            var hasher = std.crypto.hash.sha2.Sha256.init(.{});
            for (seeds) |seed| {
                hasher.update(seed);
            }
            hasher.update(&[_]u8{bump_seed});
            hasher.update(&program_id);
            hasher.update("ProgramDerivedAddress");

            var address: Pubkey = undefined;
            hasher.final(&address);

            if (!pubkey.isPointOnCurve(&address)) {
                break :blk ProgramDerivedAddress{
                    .address = address,
                    .bump_seed = bump_seed,
                };
            }

            if (bump_seed == 0) {
                @compileError("Failed to find valid PDA bump seed");
            }
        }
    };
}

// =============================================================================
// Tests
// =============================================================================

test "pda: create program address" {
    const program_id = pubkey.comptimeFromBase58("11111111111111111111111111111111");
    const address = try createProgramAddress(&.{
        "hello",
        &.{255},
    }, &program_id);
    _ = address;
}

test "pda: find program address" {
    const program_id = pubkey.comptimeFromBase58("11111111111111111111111111111111");
    const pda = try findProgramAddress(&.{"hello"}, &program_id);
    _ = pda;
}

test "pda: create with seed" {
    const base = pubkey.comptimeFromBase58("11111111111111111111111111111111");
    const program_id = pubkey.comptimeFromBase58("11111111111111111111111111111111");
    const address = try createWithSeed(&base, "seed", &program_id);
    _ = address;
}

test "pda: comptime find matches runtime find" {
    const program_id: Pubkey = .{0} ** 32; // System Program
    const ct = comptimeFindProgramAddress(.{"vault"}, program_id);
    const rt = try findProgramAddress(&.{"vault"}, &program_id);
    try std.testing.expectEqualSlices(u8, &ct.address, &rt.address);
    try std.testing.expectEqual(rt.bump_seed, ct.bump_seed);
}

test "pda: comptime find produces known address (cross-check)" {
    // Cross-verified against `python -m hashlib` and Solana's
    // Pubkey::find_program_address: for seed "vault" against the
    // System Program ID, the canonical PDA has bump = 254 and address
    // 3d467e29e4663a956c3aa851857d888f6032c4d7606825a4ab75f2e0a932a0d2.
    const program_id: Pubkey = .{0} ** 32;
    const pda = comptimeFindProgramAddress(.{"vault"}, program_id);

    try std.testing.expectEqual(@as(u8, 254), pda.bump_seed);
    const expected_hex = "3d467e29e4663a956c3aa851857d888f6032c4d7606825a4ab75f2e0a932a0d2";
    var expected: Pubkey = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_hex);
    try std.testing.expectEqualSlices(u8, &expected, &pda.address);
}

test "pda: comptime createWithSeed matches runtime" {
    const base: Pubkey = .{1} ** 32;
    const program_id: Pubkey = .{2} ** 32;
    const seed = "nonce";

    const ct = comptimeCreateWithSeed(base, seed, program_id);
    const rt = try createWithSeed(&base, seed, &program_id);
    try std.testing.expectEqualSlices(u8, &ct, &rt);
}

test "pda: comptime create matches runtime create" {
    const program_id: Pubkey = .{0} ** 32;
    const seeds = .{ "vault", &[_]u8{254} };

    const ct = comptimeCreateProgramAddress(seeds, program_id);
    const rt = try createProgramAddress(
        &.{ "vault", &[_]u8{254} },
        &program_id,
    );
    try std.testing.expectEqualSlices(u8, &ct, &rt);
}
