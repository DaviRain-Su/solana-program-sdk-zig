//! Hello World - Solana On-Chain Program Example
//!
//! This is the simplest possible Solana program that demonstrates:
//! - Program entrypoint declaration
//! - Logging messages from on-chain
//! - Basic instruction processing

const sol = @import("solana_program_sdk");

/// Process a Hello World instruction.
fn processInstruction(
    program_id: *sol.PublicKey,
    accounts: []sol.Account,
    data: []const u8,
) sol.ProgramResult {
    // Log the program invocation
    sol.print("Hello, Solana! Program: {f}", .{program_id});

    // Log the number of accounts passed
    sol.print("Number of accounts: {d}", .{accounts.len});

    // Log each account's public key
    for (accounts, 0..) |account, i| {
        sol.print("Account {d}: {f}", .{ i, account.id() });
    }

    // Log instruction data length
    sol.print("Instruction data length: {d} bytes", .{data.len});

    sol.print("Hello World executed successfully!", .{});

    return .ok;
}

// Declare the program entrypoint
comptime {
    sol.entrypoint(&processInstruction);
}
