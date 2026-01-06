//! Zig implementation of Solana SDK's feature-gate-interface module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/feature-gate-interface/src/lib.rs
//!
//! Runtime features provide a mechanism for features to be simultaneously activated across the
//! network. Since validators may choose when to upgrade, features must remain dormant until a
//! sufficient majority of the network is running a version that would support a given feature.
//!
//! Feature activation is accomplished by:
//! 1. Activation is requested by the feature authority, who issues a transaction to create the
//!    feature account. The newly created feature account will have the value of `Feature.default()`
//! 2. When the next epoch is entered the runtime will check for new activation requests and
//!    activate them. When this occurs, the activation slot is recorded in the feature account.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const AccountMeta = @import("instruction.zig").AccountMeta;
const system_program = @import("system_program.zig");
const Rent = @import("rent.zig").Rent;

/// Built instruction data for transaction building (off-chain)
pub const BuiltInstruction = system_program.BuiltInstruction;

/// Feature Gate program ID
///
/// Rust equivalent: `solana_sdk_ids::feature::id()`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/sdk-ids/src/lib.rs
pub const ID = PublicKey.comptimeFromBase58("Feature111111111111111111111111111111111111");

/// Incinerator address for burning lamports
pub const INCINERATOR_ID = PublicKey.comptimeFromBase58("1nc1nerator11111111111111111111111111111111");

/// Check if the given pubkey is the Feature program ID
pub fn checkId(pubkey: PublicKey) bool {
    return pubkey.equals(ID);
}

/// Feature state
///
/// Rust equivalent: `solana_feature_gate_interface::Feature`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/feature-gate-interface/src/state.rs
pub const Feature = struct {
    /// The slot at which this feature was activated, or null if not yet activated
    activated_at: ?u64,

    /// Size of a serialized Feature (1 byte tag + 8 bytes u64)
    /// Rust equivalent: `Feature::size_of()`
    pub const SIZE: usize = 9;

    /// Create a default (unactivated) feature
    pub fn default() Feature {
        return .{ .activated_at = null };
    }

    /// Create an activated feature at the given slot
    pub fn activated(slot: u64) Feature {
        return .{ .activated_at = slot };
    }

    /// Check if the feature is activated
    pub fn isActivated(self: Feature) bool {
        return self.activated_at != null;
    }

    /// Serialize the Feature to bytes
    /// Format: 1 byte tag (0=None, 1=Some) + 8 bytes u64 (if Some)
    pub fn serialize(self: Feature, buffer: []u8) !usize {
        if (buffer.len < SIZE) {
            return error.BufferTooSmall;
        }

        if (self.activated_at) |slot| {
            buffer[0] = 1; // Some tag
            std.mem.writeInt(u64, buffer[1..9], slot, .little);
        } else {
            buffer[0] = 0; // None tag
            // Fill remaining bytes with zeros for consistency
            @memset(buffer[1..9], 0);
        }
        return SIZE;
    }

    /// Deserialize a Feature from bytes
    pub fn deserialize(data: []const u8) !Feature {
        if (data.len < SIZE) {
            return error.InvalidAccountData;
        }

        const tag = data[0];
        if (tag == 0) {
            return .{ .activated_at = null };
        } else if (tag == 1) {
            const slot = std.mem.readInt(u64, data[1..9], .little);
            return .{ .activated_at = slot };
        } else {
            return error.InvalidAccountData;
        }
    }
};

/// Feature Gate program error types
///
/// Rust equivalent: `solana_feature_gate_interface::FeatureGateError`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/feature-gate-interface/src/error.rs
pub const FeatureGateError = enum(u32) {
    /// Feature already activated
    FeatureAlreadyActivated = 0,

    /// Convert to error message
    pub fn toStr(self: FeatureGateError) []const u8 {
        return switch (self) {
            .FeatureAlreadyActivated => "Feature already activated",
        };
    }

    /// Convert from u32 error code
    pub fn fromU32(value: u32) ?FeatureGateError {
        return switch (value) {
            0 => .FeatureAlreadyActivated,
            else => null,
        };
    }
};

/// Instructions for the Feature Gate program
pub const FeatureGateInstruction = enum(u8) {
    /// Revoke a pending feature activation
    ///
    /// A pending feature activation may only be revoked by the identity key
    /// that created it.
    ///
    /// Accounts expected by this instruction:
    /// 0. `[WRITE, SIGNER]` Feature account to revoke
    /// 1. `[WRITE]` Incinerator account (burned lamports go here)
    /// 2. `[]` System program
    RevokePendingActivation = 0,
};

/// Build instructions to activate a feature
///
/// Creates a sequence of system program instructions to:
/// 1. Transfer lamports from funding account to feature account
/// 2. Allocate space for the Feature data
/// 3. Assign the account to the Feature program
///
/// Returns an array of 3 instructions that must be freed with freeActivateInstructions.
///
/// Rust equivalent: `solana_feature_gate_interface::instruction::activate`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/feature-gate-interface/src/instruction.rs
pub fn activate(
    allocator: std.mem.Allocator,
    feature_id: PublicKey,
    funding_address: PublicKey,
    rent: *const Rent,
) ![]BuiltInstruction {
    const lamports = rent.minimumBalance(Feature.SIZE);
    return activateWithLamports(allocator, feature_id, funding_address, lamports);
}

/// Build instructions to activate a feature with specific lamports amount
///
/// Rust equivalent: `solana_feature_gate_interface::instruction::activate_with_lamports`
pub fn activateWithLamports(
    allocator: std.mem.Allocator,
    feature_id: PublicKey,
    funding_address: PublicKey,
    lamports: u64,
) ![]BuiltInstruction {
    var instructions = try allocator.alloc(BuiltInstruction, 3);
    errdefer allocator.free(instructions);

    // Track which instructions succeeded for cleanup on error
    var initialized: usize = 0;
    errdefer {
        for (instructions[0..initialized]) |*instr| {
            instr.deinit(allocator);
        }
    }

    // 1. Transfer lamports to the feature account
    instructions[0] = try system_program.transfer(allocator, funding_address, feature_id, lamports);
    initialized = 1;

    // 2. Allocate space for Feature data
    instructions[1] = try system_program.allocate(allocator, feature_id, Feature.SIZE);
    initialized = 2;

    // 3. Assign to the Feature program
    instructions[2] = try system_program.assign(allocator, feature_id, ID);
    initialized = 3;

    return instructions;
}

/// Build instruction to revoke a pending feature activation
///
/// A feature can only be revoked before it is activated by the runtime.
/// The lamports in the feature account are transferred to the incinerator.
///
/// Rust equivalent: `solana_feature_gate_interface::instruction::revoke_pending_activation`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/feature-gate-interface/src/instruction.rs
pub fn revokePendingActivation(
    allocator: std.mem.Allocator,
    feature_id: PublicKey,
) !BuiltInstruction {
    // Instruction data: just the instruction index
    var data = try allocator.alloc(u8, 1);
    errdefer allocator.free(data);
    data[0] = @intFromEnum(FeatureGateInstruction.RevokePendingActivation);

    var accounts = try allocator.alloc(AccountMeta, 3);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(feature_id, true, true); // Feature account (signer, writable)
    accounts[1] = AccountMeta.init(INCINERATOR_ID, false, true); // Incinerator (writable)
    accounts[2] = AccountMeta.newReadonly(system_program.id); // System program

    return BuiltInstruction{
        .program_id = ID,
        .accounts = accounts,
        .data = data,
    };
}

/// Free instruction resources allocated by activate or activateWithLamports
pub fn freeActivateInstructions(allocator: std.mem.Allocator, instructions: []BuiltInstruction) void {
    for (instructions) |*instr| {
        instr.deinit(allocator);
    }
    allocator.free(instructions);
}

// ============================================================================
// Tests
// ============================================================================

// Rust test: test_feature_size_of
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/feature-gate-interface/src/state.rs#L57
test "feature_gate: feature size" {
    // Feature::size_of() should be 9 bytes (1 byte tag + 8 bytes u64)
    try std.testing.expectEqual(@as(usize, 9), Feature.SIZE);

    // Verify serialization sizes
    var buffer: [Feature.SIZE]u8 = undefined;

    const default_feature = Feature.default();
    const default_size = try default_feature.serialize(&buffer);
    try std.testing.expectEqual(@as(usize, 9), default_size);

    const activated_feature = Feature.activated(0);
    const activated_size = try activated_feature.serialize(&buffer);
    try std.testing.expectEqual(@as(usize, 9), activated_size);

    const max_feature = Feature.activated(std.math.maxInt(u64));
    const max_size = try max_feature.serialize(&buffer);
    try std.testing.expectEqual(@as(usize, 9), max_size);
}

test "feature_gate: feature serialization roundtrip" {
    var buffer: [Feature.SIZE]u8 = undefined;

    // Test default (None)
    const default_feature = Feature.default();
    _ = try default_feature.serialize(&buffer);
    const deserialized_default = try Feature.deserialize(&buffer);
    try std.testing.expectEqual(default_feature.activated_at, deserialized_default.activated_at);

    // Test activated at slot 0
    const feature_0 = Feature.activated(0);
    _ = try feature_0.serialize(&buffer);
    const deserialized_0 = try Feature.deserialize(&buffer);
    try std.testing.expectEqual(feature_0.activated_at, deserialized_0.activated_at);

    // Test activated at max slot
    const feature_max = Feature.activated(std.math.maxInt(u64));
    _ = try feature_max.serialize(&buffer);
    const deserialized_max = try Feature.deserialize(&buffer);
    try std.testing.expectEqual(feature_max.activated_at, deserialized_max.activated_at);
}

test "feature_gate: feature default is unactivated" {
    const feature = Feature.default();
    try std.testing.expect(!feature.isActivated());
    try std.testing.expectEqual(@as(?u64, null), feature.activated_at);
}

test "feature_gate: feature activated" {
    const slot: u64 = 12345;
    const feature = Feature.activated(slot);
    try std.testing.expect(feature.isActivated());
    try std.testing.expectEqual(@as(?u64, slot), feature.activated_at);
}

test "feature_gate: error from u32" {
    try std.testing.expectEqual(FeatureGateError.FeatureAlreadyActivated, FeatureGateError.fromU32(0).?);
    try std.testing.expectEqual(@as(?FeatureGateError, null), FeatureGateError.fromU32(1));
    try std.testing.expectEqual(@as(?FeatureGateError, null), FeatureGateError.fromU32(999));
}

test "feature_gate: error to string" {
    const err = FeatureGateError.FeatureAlreadyActivated;
    try std.testing.expectEqualStrings("Feature already activated", err.toStr());
}

test "feature_gate: program id" {
    // Verify program ID is correct
    try std.testing.expect(checkId(ID));

    // Verify different key doesn't match
    var other = PublicKey.default();
    other.bytes[0] = 1;
    try std.testing.expect(!checkId(other));
}

test "feature_gate: revoke pending activation instruction" {
    const allocator = std.testing.allocator;

    var feature_id = PublicKey.default();
    feature_id.bytes[0] = 0xAB;

    var instruction = try revokePendingActivation(allocator, feature_id);
    defer instruction.deinit(allocator);

    // Verify instruction structure
    try std.testing.expect(instruction.program_id.equals(ID));
    try std.testing.expectEqual(@as(usize, 3), instruction.accounts.len);
    try std.testing.expectEqual(@as(usize, 1), instruction.data.len);
    try std.testing.expectEqual(@as(u8, 0), instruction.data[0]); // RevokePendingActivation = 0

    // Verify accounts
    try std.testing.expect(instruction.accounts[0].pubkey.equals(feature_id));
    try std.testing.expect(instruction.accounts[0].is_signer);
    try std.testing.expect(instruction.accounts[0].is_writable);

    try std.testing.expect(instruction.accounts[1].pubkey.equals(INCINERATOR_ID));
    try std.testing.expect(!instruction.accounts[1].is_signer);
    try std.testing.expect(instruction.accounts[1].is_writable);

    try std.testing.expect(instruction.accounts[2].pubkey.equals(system_program.id));
    try std.testing.expect(!instruction.accounts[2].is_signer);
    try std.testing.expect(!instruction.accounts[2].is_writable);
}

test "feature_gate: activate with lamports instructions" {
    const allocator = std.testing.allocator;

    const feature_id = PublicKey.from([_]u8{0xAB} ** 32);
    const funding = PublicKey.from([_]u8{0xCD} ** 32);
    const lamports: u64 = 1_000_000;

    var instructions = try activateWithLamports(allocator, feature_id, funding, lamports);
    defer freeActivateInstructions(allocator, instructions);

    // Should create 3 instructions
    try std.testing.expectEqual(@as(usize, 3), instructions.len);

    // 1. Transfer instruction
    try std.testing.expect(instructions[0].program_id.equals(system_program.id));
    try std.testing.expectEqual(@as(u8, 2), instructions[0].data[0]); // Transfer = 2

    // 2. Allocate instruction
    try std.testing.expect(instructions[1].program_id.equals(system_program.id));
    try std.testing.expectEqual(@as(u8, 8), instructions[1].data[0]); // Allocate = 8

    // 3. Assign instruction
    try std.testing.expect(instructions[2].program_id.equals(system_program.id));
    try std.testing.expectEqual(@as(u8, 1), instructions[2].data[0]); // Assign = 1
}
