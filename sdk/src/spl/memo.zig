//! SPL Memo Program
//!
//! Rust source: https://github.com/solana-program/memo/blob/master/interface/src/lib.rs
//! Instruction: https://github.com/solana-program/memo/blob/master/interface/src/instruction.rs
//!
//! The Memo program is a simple utility program for attaching UTF-8 text to transactions.
//! It validates that the memo data is valid UTF-8 and optionally verifies signers.
//!
//! ## Features
//!
//! - UTF-8 validation of memo text
//! - Optional signer verification (if accounts provided, all must sign)
//! - No instruction discriminator (data = raw UTF-8 bytes)
//! - Used by Token-2022 memo transfer extension
//!
//! ## Usage
//!
//! ```zig
//! const sdk = @import("solana_sdk");
//! const memo = sdk.spl.memo;
//!
//! // Simple memo (no signers)
//! const ix_data = memo.MemoInstruction.init("Hello, Solana!");
//!
//! // With signers - accounts must all be signers
//! const signers = [_]sdk.PublicKey{ signer1, signer2 };
//! // Build instruction with signers as readonly signer accounts
//! ```

const std = @import("std");
const PublicKey = @import("../public_key.zig").PublicKey;
const AccountMeta = @import("../instruction.zig").AccountMeta;

// ============================================================================
// Program IDs
// ============================================================================

/// SPL Memo Program ID (v2/v3 - current version)
///
/// Rust source: https://github.com/solana-program/memo/blob/master/interface/src/lib.rs#L11
pub const MEMO_PROGRAM_ID = PublicKey.comptimeFromBase58("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");

/// SPL Memo Program ID (v1 - legacy version)
///
/// The v1 program has identical functionality but a different address.
/// Most applications should use MEMO_PROGRAM_ID (v2/v3).
///
/// Rust source: https://github.com/solana-program/memo/blob/master/interface/src/lib.rs#L16
pub const MEMO_V1_PROGRAM_ID = PublicKey.comptimeFromBase58("Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo");

// ============================================================================
// Memo Instruction
// ============================================================================

/// Memo instruction data and builder.
///
/// The Memo program has no instruction discriminator - the instruction data
/// is simply the raw UTF-8 bytes of the memo text.
///
/// ## Validation
///
/// The on-chain program validates:
/// 1. **UTF-8**: The memo data must be valid UTF-8
/// 2. **Signers**: If any accounts are provided, ALL must be signers
///
/// ## Example
///
/// ```zig
/// // Create memo instruction data
/// const memo_ix = MemoInstruction.init("Hello, Solana!");
/// const data = memo_ix.getData();
///
/// // Use with instruction builder:
/// // - program_id: MEMO_PROGRAM_ID
/// // - accounts: signers as readonly signer accounts
/// // - data: memo_ix.getData()
/// ```
pub const MemoInstruction = struct {
    /// The memo text (UTF-8 bytes)
    memo: []const u8,

    /// Create a new memo instruction.
    ///
    /// Note: This does NOT validate UTF-8. The on-chain program will reject
    /// invalid UTF-8, but for better error handling, use `initValidated`.
    pub fn init(memo: []const u8) MemoInstruction {
        return .{ .memo = memo };
    }

    /// Create a new memo instruction with UTF-8 validation.
    ///
    /// Returns error if the memo is not valid UTF-8.
    pub fn initValidated(memo: []const u8) error{InvalidUtf8}!MemoInstruction {
        if (!std.unicode.utf8ValidateSlice(memo)) {
            return error.InvalidUtf8;
        }
        return .{ .memo = memo };
    }

    /// Get the instruction data (raw UTF-8 bytes).
    ///
    /// For the Memo program, the instruction data is simply the memo text
    /// with no discriminator or additional encoding.
    pub fn getData(self: MemoInstruction) []const u8 {
        return self.memo;
    }

    /// Get the program ID for memo instructions.
    pub fn getProgramId() PublicKey {
        return MEMO_PROGRAM_ID;
    }

    /// Create account metas for signer accounts.
    ///
    /// All accounts in a memo instruction must be signers (readonly).
    /// Returns a slice of AccountMeta structs for the provided signers.
    ///
    /// Note: The caller must ensure the buffer has enough capacity.
    pub fn createSignerAccounts(signers: []const PublicKey, buffer: []AccountMeta) []AccountMeta {
        const count = @min(signers.len, buffer.len);
        for (signers[0..count], 0..) |signer, i| {
            buffer[i] = AccountMeta.newReadonlySigner(signer);
        }
        return buffer[0..count];
    }
};

// ============================================================================
// Utility Functions
// ============================================================================

/// Validate that a byte slice is valid UTF-8.
///
/// This can be used to pre-validate memo data before sending a transaction.
/// Invalid UTF-8 will cause the on-chain program to fail with
/// `ProgramError::InvalidInstructionData`.
pub fn isValidUtf8(data: []const u8) bool {
    return std.unicode.utf8ValidateSlice(data);
}

