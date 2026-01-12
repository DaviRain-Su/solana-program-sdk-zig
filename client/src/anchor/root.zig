//! Anchor client helpers for generated programs
//!
//! Rust source: https://github.com/coral-xyz/anchor/blob/master/client/src/lib.rs
//!
//! Provides common RPC transaction helpers and account decode utilities used
//! by code-generated clients.

const std = @import("std");

const client_root = @import("../root.zig");
const sdk = client_root.sdk;

pub const PublicKey = client_root.PublicKey;
pub const Signature = client_root.Signature;
pub const AccountMeta = client_root.AccountMeta;
pub const Keypair = client_root.Keypair;
pub const RpcClient = client_root.RpcClient;
pub const TransactionBuilder = client_root.TransactionBuilder;
pub const AccountInfo = client_root.AccountInfo;

/// Build, sign, and send a transaction with a single instruction.
pub fn sendInstruction(
    allocator: std.mem.Allocator,
    rpc: *RpcClient,
    program_id: PublicKey,
    accounts: []const AccountMeta,
    data: []const u8,
    signers: []const *const Keypair,
) !Signature {
    // Get recent blockhash
    const blockhash = try rpc.getLatestBlockhash();

    // Build transaction
    var builder = TransactionBuilder.init(allocator);
    defer builder.deinit();

    // Set fee payer (first signer)
    if (signers.len == 0) return error.NoSigners;
    _ = builder.setFeePayer(signers[0].pubkey());
    _ = builder.setRecentBlockhash(blockhash.value.blockhash);

    _ = try builder.addInstruction(.{
        .program_id = program_id,
        .accounts = accounts,
        .data = data,
    });

    // Build and sign
    var tx = try builder.buildSigned(signers);
    defer tx.deinit();

    // Serialize and send
    const serialized = try tx.serialize();
    defer allocator.free(serialized);

    return rpc.sendAndConfirmTransaction(serialized);
}

/// Decode account data with Anchor discriminator using Borsh.
pub fn decodeAccountData(
    allocator: std.mem.Allocator,
    comptime T: type,
    data: []const u8,
    discriminator: [8]u8,
) !T {
    if (data.len < 8) return error.InvalidAccountData;
    if (!std.mem.eql(u8, data[0..8], &discriminator)) {
        return error.InvalidAccountDiscriminator;
    }
    const result = try sdk.borsh.deserializeExact(T, data[8..]);
    _ = allocator;
    return result;
}

/// Decode account data from RPC account info.
pub fn decodeAccountInfo(
    allocator: std.mem.Allocator,
    comptime T: type,
    info: AccountInfo,
    discriminator: [8]u8,
) !T {
    const decoded = try info.decodeData(allocator);
    defer allocator.free(decoded);
    return decodeAccountData(allocator, T, decoded, discriminator);
}
