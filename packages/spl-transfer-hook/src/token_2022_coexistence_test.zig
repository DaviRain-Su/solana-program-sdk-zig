const std = @import("std");
const sol = @import("solana_program_sdk");
const spl_transfer_hook = @import("spl_transfer_hook");
const spl_token_2022 = @import("spl_token_2022");

const Pubkey = sol.Pubkey;
const AccountMeta = sol.cpi.AccountMeta;
const AccountKeyData = spl_transfer_hook.AccountKeyData;
const ExtraAccountMeta = spl_transfer_hook.meta.ExtraAccountMeta;

fn writeRecord(dst: []u8, extension_type: u16, value: []const u8) usize {
    std.mem.writeInt(u16, dst[0..2], extension_type, .little);
    std.mem.writeInt(u16, dst[2..4], @intCast(value.len), .little);
    @memcpy(dst[4 .. 4 + value.len], value);
    return 4 + value.len;
}

fn writeExecuteExtraAccountMetaList(extra_account_metas: []const ExtraAccountMeta, dst: []u8) void {
    const records_len = extra_account_metas.len * spl_transfer_hook.meta.EXTRA_ACCOUNT_META_LEN;
    const value_len = @sizeOf(u32) + records_len;
    std.debug.assert(dst.len == sol.DISCRIMINATOR_LEN + @sizeOf(u32) + value_len);

    @memcpy(dst[0..sol.DISCRIMINATOR_LEN], &spl_transfer_hook.instruction.EXECUTE_DISCRIMINATOR);
    std.mem.writeInt(u32, dst[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u32)], @intCast(value_len), .little);
    std.mem.writeInt(u32, dst[12..16], @intCast(extra_account_metas.len), .little);

    var cursor: usize = 16;
    for (extra_account_metas) |extra_account_meta| {
        extra_account_meta.write(dst[cursor..][0..spl_transfer_hook.meta.EXTRA_ACCOUNT_META_LEN]);
        cursor += spl_transfer_hook.meta.EXTRA_ACCOUNT_META_LEN;
    }
}

fn TestAccount(comptime data_len: usize) type {
    return extern struct {
        account: sol.Account,
        data: [data_len]u8,

        const Init = struct {
            key: Pubkey,
            owner: Pubkey,
            is_signer: bool = false,
            is_writable: bool = false,
            is_executable: bool = false,
            data: [data_len]u8 = .{0} ** data_len,
        };

        fn init(params: Init) @This() {
            return .{
                .account = .{
                    .borrow_state = 0xff,
                    .is_signer = @intFromBool(params.is_signer),
                    .is_writable = @intFromBool(params.is_writable),
                    .is_executable = @intFromBool(params.is_executable),
                    ._padding = .{0} ** 4,
                    .key = params.key,
                    .owner = params.owner,
                    .lamports = 0,
                    .data_len = data_len,
                },
                .data = params.data,
            };
        }

        fn info(self: *@This()) sol.AccountInfo {
            return .{ .raw = &self.account };
        }
    };
}

