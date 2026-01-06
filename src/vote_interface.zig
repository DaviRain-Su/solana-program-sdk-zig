//! Zig implementation of Solana SDK's vote-interface module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/vote-interface/src/lib.rs
//!
//! The Vote program is responsible for validator voting, managing vote accounts,
//! and recording votes for consensus. This interface provides types and instruction
//! builders for interacting with the Vote program.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const Hash = @import("solana_sdk").Hash;
const AccountMeta = @import("instruction.zig").AccountMeta;
const system_program = @import("system_program.zig");
const Rent = @import("rent.zig").Rent;
const Clock = @import("clock.zig").Clock;
const slot_hashes = @import("slot_hashes.zig");

/// Built instruction data for transaction building (off-chain)
pub const BuiltInstruction = system_program.BuiltInstruction;

// ============================================================================
// Constants
// ============================================================================

/// Size of a BLS public key in compressed point representation
/// Rust equivalent: `BLS_PUBLIC_KEY_COMPRESSED_SIZE`
pub const BLS_PUBLIC_KEY_COMPRESSED_SIZE: usize = 48;

/// Size of a BLS proof of possession in compressed point representation
/// Rust equivalent: `BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE`
pub const BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE: usize = 96;

/// Maximum number of votes to keep around, tightly coupled with epoch_schedule::MINIMUM_SLOTS_PER_EPOCH
/// Rust equivalent: `MAX_LOCKOUT_HISTORY`
pub const MAX_LOCKOUT_HISTORY: usize = 31;

/// Initial lockout value
/// Rust equivalent: `INITIAL_LOCKOUT`
pub const INITIAL_LOCKOUT: usize = 2;

/// Maximum number of credits history to keep around
/// Rust equivalent: `MAX_EPOCH_CREDITS_HISTORY`
pub const MAX_EPOCH_CREDITS_HISTORY: usize = 64;

/// Number of slots of grace period for which maximum vote credits are awarded
/// Rust equivalent: `VOTE_CREDITS_GRACE_SLOTS`
pub const VOTE_CREDITS_GRACE_SLOTS: u8 = 2;

/// Maximum number of credits to award for a vote
/// Rust equivalent: `VOTE_CREDITS_MAXIMUM_PER_SLOT`
pub const VOTE_CREDITS_MAXIMUM_PER_SLOT: u8 = 16;

/// Size of VoteStateV4 (current version)
pub const VOTE_STATE_V4_SIZE: usize = 3762;

/// Size of VoteStateV3
pub const VOTE_STATE_V3_SIZE: usize = 3762;

// ============================================================================
// Program ID
// ============================================================================

/// Vote program ID
///
/// Rust equivalent: `solana_sdk_ids::vote::id()`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/sdk-ids/src/lib.rs
pub const ID = PublicKey.comptimeFromBase58("Vote111111111111111111111111111111111111111");

/// Check if the given pubkey is the Vote program ID
pub fn checkId(pubkey: PublicKey) bool {
    return pubkey.equals(ID);
}

// ============================================================================
// Core Types
// ============================================================================

/// Vote lockout - represents a vote with its slot and confirmation count
///
/// Rust equivalent: `solana_vote_interface::state::Lockout`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/vote-interface/src/state/mod.rs
pub const Lockout = struct {
    slot: u64,
    confirmation_count: u32,

    /// Create a new lockout with confirmation count of 1
    pub fn new(slot: u64) Lockout {
        return .{
            .slot = slot,
            .confirmation_count = 1,
        };
    }

    /// Create a new lockout with a specific confirmation count
    pub fn newWithConfirmationCount(slot: u64, confirmation_count: u32) Lockout {
        return .{
            .slot = slot,
            .confirmation_count = confirmation_count,
        };
    }

    /// Calculate the lockout duration (number of slots this vote is locked)
    pub fn lockout(self: Lockout) u64 {
        const exp = @min(self.confirmation_count, MAX_LOCKOUT_HISTORY);
        return std.math.pow(u64, INITIAL_LOCKOUT, exp);
    }

    /// Get the last slot at which this vote is still locked out
    pub fn lastLockedOutSlot(self: Lockout) u64 {
        return self.slot +| self.lockout();
    }

    /// Check if this vote is locked out at a given slot
    pub fn isLockedOutAtSlot(self: Lockout, slot: u64) bool {
        return self.lastLockedOutSlot() >= slot;
    }

    /// Increase the confirmation count
    pub fn increaseConfirmationCount(self: *Lockout, by: u32) void {
        self.confirmation_count = self.confirmation_count +| by;
    }
};

/// Landed vote - a lockout with its landing latency
///
/// Rust equivalent: `solana_vote_interface::state::LandedVote`
pub const LandedVote = struct {
    /// Latency is the difference between the slot voted on and the slot in which the vote landed
    latency: u8,
    lockout: Lockout,

    pub fn slot(self: LandedVote) u64 {
        return self.lockout.slot;
    }

    pub fn confirmationCount(self: LandedVote) u32 {
        return self.lockout.confirmation_count;
    }
};

/// Block timestamp - slot and timestamp pair
///
/// Rust equivalent: `solana_vote_interface::state::BlockTimestamp`
pub const BlockTimestamp = struct {
    slot: u64,
    timestamp: i64, // UnixTimestamp

    pub fn default() BlockTimestamp {
        return .{
            .slot = 0,
            .timestamp = 0,
        };
    }
};

/// Vote - simple vote instruction data
///
/// Rust equivalent: `solana_vote_interface::state::Vote`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/vote-interface/src/state/vote_instruction_data.rs
pub const Vote = struct {
    /// A stack of votes starting with the oldest vote
    slots: []const u64,
    /// Signature of the bank's state at the last slot
    hash: Hash,
    /// Processing timestamp of last slot
    timestamp: ?i64,

    /// Create a new Vote
    pub fn new(slots: []const u64, hash: Hash) Vote {
        return .{
            .slots = slots,
            .hash = hash,
            .timestamp = null,
        };
    }

    /// Get the last voted slot
    pub fn lastVotedSlot(self: Vote) ?u64 {
        if (self.slots.len == 0) return null;
        return self.slots[self.slots.len - 1];
    }
};

/// Vote initialization parameters
///
/// Rust equivalent: `solana_vote_interface::state::VoteInit`
pub const VoteInit = struct {
    node_pubkey: PublicKey,
    authorized_voter: PublicKey,
    authorized_withdrawer: PublicKey,
    commission: u8, // 0-100 percent

    pub fn default() VoteInit {
        return .{
            .node_pubkey = PublicKey.default(),
            .authorized_voter = PublicKey.default(),
            .authorized_withdrawer = PublicKey.default(),
            .commission = 0,
        };
    }

    /// Serialize to bytes (bincode format)
    pub fn serialize(self: VoteInit, buffer: []u8) !usize {
        if (buffer.len < 97) return error.BufferTooSmall;

        @memcpy(buffer[0..32], &self.node_pubkey.bytes);
        @memcpy(buffer[32..64], &self.authorized_voter.bytes);
        @memcpy(buffer[64..96], &self.authorized_withdrawer.bytes);
        buffer[96] = self.commission;

        return 97;
    }

    /// Deserialize from bytes
    pub fn deserialize(data: []const u8) !VoteInit {
        if (data.len < 97) return error.InvalidAccountData;

        return .{
            .node_pubkey = PublicKey.from(data[0..32].*),
            .authorized_voter = PublicKey.from(data[32..64].*),
            .authorized_withdrawer = PublicKey.from(data[64..96].*),
            .commission = data[96],
        };
    }
};

/// Vote authorization type
///
/// Rust equivalent: `solana_vote_interface::state::VoteAuthorize`
pub const VoteAuthorize = enum(u8) {
    Voter = 0,
    Withdrawer = 1,
};

/// Commission kind for revenue collection
///
/// Rust equivalent: `solana_vote_interface::instruction::CommissionKind`
pub const CommissionKind = enum(u8) {
    InflationRewards = 0,
    BlockRevenue = 1,
};

// ============================================================================
// VoteError
// ============================================================================

