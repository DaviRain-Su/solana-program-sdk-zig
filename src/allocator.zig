//! Bump allocator for Solana programs
//!
//! A simple bump allocator that grows from low addresses to high addresses.
//! Used for heap allocations in Solana BPF programs.

const std = @import("std");
const Alignment = std.mem.Alignment;

/// Heap start address for BPF programs (Solana convention)
pub const HEAP_START_ADDRESS: u64 = 0x300000000;

/// Default heap length (32KB)
pub const HEAP_LENGTH: usize = 32 * 1024;

/// Maximum heap length (256KB, as of Solana v1.17+)
pub const MAX_HEAP_LENGTH: usize = 256 * 1024;

/// Simple bump allocator
///
/// Allocations grow from low addresses to high addresses.
/// The end index is stored in the first `usize` bytes of the buffer.
pub const BumpAllocator = struct {
    buffer: []u8,

    /// Get pointer to the end index (stored at buffer start)
    inline fn endIndex(self: *BumpAllocator) *usize {
        return @as(*usize, @ptrCast(@alignCast(self.buffer[0..@sizeOf(usize)])));
    }

    /// Initialize at compile time
    pub fn comptimeInit(buffer: []u8) BumpAllocator {
        return .{ .buffer = buffer };
    }

    /// Initialize at runtime
    pub fn init(buffer: []u8) BumpAllocator {
        var self = BumpAllocator{ .buffer = buffer };
        self.endIndex().* = @sizeOf(usize);
        return self;
    }

    /// Get std.mem.Allocator interface
    pub fn allocator(self: *BumpAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = remap,
            },
        };
    }

    /// Reset allocator (free all allocations)
    pub inline fn reset(self: *BumpAllocator) void {
        self.endIndex().* = @sizeOf(usize);
    }

    /// Direct allocation (bypass Allocator interface for performance)
    pub inline fn allocDirect(self: *BumpAllocator, n: usize, alignment: usize) ?[*]u8 {
        const ptr_align = if (alignment > 1) alignment else 1;
        const current_end = self.endIndex().*;
        const ptr = @intFromPtr(self.buffer.ptr) + current_end;
        const aligned_ptr = std.mem.alignForward(usize, ptr, ptr_align);
        const adjust_off = aligned_ptr - ptr;
        const new_end = current_end + adjust_off + n;

        if (new_end > self.buffer.len) return null;

        self.endIndex().* = new_end;
        return @ptrFromInt(aligned_ptr);
    }

    /// Check if slice was allocated by this allocator
    inline fn ownsSlice(self: *BumpAllocator, slice: []u8) bool {
        const start = @intFromPtr(self.buffer.ptr);
        const slice_start = @intFromPtr(slice.ptr);
        const slice_end = slice_start + slice.len;
        return slice_start >= start and slice_end <= start + self.buffer.len;
    }

    /// Check if this is the last allocation (for resize/free)
    inline fn isLastAllocation(self: *BumpAllocator, buf: []u8) bool {
        return buf.ptr + buf.len == self.buffer.ptr + self.endIndex().*;
    }

    fn alloc(ctx: *anyopaque, n: usize, alignment: Alignment, ra: usize) ?[*]u8 {
        const self: *BumpAllocator = @ptrCast(@alignCast(ctx));
        _ = ra;

        if (self.endIndex().* == 0) {
            self.endIndex().* = @sizeOf(usize);
        }

        const ptr_align = alignment.toByteUnits();
        const current_end = self.endIndex().*;
        const ptr = @intFromPtr(self.buffer.ptr) + current_end;
        const aligned_ptr = std.mem.alignForward(usize, ptr, ptr_align);
        const adjust_off = aligned_ptr - ptr;
        const new_end = current_end + adjust_off + n;

        if (new_end > self.buffer.len) return null;

        self.endIndex().* = new_end;
        return @ptrFromInt(aligned_ptr);
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        alignment: Alignment,
        new_size: usize,
        return_address: usize,
    ) bool {
        const self: *BumpAllocator = @ptrCast(@alignCast(ctx));
        _ = alignment;
        _ = return_address;

        if (!self.isLastAllocation(buf)) {
            return new_size <= buf.len;
        }

        if (new_size <= buf.len) {
            self.endIndex().* -= buf.len - new_size;
            return true;
        }

        const add = new_size - buf.len;
        if (self.endIndex().* + add > self.buffer.len) return false;

        self.endIndex().* += add;
        return true;
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        alignment: Alignment,
        return_address: usize,
    ) void {
        const self: *BumpAllocator = @ptrCast(@alignCast(ctx));
        _ = alignment;
        _ = return_address;

        if (self.isLastAllocation(buf)) {
            self.endIndex().* -= buf.len;
        }
    }

    fn remap(
        context: *anyopaque,
        memory: []u8,
        alignment: Alignment,
        new_len: usize,
        return_address: usize,
    ) ?[*]u8 {
        return if (resize(context, memory, alignment, new_len, return_address))
            memory.ptr
        else
            null;
    }
};

