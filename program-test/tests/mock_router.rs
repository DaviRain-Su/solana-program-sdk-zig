//! Integration tests for the mock router demo artifacts.
//!
//! Demo ABI shared by the Zig router and these Rust fixture builders:
//!
//! ```text
//! route header
//!   u8  route_tag
//!   u64 amount_in      (little-endian)
//!   u64 min_out        (little-endian)
//!   u8  hop_count
//!   u8  split_count
//!
//! route_tag = 0  exact_in_hops
//!   repeated hop_count times:
//!     u8 account_window_len
//!     u8 adapter_opcode
//!
//! route_tag = 1  exact_in_split
//!   repeated split_count times:
//!     u8 leg_len
//!     u8 leg_hop_count
//!     repeated leg_hop_count times:
//!       u8 account_window_len
//!       u8 adapter_opcode
//! ```
//!
//! Bounds / semantics:
//!   - `hop_count` is 1..=8
//!   - `split_count` is 0 for `exact_in_hops`, 1..=4 for `exact_in_split`
//!   - each split leg has at least 1 hop
//!   - `account_window_len` is 1..=8 and counts only the dynamic
//!     non-program accounts for that hop; the executable adapter
//!     program account is supplied separately in the account list
//!   - zero-hop and zero-leg payloads are invalid

use {
    mollusk_svm::Mollusk,
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_program_error::ProgramError,
    solana_pubkey::Pubkey,
    solana_sdk_ids::{bpf_loader_upgradeable, system_program},
    std::path::{Path, PathBuf},
};

mod router_program {
    solana_pubkey::declare_id!("7Z8ftDAzMvoyXnGEJye8DurzgQQXLAbYCaeeesM7UKHa");
}

mod adapter_program {
    solana_pubkey::declare_id!("7d3y2WdzxE7CfsWjkGy3WndkvZcj1EHMkzKJiFPiDecH");
}

const ROUTE_TAG_EXACT_IN_HOPS: u8 = 0;
const ROUTE_TAG_EXACT_IN_SPLIT: u8 = 1;
const MAX_HOPS: usize = 8;
const MAX_SPLIT_COUNT: usize = 4;
const MAX_ACCOUNT_WINDOW: usize = 8;

const ROUTER_RETURN_PREFIX_LEN: usize = 32;
const ADAPTER_RETURN_LEN: usize = 1 + 8 + 8 + 8 + 1 + 1 + 1 + 1 + 32 + 32;
const DUPLICATE_REJECT_FLAG: u8 = 0x80;

#[derive(Clone, Copy, Debug)]
struct HopSpec {
    account_window_len: u8,
    adapter_opcode: u8,
}

