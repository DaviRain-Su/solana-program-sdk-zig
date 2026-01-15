//! Counter Program using Type-Safe DSL
//!
//! This example demonstrates the typed DSL that provides both concise syntax
//! AND compile-time type safety for field references.
//!
//! Key features:
//! - `.payer` instead of `"payer"` - typos caught at compile time!
//! - `Accounts(.{...})` builder for clean syntax
//! - Full validation of field references

const std = @import("std");
const sol = @import("solana_program_sdk");
const anchor = @import("anchor");

// Import the type-safe DSL
const typed = anchor.typed;

// ============================================================================
// Program ID
// ============================================================================

pub const PROGRAM_ID = sol.PublicKey.comptimeFromBase58(
    "CounterTyped111111111111111111111111111111",
);

// ============================================================================
// Account Data Structures
// ============================================================================

/// Counter account data
pub const CounterData = struct {
    count: u64,
    authority: sol.PublicKey,
    bump: u8,

    pub const SIZE: usize = @sizeOf(CounterData);
};

// ============================================================================
// Instructions - Using Type-Safe DSL
// ============================================================================

/// Initialize instruction with type-safe field references.
///
/// Notice: `.payer = .payer` uses enum literal, not string!
/// If you typo `.payerr`, you get a compile error immediately.
pub const Initialize = typed.Instr(
    "initialize",
    // Accounts definition with type-safe references
    typed.Accounts(.{
        // Mutable signer who pays
        .payer = typed.SignerMut,

        // Initialize counter - .payer references the payer field above
        // If you write .payerr by mistake, compile error!
        .counter = typed.Init(CounterData, .{
            .payer = .payer, // Type-safe reference!
        }),

        // System program for CPI
        .system_program = typed.Prog(sol.system_program.ID),
    }),
    // Instruction arguments
    struct {
        initial_value: u64,
    },
);

/// Increment instruction
pub const Increment = typed.Instr(
    "increment",
    typed.Accounts(.{
        .authority = typed.Signer,
        .counter = typed.Data(CounterData, .{ .mut = true }),
    }),
    struct {
        amount: u64,
    },
);

/// Decrement instruction
pub const Decrement = typed.Instr(
    "decrement",
    typed.Accounts(.{
        .authority = typed.Signer,
        .counter = typed.Data(CounterData, .{ .mut = true }),
    }),
    struct {
        amount: u64,
    },
);

/// Close instruction with type-safe destination reference
pub const CloseCounter = typed.Instr(
    "close",
    typed.Accounts(.{
        .authority = typed.Signer,
        // .destination references the authority field - type-safe!
        .counter = typed.Close(CounterData, .{
            .destination = .authority, // Lamports go to authority
        }),
    }),
    void,
);

// ============================================================================
// Instruction Handlers - Pure Business Logic
// ============================================================================

/// Initialize handler
pub fn initialize(ctx: Initialize.Ctx, args: Initialize.Args) !void {
    sol.print("Initializing counter with value: {d}", .{args.initial_value});

    ctx.accounts.counter.data.count = args.initial_value;
    ctx.accounts.counter.data.authority = ctx.accounts.payer.key().*;

    sol.print("Counter initialized!", .{});
}

/// Increment handler
pub fn increment(ctx: Increment.Ctx, args: Increment.Args) !void {
    sol.print("Incrementing by {d}", .{args.amount});

    const counter = ctx.accounts.counter.data;
    ctx.accounts.counter.data.count = counter.count +| args.amount;

    sol.print("New value: {d}", .{ctx.accounts.counter.data.count});
}

/// Decrement handler
pub fn decrement(ctx: Decrement.Ctx, args: Decrement.Args) !void {
    sol.print("Decrementing by {d}", .{args.amount});

    const counter = ctx.accounts.counter.data;
    if (counter.count < args.amount) {
        return error.InsufficientFunds;
    }
    ctx.accounts.counter.data.count = counter.count - args.amount;

    sol.print("New value: {d}", .{ctx.accounts.counter.data.count});
}

/// Close handler
pub fn close(ctx: CloseCounter.Ctx) !void {
    sol.print("Closing counter", .{});
    _ = ctx;
    sol.print("Counter closed!", .{});
}

// ============================================================================
// Program Entry
// ============================================================================

const CounterProgram = struct {
    pub const id = PROGRAM_ID;

    pub const instructions = struct {
        pub const init = Initialize;
        pub const inc = Increment;
        pub const dec = Decrement;
        pub const cls = CloseCounter;
    };

    pub const init = initialize;
    pub const inc = increment;
    pub const dec = decrement;
    pub const cls = close;
};

fn processInstruction(
    program_id: *sol.PublicKey,
    accounts: []sol.Account,
    data: []const u8,
) sol.ProgramResult {
    sol.print("Counter Typed program invoked", .{});

    const Entry = anchor.ProgramEntry(CounterProgram);
    return Entry.processInstruction(
        program_id,
        accountsToInfoSlice(accounts),
        data,
        .{},
    );
}

fn accountsToInfoSlice(accounts: []sol.Account) []const sol.account.Account.Info {
    var infos: [32]sol.account.Account.Info = undefined;
    const count = @min(accounts.len, 32);
    for (accounts[0..count], 0..) |*acc, i| {
        infos[i] = acc.info().*;
    }
    return infos[0..count];
}

comptime {
    sol.entrypoint(&processInstruction);
}

// ============================================================================
// Comparison: String vs Type-Safe References
// ============================================================================
//
// STRING-BASED (simple DSL):
// ```zig
// counter: simple.Init(CounterData, .{ .payer = "payer" }),
// //                                           ^^^^^^^ string - typo not caught!
// ```
//
// TYPE-SAFE (typed DSL):
// ```zig
// .counter = typed.Init(CounterData, .{ .payer = .payer }),
// //                                            ^^^^^^ enum literal - typo = compile error!
// ```
//
// Benefits of typed DSL:
// 1. Typos caught at compile time (`.payerr` = error)
// 2. IDE autocomplete works with enum literals
// 3. Refactoring-friendly (rename field = update all refs)
// 4. Still concise syntax
