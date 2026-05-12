# solana-program-sdk-zig v2 Roadmap

## 目标

基于 Pinocchio (Rust) 的零拷贝、懒解析、极致 CU 优化理念，重构 solana-program-sdk-zig，使其成为 Solana Zig 生态中最高效的底层 SDK + 构建工具链。

## 核心设计原则

1. **Zero-Copy** — 所有数据直接引用运行时输入缓冲区，不做任何拷贝
2. **Lazy Parsing** — 按需解析 account，不预分配，不浪费 CU
3. **Zero-Deps** — 零外部依赖（移除 base58），纯 Zig 实现
4. **Dual Target** — 同时支持 `sbf` (solana-zig fork) 和 `bpfel` (stock Zig)
5. **CU Optimized** — 分支预测、强制内联、最小化指令数
6. **Comptime First** — 最大化编译时计算，减少运行时开销

---

## Phase 1: 核心类型重构

### 1.1 创建 `src/pubkey.zig`

**目标**: 替换 `src/public_key.zig`，内联 Base58 编解码，零外部依赖

**内容**:
```zig
pub const Pubkey = [32]u8;
pub const PUBKEY_BYTES: usize = 32;

// 编译时 Base58 解码（内联实现，无外部依赖）
pub fn comptimeFromBase58(comptime encoded: []const u8) Pubkey;

// 运行时 Base58 编码（CU 敏感场景避免使用）
pub fn encodeBase58(bytes: *const Pubkey, out: *[44]u8) void;

// 公钥比较
pub inline fn pubkeyEq(a: *const Pubkey, b: *const Pubkey) bool;

// 检查是否在曲线上（用于 PDA 验证）
pub fn isPointOnCurve(pubkey: *const Pubkey) bool;
```

**删除**: `src/public_key.zig`

---

### 1.2 重写 `src/account.zig`

**目标**: 零拷贝 AccountInfo，直接映射 Solana 运行时内存布局

**参考**: Pinocchio `RuntimeAccount` / zignocchio `Account`

**新设计**:
```zig
/// 直接映射 Solana 运行时内存布局
/// 内存结构: [Account header][data][padding(10KB)][align]
pub const Account = extern struct {
    // Borrow state (bit-packed)
    // Bits 7-4: lamport borrows (1 mut flag + 3 count bits)
    // Bits 3-0: data borrows (1 mut flag + 3 count bits)
    // Initial: 0xFF (NOT_BORROWED)
    borrow_state: u8,
    
    is_signer: u8,
    is_writable: u8,
    executable: u8,
    
    // 4 bytes: original_data_len (u32 LE, for resize validation)
    // 或 padding (当不支持 resize 时)
    _padding: [4]u8,
    
    key: Pubkey,
    owner: Pubkey,
    lamports: u64,
    data_len: u64,
    // data follows immediately in memory
};

/// 零拷贝 account 视图 — 直接指向运行时缓冲区
pub const AccountInfo = struct {
    ptr: *Account,
    
    // === 内联访问器（强制内联，零开销）===
    pub inline fn key(self: AccountInfo) *const Pubkey;
    pub inline fn owner(self: AccountInfo) *const Pubkey;
    pub inline fn lamports(self: AccountInfo) u64;
    pub inline fn dataLen(self: AccountInfo) usize;
    pub inline fn isSigner(self: AccountInfo) bool;
    pub inline fn isWritable(self: AccountInfo) bool;
    pub inline fn executable(self: AccountInfo) bool;
    
    // === 数据访问（零拷贝）===
    pub inline fn dataPtr(self: AccountInfo) [*]u8;
    pub inline fn data(self: AccountInfo) []u8;
    
    // === Borrow 检查（可选，CU 敏感场景可跳过）===
    pub fn tryBorrowData(self: AccountInfo) ProgramError!Ref([]const u8);
    pub fn tryBorrowMutData(self: AccountInfo) ProgramError!RefMut([]u8);
    pub fn tryBorrowLamports(self: AccountInfo) ProgramError!Ref(*const u64);
    pub fn tryBorrowMutLamports(self: AccountInfo) ProgramError!RefMut(*u64);
    
    // === 不安全的直接访问（最高性能）===
    pub inline fn dataUnchecked(self: AccountInfo) []u8;
    pub inline fn lamportsUnchecked(self: AccountInfo) *u64;
};

/// RAII 不可变借用守卫
pub fn Ref(comptime T: type) type {
    return struct {
        value: T,
        state: *u8,
        borrow_shift: u8,
        pub fn release(self: *@This()) void,
    };
}

/// RAII 可变借用守卫
pub fn RefMut(comptime T: type) type {
    return struct {
        value: T,
        state: *u8,
        borrow_bitmask: u8,
        pub fn release(self: *@This()) void,
    };
}
```

