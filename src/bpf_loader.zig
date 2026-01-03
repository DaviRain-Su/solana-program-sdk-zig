//! Zig implementation of Solana SDK's BPF loader program IDs
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/sdk-ids/src/lib.rs
//!
//! This module provides the program IDs for Solana's BPF loaders.
//! BPF loaders are responsible for deploying and executing on-chain programs.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;

/// BPF Loader v1 (deprecated)
///
/// The original BPF loader, now deprecated in favor of v2 and upgradeable.
/// Programs deployed with this loader cannot be upgraded.
///
/// Rust equivalent: `solana_sdk::bpf_loader_deprecated::id()`
pub const bpf_loader_deprecated_id = PublicKey.comptimeFromBase58("BPFLoader1111111111111111111111111111111111");

/// BPF Loader v2
///
/// The standard BPF loader for non-upgradeable programs.
/// Programs deployed with this loader are immutable.
///
/// Rust equivalent: `solana_sdk::bpf_loader::id()`
pub const bpf_loader_id = PublicKey.comptimeFromBase58("BPFLoader2111111111111111111111111111111111");

/// BPF Loader Upgradeable
///
/// The upgradeable BPF loader that allows programs to be upgraded.
/// Most modern Solana programs use this loader.
///
/// Rust equivalent: `solana_sdk::bpf_loader_upgradeable::id()`
pub const bpf_loader_upgradeable_id = PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");

/// Check if a program ID is one of the BPF loaders
pub fn isBpfLoader(program_id: PublicKey) bool {
    return program_id.equals(bpf_loader_deprecated_id) or
        program_id.equals(bpf_loader_id) or
        program_id.equals(bpf_loader_upgradeable_id);
}

/// Check if a program ID is the upgradeable loader
pub fn isUpgradeableLoader(program_id: PublicKey) bool {
    return program_id.equals(bpf_loader_upgradeable_id);
}

/// Upgradeable Loader State types
///
/// Rust equivalent: `solana_sdk::bpf_loader_upgradeable::UpgradeableLoaderState`
pub const UpgradeableLoaderState = union(enum) {
    /// Account is not initialized
    uninitialized,

    /// A Buffer account stores the program data while it's being deployed
    buffer: struct {
        /// Authority address that can write to the buffer
        authority_address: ?PublicKey,
    },

    /// An executable Program account
    program: struct {
        /// Address of the ProgramData account
        programdata_address: PublicKey,
    },

    /// A ProgramData account stores the program data and upgrade authority
    program_data: struct {
        /// Slot that the program was last modified
        slot: u64,
        /// Optional upgrade authority address. If None, the program is immutable.
        upgrade_authority_address: ?PublicKey,
    },
};

/// Size of UpgradeableLoaderState::Uninitialized
pub const UPGRADEABLE_LOADER_STATE_UNINITIALIZED_SIZE: usize = 4;

/// Size of UpgradeableLoaderState::Buffer (without program data)
pub const UPGRADEABLE_LOADER_STATE_BUFFER_SIZE: usize = 37;

/// Size of UpgradeableLoaderState::Program
pub const UPGRADEABLE_LOADER_STATE_PROGRAM_SIZE: usize = 36;

/// Size of UpgradeableLoaderState::ProgramData (without program data)
pub const UPGRADEABLE_LOADER_STATE_PROGRAMDATA_SIZE: usize = 45;

/// Derive the program address for an upgradeable program's data account
///
/// The ProgramData account address is derived from the program ID.
pub fn getProgramDataAddress(program_id: PublicKey) !struct { address: PublicKey, bump: u8 } {
    const seeds = [_][]const u8{&program_id.bytes};
    return try PublicKey.findProgramAddress(&seeds, bpf_loader_upgradeable_id);
}

// ============================================================================
// Tests
// ============================================================================

test "bpf_loader: program IDs are correct length" {
    try std.testing.expectEqual(@as(usize, 32), bpf_loader_deprecated_id.bytes.len);
    try std.testing.expectEqual(@as(usize, 32), bpf_loader_id.bytes.len);
    try std.testing.expectEqual(@as(usize, 32), bpf_loader_upgradeable_id.bytes.len);
}

test "bpf_loader: isBpfLoader check" {
    try std.testing.expect(isBpfLoader(bpf_loader_deprecated_id));
    try std.testing.expect(isBpfLoader(bpf_loader_id));
    try std.testing.expect(isBpfLoader(bpf_loader_upgradeable_id));

    // System program should not be a BPF loader
    const system_id = PublicKey.from([_]u8{0} ** 32);
    try std.testing.expect(!isBpfLoader(system_id));
}

test "bpf_loader: isUpgradeableLoader check" {
    try std.testing.expect(isUpgradeableLoader(bpf_loader_upgradeable_id));
    try std.testing.expect(!isUpgradeableLoader(bpf_loader_id));
    try std.testing.expect(!isUpgradeableLoader(bpf_loader_deprecated_id));
}

test "bpf_loader: state sizes are correct" {
    // These match the Rust SDK sizes
    try std.testing.expectEqual(@as(usize, 4), UPGRADEABLE_LOADER_STATE_UNINITIALIZED_SIZE);
    try std.testing.expectEqual(@as(usize, 37), UPGRADEABLE_LOADER_STATE_BUFFER_SIZE);
    try std.testing.expectEqual(@as(usize, 36), UPGRADEABLE_LOADER_STATE_PROGRAM_SIZE);
    try std.testing.expectEqual(@as(usize, 45), UPGRADEABLE_LOADER_STATE_PROGRAMDATA_SIZE);
}

test "bpf_loader: loader IDs are different" {
    try std.testing.expect(!bpf_loader_deprecated_id.equals(bpf_loader_id));
    try std.testing.expect(!bpf_loader_id.equals(bpf_loader_upgradeable_id));
    try std.testing.expect(!bpf_loader_deprecated_id.equals(bpf_loader_upgradeable_id));
}
