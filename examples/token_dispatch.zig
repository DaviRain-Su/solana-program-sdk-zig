//! Token-like program — demonstrates comptime instruction dispatch.
//!
//! Foundation for an Anchor-style framework:
//! - Define instructions as an enum
//! - Define per-instruction data structs (comptime typed deserialization)
//! - No manual pointer casting, no manual discriminant matching
//!
//! Instruction layout:
//!   [0..4]  u32 discriminant (Transfer=0, Burn=1, Mint=2)
//!   [4..]   instruction-specific data

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
// 2. Define per-instruction data structs
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
// 3. Entrypoint — comptime typed deserialization, explicit dispatch
//    SBF linker doesn't support jump-table relocations, so we use
//    comptime `if` chains instead of `switch`.
// =========================================================================

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    // Length-check via the unchecked variant; we haven't decremented
    // the account counter (we use `nextAccountUnchecked` in branches
    // below), so the safe `instructionData()` would refuse.
    const ix_data = ctx.instructionDataUnchecked();
    if (ix_data.len < 4) return error.InvalidInstructionData;

    // Read discriminant — compiles to a single u32 load
    const tag = ctx.readIxTag(Tag);

    // Comptime dispatch — each branch has typed accounts + typed data
    if (tag == .transfer) {
        const source = ctx.nextAccountUnchecked();
        const destination = ctx.nextAccountUnchecked();
        const data = ctx.readIx(TransferData, 4);
        source.subLamports(data.amount);
        destination.addLamports(data.amount);
        return;
    }

    if (tag == .burn) {
        const account = ctx.nextAccountUnchecked();
        const data = ctx.readIx(BurnData, 4);
        account.subLamports(data.amount);
        return;
    }

    if (tag == .mint) {
        const account = ctx.nextAccountUnchecked();
        const data = ctx.readIx(MintData, 4);
        account.addLamports(data.amount);
        return;
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
