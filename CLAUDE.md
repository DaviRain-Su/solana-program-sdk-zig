# Solana Program SDK for Zig

## 项目概述

本项目旨在创建一个用 Zig 语言开发 Solana 智能合约的 SDK。这将为开发者提供一个高性能、内存安全的替代方案，相比 Rust 和 C 更加简洁。

## 技术调研

### 1. Zig 语言特性分析

**优势：**
- 编译时内存安全
- 无隐式内存分配
- 交叉编译能力强
- C ABI 兼容性好
- 编译时代码生成能力强
- 错误处理机制清晰

**挑战：**
- 生态系统相对较新
- Solana 官方无 Zig SDK
- 需要手动实现底层接口

### 2. Solana 程序要求

**基本要求：**
- BPF 目标架构支持
- 特定的内存布局
- 系统调用接口
- 账户数据序列化/反序列化
- 指令处理入口点

**技术细节：**
- 入口点：`entrypoint!` 宏等价实现
- 内存对齐：8 字节边界
- 堆栈大小限制：4KB
- 堆内存限制：32KB
- CPI（跨程序调用）支持

### 3. 实现可行性分析

**可行性论证：**
1. Zig 支持 BPF 目标：`zig build-lib -target bpf-freestanding`
2. 可以直接调用 Solana 系统调用
3. 内存管理完全可控
4. 可以生成符合 Solana 要求的 ELF 文件

## 架构设计

### 核心模块规划

```
solana-program-sdk-zig/
├── src/
│   ├── entrypoint.zig      # 程序入口点
│   ├── account.zig          # 账户结构和操作
│   ├── instruction.zig      # 指令处理
│   ├── pubkey.zig          # 公钥类型和操作
│   ├── system_program.zig   # 系统程序接口
│   ├── sysvar.zig          # 系统变量访问
│   ├── log.zig             # 日志功能
│   ├── error.zig           # 错误定义
│   ├── serialize.zig       # 序列化/反序列化
│   └── cpi.zig             # 跨程序调用
├── examples/
│   ├── hello_world/        # Hello World 示例
│   ├── transfer/           # 代币转账示例
│   └── escrow/            # 托管合约示例
└── tests/
    └── integration/        # 集成测试
```

### 关键接口设计

#### 1. 程序入口点
```zig
pub fn entrypoint(
    program_id: *const Pubkey,
    accounts: []AccountInfo,
    instruction_data: []const u8,
) !void {
    // 处理逻辑
}
```

#### 2. 账户信息结构
```zig
pub const AccountInfo = struct {
    key: *const Pubkey,
    is_signer: bool,
    is_writable: bool,
    lamports: *u64,
    data: []u8,
    owner: *const Pubkey,
    executable: bool,
    rent_epoch: u64,
};
```

#### 3. 系统调用接口
```zig
// 日志
extern fn sol_log_(message: [*]const u8, len: u64) void;

// 公钥操作
extern fn sol_create_program_address(
    seeds: [*]const u8,
    seeds_len: u64,
    program_id: *const Pubkey,
    address: *Pubkey,
) u64;
```

## 实现计划

### 第一阶段：基础设施（2-3周）✅ 已完成
1. [x] 设置 BPF 编译环境
2. [x] 实现基本数据类型（Pubkey, AccountInfo）
3. [x] 实现系统调用封装
4. [x] 创建程序入口点机制
5. [x] 实现日志功能

### 第二阶段：核心功能（3-4周）
1. [ ] 账户数据序列化/反序列化
2. [ ] 指令解析框架
3. [ ] 错误处理机制
4. [ ] 内存分配器（适配 Solana 限制）
5. [ ] 单元测试框架

### 第三阶段：高级功能（4-5周）
1. [ ] CPI（跨程序调用）支持
2. [ ] PDA（程序派生地址）工具
3. [ ] 系统程序接口
4. [ ] 代币程序接口
5. [ ] 集成测试套件

### 第四阶段：工具链和文档（2-3周）
1. [ ] CLI 工具（部署、测试）
2. [ ] 项目模板生成器
3. [ ] 详细文档编写
4. [ ] 示例程序
5. [ ] 性能优化

## 技术挑战与解决方案

### 1. BPF 目标支持
**挑战：** Zig 的 BPF 后端可能不完善
**解决：** 
- 使用 `-target bpf-freestanding`
- 必要时贡献到 Zig 编译器
- 参考 LLVM BPF 后端文档

### 2. 内存限制
**挑战：** Solana 程序严格的内存限制
**解决：**
- 使用固定大小缓冲区
- 避免动态内存分配
- 实现自定义分配器

