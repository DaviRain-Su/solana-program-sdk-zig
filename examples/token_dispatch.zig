//! Token-like program — demonstrates comptime instruction dispatch.
//!
//! Foundation for an Anchor-style framework:
//! - Define instructions as an enum
//! - Define per-instruction data structs (comptime typed deserialization)
//! - No manual pointer casting, no manual discriminant matching
//!
//! Account layout: every instruction takes the same two slots so the
//! dispatcher can parse them once before reading the ix data. Burn /
//! mint only use the first slot; the second is ignored.
//!
//! Instruction layout:
//!   [0..4]  u32 discriminant (Transfer=0, Burn=1, Mint=2)
//!   [4..12] u64 amount

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

// =========================================================================
// 1. Define your instruction set
// =========================================================================

const Tag = enum(u32) {
    transfer,
    burn,
    mint,
};

// =========================================================================
// 2. Define per-instruction data structs (kept for documentation /
//    future framework codegen — the dispatcher reads `data[4..]`
//    directly as a u64).
// =========================================================================

const TransferData = packed struct {
    amount: u64,
};

const BurnData = packed struct {
    amount: u64,
};

const MintData = packed struct {
    amount: u64,
};

// =========================================================================
// 3. Entrypoint — parse-then-dispatch.
//
// We cannot read ix data BEFORE consuming accounts: `instructionData`
// requires `remaining == 0`, and `instructionDataUnchecked` would read
// `data_len` from the account-zero serialization (garbage). Pinocchio
// programs solve this by parsing all accounts up front.
//
// SBF linker doesn't support jump-table relocations, so we use comptime
// `if` chains instead of `switch`. Each branch is fully inlined and the
// non-taken branches optimize away.
// =========================================================================

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    // Parse both account slots up front. We always advertise two
    // accounts; burn/mint just ignore the second.
    const accs = try ctx.parseAccounts(.{ "first", "second" });
    const data = try ctx.instructionData();
    if (data.len < 12) return error.InvalidInstructionData;

    // Read discriminant — single u32 load
    const raw_tag: u32 = @as(*align(1) const u32, @ptrCast(data[0..4])).*;
    const tag: Tag = @enumFromInt(raw_tag);

    // Read amount — single u64 load
    const amount: u64 = @as(*align(1) const u64, @ptrCast(data[4..12])).*;

    // For benchmarking we model burn/mint as paired lamport moves
    // (first ↔ second) so the runtime's lamport-sum check passes.
    // Real SPL token burn/mint would CPI to spl_token and update
    // supply / balance state instead.
    if (tag == .transfer) {
        accs.first.subLamports(amount);
        accs.second.addLamports(amount);
        return;
    }
    if (tag == .burn) {
        accs.first.subLamports(amount);
        accs.second.addLamports(amount);
        return;
    }
    if (tag == .mint) {
        accs.second.subLamports(amount);
        accs.first.addLamports(amount);
        return;
    }
    return error.InvalidInstructionData;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
