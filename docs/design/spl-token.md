# SPL Token 设计文档

> 本文档描述 SPL Token 和 Associated Token Account 的 Zig 实现设计。

## 概述

SPL Token 是 Solana 上最核心的代币程序，约占链上交易的 30%。本实现提供：

1. **状态类型** - Mint、Account、Multisig 的序列化/反序列化
2. **指令构建器** - 25 个指令的客户端构建函数
3. **ATA 支持** - Associated Token Account 地址推导和指令

## Program IDs

| 程序 | Program ID | 用途 |
|------|-----------|------|
| SPL Token | `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA` | 代币操作 |
| Associated Token Account | `ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL` | ATA 管理 |

## 数据结构设计

### COption<T> 编码

Solana 使用特殊的 `COption` 类型表示可选值，与 Zig/Rust 的 `?T` 或 `Option<T>` 不同：

```
COption<T> = [tag: u32 little-endian][value: T]

tag = 0 -> None (value bytes are zeroed)
tag = 1 -> Some(value)
```

**实现要点**：
- 4 字节对齐的 tag，不是 1 字节
- tag 使用 little-endian 编码
- None 时 value 字节全为 0

```zig
pub fn COption(comptime T: type) type {
    return struct {
        const Self = @This();
        
        tag: u32,
        value: T,
        
        pub const none: Self = .{ .tag = 0, .value = std.mem.zeroes(T) };
        
        pub fn some(value: T) Self {
            return .{ .tag = 1, .value = value };
        }
        
        pub fn isSome(self: Self) bool {
            return self.tag == 1;
        }
        
        pub fn unwrap(self: Self) ?T {
            return if (self.tag == 1) self.value else null;
        }
    };
}
```

### Mint 结构体 (82 bytes)

```
┌────────────────────────────────────────────────────────────────┐
│ Offset │ Size │ Field              │ Type                      │
├────────┼──────┼────────────────────┼───────────────────────────┤
│ 0      │ 36   │ mint_authority     │ COption<PublicKey>        │
│ 36     │ 8    │ supply             │ u64 (little-endian)       │
│ 44     │ 1    │ decimals           │ u8                        │
│ 45     │ 1    │ is_initialized     │ bool (0 or 1)             │
│ 46     │ 36   │ freeze_authority   │ COption<PublicKey>        │
└────────┴──────┴────────────────────┴───────────────────────────┘
Total: 82 bytes
```

**Rust 源码**: https://github.com/solana-program/token/blob/master/interface/src/state.rs#L17-L35

```zig
pub const Mint = struct {
    mint_authority: COption(PublicKey),
    supply: u64,
    decimals: u8,
    is_initialized: bool,
    freeze_authority: COption(PublicKey),
    
    pub const LEN: usize = 82;
    
    pub fn pack(self: Mint, dst: *[LEN]u8) void {
        // ... 序列化实现
    }
    
    pub fn unpack(src: *const [LEN]u8) !Mint {
        // ... 反序列化实现
    }
};
```

### Account 结构体 (165 bytes)

```
┌────────────────────────────────────────────────────────────────┐
│ Offset │ Size │ Field              │ Type                      │
├────────┼──────┼────────────────────┼───────────────────────────┤
│ 0      │ 32   │ mint               │ PublicKey                 │
│ 32     │ 32   │ owner              │ PublicKey                 │
│ 64     │ 8    │ amount             │ u64                       │
│ 72     │ 36   │ delegate           │ COption<PublicKey>        │
│ 108    │ 1    │ state              │ AccountState (u8)         │
│ 109    │ 12   │ is_native          │ COption<u64>              │
│ 121    │ 8    │ delegated_amount   │ u64                       │
│ 129    │ 36   │ close_authority    │ COption<PublicKey>        │
└────────┴──────┴────────────────────┴───────────────────────────┘
Total: 165 bytes
```

**关键偏移量**：
- `ACCOUNT_INITIALIZED_INDEX = 108` - 用于快速检查账户是否已初始化

