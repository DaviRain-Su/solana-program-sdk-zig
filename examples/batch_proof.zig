//! Devnet SPL Token batch proof.
//!
//! Instruction tags:
//!   0. init_pda                              [tag, bump:u8]
//!   1. double_transfer                       [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!   2. batch_transfer                        [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!   3. batch_prepared_transfer               [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!   4. double_transfer_checked               [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!   5. batch_transfer_checked                [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!   6. batch_prepared_transfer_checked       [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!   7. double_mixed_transfer_checked         [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!   8. batch_mixed_transfer_checked          [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!   9. batch_prepared_mixed_transfer_checked [tag, amount_a:u64, amount_b:u64, decimals:u8]
//!
//! Fixed account order (9 accounts):
//!   0. token_program   — readonly
//!   1. user_source     — writable
//!   2. mint            — readonly
//!   3. destination_a   — writable
//!   4. destination_b   — writable
//!   5. user_authority  — signer (payer for `init_pda`)
//!   6. vault_source    — writable for mixed paths
//!   7. pda_state       — writable for `init_pda`, readonly otherwise
//!   8. system_program  — readonly

const sol = @import("solana_program_sdk");
const spl_token = @import("spl_token");

pub const panic = sol.panic.Panic;

const Ix = enum(u8) {
    init_pda = 0,
    double_transfer = 1,
    batch_transfer = 2,
    batch_prepared_transfer = 3,
    double_transfer_checked = 4,
    batch_transfer_checked = 5,
    batch_prepared_transfer_checked = 6,
    double_mixed_transfer_checked = 7,
    batch_mixed_transfer_checked = 8,
    batch_prepared_mixed_transfer_checked = 9,
};

const TransferArgs = extern struct {
    amount_a: u64 align(1),
    amount_b: u64 align(1),
    decimals: u8,
};

const PdaState = extern struct {
    bump: u8,
};

const AccountInfo = sol.AccountInfo;
const Pubkey = sol.Pubkey;
const BatchEntry = spl_token.instruction.BatchEntry;
const TransferArgsReader = sol.instruction.IxDataReader(TransferArgs);

fn process(
    accounts: *const [9]AccountInfo,
    data: []const u8,
    program_id: *const Pubkey,
) sol.ProgramResult {
    const tag = sol.instruction.parseTag(Ix, data) orelse return error.InvalidInstructionData;

    return switch (tag) {
        .init_pda => processInitPda(accounts, data, program_id),
        else => blk: {
            const args = TransferArgsReader.bind(data[1..]) orelse return error.InvalidInstructionData;
            break :blk processTransfer(accounts, args, tag, program_id);
        },
    };
}

fn processInitPda(
    accounts: *const [9]AccountInfo,
    data: []const u8,
    program_id: *const Pubkey,
) !void {
    const payer = accounts[5];
    const pda_state = accounts[7];
    const system_program = accounts[8];

    try payer.expect(.{ .signer = true, .writable = true });
    try pda_state.expect(.{ .writable = true });

    const bump = sol.instruction.tryReadUnaligned(u8, data, 1) orelse
        return error.InvalidInstructionData;
    const bump_seed = [_]u8{bump};

    try sol.system.createRentExemptComptimeSingle(.{
        .payer = payer.toCpiInfo(),
        .new_account = pda_state.toCpiInfo(),
        .system_program = system_program.toCpiInfo(),
        .owner = program_id,
    }, @sizeOf(PdaState), .{ "vault", &bump_seed });

    _ = try sol.TypedAccount(PdaState).initialize(pda_state, .{ .bump = bump });
}