### 3. 序列化格式
**挑战：** 与 Rust 程序的互操作性
**解决：**
- 实现 Borsh 序列化
- 支持 bincode 格式
- 提供自定义序列化选项

## 开发环境设置

### 必需工具
- Zig 0.13.0 或更高版本
- Solana CLI 工具
- Anchor（用于测试）

### 构建命令
```bash
# 构建 Solana 程序
zig build-lib -target bpf-freestanding -O ReleaseSmall src/program.zig

# 运行测试
zig test src/tests.zig

# 部署到本地网络
solana program deploy target/program.so
```

## 参考资源

1. Solana 程序运行时：https://docs.solana.com/developing/on-chain-programs/overview
2. BPF 指令集：https://github.com/iovisor/bpf-docs
3. Zig BPF 支持：https://github.com/ziglang/zig/issues/5878
4. Rust SDK 源码：https://github.com/solana-labs/solana-program-library

## 已完成的工作

### 第一阶段：基础模块实现（2025-07-24）
1. **Pubkey 类型** (`src/solana/pubkey.zig`)
   - 基本操作（创建、比较、转换）
   - PDA 创建和查找功能
   - Base58 编码/解码接口

2. **AccountInfo 结构** (`src/solana/account.zig`)
   - 账户信息结构定义
   - 账户借用和权限检查
   - AccountMeta 和迭代器

3. **日志系统** (`src/solana/log.zig`)
   - 基础日志功能
   - 格式化日志
   - 日志级别支持
   - 公钥日志

4. **系统调用** (`src/solana/syscalls.zig`)
   - 哈希函数（SHA256, Keccak256, Blake3）
   - 系统变量访问（Clock, Rent）
   - 内存操作优化版本
   - PDA 创建系统调用

5. **入口点机制** (`src/solana/entrypoint.zig`)
   - 程序入口点宏
   - 输入数据反序列化
   - 测试支持

6. **错误处理** (`src/solana/error.zig`)
   - 标准错误类型定义
   - 错误码转换
   - 辅助检查函数

7. **Hello World 示例**
   - 完整的示例程序
   - 构建配置
   - 本地测试

### 第二阶段：集成 sig 项目组件（2025-07-24）
1. **Base58 编码/解码** (`src/solana/base58.zig`)
   - 完整的 Base58 实现（Bitcoin 变体）
   - 支持编码和解码
   - 内存分配器支持

2. **Bincode 序列化** (`src/solana/bincode.zig`)
   - 支持基本类型和复杂类型
   - 兼容 Rust bincode 格式
   - 流式和切片接口

3. **本地测试基础设施**
   - BPF 编译脚本 (`scripts/build-bpf.sh`)
   - 本地部署测试脚本 (`scripts/local-test.sh`)
   - JavaScript 客户端示例
   - 完整的测试流程自动化

### 技术要点
- 支持 BPF 目标编译（bpfel-freestanding）
- 兼容非 BPF 环境的测试
- 模块化设计，易于扩展
- 参考 Syndica/sig 项目实现
- 完整的本地测试支持

## BPF 编译解决方案（2025-07-24）

### 问题和解决方案
1. **问题**：标准 Zig 生成 eBPF，Solana 需要 sBPF
2. **解决方案**：使用 Solana 兼容的 Zig 编译器
   - 项目：[solana-zig-bootstrap](https://github.com/joncinque/solana-zig-bootstrap)
   - 安装：`./scripts/install-solana-zig.sh`
   - 使用：`./solana-zig/zig build`

### Solana Zig 编译器特性
1. **sBPF 目标支持**：`.sbf` 和 `.sbfv2` 架构
2. **Solana LLVM**：基于 v1.41 分支
3. **静态系统调用**：支持 Solana 特定的系统调用
4. **正确的 ELF 格式**：生成 Solana 可接受的二进制格式

### 编译注意事项
1. **入口点要求**：必须导出 `export fn entrypoint(input: [*]u8) callconv(.C) u64`
2. **目标配置**：使用 `sbf_target` 而不是 `bpfel`
3. **优化建议**：使用 `.ReleaseFast` 或 `.ReleaseSmall`

### 示例程序层次
1. `minimal/` - 最小可部署程序
2. `minimal-with-log/` - 添加日志功能
3. `raw-entrypoint/` - 手动解析输入
4. `simple-entrypoint/` - 使用部分 SDK 功能
5. `hello-world/` - 完整 SDK 集成

## 下一步行动

1. ✅ 完成技术可行性验证
2. ✅ 创建最小可行原型
3. 优化 SDK 以更好支持 BPF 目标
4. 与 Solana 社区交流反馈
5. 继续实现第二阶段功能（序列化、CPI等）