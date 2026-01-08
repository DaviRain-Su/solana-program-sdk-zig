//! Transaction Builder for constructing Solana transactions
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/transaction/src/lib.rs
//!
//! This module provides a fluent API for building Solana transactions.
//! It handles:
//! - Collecting instructions
//! - Deduplicating and ordering account keys
//! - Building the message header
//! - Creating signed transactions
//!
//! ## Usage
//!
//! ```zig
//! var builder = TransactionBuilder.init(allocator);
//! defer builder.deinit();
//!
//! try builder.addInstruction(transfer_ix);
//! try builder.addInstruction(another_ix);
//! builder.setFeePayer(fee_payer_pubkey);
//! builder.setRecentBlockhash(recent_blockhash);
//!
//! const tx = try builder.buildSigned(&[_]*Keypair{&fee_payer_kp});
//! ```

const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;
const Hash = sdk.Hash;
const Signature = sdk.Signature;
const Keypair = sdk.Keypair;
const Instruction = sdk.Instruction;
const AccountMeta = sdk.AccountMeta;

/// Error types for transaction building
pub const BuilderError = error{
    /// No fee payer set
    NoFeePayer,
    /// No recent blockhash set
    NoRecentBlockhash,
    /// No instructions added
    NoInstructions,
    /// Too many account keys
    TooManyAccountKeys,
    /// Too many signers
    TooManySigners,
    /// Duplicate signer not allowed
    DuplicateSigner,
    /// Account key not found
    AccountNotFound,
    /// Signer missing for required account
    MissingSigner,
    /// Memory allocation failed
    OutOfMemory,
};

/// Represents an instruction to be added to a transaction.
///
/// This is the builder's internal representation that matches sdk.Instruction.
pub const InstructionInput = struct {
    /// The program ID that executes this instruction
    program_id: PublicKey,
    /// Accounts required by the instruction
    accounts: []const AccountMeta,
    /// Instruction data
    data: []const u8,
};

/// An entry in the account keys list with metadata
const AccountEntry = struct {
    pubkey: PublicKey,
    is_signer: bool,
    is_writable: bool,
};

