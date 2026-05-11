use solana_program_test::*;
use solana_sdk::{
    account::Account,
    instruction::{AccountMeta, Instruction},
    pubkey::Pubkey,
    signature::Signer,
    transaction::Transaction,
};
use std::str::FromStr;

fn main() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let program_id = Pubkey::from_str("BenchPubkey11111111111111111111111111111111").unwrap();
        let test_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();

        let mut program_test = ProgramTest::new(
            "benchmark_pubkey_cmp_safe",
            program_id,
            None,
        );
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
            Ok(()) => println!("Transaction succeeded"),
            Err(e) => println!("Transaction failed: {}", e),
        }
    });
}
