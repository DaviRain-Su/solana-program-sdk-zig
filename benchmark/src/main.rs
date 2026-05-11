use solana_program_test::*;
use solana_sdk::{
    account::Account,
    instruction::{AccountMeta, Instruction},
    pubkey::Pubkey,
    signature::Signer,
    transaction::Transaction,
};
use std::str::FromStr;

fn program_name(benchmark: &str) -> Option<&'static str> {
    match benchmark {
        "pubkey_cmp_safe" => Some("benchmark_pubkey_cmp_safe"),
        "pubkey_cmp_fast" => Some("benchmark_pubkey_cmp_fast"),
        "pubkey_cmp_unchecked" => Some("benchmark_pubkey_cmp_unchecked"),
        "transfer_lamports" => Some("benchmark_transfer_lamports"),
        _ => None,
    }
}

fn print_usage(binary: &str) {
    println!("Usage: {} <benchmark_name>", binary);
    println!("Available benchmarks:");
    println!("  pubkey_cmp_safe");
    println!("  pubkey_cmp_fast");
    println!("  pubkey_cmp_unchecked");
    println!("  transfer_lamports");
}

fn run_benchmark(name: &str, program_name: &'static str) {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let program_id = Pubkey::from_str("BenchPubkey11111111111111111111111111111111").unwrap();
        let test_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();

        let mut program_test = ProgramTest::new(program_name, program_id, None);

        if name == "transfer_lamports" {
            let dest_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111113").unwrap();
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
                    lamports: 1_000_000,
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

            if let Err(e) = banks_client.process_transaction(transaction).await {
                panic!("{} failed: {}", name, e);
            }
        } else {
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

            if let Err(e) = banks_client.process_transaction(transaction).await {
                panic!("{} failed: {}", name, e);
            }
        }
    });
}

fn main() {
    let args: Vec<String> = std::env::args().collect();

    if args.len() < 2 {
        print_usage(&args[0]);
        return;
    }

    let benchmark = &args[1];
    let Some(program_name) = program_name(benchmark) else {
        eprintln!("Unknown benchmark: {}", benchmark);
        print_usage(&args[0]);
        std::process::exit(2);
    };

    println!("\n=== Running {} ===", benchmark);
    run_benchmark(benchmark, program_name);
}
