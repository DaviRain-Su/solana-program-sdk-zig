//! Compute-budget introspection — `sol_remaining_compute_units` wrapper.
//!
//! On-chain programs are billed per BPF instruction (a few CU per op,
//! plus larger fixed costs for syscalls). `sol_remaining_compute_units`
//! lets a program query — without consuming any meaningful budget
//! itself — how many CU are left in the current transaction. Useful
//! for:
//!
//!   - Bailing out of a long loop before the runtime hard-aborts.
//!   - Choosing between a fast / slow path based on remaining budget.
//!   - Defensive logging in profilers / batch processors.
//!
//! The Rust SDK exposes this under `solana_program::compute_budget`,
//! so we mirror the namespace here for parity.

const std = @import("std");
const builtin = @import("builtin");

const is_solana = builtin.os.tag == .freestanding and builtin.cpu.arch == .bpfel;

extern fn sol_remaining_compute_units() callconv(.c) u64;

/// Remaining compute units in the current transaction.
///
/// On host, returns `std.math.maxInt(u64)` so test code can treat
/// "plenty of budget" as the default. On-chain, calls the syscall
/// directly — the syscall itself costs a fixed number of CU per the
/// runtime's pricing table (currently 1 CU).
pub fn remaining() u64 {
    if (is_solana) {
        return sol_remaining_compute_units();
    } else {
        return std.math.maxInt(u64);
    }
}

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

test "compute_budget: host returns sentinel" {
    try testing.expectEqual(@as(u64, std.math.maxInt(u64)), remaining());
}
