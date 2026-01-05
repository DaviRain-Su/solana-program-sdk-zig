//! Zig implementation of Solana SDK's compute-budget-interface module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/compute-budget-interface/src/lib.rs
//!
//! The compute budget program provides instructions to set compute unit limits,
//! compute unit prices for priority fees, and heap frame sizes for transactions.
//!
//! ## Usage
//!
//! Add compute budget instructions to your transaction to:
//! - Set a specific compute unit limit (default is 200,000 per instruction)
//! - Set a compute unit price for priority fees
//! - Request additional heap memory
//!
//! ```zig
//! const compute_budget = @import("compute_budget.zig");
//!
//! // Create instructions
//! const limit_ix = compute_budget.setComputeUnitLimit(400_000);
//! const price_ix = compute_budget.setComputeUnitPrice(1_000); // 1000 micro-lamports
//! ```

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const Instruction = @import("instruction.zig").Instruction;
const Account = @import("account.zig").Account;

// ============================================================================
// Program ID
// ============================================================================

/// The Compute Budget program ID
///
/// Base58: "ComputeBudget111111111111111111111111111111"
pub const ID = PublicKey.comptimeFromBase58("ComputeBudget111111111111111111111111111111");

/// Alias for the program ID
pub const id = ID;

/// Check if a public key is the compute budget program
pub fn check(pubkey: PublicKey) bool {
    return pubkey.equals(ID);
}

// ============================================================================
// Constants
// ============================================================================

/// Maximum compute units a transaction can consume
pub const MAX_COMPUTE_UNIT_LIMIT: u32 = 1_400_000;

/// Default compute units per instruction
pub const DEFAULT_INSTRUCTION_COMPUTE_UNIT_LIMIT: u32 = 200_000;

/// Maximum heap frame size in bytes (256 KB)
pub const MAX_HEAP_FRAME_BYTES: u32 = 256 * 1024;

/// Minimum/default heap frame size in bytes (32 KB)
pub const MIN_HEAP_FRAME_BYTES: u32 = 32 * 1024;

/// Default heap frame size (same as minimum)
pub const DEFAULT_HEAP_FRAME_BYTES: u32 = MIN_HEAP_FRAME_BYTES;

/// Maximum loaded accounts data size in bytes (64 MB)
pub const MAX_LOADED_ACCOUNTS_DATA_SIZE_BYTES: u32 = 64 * 1024 * 1024;

/// Heap cost per 32KB page (in compute units)
pub const DEFAULT_HEAP_COST: u64 = 8;

/// Maximum builtin allocation compute unit limit
pub const MAX_BUILTIN_ALLOCATION_COMPUTE_UNIT_LIMIT: u32 = 3_000;

/// Micro-lamports per lamport (for compute unit price calculations)
pub const MICRO_LAMPORTS_PER_LAMPORT: u64 = 1_000_000;

// ============================================================================
// Instruction Types
// ============================================================================

/// Compute Budget instruction discriminators
///
/// Rust equivalent: `ComputeBudgetInstruction`
pub const ComputeBudgetInstruction = enum(u8) {
    /// Deprecated and unused
    unused = 0,

    /// Request a specific transaction-wide program heap region size in bytes.
    /// The value requested must be a multiple of 1024.
    /// This allocates bytes in addition to the default heap of 32KB.
    request_heap_frame = 1,

    /// Set a specific compute unit limit that the transaction is allowed to consume.
    /// The default is 200,000 compute units per instruction.
    set_compute_unit_limit = 2,

    /// Set a compute unit price in "micro-lamports" to pay a higher transaction
    /// fee for higher transaction prioritization.
    set_compute_unit_price = 3,

    /// Set a specific transaction-wide account data size limit, in bytes.
    set_loaded_accounts_data_size_limit = 4,
};

// ============================================================================
// Instruction Data Buffers
// ============================================================================