#[derive(Clone, Debug)]
struct SplitLeg {
    hops: Vec<HopSpec>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct HopTrace {
    program_id: Pubkey,
    adapter_opcode: u8,
    amount_in: u64,
    amount_out: u64,
    min_out: u64,
    hop_index: u8,
    account_count: u8,
    first_flags: u8,
    second_flags: u8,
    first_pubkey: Pubkey,
    second_pubkey: Pubkey,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct RouterTrace {
    hops: Vec<HopTrace>,
    final_output: u64,
}

fn build_exact_in_hops_route(amount_in: u64, min_out: u64, hops: &[HopSpec]) -> Vec<u8> {
    assert!(!hops.is_empty(), "zero-hop routes are invalid");
    assert!(hops.len() <= MAX_HOPS, "too many hops for demo ABI");

    let mut data = Vec::with_capacity(1 + 8 + 8 + 1 + 1 + hops.len() * 2);
    data.push(ROUTE_TAG_EXACT_IN_HOPS);
    data.extend_from_slice(&amount_in.to_le_bytes());
    data.extend_from_slice(&min_out.to_le_bytes());
    data.push(hops.len() as u8);
    data.push(0);
    for hop in hops {
        assert!(
            (1..=MAX_ACCOUNT_WINDOW as u8).contains(&hop.account_window_len),
            "account_window_len out of bounds",
        );
        data.push(hop.account_window_len);
        data.push(hop.adapter_opcode);
    }
    data
}

fn build_exact_in_split_route(amount_in: u64, min_out: u64, legs: &[SplitLeg]) -> Vec<u8> {
    assert!(!legs.is_empty(), "zero-leg split routes are invalid");
    assert!(legs.len() <= MAX_SPLIT_COUNT, "too many split legs for demo ABI");

    let total_hops: usize = legs.iter().map(|leg| leg.hops.len()).sum();
    assert!(total_hops > 0, "split routes must include at least one hop");
    assert!(total_hops <= MAX_HOPS, "split route exceeds max total hops");

    let mut data = Vec::new();
    data.push(ROUTE_TAG_EXACT_IN_SPLIT);
    data.extend_from_slice(&amount_in.to_le_bytes());
    data.extend_from_slice(&min_out.to_le_bytes());
    data.push(total_hops as u8);
    data.push(legs.len() as u8);

    for leg in legs {
        assert!(!leg.hops.is_empty(), "split legs must include at least one hop");
        let leg_len = 1 + leg.hops.len() * 2;
        assert!(leg_len <= u8::MAX as usize, "leg encoding must fit u8 length prefix");

        data.push(leg_len as u8);
        data.push(leg.hops.len() as u8);
        for hop in &leg.hops {
            assert!(
                (1..=MAX_ACCOUNT_WINDOW as u8).contains(&hop.account_window_len),
                "account_window_len out of bounds",
            );
            data.push(hop.account_window_len);
            data.push(hop.adapter_opcode);
        }
    }

    data
}

fn executable_program_account() -> Account {
    Account {
        lamports: 1_000_000,
        data: vec![],
        owner: bpf_loader_upgradeable::id(),
        executable: true,
        rent_epoch: 0,
    }
}

fn regular_account() -> Account {
    Account {
        lamports: 1_000_000,
        data: vec![],
        owner: system_program::id(),
        executable: false,
        rent_epoch: 0,
    }
}

fn program_test_dir() -> &'static Path {
    Path::new(env!("CARGO_MANIFEST_DIR"))
}

fn artifact_load_path(name: &str) -> String {
    program_test_dir()
        .join("zig-out")
        .join("lib")
        .join(name)
        .display()
        .to_string()
}

fn artifact_file_path(name: &str) -> PathBuf {
    program_test_dir()
        .join("zig-out")
        .join("lib")
        .join(format!("{name}.so"))
}

fn setup() -> Mollusk {
    let router_artifact_file = artifact_file_path("example_mock_router");
    let adapter_artifact_file = artifact_file_path("example_mock_adapter");
    assert!(
        router_artifact_file.exists(),
        "router artifact missing at {}",
        router_artifact_file.display(),
    );
    assert!(
        adapter_artifact_file.exists(),
        "adapter artifact missing at {}",
        adapter_artifact_file.display(),
    );

    let router_artifact_load = artifact_load_path("example_mock_router");
    let adapter_artifact_load = artifact_load_path("example_mock_adapter");

    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &router_program::id(),
        &router_artifact_load,
        &bpf_loader_upgradeable::id(),
    );
    mollusk.add_program(
        &adapter_program::id(),
        &adapter_artifact_load,
        &bpf_loader_upgradeable::id(),
    );
    mollusk
}

fn read_pubkey(bytes: &[u8]) -> Pubkey {
    Pubkey::new_from_array(bytes.try_into().unwrap())
}

