//! Zig implementation of Solana SDK's Secp256k1 signature verification program
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/secp256k1-program/src/lib.rs
//!
//! This module provides the Secp256k1 native program interface for verifying
//! Ethereum-compatible ECDSA signatures on-chain. The program uses Keccak256
//! hashing internally.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;

/// Built instruction for Secp256k1 verification
pub const BuiltInstruction = struct {
    program_id: PublicKey,
    data: []u8,

    pub fn deinit(self: *BuiltInstruction, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

/// Secp256k1 program ID
///
/// Rust equivalent: `solana_sdk::secp256k1_program::id()`
pub const id = PublicKey.comptimeFromBase58("KeccakSecp256k11111111111111111111111111111");

/// Size of a secp256k1 public key (uncompressed, without prefix)
pub const SECP256K1_PUBKEY_SIZE: usize = 64;

/// Size of a secp256k1 private key
pub const SECP256K1_PRIVATE_KEY_SIZE: usize = 32;

/// Size of an Ethereum address (Keccak256 hash of public key, last 20 bytes)
pub const HASHED_PUBKEY_SERIALIZED_SIZE: usize = 20;

/// Size of a secp256k1 signature
pub const SIGNATURE_SERIALIZED_SIZE: usize = 64;

/// Size of the signature offsets structure
pub const SIGNATURE_OFFSETS_SERIALIZED_SIZE: usize = 11;

/// Offset where actual data starts
pub const DATA_START: usize = SIGNATURE_OFFSETS_SERIALIZED_SIZE + 1;

/// Offsets for Secp256k1 signature verification
///
/// This structure describes where to find the signature, Ethereum address, and message
/// data within the instruction data or in other instructions in the transaction.
///
/// Rust equivalent: `solana_secp256k1_program::SecpSignatureOffsets`
pub const SecpSignatureOffsets = extern struct {
    /// Offset to the 64-byte signature + 1-byte recovery ID
    signature_offset: u16,
    /// Index of the instruction containing the signature (u8)
    signature_instruction_index: u8,
    /// Offset to the 20-byte Ethereum address
    eth_address_offset: u16,
    /// Index of the instruction containing the address (u8)
    eth_address_instruction_index: u8,
    /// Offset to the start of message data
    message_data_offset: u16,
    /// Size of the message data
    message_data_size: u16,
    /// Index of the instruction containing the message (u8)
    message_instruction_index: u8,

    /// Create offsets for data embedded in the current instruction
    pub fn forCurrentInstruction(
        signature_offset: u16,
        eth_address_offset: u16,
        message_offset: u16,
        message_size: u16,
    ) SecpSignatureOffsets {
        return SecpSignatureOffsets{
            .signature_offset = signature_offset,
            .signature_instruction_index = 0xFF,
            .eth_address_offset = eth_address_offset,
            .eth_address_instruction_index = 0xFF,
            .message_data_offset = message_offset,
            .message_data_size = message_size,
            .message_instruction_index = 0xFF,
        };
    }

    /// Serialize the offsets to bytes
    pub fn toBytes(self: SecpSignatureOffsets) [SIGNATURE_OFFSETS_SERIALIZED_SIZE]u8 {
        var bytes: [SIGNATURE_OFFSETS_SERIALIZED_SIZE]u8 = undefined;
        std.mem.writeInt(u16, bytes[0..2], self.signature_offset, .little);
        bytes[2] = self.signature_instruction_index;
        std.mem.writeInt(u16, bytes[3..5], self.eth_address_offset, .little);
        bytes[5] = self.eth_address_instruction_index;
        std.mem.writeInt(u16, bytes[6..8], self.message_data_offset, .little);
        std.mem.writeInt(u16, bytes[8..10], self.message_data_size, .little);
        bytes[10] = self.message_instruction_index;
        return bytes;
    }
};

/// Create a Secp256k1 verification instruction with an embedded signature
///
/// This creates an instruction that verifies a single Secp256k1 signature.
/// The signature, recovery ID, Ethereum address, and message are all embedded
/// in the instruction data.
///
/// # Arguments
/// * `allocator` - Memory allocator
/// * `message` - The message that was signed (will be Keccak256 hashed)
/// * `signature` - The 64-byte ECDSA signature (r || s)
/// * `recovery_id` - The recovery ID (0, 1, 2, or 3)
/// * `eth_address` - The 20-byte Ethereum address
///
/// # Returns
/// An instruction for the Secp256k1 program
pub fn createInstruction(
    allocator: std.mem.Allocator,
    message: []const u8,
    signature: *const [SIGNATURE_SERIALIZED_SIZE]u8,
    recovery_id: u8,
    eth_address: *const [HASHED_PUBKEY_SERIALIZED_SIZE]u8,
) !BuiltInstruction {
    // Layout:
    // [0]: num_signatures (u8)
    // [1..12]: SecpSignatureOffsets (11 bytes)
    // [12..76]: signature (64 bytes)
    // [76]: recovery_id (1 byte)
    // [77..97]: eth_address (20 bytes)
    // [97..]: message data

    const sig_with_recovery_size = SIGNATURE_SERIALIZED_SIZE + 1;
    const total_size = DATA_START + sig_with_recovery_size + HASHED_PUBKEY_SERIALIZED_SIZE + message.len;
    var data = try std.ArrayList(u8).initCapacity(allocator, total_size);
    errdefer data.deinit(allocator);

    // Number of signatures
    data.appendAssumeCapacity(1);

    // Calculate offsets
    const signature_offset: u16 = DATA_START;
    const eth_address_offset: u16 = DATA_START + sig_with_recovery_size;
    const message_offset: u16 = DATA_START + sig_with_recovery_size + HASHED_PUBKEY_SERIALIZED_SIZE;

    const offsets = SecpSignatureOffsets.forCurrentInstruction(
        signature_offset,
        eth_address_offset,
        message_offset,
        @intCast(message.len),
    );

    // Write offsets
    data.appendSliceAssumeCapacity(&offsets.toBytes());

    // Write signature
    data.appendSliceAssumeCapacity(signature);

    // Write recovery ID
    data.appendAssumeCapacity(recovery_id);

    // Write Ethereum address
    data.appendSliceAssumeCapacity(eth_address);

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

test "secp256k1_program: program id is correct" {
    // Verify the program ID decodes correctly
    try std.testing.expectEqual(@as(usize, 32), id.bytes.len);
}

test "secp256k1_program: constants are correct" {
    try std.testing.expectEqual(@as(usize, 64), SECP256K1_PUBKEY_SIZE);
    try std.testing.expectEqual(@as(usize, 32), SECP256K1_PRIVATE_KEY_SIZE);
    try std.testing.expectEqual(@as(usize, 20), HASHED_PUBKEY_SERIALIZED_SIZE);
    try std.testing.expectEqual(@as(usize, 64), SIGNATURE_SERIALIZED_SIZE);
    try std.testing.expectEqual(@as(usize, 11), SIGNATURE_OFFSETS_SERIALIZED_SIZE);
    try std.testing.expectEqual(@as(usize, 12), DATA_START);
}

test "secp256k1_program: offsets serialization" {
    const offsets = SecpSignatureOffsets{
        .signature_offset = 0x1234,
        .signature_instruction_index = 0xFF,
        .eth_address_offset = 0x5678,
        .eth_address_instruction_index = 0xFF,
        .message_data_offset = 0x9ABC,
        .message_data_size = 0x00DE,
        .message_instruction_index = 0xFF,
    };

    const bytes = offsets.toBytes();
    try std.testing.expectEqual(@as(usize, 11), bytes.len);

    // Verify encoding
    try std.testing.expectEqual(@as(u16, 0x1234), std.mem.readInt(u16, bytes[0..2], .little));
    try std.testing.expectEqual(@as(u8, 0xFF), bytes[2]);
    try std.testing.expectEqual(@as(u16, 0x5678), std.mem.readInt(u16, bytes[3..5], .little));
}

test "secp256k1_program: create instruction" {
    const allocator = std.testing.allocator;

    const message = "hello ethereum";
    var signature: [64]u8 = undefined;
    @memset(&signature, 0xAB);
    const recovery_id: u8 = 1;
    var eth_address: [20]u8 = undefined;
    @memset(&eth_address, 0xCD);

    var ix = try createInstruction(allocator, message, &signature, recovery_id, &eth_address);
    defer ix.deinit(allocator);

    // Verify program ID
    try std.testing.expectEqualSlices(u8, &id.bytes, &ix.program_id.bytes);

    // Verify data structure
    try std.testing.expectEqual(@as(u8, 1), ix.data[0]); // num_signatures

    // Verify total size: 1 (num) + 11 (offsets) + 64 (sig) + 1 (recovery) + 20 (addr) + msg_len
    const expected_size = 1 + SIGNATURE_OFFSETS_SERIALIZED_SIZE + SIGNATURE_SERIALIZED_SIZE + 1 + HASHED_PUBKEY_SERIALIZED_SIZE + message.len;
    try std.testing.expectEqual(expected_size, ix.data.len);

    // Verify signature at correct offset
    try std.testing.expectEqualSlices(u8, &signature, ix.data[DATA_START..][0..64]);

    // Verify recovery ID
    try std.testing.expectEqual(recovery_id, ix.data[DATA_START + 64]);

    // Verify eth_address at correct offset
    try std.testing.expectEqualSlices(u8, &eth_address, ix.data[DATA_START + 65 ..][0..20]);
}

test "secp256k1_program: forCurrentInstruction helper" {
    const offsets = SecpSignatureOffsets.forCurrentInstruction(12, 77, 97, 100);

    try std.testing.expectEqual(@as(u16, 12), offsets.signature_offset);
    try std.testing.expectEqual(@as(u8, 0xFF), offsets.signature_instruction_index);
    try std.testing.expectEqual(@as(u16, 77), offsets.eth_address_offset);
    try std.testing.expectEqual(@as(u8, 0xFF), offsets.eth_address_instruction_index);
    try std.testing.expectEqual(@as(u16, 97), offsets.message_data_offset);
    try std.testing.expectEqual(@as(u16, 100), offsets.message_data_size);
    try std.testing.expectEqual(@as(u8, 0xFF), offsets.message_instruction_index);
}
