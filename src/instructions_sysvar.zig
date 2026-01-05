//! Zig implementation of Solana SDK's instructions-sysvar module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/instructions-sysvar/src/lib.rs
//!
//! This module provides instruction introspection functionality, allowing programs
//! to examine other instructions in the same transaction. This is essential for:
//! - Verifying that required pre-instructions were executed (e.g., Ed25519 signature verification)
//! - Implementing complex security checks across multiple instructions
//! - Building composable programs that depend on transaction context
//!
//! ## Key Functions
//! - `loadCurrentIndex` - Get the index of the currently executing instruction
//! - `loadInstructionAt` - Load instruction data at a specific index
//! - `getInstructionRelative` - Load instruction relative to current (e.g., -1 for previous)
//!
//! ## Note
//! The Instructions sysvar is special - it's not a typical sysvar that can be read
//! via `sol_get_sysvar`. Instead, it uses a custom serialization format and requires
//! special handling through account data.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const bpf = @import("bpf.zig");

// ============================================================================
// Constants
// ============================================================================

/// The Instructions sysvar public key
///
/// This is the address of the special sysvar account that contains
/// instruction introspection data during transaction execution.
///
/// Rust equivalent: `solana_sdk::sysvar::instructions::ID`
pub const ID = PublicKey.comptimeFromBase58("Sysvar1nstructions1111111111111111111111111");

/// Check if the given public key is the Instructions sysvar ID
pub fn check(pubkey: PublicKey) bool {
    return pubkey.equals(ID);
}

// ============================================================================
// Data Structures
// ============================================================================

/// Account metadata for instruction introspection
///
/// This mirrors the AccountMeta structure but is specifically for
/// reading instruction data from the sysvar.
pub const BorrowedAccountMeta = struct {
    /// The public key of the account
    pubkey: PublicKey,
    /// Whether the account is a signer
    is_signer: bool,
    /// Whether the account is writable
    is_writable: bool,
};

/// A borrowed instruction from the Instructions sysvar
///
/// Contains all the data needed to examine an instruction in the transaction.
pub const BorrowedInstruction = struct {
    /// The program ID that will execute this instruction
    program_id: PublicKey,
    /// Account metadata for all accounts used by the instruction
    accounts: []const BorrowedAccountMeta,
    /// The instruction data
    data: []const u8,
};

/// Error type for instruction sysvar operations
pub const InstructionError = error{
    /// The account is not the Instructions sysvar
    InvalidSysvarAccount,
    /// The account data is invalid or corrupted
    InvalidAccountData,
    /// The requested instruction index is out of bounds
    InvalidInstructionIndex,
    /// Failed to deserialize instruction data
    DeserializationError,
};

// ============================================================================
// Serialization Format
// ============================================================================
// The Instructions sysvar uses a custom serialization format:
//
// Header (at end of data):
//   - num_instructions: u16 (little-endian)
//   - current_instruction_index: u16 (little-endian)
//
// Instruction offsets (after header, going backwards):
//   - For each instruction: offset: u16 (little-endian)
//
// Each instruction at its offset:
//   - num_accounts: u16
//   - For each account:
//     - pubkey: [32]u8
//     - is_signer: u8 (0 or 1)
//     - is_writable: u8 (0 or 1)
//   - program_id: [32]u8
//   - data_len: u16
//   - data: [data_len]u8

// ============================================================================
// Core Functions
// ============================================================================

/// Load the index of the currently executing instruction.
///
/// The runtime writes the current instruction index to the Instructions sysvar
/// data before executing each instruction. This allows programs to know their
/// position in the transaction.
///
/// Rust equivalent: `solana_instructions_sysvar::load_current_index_checked`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/instructions-sysvar/src/lib.rs
pub fn loadCurrentIndex(sysvar_data: []const u8) InstructionError!u16 {
    // The current index is stored at the end of the data
    // Format: ... | num_instructions (u16) | current_index (u16)
    if (sysvar_data.len < 4) {
        return InstructionError.InvalidAccountData;
    }

    const footer_start = sysvar_data.len - 4;
    // Skip num_instructions (2 bytes), read current_index (2 bytes)
    const current_index = std.mem.readInt(u16, sysvar_data[footer_start + 2 ..][0..2], .little);
    return current_index;
}

/// Load the total number of instructions in the transaction.
///
/// Returns the count of all instructions, including any inner instructions
/// that may have been added by CPI.
pub fn loadInstructionCount(sysvar_data: []const u8) InstructionError!u16 {
    if (sysvar_data.len < 4) {
        return InstructionError.InvalidAccountData;
    }

    const footer_start = sysvar_data.len - 4;
    const num_instructions = std.mem.readInt(u16, sysvar_data[footer_start..][0..2], .little);
    return num_instructions;
}

/// Load an instruction at the specified index.
///
/// This reads the instruction data from the Instructions sysvar and returns
/// a borrowed view of the instruction. The returned data is only valid
/// as long as the sysvar_data remains valid.
///
/// Rust equivalent: `solana_instructions_sysvar::load_instruction_at_checked`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/instructions-sysvar/src/lib.rs
pub fn loadInstructionAt(
    allocator: std.mem.Allocator,
    sysvar_data: []const u8,
    index: u16,
) InstructionError!BorrowedInstruction {
    const num_instructions = try loadInstructionCount(sysvar_data);

    if (index >= num_instructions) {
        return InstructionError.InvalidInstructionIndex;
    }

    // Get the offset for this instruction
    // Offsets are stored after the footer, going backwards
    const footer_start = sysvar_data.len - 4;
    const offset_table_start = footer_start - (@as(usize, num_instructions) * 2);

    if (offset_table_start > sysvar_data.len) {
        return InstructionError.InvalidAccountData;
    }

    const offset_pos = offset_table_start + (@as(usize, index) * 2);
    if (offset_pos + 2 > footer_start) {
        return InstructionError.InvalidAccountData;
    }

    const instruction_offset = std.mem.readInt(u16, sysvar_data[offset_pos..][0..2], .little);

    // Parse the instruction at the offset
    return parseInstruction(allocator, sysvar_data, instruction_offset);
}

/// Get an instruction relative to the current instruction.
///
/// A relative index of 0 returns the current instruction, -1 returns the
/// previous instruction, 1 returns the next instruction, etc.
///
/// Rust equivalent: `solana_instructions_sysvar::get_instruction_relative`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/instructions-sysvar/src/lib.rs
pub fn getInstructionRelative(
    allocator: std.mem.Allocator,
    sysvar_data: []const u8,
    relative_index: i64,
) InstructionError!BorrowedInstruction {
    const current_index = try loadCurrentIndex(sysvar_data);
    const current_i64 = @as(i64, current_index);
    const target_index = current_i64 + relative_index;

    if (target_index < 0) {
        return InstructionError.InvalidInstructionIndex;
    }

    return loadInstructionAt(allocator, sysvar_data, @intCast(target_index));
}

// ============================================================================
// Internal Helpers
// ============================================================================

fn parseInstruction(
    allocator: std.mem.Allocator,
    data: []const u8,
    offset: u16,
) InstructionError!BorrowedInstruction {
    var pos: usize = offset;

    // Read number of accounts
    if (pos + 2 > data.len) return InstructionError.InvalidAccountData;
    const num_accounts = std.mem.readInt(u16, data[pos..][0..2], .little);
    pos += 2;

    // Parse account metas
    var accounts = allocator.alloc(BorrowedAccountMeta, num_accounts) catch {
        return InstructionError.DeserializationError;
    };
    errdefer allocator.free(accounts);

    for (0..num_accounts) |i| {
        // Read pubkey (32 bytes)
        if (pos + 32 > data.len) {
            allocator.free(accounts);
            return InstructionError.InvalidAccountData;
        }
        var pubkey_bytes: [32]u8 = undefined;
        @memcpy(&pubkey_bytes, data[pos..][0..32]);
        pos += 32;

        // Read is_signer (1 byte)
        if (pos + 1 > data.len) {
            allocator.free(accounts);
            return InstructionError.InvalidAccountData;
        }
        const is_signer = data[pos] != 0;
        pos += 1;

        // Read is_writable (1 byte)
        if (pos + 1 > data.len) {
            allocator.free(accounts);
            return InstructionError.InvalidAccountData;
        }
        const is_writable = data[pos] != 0;
        pos += 1;

        accounts[i] = BorrowedAccountMeta{
            .pubkey = PublicKey.from(pubkey_bytes),
            .is_signer = is_signer,
            .is_writable = is_writable,
        };
    }

    // Read program_id (32 bytes)
    if (pos + 32 > data.len) {
        allocator.free(accounts);
        return InstructionError.InvalidAccountData;
    }
    var program_id_bytes: [32]u8 = undefined;
    @memcpy(&program_id_bytes, data[pos..][0..32]);
    const program_id = PublicKey.from(program_id_bytes);
    pos += 32;

    // Read data length (2 bytes)
    if (pos + 2 > data.len) {
        allocator.free(accounts);
        return InstructionError.InvalidAccountData;
    }
    const data_len = std.mem.readInt(u16, data[pos..][0..2], .little);
    pos += 2;

    // Read instruction data
    if (pos + data_len > data.len) {
        allocator.free(accounts);
        return InstructionError.InvalidAccountData;
    }
    const instruction_data = data[pos .. pos + data_len];

    return BorrowedInstruction{
        .program_id = program_id,
        .accounts = accounts,
        .data = instruction_data,
    };
}

/// Free the memory allocated for a BorrowedInstruction
pub fn freeBorrowedInstruction(allocator: std.mem.Allocator, instruction: BorrowedInstruction) void {
    allocator.free(instruction.accounts);
}

// ============================================================================
// Convenience Functions
// ============================================================================

/// Serialize an instruction to the sysvar format.
///
/// This is primarily used for testing - the runtime normally populates
/// the Instructions sysvar automatically.
pub fn serializeInstructions(
    allocator: std.mem.Allocator,
    instructions: []const BorrowedInstruction,
    current_index: u16,
) ![]u8 {
    // Calculate total size needed
    var total_size: usize = 0;

    // Space for each instruction
    for (instructions) |ix| {
        total_size += 2; // num_accounts
        total_size += ix.accounts.len * (32 + 1 + 1); // pubkey + is_signer + is_writable
        total_size += 32; // program_id
        total_size += 2; // data_len
        total_size += ix.data.len; // data
    }

    // Space for offset table
    total_size += instructions.len * 2;

    // Space for footer
    total_size += 4; // num_instructions + current_index

    var buffer = try allocator.alloc(u8, total_size);
    errdefer allocator.free(buffer);

    var pos: usize = 0;
    var offsets = try allocator.alloc(u16, instructions.len);
    defer allocator.free(offsets);

    // Write each instruction and record its offset
    for (instructions, 0..) |ix, i| {
        offsets[i] = @intCast(pos);

        // num_accounts
        std.mem.writeInt(u16, buffer[pos..][0..2], @intCast(ix.accounts.len), .little);
        pos += 2;

        // accounts
        for (ix.accounts) |acc| {
            @memcpy(buffer[pos..][0..32], &acc.pubkey.bytes);
            pos += 32;
            buffer[pos] = if (acc.is_signer) 1 else 0;
            pos += 1;
            buffer[pos] = if (acc.is_writable) 1 else 0;
            pos += 1;
        }

        // program_id
        @memcpy(buffer[pos..][0..32], &ix.program_id.bytes);
        pos += 32;

        // data_len
        std.mem.writeInt(u16, buffer[pos..][0..2], @intCast(ix.data.len), .little);
        pos += 2;

        // data
        @memcpy(buffer[pos..][0..ix.data.len], ix.data);
        pos += ix.data.len;
    }

    // Write offset table
    for (offsets) |offset| {
        std.mem.writeInt(u16, buffer[pos..][0..2], offset, .little);
        pos += 2;
    }

    // Write footer
    std.mem.writeInt(u16, buffer[pos..][0..2], @intCast(instructions.len), .little);
    pos += 2;
    std.mem.writeInt(u16, buffer[pos..][0..2], current_index, .little);
    pos += 2;

    return buffer;
}

// ============================================================================
// Tests
// ============================================================================

test "instructions_sysvar: ID constant" {
    // Verify the sysvar ID matches expected value
    const expected = "Sysvar1nstructions1111111111111111111111111";
    var buf: [44]u8 = undefined;
    const actual = ID.toBase58(&buf);
    try std.testing.expectEqualStrings(expected, actual);
}

test "instructions_sysvar: check function" {
    try std.testing.expect(check(ID));

    const other = PublicKey.from([_]u8{0} ** 32);
    try std.testing.expect(!check(other));
}

test "instructions_sysvar: serialize and parse single instruction" {
    const allocator = std.testing.allocator;

    const program_id = PublicKey.from([_]u8{1} ** 32);
    const account_pubkey = PublicKey.from([_]u8{2} ** 32);

    const accounts = [_]BorrowedAccountMeta{
        .{
            .pubkey = account_pubkey,
            .is_signer = true,
            .is_writable = true,
        },
    };

    const instruction_data = [_]u8{ 1, 2, 3, 4 };

    const instructions = [_]BorrowedInstruction{
        .{
            .program_id = program_id,
            .accounts = &accounts,
            .data = &instruction_data,
        },
    };

    const serialized = try serializeInstructions(allocator, &instructions, 0);
    defer allocator.free(serialized);

    // Verify we can read it back
    const count = try loadInstructionCount(serialized);
    try std.testing.expectEqual(@as(u16, 1), count);

    const current = try loadCurrentIndex(serialized);
    try std.testing.expectEqual(@as(u16, 0), current);

    const parsed = try loadInstructionAt(allocator, serialized, 0);
    defer freeBorrowedInstruction(allocator, parsed);

    try std.testing.expect(parsed.program_id.equals(program_id));
    try std.testing.expectEqual(@as(usize, 1), parsed.accounts.len);
    try std.testing.expect(parsed.accounts[0].pubkey.equals(account_pubkey));
    try std.testing.expect(parsed.accounts[0].is_signer);
    try std.testing.expect(parsed.accounts[0].is_writable);
    try std.testing.expectEqualSlices(u8, &instruction_data, parsed.data);
}

