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
//!   - `adapter_opcode & 0x80 != 0` selects duplicate-policy reject
//!     for that hop's dynamic account window; otherwise duplicates are
//!     explicitly allowed and resolve back to the first matching slot
//!   - `adapter_opcode & 0x7f` is interpreted by the mock adapter as a
//!     fee in basis points, so every hop produces a deterministic
//!     `amount_out`
//!
//! Return data:
//!   - `u8 executed_hop_count`
//!   - repeated `executed_hop_count` times:
//!     - `[32]u8 adapter_program_id`
//!     - exact return bytes emitted by the mock adapter
//!   - `u64 final_output`

const std = @import("std");
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
const ADAPTER_RETURN_LEN: usize = 93;
const DUPLICATE_REJECT_FLAG: u8 = 0x80;
const TRACE_ENTRY_LEN: usize = sol.PUBKEY_BYTES + ADAPTER_RETURN_LEN;
const ROUTER_RETURN_LEN: usize = 1 + (@as(usize, MAX_HOPS) * TRACE_ENTRY_LEN) + 8;

const RouterErr = sol.ErrorCode(
    enum(u32) {
        SlippageExceeded = 6000,
    },
    error{SlippageExceeded},
);

const HopExecution = struct {
    output_amount: u64,
    trace_len: usize,
};

const AdapterReturn = struct {
    adapter_opcode: u8,
    amount_in: u64,
    amount_out: u64,
    min_out: u64,
    hop_index: u8,
};

fn process(ctx: *sol.entrypoint.InstructionContext) RouterErr.Error!void {
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
    forwarded[0] = 0;
    var forwarded_len: usize = 1;
    var executed_hops: u8 = 0;
    var final_output: u64 = 0;

    switch (route_tag) {
        .exact_in_hops => {
            if (split_count != 0) return error.InvalidInstructionData;

            var current_amount = amount_in;
            var hop_index: u8 = 0;
            while (hop_index < hop_count) : (hop_index += 1) {
                const hop = try executeHop(
                    &route,
                    &accounts,
                    current_amount,
                    min_out,
                    hop_index,
                    forwarded[forwarded_len..],
                );
                current_amount = hop.output_amount;
                forwarded_len += hop.trace_len;
                executed_hops += 1;
            }
            final_output = current_amount;
        },
        .exact_in_split => {
            if (split_count == 0) return error.InvalidInstructionData;

            const split_count_u64: u64 = split_count;
            const base_leg_amount = @divTrunc(amount_in, split_count_u64);
            const final_leg_remainder = @rem(amount_in, split_count_u64);

            var seen_hops: u8 = 0;
            var leg_index: u8 = 0;
            while (leg_index < split_count) : (leg_index += 1) {
                var leg = try route.takeLengthPrefixedCursor(u8, MAX_LEG_LEN);
                const leg_hop_count = try leg.readCount(u8, MAX_HOPS);
                if (leg_hop_count == 0) return error.InvalidInstructionData;

                var leg_amount = base_leg_amount;
                if (leg_index + 1 == split_count) {
                    leg_amount = try sol.math.add(leg_amount, final_leg_remainder);
                }

                var leg_hop_index: u8 = 0;
                while (leg_hop_index < leg_hop_count) : (leg_hop_index += 1) {
                    const hop = try executeHop(
                        &leg,
                        &accounts,
                        leg_amount,
                        min_out,
                        seen_hops,
                        forwarded[forwarded_len..],
                    );
                    leg_amount = hop.output_amount;
                    forwarded_len += hop.trace_len;
                    executed_hops += 1;
                    seen_hops += 1;
                }
                try leg.expectEnd();
                final_output = try sol.math.add(final_output, leg_amount);
            }

            if (seen_hops != hop_count) return error.InvalidInstructionData;
        },
    }

    try route.expectEnd();
    if (accounts.remainingAccounts() != 0) return error.InvalidInstructionData;
    if (executed_hops != hop_count or executed_hops == 0) return error.InvalidInstructionData;
    try sol.math.requireMinOut(final_output, min_out);

    var summary = sol.IxDataStaging.init(forwarded[forwarded_len..]);
    try summary.writeIntLittleEndian(u64, final_output);
    forwarded_len += summary.written().len;
    forwarded[0] = executed_hops;

    sol.cpi.setReturnData(forwarded[0..forwarded_len]);
}

fn executeHop(
    cursor: *sol.IxDataCursor,
    accounts: *sol.AccountCursor,
    amount_in: u64,
    min_out: u64,
    hop_index: u8,
    forwarded_out: []u8,
) RouterErr.Error!HopExecution {
    const account_window_len = try cursor.readCount(u8, MAX_ACCOUNT_WINDOW);
    if (account_window_len == 0) return error.InvalidInstructionData;
    const adapter_opcode = try cursor.read(u8);

    const window = if ((adapter_opcode & DUPLICATE_REJECT_FLAG) != 0)
        try accounts.takeWindowWithPolicy(@intCast(account_window_len), .reject)
    else
        try accounts.takeWindowWithPolicy(@intCast(account_window_len), .allow);
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
    const returned_program = returned.@"0";
    const returned_data = returned.@"1";
    if (returned_data.len != ADAPTER_RETURN_LEN) return error.InvalidInstructionData;
    if (!std.mem.eql(u8, returned_program[0..], adapter_program.key()[0..])) {
        return error.InvalidInstructionData;
    }

    const parsed = try parseAdapterReturn(returned_data);
    if (parsed.adapter_opcode != adapter_opcode) return error.InvalidInstructionData;
    if (parsed.amount_in != amount_in) return error.InvalidInstructionData;
    if (parsed.min_out != min_out) return error.InvalidInstructionData;
    if (parsed.hop_index != hop_index) return error.InvalidInstructionData;

    if (forwarded_out.len < TRACE_ENTRY_LEN) {
        return error.InvalidInstructionData;
    }

    @memcpy(forwarded_out[0..sol.PUBKEY_BYTES], returned_program[0..]);
    @memcpy(forwarded_out[sol.PUBKEY_BYTES .. sol.PUBKEY_BYTES + returned_data.len], returned_data);
    return .{
        .output_amount = parsed.amount_out,
        .trace_len = TRACE_ENTRY_LEN,
    };
}

fn parseAdapterReturn(data: []const u8) RouterErr.Error!AdapterReturn {
    var cursor = sol.IxDataCursor.init(data);
    const adapter_opcode = try cursor.read(u8);
    const amount_in = try cursor.read(u64);
    const amount_out = try cursor.read(u64);
    const min_out = try cursor.read(u64);
    const hop_index = try cursor.read(u8);
    _ = try cursor.read(u8);
    _ = try cursor.read(u8);
    _ = try cursor.read(u8);
    _ = try cursor.take(sol.PUBKEY_BYTES);
    _ = try cursor.take(sol.PUBKEY_BYTES);
    try cursor.expectEnd();

    return .{
        .adapter_opcode = adapter_opcode,
        .amount_in = amount_in,
        .amount_out = amount_out,
        .min_out = min_out,
        .hop_index = hop_index,
    };
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointTyped(RouterErr, process)(input);
}
