//! Zig implementation of Solana SDK's message module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/message/src/lib.rs
//!
//! This module provides the Message type representing a Solana transaction message.
//! A message contains the account keys, recent blockhash, and instructions to execute.

const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = @import("public_key.zig").PublicKey;
const Hash = sdk.Hash;
const short_vec = sdk.short_vec;
const Instruction = @import("instruction.zig").Instruction;

/// Error types for message operations.
///
/// Rust equivalent: `solana_message::SanitizeError` (subset)
pub const MessageError = error{
    /// Account index out of bounds
    InvalidAccountIndex,
    /// Program ID index out of bounds
    InvalidProgramIndex,
    /// Duplicate account keys
    DuplicateAccountKeys,
    /// Number of required signatures exceeds account count
    NumSignaturesOutOfBounds,
    /// Readonly signed accounts exceeds signed account count
    NumReadonlySignedOutOfBounds,
    /// Readonly unsigned accounts exceeds unsigned account count
    NumReadonlyUnsignedOutOfBounds,
    /// Length encoding overflow (> 65535)
    LengthOverflow,
    /// Allocation failed
    OutOfMemory,
    /// Message has no instructions
    NoInstructions,
};

/// Message header containing signature and account type counts.
///
/// Rust equivalent: `solana_message::MessageHeader`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/message/src/lib.rs
pub const MessageHeader = extern struct {
    /// The number of signatures required for this message to be considered valid.
    /// The signatures must match the first `num_required_signatures` of `account_keys`.
    num_required_signatures: u8,

    /// The last `num_readonly_signed_accounts` of the signed keys are read-only accounts.
    num_readonly_signed_accounts: u8,

    /// The last `num_readonly_unsigned_accounts` of the unsigned keys are read-only accounts.
    num_readonly_unsigned_accounts: u8,

    pub fn default() MessageHeader {
        return .{
            .num_required_signatures = 0,
            .num_readonly_signed_accounts = 0,
            .num_readonly_unsigned_accounts = 0,
        };
    }
};

/// Size of a serialized MessageHeader in bytes
pub const MESSAGE_HEADER_LENGTH: usize = 3;

/// A compiled instruction with indexes into the account_keys array.
///
/// Rust equivalent: `solana_message::CompiledInstruction`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/message/src/compiled_instruction.rs
pub const CompiledInstruction = struct {
    /// Index into the message account_keys array indicating the program_id
    program_id_index: u8,

    /// Indices into the message account_keys array for instruction accounts
    accounts: []const u8,

    /// Instruction data
    data: []const u8,

    /// Create a new compiled instruction
    pub fn init(program_id_index: u8, accounts: []const u8, data: []const u8) CompiledInstruction {
        return .{
            .program_id_index = program_id_index,
            .accounts = accounts,
            .data = data,
        };
    }

    /// Get the program ID from the message account keys
    pub fn programId(self: CompiledInstruction, account_keys: []const PublicKey) PublicKey {
        return account_keys[self.program_id_index];
    }

    /// Validate that all indices are within bounds of the given account_keys.
    ///
    /// Rust equivalent: Part of `Message::sanitize`
    pub fn validate(self: CompiledInstruction, num_account_keys: usize) MessageError!void {
        // Check program_id_index is valid
        if (self.program_id_index >= num_account_keys) {
            return MessageError.InvalidProgramIndex;
        }

        // Check all account indices are valid
        for (self.accounts) |idx| {
            if (idx >= num_account_keys) {
                return MessageError.InvalidAccountIndex;
            }
        }

        // Check lengths don't exceed u16 max (short_vec limit)
        if (self.accounts.len > std.math.maxInt(u16)) {
            return MessageError.LengthOverflow;
        }
        if (self.data.len > std.math.maxInt(u16)) {
            return MessageError.LengthOverflow;
        }
    }

    /// Serialize the compiled instruction using short_vec encoding
    pub fn serialize(self: CompiledInstruction, allocator: std.mem.Allocator) ![]u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 64);
        errdefer buffer.deinit(allocator);

        // Program ID index
        buffer.appendAssumeCapacity(self.program_id_index);

        // Accounts with short_vec length prefix
        var accounts_len_buf: [short_vec.MAX_ENCODING_LENGTH]u8 = undefined;
        const accounts_len_size = short_vec.encodeU16(@intCast(self.accounts.len), &accounts_len_buf);
        try buffer.appendSlice(allocator, accounts_len_buf[0..accounts_len_size]);
        try buffer.appendSlice(allocator, self.accounts);

        // Data with short_vec length prefix
        var data_len_buf: [short_vec.MAX_ENCODING_LENGTH]u8 = undefined;
        const data_len_size = short_vec.encodeU16(@intCast(self.data.len), &data_len_buf);
        try buffer.appendSlice(allocator, data_len_buf[0..data_len_size]);
        try buffer.appendSlice(allocator, self.data);

        return try buffer.toOwnedSlice(allocator);
    }
};

