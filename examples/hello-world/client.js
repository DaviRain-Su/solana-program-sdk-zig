#!/usr/bin/env node
/**
 * Hello World 客户端测试脚本
 * 
 * 使用方法：
 * node client.js <program_id>
 */

const {
  Connection,
  PublicKey,
  Keypair,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
  SystemProgram,
} = require('@solana/web3.js');

// 从命令行参数获取程序 ID
const programId = process.argv[2];
if (!programId) {
  console.error('Usage: node client.js <program_id>');
  process.exit(1);
}

async function main() {
  console.log('🚀 Hello World Client Test');
  console.log('Program ID:', programId);
  
  // 连接到本地集群
  const connection = new Connection('http://localhost:8899', 'confirmed');
  
  // 获取本地密钥对
  const payerKeypair = Keypair.generate(); // 在实际使用中，应该从文件加载
  
  // 空投 SOL
  console.log('\n💰 Requesting airdrop...');
  const airdropSignature = await connection.requestAirdrop(
    payerKeypair.publicKey,
    2 * 1e9, // 2 SOL
  );
  await connection.confirmTransaction(airdropSignature);
  
  const balance = await connection.getBalance(payerKeypair.publicKey);
  console.log('Balance:', balance / 1e9, 'SOL');
  
  // 创建测试账户
  const testAccount = Keypair.generate();
  
  // 测试不同的指令
  await testInstruction(connection, payerKeypair, programId, [], 'No data');
  await testInstruction(connection, payerKeypair, programId, [0], 'Initialize');
  await testInstruction(connection, payerKeypair, programId, [1], 'Update');
  await testInstruction(connection, payerKeypair, programId, [2], 'Query');
  await testInstruction(connection, payerKeypair, programId, [99], 'Invalid (should fail)');
}

async function testInstruction(connection, payer, programId, data, description) {
  console.log(`\n📋 Testing: ${description}`);
  console.log('Instruction data:', data);
  
  try {
    // 创建指令
    const instruction = new TransactionInstruction({
      keys: [
        {
          pubkey: payer.publicKey,
          isSigner: true,
          isWritable: true,
        },
        {
          pubkey: SystemProgram.programId,
          isSigner: false,
          isWritable: false,
        },
      ],
      programId: new PublicKey(programId),
      data: Buffer.from(data),
    });
    
    // 创建交易
    const transaction = new Transaction().add(instruction);
    
    // 发送交易
    const signature = await sendAndConfirmTransaction(
      connection,
      transaction,
      [payer],
      {
        skipPreflight: false,
        preflightCommitment: 'confirmed',
      }
    );
    
    console.log('✅ Success! Signature:', signature);
    
    // 获取交易日志
    const confirmedTransaction = await connection.getTransaction(signature, {
      maxSupportedTransactionVersion: 0,
    });
    
    if (confirmedTransaction?.meta?.logMessages) {
      console.log('\n📜 Program logs:');
      confirmedTransaction.meta.logMessages.forEach(log => {
        if (log.includes('Program log:')) {
          console.log('  ', log);
        }
      });
    }
  } catch (error) {
    console.log('❌ Error:', error.message);
    if (error.logs) {
      console.log('\n📜 Program logs:');
      error.logs.forEach(log => {
        if (log.includes('Program log:')) {
          console.log('  ', log);
        }
      });
    }
  }
}

// 检查是否安装了必要的包
try {
  require('@solana/web3.js');
} catch (error) {
  console.error('\n❌ @solana/web3.js not found!');
  console.error('Please run: npm install @solana/web3.js');
  process.exit(1);
}

// 运行主函数
main().catch(error => {
  console.error('\n❌ Fatal error:', error);
  process.exit(1);
});