/// Global bump allocator instance (for use with std.mem.Allocator interface)
///
/// Usage:
/// ```zig
/// const ptr = allocator.allocDirect(u8, 100, 1);
/// ```
pub var global_allocator: BumpAllocator = undefined;

/// Initialize global allocator with default heap
pub fn initGlobalAllocator() void {
    const heap = @as([*]u8, @ptrFromInt(HEAP_START_ADDRESS))[0..HEAP_LENGTH];
    global_allocator = BumpAllocator.init(heap);
}

// =============================================================================
// Tests
// =============================================================================

test "BumpAllocator: basic allocation" {
    var buffer: [1024]u8 = undefined;
    var alloc = BumpAllocator.init(&buffer);

    const ptr1 = alloc.allocDirect(10, 1).?;
    @memcpy(ptr1[0..5], "hello");
    try std.testing.expectEqualStrings("hello", ptr1[0..5]);

    const ptr2 = alloc.allocDirect(20, 1).?;
    @memcpy(ptr2[0..5], "world");
    try std.testing.expectEqualStrings("world", ptr2[0..5]);
}

test "BumpAllocator: aligned allocation" {
    var buffer: [1024]u8 = undefined;
    var alloc = BumpAllocator.init(&buffer);

    const ptr2 = alloc.allocDirect(8, 8).?;
    try std.testing.expectEqual(@as(usize, 0), @intFromPtr(ptr2) % 8);

    const ptr3 = alloc.allocDirect(16, 16).?;
    try std.testing.expectEqual(@as(usize, 0), @intFromPtr(ptr3) % 16);
}

test "BumpAllocator: reset" {
    var buffer align(8) = [_]u8{0} ** 1024;
    var alloc = BumpAllocator.init(&buffer);

    _ = alloc.allocDirect(100, 1).?;
    const before = alloc.endIndex().*;
    try std.testing.expect(before > @sizeOf(usize));

    alloc.reset();
    const after = alloc.endIndex().*;
    try std.testing.expectEqual(@as(usize, @sizeOf(usize)), after);
}

test "BumpAllocator: std interface" {
    var buffer align(8) = [_]u8{0} ** 1024;
    var bump = BumpAllocator.init(&buffer);
    const std_alloc = bump.allocator();

    const ptr = try std_alloc.alloc(u8, 100);
    try std.testing.expectEqual(@as(usize, 100), ptr.len);

    std_alloc.free(ptr);
}

test "BumpAllocator: out of memory" {
    var buffer align(8) = [_]u8{0} ** 64;
    var alloc = BumpAllocator.init(&buffer);

    // First allocation should succeed
    const ptr1 = alloc.allocDirect(32, 1);
    try std.testing.expect(ptr1 != null);

    // Second allocation should fail (not enough space)
    const ptr2 = alloc.allocDirect(64, 1);
    try std.testing.expect(ptr2 == null);
}