**常量**:
```zig
pub const NON_DUP_MARKER: u8 = 0xFF;
pub const MAX_PERMITTED_DATA_INCREASE: usize = 10 * 1024;
pub const MAX_TX_ACCOUNTS: usize = 256; // u8::MAX
pub const BPF_ALIGN_OF_U128: usize = 8;
```

---

### 1.3 创建 `src/program_error.zig`

**目标**: 标准错误类型，匹配 Rust solana-program 错误码

**内容**:
```zig
/// 程序执行错误 — 匹配 Rust solana-program 错误码
pub const ProgramError = error{
    Custom,                    // 0
    InvalidArgument,           // 1
    InvalidInstructionData,    // 2
    InvalidAccountData,        // 3
    AccountDataTooSmall,       // 4
    InsufficientFunds,         // 5
    IncorrectProgramId,        // 6
    MissingRequiredSignature,  // 7
    AccountAlreadyInitialized, // 8
    UninitializedAccount,      // 9
    NotEnoughAccountKeys,      // 10
    AccountBorrowFailed,       // 11
    MaxSeedLengthExceeded,     // 12
    InvalidSeeds,              // 13
    InvalidRealloc,            // 14
    ArithmeticOverflow,        // 15
    ImmutableAccount,          // 16
    IncorrectAuthority,        // 17
};

/// 程序结果类型
pub const ProgramResult = ProgramError!void;

/// 成功返回值
pub const SUCCESS: u64 = 0;

/// 将错误转换为 u64 错误码
pub fn errorToU64(err: ProgramError) u64;
```

---

## Phase 2: Entrypoint 重构

### 2.1 创建 `src/entrypoint.zig`

**目标**: 懒解析 entrypoint，按需解析 account

**参考**: Pinocchio `lazy_program_entrypoint` / zignocchio `entrypoint`

**内容**:
```zig
/// 入口点函数签名
pub const EntrypointFn = *const fn (
    program_id: *const Pubkey,
    accounts: []AccountInfo,
    instruction_data: []const u8,
) ProgramResult;

/// 创建标准入口点（全量解析，兼容现有代码）
pub fn entrypoint(
    comptime max_accounts: usize,
    comptime process_instruction: EntrypointFn,
) fn ([*]u8) callconv(.c) u64;

/// 创建懒解析入口点（推荐，最优 CU）
/// 只解析需要的 account，不预分配数组
pub fn lazyEntrypoint(
    comptime process_instruction: fn (
        context: *InstructionContext,
    ) ProgramResult,
) fn ([*]u8) callconv(.c) u64;

/// 懒解析上下文
pub const InstructionContext = struct {
    ptr: [*]u8,
    num_accounts: u64,
    parsed_count: u64,
    
    /// 获取剩余未解析 account 数量
    pub fn remaining(self: InstructionContext) u64;
    
    /// 解析下一个 account
    pub fn nextAccount(self: *InstructionContext) ?AccountInfo;
    
    /// 获取 instruction data
    pub fn instructionData(self: *InstructionContext) []const u8;
    
    /// 获取 program id
    pub fn programId(self: *InstructionContext) *const Pubkey;
    
    /// 跳过指定数量的 account（不解析）
    pub fn skipAccounts(self: *InstructionContext, count: u64) void;
};

/// 低层解析函数（供自定义 entrypoint 使用）
pub fn deserialize(
    input: [*]u8,
    accounts_buffer: []AccountInfo,
) struct { *const Pubkey, []AccountInfo, []const u8 };
```