/// Transaction Builder for constructing Solana transactions.
///
/// Provides a fluent API for building transactions from instructions.
/// Automatically handles account deduplication and ordering according
/// to Solana's message format requirements.
///
/// ## Account Ordering
///
/// Accounts are ordered as follows:
/// 1. Writable signers (fee payer first)
/// 2. Read-only signers
/// 3. Writable non-signers
/// 4. Read-only non-signers
pub const TransactionBuilder = struct {
    allocator: std.mem.Allocator,

    /// Instructions to include in the transaction
    instructions: std.ArrayList(InstructionInput),

    /// Fee payer public key (optional, will be set as first signer)
    fee_payer: ?PublicKey,

    /// Recent blockhash for transaction replay protection
    recent_blockhash: ?Hash,

    /// Collected account entries (deduplicated)
    account_entries: std.ArrayList(AccountEntry),

    const Self = @This();

    /// Initialize a new transaction builder.
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .instructions = .{ .items = &.{}, .capacity = 0 },
            .fee_payer = null,
            .recent_blockhash = null,
            .account_entries = .{ .items = &.{}, .capacity = 0 },
        };
    }

    /// Clean up resources.
    pub fn deinit(self: *Self) void {
        self.instructions.deinit(self.allocator);
        self.account_entries.deinit(self.allocator);
    }

    /// Set the fee payer for this transaction.
    ///
    /// The fee payer must be a signer and will be placed first in the
    /// account keys array.
    pub fn setFeePayer(self: *Self, pubkey: PublicKey) *Self {
        self.fee_payer = pubkey;
        return self;
    }

    /// Set the recent blockhash for this transaction.
    pub fn setRecentBlockhash(self: *Self, blockhash: Hash) *Self {
        self.recent_blockhash = blockhash;
        return self;
    }

    /// Add an instruction to the transaction.
    ///
    /// Instructions are executed in the order they are added.
    pub fn addInstruction(self: *Self, instruction: InstructionInput) !*Self {
        try self.instructions.append(self.allocator, instruction);
        return self;
    }

    /// Add multiple instructions to the transaction.
    pub fn addInstructions(self: *Self, instructions: []const InstructionInput) !*Self {
        for (instructions) |ix| {
            try self.instructions.append(self.allocator, ix);
        }
        return self;
    }

    /// Build the transaction without signing.
    ///
    /// Returns an unsigned transaction that can be signed later.
    pub fn build(self: *Self) !BuiltTransaction {
        // Validate required fields
        const fee_payer = self.fee_payer orelse return BuilderError.NoFeePayer;
        const blockhash = self.recent_blockhash orelse return BuilderError.NoRecentBlockhash;

        if (self.instructions.items.len == 0) {
            return BuilderError.NoInstructions;
        }

        // Collect all unique accounts
        try self.collectAccounts(fee_payer);

        // Build the message
        const message = try self.buildMessage(blockhash);

        return BuiltTransaction{
            .allocator = self.allocator,
            .message = message,
            .signatures = null,
        };
    }

    /// Build and sign the transaction with the provided keypairs.
    ///
    /// The keypairs must include all required signers, including the fee payer.
    /// After signing, this method verifies all signatures are valid.
    ///
    /// ## Errors
    /// - `MissingSigner` if not all required signers are provided
    /// - `SigningFailed` if cryptographic signing fails
    /// - `SignatureVerificationFailed` if any signature is invalid
    pub fn buildSigned(self: *Self, signers: []const *const Keypair) !BuiltTransaction {
        var tx = try self.build();
        errdefer tx.deinit();

        // Sign the transaction
        try tx.sign(signers);

        // Verify all required signatures are present and valid
        try tx.verify();

        return tx;
    }

    /// Collect and deduplicate all accounts from instructions.
    fn collectAccounts(self: *Self, fee_payer: PublicKey) !void {
        self.account_entries.clearRetainingCapacity();

        // Add fee payer first (always writable signer)
        try self.addOrUpdateAccount(fee_payer, true, true);

        // Add accounts from all instructions
        for (self.instructions.items) |ix| {
            // Add program ID (read-only, non-signer)
            try self.addOrUpdateAccount(ix.program_id, false, false);

            // Add instruction accounts
            for (ix.accounts) |account| {
                try self.addOrUpdateAccount(account.pubkey, account.is_signer, account.is_writable);
            }
        }
    }

    /// Add or update an account entry, promoting permissions as needed.
    fn addOrUpdateAccount(self: *Self, pubkey: PublicKey, is_signer: bool, is_writable: bool) !void {
        // Check if account already exists
        for (self.account_entries.items) |*entry| {
            if (std.mem.eql(u8, &entry.pubkey.bytes, &pubkey.bytes)) {
                // Promote permissions (OR logic)
                entry.is_signer = entry.is_signer or is_signer;
                entry.is_writable = entry.is_writable or is_writable;
                return;
            }
        }

        // Add new entry
        try self.account_entries.append(self.allocator, .{
            .pubkey = pubkey,
            .is_signer = is_signer,
            .is_writable = is_writable,
        });
    }

    /// Build the message from collected accounts and instructions.
    fn buildMessage(self: *Self, blockhash: Hash) !Message {
        // Sort accounts into the correct order
        const sorted = try self.sortAccounts();
        errdefer self.allocator.free(sorted.account_keys);

        // Build compiled instructions
        var compiled_instructions = try std.ArrayList(CompiledInstruction).initCapacity(
            self.allocator,
            self.instructions.items.len,
        );
        errdefer {
            for (compiled_instructions.items) |*cix| {
                self.allocator.free(cix.accounts);
            }
            compiled_instructions.deinit(self.allocator);
        }

        for (self.instructions.items) |ix| {
            const compiled = try self.compileInstruction(ix, sorted.account_keys);
            compiled_instructions.appendAssumeCapacity(compiled);
        }

        return Message{
            .header = sorted.header,
            .account_keys = sorted.account_keys,
            .recent_blockhash = blockhash,
            .instructions = try compiled_instructions.toOwnedSlice(self.allocator),
        };
    }

    /// Sort accounts into message order and build header.
    fn sortAccounts(self: *Self) !struct {
        account_keys: []PublicKey,
        header: MessageHeader,
    } {
        var writable_signers: std.ArrayList(PublicKey) = .{ .items = &.{}, .capacity = 0 };
        defer writable_signers.deinit(self.allocator);
        var readonly_signers: std.ArrayList(PublicKey) = .{ .items = &.{}, .capacity = 0 };
        defer readonly_signers.deinit(self.allocator);
        var writable_non_signers: std.ArrayList(PublicKey) = .{ .items = &.{}, .capacity = 0 };
        defer writable_non_signers.deinit(self.allocator);
        var readonly_non_signers: std.ArrayList(PublicKey) = .{ .items = &.{}, .capacity = 0 };
        defer readonly_non_signers.deinit(self.allocator);

        for (self.account_entries.items) |entry| {
            if (entry.is_signer) {
                if (entry.is_writable) {
                    try writable_signers.append(self.allocator, entry.pubkey);
                } else {
                    try readonly_signers.append(self.allocator, entry.pubkey);
                }
            } else {
                if (entry.is_writable) {
                    try writable_non_signers.append(self.allocator, entry.pubkey);
                } else {
                    try readonly_non_signers.append(self.allocator, entry.pubkey);
                }
            }
        }

        // Build account_keys array
        const total_accounts = writable_signers.items.len +
            readonly_signers.items.len +
            writable_non_signers.items.len +
            readonly_non_signers.items.len;

        if (total_accounts > 256) {
            return BuilderError.TooManyAccountKeys;
        }

        var account_keys = try self.allocator.alloc(PublicKey, total_accounts);
        errdefer self.allocator.free(account_keys);

        var idx: usize = 0;

        // 1. Writable signers (fee payer should already be first)
        for (writable_signers.items) |pk| {
            account_keys[idx] = pk;
            idx += 1;
        }

        // 2. Read-only signers
        for (readonly_signers.items) |pk| {
            account_keys[idx] = pk;
            idx += 1;
        }

        // 3. Writable non-signers
        for (writable_non_signers.items) |pk| {
            account_keys[idx] = pk;
            idx += 1;
        }

        // 4. Read-only non-signers
        for (readonly_non_signers.items) |pk| {
            account_keys[idx] = pk;
            idx += 1;
        }

        const num_required_signatures: u8 = @intCast(writable_signers.items.len + readonly_signers.items.len);
        const num_readonly_signed: u8 = @intCast(readonly_signers.items.len);
        const num_readonly_unsigned: u8 = @intCast(readonly_non_signers.items.len);

        return .{
            .account_keys = account_keys,
            .header = MessageHeader{
                .num_required_signatures = num_required_signatures,
                .num_readonly_signed_accounts = num_readonly_signed,
                .num_readonly_unsigned_accounts = num_readonly_unsigned,
            },
        };
    }

    /// Compile an instruction by resolving account indices.
    fn compileInstruction(self: *Self, ix: InstructionInput, account_keys: []const PublicKey) !CompiledInstruction {
        // Find program_id index
        const program_id_index = self.findAccountIndex(ix.program_id, account_keys) orelse
            return BuilderError.AccountNotFound;

        // Build accounts array
        var accounts = try self.allocator.alloc(u8, ix.accounts.len);
        errdefer self.allocator.free(accounts);

        for (ix.accounts, 0..) |account, i| {
            accounts[i] = self.findAccountIndex(account.pubkey, account_keys) orelse
                return BuilderError.AccountNotFound;
        }

        return CompiledInstruction{
            .program_id_index = program_id_index,
            .accounts = accounts,
            .data = ix.data,
        };
    }

    /// Find the index of an account in the account_keys array.
    fn findAccountIndex(self: *Self, pubkey: PublicKey, account_keys: []const PublicKey) ?u8 {
        _ = self;
        for (account_keys, 0..) |key, i| {
            if (std.mem.eql(u8, &key.bytes, &pubkey.bytes)) {
                return @intCast(i);
            }
        }
        return null;
    }
};

