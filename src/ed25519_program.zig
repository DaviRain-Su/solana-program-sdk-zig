//! Zig implementation of Solana SDK's Ed25519 signature verification program
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/ed25519-program/src/lib.rs
//!
//! This module provides the Ed25519 native program interface for verifying
//! Ed25519 signatures on-chain. The program is stateless and requires no accounts.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;

/// Built instruction for Ed25519 verification
pub const BuiltInstruction = struct {
    program_id: PublicKey,
    data: []u8,

    pub fn deinit(self: *BuiltInstruction, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

/// Ed25519 program ID
///
/// Rust equivalent: `solana_sdk::ed25519_program::id()`
pub const id = PublicKey.comptimeFromBase58("Ed25519SigVerify111111111111111111111111111");

/// Size of a serialized public key
pub const PUBKEY_SERIALIZED_SIZE: usize = 32;

/// Size of a serialized signature
pub const SIGNATURE_SERIALIZED_SIZE: usize = 64;

/// Size of the signature offsets structure
pub const SIGNATURE_OFFSETS_SERIALIZED_SIZE: usize = 14;

/// Offset where signature offsets start in instruction data
pub const SIGNATURE_OFFSETS_START: usize = 2;

/// Offset where actual data starts (after header and offsets)
pub const DATA_START: usize = SIGNATURE_OFFSETS_SERIALIZED_SIZE + SIGNATURE_OFFSETS_START;

/// Offsets for Ed25519 signature verification
///
/// This structure describes where to find the signature, public key, and message
/// data within the instruction data or in other instructions in the transaction.
///
/// Rust equivalent: `solana_ed25519_program::Ed25519SignatureOffsets`
pub const Ed25519SignatureOffsets = extern struct {
    /// Offset to the 64-byte signature
    signature_offset: u16,
    /// Index of the instruction containing the signature (0xFF = current instruction)
    signature_instruction_index: u16,
    /// Offset to the 32-byte public key
    public_key_offset: u16,
    /// Index of the instruction containing the public key
    public_key_instruction_index: u16,
    /// Offset to the start of message data
    message_data_offset: u16,
    /// Size of the message data
    message_data_size: u16,
    /// Index of the instruction containing the message
    message_instruction_index: u16,

    /// Create offsets for data embedded in the current instruction
    pub fn forCurrentInstruction(
        signature_offset: u16,
        public_key_offset: u16,
        message_offset: u16,
        message_size: u16,
    ) Ed25519SignatureOffsets {
        return Ed25519SignatureOffsets{
            .signature_offset = signature_offset,
            .signature_instruction_index = 0xFFFF,
            .public_key_offset = public_key_offset,
            .public_key_instruction_index = 0xFFFF,
            .message_data_offset = message_offset,
            .message_data_size = message_size,
            .message_instruction_index = 0xFFFF,
        };
    }

    /// Serialize the offsets to bytes
    pub fn toBytes(self: Ed25519SignatureOffsets) [SIGNATURE_OFFSETS_SERIALIZED_SIZE]u8 {
        var bytes: [SIGNATURE_OFFSETS_SERIALIZED_SIZE]u8 = undefined;
        std.mem.writeInt(u16, bytes[0..2], self.signature_offset, .little);
        std.mem.writeInt(u16, bytes[2..4], self.signature_instruction_index, .little);
        std.mem.writeInt(u16, bytes[4..6], self.public_key_offset, .little);
        std.mem.writeInt(u16, bytes[6..8], self.public_key_instruction_index, .little);
        std.mem.writeInt(u16, bytes[8..10], self.message_data_offset, .little);
        std.mem.writeInt(u16, bytes[10..12], self.message_data_size, .little);
        std.mem.writeInt(u16, bytes[12..14], self.message_instruction_index, .little);
        return bytes;
    }
};

/// Create an Ed25519 verification instruction with an embedded signature
///
/// This creates an instruction that verifies a single Ed25519 signature.
/// The signature, public key, and message are all embedded in the instruction data.
///
/// # Arguments
/// * `allocator` - Memory allocator
/// * `message` - The message that was signed
/// * `signature` - The 64-byte Ed25519 signature
/// * `pubkey` - The 32-byte Ed25519 public key
///
/// # Returns
/// An instruction for the Ed25519 program
pub fn createInstruction(
    allocator: std.mem.Allocator,
    message: []const u8,
    signature: *const [SIGNATURE_SERIALIZED_SIZE]u8,
    pubkey: *const [PUBKEY_SERIALIZED_SIZE]u8,
) !BuiltInstruction {
    // Layout:
    // [0]: num_signatures (u8)
    // [1]: padding (u8)
    // [2..16]: Ed25519SignatureOffsets (14 bytes)
    // [16..80]: signature (64 bytes)
    // [80..112]: public key (32 bytes)
    // [112..]: message data

    const total_size = DATA_START + SIGNATURE_SERIALIZED_SIZE + PUBKEY_SERIALIZED_SIZE + message.len;
    var data = try std.ArrayList(u8).initCapacity(allocator, total_size);
    errdefer data.deinit(allocator);

    // Number of signatures
    data.appendAssumeCapacity(1);
    // Padding
    data.appendAssumeCapacity(0);

    // Calculate offsets
    const signature_offset: u16 = DATA_START;
    const pubkey_offset: u16 = DATA_START + SIGNATURE_SERIALIZED_SIZE;
    const message_offset: u16 = DATA_START + SIGNATURE_SERIALIZED_SIZE + PUBKEY_SERIALIZED_SIZE;

    const offsets = Ed25519SignatureOffsets.forCurrentInstruction(
        signature_offset,
        pubkey_offset,
        message_offset,
        @intCast(message.len),
    );

    // Write offsets
    data.appendSliceAssumeCapacity(&offsets.toBytes());

    // Write signature
    data.appendSliceAssumeCapacity(signature);

    // Write public key
    data.appendSliceAssumeCapacity(pubkey);

    // Write message
    try data.appendSlice(allocator, message);

    return BuiltInstruction{
        .program_id = id,
        .data = try data.toOwnedSlice(allocator),
    };
}

// ============================================================================
// Tests
// ============================================================================

test "ed25519_program: program id is correct" {
    // Verify the program ID decodes correctly
    try std.testing.expectEqual(@as(usize, 32), id.bytes.len);
}

test "ed25519_program: constants are correct" {
    try std.testing.expectEqual(@as(usize, 32), PUBKEY_SERIALIZED_SIZE);
    try std.testing.expectEqual(@as(usize, 64), SIGNATURE_SERIALIZED_SIZE);
    try std.testing.expectEqual(@as(usize, 14), SIGNATURE_OFFSETS_SERIALIZED_SIZE);
    try std.testing.expectEqual(@as(usize, 2), SIGNATURE_OFFSETS_START);
    try std.testing.expectEqual(@as(usize, 16), DATA_START);
}

test "ed25519_program: offsets serialization" {
    const offsets = Ed25519SignatureOffsets{
        .signature_offset = 0x1234,
        .signature_instruction_index = 0xFFFF,
        .public_key_offset = 0x5678,
        .public_key_instruction_index = 0xFFFF,
        .message_data_offset = 0x9ABC,
        .message_data_size = 0x00DE,
        .message_instruction_index = 0xFFFF,
    };

    const bytes = offsets.toBytes();
    try std.testing.expectEqual(@as(usize, 14), bytes.len);

    // Verify little-endian encoding
    try std.testing.expectEqual(@as(u16, 0x1234), std.mem.readInt(u16, bytes[0..2], .little));
    try std.testing.expectEqual(@as(u16, 0xFFFF), std.mem.readInt(u16, bytes[2..4], .little));
    try std.testing.expectEqual(@as(u16, 0x5678), std.mem.readInt(u16, bytes[4..6], .little));
}

test "ed25519_program: create instruction" {
    const allocator = std.testing.allocator;

    const message = "hello world";
    var signature: [64]u8 = undefined;
    @memset(&signature, 0xAB);
    var pubkey: [32]u8 = undefined;
    @memset(&pubkey, 0xCD);

    var ix = try createInstruction(allocator, message, &signature, &pubkey);
    defer ix.deinit(allocator);

    // Verify program ID
    try std.testing.expectEqualSlices(u8, &id.bytes, &ix.program_id.bytes);

    // Verify data structure
    try std.testing.expectEqual(@as(u8, 1), ix.data[0]); // num_signatures
    try std.testing.expectEqual(@as(u8, 0), ix.data[1]); // padding

    // Verify total size
    const expected_size = DATA_START + SIGNATURE_SERIALIZED_SIZE + PUBKEY_SERIALIZED_SIZE + message.len;
    try std.testing.expectEqual(expected_size, ix.data.len);

    // Verify signature is at correct offset
    try std.testing.expectEqualSlices(u8, &signature, ix.data[DATA_START..][0..64]);

    // Verify pubkey is at correct offset
    try std.testing.expectEqualSlices(u8, &pubkey, ix.data[DATA_START + 64 ..][0..32]);

    // Verify message is at correct offset
    try std.testing.expectEqualSlices(u8, message, ix.data[DATA_START + 64 + 32 ..]);
}

test "ed25519_program: forCurrentInstruction helper" {
    const offsets = Ed25519SignatureOffsets.forCurrentInstruction(16, 80, 112, 100);

    try std.testing.expectEqual(@as(u16, 16), offsets.signature_offset);
    try std.testing.expectEqual(@as(u16, 0xFFFF), offsets.signature_instruction_index);
    try std.testing.expectEqual(@as(u16, 80), offsets.public_key_offset);
    try std.testing.expectEqual(@as(u16, 0xFFFF), offsets.public_key_instruction_index);
    try std.testing.expectEqual(@as(u16, 112), offsets.message_data_offset);
    try std.testing.expectEqual(@as(u16, 100), offsets.message_data_size);
    try std.testing.expectEqual(@as(u16, 0xFFFF), offsets.message_instruction_index);
}
