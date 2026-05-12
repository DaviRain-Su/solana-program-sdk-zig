//! SPL Associated Token Account instruction builders — dual-target.
//!
//! Builders construct allocation-free `sol.cpi.Instruction` values
//! using caller-owned scratch, matching the sibling SPL package
//! patterns in this repository.

const std = @import("std");
const sol = @import("solana_program_sdk");
const derivation = @import("derivation.zig");
const id = @import("id.zig");

const Pubkey = sol.Pubkey;
const AccountMeta = sol.cpi.AccountMeta;
const Instruction = sol.cpi.Instruction;

pub const AssociatedTokenAccountInstruction = enum(u8) {
    create = 0,
    create_idempotent = 1,
};

pub const Spec = struct {
    disc: AssociatedTokenAccountInstruction,
    accounts_len: usize,
    data_len: usize,
};

pub const create_spec: Spec = .{
    .disc = .create,
    .accounts_len = 6,
    .data_len = 1,
};

pub const create_idempotent_spec: Spec = .{
    .disc = .create_idempotent,
    .accounts_len = 6,
    .data_len = 1,
};

pub fn metasArray(comptime spec: Spec) type {
    return [spec.accounts_len]AccountMeta;
}

pub fn dataArray(comptime spec: Spec) type {
    return [spec.data_len]u8;
}

pub fn Scratch(comptime spec: Spec) type {
    return struct {
        associated_token_account: Pubkey = undefined,
        metas: metasArray(spec) = undefined,
        data: dataArray(spec) = undefined,
    };
}

comptime {
    const DISC_LEN: usize = 1;
    const audits = .{ create_spec, create_idempotent_spec };

    for (audits) |spec| {
        if (spec.accounts_len != 6) {
            @compileError(std.fmt.comptimePrint(
                "spl-ata spec drift: {s} accounts_len={d} but protocol says 6",
                .{ @tagName(spec.disc), spec.accounts_len },
            ));
        }
        if (spec.data_len != DISC_LEN) {
            @compileError(std.fmt.comptimePrint(
                "spl-ata spec drift: {s} data_len={d} but protocol says 1",
                .{ @tagName(spec.disc), spec.data_len },
            ));
        }
    }
}

fn buildInstruction(
    comptime spec: Spec,
    payer: *const Pubkey,
    wallet: *const Pubkey,
    mint: *const Pubkey,
    system_program: *const Pubkey,
    token_program: *const Pubkey,
    scratch: *Scratch(spec),
) Instruction {
    const associated_token_address = derivation.findAddress(
        wallet,
        mint,
        token_program,
    );

    scratch.associated_token_account = associated_token_address.address;
    scratch.data = .{@intFromEnum(spec.disc)};
    scratch.metas[0] = AccountMeta.signerWritable(payer);
    scratch.metas[1] = AccountMeta.writable(&scratch.associated_token_account);
    scratch.metas[2] = AccountMeta.readonly(wallet);
    scratch.metas[3] = AccountMeta.readonly(mint);
    scratch.metas[4] = AccountMeta.readonly(system_program);
    scratch.metas[5] = AccountMeta.readonly(token_program);
    return Instruction.init(&id.PROGRAM_ID, &scratch.metas, &scratch.data);
}

pub fn create(
    payer: *const Pubkey,
    wallet: *const Pubkey,
    mint: *const Pubkey,
    system_program: *const Pubkey,
    token_program: *const Pubkey,
    scratch: *Scratch(create_spec),
) Instruction {
    return buildInstruction(
        create_spec,
        payer,
        wallet,
        mint,
        system_program,
        token_program,
        scratch,
    );
}

pub fn createIdempotent(
    payer: *const Pubkey,
    wallet: *const Pubkey,
    mint: *const Pubkey,
    system_program: *const Pubkey,
    token_program: *const Pubkey,
    scratch: *Scratch(create_idempotent_spec),
) Instruction {
    return buildInstruction(
        create_idempotent_spec,
        payer,
        wallet,
        mint,
        system_program,
        token_program,
        scratch,
    );
}

fn expectMeta(
    actual: AccountMeta,
    expected_key: *const Pubkey,
    expected_writable: u8,
    expected_signer: u8,
) !void {
    try std.testing.expectEqual(expected_key, actual.pubkey);
    try std.testing.expectEqual(expected_writable, actual.is_writable);
    try std.testing.expectEqual(expected_signer, actual.is_signer);
}

fn expectMetaBytes(
    actual: AccountMeta,
    expected_key: *const Pubkey,
    expected_writable: u8,
    expected_signer: u8,
) !void {
    try std.testing.expectEqualSlices(u8, expected_key, actual.pubkey);
    try std.testing.expectEqual(expected_writable, actual.is_writable);
    try std.testing.expectEqual(expected_signer, actual.is_signer);
}

test "spec helpers expose canonical ATA wire lengths" {
    try std.testing.expectEqual(@as(usize, 6), create_spec.accounts_len);
    try std.testing.expectEqual(@as(usize, 1), create_spec.data_len);
    try std.testing.expectEqual(@as(usize, 6), create_idempotent_spec.accounts_len);
    try std.testing.expectEqual(@as(usize, 1), create_idempotent_spec.data_len);

    const create_scratch: Scratch(create_spec) = undefined;
    const create_idempotent_scratch: Scratch(create_idempotent_spec) = undefined;
    try std.testing.expectEqual(@as(usize, 6), create_scratch.metas.len);
    try std.testing.expectEqual(@as(usize, 1), create_scratch.data.len);
    try std.testing.expectEqual(@as(usize, 6), create_idempotent_scratch.metas.len);
    try std.testing.expectEqual(@as(usize, 1), create_idempotent_scratch.data.len);
}

