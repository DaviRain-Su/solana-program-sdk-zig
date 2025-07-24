const std = @import("std");
const Pubkey = @import("pubkey.zig").Pubkey;

/// 账户信息结构
pub const AccountInfo = struct {
    /// 账户公钥
    key: *const Pubkey,
    
    /// 是否为签名者
    is_signer: bool,
    
    /// 是否可写
    is_writable: bool,
    
    /// 账户余额（lamports）
    lamports: *u64,
    
    /// 账户数据
    data: []u8,
    
    /// 账户所有者
    owner: *const Pubkey,
    
    /// 是否可执行
    executable: bool,
    
    /// 租金纪元
    rent_epoch: u64,

    /// 尝试借用账户的 lamports（可变借用）
    pub fn tryBorrowLamports(self: *AccountInfo) !*u64 {
        if (!self.is_writable) {
            return error.AccountBorrowFailed;
        }
        return self.lamports;
    }

    /// 尝试借用账户数据（可变借用）
    pub fn tryBorrowDataMut(self: *AccountInfo) ![]u8 {
        if (!self.is_writable) {
            return error.AccountBorrowFailed;
        }
        return self.data;
    }

    /// 借用账户数据（只读）
    pub fn borrowData(self: *const AccountInfo) []const u8 {
        return self.data;
    }

    /// 检查账户是否被某个程序拥有
    pub fn isOwnedBy(self: *const AccountInfo, program_id: *const Pubkey) bool {
        return self.owner.equals(program_id.*);
    }

    /// 检查账户是否可执行
    pub fn isExecutable(self: *const AccountInfo) bool {
        return self.executable;
    }

    /// 检查账户是否为签名者
    pub fn isSigner(self: *const AccountInfo) bool {
        return self.is_signer;
    }

    /// 检查账户是否可写
    pub fn isWritable(self: *const AccountInfo) bool {
        return self.is_writable;
    }

    /// 从序列化数据反序列化账户数据
    pub fn deserializeData(self: *const AccountInfo, comptime T: type) !T {
        if (@sizeOf(T) > self.data.len) {
            return error.AccountDataTooSmall;
        }
        return std.mem.bytesToValue(T, self.data[0..@sizeOf(T)]);
    }

    /// 序列化数据到账户
    pub fn serializeData(self: *AccountInfo, value: anytype) !void {
        const T = @TypeOf(value);
        if (@sizeOf(T) > self.data.len) {
            return error.AccountDataTooSmall;
        }
        const data_mut = try self.tryBorrowDataMut();
        std.mem.writeInt(T, data_mut[0..@sizeOf(T)], value, .little);
    }

    /// 重新分配账户数据空间
    pub fn realloc(
        self: *AccountInfo,
        new_len: usize,
        zero_init: bool,
    ) !void {
        // 在 Solana 中，重新分配是通过系统调用完成的
        // 这里只是接口定义，实际实现需要系统调用
        _ = self;
        _ = new_len;
        _ = zero_init;
        return error.NotImplemented;
    }

    /// 分配账户给新的所有者
    pub fn assign(self: *AccountInfo, new_owner: *const Pubkey) !void {
        if (!self.is_writable) {
            return error.AccountNotWritable;
        }
        self.owner = new_owner;
    }

    /// 检查账户数据是否为空
    pub fn dataIsEmpty(self: *const AccountInfo) bool {
        return self.data.len == 0;
    }

    /// 格式化输出
    pub fn format(
        self: AccountInfo,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("AccountInfo{{ key: {}, lamports: {}, data_len: {}, owner: {}, executable: {}, is_signer: {}, is_writable: {} }}", .{
            self.key,
            self.lamports.*,
            self.data.len,
            self.owner,
            self.executable,
            self.is_signer,
            self.is_writable,
        });
    }
};

/// 账户元数据，用于 CPI 调用
pub const AccountMeta = struct {
    /// 账户公钥
    pubkey: Pubkey,
    
    /// 是否为签名者
    is_signer: bool,
    
    /// 是否可写
    is_writable: bool,

    /// 创建新的账户元数据
    pub fn init(pubkey: Pubkey, is_signer: bool, is_writable: bool) AccountMeta {
        return .{
            .pubkey = pubkey,
            .is_signer = is_signer,
            .is_writable = is_writable,
        };
    }

    /// 创建只读账户元数据
    pub fn readonly(pubkey: Pubkey, is_signer: bool) AccountMeta {
        return init(pubkey, is_signer, false);
    }

    /// 创建可写账户元数据
    pub fn writable(pubkey: Pubkey, is_signer: bool) AccountMeta {
        return init(pubkey, is_signer, true);
    }
};

