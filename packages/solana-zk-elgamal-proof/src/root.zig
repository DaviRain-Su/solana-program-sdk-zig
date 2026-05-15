//! `solana_zk_elgamal_proof` — raw ZK ElGamal proof-program instruction builders.
//!
//! This package is intentionally byte-oriented: callers generate or obtain the
//! proof bytes elsewhere, then use these builders to include the verify
//! instruction in a transaction or write a proof context state. It stays
//! allocation-free and has no host cryptography, RPC, transaction, or wallet
//! surface.

const std = @import("std");
const sol = @import("solana_program_sdk");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("ZkE1Gama1Proof11111111111111111111111111111");

pub const ProofInstruction = enum(u8) {
    close_context_state = 0,
    verify_zero_ciphertext = 1,
    verify_ciphertext_ciphertext_equality = 2,
    verify_ciphertext_commitment_equality = 3,
    verify_pubkey_validity = 4,
    verify_percentage_with_cap = 5,
    verify_batched_range_proof_u64 = 6,
    verify_batched_range_proof_u128 = 7,
    verify_batched_range_proof_u256 = 8,
    verify_grouped_ciphertext_2_handles_validity = 9,
    verify_batched_grouped_ciphertext_2_handles_validity = 10,
    verify_grouped_ciphertext_3_handles_validity = 11,
    verify_batched_grouped_ciphertext_3_handles_validity = 12,
};

pub const ContextStateInfo = struct {
    context_state_account: *const Pubkey,
    context_state_authority: *const Pubkey,
};

pub const close_context_state_data_len: usize = 1;
pub const verify_proof_from_account_data_len: usize = 1 + @sizeOf(u32);

pub fn verifyProofDataLen(proof_data_len: usize) ?usize {
    return std.math.add(usize, 1, proof_data_len) catch null;
}

pub fn verifyProofAccountsLen(context_state_info: ?ContextStateInfo) usize {
    return if (context_state_info == null) 0 else 2;
}

pub fn verifyProofFromAccountAccountsLen(context_state_info: ?ContextStateInfo) usize {
    return if (context_state_info == null) 1 else 3;
}

pub fn closeContextState(
    context_state_account: *const Pubkey,
    destination_account: *const Pubkey,
    context_state_authority: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *[close_context_state_data_len]u8,
) Instruction {
    data[0] = @intFromEnum(ProofInstruction.close_context_state);
    metas[0] = AccountMeta.writable(context_state_account);
    metas[1] = AccountMeta.writable(destination_account);
    metas[2] = AccountMeta.signer(context_state_authority);
    return ix(metas, data);
}

pub fn verifyProof(
    proof_instruction: ProofInstruction,
    context_state_info: ?ContextStateInfo,
    proof_data: []const u8,
    metas: []AccountMeta,
    data: []u8,
) !Instruction {
    const data_len = verifyProofDataLen(proof_data.len) orelse return error.OutputTooSmall;
    const accounts_len = verifyProofAccountsLen(context_state_info);
    if (metas.len < accounts_len or data.len < data_len) return error.OutputTooSmall;

    fillContextStateMetas(context_state_info, metas);
    data[0] = @intFromEnum(proof_instruction);
    @memcpy(data[1..data_len], proof_data);
    return ixSlice(metas[0..accounts_len], data[0..data_len]);
}

pub fn verifyProofFromAccount(
    proof_instruction: ProofInstruction,
    context_state_info: ?ContextStateInfo,
    proof_account: *const Pubkey,
    offset: u32,
    metas: []AccountMeta,
    data: *[verify_proof_from_account_data_len]u8,
) !Instruction {
    const accounts_len = verifyProofFromAccountAccountsLen(context_state_info);
    if (metas.len < accounts_len) return error.OutputTooSmall;

    metas[0] = AccountMeta.writable(proof_account);
    if (context_state_info) |context| {
        metas[1] = AccountMeta.writable(context.context_state_account);
        metas[2] = AccountMeta.readonly(context.context_state_authority);
    }
    data[0] = @intFromEnum(proof_instruction);
    std.mem.writeInt(u32, data[1..5], offset, .little);
    return ixSlice(metas[0..accounts_len], data);
}