**Rust 源码**: https://github.com/solana-program/token/blob/master/interface/src/state.rs#L58-L90

### AccountState 枚举

```zig
pub const AccountState = enum(u8) {
    Uninitialized = 0,
    Initialized = 1,
    Frozen = 2,
};
```

### Multisig 结构体 (355 bytes)

```
┌────────────────────────────────────────────────────────────────┐
│ Offset │ Size │ Field              │ Type                      │
├────────┼──────┼────────────────────┼───────────────────────────┤
│ 0      │ 1    │ m                  │ u8 (required signers)     │
│ 1      │ 1    │ n                  │ u8 (valid signers)        │
│ 2      │ 1    │ is_initialized     │ bool                      │
│ 3      │ 352  │ signers            │ [11]PublicKey             │
└────────┴──────┴────────────────────┴───────────────────────────┘
Total: 355 bytes
```

**常量**：
- `MAX_SIGNERS = 11` - 最大签名者数量

## 指令设计

### 指令枚举

```zig
pub const TokenInstruction = enum(u8) {
    InitializeMint = 0,
    InitializeAccount = 1,
    InitializeMultisig = 2,
    Transfer = 3,
    Approve = 4,
    Revoke = 5,
    SetAuthority = 6,
    MintTo = 7,
    Burn = 8,
    CloseAccount = 9,
    FreezeAccount = 10,
    ThawAccount = 11,
    TransferChecked = 12,
    ApproveChecked = 13,
    MintToChecked = 14,
    BurnChecked = 15,
    InitializeAccount2 = 16,
    SyncNative = 17,
    InitializeAccount3 = 18,
    InitializeMultisig2 = 19,
    InitializeMint2 = 20,
    GetAccountDataSize = 21,
    InitializeImmutableOwner = 22,
    AmountToUiAmount = 23,
    UiAmountToAmount = 24,
};
```

### 指令数据格式

#### InitializeMint (ID=0)

```
[0]: instruction_type (u8) = 0
[1]: decimals (u8)
[2..34]: mint_authority (PublicKey)
[34]: freeze_authority_option (u8) - 0=None, 1=Some
[35..67]: freeze_authority (PublicKey, if option=1)
```

#### Transfer (ID=3)

```
[0]: instruction_type (u8) = 3
[1..9]: amount (u64, little-endian)
```

#### TransferChecked (ID=12)

```
[0]: instruction_type (u8) = 12
[1..9]: amount (u64, little-endian)
[9]: decimals (u8)
```

### 指令构建器 API

```zig
/// Create a Transfer instruction
pub fn transfer(
    source: PublicKey,
    destination: PublicKey,
    owner: PublicKey,
    amount: u64,
) Instruction {
    const data = [_]u8{
        @intFromEnum(TokenInstruction.Transfer),
    } ++ std.mem.toBytes(amount);
    
    return .{
        .program_id = TOKEN_PROGRAM_ID,
        .accounts = &[_]AccountMeta{
            .{ .pubkey = source, .is_signer = false, .is_writable = true },
            .{ .pubkey = destination, .is_signer = false, .is_writable = true },
            .{ .pubkey = owner, .is_signer = true, .is_writable = false },
        },
        .data = &data,
    };
}
```

## Associated Token Account 设计

### PDA 推导

ATA 地址使用以下种子推导：

```zig
pub fn findAssociatedTokenAddress(
    wallet: PublicKey,
    mint: PublicKey,
) struct { address: PublicKey, bump: u8 } {
    return PublicKey.findProgramAddress(
        &[_][]const u8{
            &wallet.bytes,
            &TOKEN_PROGRAM_ID.bytes,
            &mint.bytes,
        },
        ASSOCIATED_TOKEN_PROGRAM_ID,
    );
}
```

**种子顺序**（关键！）：
1. wallet address
2. token program id
3. mint address

### ATA 指令