test "Token-2022 transfer-hook fixtures coexist with spl_transfer_hook validation helpers" {
    const mint_key: Pubkey = .{0x33} ** 32;
    const hook_authority: Pubkey = .{0x44} ** 32;
    const hook_program_id: Pubkey = .{0x55} ** 32;
    const source_key: Pubkey = .{0x66} ** 32;
    const destination_key: Pubkey = .{0x77} ** 32;
    const authority_key: Pubkey = .{0x88} ** 32;
    const extra_key: Pubkey = .{0x99} ** 32;

    var mint = [_]u8{0} ** 256;
    mint[spl_token_2022.ACCOUNT_TYPE_OFFSET] = @intFromEnum(spl_token_2022.AccountType.mint);
    var hook_payload = [_]u8{0} ** spl_token_2022.extension.TransferHookView.PAYLOAD_LEN;
    @memcpy(hook_payload[0..32], &hook_authority);
    @memcpy(hook_payload[32..64], &hook_program_id);
    const mint_len = spl_token_2022.TLV_START_OFFSET + writeRecord(
        mint[spl_token_2022.TLV_START_OFFSET..],
        @intFromEnum(spl_token_2022.ExtensionType.transfer_hook),
        &hook_payload,
    );

    var account = [_]u8{0} ** 192;
    @memset(account[0..spl_token_2022.ACCOUNT_BASE_LEN], 0xAB);
    account[spl_token_2022.ACCOUNT_TYPE_OFFSET] = @intFromEnum(spl_token_2022.AccountType.account);
    const hook_account_payload = [_]u8{1};
    const account_len = spl_token_2022.TLV_START_OFFSET + writeRecord(
        account[spl_token_2022.TLV_START_OFFSET..],
        @intFromEnum(spl_token_2022.ExtensionType.transfer_hook_account),
        &hook_account_payload,
    );

    const parsed_mint = try spl_token_2022.parseMint(mint[0..mint_len]);
    try std.testing.expectEqual(spl_token_2022.AccountType.mint, parsed_mint.kind);
    const hook_view = try spl_token_2022.extension.getTransferHook(mint[0..mint_len]);
    const parsed_hook_program_id: Pubkey = hook_view.program_id;
    try std.testing.expectEqualSlices(u8, &hook_authority, std.mem.asBytes(&hook_view.authority));
    try std.testing.expectEqualSlices(u8, &hook_program_id, std.mem.asBytes(&hook_view.program_id));

    const parsed_account = try spl_token_2022.parseAccount(account[0..account_len]);
    try std.testing.expectEqual(spl_token_2022.AccountType.account, parsed_account.kind);
    const hook_account_view = try spl_token_2022.extension.getTransferHookAccount(account[0..account_len]);
    try std.testing.expectEqual(@as(u8, 1), hook_account_view.transferring);

    const validation_address = spl_transfer_hook.findValidationAddress(&mint_key, &parsed_hook_program_id);
    const extra_account_meta = ExtraAccountMeta.fixed(&extra_key, false, true);
    var validation_data = [_]u8{0} ** 51;
    writeExecuteExtraAccountMetaList(&.{extra_account_meta}, validation_data[0..]);

    var validation_account = TestAccount(validation_data.len).init(.{
        .key = validation_address.address,
        .owner = parsed_hook_program_id,
        .data = validation_data,
    });
    var extra_account = TestAccount(1).init(.{
        .key = extra_key,
        .owner = hook_program_id,
        .is_writable = true,
    });

    const base_accounts = [_]AccountKeyData{
        .{ .key = &source_key, .data = null },
        .{ .key = &mint_key, .data = mint[0..mint_len] },
        .{ .key = &destination_key, .data = account[0..account_len] },
        .{ .key = &authority_key, .data = null },
        .{ .key = validation_account.info().key(), .data = validation_account.info().data() },
    };

    var execute_metas: spl_transfer_hook.instruction.ExecuteMetas = undefined;
    var execute_data: spl_transfer_hook.instruction.ExecuteData = undefined;
    const execute_ix = spl_transfer_hook.instruction.execute(
        &parsed_hook_program_id,
        &source_key,
        &mint_key,
        &destination_key,
        &authority_key,
        42,
        &execute_metas,
        &execute_data,
    );
    try std.testing.expectEqual(@as(usize, 4), execute_ix.accounts.len);
    try std.testing.expectEqual(@as(usize, 16), execute_ix.data.len);

    var resolved_metas: [1]AccountMeta = undefined;
    var resolved_keys: [1]Pubkey = undefined;
    const extra_accounts = [_]sol.AccountInfo{extra_account.info()};
    const resolved = try spl_transfer_hook.validateExecuteExtraAccountInfos(
        validation_account.info(),
        &mint_key,
        &parsed_hook_program_id,
        execute_ix.data,
        base_accounts[0..],
        extra_accounts[0..],
        resolved_metas[0..],
        resolved_keys[0..],
    );

    try std.testing.expectEqual(@as(usize, 1), resolved.len);
    try std.testing.expectEqualSlices(u8, &extra_key, resolved[0].pubkey[0..]);
    try std.testing.expectEqual(@as(u8, 0), resolved[0].is_signer);
    try std.testing.expectEqual(@as(u8, 1), resolved[0].is_writable);
}

test "cross-package fixture stays parser and interface scoped without off-chain expansion" {
    try std.testing.expect(@hasDecl(spl_token_2022, "parseMint"));
    try std.testing.expect(@hasDecl(spl_token_2022.extension, "getTransferHook"));
    try std.testing.expect(@hasDecl(spl_token_2022, "instruction"));
    try std.testing.expect(@hasDecl(spl_token_2022.instruction, "initializeMint2"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "findValidationAddress"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "validateExecuteExtraAccountInfos"));

    try std.testing.expect(!@hasDecl(spl_token_2022, "cpi"));
    try std.testing.expect(!@hasDecl(spl_token_2022, "rpc"));
    try std.testing.expect(!@hasDecl(spl_token_2022, "client"));
    try std.testing.expect(!@hasDecl(spl_token_2022, "keypair"));
    try std.testing.expect(!@hasDecl(spl_token_2022, "transaction"));

    try std.testing.expect(!@hasDecl(spl_transfer_hook, "PROGRAM_ID"));
    try std.testing.expect(!@hasDecl(spl_transfer_hook, "rpc"));
    try std.testing.expect(!@hasDecl(spl_transfer_hook, "client"));
    try std.testing.expect(!@hasDecl(spl_transfer_hook, "keypair"));
    try std.testing.expect(!@hasDecl(spl_transfer_hook, "searcher"));
    try std.testing.expect(!@hasDecl(spl_transfer_hook, "transaction"));
}
