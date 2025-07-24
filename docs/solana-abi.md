# Solana 程序 ABI 和内存布局详解

## 程序入口点 ABI

### 入口函数签名
```c
uint64_t entrypoint(const uint8_t *input)
```

### 输入数据布局
```
input 指向的内存区域包含：
┌─────────────────────────┐
│ 账户数量 (u64)          │ 8 bytes
├─────────────────────────┤
│ 账户数组               │ 变长
├─────────────────────────┤
│ 指令数据长度 (u64)      │ 8 bytes
├─────────────────────────┤
│ 指令数据               │ 变长
├─────────────────────────┤
│ program_id             │ 32 bytes
└─────────────────────────┘
```

### 账户信息布局
每个账户的内存布局：
```
┌─────────────────────────┐
│ is_duplicate (u8)       │ 1 byte
├─────────────────────────┤
│ padding                 │ 7 bytes
├─────────────────────────┤
│ key (Pubkey)           │ 32 bytes
├─────────────────────────┤
│ owner (Pubkey)         │ 32 bytes
├─────────────────────────┤
│ lamports (u64)         │ 8 bytes
├─────────────────────────┤
│ data_len (u64)         │ 8 bytes
├─────────────────────────┤
│ data                   │ data_len bytes
├─────────────────────────┤
│ padding to 8 bytes     │ 变长
├─────────────────────────┤
│ executable (u8)        │ 1 byte
├─────────────────────────┤
│ padding                │ 7 bytes
├─────────────────────────┤
│ rent_epoch (u64)       │ 8 bytes
└─────────────────────────┘
```

## 内存限制

### 栈内存
- 最大栈大小：4KB
- 栈帧深度限制：64

### 堆内存
- 最大堆大小：32KB
- 通过 `sol_alloc_free_` 系统调用分配

### 计算单元限制
- 默认限制：200,000 计算单元
- 最大限制：1,400,000 计算单元（需要请求）

## 系统调用接口

### 核心系统调用
```c
// 日志输出
void sol_log_(const char *message, uint64_t len);
void sol_log_64_(uint64_t arg1, uint64_t arg2, uint64_t arg3, uint64_t arg4, uint64_t arg5);

// 内存操作
void sol_memcpy_(void *dst, const void *src, uint64_t n);
void sol_memmove_(void *dst, const void *src, uint64_t n);
void sol_memcmp_(const void *s1, const void *s2, uint64_t n, uint64_t *result);
void sol_memset_(void *s, uint8_t c, uint64_t n);

// 密码学操作
uint64_t sol_sha256(const uint8_t *vals, uint64_t val_len, uint8_t *hash_result);
uint64_t sol_keccak256(const uint8_t *vals, uint64_t val_len, uint8_t *hash_result);
uint64_t sol_blake3(const uint8_t *vals, uint64_t val_len, uint8_t *hash_result);

// 签名验证
uint64_t sol_ed25519_verify(
    const uint8_t *signature,
    const uint8_t *pubkey,
    const uint8_t *message,
    uint64_t message_len
);

// 程序调用
uint64_t sol_invoke_signed_c(
    const SolInstruction *instruction,
    const SolAccountInfo *account_infos,
    uint64_t account_infos_len,
    const SolSignerSeeds *signers_seeds,
    uint64_t signers_seeds_len
);

// 账户操作
uint64_t sol_create_program_address(
    const SolSignerSeed *seeds,
    uint64_t seeds_len,
    const uint8_t *program_id,
    uint8_t *address
);

// 系统变量访问
uint64_t sol_get_clock_sysvar(void *ret);
uint64_t sol_get_rent_sysvar(void *ret);
uint64_t sol_get_epoch_schedule_sysvar(void *ret);
```

## 数据对齐要求

### 基本对齐规则
- 所有数据必须按 8 字节对齐
- Pubkey（32 字节）必须 8 字节对齐
- u64 类型必须 8 字节对齐
- 指针必须 8 字节对齐

### 结构体对齐示例
```zig
// Zig 中的对齐声明
pub const AccountInfo = extern struct {
    key: [32]u8 align(8),        // Pubkey
    owner: [32]u8 align(8),       // Pubkey
    lamports: u64 align(8),
    data_len: u64 align(8),
    data: [*]u8 align(8),
    executable: u8,
    _padding1: [7]u8,
    rent_epoch: u64 align(8),
};
```

## BPF 特定要求

### 指令限制
- 不支持浮点运算
- 不支持动态链接
- 限制的指令集（eBPF）

### 寄存器使用
- R0: 返回值
- R1-R5: 函数参数
- R6-R9: 被调用者保存
- R10: 只读栈指针
- R11: 特殊用途（BPF 相关）

### 调用约定
- 参数通过寄存器传递（最多 5 个）
- 超过 5 个参数通过栈传递
- 返回值在 R0

## 序列化格式

### Borsh（推荐）
- 确定性序列化
- 紧凑的二进制格式
- 跨语言支持

### 布局示例
```
// Transfer 指令
┌────────────┐
│ variant(u8)│ 1 byte - 指令类型
├────────────┤
│ amount(u64)│ 8 bytes - 转账金额
└────────────┘
```

## 错误处理

### 返回码
- 0: 成功
- 非 0: 错误（自定义错误码）

### 程序错误范围
- 自定义错误：0x00000000 - 0xFFFFFFFF
- 系统错误：0x100000000 及以上

## Zig 实现要点

### 1. 导出入口点
```zig
export fn entrypoint(input: [*]const u8) callconv(.C) u64 {
    // 解析输入
    // 处理指令
    // 返回结果
}
```

### 2. 链接脚本
需要自定义链接脚本确保：
- 正确的内存布局
- 符合 BPF 加载器要求
- 适当的节（section）放置

### 3. 优化设置
```zig
// build.zig 中的优化设置
.optimize = .ReleaseSmall,  // 最小化代码大小
.strip = true,              // 移除调试信息
```

## 测试和验证

### 本地测试
1. 使用 `solana-test-validator`
2. 部署 BPF 程序
3. 发送测试交易

### 验证工具
- `rbpf`: Rust BPF 虚拟机
- `solana program dump`: 导出部署的程序
- `objdump`: 检查生成的 BPF 代码