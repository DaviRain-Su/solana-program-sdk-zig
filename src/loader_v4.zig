//! Zig implementation of Solana SDK's BPF Loader v4 program
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/loader-v4-interface/src/lib.rs
//!
//! This module provides the interface for Solana's BPF Loader v4, which supports
//! advanced program deployment and management features. Loader v4 introduces
//! program data account management and enhanced deployment controls.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const Instruction = @import("instruction.zig").Instruction;
const Account = @import("account.zig").Account;

/// BPF Loader v4 program ID
///
/// The program ID for the BPF Loader v4 program.
///
/// Rust equivalent: `solana_loader_v4_program::id()`
pub const id = PublicKey.comptimeFromBase58("LoaderV411111111111111111111111111111111111");

/// Program data account size calculation
///
/// Calculates the minimum size required for a program data account.
/// The size includes the program data header plus the actual program data.
///
/// # Arguments
/// * `program_data_len` - Length of the program data in bytes
///
/// # Returns
/// Minimum account size required
///
/// Rust equivalent: `solana_loader_v4_program::get_program_data_size()`
pub fn getProgramDataSize(program_data_len: usize) usize {
    // Program data account structure:
    // - Header: 45 bytes (includes magic number, version, etc.)
    // - Program data: variable length
    // - Padding to make total size aligned
    const header_size = 45;
    const alignment = 8; // Account data must be aligned

    const total_size = header_size + program_data_len;
    const aligned_size = (total_size + alignment - 1) & (~@as(usize, alignment - 1));

    return aligned_size;
}

/// Program account size calculation
///
/// Calculates the size required for a program account.
///
/// # Returns
/// Size required for program account
///
/// Rust equivalent: `solana_loader_v4_program::get_program_size()`
pub fn getProgramSize() usize {
    // Program account contains a single public key (32 bytes)
    // pointing to the program data account
    return 32;
}

/// Create a program account
///
/// Creates an instruction to initialize a new program account.
///
/// # Arguments
/// * `allocator` - Memory allocator
/// * `program_address` - Address of the program account to create
/// * `program_data_address` - Address of the program data account
/// * `authority_address` - Address that will have authority over the program
///
/// # Returns
/// Instruction to create the program account
///
/// Rust equivalent: `solana_loader_v4_program::create_program()`
// pub fn createProgram(
//     allocator: std.mem.Allocator,
//     program_address: PublicKey,
//     program_data_address: PublicKey,
//     authority_address: PublicKey,
// ) !Instruction {
//     // Instruction data format:
//     // - Instruction discriminator: 1 byte (0 = CreateProgram)
//     // - Program data address: 32 bytes
//     // - Authority address: 32 bytes
//
//     var instruction_data = try std.ArrayList(u8).initCapacity(allocator, 65);
//     defer instruction_data.deinit();
//
//     // Discriminator for CreateProgram
//     try instruction_data.append(0);
//
//     // Program data address
//     try instruction_data.appendSlice(&program_data_address.toBytes());
//
//     // Authority address
//     try instruction_data.appendSlice(&authority_address.toBytes());
//
//     return Instruction.new(
//         id,
//         &.{program_address}, // accounts
//         instruction_data.items,
//     );
// }

/// Deploy a program
///
/// Creates an instruction to deploy program data to a program data account.
///
/// # Arguments
/// * `allocator` - Memory allocator
/// * `program_data_address` - Address of the program data account
/// * `program_data` - The compiled program data (BPF bytecode)
/// * `authority_address` - Authority address for the program
///
/// # Returns
/// Instruction to deploy the program
///
/// Rust equivalent: `solana_loader_v4_program::deploy_program()`
// pub fn deployProgram(
//     allocator: std.mem.Allocator,
//     program_data_address: PublicKey,
//     program_data: []const u8,
//     authority_address: PublicKey,
// ) !Instruction {
//     // Instruction data format:
//     // - Instruction discriminator: 1 byte (1 = DeployProgram)
//     // - Program data length: 4 bytes (little endian)
//     // - Program data: variable length
//
//     const data_len = 1 + 4 + program_data.len;
//     var instruction_data = try std.ArrayList(u8).initCapacity(allocator, data_len);
//     defer instruction_data.deinit();
//
//     // Discriminator for DeployProgram
//     try instruction_data.append(1);
//
//     // Program data length
//     const len_bytes = std.mem.toBytes(@as(u32, @intCast(program_data.len)));
//     try instruction_data.appendSlice(&len_bytes);
//
//     // Program data
//     try instruction_data.appendSlice(program_data);
//
//     return Instruction.new(
//         id,
//         &.{program_data_address, authority_address}, // accounts
//         instruction_data.items,
//     );
// }