**使用示例**:
```zig
// 标准入口点
export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sdk.entrypoint(10, processInstruction), .{input});
}

fn processInstruction(
    program_id: *const Pubkey,
    accounts: []AccountInfo,
    data: []const u8,
) ProgramResult {
    // ...
}

// 懒解析入口点
export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sdk.lazyEntrypoint(processInstruction), .{input});
}

fn processInstruction(context: *sdk.InstructionContext) ProgramResult {
    const payer = context.nextAccount() orelse return error.NotEnoughAccountKeys;
    const account = context.nextAccount() orelse return error.NotEnoughAccountKeys;
    const data = try context.instructionData();
    // ...
}
```

**删除**: `src/context.zig`

---

## Phase 3: 基础设施

### 3.1 创建 `src/hint.zig`

**目标**: 分支预测优化

**参考**: Pinocchio `hint` 模块

**内容**:
```zig
/// 冷路径提示 — 告诉编译器此分支不太可能执行
pub inline fn coldPath() void {}

/// 告诉编译器 b 很可能为 true
pub inline fn likely(b: bool) bool {
    if (b) return true;
    coldPath();
    return false;
}

/// 告诉编译器 b 很可能为 false
pub inline fn unlikely(b: bool) bool {
    if (b) {
        coldPath();
        return true;
    }
    return false;
}
```

---

### 3.2 创建 `src/memory.zig`

**目标**: 内存操作 syscall 包装

**参考**: Rust solana-program `program_memory`

**内容**:
```zig
/// 安全的内存拷贝（使用 sol_memcpy_ syscall 或内联）
pub inline fn memcpy(dst: [*]u8, src: [*]const u8, n: usize) void;

/// 安全的内存设置（使用 sol_memset_ syscall 或内联）
pub inline fn memset(dst: [*]u8, c: u8, n: usize) void;

/// 内存比较
pub inline fn memcmp(a: [*]const u8, b: [*]const u8, n: usize) i32;

/// 零拷贝类型转换
pub inline fn fromBytes(comptime T: type, bytes: []const u8) *const T;
pub inline fn fromBytesMut(comptime T: type, bytes: []u8) *T;
```

---

### 3.3 优化 `src/allocator.zig`

**目标**: 简化 BumpAllocator，移除 ReverseFixedBufferAllocator

**新设计**:
```zig
/// 简单的 bump allocator
/// 从低地址向高地址分配
pub const BumpAllocator = struct {
    buffer: []u8,
    end_index: usize, // 存储在 buffer 前 8 字节
    
    pub fn init(buffer: []u8) BumpAllocator;
    pub fn allocator(self: *BumpAllocator) std.mem.Allocator;
    pub fn reset(self: *BumpAllocator) void;
    
    // 直接分配（不通过 Allocator 接口，更高性能）
    pub fn alloc(self: *BumpAllocator, n: usize, alignment: usize) ?[*]u8;
    pub fn free(self: *BumpAllocator, buf: []u8) void; // 只有最后分配的可释放
};

/// 堆起始地址（Solana BPF 约定）
pub const HEAP_START_ADDRESS: u64 = 0x300000000;

/// 堆长度
pub const HEAP_LENGTH: usize = 32 * 1024;

/// 默认全局 allocator
pub var default_allocator: BumpAllocator = undefined;
```

**删除**: `ReverseFixedBufferAllocator`（简化 API）

---

## Phase 4: CPI 和程序包装

### 4.1 创建 `src/cpi.zig`