test "instructions_sysvar: multiple instructions" {
    const allocator = std.testing.allocator;

    const program_id1 = PublicKey.from([_]u8{1} ** 32);
    const program_id2 = PublicKey.from([_]u8{2} ** 32);

    const data1 = [_]u8{ 0xAA, 0xBB };
    const data2 = [_]u8{ 0xCC, 0xDD, 0xEE };

    const instructions = [_]BorrowedInstruction{
        .{
            .program_id = program_id1,
            .accounts = &[_]BorrowedAccountMeta{},
            .data = &data1,
        },
        .{
            .program_id = program_id2,
            .accounts = &[_]BorrowedAccountMeta{},
            .data = &data2,
        },
    };

    const serialized = try serializeInstructions(allocator, &instructions, 1);
    defer allocator.free(serialized);

    const count = try loadInstructionCount(serialized);
    try std.testing.expectEqual(@as(u16, 2), count);

    const current = try loadCurrentIndex(serialized);
    try std.testing.expectEqual(@as(u16, 1), current);

    // Load first instruction
    const ix0 = try loadInstructionAt(allocator, serialized, 0);
    defer freeBorrowedInstruction(allocator, ix0);
    try std.testing.expect(ix0.program_id.equals(program_id1));
    try std.testing.expectEqualSlices(u8, &data1, ix0.data);

    // Load second instruction
    const ix1 = try loadInstructionAt(allocator, serialized, 1);
    defer freeBorrowedInstruction(allocator, ix1);
    try std.testing.expect(ix1.program_id.equals(program_id2));
    try std.testing.expectEqualSlices(u8, &data2, ix1.data);
}

test "instructions_sysvar: get instruction relative" {
    const allocator = std.testing.allocator;

    const program_id = PublicKey.from([_]u8{1} ** 32);

    const instructions = [_]BorrowedInstruction{
        .{ .program_id = program_id, .accounts = &[_]BorrowedAccountMeta{}, .data = &[_]u8{0} },
        .{ .program_id = program_id, .accounts = &[_]BorrowedAccountMeta{}, .data = &[_]u8{1} },
        .{ .program_id = program_id, .accounts = &[_]BorrowedAccountMeta{}, .data = &[_]u8{2} },
    };

    // Set current index to 1 (middle instruction)
    const serialized = try serializeInstructions(allocator, &instructions, 1);
    defer allocator.free(serialized);

    // Get current instruction (relative 0)
    const current = try getInstructionRelative(allocator, serialized, 0);
    defer freeBorrowedInstruction(allocator, current);
    try std.testing.expectEqual(@as(u8, 1), current.data[0]);

    // Get previous instruction (relative -1)
    const prev = try getInstructionRelative(allocator, serialized, -1);
    defer freeBorrowedInstruction(allocator, prev);
    try std.testing.expectEqual(@as(u8, 0), prev.data[0]);

    // Get next instruction (relative +1)
    const next = try getInstructionRelative(allocator, serialized, 1);
    defer freeBorrowedInstruction(allocator, next);
    try std.testing.expectEqual(@as(u8, 2), next.data[0]);
}

test "instructions_sysvar: invalid index returns error" {
    const allocator = std.testing.allocator;

    const program_id = PublicKey.from([_]u8{1} ** 32);
    const instructions = [_]BorrowedInstruction{
        .{ .program_id = program_id, .accounts = &[_]BorrowedAccountMeta{}, .data = &[_]u8{} },
    };

    const serialized = try serializeInstructions(allocator, &instructions, 0);
    defer allocator.free(serialized);

    // Try to load out of bounds
    const result = loadInstructionAt(allocator, serialized, 5);
    try std.testing.expectError(InstructionError.InvalidInstructionIndex, result);
}

test "instructions_sysvar: relative before start returns error" {
    const allocator = std.testing.allocator;

    const program_id = PublicKey.from([_]u8{1} ** 32);
    const instructions = [_]BorrowedInstruction{
        .{ .program_id = program_id, .accounts = &[_]BorrowedAccountMeta{}, .data = &[_]u8{} },
    };

    const serialized = try serializeInstructions(allocator, &instructions, 0);
    defer allocator.free(serialized);

    // Try to get instruction before first
    const result = getInstructionRelative(allocator, serialized, -1);
    try std.testing.expectError(InstructionError.InvalidInstructionIndex, result);
}
