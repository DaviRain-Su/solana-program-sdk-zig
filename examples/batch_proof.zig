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
//!   10. double_swap_checked                  [tag, amount_in:u64, amount_out:u64, decimals:u8]
//!   11. batch_swap_checked                   [tag, amount_in:u64, amount_out:u64, decimals:u8]
//!   12. batch_prepared_swap_checked          [tag, amount_in:u64, amount_out:u64, decimals:u8]
//!   13. init_router                          [tag, router_bump:u8]
//!   14. double_router_swap_checked           [tag, amount_in:u64, amount_out:u64, decimals:u8]
//!   15. batch_router_swap_checked            [tag, amount_in:u64, amount_out:u64, decimals:u8]
//!   16. batch_prepared_router_swap_checked   [tag, amount_in:u64, amount_out:u64, decimals:u8]
//!
//! Fixed account order (11 accounts):
//!   0. token_program              — readonly
//!   1. user_source / mint_a       — writable for transfer paths, readonly for router init
//!   2. mint / vault_a             — readonly for transfer paths, writable for router init inputs
//!   3. destination_a / mint_b     — writable for transfer paths, readonly for router init inputs
//!   4. destination_b / vault_b    — writable
//!   5. user_authority / payer     — signer
//!   6. vault_source / vault_b     — writable for mixed / swap paths
//!   7. pda_state                  — writable for `init_pda`, readonly otherwise
//!   8. mint_b / spare             — readonly
//!   9. router_state / spare       — writable for router init / router paths
//!   10. system_program / spare    — readonly

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
    double_swap_checked = 10,
    batch_swap_checked = 11,
    batch_prepared_swap_checked = 12,
    init_router = 13,
    double_router_swap_checked = 14,
    batch_router_swap_checked = 15,
    batch_prepared_router_swap_checked = 16,
};

const TransferArgs = extern struct {
    amount_a: u64 align(1),
    amount_b: u64 align(1),
    decimals: u8,
};

const PdaState = extern struct {
    bump: u8,
};

const RouterState = extern struct {
    bump: u8,
    signer: Pubkey,
    mint_a: Pubkey,
    vault_a: Pubkey,
    mint_b: Pubkey,
    vault_b: Pubkey,
    swap_count: u64 align(1),
    total_in: u64 align(1),
    total_out: u64 align(1),
};

const AccountInfo = sol.AccountInfo;
const Pubkey = sol.Pubkey;
const BatchEntry = spl_token.instruction.BatchEntry;
const TransferArgsReader = sol.instruction.IxDataReader(TransferArgs);
const RouterAccount = sol.TypedAccount(RouterState);

fn process(
    accounts: *const [11]AccountInfo,
    data: []const u8,
    program_id: *const Pubkey,
) sol.ProgramResult {
    const tag = sol.instruction.parseTag(Ix, data) orelse return error.InvalidInstructionData;

    return switch (tag) {
        .init_pda => processInitPda(accounts, data, program_id),
        .init_router => processInitRouter(accounts, data, program_id),
        else => blk: {
            const args = TransferArgsReader.bind(data[1..]) orelse return error.InvalidInstructionData;
            break :blk processTransfer(accounts, args, tag, program_id);
        },
    };
}

