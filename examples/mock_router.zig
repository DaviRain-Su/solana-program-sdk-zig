//! Mock-only router demo built as `example_mock_router` in program-test.
//!
//! The demo ABI is intentionally compact and exact so Rust fixture
//! builders can encode it byte-for-byte:
//!
//! Common header (all numeric fields little-endian):
//!   - `u8 route_tag`
//!   - `u64 amount_in`
//!   - `u64 min_out`
//!   - `u8 hop_count`         (`1..=8`, zero rejected)
//!   - `u8 split_count`       (`0` for linear routes, `1..=4` for split routes)
//!
//! `route_tag = 0` (`exact_in_hops`)
//!   - repeated `hop_count` times:
//!     - `u8 account_window_len` (`1..=8`, zero rejected)
//!     - `u8 adapter_opcode`
//!
//! `route_tag = 1` (`exact_in_split`)
//!   - repeated `split_count` times:
//!     - `u8 leg_len`
//!     - `u8 leg_hop_count` (`1..=8`, zero rejected)
//!     - repeated `leg_hop_count` times:
//!       - `u8 account_window_len`
//!       - `u8 adapter_opcode`
//!   - the sum of all `leg_hop_count` values must equal `hop_count`
//!
//! Account-list semantics:
//!   - each hop consumes `account_window_len` dynamic non-program
//!     accounts from the remaining account list
//!   - immediately after that window, the next remaining account must
//!     be the executable mock adapter program account for the CPI
//!   - the router stages the window with `CpiAccountStaging` and then
//!     appends the adapter program account explicitly before `invoke`
//!
//! Return data:
//!   - `[32]u8 adapter_program_id`
//!   - exact return bytes emitted by the mock adapter

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

const RouteTag = enum(u8) {
    exact_in_hops = 0,
    exact_in_split = 1,
};

const MAX_HOPS: u8 = 8;
const MAX_SPLIT_COUNT: u8 = 4;
const MAX_ACCOUNT_WINDOW: u8 = 8;
const MAX_LEG_LEN: usize = 1 + (@as(usize, MAX_HOPS) * 2);
const ADAPTER_IX_LEN: usize = 1 + 8 + 8 + 1;
const ADAPTER_RETURN_LEN: usize = 85;
const ROUTER_RETURN_LEN: usize = sol.PUBKEY_BYTES + ADAPTER_RETURN_LEN;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    var data_ctx = ctx.*;
    data_ctx.skipAccounts(data_ctx.remainingAccounts());
    const ix_data = data_ctx.instructionDataUnchecked();
    const route_tag = sol.instruction.parseTag(RouteTag, ix_data) orelse
        return error.InvalidInstructionData;

    var route = sol.IxDataCursor.init(ix_data);
    try route.skip(1);

    const amount_in = try route.read(u64);
    const min_out = try route.read(u64);
    const hop_count = try route.readCount(u8, MAX_HOPS);
    if (hop_count == 0) return error.InvalidInstructionData;
    const split_count = try route.readCount(u8, MAX_SPLIT_COUNT);

    var accounts = try ctx.accountCursor();
    var forwarded: [ROUTER_RETURN_LEN]u8 = undefined;
    var forwarded_len: usize = 0;

    switch (route_tag) {
        .exact_in_hops => {
            if (split_count != 0) return error.InvalidInstructionData;

            var hop_index: u8 = 0;
            while (hop_index < hop_count) : (hop_index += 1) {
                forwarded_len = try executeHop(
                    &route,
                    &accounts,
                    amount_in,
                    min_out,
                    hop_index,
                    forwarded[0..],
                );
            }
        },
        .exact_in_split => {
            if (split_count == 0) return error.InvalidInstructionData;

            var seen_hops: u8 = 0;
            var leg_index: u8 = 0;
            while (leg_index < split_count) : (leg_index += 1) {
                var leg = try route.takeLengthPrefixedCursor(u8, MAX_LEG_LEN);
                const leg_hop_count = try leg.readCount(u8, MAX_HOPS);
                if (leg_hop_count == 0) return error.InvalidInstructionData;

                var leg_hop_index: u8 = 0;
                while (leg_hop_index < leg_hop_count) : (leg_hop_index += 1) {
                    forwarded_len = try executeHop(
                        &leg,
                        &accounts,
                        amount_in,
                        min_out,
                        seen_hops,
                        forwarded[0..],
                    );
                    seen_hops += 1;
                }
                try leg.expectEnd();
            }

            if (seen_hops != hop_count) return error.InvalidInstructionData;
        },
    }

    try route.expectEnd();
    if (accounts.remainingAccounts() != 0) return error.InvalidInstructionData;
    if (forwarded_len == 0) return error.InvalidInstructionData;

    sol.cpi.setReturnData(forwarded[0..forwarded_len]);
}

fn executeHop(
    cursor: *sol.IxDataCursor,
    accounts: *sol.AccountCursor,
    amount_in: u64,
    min_out: u64,
    hop_index: u8,
    forwarded_out: []u8,
) sol.ProgramError!usize {
    const account_window_len = try cursor.readCount(u8, MAX_ACCOUNT_WINDOW);
    if (account_window_len == 0) return error.InvalidInstructionData;
    const adapter_opcode = try cursor.read(u8);

    const window = try accounts.takeWindow(@intCast(account_window_len));
    const adapter_program = try accounts.takeOne();
    try adapter_program.expect(.{ .executable = true });

    var metas: [MAX_ACCOUNT_WINDOW]sol.cpi.AccountMeta = undefined;
    var infos: [MAX_ACCOUNT_WINDOW + 1]sol.CpiAccountInfo = undefined;
    var staging = sol.CpiAccountStaging.init(metas[0..], infos[0..]);

    for (window.slice()) |account_info| {
        try staging.appendAccount(account_info.toCpiInfo());
    }
    try staging.appendProgram(adapter_program.toCpiInfo());

    var ix_buf: [ADAPTER_IX_LEN]u8 = undefined;
    var ix_staging = sol.IxDataStaging.init(ix_buf[0..]);
    try ix_staging.writeIntLittleEndian(u8, adapter_opcode);
    try ix_staging.writeIntLittleEndian(u64, amount_in);
    try ix_staging.writeIntLittleEndian(u64, min_out);
    try ix_staging.writeIntLittleEndian(u8, hop_index);

    const ix = staging.instructionFromProgram(
        adapter_program.toCpiInfo(),
        ix_staging.written(),
    );
    try sol.cpi.invoke(&ix, staging.accountInfos());

    var adapter_return: [ADAPTER_RETURN_LEN]u8 = undefined;
    const returned = sol.cpi.getReturnData(adapter_return[0..]) orelse
        return error.InvalidInstructionData;
    const returned_data = returned.@"1";
    if (returned_data.len != ADAPTER_RETURN_LEN) return error.InvalidInstructionData;
    if (forwarded_out.len < sol.PUBKEY_BYTES + returned_data.len) {
        return error.InvalidInstructionData;
    }

    @memcpy(forwarded_out[0..sol.PUBKEY_BYTES], adapter_program.key()[0..]);
    @memcpy(forwarded_out[sol.PUBKEY_BYTES .. sol.PUBKEY_BYTES + returned_data.len], returned_data);
    return sol.PUBKEY_BYTES + returned_data.len;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
