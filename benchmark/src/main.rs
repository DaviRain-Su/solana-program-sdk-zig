use solana_program_test::*;
use solana_sdk::{
    account::Account,
    instruction::{AccountMeta, Instruction},
    pubkey::Pubkey,
    signature::Signer,
    transaction::Transaction,
};
use std::str::FromStr;

fn run_benchmark(benchmark: &'static str) {
    let program_id = Pubkey::from_str("BenchPubkey11111111111111111111111111111111").unwrap();
    let program_name = format!("benchmark_{}", benchmark);
    let program_name_static: &'static str = Box::leak(program_name.into_boxed_str());
    
    println!("\n=== Running {} ===", benchmark);
    
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let mut program_test = ProgramTest::new(
            program_name_static,
            program_id,
            None,
        );
        
        if benchmark == "transfer_lamports" {
            let test_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();
            let dest_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111113").unwrap();
            
            // Use program_id as owner so the program can modify lamports
            program_test.add_account(
                test_key,
                Account {
                    lamports: 1_000_000,
                    data: vec![0],
                    owner: program_id,
                    ..Account::default()
                },
            );
            program_test.add_account(
                dest_key,
                Account {
                    lamports: 100_000,
                    data: vec![0],
                    owner: program_id,
                    ..Account::default()
                },
            );
            
            let (banks_client, payer, recent_blockhash) = program_test.start().await;

            let mut instruction_data = [0u8; 8];
            instruction_data[0] = 100;
            
            let mut transaction = Transaction::new_with_payer(
                &[Instruction::new_with_bincode(
                    program_id,
                    &instruction_data,
                    vec![
                        AccountMeta::new(test_key, false),
                        AccountMeta::new(dest_key, false),
                    ],
                )],
                Some(&payer.pubkey()),
            );
            transaction.sign(&[&payer], recent_blockhash);
            
            match banks_client.process_transaction(transaction).await {
                Ok(()) => println!("Transfer succeeded"),
                Err(e) => println!("Transfer failed: {}", e),
            }
        } else {
            let test_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();
            
            program_test.add_account(
                test_key,
                Account {
                    lamports: 100_000,
                    data: vec![0],
                    owner: test_key,
                    ..Account::default()
                },
            );
            
            let (banks_client, payer, recent_blockhash) = program_test.start().await;
            
            let mut transaction = Transaction::new_with_payer(
                &[Instruction::new_with_bincode(
                    program_id,
                    &(),
                    vec![AccountMeta::new_readonly(test_key, false)],
                )],
                Some(&payer.pubkey()),
            );
            transaction.sign(&[&payer], recent_blockhash);
            
            match banks_client.process_transaction(transaction).await {
                Ok(()) => println!("Pubkey cmp succeeded"),
                Err(e) => println!("Pubkey cmp failed: {}", e),
            }
        }
    });
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    
    if args.len() < 2 {
        println!("Usage: {} <benchmark_name>", args[0]);
        println!("Available benchmarks:");
        println!("  pubkey_cmp_safe");
        println!("  pubkey_cmp_fast");
        println!("  pubkey_cmp_unchecked");
        println!("  transfer_lamports");
        return;
    }
    
    let benchmark = args[1].clone();
    let benchmark_static: &'static str = Box::leak(benchmark.into_boxed_str());
    run_benchmark(benchmark_static);
}