/// Message header for a transaction.
pub const MessageHeader = extern struct {
    num_required_signatures: u8,
    num_readonly_signed_accounts: u8,
    num_readonly_unsigned_accounts: u8,
};

/// A compiled instruction with account indices.
pub const CompiledInstruction = struct {
    program_id_index: u8,
    accounts: []const u8,
    data: []const u8,
};

/// A transaction message.
pub const Message = struct {
    header: MessageHeader,
    account_keys: []const PublicKey,
    recent_blockhash: Hash,
    instructions: []const CompiledInstruction,

    /// Serialize the message to bytes.
    pub fn serialize(self: Message, allocator: std.mem.Allocator) ![]u8 {
        var buffer: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
        errdefer buffer.deinit(allocator);

        // Header (3 bytes)
        try buffer.append(allocator, self.header.num_required_signatures);
        try buffer.append(allocator, self.header.num_readonly_signed_accounts);
        try buffer.append(allocator, self.header.num_readonly_unsigned_accounts);

        // Account keys with short_vec length prefix
        try encodeShortVec(allocator, &buffer, @intCast(self.account_keys.len));
        for (self.account_keys) |key| {
            try buffer.appendSlice(allocator, &key.bytes);
        }

        // Recent blockhash (32 bytes)
        try buffer.appendSlice(allocator, &self.recent_blockhash.bytes);

        // Instructions with short_vec length prefix
        try encodeShortVec(allocator, &buffer, @intCast(self.instructions.len));
        for (self.instructions) |ix| {
            // Program ID index
            try buffer.append(allocator, ix.program_id_index);

            // Accounts with short_vec length prefix
            try encodeShortVec(allocator, &buffer, @intCast(ix.accounts.len));
            try buffer.appendSlice(allocator, ix.accounts);

            // Data with short_vec length prefix
            try encodeShortVec(allocator, &buffer, @intCast(ix.data.len));
            try buffer.appendSlice(allocator, ix.data);
        }

        return try buffer.toOwnedSlice(allocator);
    }
};