fn parse_router_trace(data: &[u8]) -> RouterTrace {
    assert!(!data.is_empty(), "router return data must include hop count");

    let hop_count = data[0] as usize;
    let expected_len = 1 + hop_count * (ROUTER_RETURN_PREFIX_LEN + ADAPTER_RETURN_LEN) + 8;
    assert_eq!(
        data.len(),
        expected_len,
        "router return data should encode exactly {hop_count} traces plus final output",
    );

    let mut offset = 1;
    let mut hops = Vec::with_capacity(hop_count);
    for _ in 0..hop_count {
        let program_id = read_pubkey(&data[offset..offset + ROUTER_RETURN_PREFIX_LEN]);
        offset += ROUTER_RETURN_PREFIX_LEN;

        let adapter_opcode = data[offset];
        offset += 1;

        let amount_in = u64::from_le_bytes(data[offset..offset + 8].try_into().unwrap());
        offset += 8;

        let amount_out = u64::from_le_bytes(data[offset..offset + 8].try_into().unwrap());
        offset += 8;

        let min_out = u64::from_le_bytes(data[offset..offset + 8].try_into().unwrap());
        offset += 8;

        let hop_index = data[offset];
        offset += 1;

        let account_count = data[offset];
        offset += 1;

        let first_flags = data[offset];
        offset += 1;

        let second_flags = data[offset];
        offset += 1;

        let first_pubkey = read_pubkey(&data[offset..offset + 32]);
        offset += 32;

        let second_pubkey = read_pubkey(&data[offset..offset + 32]);
        offset += 32;

        hops.push(HopTrace {
            program_id,
            adapter_opcode,
            amount_in,
            amount_out,
            min_out,
            hop_index,
            account_count,
            first_flags,
            second_flags,
            first_pubkey,
            second_pubkey,
        });
    }

    let final_output = u64::from_le_bytes(data[offset..offset + 8].try_into().unwrap());
    RouterTrace { hops, final_output }
}

#[test]
fn fixture_builders_encode_documented_demo_abi() {
    let exact = build_exact_in_hops_route(
        25,
        11,
        &[HopSpec {
            account_window_len: 2,
            adapter_opcode: 7,
        }],
    );
    assert_eq!(
        exact,
        vec![
            ROUTE_TAG_EXACT_IN_HOPS,
            25,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            11,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            2,
            7,
        ],
    );

    let split = build_exact_in_split_route(
        9,
        4,
        &[SplitLeg {
            hops: vec![
                HopSpec {
                    account_window_len: 1,
                    adapter_opcode: 3,
                },
                HopSpec {
                    account_window_len: 2,
                    adapter_opcode: 5,
                },
            ],
        }],
    );
    assert_eq!(
        split,
        vec![
            ROUTE_TAG_EXACT_IN_SPLIT,
            9,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            4,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            2,
            1,
            5,
            2,
            1,
            3,
            2,
            5,
        ],
    );
}

#[test]
fn mock_router_loads_exact_artifact_and_reaches_mock_adapter_boundary() {
    let mollusk = setup();

    let alpha = Pubkey::new_from_array([0x11; 32]);
    let beta = Pubkey::new_from_array([0x22; 32]);
    let route = build_exact_in_hops_route(
        500,
        450,
        &[HopSpec {
            account_window_len: 2,
            adapter_opcode: 9,
        }],
    );

    let instruction = Instruction {
        program_id: router_program::id(),
        accounts: vec![
            AccountMeta::new_readonly(alpha, true),
            AccountMeta::new(beta, false),
            AccountMeta::new_readonly(adapter_program::id(), false),
        ],
        data: route,
    };

    let result = mollusk.process_instruction(
        &instruction,
        &[
            (alpha, regular_account()),
            (beta, regular_account()),
            (adapter_program::id(), executable_program_account()),
        ],
    );

    assert!(
        result.program_result.is_ok(),
        "mock router failed: {:?}",
        result.program_result,
    );
    let trace = parse_router_trace(&result.return_data);
    assert_eq!(trace.hops.len(), 1, "single-hop route should produce one trace");
    assert_eq!(trace.final_output, 500, "9 bps on 500 should round down to zero fee");

    let hop = &trace.hops[0];
    assert_eq!(
        hop.program_id,
        adapter_program::id(),
        "router should prove the adapter boundary by forwarding the adapter program id",
    );
    assert_eq!(hop.adapter_opcode, 9, "adapter opcode mismatch");
    assert_eq!(hop.amount_in, 500, "amount_in should stay little-endian all the way to the adapter");
    assert_eq!(hop.amount_out, 500, "mock adapter should deterministically echo the computed amount_out");
    assert_eq!(hop.min_out, 450, "min_out should stay little-endian all the way to the adapter");
    assert_eq!(hop.hop_index, 0, "hop index mismatch");
    assert_eq!(hop.account_count, 2, "adapter should observe both staged window accounts");
    assert_eq!(
        hop.first_flags,
        0b01,
        "first account should arrive as signer + readonly",
    );
    assert_eq!(
        hop.second_flags,
        0b10,
        "second account should arrive as writable + non-signer",
    );
    assert_eq!(
        hop.first_pubkey,
        alpha,
        "first staged pubkey should stay first",
    );
    assert_eq!(
        hop.second_pubkey,
        beta,
        "second staged pubkey should stay second",
    );
}

#[test]
fn mock_router_two_hop_route_executes_in_order_with_exact_min_out_and_duplicate_modes() {
    let mollusk = setup();

    let alpha = Pubkey::new_from_array([0x51; 32]);
    let beta = Pubkey::new_from_array([0x52; 32]);
    let gamma = Pubkey::new_from_array([0x53; 32]);

    let instruction = Instruction {
        program_id: router_program::id(),
        accounts: vec![
            AccountMeta::new_readonly(alpha, true),
            AccountMeta::new_readonly(alpha, true),
            AccountMeta::new_readonly(adapter_program::id(), false),
            AccountMeta::new(beta, false),
            AccountMeta::new_readonly(gamma, false),
            AccountMeta::new_readonly(adapter_program::id(), false),
        ],
        data: build_exact_in_hops_route(
            10_000,
            9_901,
            &[
                HopSpec {
                    account_window_len: 2,
                    adapter_opcode: 25,
                },
                HopSpec {
                    account_window_len: 2,
                    adapter_opcode: DUPLICATE_REJECT_FLAG | 75,
                },
            ],
        ),
    };

    let result = mollusk.process_instruction(
        &instruction,
        &[
            (alpha, regular_account()),
            (beta, regular_account()),
            (gamma, regular_account()),
            (adapter_program::id(), executable_program_account()),
        ],
    );

    assert!(
        result.program_result.is_ok(),
        "mock router failed: {:?}",
        result.program_result,
    );

    let trace = parse_router_trace(&result.return_data);
    assert_eq!(trace.hops.len(), 2, "2-hop route should execute both hops");
    assert_eq!(trace.final_output, 9_901, "final output should satisfy exact min_out equality");

    let first = &trace.hops[0];
    assert_eq!(first.program_id, adapter_program::id());
    assert_eq!(first.adapter_opcode, 25);
    assert_eq!(first.amount_in, 10_000);
    assert_eq!(first.amount_out, 9_975);
    assert_eq!(first.min_out, 9_901);
    assert_eq!(first.hop_index, 0);
    assert_eq!(first.account_count, 2);
    assert_eq!(first.first_pubkey, alpha, "allow policy should preserve the first duplicate account");
    assert_eq!(first.second_pubkey, alpha, "allow policy should resolve the second slot back to the duplicate account");

    let second = &trace.hops[1];
    assert_eq!(second.program_id, adapter_program::id());
    assert_eq!(second.adapter_opcode, DUPLICATE_REJECT_FLAG | 75);
    assert_eq!(second.amount_in, 9_975, "second hop must consume the first hop output");
    assert_eq!(second.amount_out, 9_901);
    assert_eq!(second.min_out, 9_901);
    assert_eq!(second.hop_index, 1, "router should execute hops in-order");
    assert_eq!(second.account_count, 2);
    assert_eq!(second.first_pubkey, beta);
    assert_eq!(second.second_pubkey, gamma);
}