/// Instruction data for RequestHeapFrame (1 byte discriminator + 4 bytes u32)
pub const RequestHeapFrameData = extern struct {
    discriminator: u8 = @intFromEnum(ComputeBudgetInstruction.request_heap_frame),
    bytes_le: [4]u8,

    const SIZE: usize = 5;

    pub fn init(bytes: u32) RequestHeapFrameData {
        return .{
            .bytes_le = std.mem.toBytes(std.mem.nativeToLittle(u32, bytes)),
        };
    }

    pub fn toBytes(self: *const RequestHeapFrameData) []const u8 {
        return @as([*]const u8, @ptrCast(self))[0..SIZE];
    }
};

/// Instruction data for SetComputeUnitLimit (1 byte discriminator + 4 bytes u32)
pub const SetComputeUnitLimitData = extern struct {
    discriminator: u8 = @intFromEnum(ComputeBudgetInstruction.set_compute_unit_limit),
    units_le: [4]u8,

    const SIZE: usize = 5;

    pub fn init(units: u32) SetComputeUnitLimitData {
        return .{
            .units_le = std.mem.toBytes(std.mem.nativeToLittle(u32, units)),
        };
    }

    pub fn toBytes(self: *const SetComputeUnitLimitData) []const u8 {
        return @as([*]const u8, @ptrCast(self))[0..SIZE];
    }
};

/// Instruction data for SetComputeUnitPrice (1 byte discriminator + 8 bytes u64)
pub const SetComputeUnitPriceData = extern struct {
    discriminator: u8 = @intFromEnum(ComputeBudgetInstruction.set_compute_unit_price),
    micro_lamports_le: [8]u8,

    const SIZE: usize = 9;

    pub fn init(micro_lamports: u64) SetComputeUnitPriceData {
        return .{
            .micro_lamports_le = std.mem.toBytes(std.mem.nativeToLittle(u64, micro_lamports)),
        };
    }

    pub fn toBytes(self: *const SetComputeUnitPriceData) []const u8 {
        return @as([*]const u8, @ptrCast(self))[0..SIZE];
    }
};

/// Instruction data for SetLoadedAccountsDataSizeLimit (1 byte discriminator + 4 bytes u32)
pub const SetLoadedAccountsDataSizeLimitData = extern struct {
    discriminator: u8 = @intFromEnum(ComputeBudgetInstruction.set_loaded_accounts_data_size_limit),
    bytes_le: [4]u8,

    const SIZE: usize = 5;

    pub fn init(bytes: u32) SetLoadedAccountsDataSizeLimitData {
        return .{
            .bytes_le = std.mem.toBytes(std.mem.nativeToLittle(u32, bytes)),
        };
    }

    pub fn toBytes(self: *const SetLoadedAccountsDataSizeLimitData) []const u8 {
        return @as([*]const u8, @ptrCast(self))[0..SIZE];
    }
};

// ============================================================================
// Instruction Builders
// ============================================================================

/// Request a specific transaction-wide program heap region size in bytes.
///
/// The value requested must be a multiple of 1024. This instruction allocates
/// bytes in addition to the default heap of 32KB.
///
/// Parameters:
/// - bytes: The heap frame size in bytes (must be multiple of 1024)
///
/// Returns: Instruction data that can be used to build an Instruction
///
/// Rust equivalent: `ComputeBudgetInstruction::request_heap_frame`
pub fn requestHeapFrame(bytes: u32) RequestHeapFrameData {
    return RequestHeapFrameData.init(bytes);
}

/// Set a specific compute unit limit that the transaction is allowed to consume.
///
/// The default compute unit limit is 200,000 per instruction, with a maximum
/// of 1,400,000 per transaction.
///
/// Parameters:
/// - units: The compute unit limit
///
/// Returns: Instruction data that can be used to build an Instruction
///
/// Rust equivalent: `ComputeBudgetInstruction::set_compute_unit_limit`
pub fn setComputeUnitLimit(units: u32) SetComputeUnitLimitData {
    return SetComputeUnitLimitData.init(units);
}

