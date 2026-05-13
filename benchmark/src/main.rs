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

/// Program ID baked into `bench-pinocchio/src/lib.rs` — must match.
const PINO_VAULT_PROGRAM_ID: &str = "PinoVau1tBench11111111111111111111111111111";

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
        "pubkey_cmp_any_2",
        "pubkey_cmp_runtime_const",
        "pda_runtime",
        "pda_comptime",
        "parse_accounts",
        "parse_accounts_with",
        "parse_accounts_with_unchecked",
        "sysvar_copy",
        "sysvar_ref",
        "program_entry_1",
        "program_entry_lazy_1",
        "transfer_lamports",
        "transfer_lamports_raw",
        "spl_token_mint_to_checked_signed",
        "spl_token_mint_to_checked_signed_single",
        "spl_token_mint_to_checked_multisig",
        "spl_token_transfer_checked_multisig",
        "spl_token_approve_checked_multisig",
    ] {
        println!("  {}", name);
    }
    println!();
    println!("End-to-end vault benchmarks (deploy example_vault under Zigc1...):");
    for name in ["vault_initialize", "vault_deposit", "vault_withdraw"] {
        println!("  {}", name);
    }
    println!();
    println!("Pinocchio vault — same semantics, Rust impl, for apples-to-apples:");
    for name in [
        "pino_vault_initialize",
        "pino_vault_deposit",
        "pino_vault_withdraw",
    ] {
        println!("  {}", name);
    }
    println!();
    println!("Token dispatch benchmarks:");
    for name in [
        "token_dispatch_transfer",
        "token_dispatch_burn",
        "token_dispatch_mint",
        "token_dispatch_parse_only_transfer",
        "token_dispatch_parse_only_burn",
        "token_dispatch_parse_only_mint",
        "token_dispatch_bind_only_transfer",
        "token_dispatch_bind_only_burn",
        "token_dispatch_bind_only_mint",
        "token_dispatch_unchecked_transfer",
        "token_dispatch_unchecked_burn",
        "token_dispatch_unchecked_mint",
    ] {
        println!("  {}", name);
    }
    println!();
    println!("Typed-args benchmarks:");
    for name in ["typed_args_bind", "typed_args_raw"] {
        println!("  {}", name);
    }
}