**目标**: 跨程序调用，从 `instruction.zig` 拆分

**内容**:
```zig
/// CPI Account 元数据
pub const AccountMeta = extern struct {
    pubkey: *const Pubkey,
    is_writable: bool,
    is_signer: bool,
};

/// CPI 指令
pub const Instruction = struct {
    program_id: *const Pubkey,
    accounts: []const AccountMeta,
    data: []const u8,
};

/// 调用另一个程序
pub fn invoke(
    instruction: *const Instruction,
    accounts: []const AccountInfo,
) ProgramResult;

/// 调用另一个程序（带 PDA 签名）
pub fn invokeSigned(
    instruction: *const Instruction,
    accounts: []const AccountInfo,
    signers_seeds: []const []const u8,
) ProgramResult;

/// 设置返回数据
pub fn setReturnData(data: []const u8) void;

/// 获取返回数据
pub fn getReturnData(buffer: []u8) ?struct { Pubkey, []const u8 };
```

---

### 4.2 创建 `src/pda.zig`

**目标**: PDA 计算，从 `pubkey.zig` 拆分

**内容**:
```zig
pub const MAX_SEEDS: usize = 16;
pub const MAX_SEED_LEN: usize = 32;

/// PDA 计算结果
pub const ProgramDerivedAddress = struct {
    address: Pubkey,
    bump_seed: u8,
};

/// 创建程序地址（编译时可用）
pub fn createProgramAddress(
    seeds: []const []const u8,
    program_id: *const Pubkey,
) ProgramError!Pubkey;

/// 查找程序地址（编译时可用）
pub fn findProgramAddress(
    seeds: []const []const u8,
    program_id: *const Pubkey,
) ProgramError!ProgramDerivedAddress;

/// 使用种子创建地址
pub fn createWithSeed(
    base: *const Pubkey,
    seed: []const u8,
    program_id: *const Pubkey,
) ProgramError!Pubkey;

/// 编译时版本
pub fn comptimeCreateProgramAddress(comptime seeds: anytype, comptime program_id: Pubkey) Pubkey;
pub fn comptimeFindProgramAddress(comptime seeds: anytype, comptime program_id: Pubkey) ProgramDerivedAddress;
```

---

### 4.3 创建 `src/system.zig`

**目标**: System Program CPI 包装

**参考**: zignocchio `system.zig` / Rust solana-program `system_instruction`

**内容**:
```zig
/// System Program ID (全零)
pub const SYSTEM_PROGRAM_ID: Pubkey = .{0} ** 32;

/// 获取 System Program ID（栈拷贝，避免 Zig 0.16 BPF 常量地址陷阱）
pub fn getSystemProgramId(out: *Pubkey) void;

/// 创建账户
pub fn createAccount(
    from: AccountInfo,
    to: AccountInfo,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
) ProgramResult;

/// 创建账户（带 PDA 签名）
pub fn createAccountSigned(
    from: AccountInfo,
    to: AccountInfo,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
    signers_seeds: []const []const u8,
) ProgramResult;

/// 转账
pub fn transfer(
    from: AccountInfo,
    to: AccountInfo,
    lamports: u64,
) ProgramResult;

/// 分配账户空间
pub fn allocate(
    account: AccountInfo,
    space: u64,
) ProgramResult;

/// 重新分配账户空间
pub fn realloc(
    account: AccountInfo,
    new_space: u64,
    zero_init: bool,
) ProgramResult;

/// 分配并赋值 owner
pub fn assign(
    account: AccountInfo,
    owner: *const Pubkey,
) ProgramResult;

/// 创建账户并分配空间（组合指令）
pub fn createAccountWithSeed(
    from: AccountInfo,
    to: AccountInfo,
    base: *const Pubkey,
    seed: []const u8,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
) ProgramResult;
```

---

### 4.4 创建 `src/sysvar.zig`

**目标**: Sysvar 访问器

