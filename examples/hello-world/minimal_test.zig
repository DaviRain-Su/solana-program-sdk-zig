// Minimal test - no imports at all

// Direct syscall
extern fn sol_log_(message: [*]const u8, len: u64) callconv(.C) void;

// Message as array
const MSG = [_]u8{ 'T', 'e', 's', 't' };

// Entrypoint
export fn entrypoint(input: [*]u8) callconv(.C) u64 {
    _ = input;
    sol_log_(&MSG, MSG.len);
    return 0;
}