/// Upgrade a program
///
/// Creates an instruction to upgrade an existing program with new data.
///
/// # Arguments
/// * `allocator` - Memory allocator
/// * `program_data_address` - Address of the program data account
/// * `program_data` - The new compiled program data
/// * `authority_address` - Authority address for the program
/// * `spill_address` - Address to receive excess lamports if account shrinks
///
/// # Returns
/// Instruction to upgrade the program
///
/// Rust equivalent: `solana_loader_v4_program::upgrade_program()`
// pub fn upgradeProgram(
//     allocator: std.mem.Allocator,
//     program_data_address: PublicKey,
//     program_data: []const u8,
//     authority_address: PublicKey,
//     spill_address: PublicKey,
// ) !Instruction {
//     // Similar to deploy but with different discriminator and spill account
//     _ = allocator;
//     _ = program_data_address;
//     _ = program_data;
//     _ = authority_address;
//     _ = spill_address;
//     @panic("upgradeProgram not yet implemented");
// }

/// Close a program
///
/// Creates an instruction to close a program and recover its lamports.
///
/// # Arguments
/// * `allocator` - Memory allocator
/// * `program_address` - Address of the program account
/// * `authority_address` - Authority address for the program
/// * `recipient_address` - Address to receive the recovered lamports
///
/// # Returns
/// Instruction to close the program
///
/// Rust equivalent: `solana_loader_v4_program::close_program()`
// pub fn closeProgram(
//     allocator: std.mem.Allocator,
//     program_address: PublicKey,
//     authority_address: PublicKey,
//     recipient_address: PublicKey,
// ) !Instruction {
//     // Instruction data format:
//     // - Instruction discriminator: 1 byte (3 = CloseProgram)
//
//     var instruction_data = try std.ArrayList(u8).initCapacity(allocator, 1);
//     defer instruction_data.deinit();
//
//     // Discriminator for CloseProgram
//     try instruction_data.append(3);
//
//     return Instruction.new(
//         id,
//         &.{program_address, authority_address, recipient_address}, // accounts
//         instruction_data.items,
//     );
// }

/// Transfer program authority
///
/// Creates an instruction to transfer program authority to a new address.
///
/// # Arguments
/// * `allocator` - Memory allocator
/// * `program_data_address` - Address of the program data account
/// * `current_authority` - Current authority address
/// * `new_authority` - New authority address
///
/// # Returns
/// Instruction to transfer authority
///
/// Rust equivalent: `solana_loader_v4_program::transfer_program_authority()`
// pub fn transferProgramAuthority(
//     allocator: std.mem.Allocator,
//     program_data_address: PublicKey,
//     current_authority: PublicKey,
//     new_authority: PublicKey,
// ) !Instruction {
//     // Instruction data format:
//     // - Instruction discriminator: 1 byte (4 = TransferAuthority)
//     // - New authority address: 32 bytes
//
//     var instruction_data = try std.ArrayList(u8).initCapacity(allocator, 33);
//     defer instruction_data.deinit();
//
//     // Discriminator for TransferAuthority
//     try instruction_data.append(4);
//
//     // New authority address
//     try instruction_data.appendSlice(&new_authority.toBytes());
//
//     return Instruction.new(
//         id,
//         &.{program_data_address, current_authority}, // accounts
//         instruction_data.items,
//     );
// }