**内容**:
```zig
/// Sysvar ID 前缀
pub const SYSVAR_ID: Pubkey = comptime blk: {
    var id: Pubkey = .{0} ** 32;
    id[0] = 'S';
    id[1] = 'y';
    id[2] = 's';
    id[3] = 'v';
    id[4] = 'a';
    id[5] = 'r';
    break :blk id;
};

/// 从账户获取 sysvar 数据
pub fn getSysvar(comptime T: type, account: AccountInfo) ProgramError!T;

/// Clock sysvar ID
pub const CLOCK_ID: Pubkey = ...;
/// EpochSchedule sysvar ID
pub const EPOCH_SCHEDULE_ID: Pubkey = ...;
/// Rent sysvar ID
pub const RENT_ID: Pubkey = ...;
/// SlotHashes sysvar ID
pub const SLOT_HASHES_ID: Pubkey = ...;
/// StakeHistory sysvar ID
pub const STAKE_HISTORY_ID: Pubkey = ...;
/// Instructions sysvar ID
pub const INSTRUCTIONS_ID: Pubkey = ...;
```

---

## Phase 5: 现有模块更新

### 5.1 更新 `src/instruction.zig`

**变更**: 移除 CPI 相关代码（移到 `cpi.zig`），保留 `InstructionData` helper

**保留**:
```zig
/// 指令数据序列化 helper
pub fn InstructionData(comptime Discriminant: type, comptime Data: type) type;
```

---

### 5.2 更新 `src/log.zig`

**变更**: 添加 CU 计数器

**新增**:
```zig
/// 获取剩余 CU
pub inline fn getRemainingComputeUnits() u64;

/// 格式化日志（避免重复实现）
pub fn logFormat(comptime fmt: []const u8, args: anytype) void;
```

---

### 5.3 更新 `src/root.zig`

**变更**: 更新所有导出

```zig
pub const entrypoint = @import("entrypoint.zig");
pub const account = @import("account.zig");
pub const pubkey = @import("pubkey.zig");
pub const program_error = @import("program_error.zig");
pub const log = @import("log.zig");
pub const memory = @import("memory.zig");
pub const cpi = @import("cpi.zig");
pub const system = @import("system.zig");
pub const sysvar = @import("sysvar.zig");
pub const pda = @import("pda.zig");
pub const hint = @import("hint.zig");
pub const allocator = @import("allocator.zig");

// 保留的现有模块
pub const clock = @import("clock.zig");
pub const rent = @import("rent.zig");
pub const hash = @import("hash.zig");
pub const slot_hashes = @import("slot_hashes.zig");
pub const blake3 = @import("blake3.zig");
pub const bpf = @import("bpf.zig");

// 类型别名
pub const Pubkey = pubkey.Pubkey;
pub const AccountInfo = account.AccountInfo;
pub const ProgramError = program_error.ProgramError;
pub const ProgramResult = program_error.ProgramResult;
pub const SUCCESS = program_error.SUCCESS;

// 常量
pub const lamports_per_sol = 1_000_000_000;

// 程序 ID
pub const native_loader_id = pubkey.comptimeFromBase58("NativeLoader1111111111111111111111111111111");
pub const incinerator_id = pubkey.comptimeFromBase58("1nc1nerator11111111111111111111111111111111");
// ...
```

---

## Phase 6: 构建系统更新

### 6.1 更新 `build.zig.zon`

**变更**: 移除 base58 依赖

```zig
.{
    .name = .solana_program_sdk,
    .version = "0.18.0", // 版本升级
    .minimum_zig_version = "0.16.0",
    .dependencies = .{}, // 零依赖
    // ...
}
```

### 6.2 保留 `build.zig`

**不变**: 构建工具链保持现有设计
- `buildProgram()` — sbf 目标（fork）
- `buildProgramElf2sbpf()` — bpfel 目标（stock）
- `has_sbf_target` — 编译时检测

---

## Phase 7: 测试和模板更新

### 7.1 更新单元测试