/// 用于传递多个账户的迭代器
pub const AccountInfoIter = struct {
    accounts: []AccountInfo,
    index: usize = 0,

    pub fn next(self: *AccountInfoIter) ?*AccountInfo {
        if (self.index >= self.accounts.len) {
            return null;
        }
        const account = &self.accounts[self.index];
        self.index += 1;
        return account;
    }

    pub fn nextAccount(self: *AccountInfoIter, expected_key: *const Pubkey) !*AccountInfo {
        const account = self.next() orelse return error.NotEnoughAccountKeys;
        if (!account.key.equals(expected_key.*)) {
            return error.InvalidAccountKey;
        }
        return account;
    }

    pub fn nextAccountSigner(self: *AccountInfoIter, expected_key: *const Pubkey) !*AccountInfo {
        const account = try self.nextAccount(expected_key);
        if (!account.is_signer) {
            return error.MissingRequiredSignature;
        }
        return account;
    }

    pub fn remaining(self: *const AccountInfoIter) usize {
        return self.accounts.len - self.index;
    }
};

// 测试
test "AccountInfo basic operations" {
    const testing = std.testing;
    
    var key = Pubkey.zero;
    var owner = Pubkey.system_program_id;
    var lamports: u64 = 1000;
    var data = [_]u8{0} ** 32;
    
    var account = AccountInfo{
        .key = &key,
        .is_signer = true,
        .is_writable = true,
        .lamports = &lamports,
        .data = &data,
        .owner = &owner,
        .executable = false,
        .rent_epoch = 0,
    };
    
    // 测试基本访问
    try testing.expect(account.isSigner());
    try testing.expect(account.isWritable());
    try testing.expect(!account.isExecutable());
    try testing.expect(account.isOwnedBy(&Pubkey.system_program_id));
    
    // 测试借用
    const borrowed_lamports = try account.tryBorrowLamports();
    borrowed_lamports.* = 2000;
    try testing.expectEqual(@as(u64, 2000), lamports);
    
    // 测试数据借用
    const borrowed_data = try account.tryBorrowDataMut();
    borrowed_data[0] = 42;
    try testing.expectEqual(@as(u8, 42), data[0]);
}

test "AccountMeta creation" {
    const testing = std.testing;
    
    const pubkey = Pubkey.zero;
    
    // 只读非签名者
    const meta1 = AccountMeta.readonly(pubkey, false);
    try testing.expect(!meta1.is_signer);
    try testing.expect(!meta1.is_writable);
    
    // 可写签名者
    const meta2 = AccountMeta.writable(pubkey, true);
    try testing.expect(meta2.is_signer);
    try testing.expect(meta2.is_writable);
}

test "AccountInfoIter" {
    const testing = std.testing;
    
    var key1 = Pubkey.zero;
    var key2 = Pubkey.system_program_id;
    var lamports: u64 = 0;
    var data = [_]u8{};
    
    var accounts = [_]AccountInfo{
        .{
            .key = &key1,
            .is_signer = true,
            .is_writable = true,
            .lamports = &lamports,
            .data = &data,
            .owner = &key1,
            .executable = false,
            .rent_epoch = 0,
        },
        .{
            .key = &key2,
            .is_signer = false,
            .is_writable = false,
            .lamports = &lamports,
            .data = &data,
            .owner = &key2,
            .executable = false,
            .rent_epoch = 0,
        },
    };
    
    var iter = AccountInfoIter{ .accounts = &accounts };
    
    try testing.expectEqual(@as(usize, 2), iter.remaining());
    
    const acc1 = iter.next().?;
    try testing.expect(acc1.key.equals(key1));
    
    const acc2 = iter.next().?;
    try testing.expect(acc2.key.equals(key2));
    
    try testing.expectEqual(@as(?*AccountInfo, null), iter.next());
}