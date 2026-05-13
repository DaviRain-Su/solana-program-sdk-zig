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
    // Parse both account slots up front. We use the `Unchecked` variant
    // because this program's two-account layout is structurally unique
    // (transfer/burn/mint each move lamports between two distinct
    // roles, and the runtime catches lamport-sum violations anyway).
    // The unchecked variant skips the dup-aware tagged-union switch
    // and saves ~70 CU on this path vs the safe `parseAccounts`.
    const accs = try ctx.parseAccountsUnchecked(.{ "first", "second" });

    // For fixed-layout dispatchers, one explicit min-length check lets
    // us keep the hot-path reads as raw unaligned loads.
    try ctx.requireIxDataLen(12);

    const tag = ctx.readIxTag(Tag);
    const amount = ctx.readIx(u64, 4);

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