- 所有现有测试迁移到新 API
- 新增 borrow 检查测试
- 新增懒解析 entrypoint 测试
- 新增 System Program CPI 测试

### 7.2 更新 `program-test/`

- 使用新 entrypoint API
- 使用新 AccountInfo API
- 测试 borrow 检查

### 7.3 更新 `template/`

- 使用新 entrypoint API
- 更新示例代码

---

## 实施顺序

```
Week 1: Phase 1 + Phase 2
  - pubkey.zig (替换 public_key.zig)
  - account.zig (重写)
  - program_error.zig (新增)
  - entrypoint.zig (替换 context.zig)

Week 2: Phase 3 + Phase 4
  - hint.zig
  - memory.zig
  - allocator.zig (优化)
  - cpi.zig
  - pda.zig
  - system.zig
  - sysvar.zig

Week 3: Phase 5 + Phase 6
  - 更新现有模块
  - 更新 root.zig
  - 更新 build.zig.zon
  - 清理旧文件

Week 4: Phase 7
  - 更新测试
  - 更新 program-test
  - 更新 template
  - 文档更新
```

---

## 与 Pinocchio 的功能对等检查表

| Pinocchio 功能 | solana-program-sdk-zig v2 | 状态 |
|---------------|--------------------------|------|
| `entrypoint!` | `entrypoint()` | ✅ 计划 |
| `lazy_program_entrypoint!` | `lazyEntrypoint()` | ✅ 计划 |
| `AccountView` | `AccountInfo` | ✅ 计划 |
| `Address` | `Pubkey` | ✅ 计划 |
| `ProgramResult` | `ProgramResult` | ✅ 计划 |
| `default_allocator!` | `BumpAllocator` | ✅ 计划 |
| `no_allocator!` | 可选不提供 | ✅ 计划 |
| `nostd_panic_handler!` | Zig 内置 panic handler | ✅ 已有 |
| `system_instruction` | `system.zig` | ✅ 计划 |
| `sysvar::*` | `sysvar.zig` + 子模块 | ✅ 计划 |
| `cpi::*` | `cpi.zig` | ✅ 计划 |
| `hint::*` | `hint.zig` | ✅ 计划 |
| `program_memory` | `memory.zig` | ✅ 计划 |
| `account-resize` feature | `realloc` 方法 | ✅ 计划 |

---

## 性能目标

| 指标 | 当前 | 目标 | Pinocchio 参考 |
|------|------|------|---------------|
| Entrypoint CU (无操作) | ~100 CU | ~50 CU | ~30 CU |
| Account 解析 CU / account | ~10 CU | ~5 CU | ~3 CU |
| CPI 基础开销 | ~50 CU | ~30 CU | ~20 CU |
| 二进制大小 (空程序) | ~2KB | ~1.5KB | ~1KB |

---

## 风险和对冲

| 风险 | 影响 | 对冲措施 |
|------|------|---------|
| Zig 0.16 BPF 后端不稳定 | 运行时崩溃 | 提供 `nostd_panic_handler` 等价，详细文档 |
| 懒解析复杂度 | 开发体验下降 | 保留全量解析 `entrypoint()` 作为备选 |
| Borrow 检查开销 | CU 增加 | 提供 `Unchecked` 方法绕过检查 |
| 与 zignocchio 竞争 | 生态分裂 | 明确分工：我们 = 底层 SDK + 构建工具 |

---

*最后更新: 2026-05-12*
*目标版本: v0.18.0*
*状态: 性能优化收尾。三条 vault 指令全部 ≤ Pinocchio。*

---

## 附录：Anchor 风格地基（已落地）

> 哲学：**给地基，不给框架**。每个组件单独可用，互不强制。

| 模块 | 文件 | 作用 | 状态 |
|---|---|---|---|
| `discriminator` | `src/discriminator.zig` | 8 字节 sha256 类型标签，comptime 折叠 | ✅ |
| `TypedAccount(T)` | `src/typed_account.zig` | 零拷贝类型化账户视图，绑定时 enforce discriminator | ✅ |
| `ErrorCode(E)` | `src/error_code.zig` | 自定义 `enum(u32)` 错误码 → 运行时 `Custom(N)` wire format | ✅ |
| `system.createRentExempt` | `src/system.zig` | 一行创建账户：自动查 Rent sysvar + 可选 PDA 签名 | ✅ |
| Native program 常量 | `src/root.zig` | spl_token / token-2022 / ATA / BPF loader / memo IDs | ✅ |
| `verifyPda` / `verifyPdaCanonical` | `src/pda.zig` | Anchor `seeds = [...], bump` 等价；用储存 bump 时 ~1500 CU | ✅ |
| `TypedAccount.requireHasOne` | `src/typed_account.zig` | Anchor `has_one = field` 等价；comptime 字段偏移折叠 | ✅ |
| `event.emit` | `src/event.zig` | 结构化事件 → `sol_log_data`；`extern struct` + comptime discriminator | ✅ |
| `examples/vault.zig` | — | 把以上全部组合的 demo program | ✅ |

未做（哲学不符）:
- 借用安全 (`Ref<T>` / `RefMut<T>`) — Pinocchio 有，我们不做，工具箱哲学
- 约束 DSL (整体 `#[account(...)]` 宏) — 留给未来 Anchor-for-Zig 框架

### 附录：Anchor-style 三 ix vault 的实测 CU

`examples/vault.zig` 同时演示 `parseAccounts`, `TypedAccount(VaultState)`,
`discriminatorFor`, `ErrorCode`, `system.createRentExempt`,
`comptimeFromBase58` (PROGRAM_ID), `verifyPda`, `requireHasOneWith`,
`sol.emit`。`BPF_OUT_DIR=zig-out/lib cargo run -- vault_*` 实测：

| 指令 | Zig (this SDK) | Pinocchio | Anchor (典型) | 备注 |
|---|---:|---:|---:|---|
| `vault.initialize` | **1334 CU** | 1351 CU | 8000–10000 CU | client-supplied bump + system_program CPI 创建 + 写 discriminator |
| `vault.deposit`    | **1543 CU** | 1565 CU | 5000–8000 CU  | system_program transfer CPI + balance bump + 24-byte emit |
| `vault.withdraw`   | **1866 CU** | 1949 CU | 4000–6000 CU  | has_one + verifyPda(储存 bump) + 直接 lamport 转移 + 24-byte emit |

**🎯 三条指令全部反超 Pinocchio。** initialize 优势 17 CU，deposit 优势 22 CU，withdraw 优势 83 CU。

整轮性能 journey（`f0ece32` → `0c7586b` → `79d3161`）累计：

| 指令 | 最初  | 最终  | Δ          | vs Pinocchio  |
|------|------:|------:|-----------:|--------------:|
| initialize | 4850 (pre-bump) → 1823 → 1353 | −3497 (−72%) | +2 (打平) |
| deposit    | 1583 → 1544 | −39 (−2.5%) | **−21 (反超)** |
| withdraw   | 1887 → 1877 | −10 (−0.5%) | **−72 (反超)** |

**指令集层面优化（最后一轮，−25 CU 总计）**：

通过反汇编 vault.so 直接读 BPF 字节码，找到 LLVM 没消除的开销：

- **`pubkeyEqComptime` xor-or 重构**（−6 CU/call）— `pubkey_cmp_comptime`
  从 30 → 24 CU。把 `a == e && a == e && ...` 改成
  `(a ^ e) | (a ^ e) | ... == 0`，让 LLVM 把 4 个 short-circuit 分支合并
  成 1 个 final compare。**只对 comptime RHS 有效**——runtime-vs-runtime
  反而 +9 CU（BPFv2 的 cmp+jmp fusion 不喜欢 ALU 链）。
- **vault.zig 消除 32 字节 pubkey 局部副本**（init −15 / withdraw −10 CU）—
  把 `const auth_key = authority.key().*;` 删掉，直接传 `authority.key()[0..]`
  给 `Seed.from`。auth_key 局部变量强制 LLVM 把 pubkey 拷到栈上（4 ldxdw + 4 stxdw）。
- **`TypedAccount.initialize` 单次 store**（−3 CU）— 把 "写 value 再覆盖 disc"
  改成 "rebuild value with disc 设好，单次 store"。消除冗余的 8 字节
  disc 二次写入。

`pubkeyEqAligned` (runtime-vs-runtime) 试了同样的 xor-or 重构 — 实测
`pubkey_cmp_unchecked` 从 18 → 27 CU（+9 CU regression）。结论：BPFv2 的
**comptime 立即数比较** 喜欢 xor-or（少分支），**runtime 寄存器比较**
喜欢 and-chain（cmp+jmp fusion）。两种 shape 都要保留。

**关键优化（按贡献大小）**：

1. **`vault.initialize` 客户端 bump**（−3027 CU）— 把 `findProgramAddress`
   的 256 次循环从链上移到客户端。Client 在交易构造阶段调用
   `Pubkey::find_program_address`（host 侧，免费）得到 canonical bump，
   塞进 ix data 第二字节，program 侧只用 `createProgramAddress`
   （一次 SHA-256，~1500 CU）。安全保证来自 system_program create CPI
   的 signer-seed 证明：client 谎报 bump 直接 abort。

2. **`Rent.getMinimumBalance` 整数快路径**（−283 CU）— BPF 软件模拟
   f64 乘法 ~150-300 CU/op。改用整数路径（位比较 `exemption_threshold`
   是否为 IEEE-754 的 2.0 模式）。`src/rent.zig`

3. **`createRentExemptComptimeRaw` comptime rent 折叠**（−161 CU）—
   `space` 是 comptime 时，rent 直接 build-time 折叠成 u64 立即数。
   绕过 `sol_get_rent_sysvar` syscall。`src/system.zig`

4. **`CpiAccountInfo.fromPtr` u32 flag 合并 copy**（−27 CU/CPI）—
   把 `is_signer/is_writable/is_executable` 三个 byte copy 合并成
   一次 u32 load+store（多 copy 一个 padding 字节无害）。Pinocchio 的
   `init_from_account_view` 早就这么做了。`src/account.zig`

5. **`parseAccountsUnchecked`**（−70 CU/parse）— 跳过 dup-aware tagged
   union 分支，账户结构固定的程序适用。`src/entrypoint.zig`

6. **`TypedAccount.bindUnchecked`**（−14 CU on deposit, −8 on withdraw）
   — `assertOwnerComptime` 已经证明账户归属，discriminator 检查冗余。

7. **Event payload 收缩**（−100 CU/emit）— 删掉事件中冗余的 pubkey
   字段（off-chain indexer 可从 tx 账户列表恢复）。`fdb65f2`

8. **`sol.cpi.Seed` / `cpi.Signer` 直传 ABI**（0 CU 实测，但 API 清晰）
   — extern struct 严格匹配 `SolSignerSeedC` / `SolSignerSeedsC` 布局，
   跳过 staging copy。LLVM 在 seed 数量 comptime 已知时早就 SROA 掉了。

`examples/token_dispatch.zig`（u32 tag + u64 payload, 2 个账户 slot，
parse-then-dispatch）：**37–38 CU** for transfer / burn / mint
（用 `parseAccountsUnchecked`；safe `parseAccounts` 是 97–100 CU，
dup-aware tagged union 多花 ~63 CU）。之前的 "13 CU" 数据是隐藏 bug
导致的 noop —— `instructionDataUnchecked` 在账户解析之前调用，
读到的 `data_len` 是账户 0 的垃圾值，三个 if 分支全部 falsy，函数静默
return。现已通过 parse-then-dispatch + 新增的 `parseAccountsUnchecked`
快路径修复。