fn processInitPda(
    accounts: *const [11]AccountInfo,
    data: []const u8,
    program_id: *const Pubkey,
) !void {
    const payer = accounts[5];
    const pda_state = accounts[7];
    const system_program = accounts[10];

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

fn processInitRouter(
    accounts: *const [11]AccountInfo,
    data: []const u8,
    program_id: *const Pubkey,
) !void {
    const mint_a = accounts[1];
    const vault_a = accounts[2];
    const mint_b = accounts[3];
    const vault_b = accounts[4];
    const pda_state = accounts[7];
    const router_state = accounts[9];

    try router_state.expect(.{ .writable = true });
    if (!sol.pubkey.pubkeyEq(pda_state.owner(), program_id)) return error.IncorrectProgramId;
    if (!sol.pubkey.pubkeyEq(router_state.owner(), program_id)) return error.IncorrectProgramId;

    const router_bump = sol.instruction.tryReadUnaligned(u8, data, 1) orelse
        return error.InvalidInstructionData;

    _ = try RouterAccount.initialize(router_state, .{
        .bump = router_bump,
        .signer = pda_state.key().*,
        .mint_a = mint_a.key().*,
        .vault_a = vault_a.key().*,
        .mint_b = mint_b.key().*,
        .vault_b = vault_b.key().*,
        .swap_count = 0,
        .total_in = 0,
        .total_out = 0,
    });
}

fn processTransfer(
    accounts: *const [11]AccountInfo,
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
    const mint_b = accounts[8];
    const router_state = accounts[9];

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
        .double_swap_checked,
        .batch_swap_checked,
        .batch_prepared_swap_checked,
        .double_router_swap_checked,
        .batch_router_swap_checked,
        .batch_prepared_router_swap_checked,
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
                .double_swap_checked => processDoubleSwapChecked(
                    token_program,
                    user_source,
                    mint,
                    destination_a,
                    destination_b,
                    user_authority,
                    vault_source,
                    pda_state,
                    mint_b,
                    args,
                    .{ "vault", &bump_seed },
                ),
                .batch_swap_checked => processBatchSwapChecked(
                    token_program,
                    user_source,
                    mint,
                    destination_a,
                    destination_b,
                    user_authority,
                    vault_source,
                    pda_state,
                    mint_b,
                    args,
                    .{ "vault", &bump_seed },
                ),
                .batch_prepared_swap_checked => processBatchPreparedSwapChecked(
                    token_program,
                    user_source,
                    mint,
                    destination_a,
                    destination_b,
                    user_authority,
                    vault_source,
                    pda_state,
                    mint_b,
                    args,
                    .{ "vault", &bump_seed },
                ),
                .double_router_swap_checked,
                .batch_router_swap_checked,
                .batch_prepared_router_swap_checked,
                => {
                    try router_state.expect(.{ .writable = true });
                    if (!sol.pubkey.pubkeyEq(router_state.owner(), program_id)) return error.IncorrectProgramId;
                    const router = try RouterAccount.bind(router_state);
                    try validateRouterSwapConfig(router.read(), pda_state.key(), mint.key(), destination_a.key(), mint_b.key(), vault_source.key());
                    return switch (tag) {
                        .double_router_swap_checked => processDoubleRouterSwapChecked(
                            router,
                            token_program,
                            user_source,
                            mint,
                            destination_a,
                            destination_b,
                            user_authority,
                            vault_source,
                            pda_state,
                            mint_b,
                            args,
                            .{ "vault", &bump_seed },
                        ),
                        .batch_router_swap_checked => processBatchRouterSwapChecked(
                            router,
                            token_program,
                            user_source,
                            mint,
                            destination_a,
                            destination_b,
                            user_authority,
                            vault_source,
                            pda_state,
                            mint_b,
                            args,
                            .{ "vault", &bump_seed },
                        ),
                        .batch_prepared_router_swap_checked => processBatchPreparedRouterSwapChecked(
                            router,
                            token_program,
                            user_source,
                            mint,
                            destination_a,
                            destination_b,
                            user_authority,
                            vault_source,
                            pda_state,
                            mint_b,
                            args,
                            .{ "vault", &bump_seed },
                        ),
                        else => unreachable,
                    };
                },
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

fn processDoubleSwapChecked(
    token_program: AccountInfo,
    user_source_a: AccountInfo,
    mint_a: AccountInfo,
    vault_a: AccountInfo,
    user_destination_b: AccountInfo,
    user_authority: AccountInfo,
    vault_b: AccountInfo,
    pda_state: AccountInfo,
    mint_b: AccountInfo,
    args: TransferArgsReader,
    signer_seeds: anytype,
) !void {
    try spl_token.cpi.transferChecked(
        token_program.toCpiInfo(),
        user_source_a.toCpiInfo(),
        mint_a.toCpiInfo(),
        vault_a.toCpiInfo(),
        user_authority.toCpiInfo(),
        args.get(.amount_a),
        args.get(.decimals),
    );
    try spl_token.cpi.transferCheckedSignedSingle(
        token_program.toCpiInfo(),
        vault_b.toCpiInfo(),
        mint_b.toCpiInfo(),
        user_destination_b.toCpiInfo(),
        pda_state.toCpiInfo(),
        args.get(.amount_b),
        args.get(.decimals),
        signer_seeds,
    );
}

fn processBatchSwapChecked(
    token_program: AccountInfo,
    user_source_a: AccountInfo,
    mint_a: AccountInfo,
    vault_a: AccountInfo,
    user_destination_b: AccountInfo,
    user_authority: AccountInfo,
    vault_b: AccountInfo,
    pda_state: AccountInfo,
    mint_b: AccountInfo,
    args: TransferArgsReader,
    signer_seeds: anytype,
) !void {
    var child_a_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_a_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_a = transferCheckedEntry(
        user_source_a.key(),
        mint_a.key(),
        vault_a.key(),
        user_authority.key(),
        args.get(.amount_a),
        args.get(.decimals),
        &child_a_metas,
        &child_a_data,
    );

    var child_b_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_b_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_b = transferCheckedEntry(
        vault_b.key(),
        mint_b.key(),
        user_destination_b.key(),
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
            user_source_a.toCpiInfo(),
            mint_a.toCpiInfo(),
            vault_a.toCpiInfo(),
            user_authority.toCpiInfo(),
            vault_b.toCpiInfo(),
            mint_b.toCpiInfo(),
            user_destination_b.toCpiInfo(),
            pda_state.toCpiInfo(),
        },
        invoke_accounts[0..],
        batch_metas[0..],
        batch_data[0..],
        signer_seeds,
    );
}

fn processBatchPreparedSwapChecked(
    token_program: AccountInfo,
    user_source_a: AccountInfo,
    mint_a: AccountInfo,
    vault_a: AccountInfo,
    user_destination_b: AccountInfo,
    user_authority: AccountInfo,
    vault_b: AccountInfo,
    pda_state: AccountInfo,
    mint_b: AccountInfo,
    args: TransferArgsReader,
    signer_seeds: anytype,
) !void {
    var child_a_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_a_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_a = transferCheckedEntry(
        user_source_a.key(),
        mint_a.key(),
        vault_a.key(),
        user_authority.key(),
        args.get(.amount_a),
        args.get(.decimals),
        &child_a_metas,
        &child_a_data,
    );

    var child_b_metas: spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec) = undefined;
    var child_b_data: spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec) = undefined;
    const child_b = transferCheckedEntry(
        vault_b.key(),
        mint_b.key(),
        user_destination_b.key(),
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
            user_source_a.toCpiInfo(),
            mint_a.toCpiInfo(),
            vault_a.toCpiInfo(),
            user_authority.toCpiInfo(),
            vault_b.toCpiInfo(),
            mint_b.toCpiInfo(),
            user_destination_b.toCpiInfo(),
            pda_state.toCpiInfo(),
            token_program.toCpiInfo(),
        },
        batch_metas[0..],
        batch_data[0..],
        signer_seeds,
    );
}

