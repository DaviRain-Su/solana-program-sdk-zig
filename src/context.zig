//! Zig implementation of Solana SDK's entrypoint input deserialization
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/program-entrypoint/src/lib.rs
//!
//! This module provides the Context type which parses the raw input buffer
//! passed to BPF programs by the Solana runtime. The input format is defined
//! by the Solana BPF loader specification.
//!
//! ## Memory Optimization
//!
//! This implementation uses heap allocation for the accounts array to avoid
//! stack overflow. Solana BPF programs have only 4KB of stack space, and a
//! 64-account array would consume ~75% of it. By using the 32KB heap instead,
//! we leave the stack available for function calls and local variables.
//!
//! This approach is similar to `solana-nostd-entrypoint` in Rust, which also
//! avoids stack allocation for account arrays.

const std = @import("std");

const Account = @import("account.zig").Account;
const ACCOUNT_DATA_PADDING = @import("account.zig").ACCOUNT_DATA_PADDING;
const heap_allocator = @import("allocator.zig").allocator;
const PublicKey = @import("public_key.zig").PublicKey;
const bpf = @import("bpf.zig");

/// Maximum number of accounts supported in a single transaction
/// This matches the Solana runtime limit
pub const MAX_ACCOUNTS: usize = 64;

/// Errors that can occur during context loading
pub const ContextError = error{
    /// Number of accounts exceeds MAX_ACCOUNTS limit
    MaxAccountsExceeded,
    /// Duplicate account index references an account that hasn't been parsed yet
    InvalidDuplicateIndex,
    /// Allocator failed to allocate memory
    OutOfMemory,
};

