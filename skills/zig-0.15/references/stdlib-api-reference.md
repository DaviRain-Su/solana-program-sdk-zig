# Zig 0.15.x Standard Library API Reference

Comprehensive reference for Zig 0.15.x standard library APIs.

## std.ArrayList

### Initialization

```zig
const std = @import("std");

// Preferred: with initial capacity
var list = try std.ArrayList(u8).initCapacity(allocator, 16);
defer list.deinit(allocator);

// Alternative: empty
var list2 = std.ArrayList(u8){ .items = &.{}, .capacity = 0 };
defer list2.deinit(allocator);
```

### Methods Reference

| Method | Signature | Notes |
|--------|-----------|-------|
| `initCapacity` | `fn initCapacity(allocator, n) !Self` | Preferred init |
| `deinit` | `fn deinit(self, allocator) void` | Must pass allocator |
| `append` | `fn append(self, allocator, item) !void` | Allocator required |
| `appendSlice` | `fn appendSlice(self, allocator, items) !void` | Allocator required |
| `addOne` | `fn addOne(self, allocator) !*T` | Returns pointer to new slot |
| `ensureTotalCapacity` | `fn ensureTotalCapacity(self, allocator, n) !void` | Allocator required |
| `ensureUnusedCapacity` | `fn ensureUnusedCapacity(self, allocator, n) !void` | Allocator required |
| `toOwnedSlice` | `fn toOwnedSlice(self, allocator) ![]T` | Allocator required |
| `appendAssumeCapacity` | `fn appendAssumeCapacity(self, item) void` | No allocator |
| `appendSliceAssumeCapacity` | `fn appendSliceAssumeCapacity(self, items) void` | No allocator |
| `items` | field `[]T` | Direct access |
| `capacity` | field `usize` | Direct access |

### Usage Example

```zig
fn example(allocator: std.mem.Allocator) !void {
    var list = try std.ArrayList(u32).initCapacity(allocator, 8);
    defer list.deinit(allocator);

    // Add items
    try list.append(allocator, 1);
    try list.append(allocator, 2);
    try list.appendSlice(allocator, &[_]u32{ 3, 4, 5 });

    // Pre-allocate then use AssumeCapacity
    try list.ensureUnusedCapacity(allocator, 10);
    list.appendAssumeCapacity(6);
    list.appendAssumeCapacity(7);

    // Convert to owned slice
    const owned = try list.toOwnedSlice(allocator);
    defer allocator.free(owned);
}
```

## std.HashMap

### Managed vs Unmanaged

**Managed** - stores allocator internally:
- `std.StringHashMap(V)`
- `std.AutoHashMap(K, V)`
- `std.HashMap(K, V, ...)`

**Unmanaged** - no stored allocator:
- `std.StringHashMapUnmanaged(V)`
- `std.AutoHashMapUnmanaged(K, V)`
- `std.HashMapUnmanaged(K, V, ...)`

### Managed HashMap

```zig
var map = std.StringHashMap(u32).init(allocator);
defer map.deinit();

// Operations do NOT require allocator
try map.put("key", 42);
const val = map.get("key");
_ = map.remove("key");

// Iteration
var iter = map.iterator();
while (iter.next()) |entry| {
    std.debug.print("{s}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
}

// getOrPut pattern (avoids double lookup)
const result = try map.getOrPut("key");
if (!result.found_existing) {
    result.value_ptr.* = 100;
}
```

### Unmanaged HashMap

```zig
var map = std.StringHashMapUnmanaged(u32){};
defer map.deinit(allocator);

// Operations REQUIRE allocator
try map.put(allocator, "key", 42);
const val = map.get("key");  // get doesn't need allocator
_ = map.remove("key");       // remove doesn't need allocator

const result = try map.getOrPut(allocator, "key");
```

## std.http.Client

### GET Request

```zig
fn httpGet(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);
    
    var req = try client.open(.GET, uri, .{
        .extra_headers = &.{
            .{ .name = "Accept", .value = "application/json" },
        },
    });
    defer req.deinit();

    try req.send();
    try req.wait();

    if (req.status != .ok) {
        return error.HttpError;
    }

    // Read response body
    var body = std.ArrayList(u8).init(allocator);
    defer body.deinit();
    
    try req.reader().readAllArrayList(&body, 10 * 1024 * 1024);
    return try body.toOwnedSlice(allocator);
}
```

### POST Request

```zig
fn httpPost(allocator: std.mem.Allocator, url: []const u8, body: []const u8) ![]u8 {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);
    
    var req = try client.open(.POST, uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    try req.send();
    
    // Write body
    try req.writer().writeAll(body);
    try req.finish();
    
    try req.wait();

    // Read response
    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();
    try req.reader().readAllArrayList(&response, 10 * 1024 * 1024);
    return try response.toOwnedSlice(allocator);
}
```

## std.crypto.sign.Ed25519

### Key Generation

```zig
const Ed25519 = std.crypto.sign.Ed25519;

// Random keypair
const kp = Ed25519.KeyPair.generate();

// Deterministic from 32-byte seed
const seed: [32]u8 = ...; // Your seed
const kp = try Ed25519.KeyPair.generateDeterministic(seed);
```

### Key Conversion

```zig
// Get public key bytes
const pubkey_bytes: [32]u8 = kp.public_key.toBytes();

// Get seed from secret key
const seed: [32]u8 = kp.secret_key.seed();

// Get full secret key bytes (64 bytes = seed + pubkey)
const secret_bytes: [64]u8 = kp.secret_key.toBytes();

// Create from 64-byte secret key
var bytes: [64]u8 = ...; // seed || pubkey
const secret_key = try Ed25519.SecretKey.fromBytes(bytes);
const kp = try Ed25519.KeyPair.fromSecretKey(secret_key);

// Create public key from bytes
const pubkey = try Ed25519.PublicKey.fromBytes(pubkey_bytes);
```

