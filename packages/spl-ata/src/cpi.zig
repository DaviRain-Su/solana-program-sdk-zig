//! On-chain CPI wrappers around the SPL Associated Token Account
//! program.
//!
//! Thin syntactic sugar over `instruction.zig` + `sol.cpi.invokeRaw`.
//! The wrappers stack-allocate the builder scratch, reuse the
//! instruction builders for meta/data encoding, and then rebrand the
//! resulting instruction's `program_id` from the caller-provided ATA
//! program account so the CPI callee comes from runtime account input
//! rather than a rodata constant.

const std = @import("std");
const sol = @import("solana_program_sdk");
const instruction = @import("instruction.zig");

const Pubkey = sol.Pubkey;
const CpiAccountInfo = sol.CpiAccountInfo;
const Instruction = sol.cpi.Instruction;
const ProgramResult = sol.ProgramResult;

inline fn rebrand(ix: Instruction, program_id: *const Pubkey) Instruction {
    return .{
        .program_id = program_id,
        .accounts = ix.accounts,
        .data = ix.data,
    };
}

fn buildInstruction(
    comptime spec: instruction.Spec,
    payer: CpiAccountInfo,
    wallet: CpiAccountInfo,
    mint: CpiAccountInfo,
    system_program: CpiAccountInfo,
    token_program: CpiAccountInfo,
    associated_token_program: CpiAccountInfo,
    scratch: *instruction.Scratch(spec),
) Instruction {
    const built = switch (spec.disc) {
        .create => instruction.create(
            payer.key(),
            wallet.key(),
            mint.key(),
            system_program.key(),
            token_program.key(),
            scratch,
        ),
        .create_idempotent => instruction.createIdempotent(
            payer.key(),
            wallet.key(),
            mint.key(),
            system_program.key(),
            token_program.key(),
            scratch,
        ),
    };

    return rebrand(built, associated_token_program.key());
}

inline fn runtimeAccounts(
    payer: CpiAccountInfo,
    associated_token_account: CpiAccountInfo,
    wallet: CpiAccountInfo,
    mint: CpiAccountInfo,
    system_program: CpiAccountInfo,
    token_program: CpiAccountInfo,
    associated_token_program: CpiAccountInfo,
) [7]CpiAccountInfo {
    return .{
        payer,
        associated_token_account,
        wallet,
        mint,
        system_program,
        token_program,
        associated_token_program,
    };
}

pub fn create(
    payer: CpiAccountInfo,
    associated_token_account: CpiAccountInfo,
    wallet: CpiAccountInfo,
    mint: CpiAccountInfo,
    system_program: CpiAccountInfo,
    token_program: CpiAccountInfo,
    associated_token_program: CpiAccountInfo,
) ProgramResult {
    var scratch: instruction.Scratch(instruction.create_spec) = undefined;
    const ix = buildInstruction(
        instruction.create_spec,
        payer,
        wallet,
        mint,
        system_program,
        token_program,
        associated_token_program,
        &scratch,
    );
    const infos = runtimeAccounts(
        payer,
        associated_token_account,
        wallet,
        mint,
        system_program,
        token_program,
        associated_token_program,
    );
    return sol.cpi.invokeRaw(&ix, &infos);
}

pub fn createIdempotent(
    payer: CpiAccountInfo,
    associated_token_account: CpiAccountInfo,
    wallet: CpiAccountInfo,
    mint: CpiAccountInfo,
    system_program: CpiAccountInfo,
    token_program: CpiAccountInfo,
    associated_token_program: CpiAccountInfo,
) ProgramResult {
    var scratch: instruction.Scratch(instruction.create_idempotent_spec) = undefined;
    const ix = buildInstruction(
        instruction.create_idempotent_spec,
        payer,
        wallet,
        mint,
        system_program,
        token_program,
        associated_token_program,
        &scratch,
    );
    const infos = runtimeAccounts(
        payer,
        associated_token_account,
        wallet,
        mint,
        system_program,
        token_program,
        associated_token_program,
    );
    return sol.cpi.invokeRaw(&ix, &infos);
}

const TestAccount = extern struct {
    raw: sol.account.Account,
    data: [8]u8 = .{0} ** 8,
};

fn testAccount(
    key: Pubkey,
    owner: Pubkey,
    signer: bool,
    writable: bool,
    executable: bool,
) TestAccount {
    return .{
        .raw = .{
            .borrow_state = sol.account.NOT_BORROWED,
            .is_signer = @intFromBool(signer),
            .is_writable = @intFromBool(writable),
            .is_executable = @intFromBool(executable),
            ._padding = .{0} ** 4,
            .key = key,
            .owner = owner,
            .lamports = 0,
            .data_len = 8,
        },
    };
}

fn toCpiAccountInfo(backing: *TestAccount) CpiAccountInfo {
    return (sol.AccountInfo{ .raw = &backing.raw }).toCpiInfo();
}

test "public CPI wrapper decls exist" {
    try std.testing.expect(@hasDecl(@This(), "create"));
    try std.testing.expect(@hasDecl(@This(), "createIdempotent"));
}

