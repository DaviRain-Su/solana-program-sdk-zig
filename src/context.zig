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
    pub fn load(input: [*]u8) !Context {
        // In BPF mode, use heap allocator; in test mode, use stack
        if (bpf.is_bpf_program) {
            return loadWithAllocator(input, heap_allocator);
        } else {
            // For tests, use a static buffer to avoid needing allocator
            return loadStatic(input);
        }
    }

    /// Load context using a specific allocator (for BPF heap allocation)
    pub fn loadWithAllocator(input: [*]u8, alloc: std.mem.Allocator) !Context {
        var ptr: [*]u8 = input;

        // Get the number of accounts
        const num_accounts: *u64 = @ptrCast(@alignCast(ptr));
        if (num_accounts.* > MAX_ACCOUNTS) {
            return error.MaxAccountsExceeded;
        }
        ptr += @sizeOf(u64);

        // Allocate accounts array on heap
        // This uses only ~16 bytes on stack (slice metadata) instead of ~3KB
        const accounts = try alloc.alloc(Account, num_accounts.*);

        // Parse accounts - zero-copy, just stores pointers to input buffer
        var i: usize = 0;
        while (i < num_accounts.*) : (i += 1) {
            const data: *Account.Data = @ptrCast(@alignCast(ptr));
            if (data.duplicate_index != std.math.maxInt(u8)) {
                // Duplicate account - just copy the pointer (cheap)
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
    fn loadStatic(input: [*]u8) !Context {
        const Static = struct {
            var accounts_buffer: [MAX_ACCOUNTS]Account = undefined;
        };

        var ptr: [*]u8 = input;

        // Get the number of accounts
        const num_accounts: *u64 = @ptrCast(@alignCast(ptr));
        if (num_accounts.* > MAX_ACCOUNTS) {
            return error.MaxAccountsExceeded;
        }
        ptr += @sizeOf(u64);

        // Parse accounts into static buffer
        var i: usize = 0;
        while (i < num_accounts.*) : (i += 1) {
            const data: *Account.Data = @ptrCast(@alignCast(ptr));
            if (data.duplicate_index != std.math.maxInt(u8)) {
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
