//! Counter - Solana On-Chain Program Example
//!
//! This program demonstrates:
//! - Account data storage and modification
//! - Instruction discriminator pattern
//! - Account ownership validation
//!
//! Instructions:
//! - [0]: Initialize counter to 0
//! - [1]: Increment counter by 1
//! - [2]: Decrement counter by 1

const std = @import("std");
const sol = @import("solana_program_sdk");

/// Counter account data structure (8 bytes)
pub const Counter = extern struct {
    value: u64,

    pub const SIZE: usize = @sizeOf(Counter);

    pub fn fromBytes(data: []u8) ?*Counter {
        if (data.len < SIZE) return null;
        return @ptrCast(@alignCast(data.ptr));
    }
};

/// Instruction discriminators
pub const Instruction = enum(u8) {
    Initialize = 0,
    Increment = 1,
    Decrement = 2,
};

/// Helper to create error result
fn err(e: sol.ProgramError) sol.ProgramResult {
    return .{ .err = e };
}

/// Process a Counter instruction.
fn processInstruction(
    program_id: *sol.PublicKey,
    accounts: []sol.Account,
    data: []const u8,
) sol.ProgramResult {
    sol.print("Counter program invoked", .{});

    // Parse instruction discriminator
    if (data.len < 1) {
        sol.print("Error: No instruction data", .{});
        return err(.InvalidInstructionData);
    }

    const instruction: Instruction = @enumFromInt(data[0]);

    // Get the counter account
    if (accounts.len < 1) {
        sol.print("Error: Missing counter account", .{});
        return err(.NotEnoughAccountKeys);
    }

    const counter_account = accounts[0];

    // Verify writable
    if (!counter_account.isWritable()) {
        sol.print("Error: Counter account not writable", .{});
        return err(.InvalidArgument);
    }

    const account_data = counter_account.data();

    switch (instruction) {
        .Initialize => {
            sol.print("Initialize counter", .{});

            const counter = Counter.fromBytes(account_data) orelse {
                return err(.AccountDataTooSmall);
            };
            counter.value = 0;
            sol.print("Counter initialized to 0", .{});
        },

        .Increment => {
            sol.print("Increment counter", .{});

            // Verify ownership
            if (!counter_account.ownerId().equals(program_id.*)) {
                sol.print("Error: Invalid owner", .{});
                return err(.IncorrectProgramId);
            }

            const counter = Counter.fromBytes(account_data) orelse {
                return err(.AccountDataTooSmall);
            };

            if (counter.value == std.math.maxInt(u64)) {
                return err(.ArithmeticOverflow);
            }

            counter.value += 1;
            sol.print("Counter: {d}", .{counter.value});
        },

        .Decrement => {
            sol.print("Decrement counter", .{});

            // Verify ownership
            if (!counter_account.ownerId().equals(program_id.*)) {
                return err(.IncorrectProgramId);
            }

            const counter = Counter.fromBytes(account_data) orelse {
                return err(.AccountDataTooSmall);
            };

            if (counter.value == 0) {
                return err(.InsufficientFunds); // Underflow
            }

            counter.value -= 1;
            sol.print("Counter: {d}", .{counter.value});
        },
    }

    return .ok;
}

// Declare the program entrypoint
comptime {
    sol.entrypoint(&processInstruction);
}