test "create rebrands ATA callee and preserves canonical runtime account order" {
    var payer_account = testAccount(.{0x11} ** 32, sol.system_program_id, true, true, false);
    var associated_token_account = testAccount(.{0x22} ** 32, .{0x90} ** 32, false, true, false);
    var wallet_account = testAccount(.{0x33} ** 32, .{0x91} ** 32, false, false, false);
    var mint_account = testAccount(.{0x44} ** 32, .{0x92} ** 32, false, false, false);
    var system_program_account = testAccount(sol.system_program_id, .{0x93} ** 32, false, false, true);
    var token_program_account = testAccount(.{0x55} ** 32, .{0x94} ** 32, false, false, true);
    var ata_program_account = testAccount(.{0x66} ** 32, .{0x95} ** 32, false, false, true);

    const payer = toCpiAccountInfo(&payer_account);
    const ata = toCpiAccountInfo(&associated_token_account);
    const wallet = toCpiAccountInfo(&wallet_account);
    const mint = toCpiAccountInfo(&mint_account);
    const system_program = toCpiAccountInfo(&system_program_account);
    const token_program = toCpiAccountInfo(&token_program_account);
    const associated_token_program = toCpiAccountInfo(&ata_program_account);

    var scratch: instruction.Scratch(instruction.create_spec) = undefined;
    const ix = buildInstruction(
        instruction.create_spec,
        payer,
        wallet,
        mint,
        system_program,
        token_program,
        associated_token_program,
        &scratch,
    );
    const infos = runtimeAccounts(
        payer,
        ata,
        wallet,
        mint,
        system_program,
        token_program,
        associated_token_program,
    );
    const expected_ata = instruction.create(
        payer.key(),
        wallet.key(),
        mint.key(),
        system_program.key(),
        token_program.key(),
        &scratch,
    );

    try std.testing.expectEqual(associated_token_program.key(), ix.program_id);
    try std.testing.expectEqual(@as(usize, 6), ix.accounts.len);
    try std.testing.expectEqual(@as(usize, 1), ix.data.len);
    try std.testing.expectEqual(@as(u8, 0), ix.data[0]);
    try std.testing.expectEqualSlices(u8, expected_ata.accounts[1].pubkey, ix.accounts[1].pubkey);
    try std.testing.expect(!sol.pubkey.pubkeyEq(ix.accounts[1].pubkey, infos[1].key()));
    try std.testing.expectEqualSlices(u8, payer.key(), infos[0].key());
    try std.testing.expectEqualSlices(u8, ata.key(), infos[1].key());
    try std.testing.expectEqualSlices(u8, wallet.key(), infos[2].key());
    try std.testing.expectEqualSlices(u8, mint.key(), infos[3].key());
    try std.testing.expectEqualSlices(u8, system_program.key(), infos[4].key());
    try std.testing.expectEqualSlices(u8, token_program.key(), infos[5].key());
    try std.testing.expectEqualSlices(u8, associated_token_program.key(), infos[6].key());
}

test "createIdempotent keeps builder metas/data and caller-selected token plus ATA programs" {
    var payer_account = testAccount(.{0x71} ** 32, sol.system_program_id, true, true, false);
    var associated_token_account = testAccount(.{0x72} ** 32, .{0x96} ** 32, false, true, false);
    var wallet_account = testAccount(.{0x73} ** 32, .{0x97} ** 32, false, false, false);
    var mint_account = testAccount(.{0x74} ** 32, .{0x98} ** 32, false, false, false);
    var system_program_account = testAccount(sol.system_program_id, .{0x99} ** 32, false, false, true);
    var token_program_account = testAccount(sol.spl_token_2022_program_id, .{0x9A} ** 32, false, false, true);
    var ata_program_account = testAccount(.{0x75} ** 32, .{0x9B} ** 32, false, false, true);

    const payer = toCpiAccountInfo(&payer_account);
    const ata = toCpiAccountInfo(&associated_token_account);
    const wallet = toCpiAccountInfo(&wallet_account);
    const mint = toCpiAccountInfo(&mint_account);
    const system_program = toCpiAccountInfo(&system_program_account);
    const token_program = toCpiAccountInfo(&token_program_account);
    const associated_token_program = toCpiAccountInfo(&ata_program_account);

    var scratch: instruction.Scratch(instruction.create_idempotent_spec) = undefined;
    const ix = buildInstruction(
        instruction.create_idempotent_spec,
        payer,
        wallet,
        mint,
        system_program,
        token_program,
        associated_token_program,
        &scratch,
    );
    const infos = runtimeAccounts(
        payer,
        ata,
        wallet,
        mint,
        system_program,
        token_program,
        associated_token_program,
    );

    try std.testing.expectEqual(associated_token_program.key(), ix.program_id);
    try std.testing.expectEqual(@as(u8, 1), ix.data[0]);
    try std.testing.expectEqualSlices(u8, token_program.key(), ix.accounts[5].pubkey);
    try std.testing.expectEqualSlices(u8, ata.key(), infos[1].key());
    try std.testing.expectEqualSlices(u8, associated_token_program.key(), infos[6].key());
}