fn fillContextStateMetas(context_state_info: ?ContextStateInfo, metas: []AccountMeta) void {
    if (context_state_info) |context| {
        metas[0] = AccountMeta.writable(context.context_state_account);
        metas[1] = AccountMeta.readonly(context.context_state_authority);
    }
}

fn ix(accounts: anytype, data: anytype) Instruction {
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = accounts,
        .data = data,
    };
}

fn ixSlice(accounts: []const AccountMeta, data: []const u8) Instruction {
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = accounts,
        .data = data,
    };
}

test "closeContextState builds canonical instruction" {
    const context: Pubkey = .{1} ** 32;
    const destination: Pubkey = .{2} ** 32;
    const authority: Pubkey = .{3} ** 32;
    var metas: [3]AccountMeta = undefined;
    var data: [close_context_state_data_len]u8 = undefined;

    const built = closeContextState(&context, &destination, &authority, &metas, &data);
    try std.testing.expectEqualSlices(u8, &PROGRAM_ID, built.program_id);
    try std.testing.expectEqualSlices(u8, &.{0}, built.data);
    try expectMeta(built.accounts[0], &context, 1, 0);
    try expectMeta(built.accounts[1], &destination, 1, 0);
    try expectMeta(built.accounts[2], &authority, 0, 1);
}

test "verifyProof builds inline and proof-account shapes" {
    const context_state: Pubkey = .{4} ** 32;
    const authority: Pubkey = .{5} ** 32;
    const proof_account: Pubkey = .{6} ** 32;
    const context: ContextStateInfo = .{
        .context_state_account = &context_state,
        .context_state_authority = &authority,
    };
    const proof_bytes = [_]u8{ 0xaa, 0xbb, 0xcc };

    var inline_metas: [2]AccountMeta = undefined;
    var inline_data: [4]u8 = undefined;
    const inline_ix = try verifyProof(.verify_pubkey_validity, context, &proof_bytes, &inline_metas, &inline_data);
    try std.testing.expectEqualSlices(u8, &.{ 4, 0xaa, 0xbb, 0xcc }, inline_ix.data);
    try expectMeta(inline_ix.accounts[0], &context_state, 1, 0);
    try expectMeta(inline_ix.accounts[1], &authority, 0, 0);

    var account_metas: [3]AccountMeta = undefined;
    var account_data: [verify_proof_from_account_data_len]u8 = undefined;
    const from_account = try verifyProofFromAccount(.verify_pubkey_validity, context, &proof_account, 42, &account_metas, &account_data);
    try std.testing.expectEqualSlices(u8, &.{ 4, 42, 0, 0, 0 }, from_account.data);
    try expectMeta(from_account.accounts[0], &proof_account, 1, 0);
    try expectMeta(from_account.accounts[1], &context_state, 1, 0);
    try expectMeta(from_account.accounts[2], &authority, 0, 0);
}

test "verifyProof supports no context state account" {
    const proof_bytes = [_]u8{0xee};
    var metas: [1]AccountMeta = undefined;
    var data: [2]u8 = undefined;

    const inline_ix = try verifyProof(.verify_zero_ciphertext, null, &proof_bytes, &metas, &data);
    try std.testing.expectEqual(@as(usize, 0), inline_ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0xee }, inline_ix.data);
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "PROGRAM_ID"));
    try std.testing.expect(@hasDecl(@This(), "closeContextState"));
    try std.testing.expect(@hasDecl(@This(), "verifyProof"));
    try std.testing.expect(@hasDecl(@This(), "verifyProofFromAccount"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "transaction"));
    try std.testing.expect(!@hasDecl(@This(), "keypair"));
}

fn expectMeta(meta: AccountMeta, key: *const Pubkey, writable: u8, signer: u8) !void {
    try std.testing.expectEqualSlices(u8, key, meta.pubkey);
    try std.testing.expectEqual(writable, meta.is_writable);
    try std.testing.expectEqual(signer, meta.is_signer);
}