/// Set a compute unit price in "micro-lamports" for priority fees.
///
/// A higher compute unit price will make the transaction more likely to be
/// included in a block when the network is congested. The fee is calculated as:
/// `prioritization_fee = compute_unit_price * compute_units / 1_000_000`
///
/// Parameters:
/// - micro_lamports: The price per compute unit in micro-lamports (1 lamport = 1,000,000 micro-lamports)
///
/// Returns: Instruction data that can be used to build an Instruction
///
/// Rust equivalent: `ComputeBudgetInstruction::set_compute_unit_price`
pub fn setComputeUnitPrice(micro_lamports: u64) SetComputeUnitPriceData {
    return SetComputeUnitPriceData.init(micro_lamports);
}

/// Set a specific transaction-wide account data size limit.
///
/// This limits the total size of account data that can be loaded for the transaction.
/// Maximum is 64 MB.
///
/// Parameters:
/// - bytes: The account data size limit in bytes
///
/// Returns: Instruction data that can be used to build an Instruction
///
/// Rust equivalent: `ComputeBudgetInstruction::set_loaded_accounts_data_size_limit`
pub fn setLoadedAccountsDataSizeLimit(bytes: u32) SetLoadedAccountsDataSizeLimitData {
    return SetLoadedAccountsDataSizeLimitData.init(bytes);
}

// ============================================================================
// Full Instruction Builders (for use with Transaction)
// ============================================================================

/// Create a full RequestHeapFrame instruction
pub fn requestHeapFrameInstruction(bytes: u32) struct {
    data: RequestHeapFrameData,

    pub fn toInstruction(self: *const @This()) Instruction {
        return Instruction.from(.{
            .program_id = &ID,
            .accounts = &[_]Account.Param{}, // No accounts needed
            .data = self.data.toBytes(),
        });
    }
} {
    return .{ .data = requestHeapFrame(bytes) };
}

/// Create a full SetComputeUnitLimit instruction
pub fn setComputeUnitLimitInstruction(units: u32) struct {
    data: SetComputeUnitLimitData,

    pub fn toInstruction(self: *const @This()) Instruction {
        return Instruction.from(.{
            .program_id = &ID,
            .accounts = &[_]Account.Param{}, // No accounts needed
            .data = self.data.toBytes(),
        });
    }
} {
    return .{ .data = setComputeUnitLimit(units) };
}

/// Create a full SetComputeUnitPrice instruction
pub fn setComputeUnitPriceInstruction(micro_lamports: u64) struct {
    data: SetComputeUnitPriceData,

    pub fn toInstruction(self: *const @This()) Instruction {
        return Instruction.from(.{
            .program_id = &ID,
            .accounts = &[_]Account.Param{}, // No accounts needed
            .data = self.data.toBytes(),
        });
    }
} {
    return .{ .data = setComputeUnitPrice(micro_lamports) };
}

/// Create a full SetLoadedAccountsDataSizeLimit instruction
pub fn setLoadedAccountsDataSizeLimitInstruction(bytes: u32) struct {
    data: SetLoadedAccountsDataSizeLimitData,

    pub fn toInstruction(self: *const @This()) Instruction {
        return Instruction.from(.{
            .program_id = &ID,
            .accounts = &[_]Account.Param{}, // No accounts needed
            .data = self.data.toBytes(),
        });
    }
} {
    return .{ .data = setLoadedAccountsDataSizeLimit(bytes) };
}

// ============================================================================
// Tests
// ============================================================================

test "compute_budget: program ID" {
    // Verify the program ID matches the expected base58 string
    const expected = "ComputeBudget111111111111111111111111111111";
    var buf: [44]u8 = undefined;
    const encoded = ID.toBase58(&buf);
    try std.testing.expectEqualStrings(expected, encoded);
}

test "compute_budget: check function" {
    try std.testing.expect(check(ID));
    try std.testing.expect(!check(PublicKey.default()));
}