/// A built transaction, ready for signing or submission.
pub const BuiltTransaction = struct {
    allocator: std.mem.Allocator,
    message: Message,
    signatures: ?[]Signature,

    const Self = @This();

    /// Clean up resources.
    pub fn deinit(self: *Self) void {
        // Free account_keys
        self.allocator.free(self.message.account_keys);

        // Free compiled instructions
        for (self.message.instructions) |ix| {
            self.allocator.free(ix.accounts);
        }
        self.allocator.free(self.message.instructions);

        // Free signatures
        if (self.signatures) |sigs| {
            self.allocator.free(sigs);
        }
    }

    /// Sign the transaction with the provided keypairs.
    ///
    /// The keypairs must include all required signers.
    pub fn sign(self: *Self, signers: []const *const Keypair) !void {
        const num_required = self.message.header.num_required_signatures;

        // Allocate signatures if not already done
        if (self.signatures == null) {
            self.signatures = try self.allocator.alloc(Signature, num_required);
            for (self.signatures.?) |*sig| {
                sig.* = Signature.default();
            }
        }

        // Serialize message for signing
        const message_bytes = try self.message.serialize(self.allocator);
        defer self.allocator.free(message_bytes);

        // Sign with each keypair
        for (signers) |kp| {
            const pk = kp.pubkey();

            // Find the position of this pubkey in account_keys
            for (self.message.account_keys[0..num_required], 0..) |account_key, i| {
                if (std.mem.eql(u8, &pk.bytes, &account_key.bytes)) {
                    self.signatures.?[i] = kp.sign(message_bytes) catch return error.SigningFailed;
                    break;
                }
            }
        }
    }

    /// Check if the transaction has all required signature slots filled.
    ///
    /// **IMPORTANT**: This is a presence check only - it verifies that all
    /// required signature slots contain non-zero bytes, but does NOT validate
    /// that the signatures are cryptographically correct.
    ///
    /// For signature validation, use `verify()` or `signer.verifyTransaction()`
    /// which performs full cryptographic verification of each signature.
    ///
    /// ## Use Cases
    /// - Quick check before serialization
    /// - Multi-party signing progress tracking
    ///
    /// ## Returns
    /// `true` if all required signature slots are non-zero, `false` otherwise
    pub fn isSigned(self: Self) bool {
        const sigs = self.signatures orelse return false;
        const num_required = self.message.header.num_required_signatures;

        if (sigs.len < num_required) {
            return false;
        }

        for (sigs[0..num_required]) |sig| {
            if (std.mem.eql(u8, &sig.bytes, &[_]u8{0} ** 64)) {
                return false;
            }
        }

        return true;
    }

    /// Verify all signatures in the transaction are cryptographically valid.
    ///
    /// Checks that:
    /// 1. All required signatures are present (non-zero)
    /// 2. Each signature is valid for the corresponding public key
    ///
    /// ## Errors
    /// - `MissingSigner` if signatures are missing
    /// - `SignatureVerificationFailed` if any signature is invalid
    pub fn verify(self: Self) !void {
        const sigs = self.signatures orelse return error.MissingSigner;
        const num_required = self.message.header.num_required_signatures;

        if (sigs.len < num_required) {
            return error.MissingSigner;
        }

        // Serialize message for verification
        const message_bytes = self.message.serialize(self.allocator) catch {
            return error.OutOfMemory;
        };
        defer self.allocator.free(message_bytes);

        // Verify each required signature
        for (sigs[0..num_required], 0..) |sig, i| {
            // Check for default (zero) signature
            if (std.mem.eql(u8, &sig.bytes, &[_]u8{0} ** 64)) {
                return error.MissingSigner;
            }

            // Verify signature
            const pubkey = self.message.account_keys[i];
            sig.verify(message_bytes, &pubkey.bytes) catch {
                return error.SignatureVerificationFailed;
            };
        }
    }

    /// Serialize the transaction to bytes.
    ///
    /// Format: signatures (short_vec) + message
    pub fn serialize(self: Self) ![]u8 {
        var buffer: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
        errdefer buffer.deinit(self.allocator);

        // Signatures with short_vec length prefix
        const sigs = self.signatures orelse &[_]Signature{};
        try encodeShortVec(self.allocator, &buffer, @intCast(sigs.len));
        for (sigs) |sig| {
            try buffer.appendSlice(self.allocator, &sig.bytes);
        }

        // Message
        const message_bytes = try self.message.serialize(self.allocator);
        defer self.allocator.free(message_bytes);
        try buffer.appendSlice(self.allocator, message_bytes);

        return try buffer.toOwnedSlice(self.allocator);
    }

    /// Get the first signature (transaction ID).
    pub fn getSignature(self: Self) ?Signature {
        const sigs = self.signatures orelse return null;
        if (sigs.len == 0) return null;
        return sigs[0];
    }
};

/// Encode a u16 value as short_vec format.
fn encodeShortVec(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), value: u16) !void {
    var val = value;
    while (val >= 0x80) {
        try buffer.append(allocator, @as(u8, @intCast(val & 0x7F)) | 0x80);
        val >>= 7;
    }
    try buffer.append(allocator, @intCast(val));
}

// ============================================================================
// Tests
// ============================================================================

test "builder: basic initialization" {
    const allocator = std.testing.allocator;
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    try std.testing.expectEqual(@as(?PublicKey, null), builder.fee_payer);
    try std.testing.expectEqual(@as(?Hash, null), builder.recent_blockhash);
    try std.testing.expectEqual(@as(usize, 0), builder.instructions.items.len);
}

test "builder: set fee payer and blockhash" {
    const allocator = std.testing.allocator;
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    const fee_payer = PublicKey.from([_]u8{1} ** 32);
    const blockhash = Hash.from([_]u8{2} ** 32);

    _ = builder.setFeePayer(fee_payer);
    _ = builder.setRecentBlockhash(blockhash);

    try std.testing.expect(builder.fee_payer != null);
    try std.testing.expectEqualSlices(u8, &fee_payer.bytes, &builder.fee_payer.?.bytes);
    try std.testing.expect(builder.recent_blockhash != null);
    try std.testing.expectEqualSlices(u8, &blockhash.bytes, &builder.recent_blockhash.?.bytes);
}

test "builder: add instruction" {
    const allocator = std.testing.allocator;
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    const program_id = PublicKey.from([_]u8{3} ** 32);
    const account = AccountMeta{
        .pubkey = PublicKey.from([_]u8{4} ** 32),
        .is_signer = false,
        .is_writable = true,
    };
    const accounts = [_]AccountMeta{account};
    const data = [_]u8{ 0xde, 0xad, 0xbe, 0xef };

    _ = try builder.addInstruction(.{
        .program_id = program_id,
        .accounts = &accounts,
        .data = &data,
    });

    try std.testing.expectEqual(@as(usize, 1), builder.instructions.items.len);
}

test "builder: build requires fee payer" {
    const allocator = std.testing.allocator;
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setRecentBlockhash(Hash.from([_]u8{1} ** 32));

    const program_id = PublicKey.from([_]u8{2} ** 32);
    _ = try builder.addInstruction(.{
        .program_id = program_id,
        .accounts = &[_]AccountMeta{},
        .data = &[_]u8{},
    });

    const result = builder.build();
    try std.testing.expectError(BuilderError.NoFeePayer, result);
}

test "builder: build requires blockhash" {
    const allocator = std.testing.allocator;
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setFeePayer(PublicKey.from([_]u8{1} ** 32));

    const program_id = PublicKey.from([_]u8{2} ** 32);
    _ = try builder.addInstruction(.{
        .program_id = program_id,
        .accounts = &[_]AccountMeta{},
        .data = &[_]u8{},
    });

    const result = builder.build();
    try std.testing.expectError(BuilderError.NoRecentBlockhash, result);
}

test "builder: build requires instructions" {
    const allocator = std.testing.allocator;
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setFeePayer(PublicKey.from([_]u8{1} ** 32));
    _ = builder.setRecentBlockhash(Hash.from([_]u8{2} ** 32));

    const result = builder.build();
    try std.testing.expectError(BuilderError.NoInstructions, result);
}

test "builder: build simple transaction" {
    const allocator = std.testing.allocator;
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    const fee_payer = PublicKey.from([_]u8{1} ** 32);
    const blockhash = Hash.from([_]u8{2} ** 32);
    const program_id = PublicKey.from([_]u8{3} ** 32);

    _ = builder.setFeePayer(fee_payer);
    _ = builder.setRecentBlockhash(blockhash);

    const data = [_]u8{ 0x01, 0x02, 0x03 };
    _ = try builder.addInstruction(.{
        .program_id = program_id,
        .accounts = &[_]AccountMeta{},
        .data = &data,
    });

    var tx = try builder.build();
    defer tx.deinit();

    // Verify message header
    try std.testing.expectEqual(@as(u8, 1), tx.message.header.num_required_signatures);
    try std.testing.expectEqual(@as(u8, 0), tx.message.header.num_readonly_signed_accounts);

    // Verify account keys (fee_payer + program_id)
    try std.testing.expectEqual(@as(usize, 2), tx.message.account_keys.len);
    try std.testing.expectEqualSlices(u8, &fee_payer.bytes, &tx.message.account_keys[0].bytes);

    // Verify instructions
    try std.testing.expectEqual(@as(usize, 1), tx.message.instructions.len);
}

test "builder: account deduplication" {
    const allocator = std.testing.allocator;
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    const fee_payer = PublicKey.from([_]u8{1} ** 32);
    const account1 = PublicKey.from([_]u8{2} ** 32);
    const program_id = PublicKey.from([_]u8{3} ** 32);
    const blockhash = Hash.from([_]u8{4} ** 32);

    _ = builder.setFeePayer(fee_payer);
    _ = builder.setRecentBlockhash(blockhash);

    // Add same account twice with different permissions
    const accounts1 = [_]AccountMeta{
        .{ .pubkey = account1, .is_signer = false, .is_writable = false },
    };
    const accounts2 = [_]AccountMeta{
        .{ .pubkey = account1, .is_signer = false, .is_writable = true },
    };

    _ = try builder.addInstruction(.{
        .program_id = program_id,
        .accounts = &accounts1,
        .data = &[_]u8{},
    });

    _ = try builder.addInstruction(.{
        .program_id = program_id,
        .accounts = &accounts2,
        .data = &[_]u8{},
    });

    var tx = try builder.build();
    defer tx.deinit();

    // Account1 should appear only once, with promoted permissions (writable)
    // Total accounts: fee_payer + account1 + program_id = 3
    try std.testing.expectEqual(@as(usize, 3), tx.message.account_keys.len);
}

test "builder: serialize unsigned transaction" {
    const allocator = std.testing.allocator;
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    const fee_payer = PublicKey.from([_]u8{1} ** 32);
    const blockhash = Hash.from([_]u8{2} ** 32);
    const program_id = PublicKey.from([_]u8{3} ** 32);

    _ = builder.setFeePayer(fee_payer);
    _ = builder.setRecentBlockhash(blockhash);

    _ = try builder.addInstruction(.{
        .program_id = program_id,
        .accounts = &[_]AccountMeta{},
        .data = &[_]u8{ 0x01, 0x02 },
    });

    var tx = try builder.build();
    defer tx.deinit();

    const serialized = try tx.serialize();
    defer allocator.free(serialized);

    // Should have valid structure
    try std.testing.expect(serialized.len > 0);

    // First byte should be signature count (0 for unsigned)
    try std.testing.expectEqual(@as(u8, 0), serialized[0]);
}

test "builder: isSigned is presence check only" {
    const allocator = std.testing.allocator;
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    const fee_payer = PublicKey.from([_]u8{1} ** 32);
    const blockhash = Hash.from([_]u8{2} ** 32);
    const program_id = PublicKey.from([_]u8{3} ** 32);

    _ = builder.setFeePayer(fee_payer);
    _ = builder.setRecentBlockhash(blockhash);

    _ = try builder.addInstruction(.{
        .program_id = program_id,
        .accounts = &[_]AccountMeta{},
        .data = &[_]u8{},
    });

    var tx = try builder.build();
    defer tx.deinit();

    // Unsigned transaction should not be signed
    try std.testing.expect(!tx.isSigned());

    // Manually set arbitrary non-zero bytes as "signature"
    // NOTE: isSigned() only checks for non-zero bytes (presence check),
    // it does NOT validate that signatures are cryptographically correct.
    // For actual validation, use signer.verifyTransaction().
    tx.signatures = try allocator.alloc(Signature, 1);
    tx.signatures.?[0] = Signature.from([_]u8{0xFF} ** 64);

    // isSigned() returns true because slots are non-zero (presence check)
    try std.testing.expect(tx.isSigned());

    // However, verify() should fail because these bytes are NOT a valid Ed25519 signature
    try std.testing.expectError(error.SignatureVerificationFailed, tx.verify());
}

test "builder: verify succeeds with real signatures" {
    const allocator = std.testing.allocator;

    // Create a real keypair for the fee payer
    const fee_payer_kp = Keypair.generate();
    const blockhash = Hash.from([_]u8{2} ** 32);
    const program_id = PublicKey.from([_]u8{3} ** 32);

    var tx_builder = TransactionBuilder.init(allocator);
    defer tx_builder.deinit();

    _ = tx_builder.setFeePayer(fee_payer_kp.pubkey());
    _ = tx_builder.setRecentBlockhash(blockhash);

    _ = try tx_builder.addInstruction(.{
        .program_id = program_id,
        .accounts = &[_]AccountMeta{},
        .data = &[_]u8{ 0x01, 0x02, 0x03 },
    });

    // buildSigned should sign and verify
    var tx = try tx_builder.buildSigned(&[_]*const Keypair{&fee_payer_kp});
    defer tx.deinit();

    // Both presence check and cryptographic verification should pass
    try std.testing.expect(tx.isSigned());
    try tx.verify();
}

test "encodeShortVec: small values" {
    const allocator = std.testing.allocator;
    var buffer: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
    defer buffer.deinit(allocator);

    try encodeShortVec(allocator, &buffer, 0);
    try std.testing.expectEqual(@as(usize, 1), buffer.items.len);
    try std.testing.expectEqual(@as(u8, 0), buffer.items[0]);

    buffer.clearRetainingCapacity();
    try encodeShortVec(allocator, &buffer, 127);
    try std.testing.expectEqual(@as(usize, 1), buffer.items.len);
    try std.testing.expectEqual(@as(u8, 127), buffer.items[0]);
}

test "encodeShortVec: larger values" {
    const allocator = std.testing.allocator;
    var buffer: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
    defer buffer.deinit(allocator);

    try encodeShortVec(allocator, &buffer, 128);
    try std.testing.expectEqual(@as(usize, 2), buffer.items.len);
    try std.testing.expectEqual(@as(u8, 0x80), buffer.items[0]);
    try std.testing.expectEqual(@as(u8, 0x01), buffer.items[1]);

    buffer.clearRetainingCapacity();
    try encodeShortVec(allocator, &buffer, 16384);
    try std.testing.expectEqual(@as(usize, 3), buffer.items.len);
}
