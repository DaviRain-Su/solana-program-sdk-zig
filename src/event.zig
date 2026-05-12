//! Program events — emit structured data on-chain via `sol_log_data`.
//!
//! Solana programs emit "events" by calling the `sol_log_data` syscall
//! with one or more byte slices. Off-chain indexers (Helius, Triton,
//! geyser plugins, etc.) decode these from the transaction logs and
//! drive notification systems / databases.
//!
//! Convention (Anchor-compatible):
//!
//!   emit(MyEvent { ... })
//!
//! becomes a single `sol_log_data` call with one slice equal to
//!
//!   discriminator(8B) || raw_bytes_of(MyEvent)
//!
//! where `discriminator` is `sha256("event:" ++ "MyEvent")[..8]`. Event
//! types must be `extern struct` so their wire layout is stable.
//!
//! Cost: one `sol_log_data` syscall (~100 CU) + ~80 bytes of stack for
//! the assembled buffer (event size capped to 247 bytes to fit in a
//! 256-byte stack buffer including the 8-byte discriminator + 1 byte
//! safety margin for alignment).

const std = @import("std");
const log = @import("log.zig");
const discriminator = @import("discriminator.zig");
const bpf = @import("bpf.zig");

const DISCRIMINATOR_LEN = discriminator.DISCRIMINATOR_LEN;

/// Soft upper bound on a single emitted event payload (discriminator
/// + value). The runtime caps `sol_log_data` at a few KB anyway; we
/// pin to 256 bytes to discourage giant events that would dominate
/// the program's CU budget (`sol_log_data` charges ~1 CU per byte).
pub const MAX_EVENT_SIZE: usize = 256;

/// Pull the `DISCRIMINATOR` decl off `T` if it has one, otherwise
/// compute `sha256("event:" ++ @typeName(T))[..8]`.
fn discriminatorFor(comptime T: type) [DISCRIMINATOR_LEN]u8 {
    if (@hasDecl(T, "DISCRIMINATOR")) {
        const d = @field(T, "DISCRIMINATOR");
        if (@TypeOf(d) == [DISCRIMINATOR_LEN]u8) return d;
    }
    // Fall back to `event:<TypeName>` derived discriminator.
    const name = comptime trimTypeName(@typeName(T));
    return discriminator.forEvent(name);
}

/// Strip everything before the last `.` in a fully-qualified type name
/// so `mymod.MyEvent` and `MyEvent` produce the same discriminator.
fn trimTypeName(comptime full: []const u8) []const u8 {
    return comptime blk: {
        var idx: usize = full.len;
        while (idx > 0) : (idx -= 1) {
            if (full[idx - 1] == '.') break;
        }
        break :blk full[idx..];
    };
}

/// Emit a structured event. `T` must be an `extern struct` and its
/// total wire size (8-byte discriminator + sizeof T) must fit in
/// `MAX_EVENT_SIZE`.
///
/// On host the call is a no-op (well, prints to stderr); on BPF it
/// dispatches `sol_log_data` with the assembled slice.
pub fn emit(value: anytype) void {
    const T = @TypeOf(value);
    comptime {
        const info = @typeInfo(T);
        if (info != .@"struct") {
            @compileError("emit(value): value must be an extern struct, got " ++ @typeName(T));
        }
        if (info.@"struct".layout != .@"extern") {
            @compileError("emit(value): value must be an extern struct (got layout " ++
                @tagName(info.@"struct".layout) ++ ")");
        }
        if (DISCRIMINATOR_LEN + @sizeOf(T) > MAX_EVENT_SIZE) {
            @compileError("emit(value): payload exceeds MAX_EVENT_SIZE — " ++
                "split into smaller events or raise MAX_EVENT_SIZE");
        }
    }

    const disc = comptime discriminatorFor(T);

    // Assemble disc || raw(value) on the stack and call `sol_log_data`
    // with one slice. Counter-intuitively this is ~100 CU cheaper than
    // calling `sol_log_data` with two slices (disc + value) — the
    // runtime charges a per-slice base fee that exceeds the memcpy
    // cost for typical small events.
    //
    // Buffer is sized at comptime to the exact payload — no need to
    // reserve a full MAX_EVENT_SIZE worth of stack at every emit site
    // when the actual event might be only a few bytes.
    const payload_size = comptime DISCRIMINATOR_LEN + @sizeOf(T);
    var buf: [payload_size]u8 = undefined;
    @memcpy(buf[0..DISCRIMINATOR_LEN], &disc);
    const value_bytes = std.mem.asBytes(&value);
    @memcpy(buf[DISCRIMINATOR_LEN..payload_size], value_bytes);

    const payload: []const u8 = &buf;

    if (bpf.is_bpf_program) {
        const slices = [_][]const u8{payload};
        log.logData(&slices);
    } else {
        std.debug.print(
            "[solana] event {s}: payload_size={d}\n",
            .{ @typeName(T), @sizeOf(T) },
        );
    }
}

// =============================================================================
// Tests
// =============================================================================

const TransferEvent = extern struct {
    from: [32]u8,
    to: [32]u8,
    amount: u64,

    pub const DISCRIMINATOR = discriminator.forEvent("Transfer");
};

const UntaggedEvent = extern struct {
    amount: u64,
    // No DISCRIMINATOR decl — falls back to forEvent(@typeName(T))
};

test "event: emit transfer event (host fallback)" {
    emit(TransferEvent{
        .from = .{1} ** 32,
        .to = .{2} ** 32,
        .amount = 100,
    });
}

test "event: emit untagged event computes discriminator from type name" {
    emit(UntaggedEvent{ .amount = 42 });
}

test "event: discriminator decl is used when present" {
    const want = discriminator.forEvent("Transfer");
    const got = discriminatorFor(TransferEvent);
    try std.testing.expectEqualSlices(u8, &want, &got);
}

test "event: trimTypeName strips module prefix" {
    try std.testing.expectEqualStrings("MyEvent", trimTypeName("foo.bar.MyEvent"));
    try std.testing.expectEqualStrings("Simple", trimTypeName("Simple"));
}
