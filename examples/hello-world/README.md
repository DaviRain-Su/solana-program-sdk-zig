# Hello World Solana Program in Zig

这是一个使用 Zig 编写的简单 Solana 程序示例。

## 功能

- 记录程序调用信息
- 显示所有传入的账户信息
- 根据指令数据执行不同命令
- 演示错误处理

## 构建

```bash
# 构建 BPF 程序
zig build

# 运行本地测试
zig build test
```

## 部署

1. 首先创建程序密钥对：
```bash
solana-keygen new -o hello-world-keypair.json
```

2. 获取程序 ID：
```bash
solana-keygen pubkey hello-world-keypair.json
```

3. 部署程序：
```bash
zig build deploy
```

或手动部署：
```bash
solana program deploy zig-out/lib/hello_world.so --program-id hello-world-keypair.json
```

## 测试

### 本地测试
```bash
zig build test
```

### 链上测试
使用 Solana CLI 或客户端库发送交易到部署的程序。

## 指令格式

程序接受以下指令：

- `[0, ...]` - Initialize 命令
- `[1, ...]` - Update 命令  
- `[2, ...]` - Query 命令
- 其他值将返回 `InvalidInstruction` 错误

## 示例客户端代码

```javascript
// JavaScript 示例
const instruction = new TransactionInstruction({
  keys: [
    { pubkey: account1, isSigner: true, isWritable: true },
    { pubkey: account2, isSigner: false, isWritable: false },
  ],
  programId: programId,
  data: Buffer.from([0]), // Initialize 命令
});
```