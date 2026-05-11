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
        var address: Pubkey = undefined;
        var seeds_array: [seeds.len][]const u8 = undefined;
        for (seeds, 0..) |seed, i| {
            seeds_array[i] = seed;
        }

        const result = sol_create_program_address(
            &seeds_array,
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
        var pda: ProgramDerivedAddress = undefined;
        var seeds_array: [seeds.len][]const u8 = undefined;
        for (seeds, 0..) |seed, i| {
            seeds_array[i] = seed;
        }

        const result = sol_try_find_program_address(
            &seeds_array,
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

/// Compile-time create program address (pure SHA-256, no BPF syscall)
pub fn comptimeCreateProgramAddress(
    comptime seeds: anytype,
    comptime program_id: Pubkey,
) Pubkey {
    return comptime blk: {
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

/// Compile-time find program address (pure SHA-256, no BPF syscall)
pub fn comptimeFindProgramAddress(
    comptime seeds: anytype,
    comptime program_id: Pubkey,
) ProgramDerivedAddress {
    return comptime blk: {
        var bump_seed: u8 = 255;
        while (true) : (bump_seed -= 1) {
            var hasher = std.crypto.hash.sha2.Sha256.init(.{});
            for (seeds) |seed| {
                hasher.update(seed);
            }
            hasher.update(&.{bump_seed});
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

test "pda: comptime create" {
    // comptime PDA creation - tested via comptimeCreateProgramAddress at usage site
}

test "pda: comptime find" {
    // comptime PDA finding - tested via comptimeFindProgramAddress at usage site
}