/// Program execution context parsed from BPF entrypoint input
///
/// The accounts are stored as a slice pointing to heap-allocated memory,
/// avoiding stack overflow in the limited 4KB BPF stack space.
///
/// Rust equivalent: Deserialized from `entrypoint` input buffer
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/program-entrypoint/src/lib.rs
pub const Context = struct {
    /// Number of accounts passed to the program
    num_accounts: u64,
    /// Slice of parsed accounts (heap-allocated in BPF, stack in tests)
    accounts: []Account,
    /// Instruction data passed to the program
    data: []const u8,
    /// The program ID of the currently executing program
    program_id: *align(1) PublicKey,

    /// Load and parse the entrypoint input buffer
    ///
    /// In BPF mode: Allocates accounts array on the 32KB heap
    /// In test mode: Uses a provided allocator or stack buffer
    ///
    /// This is a zero-copy operation for account data - the Account structs
    /// contain pointers directly into the input buffer.
    ///
    /// Returns ContextError on invalid input (e.g., too many accounts, invalid duplicate index)
    pub fn load(input: [*]u8) ContextError!Context {
        // In BPF mode, use heap allocator; in test mode, use stack
        if (bpf.is_bpf_program) {
            return loadWithAllocator(input, heap_allocator);
        } else {
            // For tests, use a static buffer to avoid needing allocator
            return loadStatic(input);
        }
    }

    /// Load context using a specific allocator (for BPF heap allocation)
    ///
    /// Note: This function trusts that the input buffer was serialized by the Solana runtime.
    /// Using with buffers serialized otherwise is unsupported. However, we do perform
    /// defensive checks for duplicate_index to prevent accessing uninitialized memory.
    ///
    /// Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/program-entrypoint/src/lib.rs
    pub fn loadWithAllocator(input: [*]u8, alloc: std.mem.Allocator) ContextError!Context {
        var ptr: [*]u8 = input;

        // Get the number of accounts
        const num_accounts: *u64 = @ptrCast(@alignCast(ptr));
        if (num_accounts.* > MAX_ACCOUNTS) {
            return ContextError.MaxAccountsExceeded;
        }
        ptr += @sizeOf(u64);

        // Allocate accounts array on heap
        // This uses only ~16 bytes on stack (slice metadata) instead of ~3KB
        const accounts = alloc.alloc(Account, num_accounts.*) catch return ContextError.OutOfMemory;

        // Parse accounts - zero-copy, just stores pointers to input buffer
        var i: usize = 0;
        while (i < num_accounts.*) : (i += 1) {
            const data: *Account.Data = @ptrCast(@alignCast(ptr));
            if (data.duplicate_index != std.math.maxInt(u8)) {
                // Duplicate account - validate index before accessing
                // Rust equivalent check: dup_info < i (implicit via Vec bounds)
                if (data.duplicate_index >= i) {
                    // Free allocated memory before returning error
                    alloc.free(accounts);
                    return ContextError.InvalidDuplicateIndex;
                }
                ptr += @sizeOf(u64);
                accounts[i] = accounts[data.duplicate_index];
            } else {
                // New account - store pointer to data in input buffer
                accounts[i] = Account.fromDataPtr(data);
                ptr += Account.DATA_HEADER + data.data_len + ACCOUNT_DATA_PADDING + @sizeOf(u64);
                ptr = @ptrFromInt(std.mem.alignForward(u64, @intFromPtr(ptr), @alignOf(u64)));
            }
        }

        // Parse instruction data
        const data_len: *u64 = @ptrCast(@alignCast(ptr));
        ptr += @sizeOf(u64);
        const data = ptr[0..data_len.*];
        ptr += data_len.*;

        // Parse program ID
        const program_id = @as(*align(1) PublicKey, @ptrCast(ptr));

        return Context{
            .num_accounts = num_accounts.*,
            .accounts = accounts,
            .data = data,
            .program_id = program_id,
        };
    }

    /// Load context using stack allocation (for tests only)
    ///
    /// WARNING: This uses ~3KB of stack space. Only use in test environments
    /// where stack space is not as constrained as in BPF.
    fn loadStatic(input: [*]u8) ContextError!Context {
        const Static = struct {
            var accounts_buffer: [MAX_ACCOUNTS]Account = undefined;
        };

        var ptr: [*]u8 = input;

        // Get the number of accounts
        const num_accounts: *u64 = @ptrCast(@alignCast(ptr));
        if (num_accounts.* > MAX_ACCOUNTS) {
            return ContextError.MaxAccountsExceeded;
        }
        ptr += @sizeOf(u64);

        // Parse accounts into static buffer
        var i: usize = 0;
        while (i < num_accounts.*) : (i += 1) {
            const data: *Account.Data = @ptrCast(@alignCast(ptr));
            if (data.duplicate_index != std.math.maxInt(u8)) {
                // Validate duplicate index before accessing
                if (data.duplicate_index >= i) {
                    return ContextError.InvalidDuplicateIndex;
                }
                ptr += @sizeOf(u64);
                Static.accounts_buffer[i] = Static.accounts_buffer[data.duplicate_index];
            } else {
                Static.accounts_buffer[i] = Account.fromDataPtr(data);
                ptr += Account.DATA_HEADER + data.data_len + ACCOUNT_DATA_PADDING + @sizeOf(u64);
                ptr = @ptrFromInt(std.mem.alignForward(u64, @intFromPtr(ptr), @alignOf(u64)));
            }
        }

        // Parse instruction data
        const data_len: *u64 = @ptrCast(@alignCast(ptr));
        ptr += @sizeOf(u64);
        const data = ptr[0..data_len.*];
        ptr += data_len.*;

        // Parse program ID
        const program_id = @as(*align(1) PublicKey, @ptrCast(ptr));

        return Context{
            .num_accounts = num_accounts.*,
            .accounts = Static.accounts_buffer[0..num_accounts.*],
            .data = data,
            .program_id = program_id,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "context: MAX_ACCOUNTS constant" {
    try std.testing.expectEqual(@as(usize, 64), MAX_ACCOUNTS);
}

test "context: Account size for stack calculation" {
    // Document the size for stack overflow prevention
    // Account is just a pointer wrapper, so it's small
    const account_size = @sizeOf(Account);
    try std.testing.expect(account_size <= 16); // Should be pointer-sized

    // Stack usage calculation:
    // MAX_ACCOUNTS * account_size = 64 * 8 = 512 bytes (if pointer)
    // This is manageable, but we still use heap for safety margin
}

test "context: ContextError types" {
    // Verify error types exist and are distinct
    const e1: ContextError = ContextError.MaxAccountsExceeded;
    const e2: ContextError = ContextError.InvalidDuplicateIndex;
    const e3: ContextError = ContextError.OutOfMemory;

    try std.testing.expect(e1 != e2);
    try std.testing.expect(e2 != e3);
    try std.testing.expect(e1 != e3);
}

test "context: MaxAccountsExceeded error" {
    // Create a buffer with num_accounts > MAX_ACCOUNTS
    var buffer: [8]u8 align(8) = undefined;
    const num_accounts: *u64 = @ptrCast(&buffer);
    num_accounts.* = MAX_ACCOUNTS + 1;

    const result = Context.load(@ptrCast(&buffer));
    try std.testing.expectError(ContextError.MaxAccountsExceeded, result);
}

test "context: InvalidDuplicateIndex error - index equals current" {
    // Create a minimal buffer where duplicate_index == i (invalid: must be < i)
    // Layout: num_accounts (u64) + account data
    var buffer: [256]u8 align(8) = std.mem.zeroes([256]u8);

    // Set num_accounts = 1
    const num_accounts: *u64 = @ptrCast(&buffer);
    num_accounts.* = 1;

    // Set duplicate_index = 0 (invalid because i=0, and 0 >= 0)
    // Account.Data starts at offset 8
    buffer[8] = 0; // duplicate_index = 0 (not 0xFF which means non-duplicate)

    const result = Context.load(@ptrCast(&buffer));
    try std.testing.expectError(ContextError.InvalidDuplicateIndex, result);
}

test "context: InvalidDuplicateIndex error - forward reference" {
    // Create buffer where first account claims to be duplicate of index 5 (which doesn't exist yet)
    var buffer: [256]u8 align(8) = std.mem.zeroes([256]u8);

    // Set num_accounts = 1
    const num_accounts: *u64 = @ptrCast(&buffer);
    num_accounts.* = 1;

    // Set duplicate_index = 5 (invalid because only 0 accounts have been parsed so far)
    // Account.Data starts at offset 8
    buffer[8] = 5; // duplicate_index = 5 (forward reference - invalid)

    const result = Context.load(@ptrCast(&buffer));
    try std.testing.expectError(ContextError.InvalidDuplicateIndex, result);
}