fn processTransfer(
    accounts: *const [9]AccountInfo,
    args: TransferArgsReader,
    tag: Ix,
    program_id: *const Pubkey,
) !void {
    const token_program = accounts[0];
    const user_source = accounts[1];
    const mint = accounts[2];
    const destination_a = accounts[3];
    const destination_b = accounts[4];
    const user_authority = accounts[5];
    const vault_source = accounts[6];
    const pda_state = accounts[7];

    try user_source.expect(.{ .writable = true });
    try destination_a.expect(.{ .writable = true });
    try destination_b.expect(.{ .writable = true });
    try user_authority.expect(.{ .signer = true });

    switch (tag) {
        .double_transfer => return processDoubleTransfer(
            token_program,
            user_source,
            destination_a,
            destination_b,
            user_authority,
            args,
        ),
        .batch_transfer => return processBatchTransfer(
            token_program,
            user_source,
            destination_a,
            destination_b,
            user_authority,
            args,
        ),
        .batch_prepared_transfer => return processBatchPreparedTransfer(
            token_program,
            user_source,
            destination_a,
            destination_b,
            user_authority,
            args,
        ),
        .double_transfer_checked => return processDoubleTransferChecked(
            token_program,
            user_source,
            mint,
            destination_a,
            destination_b,
            user_authority,
            args,
        ),
        .batch_transfer_checked => return processBatchTransferChecked(
            token_program,
            user_source,
            mint,
            destination_a,
            destination_b,
            user_authority,
            args,
        ),
        .batch_prepared_transfer_checked => return processBatchPreparedTransferChecked(
            token_program,
            user_source,
            mint,
            destination_a,
            destination_b,
            user_authority,
            args,
        ),
        .double_mixed_transfer_checked,
        .batch_mixed_transfer_checked,
        .batch_prepared_mixed_transfer_checked,
        => {
            try vault_source.expect(.{ .writable = true });
            if (!sol.pubkey.pubkeyEq(pda_state.owner(), program_id)) return error.IncorrectProgramId;
            const state = try sol.TypedAccount(PdaState).bind(pda_state);
            const bump_seed = [_]u8{state.read().bump};
            return switch (tag) {
                .double_mixed_transfer_checked => processDoubleMixedTransferChecked(
                    token_program,
                    user_source,
                    mint,
                    destination_a,
                    destination_b,
                    user_authority,
                    vault_source,
                    pda_state,
                    args,
                    .{ "vault", &bump_seed },
                ),
                .batch_mixed_transfer_checked => processBatchMixedTransferChecked(
                    token_program,
                    user_source,
                    mint,
                    destination_a,
                    destination_b,
                    user_authority,
                    vault_source,
                    pda_state,
                    args,
                    .{ "vault", &bump_seed },
                ),
                .batch_prepared_mixed_transfer_checked => processBatchPreparedMixedTransferChecked(
                    token_program,
                    user_source,
                    mint,
                    destination_a,
                    destination_b,
                    user_authority,
                    vault_source,
                    pda_state,
                    args,
                    .{ "vault", &bump_seed },
                ),
                else => unreachable,
            };
        },
        else => unreachable,
    }
}

fn transferEntry(
    source: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    metas: *spl_token.instruction.metasArray(spl_token.instruction.transfer_spec),
    data: *spl_token.instruction.dataArray(spl_token.instruction.transfer_spec),
) BatchEntry {
    return spl_token.instruction.asBatchEntry(
        spl_token.instruction.transfer(
            source,
            destination,
            authority,
            amount,
            metas,
            data,
        ),
    );
}

fn transferCheckedEntry(
    source: *const Pubkey,
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    decimals: u8,
    metas: *spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec),
    data: *spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec),
) BatchEntry {
    return spl_token.instruction.asBatchEntry(
        spl_token.instruction.transferChecked(
            source,
            mint,
            destination,
            authority,
            amount,
            decimals,
            metas,
            data,
        ),
    );
}

fn processDoubleTransfer(
    token_program: AccountInfo,
    source: AccountInfo,
    destination_a: AccountInfo,
    destination_b: AccountInfo,
    authority: AccountInfo,
    args: TransferArgsReader,
) !void {
    try spl_token.cpi.transfer(
        token_program.toCpiInfo(),
        source.toCpiInfo(),
        destination_a.toCpiInfo(),
        authority.toCpiInfo(),
        args.get(.amount_a),
    );
    try spl_token.cpi.transfer(
        token_program.toCpiInfo(),
        source.toCpiInfo(),
        destination_b.toCpiInfo(),
        authority.toCpiInfo(),
        args.get(.amount_b),
    );
}

