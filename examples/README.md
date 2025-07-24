# Solana Program SDK for Zig - 示例

本目录包含使用 Zig 编写 Solana 程序的各种示例。

## 示例列表

### 1. hello-world/
完整的 Hello World 示例，展示了：
- 使用 SDK 的入口点机制
- 日志记录
- 账户遍历
- 指令数据处理
- JavaScript 客户端测试

### 2. simple-entrypoint/
简化的入口点示例，展示了：
- 手动导出 `entrypoint` 函数
- 使用 SDK 的处理函数
- 基本的指令处理

### 3. raw-entrypoint/
原始入口点实现，展示了：
- 最基础的 Solana 程序结构
- 直接使用系统调用
- 手动解析输入数据
- 不依赖 SDK 的高级功能

## 入口点实现方式

### 方式 1：使用 SDK 的声明式方法（推荐）
```zig
const solana = @import("solana_program_sdk_zig_lib").solana;

fn processInstruction(...) solana.ProgramResult {
    // 你的逻辑
}

// 在文件底部
comptime {
    solana.declareEntrypoint(processInstruction);
}
```

### 方式 2：手动导出入口点
```zig
export fn entrypoint(input: [*]u8) callconv(.C) u64 {
    const handler = solana.entrypoint.entrypoint(processInstruction);
    return handler(input);
}

fn processInstruction(...) solana.ProgramResult {
    // 你的逻辑
}
```

### 方式 3：原始实现
```zig
export fn entrypoint(input: [*]u8) callconv(.C) u64 {
    // 手动解析输入
    // 调用系统函数
    // 返回状态码
    return 0; // 成功
}
```

## 构建和测试

### 构建单个示例
```bash
../../scripts/build-bpf.sh <example>/root.zig
```

### 运行本地测试
```bash
../../scripts/local-test.sh <example>/root.zig
```

### 部署到本地验证器
```bash
# 启动验证器
solana-test-validator

# 部署程序
solana program deploy target/bpf/root.so
```

## 注意事项

1. **入口点要求**：所有 Solana 程序必须导出一个名为 `entrypoint` 的函数
2. **函数签名**：`export fn entrypoint(input: [*]u8) callconv(.C) u64`
3. **返回值**：0 表示成功，非零值表示错误
4. **内存对齐**：确保所有指针访问都正确对齐
5. **BPF 限制**：注意栈大小和计算单元限制