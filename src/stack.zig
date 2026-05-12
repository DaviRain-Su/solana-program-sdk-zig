//! Call-stack & processed-sibling-instruction syscalls.
//!
//! These are companion APIs to the instructions sysvar and CPI:
//!
//! - **`getStackHeight()`** — depth of the current invoke chain.
//!   Top-level (transaction-message) instructions are
//!   `TRANSACTION_LEVEL_STACK_HEIGHT` (`= 1`); the first CPI inside one is
//!   `2`, and so on. Useful to assert "this entrypoint must run as a
//!   top-level instruction" or "must be invoked via CPI from program X".
//!
//! - **`getProcessedSiblingInstruction(index)`** — walks the
//!   reverse-ordered list of *already processed* sibling instructions of
//!   the parent invocation.
//!
//!   ```text
//!   A
//!   B → C → D
//!   B → E
//!   B → F
//!   ```
//!
//!   Then `B`'s processed-sibling list is `[A]`, and `F`'s is `[E, C]`.
//!
//!   The Solana ABI is a two-call protocol:
//!     1. Call with `data_ptr` / `accounts_ptr` pointing to scratch (we
//!        pass `null`-ish single-byte stubs since the runtime ignores
//!        them on the discovery call). The returned struct populates
//!        `data_len` and `accounts_len` so the caller can size its
//!        buffers.
//!     2. Allocate buffers of those sizes and call again — the runtime
//!        copies in the data and account-meta array.
//!
//!   Because the second-call buffers must be writable on the BPF stack
//!   or heap, this SDK provides three flavours:
//!
//!     - `siblingMeta(index)` → just `(data_len, accounts_len, program_id)`,
//!        cheap probe for "is there an Nth sibling?".
//!     - `getProcessedSiblingInstruction(index, data_buf, accts_buf)` →
//!        you provide pre-sized buffers (typically allocated with
//!        `BumpAllocator` / fixed scratch).
//!     - `getProcessedSiblingInstructionAlloc(index, allocator)` →
//!        runs the two-call protocol against the supplied allocator.

const std = @import("std");
const builtin = @import("builtin");
const pubkey = @import("pubkey.zig");
const cpi = @import("cpi.zig");

const Pubkey = pubkey.Pubkey;

/// Stack height assigned to instructions that appear in the transaction
/// message itself (i.e. not invoked via CPI). Higher values mean deeper
/// nesting.
pub const TRANSACTION_LEVEL_STACK_HEIGHT: u64 = 1;

/// FFI shape that the `sol_get_processed_sibling_instruction` syscall
/// reads/writes. `#[repr(C)]` in Rust → identical layout in `extern struct`.
pub const ProcessedSiblingMeta = extern struct {
    /// Length of the instruction data buffer the caller must provide on
    /// the second syscall invocation.
    data_len: u64,
    /// Number of `AccountMeta` entries the caller must provide on the
    /// second syscall invocation.
    accounts_len: u64,
};

/// Owned account meta, identical layout to `cpi.AccountMeta` so the
/// runtime can write directly into a `[]AccountMeta` array.
pub const AccountMeta = cpi.AccountMeta;

const is_solana = builtin.os.tag == .freestanding and builtin.cpu.arch == .bpfel;

extern fn sol_get_stack_height() callconv(.c) u64;

extern fn sol_get_processed_sibling_instruction(
    index: u64,
    meta: *ProcessedSiblingMeta,
    program_id: *Pubkey,
    data: [*]u8,
    accounts: [*]AccountMeta,
) callconv(.c) u64;

/// Returns the current invocation's stack height.
///
/// On non-Solana hosts always returns `0` (matches the upstream stub).
pub inline fn getStackHeight() u64 {
    if (comptime !is_solana) return 0;
    return sol_get_stack_height();
}

/// Probe a sibling instruction without copying its data/accounts.
///
/// Returns:
///   - `meta.data_len`, `meta.accounts_len` — required buffer sizes.
///   - `program_id` — pubkey of the sibling's program.
///   - `null` if no sibling exists at `index`.
///
/// Intended for "do I have N siblings?" or "is the previous sibling
/// program X?" checks where the data/accounts aren't actually needed.
pub fn siblingMeta(index: u64) ?struct {
    meta: ProcessedSiblingMeta,
    program_id: Pubkey,
} {
    if (comptime !is_solana) return null;

    var meta: ProcessedSiblingMeta = .{ .data_len = 0, .accounts_len = 0 };
    var pid: Pubkey = @splat(0);
    // Single-byte stubs — runtime ignores them on the discovery call,
    // but the syscall ABI doesn't accept null pointers, so we hand it
    // a real address.
    var data_stub: [1]u8 = .{0};
    var accts_stub: [1]AccountMeta = undefined;

    const present = sol_get_processed_sibling_instruction(
        index,
        &meta,
        &pid,
        &data_stub,
        &accts_stub,
    );
    if (present != 1) return null;
    return .{ .meta = meta, .program_id = pid };
}

/// Sibling instruction view backed by caller-provided buffers.
pub const ProcessedSibling = struct {
    program_id: Pubkey,
    /// Filled-in instruction data (subset of caller's buffer if
    /// `data_buf.len > meta.data_len`).
    data: []u8,
    /// Filled-in account metas (subset of caller's slice).
    accounts: []AccountMeta,
};

/// Two-call protocol with caller-provided scratch buffers.
///
/// Pass buffers at least `meta.data_len` / `meta.accounts_len` long
/// (use `siblingMeta(index)` first to learn the sizes). Returns `null`
/// if no sibling exists at `index`.
pub fn getProcessedSiblingInstruction(
    index: u64,
    data_buf: []u8,
    accounts_buf: []AccountMeta,
) ?ProcessedSibling {
    if (comptime !is_solana) return null;

    var meta: ProcessedSiblingMeta = .{
        .data_len = data_buf.len,
        .accounts_len = accounts_buf.len,
    };
    var pid: Pubkey = @splat(0);

    const present = sol_get_processed_sibling_instruction(
        index,
        &meta,
        &pid,
        data_buf.ptr,
        accounts_buf.ptr,
    );
    if (present != 1) return null;
    return .{
        .program_id = pid,
        .data = data_buf[0..@intCast(meta.data_len)],
        .accounts = accounts_buf[0..@intCast(meta.accounts_len)],
    };
}

/// Convenience: probe → allocate → fetch. Useful when the sibling sizes
/// aren't known at compile time.
pub fn getProcessedSiblingInstructionAlloc(
    index: u64,
    allocator: std.mem.Allocator,
) !?ProcessedSibling {
    const probe = siblingMeta(index) orelse return null;
    const data_buf = try allocator.alloc(u8, @intCast(probe.meta.data_len));
    errdefer allocator.free(data_buf);
    const accts_buf = try allocator.alloc(
        AccountMeta,
        @intCast(probe.meta.accounts_len),
    );
    errdefer allocator.free(accts_buf);
    return getProcessedSiblingInstruction(index, data_buf, accts_buf);
}

// =============================================================================
// Tests (host-only — syscalls are no-ops off-chain)
// =============================================================================

const testing = std.testing;

test "getStackHeight: host stub returns 0" {
    try testing.expectEqual(@as(u64, 0), getStackHeight());
}

test "siblingMeta: host stub returns null" {
    try testing.expectEqual(@as(?@TypeOf(siblingMeta(0).?), null), siblingMeta(0));
}

test "TRANSACTION_LEVEL_STACK_HEIGHT constant" {
    try testing.expectEqual(@as(u64, 1), TRANSACTION_LEVEL_STACK_HEIGHT);
}

test "ProcessedSiblingMeta layout: 16 bytes, repr(C) compatible" {
    try testing.expectEqual(@as(usize, 16), @sizeOf(ProcessedSiblingMeta));
    try testing.expectEqual(@as(usize, 0), @offsetOf(ProcessedSiblingMeta, "data_len"));
    try testing.expectEqual(@as(usize, 8), @offsetOf(ProcessedSiblingMeta, "accounts_len"));
}