async fn run_benchmark(name: &'static str) {
    println!("\n=== Running {} ===", name);
    match name {
        // Vault end-to-end (Zig)
        "vault_initialize" => run_vault_initialize(VaultImpl::Zig).await,
        "vault_deposit" => run_vault_deposit(VaultImpl::Zig).await,
        "vault_withdraw" => run_vault_withdraw(VaultImpl::Zig).await,

        // Vault end-to-end (Pinocchio)
        "pino_vault_initialize" => run_vault_initialize(VaultImpl::Pinocchio).await,
        "pino_vault_deposit" => run_vault_deposit(VaultImpl::Pinocchio).await,
        "pino_vault_withdraw" => run_vault_withdraw(VaultImpl::Pinocchio).await,

        // Parse-account primitives that need a 2-account harness.
        "parse_accounts" => run_parse_accounts_primitive("benchmark_parse_accounts", false).await,
        "parse_accounts_with" => {
            run_parse_accounts_primitive("benchmark_parse_accounts_with", true).await
        }
        "parse_accounts_with_unchecked" => {
            run_parse_accounts_primitive("benchmark_parse_accounts_with_unchecked", true).await
        }

        // Account-backed sysvar access primitives.
        "sysvar_copy" => run_sysvar_access_primitive("benchmark_sysvar_copy").await,
        "sysvar_ref" => run_sysvar_access_primitive("benchmark_sysvar_ref").await,

        // Token dispatch — current ergonomic path.
        "token_dispatch_transfer" => run_token_dispatch("example_token_dispatch", 0, 100).await,
        "token_dispatch_burn" => run_token_dispatch("example_token_dispatch", 1, 50).await,
        "token_dispatch_mint" => run_token_dispatch("example_token_dispatch", 2, 25).await,

        // Token dispatch — isolate parseAccountsUnchecked overhead.
        "token_dispatch_parse_only_transfer" => {
            run_token_dispatch("benchmark_token_dispatch_parse_only", 0, 100).await
        }
        "token_dispatch_parse_only_burn" => {
            run_token_dispatch("benchmark_token_dispatch_parse_only", 1, 50).await
        }
        "token_dispatch_parse_only_mint" => {
            run_token_dispatch("benchmark_token_dispatch_parse_only", 2, 25).await
        }

        // Token dispatch — isolate bindIxDataUnchecked overhead.
        "token_dispatch_bind_only_transfer" => {
            run_token_dispatch("benchmark_token_dispatch_bind_only", 0, 100).await
        }
        "token_dispatch_bind_only_burn" => {
            run_token_dispatch("benchmark_token_dispatch_bind_only", 1, 50).await
        }
        "token_dispatch_bind_only_mint" => {
            run_token_dispatch("benchmark_token_dispatch_bind_only", 2, 25).await
        }

        // Token dispatch — minimal unchecked baseline.
        "token_dispatch_unchecked_transfer" => {
            run_token_dispatch("benchmark_token_dispatch_unchecked", 0, 100).await
        }
        "token_dispatch_unchecked_burn" => {
            run_token_dispatch("benchmark_token_dispatch_unchecked", 1, 50).await
        }
        "token_dispatch_unchecked_mint" => {
            run_token_dispatch("benchmark_token_dispatch_unchecked", 2, 25).await
        }

        // Typed-args — realistic multi-field payload, bind vs raw reads.
        "typed_args_bind" => run_typed_args("benchmark_typed_args_bind").await,
        "typed_args_raw" => run_typed_args("benchmark_typed_args_raw").await,

        "spl_token_mint_to_checked_signed" => {
            run_spl_token_cpi_compare("benchmark_spl_token_mint_to_checked_signed").await
        }
        "spl_token_mint_to_checked_signed_single" => {
            run_spl_token_cpi_compare("benchmark_spl_token_mint_to_checked_signed_single").await
        }
        "spl_token_mint_to_checked_multisig" => {
            run_spl_token_multisig_cpi_compare("benchmark_spl_token_mint_to_checked_multisig").await
        }
        "spl_token_transfer_checked_multisig" => {
            run_spl_token_transfer_checked_multisig_cpi_compare(
                "benchmark_spl_token_transfer_checked_multisig",
            )
            .await
        }
        "spl_token_approve_checked_multisig" => {
            run_spl_token_approve_checked_multisig_cpi_compare(
                "benchmark_spl_token_approve_checked_multisig",
            )
            .await
        }

        // Primitives: pubkey_*, pda_*, parse_*, transfer_*
        n if n.starts_with("transfer_lamports") => run_transfer_lamports_primitive(n).await,
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

async fn run_spl_token_cpi_compare(program_name: &'static str) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let noop_callee_id = Pubkey::new_from_array([0x42; 32]);
    let mut pt = ProgramTest::new(program_name, program_id, None);
    pt.add_program("benchmark_noop_callee", noop_callee_id, None);

    let mint = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();
    let destination = Pubkey::from_str("BenchPubkey11111111111111111111111111111113").unwrap();
    let (authority, _) = Pubkey::find_program_address(&[b"vault"], &program_id);

    for key in [mint, destination, authority] {
        pt.add_account(
            key,
            Account {
                lamports: 1_000_000,
                data: vec![],
                owner: program_id,
                ..Account::default()
            },
        );
    }

    let (banks_client, payer, recent_blockhash) = pt.start().await;
    let mut tx = Transaction::new_with_payer(
        &[Instruction::new_with_bytes(
            program_id,
            &[],
            vec![
                AccountMeta::new_readonly(noop_callee_id, false),
                AccountMeta::new(mint, false),
                AccountMeta::new(destination, false),
                AccountMeta::new_readonly(authority, false),
            ],
        )],
        Some(&payer.pubkey()),
    );
    tx.sign(&[&payer], recent_blockhash);
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("SPL token CPI compare succeeded"),
        Err(e) => println!("SPL token CPI compare failed: {}", e),
    }
}

async fn run_spl_token_multisig_cpi_compare(program_name: &'static str) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let noop_callee_id = Pubkey::new_from_array([0x42; 32]);
    let mut pt = ProgramTest::new(program_name, program_id, None);
    pt.add_program("benchmark_noop_callee", noop_callee_id, None);

    let mint = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();
    let destination = Pubkey::from_str("BenchPubkey11111111111111111111111111111113").unwrap();
    let multisig = Pubkey::from_str("BenchPubkey11111111111111111111111111111114").unwrap();
    let signer_one = keypair_from_seed(&[0x11u8; 64]).expect("signer one");
    let signer_two = keypair_from_seed(&[0x12u8; 64]).expect("signer two");
    let signer_three = keypair_from_seed(&[0x13u8; 64]).expect("signer three");

    for key in [
        mint,
        destination,
        multisig,
        signer_one.pubkey(),
        signer_two.pubkey(),
        signer_three.pubkey(),
    ] {
        pt.add_account(
            key,
            Account {
                lamports: 1_000_000,
                data: vec![],
                owner: program_id,
                ..Account::default()
            },
        );
    }

    let (banks_client, payer, recent_blockhash) = pt.start().await;
    let mut tx = Transaction::new_with_payer(
        &[Instruction::new_with_bytes(
            program_id,
            &[],
            vec![
                AccountMeta::new_readonly(noop_callee_id, false),
                AccountMeta::new(mint, false),
                AccountMeta::new(destination, false),
                AccountMeta::new_readonly(multisig, false),
                AccountMeta::new_readonly(signer_one.pubkey(), true),
                AccountMeta::new_readonly(signer_two.pubkey(), true),
                AccountMeta::new_readonly(signer_three.pubkey(), true),
            ],
        )],
        Some(&payer.pubkey()),
    );
    tx.sign(
        &[&payer, &signer_one, &signer_two, &signer_three],
        recent_blockhash,
    );
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("SPL token multisig CPI compare succeeded"),
        Err(e) => println!("SPL token multisig CPI compare failed: {}", e),
    }
}

async fn run_spl_token_transfer_checked_multisig_cpi_compare(program_name: &'static str) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let noop_callee_id = Pubkey::new_from_array([0x42; 32]);
    let mut pt = ProgramTest::new(program_name, program_id, None);
    pt.add_program("benchmark_noop_callee", noop_callee_id, None);

    let source = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();
    let mint = Pubkey::from_str("BenchPubkey11111111111111111111111111111113").unwrap();
    let destination = Pubkey::from_str("BenchPubkey11111111111111111111111111111114").unwrap();
    let multisig = Pubkey::from_str("BenchPubkey11111111111111111111111111111115").unwrap();
    let signer_one = keypair_from_seed(&[0x11u8; 64]).expect("signer one");
    let signer_two = keypair_from_seed(&[0x12u8; 64]).expect("signer two");
    let signer_three = keypair_from_seed(&[0x13u8; 64]).expect("signer three");

    for key in [
        source,
        mint,
        destination,
        multisig,
        signer_one.pubkey(),
        signer_two.pubkey(),
        signer_three.pubkey(),
    ] {
        pt.add_account(
            key,
            Account {
                lamports: 1_000_000,
                data: vec![],
                owner: program_id,
                ..Account::default()
            },
        );
    }

    let (banks_client, payer, recent_blockhash) = pt.start().await;
    let mut tx = Transaction::new_with_payer(
        &[Instruction::new_with_bytes(
            program_id,
            &[],
            vec![
                AccountMeta::new_readonly(noop_callee_id, false),
                AccountMeta::new(source, false),
                AccountMeta::new(mint, false),
                AccountMeta::new(destination, false),
                AccountMeta::new_readonly(multisig, false),
                AccountMeta::new_readonly(signer_one.pubkey(), true),
                AccountMeta::new_readonly(signer_two.pubkey(), true),
                AccountMeta::new_readonly(signer_three.pubkey(), true),
            ],
        )],
        Some(&payer.pubkey()),
    );
    tx.sign(
        &[&payer, &signer_one, &signer_two, &signer_three],
        recent_blockhash,
    );
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("SPL token transferChecked multisig CPI compare succeeded"),
        Err(e) => println!(
            "SPL token transferChecked multisig CPI compare failed: {}",
            e
        ),
    }
}

async fn run_spl_token_approve_checked_multisig_cpi_compare(program_name: &'static str) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let noop_callee_id = Pubkey::new_from_array([0x42; 32]);
    let mut pt = ProgramTest::new(program_name, program_id, None);
    pt.add_program("benchmark_noop_callee", noop_callee_id, None);

    let source = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();
    let mint = Pubkey::from_str("BenchPubkey11111111111111111111111111111113").unwrap();
    let delegate = Pubkey::from_str("BenchPubkey11111111111111111111111111111114").unwrap();
    let multisig = Pubkey::from_str("BenchPubkey11111111111111111111111111111115").unwrap();
    let signer_one = keypair_from_seed(&[0x11u8; 64]).expect("signer one");
    let signer_two = keypair_from_seed(&[0x12u8; 64]).expect("signer two");
    let signer_three = keypair_from_seed(&[0x13u8; 64]).expect("signer three");

    for key in [
        source,
        mint,
        delegate,
        multisig,
        signer_one.pubkey(),
        signer_two.pubkey(),
        signer_three.pubkey(),
    ] {
        pt.add_account(
            key,
            Account {
                lamports: 1_000_000,
                data: vec![],
                owner: program_id,
                ..Account::default()
            },
        );
    }

    let (banks_client, payer, recent_blockhash) = pt.start().await;
    let mut tx = Transaction::new_with_payer(
        &[Instruction::new_with_bytes(
            program_id,
            &[],
            vec![
                AccountMeta::new_readonly(noop_callee_id, false),
                AccountMeta::new(source, false),
                AccountMeta::new(mint, false),
                AccountMeta::new_readonly(delegate, false),
                AccountMeta::new_readonly(multisig, false),
                AccountMeta::new_readonly(signer_one.pubkey(), true),
                AccountMeta::new_readonly(signer_two.pubkey(), true),
                AccountMeta::new_readonly(signer_three.pubkey(), true),
            ],
        )],
        Some(&payer.pubkey()),
    );
    tx.sign(
        &[&payer, &signer_one, &signer_two, &signer_three],
        recent_blockhash,
    );
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("SPL token approveChecked multisig CPI compare succeeded"),
        Err(e) => println!(
            "SPL token approveChecked multisig CPI compare failed: {}",
            e
        ),
    }
}

async fn run_parse_accounts_primitive(program_name: &'static str, validated: bool) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let mut pt = ProgramTest::new(program_name, program_id, None);

    let to_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111113").unwrap();
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
    let payer_meta = if validated {
        AccountMeta::new(payer.pubkey(), true)
    } else {
        AccountMeta::new_readonly(payer.pubkey(), true)
    };
    let to_meta = AccountMeta::new(to_key, false);

    let mut tx = Transaction::new_with_payer(
        &[Instruction::new_with_bytes(
            program_id,
            &[],
            vec![payer_meta, to_meta],
        )],
        Some(&payer.pubkey()),
    );
    tx.sign(&[&payer], recent_blockhash);
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("Parse-accounts primitive {} succeeded", program_name),
        Err(e) => println!("Parse-accounts primitive {} failed: {}", program_name, e),
    }
}

async fn run_sysvar_access_primitive(program_name: &'static str) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let mut pt = ProgramTest::new(program_name, program_id, None);

    let sysvar_key = Pubkey::from_str("BenchPubkey11111111111111111111111111111112").unwrap();
    pt.add_account(
        sysvar_key,
        Account {
            lamports: 100_000,
            data: vec![0; 64],
            owner: program_id,
            ..Account::default()
        },
    );

    let (banks_client, payer, recent_blockhash) = pt.start().await;
    let mut tx = Transaction::new_with_payer(
        &[Instruction::new_with_bytes(
            program_id,
            &[],
            vec![AccountMeta::new_readonly(sysvar_key, false)],
        )],
        Some(&payer.pubkey()),
    );
    tx.sign(&[&payer], recent_blockhash);
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("Sysvar primitive {} succeeded", program_name),
        Err(e) => println!("Sysvar primitive {} failed: {}", program_name, e),
    }
}

// ---------------------------------------------------------------------------
// Vault end-to-end benchmarks (Zig + Pinocchio)
// ---------------------------------------------------------------------------

#[derive(Copy, Clone)]
enum VaultImpl {
    Zig,
    Pinocchio,
}

impl VaultImpl {
    fn program_id(self) -> Pubkey {
        match self {
            VaultImpl::Zig => Pubkey::from_str(VAULT_PROGRAM_ID).unwrap(),
            VaultImpl::Pinocchio => Pubkey::from_str(PINO_VAULT_PROGRAM_ID).unwrap(),
        }
    }

    fn so_name(self) -> &'static str {
        match self {
            VaultImpl::Zig => "example_vault",
            VaultImpl::Pinocchio => "bench_pinocchio_vault",
        }
    }
}

/// Derive the vault PDA for a given authority — matches the seeds used
/// in both implementations: `[b"vault", authority.key.as_ref()]`.
fn derive_vault(impl_: VaultImpl, authority: &Pubkey) -> (Pubkey, u8) {
    let program_id = impl_.program_id();
    Pubkey::find_program_address(&[b"vault", authority.as_ref()], &program_id)
}

async fn run_vault_initialize(impl_: VaultImpl) {
    let program_id = impl_.program_id();
    let mut pt = ProgramTest::new(impl_.so_name(), program_id, None);
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

    let (vault_pda, bump) = derive_vault(impl_, &auth.pubkey());

    // Initialize: tag = 0, bump = derived off-chain
    let ix_data = vec![0u8, bump];
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

async fn run_vault_deposit(impl_: VaultImpl) {
    let program_id = impl_.program_id();
    let mut pt = ProgramTest::new(impl_.so_name(), program_id, None);
    let auth = fixed_payer();
    pt.add_account(
        auth.pubkey(),
        Account {
            lamports: 1_000_000_000,
            ..Account::default()
        },
    );
    let (banks_client, payer, recent_blockhash) = pt.start().await;

    let (vault_pda, bump) = derive_vault(impl_, &auth.pubkey());

    // Step 1: initialize (off-chain bump in ix data)
    {
        let mut tx = Transaction::new_with_payer(
            &[Instruction::new_with_bytes(
                program_id,
                &[0u8, bump],
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

async fn run_vault_withdraw(impl_: VaultImpl) {
    let program_id = impl_.program_id();
    let mut pt = ProgramTest::new(impl_.so_name(), program_id, None);
    let auth = fixed_payer();
    pt.add_account(
        auth.pubkey(),
        Account {
            lamports: 1_000_000_000,
            ..Account::default()
        },
    );
    let (banks_client, payer, recent_blockhash) = pt.start().await;

    let (vault_pda, bump) = derive_vault(impl_, &auth.pubkey());
    let recipient = Keypair::new();

    // Step 1: initialize (off-chain bump in ix data)
    {
        let mut tx = Transaction::new_with_payer(
            &[Instruction::new_with_bytes(
                program_id,
                &[0u8, bump],
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

    // Step 2: deposit (so the vault has something to withdraw —
    // enough that the recipient lands above the rent-exempt floor)
    {
        let blockhash = banks_client.get_latest_blockhash().await.unwrap();
        let mut data = vec![1u8];
        data.extend_from_slice(&5_000_000u64.to_le_bytes());
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

    // Step 3: withdraw (measure this).
    // Use an amount large enough that the recipient lands above the
    // rent-exempt minimum for a zero-data system account
    // (~890_880 lamports), otherwise the runtime aborts with "insufficient
    // funds for rent" on the recipient.
    let blockhash = banks_client.get_latest_blockhash().await.unwrap();
    let mut data = vec![2u8];
    data.extend_from_slice(&1_500_000u64.to_le_bytes());
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

async fn run_token_dispatch(program_name: &'static str, tag: u32, amount: u64) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let mut pt = ProgramTest::new(program_name, program_id, None);

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

    // The dispatch program always parses two account slots up front,
    // even though burn/mint only use the first. Pass both.
    let accounts = vec![
        AccountMeta::new(source, false),
        AccountMeta::new(dest, false),
    ];

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

async fn run_typed_args(program_name: &'static str) {
    let program_id = Pubkey::from_str(BENCH_PROGRAM_ID).unwrap();
    let mut pt = ProgramTest::new(program_name, program_id, None);

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

    // Layout:
    // [u32 tag][u64 amount][u64 fee][u64 bonus][u16 flags][u8 bump][u8 mode][u64 limit]
    let mut data = Vec::with_capacity(40);
    data.extend_from_slice(&0u32.to_le_bytes());
    data.extend_from_slice(&100u64.to_le_bytes());
    data.extend_from_slice(&7u64.to_le_bytes());
    data.extend_from_slice(&11u64.to_le_bytes());
    data.extend_from_slice(&1u16.to_le_bytes());
    data.push(8u8);
    data.push(1u8);
    data.extend_from_slice(&256u64.to_le_bytes());

    let accounts = vec![
        AccountMeta::new(source, false),
        AccountMeta::new(dest, false),
    ];

    let mut tx = Transaction::new_with_payer(
        &[Instruction::new_with_bytes(program_id, &data, accounts)],
        Some(&payer.pubkey()),
    );
    tx.sign(&[&payer], recent_blockhash);
    match banks_client.process_transaction(tx).await {
        Ok(()) => println!("typed_args {} succeeded", program_name),
        Err(e) => println!("typed_args {} failed: {}", program_name, e),
    }
}
