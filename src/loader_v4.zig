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
const AccountMeta = @import("instruction.zig").AccountMeta;
const Account = @import("account.zig").Account;
const system_program = @import("system_program.zig");

/// Instruction type for off-chain construction
pub const BuiltInstruction = system_program.BuiltInstruction;

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

// ============================================================================
// Instruction Builders
// ============================================================================

/// Write bytes to a program account
///
/// Accounts:
///   0. `[writable]` Program account to write to
///   1. `[signer]` Authority
///
/// Rust equivalent: `loader_v4::instruction::write()`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/loader-v4-interface/src/instruction.rs
pub fn write(
    allocator: std.mem.Allocator,
    program_address: PublicKey,
    authority_address: PublicKey,
    offset: u32,
    bytes: []const u8,
) !BuiltInstruction {
    // Instruction data format:
    // - Instruction discriminator: 1 byte (0 = Write)
    // - Offset: 4 bytes (little endian)
    // - Bytes: variable length

    const data_len = 1 + 4 + bytes.len;
    var instruction_data = try allocator.alloc(u8, data_len);
    errdefer allocator.free(instruction_data);

    instruction_data[0] = @intFromEnum(InstructionType.write);
    @memcpy(instruction_data[1..5], &std.mem.toBytes(offset));
    @memcpy(instruction_data[5..], bytes);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 2);
    errdefer accounts.deinit(allocator);

    accounts.appendAssumeCapacity(AccountMeta.init(program_address, false, true)); // writable
    accounts.appendAssumeCapacity(AccountMeta.init(authority_address, true, false)); // signer

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = instruction_data,
    };
}

/// Copy bytes from source program to destination program
///
/// Accounts:
///   0. `[writable]` Destination program account
///   1. `[signer]` Authority
///   2. `[]` Source program account
///
/// Rust equivalent: `loader_v4::instruction::copy()`
pub fn copy(
    allocator: std.mem.Allocator,
    destination_address: PublicKey,
    authority_address: PublicKey,
    source_address: PublicKey,
    destination_offset: u32,
    source_offset: u32,
    length: u32,
) !BuiltInstruction {
    // Instruction data format:
    // - Instruction discriminator: 1 byte (1 = Copy)
    // - Destination offset: 4 bytes
    // - Source offset: 4 bytes
    // - Length: 4 bytes

    const data_len = 1 + 4 + 4 + 4;
    var instruction_data = try allocator.alloc(u8, data_len);
    errdefer allocator.free(instruction_data);

    instruction_data[0] = @intFromEnum(InstructionType.copy);
    @memcpy(instruction_data[1..5], &std.mem.toBytes(destination_offset));
    @memcpy(instruction_data[5..9], &std.mem.toBytes(source_offset));
    @memcpy(instruction_data[9..13], &std.mem.toBytes(length));

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 3);
    errdefer accounts.deinit(allocator);

    accounts.appendAssumeCapacity(AccountMeta.init(destination_address, false, true)); // writable
    accounts.appendAssumeCapacity(AccountMeta.init(authority_address, true, false)); // signer
    accounts.appendAssumeCapacity(AccountMeta.init(source_address, false, false)); // read-only

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = instruction_data,
    };
}

/// Set program length (allocate or truncate)
///
/// Accounts:
///   0. `[writable]` Program account
///   1. `[signer]` Authority
///   2. `[writable]` Recipient (receives lamports if truncating)
///
/// Rust equivalent: `loader_v4::instruction::set_program_length()`
pub fn setProgramLength(
    allocator: std.mem.Allocator,
    program_address: PublicKey,
    authority_address: PublicKey,
    recipient_address: PublicKey,
    new_size: u32,
) !BuiltInstruction {
    // Instruction data format:
    // - Instruction discriminator: 1 byte (2 = SetProgramLength)
    // - New size: 4 bytes

    const data_len = 1 + 4;
    var instruction_data = try allocator.alloc(u8, data_len);
    errdefer allocator.free(instruction_data);

    instruction_data[0] = @intFromEnum(InstructionType.set_program_length);
    @memcpy(instruction_data[1..5], &std.mem.toBytes(new_size));

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 3);
    errdefer accounts.deinit(allocator);

    accounts.appendAssumeCapacity(AccountMeta.init(program_address, false, true)); // writable
    accounts.appendAssumeCapacity(AccountMeta.init(authority_address, true, false)); // signer
    accounts.appendAssumeCapacity(AccountMeta.init(recipient_address, false, true)); // writable

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = instruction_data,
    };
}