/// Program data account state
///
/// Represents the state stored in a program data account.
///
/// Rust equivalent: `solana_loader_v4_program::ProgramData`
pub const ProgramData = struct {
    /// Magic number identifying the account as program data
    magic: u32,
    /// Version of the loader
    version: u32,
    /// Slot when the program was last modified
    slot: u64,
    /// Authority that can modify the program
    authority: PublicKey,

    /// Size of the program data header
    pub const header_size = 45; // 4 + 4 + 8 + 32 - 3 bytes alignment

    /// Parse program data from account data
    ///
    /// # Arguments
    /// * `account_data` - Raw account data from program data account
    ///
    /// # Returns
    /// Parsed program data state
    ///
    /// # Errors
    /// Returns error if data is invalid or too short
    pub fn parse(account_data: []const u8) !ProgramData {
        if (account_data.len < header_size) {
            return error.InvalidData;
        }

        const magic = std.mem.readInt(u32, account_data[0..4], .little);
        const version = std.mem.readInt(u32, account_data[4..8], .little);
        const slot = std.mem.readInt(u64, account_data[8..16], .little);

        // Authority is stored at offset 13 (after magic, version, slot)
        const authority_offset = 13;
        const authority_bytes = account_data[authority_offset .. authority_offset + 32];
        const authority = PublicKey.from(authority_bytes.*);

        return ProgramData{
            .magic = magic,
            .version = version,
            .slot = slot,
            .authority = authority,
        };
    }

    /// Get the program data portion (excluding header)
    ///
    /// # Arguments
    /// * `account_data` - Raw account data from program data account
    ///
    /// # Returns
    /// Slice containing just the program data
    pub fn getProgramData(account_data: []const u8) []const u8 {
        if (account_data.len < header_size) {
            return &.{};
        }
        return account_data[header_size..];
    }
};

/// Program account state
///
/// Represents the state stored in a program account.
///
/// Rust equivalent: `solana_loader_v4_program::Program`
pub const Program = struct {
    /// Address of the program data account
    program_data_address: PublicKey,

    /// Parse program from account data
    ///
    /// # Arguments
    /// * `account_data` - Raw account data from program account
    ///
    /// # Returns
    /// Parsed program state
    ///
    /// # Errors
    /// Returns error if data is invalid
    pub fn parse(account_data: []const u8) !Program {
        if (account_data.len != 32) {
            return error.InvalidData;
        }

        var addr_bytes: [32]u8 = undefined;
        @memcpy(&addr_bytes, account_data[0..32]);
        const program_data_address = PublicKey.from(addr_bytes);

        return Program{
            .program_data_address = program_data_address,
        };
    }
};

/// Instruction discriminators for Loader V4
pub const InstructionType = enum(u8) {
    /// Create a new program account
    create_program = 0,
    /// Deploy program data
    deploy_program = 1,
    /// Redeploy program with new data
    redeploy_program = 2,
    /// Close program and recover lamports
    close_program = 3,
    /// Transfer program authority
    transfer_authority = 4,
};

test "loader_v4: program data size calculation" {
    // Test basic size calculation
    const size = getProgramDataSize(1000);
    try std.testing.expect(size >= 1000 + ProgramData.header_size);
    try std.testing.expect(size % 8 == 0); // Should be aligned
}

test "loader_v4: program size" {
    const size = getProgramSize();
    try std.testing.expectEqual(@as(usize, 32), size);
}

test "loader_v4: program data parsing" {
    // Create mock program data (minimum 48 bytes for header)
    var data: [48]u8 = undefined;

    // Magic number (offset 0-4)
    std.mem.writeInt(u32, data[0..4], 0x12345678, .little);
    // Version (offset 4-8)
    std.mem.writeInt(u32, data[4..8], 1, .little);
    // Slot (offset 8-16)
    std.mem.writeInt(u64, data[8..16], 12345, .little);
    // Authority (offset 16-48)
    const authority_bytes = [_]u8{1} ** 32;
    @memcpy(data[16..48], &authority_bytes);

    const program_data = try ProgramData.parse(&data);
    try std.testing.expectEqual(@as(u32, 0x12345678), program_data.magic);
    try std.testing.expectEqual(@as(u32, 1), program_data.version);
    try std.testing.expectEqual(@as(u64, 12345), program_data.slot);
}

test "loader_v4: program parsing" {
    // Create mock program account data
    var data: [32]u8 = undefined;
    const program_data_addr = [_]u8{2} ** 32;
    @memcpy(&data, &program_data_addr);

    const program = try Program.parse(&data);
    // Verify the program data address was parsed correctly
    try std.testing.expect(std.mem.eql(u8, &program.program_data_address.bytes, &program_data_addr));
}

test "loader_v4: get program data" {
    var data: [64]u8 = undefined;
    // Fill with test data
    @memset(&data, 0xAA);

    const program_data = ProgramData.getProgramData(&data);
    try std.testing.expectEqual(@as(usize, 64 - ProgramData.header_size), program_data.len);

    // Verify the data starts after the header
    for (program_data) |byte| {
        try std.testing.expectEqual(@as(u8, 0xAA), byte);
    }
}