/// Vote program error types
///
/// Rust equivalent: `solana_vote_interface::error::VoteError`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/vote-interface/src/error.rs
pub const VoteError = enum(u32) {
    VoteTooOld = 0,
    SlotsMismatch = 1,
    SlotHashMismatch = 2,
    EmptySlots = 3,
    TimestampTooOld = 4,
    TooSoonToReauthorize = 5,
    LockoutConflict = 6,
    NewVoteStateLockoutMismatch = 7,
    SlotsNotOrdered = 8,
    ConfirmationsNotOrdered = 9,
    ZeroConfirmations = 10,
    ConfirmationTooLarge = 11,
    RootRollBack = 12,
    ConfirmationRollBack = 13,
    SlotSmallerThanRoot = 14,
    TooManyVotes = 15,
    VotesTooOldAllFiltered = 16,
    RootOnDifferentFork = 17,
    ActiveVoteAccountClose = 18,
    CommissionUpdateTooLate = 19,
    AssertionFailed = 20,

    /// Convert to error message
    pub fn toStr(self: VoteError) []const u8 {
        return switch (self) {
            .VoteTooOld => "vote already recorded or not in slot hashes history",
            .SlotsMismatch => "vote slots do not match bank history",
            .SlotHashMismatch => "vote hash does not match bank hash",
            .EmptySlots => "vote has no slots, invalid",
            .TimestampTooOld => "vote timestamp not recent",
            .TooSoonToReauthorize => "authorized voter has already been changed this epoch",
            .LockoutConflict => "Old state had vote which should not have been popped off by vote in new state",
            .NewVoteStateLockoutMismatch => "Proposed state had earlier slot which should have been popped off by later vote",
            .SlotsNotOrdered => "Vote slots are not ordered",
            .ConfirmationsNotOrdered => "Confirmations are not ordered",
            .ZeroConfirmations => "Zero confirmations",
            .ConfirmationTooLarge => "Confirmation exceeds limit",
            .RootRollBack => "Root rolled back",
            .ConfirmationRollBack => "Confirmations for same vote were smaller in new proposed state",
            .SlotSmallerThanRoot => "New state contained a vote slot smaller than the root",
            .TooManyVotes => "New state contained too many votes",
            .VotesTooOldAllFiltered => "every slot in the vote was older than the SlotHashes history",
            .RootOnDifferentFork => "Proposed root is not in slot hashes",
            .ActiveVoteAccountClose => "Cannot close vote account unless it stopped voting at least one full epoch ago",
            .CommissionUpdateTooLate => "Cannot update commission at this point in the epoch",
            .AssertionFailed => "Assertion failed",
        };
    }

    /// Convert from u32 error code
    pub fn fromU32(value: u32) ?VoteError {
        return std.meta.intToEnum(VoteError, value) catch null;
    }
};

// ============================================================================
// VoteInstruction
// ============================================================================

/// Vote instruction types (simplified enum for instruction index)
///
/// Rust equivalent: `solana_vote_interface::instruction::VoteInstruction`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/vote-interface/src/instruction.rs
pub const VoteInstructionType = enum(u8) {
    /// Initialize a vote account
    InitializeAccount = 0,
    /// Authorize a key to send votes or issue a withdrawal
    Authorize = 1,
    /// A Vote instruction with recent votes
    Vote = 2,
    /// Withdraw some amount of funds
    Withdraw = 3,
    /// Update the vote account's validator identity
    UpdateValidatorIdentity = 4,
    /// Update the commission for the vote account
    UpdateCommission = 5,
    /// A Vote instruction with recent votes and switch proof
    VoteSwitch = 6,
    /// Authorize with the additional requirement that new authority must also be a signer
    AuthorizeChecked = 7,
    /// Update the onchain vote state
    UpdateVoteState = 8,
    /// Update the onchain vote state with switch proof
    UpdateVoteStateSwitch = 9,
    /// Authorize with seed
    AuthorizeWithSeed = 10,
    /// Authorize checked with seed
    AuthorizeCheckedWithSeed = 11,
    /// Compact update vote state
    CompactUpdateVoteState = 12,
    /// Compact update vote state with switch
    CompactUpdateVoteStateSwitch = 13,
    /// Tower sync
    TowerSync = 14,
    /// Tower sync with switch
    TowerSyncSwitch = 15,
    /// Initialize account V2
    InitializeAccountV2 = 16,
    /// Update commission collector
    UpdateCommissionCollector = 17,
    /// Update commission in basis points
    UpdateCommissionBps = 18,
    /// Deposit delegator rewards
    DepositDelegatorRewards = 19,
};

// ============================================================================
// Instruction Builders
// ============================================================================

/// Build instruction to initialize a vote account
///
/// # Account references
///   0. `[WRITE]` Uninitialized vote account
///   1. `[]` Rent sysvar
///   2. `[]` Clock sysvar
///   3. `[SIGNER]` New validator identity (node_pubkey)
///
/// Rust equivalent: `solana_vote_interface::instruction::initialize_account`
pub fn initializeAccount(
    allocator: std.mem.Allocator,
    vote_pubkey: PublicKey,
    vote_init: VoteInit,
) !BuiltInstruction {
    // Instruction data: 4 bytes enum index + VoteInit (97 bytes)
    var data = try allocator.alloc(u8, 4 + 97);
    errdefer allocator.free(data);

    // Write instruction index (InitializeAccount = 0)
    std.mem.writeInt(u32, data[0..4], 0, .little);
    // Write VoteInit
    _ = try vote_init.serialize(data[4..]);

    var accounts = try allocator.alloc(AccountMeta, 4);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(vote_pubkey, false, true); // Vote account (writable)
    accounts[1] = AccountMeta.newReadonly(Rent.id); // Rent sysvar
    accounts[2] = AccountMeta.newReadonly(Clock.id); // Clock sysvar
    accounts[3] = AccountMeta.init(vote_init.node_pubkey, true, false); // Node identity (signer)

    return BuiltInstruction{
        .program_id = ID,
        .accounts = accounts,
        .data = data,
    };
}

/// Build instruction to authorize a new voter or withdrawer
///
/// # Account references
///   0. `[WRITE]` Vote account to be updated
///   1. `[]` Clock sysvar
///   2. `[SIGNER]` Vote or withdraw authority
///
/// Rust equivalent: `solana_vote_interface::instruction::authorize`
pub fn authorize(
    allocator: std.mem.Allocator,
    vote_pubkey: PublicKey,
    authorized_pubkey: PublicKey,
    new_authorized_pubkey: PublicKey,
    vote_authorize: VoteAuthorize,
) !BuiltInstruction {
    // Instruction data: 4 bytes enum index + 32 bytes pubkey + 4 bytes VoteAuthorize
    var data = try allocator.alloc(u8, 4 + 32 + 4);
    errdefer allocator.free(data);

    std.mem.writeInt(u32, data[0..4], @intFromEnum(VoteInstructionType.Authorize), .little);
    @memcpy(data[4..36], &new_authorized_pubkey.bytes);
    std.mem.writeInt(u32, data[36..40], @intFromEnum(vote_authorize), .little);

    var accounts = try allocator.alloc(AccountMeta, 3);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(vote_pubkey, false, true); // Vote account (writable)
    accounts[1] = AccountMeta.newReadonly(Clock.id); // Clock sysvar
    accounts[2] = AccountMeta.init(authorized_pubkey, true, false); // Current authority (signer)

    return BuiltInstruction{
        .program_id = ID,
        .accounts = accounts,
        .data = data,
    };
}

/// Build instruction to withdraw lamports from a vote account
///
/// # Account references
///   0. `[WRITE]` Vote account to withdraw from
///   1. `[WRITE]` Recipient account
///   2. `[SIGNER]` Withdraw authority
///
/// Rust equivalent: `solana_vote_interface::instruction::withdraw`
pub fn withdraw(
    allocator: std.mem.Allocator,
    vote_pubkey: PublicKey,
    authorized_withdrawer_pubkey: PublicKey,
    lamports: u64,
    to_pubkey: PublicKey,
) !BuiltInstruction {
    // Instruction data: 4 bytes enum index + 8 bytes lamports
    var data = try allocator.alloc(u8, 4 + 8);
    errdefer allocator.free(data);

    std.mem.writeInt(u32, data[0..4], @intFromEnum(VoteInstructionType.Withdraw), .little);
    std.mem.writeInt(u64, data[4..12], lamports, .little);

    var accounts = try allocator.alloc(AccountMeta, 3);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(vote_pubkey, false, true); // Vote account (writable)
    accounts[1] = AccountMeta.init(to_pubkey, false, true); // Recipient (writable)
    accounts[2] = AccountMeta.init(authorized_withdrawer_pubkey, true, false); // Withdrawer (signer)

    return BuiltInstruction{
        .program_id = ID,
        .accounts = accounts,
        .data = data,
    };
}

/// Build instruction to update the validator identity
///
/// # Account references
///   0. `[WRITE]` Vote account to be updated
///   1. `[SIGNER]` New validator identity (node_pubkey)
///   2. `[SIGNER]` Withdraw authority
///
/// Rust equivalent: `solana_vote_interface::instruction::update_validator_identity`
pub fn updateValidatorIdentity(
    allocator: std.mem.Allocator,
    vote_pubkey: PublicKey,
    authorized_withdrawer_pubkey: PublicKey,
    node_pubkey: PublicKey,
) !BuiltInstruction {
    // Instruction data: 4 bytes enum index only
    var data = try allocator.alloc(u8, 4);
    errdefer allocator.free(data);

    std.mem.writeInt(u32, data[0..4], @intFromEnum(VoteInstructionType.UpdateValidatorIdentity), .little);

    var accounts = try allocator.alloc(AccountMeta, 3);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(vote_pubkey, false, true); // Vote account (writable)
    accounts[1] = AccountMeta.init(node_pubkey, true, false); // New node identity (signer)
    accounts[2] = AccountMeta.init(authorized_withdrawer_pubkey, true, false); // Withdrawer (signer)

    return BuiltInstruction{
        .program_id = ID,
        .accounts = accounts,
        .data = data,
    };
}

/// Build instruction to update the commission
///
/// # Account references
///   0. `[WRITE]` Vote account to be updated
///   1. `[SIGNER]` Withdraw authority
///
/// Rust equivalent: `solana_vote_interface::instruction::update_commission`
pub fn updateCommission(
    allocator: std.mem.Allocator,
    vote_pubkey: PublicKey,
    authorized_withdrawer_pubkey: PublicKey,
    commission: u8,
) !BuiltInstruction {
    // Instruction data: 4 bytes enum index + 1 byte commission
    var data = try allocator.alloc(u8, 4 + 1);
    errdefer allocator.free(data);

    std.mem.writeInt(u32, data[0..4], @intFromEnum(VoteInstructionType.UpdateCommission), .little);
    data[4] = commission;

    var accounts = try allocator.alloc(AccountMeta, 2);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(vote_pubkey, false, true); // Vote account (writable)
    accounts[1] = AccountMeta.init(authorized_withdrawer_pubkey, true, false); // Withdrawer (signer)

    return BuiltInstruction{
        .program_id = ID,
        .accounts = accounts,
        .data = data,
    };
}

/// Build instructions to create and initialize a vote account
///
/// Returns an array of 2 instructions:
/// 1. System program create_account
/// 2. Vote program initialize_account
///
/// Rust equivalent: `solana_vote_interface::instruction::create_account_with_config`
pub fn createAccount(
    allocator: std.mem.Allocator,
    from_pubkey: PublicKey,
    vote_pubkey: PublicKey,
    vote_init: VoteInit,
    lamports: u64,
) ![]BuiltInstruction {
    var instructions = try allocator.alloc(BuiltInstruction, 2);
    errdefer allocator.free(instructions);

    var initialized: usize = 0;
    errdefer {
        for (instructions[0..initialized]) |*instr| {
            instr.deinit(allocator);
        }
    }

    // 1. Create account with space for VoteStateV4
    instructions[0] = try system_program.createAccount(
        allocator,
        from_pubkey,
        vote_pubkey,
        lamports,
        VOTE_STATE_V4_SIZE,
        ID,
    );
    initialized = 1;

    // 2. Initialize vote account
    instructions[1] = try initializeAccount(allocator, vote_pubkey, vote_init);
    initialized = 2;

    return instructions;
}

/// Free instructions allocated by createAccount
pub fn freeCreateAccountInstructions(allocator: std.mem.Allocator, instructions: []BuiltInstruction) void {
    for (instructions) |*instr| {
        instr.deinit(allocator);
    }
    allocator.free(instructions);
}

// ============================================================================
// Tests
// ============================================================================

test "vote_interface: constants" {
    try std.testing.expectEqual(@as(usize, 48), BLS_PUBLIC_KEY_COMPRESSED_SIZE);
    try std.testing.expectEqual(@as(usize, 96), BLS_PROOF_OF_POSSESSION_COMPRESSED_SIZE);
    try std.testing.expectEqual(@as(usize, 31), MAX_LOCKOUT_HISTORY);
    try std.testing.expectEqual(@as(usize, 2), INITIAL_LOCKOUT);
    try std.testing.expectEqual(@as(usize, 64), MAX_EPOCH_CREDITS_HISTORY);
    try std.testing.expectEqual(@as(u8, 2), VOTE_CREDITS_GRACE_SLOTS);
    try std.testing.expectEqual(@as(u8, 16), VOTE_CREDITS_MAXIMUM_PER_SLOT);
    try std.testing.expectEqual(@as(usize, 3762), VOTE_STATE_V4_SIZE);
}

test "vote_interface: program id" {
    try std.testing.expect(checkId(ID));

    var other = PublicKey.default();
    other.bytes[0] = 1;
    try std.testing.expect(!checkId(other));
}

test "vote_interface: lockout creation" {
    const lockout = Lockout.new(100);
    try std.testing.expectEqual(@as(u64, 100), lockout.slot);
    try std.testing.expectEqual(@as(u32, 1), lockout.confirmation_count);
}

test "vote_interface: lockout with confirmation count" {
    const lockout = Lockout.newWithConfirmationCount(200, 5);
    try std.testing.expectEqual(@as(u64, 200), lockout.slot);
    try std.testing.expectEqual(@as(u32, 5), lockout.confirmation_count);
}

test "vote_interface: lockout calculation" {
    // lockout = INITIAL_LOCKOUT ^ confirmation_count = 2^confirmation_count
    const lockout1 = Lockout.newWithConfirmationCount(0, 1);
    try std.testing.expectEqual(@as(u64, 2), lockout1.lockout());

    const lockout2 = Lockout.newWithConfirmationCount(0, 2);
    try std.testing.expectEqual(@as(u64, 4), lockout2.lockout());

    const lockout3 = Lockout.newWithConfirmationCount(0, 10);
    try std.testing.expectEqual(@as(u64, 1024), lockout3.lockout());

    // MAX_LOCKOUT_HISTORY = 31, so 2^31 = 2147483648
    const lockout_max = Lockout.newWithConfirmationCount(0, 31);
    try std.testing.expectEqual(@as(u64, 2147483648), lockout_max.lockout());

    // Confirmation count > MAX_LOCKOUT_HISTORY should be capped
    const lockout_over = Lockout.newWithConfirmationCount(0, 50);
    try std.testing.expectEqual(@as(u64, 2147483648), lockout_over.lockout());
}

test "vote_interface: last locked out slot" {
    const lockout = Lockout.newWithConfirmationCount(100, 3);
    // lockout = 2^3 = 8
    // last_locked_out_slot = 100 + 8 = 108
    try std.testing.expectEqual(@as(u64, 108), lockout.lastLockedOutSlot());
}

test "vote_interface: is locked out at slot" {
    const lockout = Lockout.newWithConfirmationCount(100, 3);
    // last_locked_out_slot = 108

    try std.testing.expect(lockout.isLockedOutAtSlot(105));
    try std.testing.expect(lockout.isLockedOutAtSlot(108));
    try std.testing.expect(!lockout.isLockedOutAtSlot(109));
}

test "vote_interface: vote init serialization" {
    var buffer: [97]u8 = undefined;

    const init = VoteInit{
        .node_pubkey = PublicKey.from([_]u8{0xAA} ** 32),
        .authorized_voter = PublicKey.from([_]u8{0xBB} ** 32),
        .authorized_withdrawer = PublicKey.from([_]u8{0xCC} ** 32),
        .commission = 10,
    };

    const size = try init.serialize(&buffer);
    try std.testing.expectEqual(@as(usize, 97), size);

    // Verify deserialization
    const deserialized = try VoteInit.deserialize(&buffer);
    try std.testing.expect(deserialized.node_pubkey.equals(init.node_pubkey));
    try std.testing.expect(deserialized.authorized_voter.equals(init.authorized_voter));
    try std.testing.expect(deserialized.authorized_withdrawer.equals(init.authorized_withdrawer));
    try std.testing.expectEqual(init.commission, deserialized.commission);
}

test "vote_interface: vote error from u32" {
    try std.testing.expectEqual(VoteError.VoteTooOld, VoteError.fromU32(0).?);
    try std.testing.expectEqual(VoteError.SlotsMismatch, VoteError.fromU32(1).?);
    try std.testing.expectEqual(VoteError.AssertionFailed, VoteError.fromU32(20).?);
    try std.testing.expectEqual(@as(?VoteError, null), VoteError.fromU32(100));
}

test "vote_interface: vote error to string" {
    try std.testing.expectEqualStrings(
        "vote already recorded or not in slot hashes history",
        VoteError.VoteTooOld.toStr(),
    );
    try std.testing.expectEqualStrings(
        "Cannot close vote account unless it stopped voting at least one full epoch ago",
        VoteError.ActiveVoteAccountClose.toStr(),
    );
}

test "vote_interface: authorize instruction" {
    const allocator = std.testing.allocator;

    const vote_pubkey = PublicKey.from([_]u8{0x11} ** 32);
    const current_auth = PublicKey.from([_]u8{0x22} ** 32);
    const new_auth = PublicKey.from([_]u8{0x33} ** 32);

    var instruction = try authorize(
        allocator,
        vote_pubkey,
        current_auth,
        new_auth,
        .Voter,
    );
    defer instruction.deinit(allocator);

    try std.testing.expect(instruction.program_id.equals(ID));
    try std.testing.expectEqual(@as(usize, 3), instruction.accounts.len);
    try std.testing.expectEqual(@as(usize, 40), instruction.data.len);

    // Check instruction type
    const instr_type = std.mem.readInt(u32, instruction.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 1), instr_type); // Authorize = 1
}

test "vote_interface: withdraw instruction" {
    const allocator = std.testing.allocator;

    const vote_pubkey = PublicKey.from([_]u8{0x11} ** 32);
    const withdrawer = PublicKey.from([_]u8{0x22} ** 32);
    const to = PublicKey.from([_]u8{0x33} ** 32);
    const lamports: u64 = 1_000_000;

    var instruction = try withdraw(allocator, vote_pubkey, withdrawer, lamports, to);
    defer instruction.deinit(allocator);

    try std.testing.expect(instruction.program_id.equals(ID));
    try std.testing.expectEqual(@as(usize, 3), instruction.accounts.len);
    try std.testing.expectEqual(@as(usize, 12), instruction.data.len);

    // Check instruction type
    const instr_type = std.mem.readInt(u32, instruction.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 3), instr_type); // Withdraw = 3

    // Check lamports
    const data_lamports = std.mem.readInt(u64, instruction.data[4..12], .little);
    try std.testing.expectEqual(lamports, data_lamports);
}

test "vote_interface: update commission instruction" {
    const allocator = std.testing.allocator;

    const vote_pubkey = PublicKey.from([_]u8{0x11} ** 32);
    const withdrawer = PublicKey.from([_]u8{0x22} ** 32);
    const commission: u8 = 10;

    var instruction = try updateCommission(allocator, vote_pubkey, withdrawer, commission);
    defer instruction.deinit(allocator);

    try std.testing.expect(instruction.program_id.equals(ID));
    try std.testing.expectEqual(@as(usize, 2), instruction.accounts.len);
    try std.testing.expectEqual(@as(usize, 5), instruction.data.len);

    // Check instruction type
    const instr_type = std.mem.readInt(u32, instruction.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 5), instr_type); // UpdateCommission = 5

    // Check commission
    try std.testing.expectEqual(commission, instruction.data[4]);
}

test "vote_interface: update validator identity instruction" {
    const allocator = std.testing.allocator;

    const vote_pubkey = PublicKey.from([_]u8{0x11} ** 32);
    const withdrawer = PublicKey.from([_]u8{0x22} ** 32);
    const new_node = PublicKey.from([_]u8{0x33} ** 32);

    var instruction = try updateValidatorIdentity(allocator, vote_pubkey, withdrawer, new_node);
    defer instruction.deinit(allocator);

    try std.testing.expect(instruction.program_id.equals(ID));
    try std.testing.expectEqual(@as(usize, 3), instruction.accounts.len);
    try std.testing.expectEqual(@as(usize, 4), instruction.data.len);

    // Check instruction type
    const instr_type = std.mem.readInt(u32, instruction.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 4), instr_type); // UpdateValidatorIdentity = 4

    // Check account order
    try std.testing.expect(instruction.accounts[0].pubkey.equals(vote_pubkey));
    try std.testing.expect(instruction.accounts[1].pubkey.equals(new_node));
    try std.testing.expect(instruction.accounts[2].pubkey.equals(withdrawer));
}

test "vote_interface: initialize account instruction" {
    const allocator = std.testing.allocator;

    const vote_pubkey = PublicKey.from([_]u8{0x11} ** 32);
    const vote_init = VoteInit{
        .node_pubkey = PublicKey.from([_]u8{0x22} ** 32),
        .authorized_voter = PublicKey.from([_]u8{0x33} ** 32),
        .authorized_withdrawer = PublicKey.from([_]u8{0x44} ** 32),
        .commission = 5,
    };

    var instruction = try initializeAccount(allocator, vote_pubkey, vote_init);
    defer instruction.deinit(allocator);

    try std.testing.expect(instruction.program_id.equals(ID));
    try std.testing.expectEqual(@as(usize, 4), instruction.accounts.len);
    try std.testing.expectEqual(@as(usize, 101), instruction.data.len); // 4 + 97

    // Check instruction type
    const instr_type = std.mem.readInt(u32, instruction.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 0), instr_type); // InitializeAccount = 0

    // Check accounts
    try std.testing.expect(instruction.accounts[0].pubkey.equals(vote_pubkey));
    try std.testing.expect(instruction.accounts[0].is_writable);
    try std.testing.expect(!instruction.accounts[0].is_signer);

    try std.testing.expect(instruction.accounts[1].pubkey.equals(Rent.id)); // Rent sysvar
    try std.testing.expect(instruction.accounts[2].pubkey.equals(Clock.id)); // Clock sysvar

    try std.testing.expect(instruction.accounts[3].pubkey.equals(vote_init.node_pubkey));
    try std.testing.expect(instruction.accounts[3].is_signer);
}

test "vote_interface: create account instructions" {
    const allocator = std.testing.allocator;

    const from = PublicKey.from([_]u8{0x11} ** 32);
    const vote_pubkey = PublicKey.from([_]u8{0x22} ** 32);
    const vote_init = VoteInit{
        .node_pubkey = PublicKey.from([_]u8{0x33} ** 32),
        .authorized_voter = PublicKey.from([_]u8{0x44} ** 32),
        .authorized_withdrawer = PublicKey.from([_]u8{0x55} ** 32),
        .commission = 10,
    };
    const lamports: u64 = 10_000_000;

    var instructions = try createAccount(allocator, from, vote_pubkey, vote_init, lamports);
    defer freeCreateAccountInstructions(allocator, instructions);

    try std.testing.expectEqual(@as(usize, 2), instructions.len);

    // First instruction: system program create_account
    try std.testing.expect(instructions[0].program_id.equals(system_program.id));

    // Second instruction: vote program initialize_account
    try std.testing.expect(instructions[1].program_id.equals(ID));
}

test "vote_interface: landed vote" {
    const lockout = Lockout.newWithConfirmationCount(100, 5);
    const landed = LandedVote{
        .latency = 3,
        .lockout = lockout,
    };

    try std.testing.expectEqual(@as(u64, 100), landed.slot());
    try std.testing.expectEqual(@as(u32, 5), landed.confirmationCount());
    try std.testing.expectEqual(@as(u8, 3), landed.latency);
}

test "vote_interface: block timestamp" {
    const ts = BlockTimestamp{
        .slot = 12345,
        .timestamp = 1704067200,
    };

    try std.testing.expectEqual(@as(u64, 12345), ts.slot);
    try std.testing.expectEqual(@as(i64, 1704067200), ts.timestamp);

    const default_ts = BlockTimestamp.default();
    try std.testing.expectEqual(@as(u64, 0), default_ts.slot);
    try std.testing.expectEqual(@as(i64, 0), default_ts.timestamp);
}

test "vote_interface: vote type" {
    const slots = [_]u64{ 100, 101, 102 };
    const hash = Hash.default();

    const vote = Vote.new(&slots, hash);
    try std.testing.expectEqual(@as(?u64, 102), vote.lastVotedSlot());
    try std.testing.expectEqual(@as(?i64, null), vote.timestamp);

    const empty_slots = [_]u64{};
    const empty_vote = Vote.new(&empty_slots, hash);
    try std.testing.expectEqual(@as(?u64, null), empty_vote.lastVotedSlot());
}