/// Get the byte position of the first invalid UTF-8 sequence.
///
/// Returns null if the data is valid UTF-8.
/// Useful for error messages matching the on-chain program's behavior.
pub fn findInvalidUtf8Position(data: []const u8) ?usize {
    var i: usize = 0;
    while (i < data.len) {
        const len = std.unicode.utf8ByteSequenceLength(data[i]) catch {
            return i;
        };
        if (i + len > data.len) {
            return i;
        }
        _ = std.unicode.utf8Decode(data[i..][0..len]) catch {
            return i;
        };
        i += len;
    }
    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "memo: program IDs are correct" {
    // Verify the Program ID matches the expected base58 string
    const expected_v2 = "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr";
    const expected_v1 = "Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo";

    var buffer: [PublicKey.max_base58_len]u8 = undefined;
    try std.testing.expectEqualStrings(expected_v2, MEMO_PROGRAM_ID.toBase58(&buffer));

    var buffer2: [PublicKey.max_base58_len]u8 = undefined;
    try std.testing.expectEqualStrings(expected_v1, MEMO_V1_PROGRAM_ID.toBase58(&buffer2));
}

test "memo: build simple memo instruction" {
    const memo_text = "Hello, Solana!";
    const memo_ix = MemoInstruction.init(memo_text);

    // Instruction data should be the raw memo bytes
    try std.testing.expectEqualStrings(memo_text, memo_ix.getData());
    try std.testing.expectEqual(MEMO_PROGRAM_ID, MemoInstruction.getProgramId());
}

test "memo: build empty memo instruction" {
    const memo_ix = MemoInstruction.init("");
    try std.testing.expectEqual(@as(usize, 0), memo_ix.getData().len);
}

test "memo: build memo with emoji (multi-byte UTF-8)" {
    // Leopard emoji: U+1F406 = F0 9F 90 86 in UTF-8
    const memo_text = "🐆";
    const memo_ix = MemoInstruction.init(memo_text);

    try std.testing.expectEqualStrings(memo_text, memo_ix.getData());
    try std.testing.expectEqual(@as(usize, 4), memo_ix.getData().len);

    // Verify the UTF-8 bytes
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xF0, 0x9F, 0x90, 0x86 }, memo_ix.getData());
}

test "memo: UTF-8 validation - valid ASCII" {
    const valid = "letters and such";
    const result = try MemoInstruction.initValidated(valid);
    try std.testing.expectEqualStrings(valid, result.getData());
}

test "memo: UTF-8 validation - valid emoji" {
    const valid = "🐆";
    const result = MemoInstruction.initValidated(valid);
    try std.testing.expect(result != error.InvalidUtf8);
    const memo_ix = try result;
    try std.testing.expectEqualStrings(valid, memo_ix.getData());
}

test "memo: UTF-8 validation - invalid bytes" {
    // Invalid UTF-8: last byte should be 0x86, not 0xFF
    const invalid = &[_]u8{ 0xF0, 0x9F, 0x90, 0xFF };
    const result = MemoInstruction.initValidated(invalid);
    try std.testing.expectError(error.InvalidUtf8, result);
}

test "memo: isValidUtf8" {
    try std.testing.expect(isValidUtf8("Hello, World!"));
    try std.testing.expect(isValidUtf8("🐆"));
    try std.testing.expect(isValidUtf8(""));
    try std.testing.expect(!isValidUtf8(&[_]u8{ 0xF0, 0x9F, 0x90, 0xFF }));
    try std.testing.expect(!isValidUtf8(&[_]u8{0xFF}));
}

test "memo: findInvalidUtf8Position" {
    // Valid UTF-8
    try std.testing.expectEqual(@as(?usize, null), findInvalidUtf8Position("Hello"));
    try std.testing.expectEqual(@as(?usize, null), findInvalidUtf8Position("🐆"));

    // Invalid at position 0 (0xF0 starts a 4-byte sequence but 0xFF is invalid continuation)
    const invalid1 = &[_]u8{ 0xF0, 0x9F, 0x90, 0xFF };
    try std.testing.expectEqual(@as(?usize, 0), findInvalidUtf8Position(invalid1));

    // Invalid at start
    const invalid2 = &[_]u8{0xFF};
    try std.testing.expectEqual(@as(?usize, 0), findInvalidUtf8Position(invalid2));

    // Valid ASCII followed by invalid
    const invalid3: []const u8 = "Hello" ++ &[_]u8{0xFF};
    try std.testing.expectEqual(@as(?usize, 5), findInvalidUtf8Position(invalid3));
}

test "memo: createSignerAccounts" {
    // Use proper 32-byte keys
    const key1 = PublicKey.from([_]u8{1} ** 32);
    const key2 = PublicKey.from([_]u8{2} ** 32);
    const signers = [_]PublicKey{ key1, key2 };

    var buffer: [10]AccountMeta = undefined;
    const accounts = MemoInstruction.createSignerAccounts(&signers, &buffer);

    try std.testing.expectEqual(@as(usize, 2), accounts.len);

    // First signer
    try std.testing.expectEqual(key1, accounts[0].pubkey);
    try std.testing.expect(accounts[0].is_signer);
    try std.testing.expect(!accounts[0].is_writable);

    // Second signer
    try std.testing.expectEqual(key2, accounts[1].pubkey);
    try std.testing.expect(accounts[1].is_signer);
    try std.testing.expect(!accounts[1].is_writable);
}

test "memo: createSignerAccounts with empty signers" {
    const signers = [_]PublicKey{};
    var buffer: [10]AccountMeta = undefined;
    const accounts = MemoInstruction.createSignerAccounts(&signers, &buffer);

    try std.testing.expectEqual(@as(usize, 0), accounts.len);
}
