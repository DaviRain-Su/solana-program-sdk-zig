//! Devnet SPL Token batch proof.
//!
//! Instruction tags:
//!   1. double_transfer_checked         [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!   2. batch_transfer_checked          [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!   3. batch_prepared_transfer_checked [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!
//! Fixed account order (6 accounts):
//!   0. token_program   — readonly
//!   1. source          — writable
//!   2. mint            — readonly
//!   3. destination_a   — writable
//!   4. destination_b   — writable
//!   5. authority       — signer

const sol = @import("solana_program_sdk");
const spl_token = @import("spl_token");

pub const panic = sol.panic.Panic;

const Ix = enum(u8) {
    double_transfer_checked = 1,
    batch_transfer_checked = 2,
    batch_prepared_transfer_checked = 3,
};

const TransferArgs = extern struct {
    amount_a: u64 align(1),
    amount_b: u64 align(1),
    decimals: u8,
};

const AccountInfo = sol.AccountInfo;
const TransferArgsReader = sol.instruction.IxDataReader(TransferArgs);

fn process(
    accounts: *const [6]AccountInfo,
    data: []const u8,
    _: *const sol.Pubkey,
) sol.ProgramResult {
    const tag = sol.instruction.parseTag(Ix, data) orelse return error.InvalidInstructionData;
    const args = TransferArgsReader.bind(data[1..]) orelse return error.InvalidInstructionData;

    const token_program = accounts[0];
    const source = accounts[1];
    const mint = accounts[2];
    const destination_a = accounts[3];
    const destination_b = accounts[4];
    const authority = accounts[5];

    try source.expect(.{ .writable = true });
    try destination_a.expect(.{ .writable = true });
    try destination_b.expect(.{ .writable = true });
    try authority.expect(.{ .signer = true });

    return switch (tag) {
        .double_transfer_checked => processDouble(
            token_program,
            source,
            mint,
            destination_a,
            destination_b,
            authority,
            args,
        ),
        .batch_transfer_checked => processBatch(
            token_program,
            source,
            mint,
            destination_a,
            destination_b,
            authority,
            args,
        ),
        .batch_prepared_transfer_checked => processBatchPrepared(
            token_program,
            source,
            mint,
            destination_a,
            destination_b,
            authority,
            args,
        ),
    };
}

fn processDouble(
    token_program: AccountInfo,
    source: AccountInfo,
    mint: AccountInfo,
    destination_a: AccountInfo,
    destination_b: AccountInfo,
    authority: AccountInfo,
    args: TransferArgsReader,
) !void {
    try spl_token.cpi.transferChecked(
        token_program.toCpiInfo(),
        source.toCpiInfo(),
        mint.toCpiInfo(),
        destination_a.toCpiInfo(),
        authority.toCpiInfo(),
        args.get(.amount_a),
        args.get(.decimals),
    );
    try spl_token.cpi.transferChecked(
        token_program.toCpiInfo(),
        source.toCpiInfo(),
        mint.toCpiInfo(),
        destination_b.toCpiInfo(),
        authority.toCpiInfo(),
        args.get(.amount_b),
        args.get(.decimals),
    );
}

fn processBatch(
    token_program: AccountInfo,
    source: AccountInfo,
    mint: AccountInfo,
    destination_a: AccountInfo,
    destination_b: AccountInfo,
    authority: AccountInfo,
    args: TransferArgsReader,
) !void {
    var child_a_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_a_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_a = spl_token.instruction.transferChecked(
        source.key(),
        mint.key(),
        destination_a.key(),
        authority.key(),
        args.get(.amount_a),
        args.get(.decimals),
        &child_a_metas,
        &child_a_data,
    );

    var child_b_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_b_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_b = spl_token.instruction.transferChecked(
        source.key(),
        mint.key(),
        destination_b.key(),
        authority.key(),
        args.get(.amount_b),
        args.get(.decimals),
        &child_b_metas,
        &child_b_data,
    );

    const entries = [_]spl_token.instruction.BatchEntry{
        spl_token.instruction.asBatchEntry(child_a),
        spl_token.instruction.asBatchEntry(child_b),
    };
    var batch_metas: [spl_token.instruction.transfer_checked_spec.accounts_len * entries.len]sol.cpi.AccountMeta = undefined;
    var batch_data: [1 + entries.len * (2 + spl_token.instruction.transfer_checked_spec.data_len)]u8 = undefined;
    var invoke_accounts: [spl_token.instruction.transfer_checked_spec.accounts_len * entries.len + 1]sol.CpiAccountInfo = undefined;

    try spl_token.cpi.batch(
        token_program.toCpiInfo(),
        &entries,
        &.{
            source.toCpiInfo(),
            mint.toCpiInfo(),
            destination_a.toCpiInfo(),
            authority.toCpiInfo(),
            source.toCpiInfo(),
            mint.toCpiInfo(),
            destination_b.toCpiInfo(),
            authority.toCpiInfo(),
        },
        invoke_accounts[0..],
        batch_metas[0..],
        batch_data[0..],
    );
}

fn processBatchPrepared(
    token_program: AccountInfo,
    source: AccountInfo,
    mint: AccountInfo,
    destination_a: AccountInfo,
    destination_b: AccountInfo,
    authority: AccountInfo,
    args: TransferArgsReader,
) !void {
    var child_a_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_a_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_a = spl_token.instruction.transferChecked(
        source.key(),
        mint.key(),
        destination_a.key(),
        authority.key(),
        args.get(.amount_a),
        args.get(.decimals),
        &child_a_metas,
        &child_a_data,
    );

    var child_b_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_b_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_b = spl_token.instruction.transferChecked(
        source.key(),
        mint.key(),
        destination_b.key(),
        authority.key(),
        args.get(.amount_b),
        args.get(.decimals),
        &child_b_metas,
        &child_b_data,
    );

    const entries = [_]spl_token.instruction.BatchEntry{
        spl_token.instruction.asBatchEntry(child_a),
        spl_token.instruction.asBatchEntry(child_b),
    };
    var batch_metas: [spl_token.instruction.transfer_checked_spec.accounts_len * entries.len]sol.cpi.AccountMeta = undefined;
    var batch_data: [1 + entries.len * (2 + spl_token.instruction.transfer_checked_spec.data_len)]u8 = undefined;

    try spl_token.cpi.batchPrepared(
        token_program.toCpiInfo(),
        &entries,
        &.{
            source.toCpiInfo(),
            mint.toCpiInfo(),
            destination_a.toCpiInfo(),
            authority.toCpiInfo(),
            source.toCpiInfo(),
            mint.toCpiInfo(),
            destination_b.toCpiInfo(),
            authority.toCpiInfo(),
            token_program.toCpiInfo(),
        },
        batch_metas[0..],
        batch_data[0..],
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.programEntrypoint(6, process)(input);
}