fn processBatchTransfer(
    token_program: AccountInfo,
    source: AccountInfo,
    destination_a: AccountInfo,
    destination_b: AccountInfo,
    authority: AccountInfo,
    args: TransferArgsReader,
) !void {
    var child_a_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_spec) = undefined;
    var child_a_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_spec) = undefined;
    const child_a = transferEntry(
        source.key(),
        destination_a.key(),
        authority.key(),
        args.get(.amount_a),
        &child_a_metas,
        &child_a_data,
    );

    var child_b_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_spec) = undefined;
    var child_b_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_spec) = undefined;
    const child_b = transferEntry(
        source.key(),
        destination_b.key(),
        authority.key(),
        args.get(.amount_b),
        &child_b_metas,
        &child_b_data,
    );

    const entries = [_]BatchEntry{ child_a, child_b };
    var batch_metas: [spl_token.instruction.transfer_spec.accounts_len * entries.len]sol.cpi.AccountMeta = undefined;
    var batch_data: [1 + entries.len * (2 + spl_token.instruction.transfer_spec.data_len)]u8 = undefined;
    var invoke_accounts: [spl_token.instruction.transfer_spec.accounts_len * entries.len + 1]sol.CpiAccountInfo = undefined;

    try spl_token.cpi.batch(
        token_program.toCpiInfo(),
        &entries,
        &.{
            source.toCpiInfo(),
            destination_a.toCpiInfo(),
            authority.toCpiInfo(),
            source.toCpiInfo(),
            destination_b.toCpiInfo(),
            authority.toCpiInfo(),
        },
        invoke_accounts[0..],
        batch_metas[0..],
        batch_data[0..],
    );
}

fn processBatchPreparedTransfer(
    token_program: AccountInfo,
    source: AccountInfo,
    destination_a: AccountInfo,
    destination_b: AccountInfo,
    authority: AccountInfo,
    args: TransferArgsReader,
) !void {
    var child_a_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_spec) = undefined;
    var child_a_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_spec) = undefined;
    const child_a = transferEntry(
        source.key(),
        destination_a.key(),
        authority.key(),
        args.get(.amount_a),
        &child_a_metas,
        &child_a_data,
    );

    var child_b_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_spec) = undefined;
    var child_b_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_spec) = undefined;
    const child_b = transferEntry(
        source.key(),
        destination_b.key(),
        authority.key(),
        args.get(.amount_b),
        &child_b_metas,
        &child_b_data,
    );

    const entries = [_]BatchEntry{ child_a, child_b };
    var batch_metas: [spl_token.instruction.transfer_spec.accounts_len * entries.len]sol.cpi.AccountMeta = undefined;
    var batch_data: [1 + entries.len * (2 + spl_token.instruction.transfer_spec.data_len)]u8 = undefined;

    try spl_token.cpi.batchPrepared(
        token_program.toCpiInfo(),
        &entries,
        &.{
            source.toCpiInfo(),
            destination_a.toCpiInfo(),
            authority.toCpiInfo(),
            source.toCpiInfo(),
            destination_b.toCpiInfo(),
            authority.toCpiInfo(),
            token_program.toCpiInfo(),
        },
        batch_metas[0..],
        batch_data[0..],
    );
}