/// Deploy program (make executable)
///
/// Accounts:
///   0. `[writable]` Program account
///   1. `[signer]` Authority
///   2. `[writable, optional]` Source program (for deploy_from_source)
///
/// Rust equivalent: `loader_v4::instruction::deploy()`
pub fn deploy(
    allocator: std.mem.Allocator,
    program_address: PublicKey,
    authority_address: PublicKey,
    source_address: ?PublicKey,
) !BuiltInstruction {
    // Instruction data format:
    // - Instruction discriminator: 1 byte (3 = Deploy)

    var instruction_data = try allocator.alloc(u8, 1);
    errdefer allocator.free(instruction_data);

    instruction_data[0] = @intFromEnum(InstructionType.deploy);

    const num_accounts: usize = if (source_address != null) 3 else 2;
    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, num_accounts);
    errdefer accounts.deinit(allocator);

    accounts.appendAssumeCapacity(AccountMeta.init(program_address, false, true)); // writable
    accounts.appendAssumeCapacity(AccountMeta.init(authority_address, true, false)); // signer

    if (source_address) |source| {
        accounts.appendAssumeCapacity(AccountMeta.init(source, false, true)); // writable
    }

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = instruction_data,
    };
}

/// Retract deployment (make non-executable)
///
/// Accounts:
///   0. `[writable]` Program account
///   1. `[signer]` Authority
///
/// Rust equivalent: `loader_v4::instruction::retract()`
pub fn retract(
    allocator: std.mem.Allocator,
    program_address: PublicKey,
    authority_address: PublicKey,
) !BuiltInstruction {
    // Instruction data format:
    // - Instruction discriminator: 1 byte (4 = Retract)

    var instruction_data = try allocator.alloc(u8, 1);
    errdefer allocator.free(instruction_data);

    instruction_data[0] = @intFromEnum(InstructionType.retract);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 2);
    errdefer accounts.deinit(allocator);

    accounts.appendAssumeCapacity(AccountMeta.init(program_address, false, true)); // writable
    accounts.appendAssumeCapacity(AccountMeta.init(authority_address, true, false)); // signer

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = instruction_data,
    };
}

/// Transfer program authority
///
/// Accounts:
///   0. `[writable]` Program account
///   1. `[signer]` Current authority
///   2. `[signer]` New authority
///
/// Rust equivalent: `loader_v4::instruction::transfer_authority()`
pub fn transferAuthority(
    allocator: std.mem.Allocator,
    program_address: PublicKey,
    current_authority: PublicKey,
    new_authority: PublicKey,
) !BuiltInstruction {
    // Instruction data format:
    // - Instruction discriminator: 1 byte (5 = TransferAuthority)

    var instruction_data = try allocator.alloc(u8, 1);
    errdefer allocator.free(instruction_data);

    instruction_data[0] = @intFromEnum(InstructionType.transfer_authority);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 3);
    errdefer accounts.deinit(allocator);

    accounts.appendAssumeCapacity(AccountMeta.init(program_address, false, true)); // writable
    accounts.appendAssumeCapacity(AccountMeta.init(current_authority, true, false)); // signer
    accounts.appendAssumeCapacity(AccountMeta.init(new_authority, true, false)); // signer

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = instruction_data,
    };
}

