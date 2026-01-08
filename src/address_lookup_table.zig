//! Zig implementation of Solana SDK's address-lookup-table-interface module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/state.rs
//!
//! Address Lookup Tables (ALTs) allow transactions to reference more accounts
//! while staying within size limits. Instead of including full 32-byte public keys,
//! transactions can reference addresses by their 1-byte index in a lookup table.
//!
//! ## Key Types
//! - `AddressLookupTable` - The main lookup table structure
//! - `LookupTableMeta` - Metadata about the table (authority, slots, etc.)
//! - `LookupTableStatus` - Whether the table is active, deactivating, or deactivated
//!
//! ## Usage
//! ALTs are created, extended, and managed through the Address Lookup Table program.
//! Programs typically only need to read/lookup addresses from existing tables.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;

// ============================================================================
// Constants
// ============================================================================

/// Address Lookup Table program ID
///
/// Rust equivalent: `solana_sdk::address_lookup_table::program::ID`
pub const ID = PublicKey.comptimeFromBase58("AddressLookupTab1e1111111111111111111111111");

/// Maximum number of addresses that a lookup table can hold
///
/// Rust equivalent: `LOOKUP_TABLE_MAX_ADDRESSES`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/state.rs#L28
pub const LOOKUP_TABLE_MAX_ADDRESSES: usize = 256;

/// The serialized size of lookup table metadata (56 bytes)
///
/// Rust equivalent: `LOOKUP_TABLE_META_SIZE`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/state.rs#L31
pub const LOOKUP_TABLE_META_SIZE: usize = 56;

/// Slot value indicating the table has never been deactivated
pub const SLOT_MAX: u64 = std.math.maxInt(u64);

/// Number of slots in SlotHashes sysvar (used for deactivation cooldown)
const SLOT_HASHES_MAX_ENTRIES: usize = 512;

// ============================================================================
// Error Types
// ============================================================================

/// Errors that can occur during address lookup operations
///
/// Rust equivalent: `AddressLookupError`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/error.rs
pub const AddressLookupError = error{
    /// Attempted to lookup addresses from a table that does not exist
    LookupTableAccountNotFound,
    /// Attempted to lookup addresses from an account owned by the wrong program
    InvalidAccountOwner,
    /// Attempted to lookup addresses from an invalid account
    InvalidAccountData,
    /// Address lookup contains an invalid index
    InvalidLookupIndex,
    /// Table is not active (deactivated)
    LookupTableNotActive,
};

// ============================================================================
// State Types
// ============================================================================

/// Activation status of a lookup table
///
/// Rust equivalent: `LookupTableStatus`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/state.rs#L34-L40
pub const LookupTableStatus = union(enum) {
    /// Table is active and can be used for lookups
    activated: void,
    /// Table is being deactivated, will be deactivated after remaining_blocks
    deactivating: struct {
        remaining_blocks: usize,
    },
    /// Table is fully deactivated and can be closed
    deactivated: void,
};

/// Address lookup table metadata
///
/// Rust equivalent: `LookupTableMeta`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/state.rs#L42-L63
pub const LookupTableMeta = struct {
    /// Lookup tables cannot be closed until the deactivation slot is
    /// no longer "recent" (not accessible in the SlotHashes sysvar).
    /// Set to SLOT_MAX when table is active.
    deactivation_slot: u64,

    /// The slot that the table was last extended. Address tables may
    /// only be used to lookup addresses that were extended before
    /// the current bank's slot.
    last_extended_slot: u64,

    /// The start index where the table was last extended from during
    /// the `last_extended_slot`.
    last_extended_slot_start_index: u8,

    /// Authority address which must sign for each modification.
    /// None if the table is frozen (immutable).
    authority: ?PublicKey,

    /// Check if the table has been deactivated
    pub fn isDeactivated(self: LookupTableMeta) bool {
        return self.deactivation_slot != SLOT_MAX;
    }

    /// Get the status of this lookup table
    ///
    /// Rust equivalent: `LookupTableMeta::status`
    pub fn status(self: LookupTableMeta, current_slot: u64, slot_hashes: ?[]const u64) LookupTableStatus {
        if (self.deactivation_slot == SLOT_MAX) {
            return .activated;
        }

        if (self.deactivation_slot == current_slot) {
            return .{ .deactivating = .{ .remaining_blocks = SLOT_HASHES_MAX_ENTRIES + 1 } };
        }

        // Check if deactivation_slot is still in slot_hashes
        if (slot_hashes) |hashes| {
            for (hashes, 0..) |hash_slot, position| {
                if (hash_slot == self.deactivation_slot) {
                    return .{ .deactivating = .{
                        .remaining_blocks = SLOT_HASHES_MAX_ENTRIES -| position,
                    } };
                }
            }
        }

        return .deactivated;
    }

    /// Check if the table is active for address lookups
    pub fn isActive(self: LookupTableMeta, current_slot: u64, slot_hashes: ?[]const u64) bool {
        return switch (self.status(current_slot, slot_hashes)) {
            .activated, .deactivating => true,
            .deactivated => false,
        };
    }
};

/// Program account states
///
/// Rust equivalent: `ProgramState`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/state.rs#L121-L131
pub const ProgramState = union(enum) {
    /// Account is not initialized
    uninitialized: void,
    /// Initialized LookupTable account
    lookup_table: LookupTableMeta,
};

/// An address lookup table
///
/// Rust equivalent: `AddressLookupTable`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/state.rs#L133-L138
pub const AddressLookupTable = struct {
    /// Table metadata
    meta: LookupTableMeta,
    /// The addresses stored in the table (up to 256)
    addresses: []const PublicKey,

    /// Deserialize an address lookup table from account data
    ///
    /// This performs zero-copy deserialization where possible.
    /// Validates that:
    /// - Data length is exactly LOOKUP_TABLE_META_SIZE + 32 * num_addresses
    /// - last_extended_slot_start_index <= num_addresses
    ///
    /// Rust equivalent: `AddressLookupTable::deserialize`
    /// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/state.rs#L228
    pub fn deserialize(data: []const u8) AddressLookupError!AddressLookupTable {
        if (data.len < LOOKUP_TABLE_META_SIZE) {
            return AddressLookupError.InvalidAccountData;
        }

        // Parse the metadata
        const meta = parseMeta(data[0..LOOKUP_TABLE_META_SIZE]) catch {
            return AddressLookupError.InvalidAccountData;
        };

        // Parse addresses (remaining data after metadata)
        const addresses_data = data[LOOKUP_TABLE_META_SIZE..];

        // Each address is 32 bytes - strict length check
        // Rust requires: data.len == LOOKUP_TABLE_META_SIZE + 32 * num_addresses
        if (addresses_data.len % 32 != 0) {
            return AddressLookupError.InvalidAccountData;
        }

        const num_addresses = addresses_data.len / 32;
        if (num_addresses > LOOKUP_TABLE_MAX_ADDRESSES) {
            return AddressLookupError.InvalidAccountData;
        }

        // Validate last_extended_slot_start_index
        // Rust requires: last_extended_slot_start_index <= num_addresses
        // This prevents referencing addresses that don't exist
        if (meta.last_extended_slot_start_index > num_addresses) {
            return AddressLookupError.InvalidAccountData;
        }

        // Cast the byte slice to a PublicKey slice (zero-copy)
        const addresses = std.mem.bytesAsSlice(PublicKey, addresses_data);

        return AddressLookupTable{
            .meta = meta,
            .addresses = addresses,
        };
    }

    /// Look up a single address by index
    pub fn lookup(self: AddressLookupTable, index: u8) AddressLookupError!PublicKey {
        if (index >= self.addresses.len) {
            return AddressLookupError.InvalidLookupIndex;
        }
        return self.addresses[index];
    }

    /// Look up multiple addresses by their indexes
    ///
    /// Returns the addresses in the same order as the indexes.
    pub fn lookupMany(
        self: AddressLookupTable,
        allocator: std.mem.Allocator,
        indexes: []const u8,
    ) AddressLookupError![]PublicKey {
        var result = allocator.alloc(PublicKey, indexes.len) catch {
            return AddressLookupError.InvalidAccountData;
        };
        errdefer allocator.free(result);

        for (indexes, 0..) |idx, i| {
            if (idx >= self.addresses.len) {
                allocator.free(result);
                return AddressLookupError.InvalidLookupIndex;
            }
            result[i] = self.addresses[idx];
        }

        return result;
    }

    /// Get the number of active addresses that can be looked up
    ///
    /// Addresses added in the current slot are not yet active.
    pub fn getActiveAddressesLen(
        self: AddressLookupTable,
        current_slot: u64,
    ) usize {
        if (self.meta.last_extended_slot == 0) {
            // Table has never been extended, all addresses are active
            return self.addresses.len;
        }

        if (current_slot > self.meta.last_extended_slot) {
            // All addresses were added in previous slots, all are active
            return self.addresses.len;
        }

        // Some addresses were added in the current slot
        // Only addresses before last_extended_slot_start_index are active
        return self.meta.last_extended_slot_start_index;
    }

    /// Check if the table is active for lookups
    pub fn isActive(self: AddressLookupTable, current_slot: u64, slot_hashes: ?[]const u64) bool {
        return self.meta.isActive(current_slot, slot_hashes);
    }
};