test "compute_budget: constants" {
    try std.testing.expectEqual(@as(u32, 1_400_000), MAX_COMPUTE_UNIT_LIMIT);
    try std.testing.expectEqual(@as(u32, 200_000), DEFAULT_INSTRUCTION_COMPUTE_UNIT_LIMIT);
    try std.testing.expectEqual(@as(u32, 256 * 1024), MAX_HEAP_FRAME_BYTES);
    try std.testing.expectEqual(@as(u32, 32 * 1024), MIN_HEAP_FRAME_BYTES);
    try std.testing.expectEqual(@as(u32, 64 * 1024 * 1024), MAX_LOADED_ACCOUNTS_DATA_SIZE_BYTES);
    try std.testing.expectEqual(@as(u64, 1_000_000), MICRO_LAMPORTS_PER_LAMPORT);
}

test "compute_budget: instruction discriminators" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(ComputeBudgetInstruction.unused));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(ComputeBudgetInstruction.request_heap_frame));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(ComputeBudgetInstruction.set_compute_unit_limit));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(ComputeBudgetInstruction.set_compute_unit_price));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(ComputeBudgetInstruction.set_loaded_accounts_data_size_limit));
}

test "compute_budget: RequestHeapFrame serialization" {
    const data = requestHeapFrame(65536);
    const bytes = data.toBytes();

    try std.testing.expectEqual(@as(usize, 5), bytes.len);
    try std.testing.expectEqual(@as(u8, 1), bytes[0]); // discriminator

    // Little-endian u32: 65536 = 0x00010000
    try std.testing.expectEqual(@as(u8, 0x00), bytes[1]);
    try std.testing.expectEqual(@as(u8, 0x00), bytes[2]);
    try std.testing.expectEqual(@as(u8, 0x01), bytes[3]);
    try std.testing.expectEqual(@as(u8, 0x00), bytes[4]);
}

test "compute_budget: SetComputeUnitLimit serialization" {
    const data = setComputeUnitLimit(400_000);
    const bytes = data.toBytes();

    try std.testing.expectEqual(@as(usize, 5), bytes.len);
    try std.testing.expectEqual(@as(u8, 2), bytes[0]); // discriminator

    // Little-endian u32: 400000 = 0x00061A80
    const expected_value = std.mem.toBytes(@as(u32, 400_000));
    try std.testing.expectEqualSlices(u8, &expected_value, bytes[1..5]);
}

test "compute_budget: SetComputeUnitPrice serialization" {
    const data = setComputeUnitPrice(1_000_000);
    const bytes = data.toBytes();

    try std.testing.expectEqual(@as(usize, 9), bytes.len);
    try std.testing.expectEqual(@as(u8, 3), bytes[0]); // discriminator

    // Little-endian u64
    const expected_value = std.mem.toBytes(@as(u64, 1_000_000));
    try std.testing.expectEqualSlices(u8, &expected_value, bytes[1..9]);
}

test "compute_budget: SetLoadedAccountsDataSizeLimit serialization" {
    const data = setLoadedAccountsDataSizeLimit(10 * 1024 * 1024);
    const bytes = data.toBytes();

    try std.testing.expectEqual(@as(usize, 5), bytes.len);
    try std.testing.expectEqual(@as(u8, 4), bytes[0]); // discriminator

    // Little-endian u32: 10MB = 10485760
    const expected_value = std.mem.toBytes(@as(u32, 10 * 1024 * 1024));
    try std.testing.expectEqualSlices(u8, &expected_value, bytes[1..5]);
}

test "compute_budget: instruction builders create valid instructions" {
    // SetComputeUnitLimit
    {
        var ix_builder = setComputeUnitLimitInstruction(500_000);
        const ix = ix_builder.toInstruction();
        try std.testing.expectEqual(&ID, ix.program_id);
        try std.testing.expectEqual(@as(usize, 0), ix.accounts_len);
        try std.testing.expectEqual(@as(usize, 5), ix.data_len);
    }

    // SetComputeUnitPrice
    {
        var ix_builder = setComputeUnitPriceInstruction(100_000);
        const ix = ix_builder.toInstruction();
        try std.testing.expectEqual(&ID, ix.program_id);
        try std.testing.expectEqual(@as(usize, 0), ix.accounts_len);
        try std.testing.expectEqual(@as(usize, 9), ix.data_len);
    }
}
