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
    std::path::Path,
};

mod router_program {
    solana_pubkey::declare_id!("7Z8ftDAzMvoyXnGEJye8DurzgQQXLAbYCaeeesM7UKHa");
}

mod adapter_program {
    solana_pubkey::declare_id!("7d3y2WdzxE7CfsWjkGy3WndkvZcj1EHMkzKJiFPiDecH");
}

const ROUTER_ARTIFACT_LOAD_PATH: &str = "zig-out/lib/example_mock_router";
const ADAPTER_ARTIFACT_LOAD_PATH: &str = "zig-out/lib/example_mock_adapter";
const ROUTER_ARTIFACT_FILE_PATH: &str = "zig-out/lib/example_mock_router.so";
const ADAPTER_ARTIFACT_FILE_PATH: &str = "zig-out/lib/example_mock_adapter.so";

const ROUTE_TAG_EXACT_IN_HOPS: u8 = 0;
const ROUTE_TAG_EXACT_IN_SPLIT: u8 = 1;
const MAX_HOPS: usize = 8;
const MAX_SPLIT_COUNT: usize = 4;
const MAX_ACCOUNT_WINDOW: usize = 8;

const ROUTER_RETURN_PREFIX_LEN: usize = 32;
const ADAPTER_RETURN_LEN: usize = 1 + 8 + 8 + 1 + 1 + 1 + 1 + 32 + 32;

#[derive(Clone, Copy, Debug)]
struct HopSpec {
    account_window_len: u8,
    adapter_opcode: u8,
}

#[derive(Clone, Debug)]
struct SplitLeg {
    hops: Vec<HopSpec>,
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

fn setup() -> Mollusk {
    assert!(
        Path::new(ROUTER_ARTIFACT_FILE_PATH).exists(),
        "router artifact missing at {ROUTER_ARTIFACT_FILE_PATH}",
    );
    assert!(
        Path::new(ADAPTER_ARTIFACT_FILE_PATH).exists(),
        "adapter artifact missing at {ADAPTER_ARTIFACT_FILE_PATH}",
    );

    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &router_program::id(),
        ROUTER_ARTIFACT_LOAD_PATH,
        &bpf_loader_upgradeable::id(),
    );
    mollusk.add_program(
        &adapter_program::id(),
        ADAPTER_ARTIFACT_LOAD_PATH,
        &bpf_loader_upgradeable::id(),
    );
    mollusk
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
    assert_eq!(
        result.return_data.len(),
        ROUTER_RETURN_PREFIX_LEN + ADAPTER_RETURN_LEN,
        "router should forward adapter program id plus adapter echo payload",
    );

    let (returned_program, adapter_echo) = result.return_data.split_at(ROUTER_RETURN_PREFIX_LEN);
    assert_eq!(
        returned_program,
        adapter_program::id().as_ref(),
        "router should prove the adapter boundary by forwarding the adapter program id",
    );
    assert_eq!(adapter_echo[0], 9, "adapter opcode mismatch");
    assert_eq!(
        u64::from_le_bytes(adapter_echo[1..9].try_into().unwrap()),
        500,
        "amount_in should stay little-endian all the way to the adapter",
    );
    assert_eq!(
        u64::from_le_bytes(adapter_echo[9..17].try_into().unwrap()),
        450,
        "min_out should stay little-endian all the way to the adapter",
    );
    assert_eq!(adapter_echo[17], 0, "hop index mismatch");
    assert_eq!(adapter_echo[18], 2, "adapter should observe both staged window accounts");
    assert_eq!(
        adapter_echo[19],
        0b01,
        "first account should arrive as signer + readonly",
    );
    assert_eq!(
        adapter_echo[20],
        0b10,
        "second account should arrive as writable + non-signer",
    );
    assert_eq!(
        &adapter_echo[21..53],
        alpha.as_ref(),
        "first staged pubkey should stay first",
    );
    assert_eq!(
        &adapter_echo[53..85],
        beta.as_ref(),
        "second staged pubkey should stay second",
    );
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
