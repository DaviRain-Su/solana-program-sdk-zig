//! `spl-token` reference on-chain example.
//!
//! Exercises the package's CPI surface against the **real** SPL
//! Token program loaded by Mollusk in
//! `program-test/tests/spl_token.rs`.
//!
//! Stable route table:
//!   tag = 0   mintTo                    data: tag + amount
//!   tag = 1   transferChecked           data: tag + amount + decimals
//!   tag = 2   burn                      data: tag + amount
//!   tag = 3   closeAccount              data: tag
//!   tag = 4   approve                   data: tag + amount
//!   tag = 5   approveSigned             data: tag + amount + bump
//!   tag = 6   approveChecked            data: tag + amount + decimals
//!   tag = 7   approveCheckedSigned      data: tag + amount + decimals + bump
//!   tag = 8   revoke                    data: tag
//!   tag = 9   revokeSigned              data: tag + bump
//!   tag = 10  setAuthority              data: tag + authority_type + option + pubkey?
//!   tag = 11  setAuthoritySigned        data: tag + authority_type + option + pubkey? + bump
//!   tag = 12  freezeAccount             data: tag
//!   tag = 13  freezeAccountSigned       data: tag + bump
//!   tag = 14  thawAccount               data: tag
//!   tag = 15  thawAccountSigned         data: tag + bump
//!   tag = 16  initializeMultisig2       data: tag + threshold
//!   tag = 17  transferMultisig          data: tag + amount
//!   tag = 18  transferCheckedMultisig   data: tag + amount + decimals
//!   tag = 19  approveMultisig           data: tag + amount
//!   tag = 20  approveCheckedMultisig    data: tag + amount + decimals
//!   tag = 21  revokeMultisig            data: tag
//!   tag = 22  setAuthorityMultisig      data: tag + authority_type + option + pubkey?
//!   tag = 23  freezeAccountMultisig     data: tag
//!   tag = 24  thawAccountMultisig       data: tag
//!   tag = 25  mintToMultisig            data: tag + amount
//!   tag = 26  mintToCheckedMultisig     data: tag + amount + decimals
//!   tag = 27  burnMultisig              data: tag + amount
//!   tag = 28  burnCheckedMultisig       data: tag + amount + decimals
//!   tag = 29  closeAccountMultisig      data: tag
//!
//! Signed routes use a PDA authority derived from:
//!   seeds = ["authority", &[bump]]
//! where `bump` is the final payload byte.

const sol = @import("solana_program_sdk");
const spl_token = @import("spl_token");

pub const panic = sol.panic.Panic;

const Op = enum(u8) {
    mint_to = 0,
    transfer_checked = 1,
    burn = 2,
    close_account = 3,
    approve = 4,
    approve_signed = 5,
    approve_checked = 6,
    approve_checked_signed = 7,
    revoke = 8,
    revoke_signed = 9,
    set_authority = 10,
    set_authority_signed = 11,
    freeze_account = 12,
    freeze_account_signed = 13,
    thaw_account = 14,
    thaw_account_signed = 15,
    initialize_multisig2 = 16,
    transfer_multisig = 17,
    transfer_checked_multisig = 18,
    approve_multisig = 19,
    approve_checked_multisig = 20,
    revoke_multisig = 21,
    set_authority_multisig = 22,
    freeze_account_multisig = 23,
    thaw_account_multisig = 24,
    mint_to_multisig = 25,
    mint_to_checked_multisig = 26,
    burn_multisig = 27,
    burn_checked_multisig = 28,
    close_account_multisig = 29,
    _,
};

const SIGNED_AUTHORITY_SEED = "authority";

inline fn requireAccounts(ctx: *sol.entrypoint.InstructionContext, need: usize) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() < need)) {
        return error.NotEnoughAccountKeys;
    }
}

inline fn requireDataLen(data: []const u8, need: usize) sol.ProgramResult {
    if (sol.entrypoint.unlikely(data.len < need)) {
        return error.InvalidInstructionData;
    }
}

inline fn readAmount(data: []const u8) sol.ProgramError!u64 {
    try requireDataLen(data, 1 + @sizeOf(u64));
    return sol.instruction.tryReadUnaligned(u64, data, 1) orelse error.InvalidInstructionData;
}

inline fn readAmountDecimals(data: []const u8) sol.ProgramError!struct { amount: u64, decimals: u8 } {
    try requireDataLen(data, 1 + @sizeOf(u64) + 1);
    return .{
        .amount = sol.instruction.tryReadUnaligned(u64, data, 1) orelse return error.InvalidInstructionData,
        .decimals = data[9],
    };
}

