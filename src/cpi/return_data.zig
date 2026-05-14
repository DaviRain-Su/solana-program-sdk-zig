const shared = @import("shared.zig");
const bpf = shared.bpf;
const Pubkey = shared.Pubkey;

extern fn sol_set_return_data(data: [*]const u8, len: u64) callconv(.c) void;
extern fn sol_get_return_data(data: [*]u8, len: u64, program_id: *Pubkey) callconv(.c) u64;

/// Set return data for this program
pub fn setReturnData(data: []const u8) void {
    if (bpf.is_bpf_program) {
        sol_set_return_data(data.ptr, data.len);
    }
}

/// Get return data from the last CPI call
pub fn getReturnData(buffer: []u8) ?struct { Pubkey, []const u8 } {
    if (!bpf.is_bpf_program) {
        return null;
    }

    var program_id: Pubkey = undefined;
    const len = sol_get_return_data(buffer.ptr, buffer.len, &program_id);

    if (len == 0) {
        return null;
    }

    return .{ program_id, buffer[0..@intCast(len)] };
}