| ID | 指令 | 描述 |
|----|------|------|
| 0 | Create | 创建 ATA（如已存在则失败） |
| 1 | CreateIdempotent | 创建 ATA（如已存在则成功）**推荐** |
| 2 | RecoverNested | 恢复嵌套 ATA 中的代币 |

## 错误处理

### TokenError 枚举

```zig
pub const TokenError = enum(u32) {
    NotRentExempt = 0,
    InsufficientFunds = 1,
    InvalidMint = 2,
    MintMismatch = 3,
    OwnerMismatch = 4,
    FixedSupply = 5,
    AlreadyInUse = 6,
    InvalidNumberOfProvidedSigners = 7,
    InvalidNumberOfRequiredSigners = 8,
    UninitializedState = 9,
    NativeNotSupported = 10,
    NonNativeHasBalance = 11,
    InvalidInstruction = 12,
    InvalidState = 13,
    Overflow = 14,
    AuthorityTypeNotSupported = 15,
    MintCannotFreeze = 16,
    AccountFrozen = 17,
    MintDecimalsMismatch = 18,
    NonNativeNotSupported = 19,
};
```

## 文件结构

```
client/src/spl/
├── token/
│   ├── state.zig        # Mint, Account, Multisig, COption
│   ├── instruction.zig  # 25 个指令构建器
│   ├── error.zig        # TokenError
│   └── root.zig         # 模块导出
├── associated_token.zig # ATA 推导和指令
└── root.zig             # SPL 模块导出
```

## 测试策略

### 单元测试

每个模块需要覆盖：

1. **序列化测试** - pack/unpack 往返
2. **边界测试** - COption None/Some、AccountState 各值
3. **兼容性测试** - 与 Rust SDK 序列化结果对比

### 测试向量

从 Rust SDK 生成的测试向量用于验证序列化兼容性：

```zig
test "Mint serialization matches Rust SDK" {
    const mint = Mint{
        .mint_authority = COption(PublicKey).some(test_pubkey),
        .supply = 1000000,
        .decimals = 6,
        .is_initialized = true,
        .freeze_authority = COption(PublicKey).none,
    };
    
    var buffer: [Mint.LEN]u8 = undefined;
    mint.pack(&buffer);
    
    // 与 Rust SDK 生成的字节比较
    try std.testing.expectEqualSlices(u8, &expected_bytes, &buffer);
}
```

## 与 Rust SDK 的对应关系

| Zig 模块 | Rust Crate | 源码链接 |
|----------|-----------|---------|
| `spl/token/state.zig` | `spl-token-interface` | [state.rs](https://github.com/solana-program/token/blob/master/interface/src/state.rs) |
| `spl/token/instruction.zig` | `spl-token-interface` | [instruction.rs](https://github.com/solana-program/token/blob/master/interface/src/instruction.rs) |
| `spl/token/error.zig` | `spl-token-interface` | [error.rs](https://github.com/solana-program/token/blob/master/interface/src/error.rs) |
| `spl/associated_token.zig` | `spl-associated-token-account-interface` | [instruction.rs](https://github.com/solana-program/associated-token-account/blob/master/interface/src/instruction.rs) |

## 使用示例

### 创建代币转账指令

```zig
const spl = @import("spl");

// 创建转账指令
const transfer_ix = spl.token.transfer(
    source_account,
    destination_account,
    owner,
    1000000, // 转账数量
);

// 添加到交易
try builder.addInstruction(transfer_ix);
```

### 查找 ATA 地址

```zig
const spl = @import("spl");

// 获取 ATA 地址
const result = spl.associated_token.findAssociatedTokenAddress(
    wallet_pubkey,
    mint_pubkey,
);

const ata_address = result.address;
const bump = result.bump;
```

### 创建 ATA

```zig
const spl = @import("spl");

// 创建 ATA 指令（幂等版本，推荐）
const create_ata_ix = spl.associated_token.createIdempotent(
    payer,
    wallet,
    mint,
);
```