#[test]
fn mock_router_split_route_uses_bounded_leg_segments_and_exact_output_accounting() {
    let mollusk = setup();

    let alpha = Pubkey::new_from_array([0x51; 32]);
    let beta = Pubkey::new_from_array([0x52; 32]);
    let gamma = Pubkey::new_from_array([0x53; 32]);

    let instruction = Instruction {
        program_id: router_program::id(),
        accounts: vec![
            AccountMeta::new_readonly(alpha, true),
            AccountMeta::new_readonly(alpha, true),
            AccountMeta::new_readonly(adapter_program::id(), false),
            AccountMeta::new(beta, false),
            AccountMeta::new_readonly(gamma, false),
            AccountMeta::new_readonly(adapter_program::id(), false),
        ],
        data: build_exact_in_split_route(
            10_000,
            9_900,
            &[
                SplitLeg {
                    hops: vec![HopSpec {
                        account_window_len: 2,
                        adapter_opcode: 25,
                    }],
                },
                SplitLeg {
                    hops: vec![HopSpec {
                        account_window_len: 2,
                        adapter_opcode: DUPLICATE_REJECT_FLAG | 75,
                    }],
                },
            ],
        ),
    };

    let result = mollusk.process_instruction(
        &instruction,
        &[
            (alpha, regular_account()),
            (beta, regular_account()),
            (gamma, regular_account()),
            (adapter_program::id(), executable_program_account()),
        ],
    );

    assert!(
        result.program_result.is_ok(),
        "mock router failed: {:?}",
        result.program_result,
    );

    let trace = parse_router_trace(&result.return_data);
    assert_eq!(trace.hops.len(), 2, "split route should execute exactly the declared two hops");
    assert_eq!(trace.final_output, 9_951, "split route should sum deterministic leg outputs exactly");
    assert!(
        trace.final_output > 9_900,
        "split route should also cover the greater-than-min_out happy path",
    );

    assert_eq!(trace.hops[0].hop_index, 0);
    assert_eq!(trace.hops[0].program_id, adapter_program::id());
    assert_eq!(trace.hops[0].amount_in, 5_000);
    assert_eq!(trace.hops[0].amount_out, 4_988);
    assert_eq!(trace.hops[0].account_count, 2);
    assert_eq!(trace.hops[0].first_pubkey, alpha);
    assert_eq!(trace.hops[0].second_pubkey, alpha);

    assert_eq!(trace.hops[1].hop_index, 1);
    assert_eq!(trace.hops[1].program_id, adapter_program::id());
    assert_eq!(trace.hops[1].amount_in, 5_000);
    assert_eq!(trace.hops[1].amount_out, 4_963);
    assert_eq!(trace.hops[1].account_count, 2);
    assert_eq!(trace.hops[1].first_pubkey, beta);
    assert_eq!(trace.hops[1].second_pubkey, gamma);
}

#[test]
fn fixture_builders_reject_zero_hop_and_zero_leg_routes() {
    let zero_hop = std::panic::catch_unwind(|| build_exact_in_hops_route(1, 1, &[]));
    assert!(zero_hop.is_err(), "zero-hop routes must be rejected");

    let zero_leg =
        std::panic::catch_unwind(|| build_exact_in_split_route(1, 1, &[]));
    assert!(zero_leg.is_err(), "zero-leg split routes must be rejected");
}

#[test]
fn mock_router_missing_adapter_program_fails_before_boundary() {
    let mollusk = setup();
    let alpha = Pubkey::new_from_array([0x33; 32]);
    let beta = Pubkey::new_from_array([0x44; 32]);

    let instruction = Instruction {
        program_id: router_program::id(),
        accounts: vec![
            AccountMeta::new_readonly(alpha, true),
            AccountMeta::new(beta, false),
        ],
        data: build_exact_in_hops_route(
            10,
            9,
            &[HopSpec {
                account_window_len: 2,
                adapter_opcode: 1,
            }],
        ),
    };

    let result = mollusk.process_instruction(
        &instruction,
        &[(alpha, regular_account()), (beta, regular_account())],
    );

    match result.program_result {
        mollusk_svm::result::ProgramResult::Failure(ref err) => {
            assert_eq!(
                err,
                &ProgramError::NotEnoughAccountKeys,
                "expected router to reject a missing adapter program account",
            );
        }
        other => panic!("expected NotEnoughAccountKeys failure, got {other:?}"),
    }
}