inline fn readTrailingBump(data: []const u8, base_len: usize) sol.ProgramError!u8 {
    try requireDataLen(data, base_len + 1);
    return data[base_len];
}

fn readAuthorityType(data: []const u8) sol.ProgramError!spl_token.instruction.AuthorityType {
    try requireDataLen(data, 3);
    return switch (data[1]) {
        @intFromEnum(spl_token.instruction.AuthorityType.MintTokens) => .MintTokens,
        @intFromEnum(spl_token.instruction.AuthorityType.FreezeAccount) => .FreezeAccount,
        @intFromEnum(spl_token.instruction.AuthorityType.AccountOwner) => .AccountOwner,
        @intFromEnum(spl_token.instruction.AuthorityType.CloseAccount) => .CloseAccount,
        else => error.InvalidInstructionData,
    };
}

fn readSetAuthorityPayload(data: []const u8, signed: bool) sol.ProgramError!struct {
    authority_type: spl_token.instruction.AuthorityType,
    new_authority: ?*const sol.Pubkey,
    bump: ?u8,
} {
    const authority_type = try readAuthorityType(data);
    const option_tag = data[2];
    const bump_offset: usize = if (option_tag == 0) 3 else 35;

    switch (option_tag) {
        0 => {
            const bump = if (signed) try readTrailingBump(data, bump_offset) else null;
            return .{
                .authority_type = authority_type,
                .new_authority = null,
                .bump = bump,
            };
        },
        1 => {
            try requireDataLen(data, bump_offset + @intFromBool(signed));
            const authority_ptr: *const sol.Pubkey = @ptrCast(data.ptr + 3);
            const bump = if (signed) data[bump_offset] else null;
            return .{
                .authority_type = authority_type,
                .new_authority = authority_ptr,
                .bump = bump,
            };
        },
        else => return error.InvalidInstructionData,
    }
}

fn collectExtraAccounts(
    ctx: *sol.entrypoint.InstructionContext,
    fixed: usize,
    buf: *[spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo,
) sol.ProgramError![]const sol.CpiAccountInfo {
    try requireAccounts(ctx, fixed + 1);
    const extras = ctx.remainingAccounts() - fixed;
    if (extras < 1 or extras > spl_token.MULTISIG_SIGNER_MAX) {
        return error.InvalidArgument;
    }

    var i: usize = 0;
    while (i < extras) : (i += 1) {
        buf[i] = ctx.nextAccountUnchecked().toCpiInfo();
    }
    return buf[0..extras];
}

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    var probe = ctx.*;
    probe.skipAccounts(probe.remainingAccounts());
    const data = probe.instructionDataUnchecked();
    try requireDataLen(data, 1);
    const op: Op = @enumFromInt(data[0]);

    switch (op) {
        .mint_to => {
            try requireAccounts(ctx, 5);
            const token_program = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            _ = ctx.nextAccountUnchecked();
            const destination = ctx.nextAccountUnchecked();
            const authority = ctx.nextAccountUnchecked();
            const amount = try readAmount(data);
            try spl_token.cpi.mintTo(
                token_program.toCpiInfo(),
                mint.toCpiInfo(),
                destination.toCpiInfo(),
                authority.toCpiInfo(),
                amount,
            );
        },
        .transfer_checked => {
            try requireAccounts(ctx, 5);
            const token_program = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const destination = ctx.nextAccountUnchecked();
            const authority = ctx.nextAccountUnchecked();
            const args = try readAmountDecimals(data);
            try spl_token.cpi.transferChecked(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                mint.toCpiInfo(),
                destination.toCpiInfo(),
                authority.toCpiInfo(),
                args.amount,
                args.decimals,
            );
        },
        .burn => {
            try requireAccounts(ctx, 5);
            const token_program = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            _ = ctx.nextAccountUnchecked();
            const authority = ctx.nextAccountUnchecked();
            const amount = try readAmount(data);
            try spl_token.cpi.burn(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                mint.toCpiInfo(),
                authority.toCpiInfo(),
                amount,
            );
        },
        .close_account => {
            try requireAccounts(ctx, 5);
            const token_program = ctx.nextAccountUnchecked();
            _ = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const destination = ctx.nextAccountUnchecked();
            const authority = ctx.nextAccountUnchecked();
            try spl_token.cpi.closeAccount(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                destination.toCpiInfo(),
                authority.toCpiInfo(),
            );
        },
        .approve => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const delegate = ctx.nextAccountUnchecked();
            const owner = ctx.nextAccountUnchecked();
            try spl_token.cpi.approve(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                delegate.toCpiInfo(),
                owner.toCpiInfo(),
                try readAmount(data),
            );
        },
        .approve_signed => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const delegate = ctx.nextAccountUnchecked();
            const owner = ctx.nextAccountUnchecked();
            const amount = try readAmount(data);
            const bump = try readTrailingBump(data, 9);
            const bump_seed = [_]u8{bump};
            try spl_token.cpi.approveSignedSingle(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                delegate.toCpiInfo(),
                owner.toCpiInfo(),
                amount,
                .{ SIGNED_AUTHORITY_SEED, &bump_seed },
            );
        },
        .approve_checked => {
            try requireAccounts(ctx, 5);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const delegate = ctx.nextAccountUnchecked();
            const owner = ctx.nextAccountUnchecked();
            const args = try readAmountDecimals(data);
            try spl_token.cpi.approveChecked(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                mint.toCpiInfo(),
                delegate.toCpiInfo(),
                owner.toCpiInfo(),
                args.amount,
                args.decimals,
            );
        },
        .approve_checked_signed => {
            try requireAccounts(ctx, 5);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const delegate = ctx.nextAccountUnchecked();
            const owner = ctx.nextAccountUnchecked();
            const args = try readAmountDecimals(data);
            const bump = try readTrailingBump(data, 10);
            const bump_seed = [_]u8{bump};
            try spl_token.cpi.approveCheckedSignedSingle(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                mint.toCpiInfo(),
                delegate.toCpiInfo(),
                owner.toCpiInfo(),
                args.amount,
                args.decimals,
                .{ SIGNED_AUTHORITY_SEED, &bump_seed },
            );
        },
        .revoke => {
            try requireAccounts(ctx, 3);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const owner = ctx.nextAccountUnchecked();
            try spl_token.cpi.revoke(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                owner.toCpiInfo(),
            );
        },
        .revoke_signed => {
            try requireAccounts(ctx, 3);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const owner = ctx.nextAccountUnchecked();
            const bump = try readTrailingBump(data, 1);
            const bump_seed = [_]u8{bump};
            try spl_token.cpi.revokeSignedSingle(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                owner.toCpiInfo(),
                .{ SIGNED_AUTHORITY_SEED, &bump_seed },
            );
        },
        .set_authority => {
            try requireAccounts(ctx, 3);
            const token_program = ctx.nextAccountUnchecked();
            const target = ctx.nextAccountUnchecked();
            const current_authority = ctx.nextAccountUnchecked();
            const args = try readSetAuthorityPayload(data, false);
            try spl_token.cpi.setAuthority(
                token_program.toCpiInfo(),
                target.toCpiInfo(),
                current_authority.toCpiInfo(),
                args.authority_type,
                args.new_authority,
            );
        },
        .set_authority_signed => {
            try requireAccounts(ctx, 3);
            const token_program = ctx.nextAccountUnchecked();
            const target = ctx.nextAccountUnchecked();
            const current_authority = ctx.nextAccountUnchecked();
            const args = try readSetAuthorityPayload(data, true);
            const bump_seed = [_]u8{args.bump.?};
            try spl_token.cpi.setAuthoritySignedSingle(
                token_program.toCpiInfo(),
                target.toCpiInfo(),
                current_authority.toCpiInfo(),
                args.authority_type,
                args.new_authority,
                .{ SIGNED_AUTHORITY_SEED, &bump_seed },
            );
        },
        .freeze_account => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const account = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const freeze_authority = ctx.nextAccountUnchecked();
            try spl_token.cpi.freezeAccount(
                token_program.toCpiInfo(),
                account.toCpiInfo(),
                mint.toCpiInfo(),
                freeze_authority.toCpiInfo(),
            );
        },
        .freeze_account_signed => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const account = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const freeze_authority = ctx.nextAccountUnchecked();
            const bump = try readTrailingBump(data, 1);
            const bump_seed = [_]u8{bump};
            try spl_token.cpi.freezeAccountSignedSingle(
                token_program.toCpiInfo(),
                account.toCpiInfo(),
                mint.toCpiInfo(),
                freeze_authority.toCpiInfo(),
                .{ SIGNED_AUTHORITY_SEED, &bump_seed },
            );
        },
        .thaw_account => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const account = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const freeze_authority = ctx.nextAccountUnchecked();
            try spl_token.cpi.thawAccount(
                token_program.toCpiInfo(),
                account.toCpiInfo(),
                mint.toCpiInfo(),
                freeze_authority.toCpiInfo(),
            );
        },
        .thaw_account_signed => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const account = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const freeze_authority = ctx.nextAccountUnchecked();
            const bump = try readTrailingBump(data, 1);
            const bump_seed = [_]u8{bump};
            try spl_token.cpi.thawAccountSignedSingle(
                token_program.toCpiInfo(),
                account.toCpiInfo(),
                mint.toCpiInfo(),
                freeze_authority.toCpiInfo(),
                .{ SIGNED_AUTHORITY_SEED, &bump_seed },
            );
        },
        .initialize_multisig2 => {
            try requireAccounts(ctx, 3);
            const token_program = ctx.nextAccountUnchecked();
            const multisig = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 2, &signer_buf);
            try requireDataLen(data, 2);
            try spl_token.cpi.initializeMultisig2(
                token_program.toCpiInfo(),
                multisig.toCpiInfo(),
                signer_infos,
                data[1],
            );
        },
        .transfer_multisig => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const destination = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 4, &signer_buf);
            try spl_token.cpi.transferMultisig(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                destination.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
                try readAmount(data),
            );
        },
        .transfer_checked_multisig => {
            try requireAccounts(ctx, 5);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const destination = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 5, &signer_buf);
            const args = try readAmountDecimals(data);
            try spl_token.cpi.transferCheckedMultisig(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                mint.toCpiInfo(),
                destination.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
                args.amount,
                args.decimals,
            );
        },
        .approve_multisig => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const delegate = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 4, &signer_buf);
            try spl_token.cpi.approveMultisig(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                delegate.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
                try readAmount(data),
            );
        },
        .approve_checked_multisig => {
            try requireAccounts(ctx, 5);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const delegate = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 5, &signer_buf);
            const args = try readAmountDecimals(data);
            try spl_token.cpi.approveCheckedMultisig(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                mint.toCpiInfo(),
                delegate.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
                args.amount,
                args.decimals,
            );
        },
        .revoke_multisig => {
            try requireAccounts(ctx, 3);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 3, &signer_buf);
            try spl_token.cpi.revokeMultisig(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
            );
        },
        .set_authority_multisig => {
            try requireAccounts(ctx, 3);
            const token_program = ctx.nextAccountUnchecked();
            const target = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 3, &signer_buf);
            const args = try readSetAuthorityPayload(data, false);
            try spl_token.cpi.setAuthorityMultisig(
                token_program.toCpiInfo(),
                target.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
                args.authority_type,
                args.new_authority,
            );
        },
        .freeze_account_multisig => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const account = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 4, &signer_buf);
            try spl_token.cpi.freezeAccountMultisig(
                token_program.toCpiInfo(),
                account.toCpiInfo(),
                mint.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
            );
        },
        .thaw_account_multisig => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const account = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 4, &signer_buf);
            try spl_token.cpi.thawAccountMultisig(
                token_program.toCpiInfo(),
                account.toCpiInfo(),
                mint.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
            );
        },
        .mint_to_multisig => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const destination = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 4, &signer_buf);
            try spl_token.cpi.mintToMultisig(
                token_program.toCpiInfo(),
                mint.toCpiInfo(),
                destination.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
                try readAmount(data),
            );
        },
        .mint_to_checked_multisig => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const destination = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 4, &signer_buf);
            const args = try readAmountDecimals(data);
            try spl_token.cpi.mintToCheckedMultisig(
                token_program.toCpiInfo(),
                mint.toCpiInfo(),
                destination.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
                args.amount,
                args.decimals,
            );
        },
        .burn_multisig => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 4, &signer_buf);
            try spl_token.cpi.burnMultisig(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                mint.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
                try readAmount(data),
            );
        },
        .burn_checked_multisig => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const source = ctx.nextAccountUnchecked();
            const mint = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 4, &signer_buf);
            const args = try readAmountDecimals(data);
            try spl_token.cpi.burnCheckedMultisig(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                mint.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
                args.amount,
                args.decimals,
            );
        },
        .close_account_multisig => {
            try requireAccounts(ctx, 4);
            const token_program = ctx.nextAccountUnchecked();
            const account = ctx.nextAccountUnchecked();
            const destination = ctx.nextAccountUnchecked();
            const multisig_authority = ctx.nextAccountUnchecked();
            var signer_buf: [spl_token.MULTISIG_SIGNER_MAX]sol.CpiAccountInfo = undefined;
            const signer_infos = try collectExtraAccounts(ctx, 4, &signer_buf);
            try spl_token.cpi.closeAccountMultisig(
                token_program.toCpiInfo(),
                account.toCpiInfo(),
                destination.toCpiInfo(),
                multisig_authority.toCpiInfo(),
                signer_infos,
            );
        },
        else => return error.InvalidInstructionData,
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
