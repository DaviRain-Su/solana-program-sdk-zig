//! Mock-only transfer-hook program built as `example_mock_transfer_hook`
//! for program-test / Mollusk validation.
//!
//! The program proves that an SBF artifact can import
//! `spl_transfer_hook`, accept canonical Execute instruction
//! accounts/data, and reject malformed or unsafe Execute flows
//! deterministically through the package's parser and validation
//! helpers.

const sol = @import("solana_program_sdk");
const spl_transfer_hook = @import("spl_transfer_hook");

pub const panic = sol.panic.Panic;

const MAX_EXTRA_ACCOUNT_METAS: usize = 8;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    var data_ctx = ctx.*;
    data_ctx.skipAccounts(data_ctx.remainingAccounts());
    const ix_data = data_ctx.instructionDataUnchecked();
    const hook_program_id = data_ctx.programIdUnchecked();
    switch (spl_transfer_hook.instruction.TransferHookInstruction.unpack(ix_data) catch |err| {
        return sol.fail(@src(), "mock_transfer_hook:unpack", err);
    }) {
        .execute => {},
        else => return error.InvalidInstructionData,
    }

    var accounts = ctx.accountCursor() catch |err| return sol.fail(@src(), "mock_transfer_hook:cursor", err);
    const source = accounts.takeOne() catch |err| return sol.fail(@src(), "mock_transfer_hook:source", err);
    const mint = accounts.takeOne() catch |err| return sol.fail(@src(), "mock_transfer_hook:mint", err);
    const destination = accounts.takeOne() catch |err| return sol.fail(@src(), "mock_transfer_hook:destination", err);
    const authority = accounts.takeOne() catch |err| return sol.fail(@src(), "mock_transfer_hook:authority", err);
    const validation = accounts.takeOne() catch |err| return sol.fail(@src(), "mock_transfer_hook:validation", err);
    const extra_accounts = accounts.takeWindow(@intCast(accounts.remainingAccounts())) catch |err| {
        return sol.fail(@src(), "mock_transfer_hook:extra_accounts", err);
    };

    const base_accounts = [_]spl_transfer_hook.AccountKeyData{
        .{ .key = source.key(), .data = source.data() },
        .{ .key = mint.key(), .data = mint.data() },
        .{ .key = destination.key(), .data = destination.data() },
        .{ .key = authority.key(), .data = authority.data() },
        .{ .key = validation.key(), .data = validation.data() },
    };

    var out_metas: [MAX_EXTRA_ACCOUNT_METAS]sol.cpi.AccountMeta = undefined;
    var out_keys: [MAX_EXTRA_ACCOUNT_METAS]sol.Pubkey = undefined;
    _ = spl_transfer_hook.validateExecuteExtraAccountInfos(
        validation,
        mint.key(),
        hook_program_id,
        ix_data,
        base_accounts[0..],
        extra_accounts.slice(),
        out_metas[0..],
        out_keys[0..],
    ) catch |err| return sol.fail(@src(), "mock_transfer_hook:validate_execute", err);
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