### Signing and Verification

```zig
// Sign message
const message = "Hello, World!";
const signature = try kp.sign(message, null);  // null = no context
const sig_bytes: [64]u8 = signature.toBytes();

// Verify signature
const sig = Ed25519.Signature.fromBytes(sig_bytes);  // No try!
try sig.verify(message, kp.public_key);  // Throws on invalid
```

## std.base64

### Encoding

```zig
const encoder = std.base64.standard.Encoder;

// Calculate output size
const input = "Hello";
const output_len = encoder.calcSize(input.len);

// Encode to buffer
var buf: [100]u8 = undefined;
const encoded = encoder.encode(&buf, input);
// encoded is []const u8 slice of buf
```

### Decoding

```zig
const decoder = std.base64.standard.Decoder;

// Calculate max output size
const encoded = "SGVsbG8=";
const max_len = try decoder.calcSizeUpperBound(encoded.len);

// Decode to buffer
var buf: [100]u8 = undefined;
const decoded = try decoder.decode(&buf, encoded);
```

### URL-safe Base64

```zig
const encoder = std.base64.url_safe.Encoder;
const decoder = std.base64.url_safe.Decoder;
// Same API as standard
```

## std.json

### Parsing

```zig
const MyStruct = struct {
    name: []const u8,
    value: u32,
};

// Parse from string
const json_str = 
    \\{"name": "test", "value": 42}
;

const parsed = try std.json.parseFromSlice(MyStruct, allocator, json_str, .{});
defer parsed.deinit();

const data = parsed.value;
std.debug.print("name: {s}, value: {d}\n", .{ data.name, data.value });
```

### Stringify

```zig
const data = MyStruct{ .name = "test", .value = 42 };

// Allocating
const json = try std.json.stringifyAlloc(allocator, data, .{});
defer allocator.free(json);

// To writer
var buf: [1024]u8 = undefined;
var fbs = std.io.fixedBufferStream(&buf);
try std.json.stringify(data, .{}, fbs.writer());
const output = fbs.getWritten();
```

### Parse Options

```zig
const parsed = try std.json.parseFromSlice(MyStruct, allocator, json_str, .{
    .allocate = .alloc_always,           // How to handle strings
    .ignore_unknown_fields = true,        // Skip unknown fields
    .max_value_len = 1024 * 1024,        // Max string/array length
});
```

## @typeInfo

### Enum Values (0.15+ lowercase)

```zig
const info = @typeInfo(T);

switch (info) {
    .int => |i| { ... },
    .float => |f| { ... },
    .bool => { ... },
    .pointer => |p| { 
        if (p.size == .slice) { ... }
        if (p.size == .one) { ... }
    },
    .array => |a| { ... },
    .@"struct" => |s| { ... },    // Escaped keyword
    .@"enum" => |e| { ... },      // Escaped keyword
    .@"union" => |u| { ... },     // Escaped keyword
    .optional => |o| { ... },
    .error_union => |eu| { ... },
    .void => { ... },
    else => { ... },
}
```

### Common Patterns

```zig
// Check if type is slice
fn isSlice(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .pointer and info.pointer.size == .slice;
}

// Check if type is struct
fn isStruct(comptime T: type) bool {
    return @typeInfo(T) == .@"struct";
}

// Iterate struct fields
fn printFields(comptime T: type) void {
    const info = @typeInfo(T);
    if (info != .@"struct") return;
    
    inline for (info.@"struct".fields) |field| {
        std.debug.print("field: {s}\n", .{field.name});
    }
}
```

## std.fmt

### Allocating Print

```zig
const result = try std.fmt.allocPrint(allocator, "Hello, {s}! Value: {d}", .{ "World", 42 });
defer allocator.free(result);
```

### Buffer Print

```zig
var buf: [256]u8 = undefined;
const result = try std.fmt.bufPrint(&buf, "Value: {d}", .{42});
// result is []u8 slice of buf
```

### Format Specifiers

| Specifier | Use |
|-----------|-----|
| `{d}` | Integers |
| `{x}` | Hex |
| `{s}` | Strings/slices |
| `{any}` | Any type |
| `{*}` | Pointer address |
| `{e}` | Floats (scientific) |
| `{f}` | Custom format function |
| `{c}` | Single character |
| `{b}` | Binary |
| `{o}` | Octal |

### Width and Padding

```zig
// Width and alignment
std.fmt.bufPrint(&buf, "{d:>10}", .{42});   // Right align, width 10
std.fmt.bufPrint(&buf, "{d:<10}", .{42});   // Left align
std.fmt.bufPrint(&buf, "{d:^10}", .{42});   // Center
std.fmt.bufPrint(&buf, "{d:0>10}", .{42});  // Zero-pad
std.fmt.bufPrint(&buf, "{x:0>8}", .{255});  // Hex, zero-pad to 8
```

## Error Handling Patterns

### errdefer

```zig
fn createResource(allocator: Allocator) !*Resource {
    const res = try allocator.create(Resource);
    errdefer allocator.destroy(res);

    res.data = try allocator.alloc(u8, 100);
    errdefer allocator.free(res.data);

    try res.initialize();  // If this fails, both errdefers run
    return res;
}
```

### Error Union Handling

```zig
// Propagate
const result = try doSomething();

// Catch with handling
const result = doSomething() catch |err| {
    std.log.err("Failed: {}", .{err});
    return err;
};

// Catch with default
const result = doSomething() catch 0;

// Catch unreachable (when you know it won't fail)
const result = doSomething() catch unreachable;
```
