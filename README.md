# Solana Program SDK for Zig

使用 Zig 语言开发 Solana 智能合约的 SDK。

## 特性

- ✅ 基础数据类型（Pubkey、AccountInfo）
- ✅ 系统调用封装
- ✅ 日志功能
- ✅ 程序入口点机制
- ✅ 错误处理
- ✅ Hello World 示例
- 🚧 BPF 编译支持（进行中）
- 🚧 序列化/反序列化
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

### 5. 构建程序

```bash
zig build -Dtarget=sbf-freestanding -Doptimize=ReleaseSmall
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

详细的技术方案和实现计划请参考 [CLAUDE.md](CLAUDE.md)。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT