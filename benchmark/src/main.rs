//! Benchmark runner — measures BPF CU consumption for SDK programs.
//!
//! Two flavours of benchmarks:
//!
//! 1. Simple ones (`pubkey_*`, `transfer_*`, `pda_*`, `parse_*`):
//!    deploy under a benchmark-only program id, drive a single fixed
//!    instruction, report CU. These exercise the SDK primitives.
//!
//! 2. End-to-end vault benchmarks (`vault_initialize`, `vault_deposit`,
//!    `vault_withdraw`): deploy `example_vault.so` under the program id
//!    baked into the vault source. Drive the three instruction variants
//!    that the example exposes, each tagged by the first byte of the
//!    ix data.
//!
//! Set `BPF_OUT_DIR` (defaults to `zig-out/lib` relative to CWD) to
//! point at the directory containing the prebuilt `.so` files.

use solana_program_test::*;
use solana_sdk::{
    account::Account,
    instruction::{AccountMeta, Instruction},
    pubkey::Pubkey,
    signature::{Keypair, Signer},
    signer::keypair::keypair_from_seed,
    system_program,
    transaction::Transaction,
};
use std::str::FromStr;

/// A deterministic test payer so that `findProgramAddress` always
/// returns the same bump → stable vault CU numbers across runs.
fn fixed_payer() -> Keypair {
    keypair_from_seed(&[7u8; 64]).expect("fixed seed")
}

/// Program ID baked into `examples/vault.zig` — must match exactly.
const VAULT_PROGRAM_ID: &str = "Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK";

/// Generic benchmark program ID used by everything else.
const BENCH_PROGRAM_ID: &str = "BenchPubkey11111111111111111111111111111111";

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        print_usage(&args[0]);
        return;
    }
    let benchmark = args[1].clone();
    let leaked: &'static str = Box::leak(benchmark.into_boxed_str());

    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(run_benchmark(leaked));
}

fn print_usage(prog: &str) {
    println!("Usage: {} <benchmark_name>", prog);
    println!();
    println!("Primitive benchmarks (deploy under BenchPubkey...):");
    for name in [
        "pubkey_cmp_safe",
        "pubkey_cmp_safe_raw",
        "pubkey_cmp_unchecked",
        "pubkey_cmp_comptime",
        "pubkey_cmp_runtime_const",
        "pda_runtime",
        "pda_comptime",
        "parse_accounts",
        "parse_accounts_with",
        "transfer_lamports",
        "transfer_lamports_raw",
    ] {
        println!("  {}", name);
    }
    println!();
    println!("End-to-end vault benchmarks (deploy example_vault under Zigc1...):");
    for name in ["vault_initialize", "vault_deposit", "vault_withdraw"] {
        println!("  {}", name);
    }
    println!();
    println!("Token dispatch benchmarks (deploy example_token_dispatch):");
    for name in [
        "token_dispatch_transfer",
        "token_dispatch_burn",
        "token_dispatch_mint",
    ] {
        println!("  {}", name);
    }
}

async fn run_benchmark(name: &'static str) {
    println!("\n=== Running {} ===", name);
    match name {
        // Vault end-to-end
        "vault_initialize" => run_vault_initialize().await,
        "vault_deposit" => run_vault_deposit().await,
        "vault_withdraw" => run_vault_withdraw().await,

        // Token dispatch
        "token_dispatch_transfer" => run_token_dispatch(0, 100).await,
        "token_dispatch_burn" => run_token_dispatch(1, 50).await,
        "token_dispatch_mint" => run_token_dispatch(2, 25).await,

        // Primitives: pubkey_*, pda_*, parse_*, transfer_*
        n if n.starts_with("transfer_lamports") => {
            run_transfer_lamports_primitive(n).await
        }
        other => run_simple_primitive(other).await,
    }
}

// ---------------------------------------------------------------------------
// Primitive benchmark drivers
// ---------------------------------------------------------------------------

async fn run_simple_primitive(name: &'static str) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let program_name = Box::leak(format!("benchmark_{}", name).into_boxed_str());
    let mut pt = ProgramTest::new(program_name, program_id, None);

    let test_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();
    pt.add_account(
        test_key,
        Account {
            lamports: 100_000,
            data: vec![0],
            owner: test_key,
            ..Account::default()
        },
    );

    let (banks_client, payer, recent_blockhash) = pt.start().await;
    let mut tx = Transaction::new_with_payer(
        &[Instruction::new_with_bytes(
            program_id,
            &[],
            vec![AccountMeta::new_readonly(test_key, false)],
        )],
        Some(&payer.pubkey()),
    );
    tx.sign(&[&payer], recent_blockhash);
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("Primitive {} succeeded", name),
        Err(e) => println!("Primitive {} failed: {}", name, e),
    }
}

async fn run_transfer_lamports_primitive(name: &'static str) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let program_name = Box::leak(format!("benchmark_{}", name).into_boxed_str());
    let mut pt = ProgramTest::new(program_name, program_id, None);

    let from_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();
    let to_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111113").unwrap();

    pt.add_account(
        from_key,
        Account {
            lamports: 10_000_000,
            data: vec![0],
            owner: program_id,
            ..Account::default()
        },
    );
    pt.add_account(
        to_key,
        Account {
            lamports: 10_000_000,
            data: vec![0],
            owner: program_id,
            ..Account::default()
        },
    );

    let (banks_client, payer, recent_blockhash) = pt.start().await;
    let mut ix_data = [0u8; 8];
    ix_data[0] = 100;
    let mut tx = Transaction::new_with_payer(
        &[Instruction::new_with_bytes(
            program_id,
            &ix_data,
            vec![
                AccountMeta::new(from_key, false),
                AccountMeta::new(to_key, false),
            ],
        )],
        Some(&payer.pubkey()),
    );
    tx.sign(&[&payer], recent_blockhash);
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("Transfer succeeded"),
        Err(e) => println!("Transfer failed: {}", e),
    }
}

// ---------------------------------------------------------------------------
// Vault end-to-end benchmarks
// ---------------------------------------------------------------------------

fn vault_program_id() -> Pubkey {
    Pubkey::from_str(VAULT_PROGRAM_ID).unwrap()
}

/// Derive the vault PDA for a given authority — matches the seeds used
/// inside `examples/vault.zig`: `[b"vault", authority.key.as_ref()]`.
fn derive_vault(authority: &Pubkey) -> (Pubkey, u8) {
    let program_id = vault_program_id();
    Pubkey::find_program_address(&[b"vault", authority.as_ref()], &program_id)
}

async fn run_vault_initialize() {
    let program_id = vault_program_id();
    let mut pt = ProgramTest::new("example_vault", program_id, None);
    let auth = fixed_payer();
    // Fund the fixed authority so it can pay for the new vault account.
    pt.add_account(
        auth.pubkey(),
        Account {
            lamports: 1_000_000_000,
            ..Account::default()
        },
    );
    let (banks_client, payer, recent_blockhash) = pt.start().await;

    let (vault_pda, _bump) = derive_vault(&auth.pubkey());

    // Initialize: tag = 0
    let ix_data = vec![0u8];
    let ix = Instruction::new_with_bytes(
        program_id,
        &ix_data,
        vec![
            AccountMeta::new(auth.pubkey(), true), // authority (signer, writable)
            AccountMeta::new(vault_pda, false),    // vault PDA (writable)
            AccountMeta::new_readonly(system_program::ID, false),
        ],
    );

    let mut tx = Transaction::new_with_payer(&[ix], Some(&payer.pubkey()));
    tx.sign(&[&payer, &auth], recent_blockhash);
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("vault_initialize succeeded"),
        Err(e) => println!("vault_initialize failed: {}", e),
    }
}

async fn run_vault_deposit() {
    let program_id = vault_program_id();
    let mut pt = ProgramTest::new("example_vault", program_id, None);
    let auth = fixed_payer();
    pt.add_account(
        auth.pubkey(),
        Account {
            lamports: 1_000_000_000,
            ..Account::default()
        },
    );
    let (banks_client, payer, recent_blockhash) = pt.start().await;

    let (vault_pda, _bump) = derive_vault(&auth.pubkey());

    // Step 1: initialize
    {
        let mut tx = Transaction::new_with_payer(
            &[Instruction::new_with_bytes(
                program_id,
                &[0u8],
                vec![
                    AccountMeta::new(auth.pubkey(), true),
                    AccountMeta::new(vault_pda, false),
                    AccountMeta::new_readonly(system_program::ID, false),
                ],
            )],
            Some(&payer.pubkey()),
        );
        tx.sign(&[&payer, &auth], recent_blockhash);
        banks_client
            .process_transaction(tx)
            .await
            .expect("init for deposit");
    }

    // Step 2: deposit (measure this)
    let blockhash = banks_client.get_latest_blockhash().await.unwrap();
    let mut data = vec![1u8];
    data.extend_from_slice(&1_000_000u64.to_le_bytes());
    let ix = Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(auth.pubkey(), true),
            AccountMeta::new(vault_pda, false),
            AccountMeta::new_readonly(system_program::ID, false),
        ],
    );
    let mut tx = Transaction::new_with_payer(&[ix], Some(&payer.pubkey()));
    tx.sign(&[&payer, &auth], blockhash);
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("vault_deposit succeeded"),
        Err(e) => println!("vault_deposit failed: {}", e),
    }
}

async fn run_vault_withdraw() {
    let program_id = vault_program_id();
    let mut pt = ProgramTest::new("example_vault", program_id, None);
    let auth = fixed_payer();
    pt.add_account(
        auth.pubkey(),
        Account {
            lamports: 1_000_000_000,
            ..Account::default()
        },
    );
    let (banks_client, payer, recent_blockhash) = pt.start().await;

    let (vault_pda, _bump) = derive_vault(&auth.pubkey());
    let recipient = Keypair::new();

    // Step 1: initialize
    {
        let mut tx = Transaction::new_with_payer(
            &[Instruction::new_with_bytes(
                program_id,
                &[0u8],
                vec![
                    AccountMeta::new(auth.pubkey(), true),
                    AccountMeta::new(vault_pda, false),
                    AccountMeta::new_readonly(system_program::ID, false),
                ],
            )],
            Some(&payer.pubkey()),
        );
        tx.sign(&[&payer, &auth], recent_blockhash);
        banks_client
            .process_transaction(tx)
            .await
            .expect("init for withdraw");
    }

    // Step 2: deposit (so the vault has something to withdraw)
    {
        let blockhash = banks_client.get_latest_blockhash().await.unwrap();
        let mut data = vec![1u8];
        data.extend_from_slice(&2_000_000u64.to_le_bytes());
        let mut tx = Transaction::new_with_payer(
            &[Instruction::new_with_bytes(
                program_id,
                &data,
                vec![
                    AccountMeta::new(auth.pubkey(), true),
                    AccountMeta::new(vault_pda, false),
                    AccountMeta::new_readonly(system_program::ID, false),
                ],
            )],
            Some(&payer.pubkey()),
        );
        tx.sign(&[&payer, &auth], blockhash);
        banks_client
            .process_transaction(tx)
            .await
            .expect("deposit for withdraw");
    }

    // Step 3: withdraw (measure this)
    let blockhash = banks_client.get_latest_blockhash().await.unwrap();
    let mut data = vec![2u8];
    data.extend_from_slice(&500_000u64.to_le_bytes());
    let ix = Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new_readonly(auth.pubkey(), true), // authority (signer)
            AccountMeta::new(vault_pda, false),             // vault (writable)
            AccountMeta::new(recipient.pubkey(), false),    // recipient (writable)
        ],
    );
    let mut tx = Transaction::new_with_payer(&[ix], Some(&payer.pubkey()));
    tx.sign(&[&payer, &auth], blockhash);
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("vault_withdraw succeeded"),
        Err(e) => println!("vault_withdraw failed: {}", e),
    }
}

// ---------------------------------------------------------------------------
// Token dispatch benchmarks
// ---------------------------------------------------------------------------

async fn run_token_dispatch(tag: u32, amount: u64) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let mut pt = ProgramTest::new("example_token_dispatch", program_id, None);

    let source = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();
    let dest = Pubkey::from_str("BenchPubkey11111111111111111111111111111113").unwrap();

    pt.add_account(
        source,
        Account {
            lamports: 10_000_000,
            data: vec![0],
            owner: program_id,
            ..Account::default()
        },
    );
    pt.add_account(
        dest,
        Account {
            lamports: 10_000_000,
            data: vec![0],
            owner: program_id,
            ..Account::default()
        },
    );

    let (banks_client, payer, recent_blockhash) = pt.start().await;

    // Layout: [u32 tag][u64 amount]
    let mut data = Vec::with_capacity(12);
    data.extend_from_slice(&tag.to_le_bytes());
    data.extend_from_slice(&amount.to_le_bytes());

    let accounts = if tag == 0 {
        vec![AccountMeta::new(source, false), AccountMeta::new(dest, false)]
    } else {
        vec![AccountMeta::new(source, false)]
    };

    let mut tx = Transaction::new_with_payer(
        &[Instruction::new_with_bytes(program_id, &data, accounts)],
        Some(&payer.pubkey()),
    );
    tx.sign(&[&payer], recent_blockhash);
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("token_dispatch tag={} succeeded", tag),
        Err(e) => println!("token_dispatch tag={} failed: {}", tag, e),
    }
}
