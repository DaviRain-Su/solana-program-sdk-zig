//! Transfer Lamports - Solana On-Chain Program Example
//!
//! This program demonstrates:
//! - Cross-Program Invocation (CPI) to the System Program
//! - Transferring SOL between accounts
//!
//! Instructions:
//! - [0, amount: u64]: Transfer lamports from signer to destination
//!
//! Accounts:
//! 0. [signer, writable] Source account
//! 1. [writable] Destination account
//! 2. [] System program

const std = @import("std");
const sol = @import("solana_program_sdk");

/// Instruction discriminators
pub const Instruction = enum(u8) {
    Transfer = 0,
};

/// Helper to create error result
fn err(e: sol.ProgramError) sol.ProgramResult {
    return .{ .err = e };
}

/// Process instruction
fn processInstruction(
    program_id: *sol.PublicKey,
    accounts: []sol.Account,
    data: []const u8,
) sol.ProgramResult {
    _ = program_id;
    sol.print("Transfer Lamports program invoked", .{});

    if (data.len < 1) {
        return err(.InvalidInstructionData);
    }

    const instruction: Instruction = @enumFromInt(data[0]);

    switch (instruction) {
        .Transfer => return processTransfer(accounts, data),
    }
}

/// Process a transfer
fn processTransfer(accounts: []sol.Account, data: []const u8) sol.ProgramResult {
    sol.print("Processing transfer", .{});

    // Validate accounts
    if (accounts.len < 3) {
        sol.print("Error: Need 3 accounts", .{});
        return err(.NotEnoughAccountKeys);
    }

    const source = accounts[0];
    const destination = accounts[1];
    const system_program = accounts[2];

    // Verify source is signer
    if (!source.isSigner()) {
        return err(.MissingRequiredSignature);
    }

    // Verify writable
    if (!source.isWritable() or !destination.isWritable()) {
        return err(.InvalidArgument);
    }

    // Verify system program
    if (!system_program.id().equals(sol.system_program.id)) {
        return err(.IncorrectProgramId);
    }

    // Parse amount
    if (data.len < 9) {
        return err(.InvalidInstructionData);
    }

    const amount = std.mem.readInt(u64, data[1..9], .little);
    sol.print("Transfer amount: {d}", .{amount});

    // Check funds
    if (source.lamports().* < amount) {
        return err(.InsufficientFunds);
    }

    // Build System Program transfer instruction data
    // Transfer = instruction index 2
    var transfer_data: [12]u8 = undefined;
    transfer_data[0] = 2;
    transfer_data[1] = 0;
    transfer_data[2] = 0;
    transfer_data[3] = 0;
    std.mem.writeInt(u64, transfer_data[4..12], amount, .little);

    // Account params for CPI
    const account_params = [_]sol.Account.Param{
        .{ .id = &source.ptr.id, .is_writable = true, .is_signer = true },
        .{ .id = &destination.ptr.id, .is_writable = true, .is_signer = false },
    };

    const cpi_ix = sol.instruction.Instruction.from(.{
        .program_id = &sol.system_program.id,
        .accounts = &account_params,
        .data = &transfer_data,
    });

    const account_infos = [_]sol.Account.Info{
        source.info(),
        destination.info(),
    };

    // Invoke System Program
    if (cpi_ix.invoke(&account_infos)) |cpi_err| {
        sol.print("CPI failed: {d}", .{@intFromEnum(cpi_err)});
        return .{ .err = cpi_err };
    }

    sol.print("Transfer successful!", .{});
    return .ok;
}

// Declare the program entrypoint
comptime {
    sol.entrypoint(&processInstruction);
}