/// A Solana transaction message.
///
/// Rust equivalent: `solana_message::Message` (legacy format)
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/message/src/legacy.rs
pub const Message = struct {
    /// The message header
    header: MessageHeader,

    /// All account keys used by this transaction
    account_keys: []const PublicKey,

    /// A recent blockhash for transaction replay protection
    recent_blockhash: Hash,

    /// Programs that will be executed in sequence
    instructions: []const CompiledInstruction,

    const Self = @This();

    /// Create a new message with the given instructions and optional payer.
    ///
    /// If payer is provided, it will be the first account in account_keys.
    pub fn init(
        header: MessageHeader,
        account_keys: []const PublicKey,
        recent_blockhash: Hash,
        instructions: []const CompiledInstruction,
    ) Self {
        return .{
            .header = header,
            .account_keys = account_keys,
            .recent_blockhash = recent_blockhash,
            .instructions = instructions,
        };
    }

    /// Create a default/empty message
    pub fn default() Self {
        return .{
            .header = MessageHeader.default(),
            .account_keys = &[_]PublicKey{},
            .recent_blockhash = Hash.default(),
            .instructions = &[_]CompiledInstruction{},
        };
    }

    /// Check if the account at the given index is a signer
    pub fn isSigner(self: Self, index: usize) bool {
        return index < self.header.num_required_signatures;
    }

    /// Check if the account at the given index is writable
    pub fn isWritable(self: Self, index: usize) bool {
        const num_signed = self.header.num_required_signatures;
        const num_readonly_signed = self.header.num_readonly_signed_accounts;
        const num_readonly_unsigned = self.header.num_readonly_unsigned_accounts;

        if (index < @as(usize, num_signed)) {
            // It's a signer - check if it's readonly
            const readonly_signed_start = num_signed - num_readonly_signed;
            return index < readonly_signed_start;
        } else {
            // It's unsigned - check if it's readonly
            const num_unsigned = self.account_keys.len - num_signed;
            const readonly_unsigned_start = num_unsigned - num_readonly_unsigned;
            return (index - num_signed) < readonly_unsigned_start;
        }
    }

    /// Get program ID for the instruction at the given index
    pub fn programId(self: Self, instruction_index: usize) ?PublicKey {
        if (instruction_index >= self.instructions.len) {
            return null;
        }
        const ix = self.instructions[instruction_index];
        if (ix.program_id_index >= self.account_keys.len) {
            return null;
        }
        return self.account_keys[ix.program_id_index];
    }

    /// Get all program IDs used in this message
    pub fn programIds(self: Self, allocator: std.mem.Allocator) ![]PublicKey {
        var result = try std.ArrayList(PublicKey).initCapacity(allocator, self.instructions.len);
        errdefer result.deinit(allocator);

        for (self.instructions) |ix| {
            if (ix.program_id_index < self.account_keys.len) {
                result.appendAssumeCapacity(self.account_keys[ix.program_id_index]);
            }
        }

        return try result.toOwnedSlice(allocator);
    }

    /// Get all signer keys
    pub fn signerKeys(self: Self) []const PublicKey {
        return self.account_keys[0..self.header.num_required_signatures];
    }

    /// Check if this message has duplicate account keys
    pub fn hasDuplicates(self: Self) bool {
        for (0..self.account_keys.len) |i| {
            for ((i + 1)..self.account_keys.len) |j| {
                if (std.mem.eql(u8, &self.account_keys[i].bytes, &self.account_keys[j].bytes)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Sanitize and validate the message.
    ///
    /// Performs the following checks (matching Rust's Message::sanitize):
    /// - num_required_signatures <= account_keys.len
    /// - num_readonly_signed_accounts <= num_required_signatures
    /// - num_readonly_unsigned_accounts <= (account_keys.len - num_required_signatures)
    /// - All instruction program_id_index values are valid
    /// - All instruction account indices are valid
    /// - No duplicate account keys
    /// - Lengths don't exceed short_vec limits (u16 max)
    ///
    /// Rust equivalent: `Message::sanitize`
    pub fn sanitize(self: Self) MessageError!void {
        const num_keys = self.account_keys.len;
        const num_signed: usize = self.header.num_required_signatures;
        const num_readonly_signed: usize = self.header.num_readonly_signed_accounts;
        const num_readonly_unsigned: usize = self.header.num_readonly_unsigned_accounts;

        // Check num_required_signatures <= account_keys.len
        if (num_signed > num_keys) {
            return MessageError.NumSignaturesOutOfBounds;
        }

        // Check num_readonly_signed_accounts <= num_required_signatures
        if (num_readonly_signed > num_signed) {
            return MessageError.NumReadonlySignedOutOfBounds;
        }

        // Check num_readonly_unsigned_accounts <= unsigned accounts
        const num_unsigned = num_keys - num_signed;
        if (num_readonly_unsigned > num_unsigned) {
            return MessageError.NumReadonlyUnsignedOutOfBounds;
        }

        // Check all instruction indices are valid
        for (self.instructions) |ix| {
            try ix.validate(num_keys);
        }

        // Check for duplicate account keys
        if (self.hasDuplicates()) {
            return MessageError.DuplicateAccountKeys;
        }

        // Check lengths don't exceed u16 max (short_vec encoding limit)
        if (num_keys > std.math.maxInt(u16)) {
            return MessageError.LengthOverflow;
        }
        if (self.instructions.len > std.math.maxInt(u16)) {
            return MessageError.LengthOverflow;
        }
    }

    /// Serialize the message to bytes.
    ///
    /// Validates the message before serialization using `sanitize()`.
    /// Returns an error if validation fails or serialization cannot be performed.
    ///
    /// Format: header (3 bytes) + account_keys (short_vec) + blockhash (32 bytes) + instructions (short_vec)
    ///
    /// Rust equivalent: `Message::serialize` (with implicit sanitization)
    pub fn serialize(self: Self, allocator: std.mem.Allocator) ![]u8 {
        // Validate message before serialization
        try self.sanitize();

        var buffer = try std.ArrayList(u8).initCapacity(allocator, 256);
        errdefer buffer.deinit(allocator);

        // Header (3 bytes)
        buffer.appendAssumeCapacity(self.header.num_required_signatures);
        buffer.appendAssumeCapacity(self.header.num_readonly_signed_accounts);
        buffer.appendAssumeCapacity(self.header.num_readonly_unsigned_accounts);

        // Account keys with short_vec length prefix
        var num_keys_buf: [short_vec.MAX_ENCODING_LENGTH]u8 = undefined;
        const num_keys_size = short_vec.encodeU16(@intCast(self.account_keys.len), &num_keys_buf);
        try buffer.appendSlice(allocator, num_keys_buf[0..num_keys_size]);
        for (self.account_keys) |key| {
            try buffer.appendSlice(allocator, &key.bytes);
        }

        // Recent blockhash (32 bytes)
        try buffer.appendSlice(allocator, &self.recent_blockhash.bytes);

        // Instructions with short_vec length prefix
        var num_ix_buf: [short_vec.MAX_ENCODING_LENGTH]u8 = undefined;
        const num_ix_size = short_vec.encodeU16(@intCast(self.instructions.len), &num_ix_buf);
        try buffer.appendSlice(allocator, num_ix_buf[0..num_ix_size]);
        for (self.instructions) |ix| {
            const ix_bytes = try ix.serialize(allocator);
            defer allocator.free(ix_bytes);
            try buffer.appendSlice(allocator, ix_bytes);
        }

        return try buffer.toOwnedSlice(allocator);
    }

    /// Hash the serialized message using SHA-256
    pub fn hash(self: Self, allocator: std.mem.Allocator) !Hash {
        const serialized = try self.serialize(allocator);
        defer allocator.free(serialized);
        return hashRawMessage(serialized);
    }

    /// Hash a raw message byte slice
    pub fn hashRawMessage(message_bytes: []const u8) Hash {
        const sha256_hasher = @import("sha256_hasher.zig");
        return sha256_hasher.hash(message_bytes);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "message: MessageHeader default" {
    const header = MessageHeader.default();
    try std.testing.expectEqual(@as(u8, 0), header.num_required_signatures);
    try std.testing.expectEqual(@as(u8, 0), header.num_readonly_signed_accounts);
    try std.testing.expectEqual(@as(u8, 0), header.num_readonly_unsigned_accounts);
}

test "message: MessageHeader size" {
    try std.testing.expectEqual(MESSAGE_HEADER_LENGTH, @sizeOf(MessageHeader));
}

test "message: CompiledInstruction init" {
    const accounts = [_]u8{ 0, 1, 2 };
    const data = [_]u8{ 0xde, 0xad, 0xbe, 0xef };
    const ix = CompiledInstruction.init(3, &accounts, &data);

    try std.testing.expectEqual(@as(u8, 3), ix.program_id_index);
    try std.testing.expectEqualSlices(u8, &accounts, ix.accounts);
    try std.testing.expectEqualSlices(u8, &data, ix.data);
}

test "message: Message default" {
    const msg = Message.default();
    try std.testing.expectEqual(@as(u8, 0), msg.header.num_required_signatures);
    try std.testing.expectEqual(@as(usize, 0), msg.account_keys.len);
    try std.testing.expectEqual(@as(usize, 0), msg.instructions.len);
}

test "message: isSigner" {
    const header = MessageHeader{
        .num_required_signatures = 2,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
        PublicKey.from([_]u8{3} ** 32),
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    try std.testing.expect(msg.isSigner(0));
    try std.testing.expect(msg.isSigner(1));
    try std.testing.expect(!msg.isSigner(2));
}

test "message: isWritable" {
    // 2 signers (1 readonly), 2 unsigned (1 readonly)
    const header = MessageHeader{
        .num_required_signatures = 2,
        .num_readonly_signed_accounts = 1,
        .num_readonly_unsigned_accounts = 1,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32), // signer, writable
        PublicKey.from([_]u8{2} ** 32), // signer, readonly
        PublicKey.from([_]u8{3} ** 32), // unsigned, writable
        PublicKey.from([_]u8{4} ** 32), // unsigned, readonly
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    try std.testing.expect(msg.isWritable(0)); // signer, writable
    try std.testing.expect(!msg.isWritable(1)); // signer, readonly
    try std.testing.expect(msg.isWritable(2)); // unsigned, writable
    try std.testing.expect(!msg.isWritable(3)); // unsigned, readonly
}

test "message: signerKeys" {
    const header = MessageHeader{
        .num_required_signatures = 2,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
        PublicKey.from([_]u8{3} ** 32),
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    const signer_keys = msg.signerKeys();
    try std.testing.expectEqual(@as(usize, 2), signer_keys.len);
    try std.testing.expectEqualSlices(u8, &[_]u8{1} ** 32, &signer_keys[0].bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{2} ** 32, &signer_keys[1].bytes);
}

test "message: hasDuplicates" {
    const keys_no_dup = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
    };
    const msg_no_dup = Message.init(MessageHeader.default(), &keys_no_dup, Hash.default(), &[_]CompiledInstruction{});
    try std.testing.expect(!msg_no_dup.hasDuplicates());

    const keys_with_dup = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{1} ** 32),
    };
    const msg_with_dup = Message.init(MessageHeader.default(), &keys_with_dup, Hash.default(), &[_]CompiledInstruction{});
    try std.testing.expect(msg_with_dup.hasDuplicates());
}

test "message: programId" {
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
    };
    const ix = CompiledInstruction.init(1, &[_]u8{0}, &[_]u8{});
    const ixs = [_]CompiledInstruction{ix};
    const msg = Message.init(MessageHeader.default(), &keys, Hash.default(), &ixs);

    const program_id = msg.programId(0);
    try std.testing.expect(program_id != null);
    try std.testing.expectEqualSlices(u8, &[_]u8{2} ** 32, &program_id.?.bytes);

    // Out of bounds
    try std.testing.expect(msg.programId(1) == null);
}

test "message: serialize and hash" {
    const allocator = std.testing.allocator;

    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    const serialized = try msg.serialize(allocator);
    defer allocator.free(serialized);

    // Should start with header bytes
    try std.testing.expectEqual(@as(u8, 1), serialized[0]); // num_required_signatures
    try std.testing.expectEqual(@as(u8, 0), serialized[1]); // num_readonly_signed_accounts
    try std.testing.expectEqual(@as(u8, 0), serialized[2]); // num_readonly_unsigned_accounts

    // Hash should be deterministic
    const hash1 = try msg.hash(allocator);
    const hash2 = try msg.hash(allocator);
    try std.testing.expectEqualSlices(u8, &hash1.bytes, &hash2.bytes);
}

// ============================================================================
// Sanitize/Validation Tests
// ============================================================================

test "message: sanitize valid message" {
    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 1,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
    };
    const ix = CompiledInstruction.init(1, &[_]u8{0}, &[_]u8{ 0xde, 0xad });
    const ixs = [_]CompiledInstruction{ix};
    const msg = Message.init(header, &keys, Hash.default(), &ixs);

    // Should pass sanitization
    try msg.sanitize();
}

test "message: sanitize NumSignaturesOutOfBounds" {
    const header = MessageHeader{
        .num_required_signatures = 5, // More than account keys
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    try std.testing.expectError(MessageError.NumSignaturesOutOfBounds, msg.sanitize());
}

test "message: sanitize NumReadonlySignedOutOfBounds" {
    const header = MessageHeader{
        .num_required_signatures = 2,
        .num_readonly_signed_accounts = 5, // More than signed accounts
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
        PublicKey.from([_]u8{3} ** 32),
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    try std.testing.expectError(MessageError.NumReadonlySignedOutOfBounds, msg.sanitize());
}

test "message: sanitize NumReadonlyUnsignedOutOfBounds" {
    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 5, // More than unsigned accounts
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    try std.testing.expectError(MessageError.NumReadonlyUnsignedOutOfBounds, msg.sanitize());
}

test "message: sanitize InvalidProgramIndex" {
    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
    };
    // program_id_index = 10, but only 1 account key exists
    const ix = CompiledInstruction.init(10, &[_]u8{0}, &[_]u8{});
    const ixs = [_]CompiledInstruction{ix};
    const msg = Message.init(header, &keys, Hash.default(), &ixs);

    try std.testing.expectError(MessageError.InvalidProgramIndex, msg.sanitize());
}

test "message: sanitize InvalidAccountIndex" {
    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{2} ** 32),
    };
    // program_id_index = 1 (valid), but accounts contains index 10 (invalid)
    const ix = CompiledInstruction.init(1, &[_]u8{ 0, 10 }, &[_]u8{});
    const ixs = [_]CompiledInstruction{ix};
    const msg = Message.init(header, &keys, Hash.default(), &ixs);

    try std.testing.expectError(MessageError.InvalidAccountIndex, msg.sanitize());
}

test "message: sanitize DuplicateAccountKeys" {
    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
        PublicKey.from([_]u8{1} ** 32), // Duplicate
    };
    const msg = Message.init(header, &keys, Hash.default(), &[_]CompiledInstruction{});

    try std.testing.expectError(MessageError.DuplicateAccountKeys, msg.sanitize());
}

test "message: serialize fails on invalid message" {
    const allocator = std.testing.allocator;

    const header = MessageHeader{
        .num_required_signatures = 1,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };
    const keys = [_]PublicKey{
        PublicKey.from([_]u8{1} ** 32),
    };
    // Invalid program_id_index
    const ix = CompiledInstruction.init(10, &[_]u8{0}, &[_]u8{});
    const ixs = [_]CompiledInstruction{ix};
    const msg = Message.init(header, &keys, Hash.default(), &ixs);

    // Serialize should fail because sanitize fails
    try std.testing.expectError(MessageError.InvalidProgramIndex, msg.serialize(allocator));
}

test "message: CompiledInstruction validate" {
    const ix = CompiledInstruction.init(1, &[_]u8{ 0, 1, 2 }, &[_]u8{ 0xde, 0xad });

    // Valid with 3 account keys
    try ix.validate(3);

    // Invalid - program_id_index out of bounds
    try std.testing.expectError(MessageError.InvalidProgramIndex, ix.validate(1));

    // Invalid - account index out of bounds
    const ix2 = CompiledInstruction.init(0, &[_]u8{ 0, 5 }, &[_]u8{});
    try std.testing.expectError(MessageError.InvalidAccountIndex, ix2.validate(3));
}
