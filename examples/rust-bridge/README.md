# Rust-Zig 桥接示例

这个示例展示如何在 Rust Solana 程序中使用 Zig 编写的函数。

## 概念

1. 使用 Zig 编写核心算法
2. 编译 Zig 代码为静态库
3. 在 Rust 中链接和调用 Zig 函数
4. 使用 Rust 的 Solana SDK 进行部署

## 文件结构

```
rust-bridge/
├── src/
│   ├── lib.rs          # Rust 入口点
│   └── processor.rs    # 处理逻辑
├── zig/
│   ├── algorithms.zig  # Zig 算法实现
│   └── build.zig       # Zig 构建配置
├── Cargo.toml
└── build.rs            # Rust 构建脚本
```

## 示例代码

### Zig 算法 (zig/algorithms.zig)
```zig
export fn calculate_fibonacci(n: u32) u64 {
    if (n <= 1) return n;
    
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u32 = 2;
    
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    
    return b;
}

export fn verify_signature(
    data: [*]const u8,
    data_len: usize,
    signature: [*]const u8,
) bool {
    // 实现签名验证逻辑
    _ = data;
    _ = data_len;
    _ = signature;
    return true;
}
```

### Rust 包装器 (src/lib.rs)
```rust
use solana_program::{
    account_info::AccountInfo,
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    pubkey::Pubkey,
};

// 声明 Zig 函数
extern "C" {
    fn calculate_fibonacci(n: u32) -> u64;
    fn verify_signature(
        data: *const u8,
        data_len: usize,
        signature: *const u8,
    ) -> bool;
}

entrypoint!(process_instruction);

pub fn process_instruction(
    _program_id: &Pubkey,
    _accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.is_empty() {
        return Ok(());
    }
    
    match instruction_data[0] {
        0 => {
            // 调用 Zig 计算斐波那契数
            let n = instruction_data.get(1).copied().unwrap_or(10) as u32;
            let result = unsafe { calculate_fibonacci(n) };
            msg!("Fibonacci({}) = {}", n, result);
        }
        1 => {
            // 调用 Zig 验证签名
            let verified = unsafe {
                verify_signature(
                    instruction_data.as_ptr().offset(1),
                    instruction_data.len() - 1,
                    instruction_data.as_ptr(),
                )
            };
            msg!("Signature verified: {}", verified);
        }
        _ => {
            msg!("Unknown instruction");
        }
    }
    
    Ok(())
}
```

## 构建步骤

1. 编译 Zig 代码：
```bash
cd zig
zig build-lib -target wasm32-freestanding -O ReleaseSmall algorithms.zig
```

2. 构建 Rust 程序：
```bash
cargo build-sbf
```

## 优势

- **性能**：Zig 的零成本抽象
- **安全**：Zig 的编译时内存安全
- **灵活**：结合两种语言的优势
- **兼容**：可以正常部署到 Solana

## 注意事项

1. 确保 Zig 函数使用 `export` 和正确的调用约定
2. 注意内存对齐和 ABI 兼容性
3. 处理错误时要考虑两种语言的差异