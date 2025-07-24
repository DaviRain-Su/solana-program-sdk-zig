# Hello World Solana Program in Zig

这是一个使用 Zig 编写的简单 Solana 程序示例。

## 功能

- 记录程序调用信息
- 显示所有传入的账户信息
- 根据指令数据执行不同命令
- 演示错误处理

## 快速开始

### 一键本地测试

```bash
# 从项目根目录运行
./scripts/local-test.sh examples/hello-world/main.zig
```

这个脚本会自动：
1. 启动本地 Solana 验证器
2. 设置测试账户
3. 构建 Zig 程序为 BPF
4. 部署程序到本地网络
5. 运行 JavaScript 客户端测试

### 手动构建

```bash
# 构建 BPF 程序
../../scripts/build-bpf.sh root.zig

# 运行本地单元测试
zig build test
```

## 部署

### 本地网络部署

```bash
# 启动本地验证器
solana-test-validator

# 部署程序
solana program deploy target/bpf/root.so
```

### 开发网/测试网部署

1. 创建程序密钥对：
```bash
solana-keygen new -o hello-world-keypair.json
```

2. 设置网络：
```bash
solana config set --url devnet  # 或 testnet
```

3. 获取空投：
```bash
solana airdrop 2
```

4. 部署程序：
```bash
solana program deploy target/bpf/root.so --program-id hello-world-keypair.json
```

## 客户端测试

### JavaScript 客户端

```bash
# 安装依赖
npm install

# 运行客户端测试
node client.js <program_id>
```

### 使用 Solana CLI

```bash
# 发送测试交易
solana program invoke <program_id> --data 0 # Initialize
solana program invoke <program_id> --data 1 # Update
solana program invoke <program_id> --data 2 # Query
```

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