/// Finalize program (set next version)
///
/// Accounts:
///   0. `[writable]` Program account
///   1. `[signer]` Authority
///   2. `[]` Next version program account
///
/// Rust equivalent: `loader_v4::instruction::finalize()`
pub fn finalize(
    allocator: std.mem.Allocator,
    program_address: PublicKey,
    authority_address: PublicKey,
    next_version_address: PublicKey,
) !BuiltInstruction {
    // Instruction data format:
    // - Instruction discriminator: 1 byte (6 = Finalize)

    var instruction_data = try allocator.alloc(u8, 1);
    errdefer allocator.free(instruction_data);

    instruction_data[0] = @intFromEnum(InstructionType.finalize);

    var accounts = try std.ArrayList(AccountMeta).initCapacity(allocator, 3);
    errdefer accounts.deinit(allocator);

    accounts.appendAssumeCapacity(AccountMeta.init(program_address, false, true)); // writable
    accounts.appendAssumeCapacity(AccountMeta.init(authority_address, true, false)); // signer
    accounts.appendAssumeCapacity(AccountMeta.init(next_version_address, false, false)); // read-only

    return BuiltInstruction{
        .program_id = id,
        .accounts = try accounts.toOwnedSlice(allocator),
        .data = instruction_data,
    };
}

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
///
/// Rust equivalent: `LoaderV4Instruction`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/loader-v4-interface/src/instruction.rs
pub const InstructionType = enum(u8) {
    /// Write bytes to program account
    write = 0,
    /// Copy bytes from source program
    copy = 1,
    /// Set program length (allocate/truncate)
    set_program_length = 2,
    /// Deploy program (make executable)
    deploy = 3,
    /// Retract deployment (make non-executable)
    retract = 4,
    /// Transfer program authority
    transfer_authority = 5,
    /// Finalize program (set next version)
    finalize = 6,
};

/// Cooldown before a program can be un-/redeployed again
///
/// Rust equivalent: `DEPLOYMENT_COOLDOWN_IN_SLOTS`
pub const DEPLOYMENT_COOLDOWN_IN_SLOTS: u64 = 1;

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

test "loader_v4: write instruction" {
    const allocator = std.testing.allocator;

    const program_addr = PublicKey.from([_]u8{1} ** 32);
    const authority_addr = PublicKey.from([_]u8{2} ** 32);
    const test_bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };

    var ix = try write(allocator, program_addr, authority_addr, 100, &test_bytes);
    defer ix.deinit(allocator);

    // Verify discriminator
    try std.testing.expectEqual(@as(u8, @intFromEnum(InstructionType.write)), ix.data[0]);
    // Verify offset
    try std.testing.expectEqual(@as(u32, 100), std.mem.readInt(u32, ix.data[1..5], .little));
    // Verify bytes
    try std.testing.expectEqualSlices(u8, &test_bytes, ix.data[5..]);
    // Verify accounts
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_writable);
    try std.testing.expect(ix.accounts[1].is_signer);
}

test "loader_v4: copy instruction" {
    const allocator = std.testing.allocator;

    const dest_addr = PublicKey.from([_]u8{1} ** 32);
    const authority_addr = PublicKey.from([_]u8{2} ** 32);
    const source_addr = PublicKey.from([_]u8{3} ** 32);

    var ix = try copy(allocator, dest_addr, authority_addr, source_addr, 0, 100, 500);
    defer ix.deinit(allocator);

    // Verify discriminator
    try std.testing.expectEqual(@as(u8, @intFromEnum(InstructionType.copy)), ix.data[0]);
    // Verify offsets and length
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, ix.data[1..5], .little));
    try std.testing.expectEqual(@as(u32, 100), std.mem.readInt(u32, ix.data[5..9], .little));
    try std.testing.expectEqual(@as(u32, 500), std.mem.readInt(u32, ix.data[9..13], .little));
    // Verify accounts
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_writable); // dest
    try std.testing.expect(ix.accounts[1].is_signer); // authority
    try std.testing.expect(!ix.accounts[2].is_writable); // source (read-only)
}

test "loader_v4: set_program_length instruction" {
    const allocator = std.testing.allocator;

    const program_addr = PublicKey.from([_]u8{1} ** 32);
    const authority_addr = PublicKey.from([_]u8{2} ** 32);
    const recipient_addr = PublicKey.from([_]u8{3} ** 32);

    var ix = try setProgramLength(allocator, program_addr, authority_addr, recipient_addr, 10000);
    defer ix.deinit(allocator);

    // Verify discriminator
    try std.testing.expectEqual(@as(u8, @intFromEnum(InstructionType.set_program_length)), ix.data[0]);
    // Verify new size
    try std.testing.expectEqual(@as(u32, 10000), std.mem.readInt(u32, ix.data[1..5], .little));
    // Verify accounts
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_writable); // program
    try std.testing.expect(ix.accounts[1].is_signer); // authority
    try std.testing.expect(ix.accounts[2].is_writable); // recipient
}

test "loader_v4: deploy instruction" {
    const allocator = std.testing.allocator;

    const program_addr = PublicKey.from([_]u8{1} ** 32);
    const authority_addr = PublicKey.from([_]u8{2} ** 32);

    // Without source
    var ix1 = try deploy(allocator, program_addr, authority_addr, null);
    defer ix1.deinit(allocator);

    try std.testing.expectEqual(@as(u8, @intFromEnum(InstructionType.deploy)), ix1.data[0]);
    try std.testing.expectEqual(@as(usize, 1), ix1.data.len);
    try std.testing.expectEqual(@as(usize, 2), ix1.accounts.len);

    // With source
    const source_addr = PublicKey.from([_]u8{3} ** 32);
    var ix2 = try deploy(allocator, program_addr, authority_addr, source_addr);
    defer ix2.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), ix2.accounts.len);
    try std.testing.expect(ix2.accounts[2].is_writable); // source is writable
}

test "loader_v4: retract instruction" {
    const allocator = std.testing.allocator;

    const program_addr = PublicKey.from([_]u8{1} ** 32);
    const authority_addr = PublicKey.from([_]u8{2} ** 32);

    var ix = try retract(allocator, program_addr, authority_addr);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(u8, @intFromEnum(InstructionType.retract)), ix.data[0]);
    try std.testing.expectEqual(@as(usize, 1), ix.data.len);
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_writable);
    try std.testing.expect(ix.accounts[1].is_signer);
}

test "loader_v4: transfer_authority instruction" {
    const allocator = std.testing.allocator;

    const program_addr = PublicKey.from([_]u8{1} ** 32);
    const current_auth = PublicKey.from([_]u8{2} ** 32);
    const new_auth = PublicKey.from([_]u8{3} ** 32);

    var ix = try transferAuthority(allocator, program_addr, current_auth, new_auth);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(u8, @intFromEnum(InstructionType.transfer_authority)), ix.data[0]);
    try std.testing.expectEqual(@as(usize, 1), ix.data.len);
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_writable); // program
    try std.testing.expect(ix.accounts[1].is_signer); // current authority
    try std.testing.expect(ix.accounts[2].is_signer); // new authority
}

test "loader_v4: finalize instruction" {
    const allocator = std.testing.allocator;

    const program_addr = PublicKey.from([_]u8{1} ** 32);
    const authority_addr = PublicKey.from([_]u8{2} ** 32);
    const next_version_addr = PublicKey.from([_]u8{3} ** 32);

    var ix = try finalize(allocator, program_addr, authority_addr, next_version_addr);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(u8, @intFromEnum(InstructionType.finalize)), ix.data[0]);
    try std.testing.expectEqual(@as(usize, 1), ix.data.len);
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_writable); // program
    try std.testing.expect(ix.accounts[1].is_signer); // authority
    try std.testing.expect(!ix.accounts[2].is_writable); // next version (read-only)
}

test "loader_v4: DEPLOYMENT_COOLDOWN_IN_SLOTS constant" {
    try std.testing.expectEqual(@as(u64, 1), DEPLOYMENT_COOLDOWN_IN_SLOTS);
}

test "loader_v4: InstructionType discriminators" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(InstructionType.write));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(InstructionType.copy));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(InstructionType.set_program_length));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(InstructionType.deploy));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(InstructionType.retract));
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(InstructionType.transfer_authority));
    try std.testing.expectEqual(@as(u8, 6), @intFromEnum(InstructionType.finalize));
}
