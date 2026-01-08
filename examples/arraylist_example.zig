const std = @import("std");

pub fn main() !void {
    // Use general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create ArrayList with initial capacity (Zig 0.15+ API)
    var list = try std.ArrayList(i32).initCapacity(allocator, 8);
    defer list.deinit(allocator);

    // Append items - allocator required in 0.15+
    try list.append(allocator, 10);
    try list.append(allocator, 20);
    try list.append(allocator, 30);

    // Print current state
    std.debug.print("List items: {any}\n", .{list.items});
    std.debug.print("Length: {}, Capacity: {}\n", .{ list.items.len, list.capacity });

    // Append multiple items at once
    try list.appendSlice(allocator, &[_]i32{ 40, 50, 60 });
    std.debug.print("After appendSlice: {any}\n", .{list.items});

    // Use appendAssumeCapacity when capacity is guaranteed (no allocator needed)
    try list.ensureTotalCapacity(allocator, 20);
    list.appendAssumeCapacity(70);
    list.appendAssumeCapacity(80);
    std.debug.print("After appendAssumeCapacity: {any}\n", .{list.items});

    // Pop items
    const popped = list.pop();
    std.debug.print("Popped: {?}\n", .{popped});

    // Iterate over items
    std.debug.print("Iterating: ", .{});
    for (list.items) |item| {
        std.debug.print("{} ", .{item});
    }
    std.debug.print("\n", .{});

    // Get owned slice (transfers ownership)
    const owned = try list.toOwnedSlice(allocator);
    defer allocator.free(owned);
    std.debug.print("Owned slice: {any}\n", .{owned});

    // After toOwnedSlice, list is empty
    std.debug.print("List after toOwnedSlice: {any}\n", .{list.items});
}

test "ArrayList basic operations" {
    const allocator = std.testing.allocator;

    var list = try std.ArrayList(u8).initCapacity(allocator, 4);
    defer list.deinit(allocator);

    try list.append(allocator, 'H');
    try list.append(allocator, 'i');

    try std.testing.expectEqual(@as(usize, 2), list.items.len);
    try std.testing.expectEqualSlices(u8, "Hi", list.items);
}

test "ArrayList with structs" {
    const allocator = std.testing.allocator;

    const Point = struct {
        x: i32,
        y: i32,
    };

    var points = try std.ArrayList(Point).initCapacity(allocator, 4);
    defer points.deinit(allocator);

    try points.append(allocator, .{ .x = 0, .y = 0 });
    try points.append(allocator, .{ .x = 10, .y = 20 });

    try std.testing.expectEqual(@as(i32, 10), points.items[1].x);
    try std.testing.expectEqual(@as(i32, 20), points.items[1].y);
}