test "create emits canonical metas, ATA callee, and [0] discriminator" {
    const payer: Pubkey = .{0x11} ** 32;
    const wallet: Pubkey = .{0x22} ** 32;
    const mint: Pubkey = .{0x33} ** 32;
    const system_program: Pubkey = sol.system_program_id;
    const token_program: Pubkey = sol.spl_token_program_id;
    const expected_ata = derivation.findAddress(&wallet, &mint, &token_program);

    var scratch: Scratch(create_spec) = undefined;
    const ix = create(
        &payer,
        &wallet,
        &mint,
        &system_program,
        &token_program,
        &scratch,
    );

    try std.testing.expectEqual(&id.PROGRAM_ID, ix.program_id);
    try std.testing.expectEqual(@as(usize, 6), ix.accounts.len);
    try std.testing.expectEqual(@as(usize, 1), ix.data.len);
    try std.testing.expectEqual(@as(u8, 0), ix.data[0]);

    try expectMeta(ix.accounts[0], &payer, 1, 1);
    try expectMeta(ix.accounts[1], &scratch.associated_token_account, 1, 0);
    try std.testing.expectEqualSlices(u8, &expected_ata.address, ix.accounts[1].pubkey);
    try expectMeta(ix.accounts[2], &wallet, 0, 0);
    try expectMeta(ix.accounts[3], &mint, 0, 0);
    try expectMeta(ix.accounts[4], &system_program, 0, 0);
    try expectMeta(ix.accounts[5], &token_program, 0, 0);
}

test "createIdempotent emits create metas with [1] discriminator" {
    const payer: Pubkey = .{0x44} ** 32;
    const wallet: Pubkey = .{0x55} ** 32;
    const mint: Pubkey = .{0x66} ** 32;
    const system_program: Pubkey = sol.system_program_id;
    const token_program: Pubkey = sol.spl_token_program_id;

    var create_scratch: Scratch(create_spec) = undefined;
    create_scratch.associated_token_account = payer;
    var idempotent_scratch: Scratch(create_idempotent_spec) = undefined;
    idempotent_scratch.associated_token_account = payer;

    const create_ix = create(
        &payer,
        &wallet,
        &mint,
        &system_program,
        &token_program,
        &create_scratch,
    );
    const idempotent_ix = createIdempotent(
        &payer,
        &wallet,
        &mint,
        &system_program,
        &token_program,
        &idempotent_scratch,
    );

    try std.testing.expectEqual(&id.PROGRAM_ID, idempotent_ix.program_id);
    try std.testing.expectEqual(@as(usize, 6), idempotent_ix.accounts.len);
    try std.testing.expectEqual(@as(usize, 1), idempotent_ix.data.len);
    try std.testing.expectEqual(@as(u8, 1), idempotent_ix.data[0]);

    for (create_ix.accounts, idempotent_ix.accounts) |create_meta, idempotent_meta| {
        try expectMetaBytes(
            idempotent_meta,
            create_meta.pubkey,
            create_meta.is_writable,
            create_meta.is_signer,
        );
    }
}

test "builders preserve caller-owned scratch buffers" {
    const payer: Pubkey = .{0x77} ** 32;
    const wallet: Pubkey = .{0x88} ** 32;
    const mint: Pubkey = .{0x99} ** 32;
    const system_program: Pubkey = sol.system_program_id;
    const token_program: Pubkey = sol.spl_token_program_id;

    var scratch: Scratch(create_spec) = undefined;
    const ix = create(
        &payer,
        &wallet,
        &mint,
        &system_program,
        &token_program,
        &scratch,
    );

    try std.testing.expectEqual(@intFromPtr(&scratch.metas[0]), @intFromPtr(ix.accounts.ptr));
    try std.testing.expectEqual(@intFromPtr(&scratch.data[0]), @intFromPtr(ix.data.ptr));
    try std.testing.expectEqual(&scratch.associated_token_account, ix.accounts[1].pubkey);
}

test "token program id stays caller-controlled while ATA callee stays fixed" {
    const payer: Pubkey = .{0xAA} ** 32;
    const wallet: Pubkey = .{0xBB} ** 32;
    const mint: Pubkey = .{0xCC} ** 32;
    const system_program: Pubkey = sol.system_program_id;
    const classic_token_program: Pubkey = sol.spl_token_program_id;
    const token_2022_program: Pubkey = sol.spl_token_2022_program_id;

    var classic_scratch: Scratch(create_spec) = undefined;
    var token_2022_scratch: Scratch(create_spec) = undefined;

    const classic_ix = create(
        &payer,
        &wallet,
        &mint,
        &system_program,
        &classic_token_program,
        &classic_scratch,
    );
    const token_2022_ix = create(
        &payer,
        &wallet,
        &mint,
        &system_program,
        &token_2022_program,
        &token_2022_scratch,
    );

    try std.testing.expectEqual(&id.PROGRAM_ID, classic_ix.program_id);
    try std.testing.expectEqual(&id.PROGRAM_ID, token_2022_ix.program_id);
    try expectMeta(classic_ix.accounts[5], &classic_token_program, 0, 0);
    try expectMeta(token_2022_ix.accounts[5], &token_2022_program, 0, 0);
    try std.testing.expect(
        !sol.pubkey.pubkeyEq(
            classic_ix.accounts[1].pubkey,
            token_2022_ix.accounts[1].pubkey,
        ),
    );
}
