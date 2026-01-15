//! Counter Program using Simplified DSL
//!
//! This example demonstrates the simplified DSL that reduces boilerplate
//! while maintaining full type safety via Zig's comptime.
//!
//! Compare this with the original counter example to see the difference.

const std = @import("std");
const sol = @import("solana_program_sdk");
const anchor = @import("anchor");
const simple = anchor.simple;

// ============================================================================
// Program ID
// ============================================================================

pub const PROGRAM_ID = sol.PublicKey.comptimeFromBase58(
    "CounterSimp1e11111111111111111111111111111",
);

// ============================================================================
// Account Data Structures
// ============================================================================

/// Counter account data (discriminator auto-derived from type name)
pub const CounterData = struct {
    /// Current counter value
    count: u64,
    /// Authority who can modify the counter
    authority: sol.PublicKey,
    /// Bump seed for PDA (if applicable)
    bump: u8,

    pub const SIZE: usize = @sizeOf(CounterData);
};

// ============================================================================
// Instructions - Using Simplified DSL
// ============================================================================

/// Initialize a new counter account.
///
/// Accounts:
/// - payer: Signer who pays for account creation
/// - counter: New counter account to initialize
/// - system_program: System program for CPI
pub const Initialize = simple.Instruction("initialize", struct {
    /// Signer who pays for account creation
    payer: simple.Signer(.mut),

    /// Counter account to initialize (auto: mut + init + zero)
    counter: simple.Init(CounterData, .{
        .payer = "payer",
    }),

    /// System program for CPI
    system_program: simple.Program(sol.system_program.ID),
}, struct {
    /// Initial counter value
    initial_value: u64,
});

/// Increment the counter by a specified amount.
///
/// Accounts:
/// - authority: Signer who owns the counter
/// - counter: Counter account to increment
pub const Increment = simple.Instruction("increment", struct {
    /// Authority who owns the counter
    authority: simple.Signer(.{}),

    /// Counter account (mutable, with constraint)
    counter: simple.Data(CounterData, .{
        .mut = true,
        .owner = PROGRAM_ID,
        // Constraint: counter.authority must match authority account
        .constraint = "counter.authority == authority",
    }),
}, struct {
    /// Amount to increment
    amount: u64,
});

/// Decrement the counter by a specified amount.
pub const Decrement = simple.Instruction("decrement", struct {
    authority: simple.Signer(.{}),
    counter: simple.Data(CounterData, .{
        .mut = true,
        .owner = PROGRAM_ID,
        .constraint = "counter.authority == authority",
    }),
}, struct {
    amount: u64,
});

/// Close the counter account and reclaim lamports.
pub const CloseCounter = simple.Instruction("close", struct {
    authority: simple.Signer(.{}),
    counter: simple.Close(CounterData, .{
        .destination = "authority",
    }),
}, void);

// ============================================================================
// Instruction Handlers - Pure Business Logic!
// ============================================================================

/// Initialize handler - just business logic, no boilerplate validation
pub fn initialize(ctx: Initialize.Context, args: Initialize.Args) !void {
    sol.print("Initializing counter with value: {d}", .{args.initial_value});

    // All validation already done by the DSL:
    // - payer is signer and writable
    // - counter account is created and zeroed
    // - system_program is correct

    ctx.accounts.counter.data.count = args.initial_value;
    ctx.accounts.counter.data.authority = ctx.accounts.payer.key().*;

    sol.print("Counter initialized successfully", .{});
}

/// Increment handler
pub fn increment(ctx: Increment.Context, args: Increment.Args) !void {
    sol.print("Incrementing counter by {d}", .{args.amount});

    // Constraint already validated: counter.authority == authority

    const counter = ctx.accounts.counter.data;
    const new_value = counter.count +| args.amount; // saturating add

    if (new_value == counter.count and args.amount > 0) {
        return error.ArithmeticOverflow;
    }

    ctx.accounts.counter.data.count = new_value;
    sol.print("Counter: {d}", .{new_value});
}

/// Decrement handler
pub fn decrement(ctx: Decrement.Context, args: Decrement.Args) !void {
    sol.print("Decrementing counter by {d}", .{args.amount});

    const counter = ctx.accounts.counter.data;

    if (counter.count < args.amount) {
        return error.InsufficientFunds;
    }

    ctx.accounts.counter.data.count = counter.count - args.amount;
    sol.print("Counter: {d}", .{ctx.accounts.counter.data.count});
}

/// Close handler
pub fn close(ctx: CloseCounter.Context) !void {
    sol.print("Closing counter account", .{});
    _ = ctx;
    // Close is automatically handled by the Close account type
    // Lamports transferred to authority
    sol.print("Counter closed", .{});
}

// ============================================================================
// Program Entry Point
// ============================================================================

/// Program definition using typed dispatcher.
const CounterProgram = struct {
    pub const id = PROGRAM_ID;

    pub const instructions = struct {
        pub const init = Initialize;
        pub const inc = Increment;
        pub const dec = Decrement;
        pub const cls = CloseCounter;
    };

    // Handlers
    pub const init = initialize;
    pub const inc = increment;
    pub const dec = decrement;
    pub const cls = close;
};

/// Process instruction entry point.
fn processInstruction(
    program_id: *sol.PublicKey,
    accounts: []sol.Account,
    data: []const u8,
) sol.ProgramResult {
    sol.print("Counter Simple program invoked", .{});

    // Use the typed program dispatcher
    const Entry = anchor.ProgramEntry(CounterProgram);
    return Entry.processInstruction(
        program_id,
        accountsToInfoSlice(accounts),
        data,
        .{},
    );
}

fn accountsToInfoSlice(accounts: []sol.Account) []const sol.account.Account.Info {
    // This is a workaround - in real code you'd have direct access to AccountInfo
    var infos: [32]sol.account.Account.Info = undefined;
    const count = @min(accounts.len, 32);
    for (accounts[0..count], 0..) |*acc, i| {
        infos[i] = acc.info().*;
    }
    return infos[0..count];
}

// Declare the program entrypoint
comptime {
    sol.entrypoint(&processInstruction);
}

// ============================================================================
// Comparison: Old vs New Style
// ============================================================================
//
// OLD STYLE (verbose):
// ```zig
// const Counter = anchor.Account(CounterData, .{
//     .discriminator = anchor.accountDiscriminator("CounterData"),
//     .mut = true,
//     .owner = PROGRAM_ID,
// });
//
// const IncrementAccounts = struct {
//     authority: anchor.Signer,
//     counter: Counter,
// };
//
// const IncrementInstruction = struct {
//     pub const Accounts = IncrementAccounts;
//     pub const Args = struct { amount: u64 };
// };
// ```
//
// NEW STYLE (concise):
// ```zig
// const Increment = simple.Instruction("increment", struct {
//     authority: simple.Signer(.{}),
//     counter: simple.Data(CounterData, .{ .mut = true, .owner = PROGRAM_ID }),
// }, struct {
//     amount: u64,
// });
// ```
//
// Benefits:
// 1. Discriminator auto-derived from type name
// 2. All instruction components in one place
// 3. Inline constraints at field level
// 4. Less type definitions needed
// 5. Context type auto-generated