// ============================================================================
// Instruction Types
// ============================================================================

/// Address Lookup Table program instructions
///
/// Rust equivalent: `ProgramInstruction`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/instruction.rs
pub const ProgramInstruction = union(enum) {
    /// Create a new address lookup table
    ///
    /// Account references:
    ///   0. `[WRITE]` Uninitialized address lookup table account
    ///   1. `[SIGNER]` Account used to derive and control the new address lookup table
    ///   2. `[SIGNER, WRITE]` Account that will fund the new address lookup table
    ///   3. `[]` System program for CPI
    create_lookup_table: struct {
        recent_slot: u64,
        bump_seed: u8,
    },

    /// Permanently freeze an address lookup table, making it immutable
    ///
    /// Account references:
    ///   0. `[WRITE]` Address lookup table account to freeze
    ///   1. `[SIGNER]` Current authority
    freeze_lookup_table: void,

    /// Extend an address lookup table with new addresses
    ///
    /// Account references:
    ///   0. `[WRITE]` Address lookup table account to extend
    ///   1. `[SIGNER]` Current authority
    ///   2. `[SIGNER, WRITE, OPTIONAL]` Account that will fund the table reallocation
    ///   3. `[OPTIONAL]` System program for CPI
    extend_lookup_table: struct {
        new_addresses: []const PublicKey,
    },

    /// Deactivate an address lookup table
    ///
    /// Account references:
    ///   0. `[WRITE]` Address lookup table account to deactivate
    ///   1. `[SIGNER]` Current authority
    deactivate_lookup_table: void,

    /// Close an address lookup table account
    ///
    /// Account references:
    ///   0. `[WRITE]` Address lookup table account to close
    ///   1. `[SIGNER]` Current authority
    ///   2. `[WRITE]` Recipient of closed account lamports
    close_lookup_table: void,
};

// ============================================================================
// Helper Functions
// ============================================================================

/// Derive the address of a lookup table account
///
/// Rust equivalent: `derive_lookup_table_address`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/address-lookup-table-interface/src/instruction.rs#L69
pub fn deriveLookupTableAddress(
    authority: PublicKey,
    recent_slot: u64,
) struct { address: PublicKey, bump_seed: u8 } {
    var slot_bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &slot_bytes, recent_slot, .little);

    const seeds = [_][]const u8{
        &authority.bytes,
        &slot_bytes,
    };

    const result = PublicKey.findProgramAddress(&seeds, ID) catch {
        // This should not happen with valid inputs
        return .{
            .address = PublicKey.default(),
            .bump_seed = 0,
        };
    };
    return .{
        .address = result.address,
        .bump_seed = result.bump_seed[0],
    };
}

/// Check if a public key is the Address Lookup Table program ID
pub fn check(pubkey: PublicKey) bool {
    return pubkey.equals(ID);
}

// ============================================================================
// Internal Helpers
// ============================================================================

fn parseMeta(data: *const [LOOKUP_TABLE_META_SIZE]u8) !LookupTableMeta {
    // Metadata layout (56 bytes total):
    // - u32: account type discriminator (4 bytes) - must be 1 for LookupTable
    // - u64: deactivation_slot (8 bytes)
    // - u64: last_extended_slot (8 bytes)
    // - u8: last_extended_slot_start_index (1 byte)
    // - u8: has_authority flag (1 byte)
    // - [32]u8: authority pubkey (32 bytes)
    // - u16: padding (2 bytes)

    var pos: usize = 0;

    // Read discriminator
    const discriminator = std.mem.readInt(u32, data[pos..][0..4], .little);
    pos += 4;

    if (discriminator != 1) {
        // 0 = Uninitialized, 1 = LookupTable
        return error.InvalidAccountData;
    }

    // Read deactivation_slot
    const deactivation_slot = std.mem.readInt(u64, data[pos..][0..8], .little);
    pos += 8;

    // Read last_extended_slot
    const last_extended_slot = std.mem.readInt(u64, data[pos..][0..8], .little);
    pos += 8;

    // Read last_extended_slot_start_index
    const last_extended_slot_start_index = data[pos];
    pos += 1;

    // Read has_authority flag
    const has_authority = data[pos] != 0;
    pos += 1;

    // Read authority pubkey
    var authority_bytes: [32]u8 = undefined;
    @memcpy(&authority_bytes, data[pos..][0..32]);
    // Note: 2 bytes of padding follow but we don't need to read them

    const authority: ?PublicKey = if (has_authority) PublicKey.from(authority_bytes) else null;

    return LookupTableMeta{
        .deactivation_slot = deactivation_slot,
        .last_extended_slot = last_extended_slot,
        .last_extended_slot_start_index = last_extended_slot_start_index,
        .authority = authority,
    };
}

/// Serialize lookup table metadata to bytes
pub fn serializeMeta(meta: LookupTableMeta) [LOOKUP_TABLE_META_SIZE]u8 {
    var data: [LOOKUP_TABLE_META_SIZE]u8 = [_]u8{0} ** LOOKUP_TABLE_META_SIZE;
    var pos: usize = 0;

    // Write discriminator (1 = LookupTable)
    std.mem.writeInt(u32, data[pos..][0..4], 1, .little);
    pos += 4;

    // Write deactivation_slot
    std.mem.writeInt(u64, data[pos..][0..8], meta.deactivation_slot, .little);
    pos += 8;

    // Write last_extended_slot
    std.mem.writeInt(u64, data[pos..][0..8], meta.last_extended_slot, .little);
    pos += 8;

    // Write last_extended_slot_start_index
    data[pos] = meta.last_extended_slot_start_index;
    pos += 1;

    // Write has_authority flag and authority
    if (meta.authority) |auth| {
        data[pos] = 1;
        pos += 1;
        @memcpy(data[pos..][0..32], &auth.bytes);
    } else {
        data[pos] = 0;
        pos += 1;
        // Leave authority bytes as zero
    }

    return data;
}

// ============================================================================
// Tests
// ============================================================================

test "address_lookup_table: ID constant" {
    const expected = "AddressLookupTab1e1111111111111111111111111";
    var buf: [44]u8 = undefined;
    const actual = ID.toBase58(&buf);
    try std.testing.expectEqualStrings(expected, actual);
}

test "address_lookup_table: check function" {
    try std.testing.expect(check(ID));

    const other = PublicKey.from([_]u8{0} ** 32);
    try std.testing.expect(!check(other));
}

test "address_lookup_table: constants" {
    try std.testing.expectEqual(@as(usize, 256), LOOKUP_TABLE_MAX_ADDRESSES);
    try std.testing.expectEqual(@as(usize, 56), LOOKUP_TABLE_META_SIZE);
}

test "address_lookup_table: LookupTableStatus - activated" {
    const meta = LookupTableMeta{
        .deactivation_slot = SLOT_MAX,
        .last_extended_slot = 100,
        .last_extended_slot_start_index = 0,
        .authority = null,
    };

    const status = meta.status(200, null);
    try std.testing.expectEqual(LookupTableStatus.activated, status);
    try std.testing.expect(meta.isActive(200, null));
}

test "address_lookup_table: LookupTableStatus - deactivating same slot" {
    const meta = LookupTableMeta{
        .deactivation_slot = 100,
        .last_extended_slot = 50,
        .last_extended_slot_start_index = 0,
        .authority = null,
    };

    const status = meta.status(100, null);
    switch (status) {
        .deactivating => |info| {
            try std.testing.expectEqual(@as(usize, SLOT_HASHES_MAX_ENTRIES + 1), info.remaining_blocks);
        },
        else => try std.testing.expect(false),
    }
}

test "address_lookup_table: LookupTableStatus - deactivated" {
    const meta = LookupTableMeta{
        .deactivation_slot = 100,
        .last_extended_slot = 50,
        .last_extended_slot_start_index = 0,
        .authority = null,
    };

    // With empty slot_hashes, deactivation_slot not found = deactivated
    const empty_hashes = [_]u64{};
    const status = meta.status(1000, &empty_hashes);
    try std.testing.expectEqual(LookupTableStatus.deactivated, status);
    try std.testing.expect(!meta.isActive(1000, &empty_hashes));
}

test "address_lookup_table: serialize and deserialize meta" {
    const authority = PublicKey.from([_]u8{1} ** 32);

    const original = LookupTableMeta{
        .deactivation_slot = SLOT_MAX,
        .last_extended_slot = 12345,
        .last_extended_slot_start_index = 5,
        .authority = authority,
    };

    const serialized = serializeMeta(original);
    const parsed = try parseMeta(&serialized);

    try std.testing.expectEqual(original.deactivation_slot, parsed.deactivation_slot);
    try std.testing.expectEqual(original.last_extended_slot, parsed.last_extended_slot);
    try std.testing.expectEqual(original.last_extended_slot_start_index, parsed.last_extended_slot_start_index);
    try std.testing.expect(parsed.authority != null);
    try std.testing.expect(parsed.authority.?.equals(authority));
}

test "address_lookup_table: serialize and deserialize meta without authority" {
    const original = LookupTableMeta{
        .deactivation_slot = 1000,
        .last_extended_slot = 500,
        .last_extended_slot_start_index = 10,
        .authority = null,
    };

    const serialized = serializeMeta(original);
    const parsed = try parseMeta(&serialized);

    try std.testing.expectEqual(original.deactivation_slot, parsed.deactivation_slot);
    try std.testing.expectEqual(original.last_extended_slot, parsed.last_extended_slot);
    try std.testing.expectEqual(original.last_extended_slot_start_index, parsed.last_extended_slot_start_index);
    try std.testing.expect(parsed.authority == null);
}

test "address_lookup_table: deserialize full table" {
    const authority = PublicKey.from([_]u8{1} ** 32);
    const addr1 = PublicKey.from([_]u8{2} ** 32);
    const addr2 = PublicKey.from([_]u8{3} ** 32);

    const meta = LookupTableMeta{
        .deactivation_slot = SLOT_MAX,
        .last_extended_slot = 100,
        .last_extended_slot_start_index = 0,
        .authority = authority,
    };

    // Build account data
    var data: [LOOKUP_TABLE_META_SIZE + 64]u8 = undefined;
    const meta_bytes = serializeMeta(meta);
    @memcpy(data[0..LOOKUP_TABLE_META_SIZE], &meta_bytes);
    @memcpy(data[LOOKUP_TABLE_META_SIZE..][0..32], &addr1.bytes);
    @memcpy(data[LOOKUP_TABLE_META_SIZE + 32 ..][0..32], &addr2.bytes);

    const table = try AddressLookupTable.deserialize(&data);

    try std.testing.expectEqual(@as(usize, 2), table.addresses.len);
    try std.testing.expect(table.addresses[0].equals(addr1));
    try std.testing.expect(table.addresses[1].equals(addr2));
    try std.testing.expect(table.isActive(200, null));
}

test "address_lookup_table: lookup by index" {
    const addr1 = PublicKey.from([_]u8{1} ** 32);
    const addr2 = PublicKey.from([_]u8{2} ** 32);

    const meta = LookupTableMeta{
        .deactivation_slot = SLOT_MAX,
        .last_extended_slot = 0,
        .last_extended_slot_start_index = 0,
        .authority = null,
    };

    var data: [LOOKUP_TABLE_META_SIZE + 64]u8 = undefined;
    const meta_bytes = serializeMeta(meta);
    @memcpy(data[0..LOOKUP_TABLE_META_SIZE], &meta_bytes);
    @memcpy(data[LOOKUP_TABLE_META_SIZE..][0..32], &addr1.bytes);
    @memcpy(data[LOOKUP_TABLE_META_SIZE + 32 ..][0..32], &addr2.bytes);

    const table = try AddressLookupTable.deserialize(&data);

    const lookup0 = try table.lookup(0);
    try std.testing.expect(lookup0.equals(addr1));

    const lookup1 = try table.lookup(1);
    try std.testing.expect(lookup1.equals(addr2));

    // Invalid index
    const result = table.lookup(5);
    try std.testing.expectError(AddressLookupError.InvalidLookupIndex, result);
}

test "address_lookup_table: derive lookup table address" {
    const authority = PublicKey.from([_]u8{1} ** 32);
    const recent_slot: u64 = 12345;

    const result = deriveLookupTableAddress(authority, recent_slot);

    // Just verify we get a valid result (actual address depends on PDA derivation)
    try std.testing.expect(result.bump_seed <= 255);
    // The address should not be the authority
    try std.testing.expect(!result.address.equals(authority));
}

test "address_lookup_table: getActiveAddressesLen" {
    const meta = LookupTableMeta{
        .deactivation_slot = SLOT_MAX,
        .last_extended_slot = 100,
        .last_extended_slot_start_index = 5,
        .authority = null,
    };

    // Create a minimal table with addresses
    const addresses = [_]PublicKey{
        PublicKey.default(),
        PublicKey.default(),
        PublicKey.default(),
        PublicKey.default(),
        PublicKey.default(),
        PublicKey.default(),
        PublicKey.default(),
        PublicKey.default(),
        PublicKey.default(),
        PublicKey.default(),
    };

    const table = AddressLookupTable{
        .meta = meta,
        .addresses = &addresses,
    };

    // Current slot > last_extended_slot: all addresses active
    try std.testing.expectEqual(@as(usize, 10), table.getActiveAddressesLen(200));

    // Current slot == last_extended_slot: only first 5 active
    try std.testing.expectEqual(@as(usize, 5), table.getActiveAddressesLen(100));
}

test "address_lookup_table: invalid data too short" {
    const short_data = [_]u8{0} ** 10;
    const result = AddressLookupTable.deserialize(&short_data);
    try std.testing.expectError(AddressLookupError.InvalidAccountData, result);
}

test "address_lookup_table: invalid data unaligned addresses" {
    var data: [LOOKUP_TABLE_META_SIZE + 10]u8 = undefined;
    const meta = LookupTableMeta{
        .deactivation_slot = SLOT_MAX,
        .last_extended_slot = 0,
        .last_extended_slot_start_index = 0,
        .authority = null,
    };
    const meta_bytes = serializeMeta(meta);
    @memcpy(data[0..LOOKUP_TABLE_META_SIZE], &meta_bytes);
    // 10 bytes is not divisible by 32

    const result = AddressLookupTable.deserialize(&data);
    try std.testing.expectError(AddressLookupError.InvalidAccountData, result);
}

test "address_lookup_table: invalid last_extended_slot_start_index exceeds addresses" {
    // Create metadata with last_extended_slot_start_index = 5 but only 2 addresses
    var data: [LOOKUP_TABLE_META_SIZE + 64]u8 = undefined;
    const meta = LookupTableMeta{
        .deactivation_slot = SLOT_MAX,
        .last_extended_slot = 100,
        .last_extended_slot_start_index = 5, // Invalid: exceeds num_addresses (2)
        .authority = null,
    };
    const meta_bytes = serializeMeta(meta);
    @memcpy(data[0..LOOKUP_TABLE_META_SIZE], &meta_bytes);
    // 64 bytes = 2 addresses
    @memset(data[LOOKUP_TABLE_META_SIZE..], 0);

    const result = AddressLookupTable.deserialize(&data);
    try std.testing.expectError(AddressLookupError.InvalidAccountData, result);
}

test "address_lookup_table: valid last_extended_slot_start_index equals addresses len" {
    // last_extended_slot_start_index == num_addresses is valid (all addresses added in last slot)
    var data: [LOOKUP_TABLE_META_SIZE + 64]u8 = undefined;
    const meta = LookupTableMeta{
        .deactivation_slot = SLOT_MAX,
        .last_extended_slot = 100,
        .last_extended_slot_start_index = 2, // Valid: equals num_addresses
        .authority = null,
    };
    const meta_bytes = serializeMeta(meta);
    @memcpy(data[0..LOOKUP_TABLE_META_SIZE], &meta_bytes);
    @memset(data[LOOKUP_TABLE_META_SIZE..], 0);

    const table = try AddressLookupTable.deserialize(&data);
    try std.testing.expectEqual(@as(usize, 2), table.addresses.len);
    try std.testing.expectEqual(@as(u8, 2), table.meta.last_extended_slot_start_index);
}

test "address_lookup_table: empty table with zero start index" {
    // Empty table (no addresses) with start_index = 0 is valid
    var data: [LOOKUP_TABLE_META_SIZE]u8 = undefined;
    const meta = LookupTableMeta{
        .deactivation_slot = SLOT_MAX,
        .last_extended_slot = 0,
        .last_extended_slot_start_index = 0,
        .authority = null,
    };
    const meta_bytes = serializeMeta(meta);
    @memcpy(data[0..LOOKUP_TABLE_META_SIZE], &meta_bytes);

    const table = try AddressLookupTable.deserialize(&data);
    try std.testing.expectEqual(@as(usize, 0), table.addresses.len);
}

test "address_lookup_table: empty table with non-zero start index is invalid" {
    // Empty table with start_index > 0 is invalid
    var data: [LOOKUP_TABLE_META_SIZE]u8 = undefined;
    const meta = LookupTableMeta{
        .deactivation_slot = SLOT_MAX,
        .last_extended_slot = 100,
        .last_extended_slot_start_index = 1, // Invalid: exceeds num_addresses (0)
        .authority = null,
    };
    const meta_bytes = serializeMeta(meta);
    @memcpy(data[0..LOOKUP_TABLE_META_SIZE], &meta_bytes);

    const result = AddressLookupTable.deserialize(&data);
    try std.testing.expectError(AddressLookupError.InvalidAccountData, result);
}
