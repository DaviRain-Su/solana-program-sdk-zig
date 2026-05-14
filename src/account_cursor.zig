const account = @import("account/root.zig");
const program_error = @import("program_error.zig");

const Account = account.Account;
const AccountInfo = account.AccountInfo;
const MAX_PERMITTED_DATA_INCREASE = account.MAX_PERMITTED_DATA_INCREASE;
const MAX_TX_ACCOUNTS = account.MAX_TX_ACCOUNTS;
const NON_DUP_MARKER = account.NON_DUP_MARKER;
const ProgramError = program_error.ProgramError;

inline fn alignPointer(ptr: usize) usize {
    return (ptr + 7) & ~@as(usize, 7);
}

pub const DuplicatePolicy = enum {
    allow,
    reject,
    assume_unique,
};

pub const AccountWindow = struct {
    accounts: []const AccountInfo,

    const Self = @This();

    pub const Iterator = struct {
        accounts: []const AccountInfo,
        index: usize = 0,

        pub inline fn next(self: *Iterator) ?AccountInfo {
            if (self.index >= self.accounts.len) return null;
            defer self.index += 1;
            return self.accounts[self.index];
        }
    };

    pub inline fn len(self: Self) usize {
        return self.accounts.len;
    }

    pub inline fn isEmpty(self: Self) bool {
        return self.accounts.len == 0;
    }

    pub inline fn slice(self: Self) []const AccountInfo {
        return self.accounts;
    }

    pub inline fn get(self: Self, index: usize) ?AccountInfo {
        if (index >= self.accounts.len) return null;
        return self.accounts[index];
    }

    pub inline fn at(self: Self, index: usize) AccountInfo {
        return self.accounts[index];
    }

    pub inline fn iterator(self: Self) Iterator {
        return .{ .accounts = self.accounts };
    }

    pub inline fn expectEach(self: Self, comptime spec: anytype) ProgramError!void {
        for (self.accounts) |acc| {
            try acc.expect(spec);
        }
    }
};