fn validateRouterSwapConfig(
    router: *align(1) const RouterState,
    signer: *const Pubkey,
    mint_a: *const Pubkey,
    vault_a: *const Pubkey,
    mint_b: *const Pubkey,
    vault_b: *const Pubkey,
) !void {
    if (!sol.pubkey.pubkeyEq(&router.signer, signer)) return error.IncorrectAuthority;
    if (!sol.pubkey.pubkeyEq(&router.mint_a, mint_a)) return error.InvalidArgument;
    if (!sol.pubkey.pubkeyEq(&router.vault_a, vault_a)) return error.InvalidArgument;
    if (!sol.pubkey.pubkeyEq(&router.mint_b, mint_b)) return error.InvalidArgument;
    if (!sol.pubkey.pubkeyEq(&router.vault_b, vault_b)) return error.InvalidArgument;
}

fn recordRouterSwap(router: RouterAccount, args: TransferArgsReader) !void {
    if (args.get(.amount_b) > args.get(.amount_a)) return error.InvalidArgument;
    router.write().swap_count = sol.math.tryAdd(router.read().swap_count, 1) orelse return error.ArithmeticOverflow;
    router.write().total_in = sol.math.tryAdd(router.read().total_in, args.get(.amount_a)) orelse return error.ArithmeticOverflow;
    router.write().total_out = sol.math.tryAdd(router.read().total_out, args.get(.amount_b)) orelse return error.ArithmeticOverflow;
}

fn processDoubleRouterSwapChecked(
    router: RouterAccount,
    token_program: AccountInfo,
    user_source_a: AccountInfo,
    mint_a: AccountInfo,
    vault_a: AccountInfo,
    user_destination_b: AccountInfo,
    user_authority: AccountInfo,
    vault_b: AccountInfo,
    pda_state: AccountInfo,
    mint_b: AccountInfo,
    args: TransferArgsReader,
    signer_seeds: anytype,
) !void {
    try recordRouterSwap(router, args);
    try processDoubleSwapChecked(
        token_program,
        user_source_a,
        mint_a,
        vault_a,
        user_destination_b,
        user_authority,
        vault_b,
        pda_state,
        mint_b,
        args,
        signer_seeds,
    );
}

fn processBatchRouterSwapChecked(
    router: RouterAccount,
    token_program: AccountInfo,
    user_source_a: AccountInfo,
    mint_a: AccountInfo,
    vault_a: AccountInfo,
    user_destination_b: AccountInfo,
    user_authority: AccountInfo,
    vault_b: AccountInfo,
    pda_state: AccountInfo,
    mint_b: AccountInfo,
    args: TransferArgsReader,
    signer_seeds: anytype,
) !void {
    try recordRouterSwap(router, args);
    try processBatchSwapChecked(
        token_program,
        user_source_a,
        mint_a,
        vault_a,
        user_destination_b,
        user_authority,
        vault_b,
        pda_state,
        mint_b,
        args,
        signer_seeds,
    );
}

fn processBatchPreparedRouterSwapChecked(
    router: RouterAccount,
    token_program: AccountInfo,
    user_source_a: AccountInfo,
    mint_a: AccountInfo,
    vault_a: AccountInfo,
    user_destination_b: AccountInfo,
    user_authority: AccountInfo,
    vault_b: AccountInfo,
    pda_state: AccountInfo,
    mint_b: AccountInfo,
    args: TransferArgsReader,
    signer_seeds: anytype,
) !void {
    try recordRouterSwap(router, args);
    try processBatchPreparedSwapChecked(
        token_program,
        user_source_a,
        mint_a,
        vault_a,
        user_destination_b,
        user_authority,
        vault_b,
        pda_state,
        mint_b,
        args,
        signer_seeds,
    );
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.programEntrypoint(11, process)(input);
}