fn processDoubleTransferChecked(
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

fn processBatchTransferChecked(
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
    const child_a = transferCheckedEntry(
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
    const child_b = transferCheckedEntry(
        source.key(),
        mint.key(),
        destination_b.key(),
        authority.key(),
        args.get(.amount_b),
        args.get(.decimals),
        &child_b_metas,
        &child_b_data,
    );

    const entries = [_]BatchEntry{ child_a, child_b };
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

fn processBatchPreparedTransferChecked(
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
    const child_a = transferCheckedEntry(
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
    const child_b = transferCheckedEntry(
        source.key(),
        mint.key(),
        destination_b.key(),
        authority.key(),
        args.get(.amount_b),
        args.get(.decimals),
        &child_b_metas,
        &child_b_data,
    );

    const entries = [_]BatchEntry{ child_a, child_b };
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

fn processDoubleMixedTransferChecked(
    token_program: AccountInfo,
    user_source: AccountInfo,
    mint: AccountInfo,
    destination_a: AccountInfo,
    destination_b: AccountInfo,
    user_authority: AccountInfo,
    vault_source: AccountInfo,
    pda_state: AccountInfo,
    args: TransferArgsReader,
    signer_seeds: anytype,
) !void {
    try spl_token.cpi.transferChecked(
        token_program.toCpiInfo(),
        user_source.toCpiInfo(),
        mint.toCpiInfo(),
        destination_a.toCpiInfo(),
        user_authority.toCpiInfo(),
        args.get(.amount_a),
        args.get(.decimals),
    );
    try spl_token.cpi.transferCheckedSignedSingle(
        token_program.toCpiInfo(),
        vault_source.toCpiInfo(),
        mint.toCpiInfo(),
        destination_b.toCpiInfo(),
        pda_state.toCpiInfo(),
        args.get(.amount_b),
        args.get(.decimals),
        signer_seeds,
    );
}

fn processBatchMixedTransferChecked(
    token_program: AccountInfo,
    user_source: AccountInfo,
    mint: AccountInfo,
    destination_a: AccountInfo,
    destination_b: AccountInfo,
    user_authority: AccountInfo,
    vault_source: AccountInfo,
    pda_state: AccountInfo,
    args: TransferArgsReader,
    signer_seeds: anytype,
) !void {
    var child_a_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_a_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_a = transferCheckedEntry(
        user_source.key(),
        mint.key(),
        destination_a.key(),
        user_authority.key(),
        args.get(.amount_a),
        args.get(.decimals),
        &child_a_metas,
        &child_a_data,
    );

    var child_b_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_b_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_b = transferCheckedEntry(
        vault_source.key(),
        mint.key(),
        destination_b.key(),
        pda_state.key(),
        args.get(.amount_b),
        args.get(.decimals),
        &child_b_metas,
        &child_b_data,
    );

    const entries = [_]BatchEntry{ child_a, child_b };
    var batch_metas: [spl_token.instruction.transfer_checked_spec.accounts_len * entries.len]sol.cpi.AccountMeta = undefined;
    var batch_data: [1 + entries.len * (2 + spl_token.instruction.transfer_checked_spec.data_len)]u8 = undefined;
    var invoke_accounts: [spl_token.instruction.transfer_checked_spec.accounts_len * entries.len + 1]sol.CpiAccountInfo = undefined;

    try spl_token.cpi.batchSignedSingle(
        token_program.toCpiInfo(),
        &entries,
        &.{
            user_source.toCpiInfo(),
            mint.toCpiInfo(),
            destination_a.toCpiInfo(),
            user_authority.toCpiInfo(),
            vault_source.toCpiInfo(),
            mint.toCpiInfo(),
            destination_b.toCpiInfo(),
            pda_state.toCpiInfo(),
        },
        invoke_accounts[0..],
        batch_metas[0..],
        batch_data[0..],
        signer_seeds,
    );
}

fn processBatchPreparedMixedTransferChecked(
    token_program: AccountInfo,
    user_source: AccountInfo,
    mint: AccountInfo,
    destination_a: AccountInfo,
    destination_b: AccountInfo,
    user_authority: AccountInfo,
    vault_source: AccountInfo,
    pda_state: AccountInfo,
    args: TransferArgsReader,
    signer_seeds: anytype,
) !void {
    var child_a_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_a_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_a = transferCheckedEntry(
        user_source.key(),
        mint.key(),
        destination_a.key(),
        user_authority.key(),
        args.get(.amount_a),
        args.get(.decimals),
        &child_a_metas,
        &child_a_data,
    );

    var child_b_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_b_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_b = transferCheckedEntry(
        vault_source.key(),
        mint.key(),
        destination_b.key(),
        pda_state.key(),
        args.get(.amount_b),
        args.get(.decimals),
        &child_b_metas,
        &child_b_data,
    );

    const entries = [_]BatchEntry{ child_a, child_b };
    var batch_metas: [spl_token.instruction.transfer_checked_spec.accounts_len * entries.len]sol.cpi.AccountMeta = undefined;
    var batch_data: [1 + entries.len * (2 + spl_token.instruction.transfer_checked_spec.data_len)]u8 = undefined;

    try spl_token.cpi.batchPreparedSignedSingle(
        token_program.toCpiInfo(),
        &entries,
        &.{
            user_source.toCpiInfo(),
            mint.toCpiInfo(),
            destination_a.toCpiInfo(),
            user_authority.toCpiInfo(),
            vault_source.toCpiInfo(),
            mint.toCpiInfo(),
            destination_b.toCpiInfo(),
            pda_state.toCpiInfo(),
            token_program.toCpiInfo(),
        },
        batch_metas[0..],
        batch_data[0..],
        signer_seeds,
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.programEntrypoint(9, process)(input);
}