pub const AccountCursor = struct {
    buffer: [*]u8,
    remaining: u64,
    resolved: [MAX_TX_ACCOUNTS]AccountInfo,
    resolved_len: usize,

    const Self = @This();
    const Mark = struct {
        buffer: [*]u8,
        remaining: u64,
        resolved_len: usize,
    };

    pub fn initRemaining(
        buffer: [*]u8,
        remaining: u64,
        prefix: []const AccountInfo,
    ) ProgramError!Self {
        const total = prefix.len + @as(usize, @intCast(remaining));
        if (total > MAX_TX_ACCOUNTS) return error.InvalidArgument;

        var self: Self = .{
            .buffer = buffer,
            .remaining = remaining,
            .resolved = undefined,
            .resolved_len = prefix.len,
        };
        @memcpy(self.resolved[0..prefix.len], prefix);
        return self;
    }

    pub inline fn remainingAccounts(self: Self) u64 {
        return self.remaining;
    }

    pub inline fn nextIndex(self: Self) usize {
        return self.resolved_len;
    }

    pub inline fn takeOne(self: *Self) ProgramError!AccountInfo {
        return self.takeOneWithPolicy(.allow);
    }

    pub inline fn takeOneWithPolicy(
        self: *Self,
        comptime policy: DuplicatePolicy,
    ) ProgramError!AccountInfo {
        const saved = self.snapshot();
        errdefer self.restore(saved);

        if (self.remaining == 0) return error.NotEnoughAccountKeys;
        return self.advanceOne(policy);
    }

    pub inline fn takeOneAssumeUnique(self: *Self) ProgramError!AccountInfo {
        return self.takeOneWithPolicy(.assume_unique);
    }

    pub inline fn peek(self: *Self) ProgramError!AccountInfo {
        return self.peekWithPolicy(.allow);
    }

    pub inline fn peekWithPolicy(
        self: *Self,
        comptime policy: DuplicatePolicy,
    ) ProgramError!AccountInfo {
        const saved = self.snapshot();
        const acc = try self.takeOneWithPolicy(policy);
        self.restore(saved);
        return acc;
    }

    pub inline fn peekAssumeUnique(self: *Self) ProgramError!AccountInfo {
        return self.peekWithPolicy(.assume_unique);
    }

    pub inline fn skip(self: *Self, count: usize) ProgramError!void {
        return self.skipWithPolicy(count, .allow);
    }

    pub inline fn skipWithPolicy(
        self: *Self,
        count: usize,
        comptime policy: DuplicatePolicy,
    ) ProgramError!void {
        const saved = self.snapshot();
        errdefer self.restore(saved);

        if (count > self.remainingAccounts()) return error.NotEnoughAccountKeys;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            _ = try self.advanceOne(policy);
        }
    }

    pub inline fn skipAssumeUnique(self: *Self, count: usize) ProgramError!void {
        return self.skipWithPolicy(count, .assume_unique);
    }

    pub inline fn takeWindow(self: *Self, count: usize) ProgramError!AccountWindow {
        return self.takeWindowWithPolicy(count, .allow);
    }

    pub inline fn takeWindowWithPolicy(
        self: *Self,
        count: usize,
        comptime policy: DuplicatePolicy,
    ) ProgramError!AccountWindow {
        const saved = self.snapshot();
        errdefer self.restore(saved);

        if (count > self.remainingAccounts()) return error.NotEnoughAccountKeys;

        const window_start = self.resolved_len;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            _ = try self.advanceOne(policy);
            if (policy == .reject) {
                try self.rejectWindowDuplicate(window_start);
            }
        }

        return .{ .accounts = self.resolved[window_start..self.resolved_len] };
    }

    pub inline fn takeWindowAssumeUnique(
        self: *Self,
        count: usize,
    ) ProgramError!AccountWindow {
        return self.takeWindowWithPolicy(count, .assume_unique);
    }

    pub inline fn takeWindowValidated(
        self: *Self,
        count: usize,
        comptime policy: DuplicatePolicy,
        comptime spec: anytype,
    ) ProgramError!AccountWindow {
        const saved = self.snapshot();
        errdefer self.restore(saved);

        const window = try self.takeWindowWithPolicy(count, policy);
        try window.expectEach(spec);
        return window;
    }

    fn snapshot(self: Self) Mark {
        return .{
            .buffer = self.buffer,
            .remaining = self.remaining,
            .resolved_len = self.resolved_len,
        };
    }

    fn restore(self: *Self, saved: Mark) void {
        self.buffer = saved.buffer;
        self.remaining = saved.remaining;
        self.resolved_len = saved.resolved_len;
    }

    fn appendResolved(self: *Self, acc: AccountInfo) ProgramError!AccountInfo {
        if (self.resolved_len >= MAX_TX_ACCOUNTS) return error.InvalidArgument;
        self.resolved[self.resolved_len] = acc;
        self.resolved_len += 1;
        return acc;
    }

    fn advanceOne(self: *Self, comptime policy: DuplicatePolicy) ProgramError!AccountInfo {
        return switch (policy) {
            .allow, .reject => self.advanceOneResolved(),
            .assume_unique => self.advanceOneUnchecked(),
        };
    }

    fn advanceOneUnchecked(self: *Self) ProgramError!AccountInfo {
        const account_ptr: *Account = @ptrCast(@alignCast(self.buffer));
        const acc: AccountInfo = .{ .raw = account_ptr };
        const data_len: usize = @intCast(account_ptr.data_len);

        self.remaining -= 1;
        self.buffer +=
            @sizeOf(u64) +
            (@sizeOf(Account) - @sizeOf(u64)) +
            data_len +
            MAX_PERMITTED_DATA_INCREASE;
        self.buffer = @ptrFromInt(alignPointer(@intFromPtr(self.buffer)));
        self.buffer += @sizeOf(u64);
        return self.appendResolved(acc);
    }

    fn advanceOneResolved(self: *Self) ProgramError!AccountInfo {
        const account_ptr: *Account = @ptrCast(@alignCast(self.buffer));

        self.remaining -= 1;

        if (account_ptr.borrow_state == NON_DUP_MARKER) {
            const acc: AccountInfo = .{ .raw = account_ptr };
            const data_len: usize = @intCast(account_ptr.data_len);

            self.buffer +=
                @sizeOf(u64) +
                (@sizeOf(Account) - @sizeOf(u64)) +
                data_len +
                MAX_PERMITTED_DATA_INCREASE;
            self.buffer = @ptrFromInt(alignPointer(@intFromPtr(self.buffer)));
            self.buffer += @sizeOf(u64);
            return self.appendResolved(acc);
        }

        const idx = account_ptr.borrow_state;
        if (idx >= self.resolved_len) return error.InvalidArgument;

        self.buffer += @sizeOf(u64);
        return self.appendResolved(self.resolved[idx]);
    }

    fn rejectWindowDuplicate(self: *Self, window_start: usize) ProgramError!void {
        if (self.resolved_len == 0) return;

        const last_index = self.resolved_len - 1;
        const last = self.resolved[last_index];

        var i = window_start;
        while (i < last_index) : (i += 1) {
            if (@intFromPtr(self.resolved[i].raw) == @intFromPtr(last.raw)) {
                return error.InvalidArgument;
            }
        }
    }
};
