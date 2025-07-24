# Solana Program SDK for Zig

使用 Zig 语言开发 Solana 智能合约的 SDK。

## 特性

- ✅ 基础数据类型（Pubkey、AccountInfo）
- ✅ 系统调用封装
- ✅ 日志功能
- ✅ 程序入口点机制
- ✅ 错误处理
- ✅ Base58 编码/解码
- ✅ Bincode 序列化/反序列化
- ✅ Hello World 示例
- ✅ 本地测试脚本
- ✅ BPF 编译支持
- 🚧 CPI（跨程序调用）
- 🚧 更多示例程序

## 快速开始

### 1. 安装依赖

- Zig 0.14.0 或更高版本
- Solana CLI 工具

### 2. 创建新项目

```bash
mkdir my-solana-program
cd my-solana-program
zig init
```

### 3. 添加依赖

编辑 `build.zig.zon`：

```zig
.{
    .name = "my-solana-program",
    .version = "0.1.0",
    .dependencies = .{
        .solana_program_sdk_zig = .{
            .path = "path/to/solana-program-sdk-zig",
        },
    },
    .paths = .{""},
}
```

### 4. 编写程序

```zig
const std = @import("std");
const solana = @import("solana_program_sdk_zig").solana;

fn processInstruction(
    program_id: *const solana.Pubkey,
    accounts: []solana.AccountInfo,
    instruction_data: []const u8,
) solana.ProgramResult {
    solana.log.log("Hello from Zig!");
    return;
}

pub fn main() void {
    solana.declareEntrypoint(processInstruction);
}
```

### 5. 构建和测试

#### 本地单元测试
```bash
zig build test
```

#### 构建 BPF 程序
```bash
./scripts/build-bpf.sh src/main.zig
```

#### 一键本地部署测试
```bash
./scripts/local-test.sh examples/hello-world/main.zig
```

## 示例

查看 `examples/` 目录中的示例：

- `hello-world/` - 基础示例程序
- 更多示例即将推出...

## 开发状态

本项目仍在积极开发中。基础功能已实现，但仍需要：

1. 完善的 BPF 编译配置
2. 完整的序列化支持
3. CPI 功能
4. 更多测试和示例

### 🚀 部署到 Solana

要部署 Zig 程序到 Solana，你需要使用 **Solana 兼容的 Zig 编译器**：

#### 快速开始
```bash
# 1. 安装 Solana Zig 编译器
./scripts/install-solana-zig.sh

# 2. 构建你的程序
./solana-zig/zig build

# 3. 部署到 Solana
solana program deploy zig-out/lib/program.so
```

#### 为什么需要特殊编译器？
- 标准 Zig 生成 eBPF 格式，而 Solana 需要 sBPF 格式
- Solana Zig 包含必要的补丁和 LLVM 修改
- 由 [solana-zig-bootstrap](https://github.com/joncinque/solana-zig-bootstrap) 项目提供

详细信息请参考：
- [部署指南](docs/deployment-guide.md) - 当前限制和解决方案
- [CLAUDE.md](CLAUDE.md) - 技术实现细节

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT