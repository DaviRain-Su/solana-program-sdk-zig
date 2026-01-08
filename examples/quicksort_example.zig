const std = @import("std");

/// Quicksort implementation using ArrayList
/// Demonstrates ArrayList operations in Zig 0.15+ API
pub fn quicksort(items: []i32) void {
    if (items.len <= 1) return;
    quicksortRecursive(items, 0, @as(isize, @intCast(items.len)) - 1);
}

fn quicksortRecursive(items: []i32, low: isize, high: isize) void {
    if (low >= high) return;

    const pivot_index = partition(items, low, high);
    quicksortRecursive(items, low, pivot_index - 1);
    quicksortRecursive(items, pivot_index + 1, high);
}

fn partition(items: []i32, low: isize, high: isize) isize {
    const pivot = items[@intCast(high)];
    var i = low - 1;

    var j = low;
    while (j < high) : (j += 1) {
        if (items[@intCast(j)] <= pivot) {
            i += 1;
            swap(items, @intCast(i), @intCast(j));
        }
    }

    swap(items, @intCast(i + 1), @intCast(high));
    return i + 1;
}

fn swap(items: []i32, a: usize, b: usize) void {
    const temp = items[a];
    items[a] = items[b];
    items[b] = temp;
}

pub fn main() !void {
    // Use general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create ArrayList with initial capacity (Zig 0.15+ API)
    var list = try std.ArrayList(i32).initCapacity(allocator, 16);
    defer list.deinit(allocator);

    // Add unsorted elements
    const unsorted = [_]i32{ 64, 34, 25, 12, 22, 11, 90, 5, 77, 30 };
    try list.appendSlice(allocator, &unsorted);

    std.debug.print("Before sorting: {any}\n", .{list.items});

    // Sort using quicksort
    quicksort(list.items);

    std.debug.print("After sorting:  {any}\n", .{list.items});

    // Demonstrate dynamic operations after sorting
    std.debug.print("\n--- Dynamic Operations ---\n", .{});

    // Insert element and re-sort
    try list.append(allocator, 15);
    std.debug.print("After appending 15: {any}\n", .{list.items});

    quicksort(list.items);
    std.debug.print("After re-sorting:   {any}\n", .{list.items});

    // Insert multiple elements
    try list.appendSlice(allocator, &[_]i32{ 100, 1, 50 });
    std.debug.print("After appending 100, 1, 50: {any}\n", .{list.items});

    quicksort(list.items);
    std.debug.print("After final sort:          {any}\n", .{list.items});

    // Show statistics
    std.debug.print("\nList length: {}, Capacity: {}\n", .{ list.items.len, list.capacity });
}

test "quicksort empty list" {
    const allocator = std.testing.allocator;

    var list = try std.ArrayList(i32).initCapacity(allocator, 4);
    defer list.deinit(allocator);

    quicksort(list.items);
    try std.testing.expectEqual(@as(usize, 0), list.items.len);
}

test "quicksort single element" {
    const allocator = std.testing.allocator;

    var list = try std.ArrayList(i32).initCapacity(allocator, 4);
    defer list.deinit(allocator);

    try list.append(allocator, 42);
    quicksort(list.items);

    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    try std.testing.expectEqual(@as(i32, 42), list.items[0]);
}

test "quicksort multiple elements" {
    const allocator = std.testing.allocator;

    var list = try std.ArrayList(i32).initCapacity(allocator, 8);
    defer list.deinit(allocator);

    try list.appendSlice(allocator, &[_]i32{ 5, 2, 8, 1, 9, 3 });
    quicksort(list.items);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3, 5, 8, 9 }, list.items);
}

test "quicksort already sorted" {
    const allocator = std.testing.allocator;

    var list = try std.ArrayList(i32).initCapacity(allocator, 8);
    defer list.deinit(allocator);

    try list.appendSlice(allocator, &[_]i32{ 1, 2, 3, 4, 5 });
    quicksort(list.items);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3, 4, 5 }, list.items);
}

test "quicksort reverse sorted" {
    const allocator = std.testing.allocator;

    var list = try std.ArrayList(i32).initCapacity(allocator, 8);
    defer list.deinit(allocator);

    try list.appendSlice(allocator, &[_]i32{ 5, 4, 3, 2, 1 });
    quicksort(list.items);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3, 4, 5 }, list.items);
}

test "quicksort with duplicates" {
    const allocator = std.testing.allocator;

    var list = try std.ArrayList(i32).initCapacity(allocator, 8);
    defer list.deinit(allocator);

    try list.appendSlice(allocator, &[_]i32{ 3, 1, 4, 1, 5, 9, 2, 6, 5, 3 });
    quicksort(list.items);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 1, 2, 3, 3, 4, 5, 5, 6, 9 }, list.items);
}

test "quicksort with negative numbers" {
    const allocator = std.testing.allocator;

    var list = try std.ArrayList(i32).initCapacity(allocator, 8);
    defer list.deinit(allocator);

    try list.appendSlice(allocator, &[_]i32{ -5, 10, -3, 0, 7, -1 });
    quicksort(list.items);

    try std.testing.expectEqualSlices(i32, &[_]i32{ -5, -3, -1, 0, 7, 10 }, list.items);
}
