use serde::{Deserialize, Serialize};
use solana_epoch_schedule::EpochSchedule;
use solana_nonce::state::DurableNonce;
use solana_sdk::{
    hash::Hash,
    native_token::sol_str_to_lamports,
    pubkey::Pubkey,
    rent::Rent,
    short_vec,
    signature::{Keypair, Signature, Signer},
};
use std::fs;
use std::path::Path;

const SYSTEM_PROGRAM_ID: Pubkey = Pubkey::from_str_const("11111111111111111111111111111111");

#[derive(Serialize, Deserialize, Debug)]
pub struct PubkeyTestVector {
    pub name: String,
    pub bytes: [u8; 32],
    pub base58: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct HashTestVector {
    pub name: String,
    pub bytes: [u8; 32],
    pub hex: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SignatureTestVector {
    pub name: String,
    pub bytes: Vec<u8>,
    pub base58: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PdaTestVector {
    pub program_id: [u8; 32],
    pub seeds: Vec<Vec<u8>>,
    pub expected_pubkey: [u8; 32],
    pub expected_bump: u8,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct KeypairTestVector {
    pub name: String,
    pub seed: Vec<u8>,
    pub keypair_bytes: Vec<u8>,
    pub pubkey: Vec<u8>,
    pub message: Vec<u8>,
    pub signature: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct EpochInfoTestVector {
    pub name: String,
    pub epoch: u64,
    pub slot_index: u64,
    pub slots_in_epoch: u64,
    pub absolute_slot: u64,
    pub block_height: u64,
    pub transaction_count: Option<u64>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ShortVecTestVector {
    pub name: String,
    pub value: u16,
    pub encoded: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Sha256TestVector {
    pub name: String,
    pub input: Vec<u8>,
    pub hash: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct LamportsTestVector {
    pub name: String,
    pub sol_str: String,
    pub lamports: Option<u64>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct RentTestVector {
    pub name: String,
    pub data_len: u64,
    pub minimum_balance: u64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ClockTestVector {
    pub name: String,
    pub slot: u64,
    pub epoch_start_timestamp: i64,
    pub epoch: u64,
    pub leader_schedule_epoch: u64,
    pub unix_timestamp: i64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct EpochScheduleTestVector {
    pub name: String,
    pub slots_per_epoch: u64,
    pub warmup: bool,
    pub first_normal_epoch: u64,
    pub first_normal_slot: u64,
    pub test_slot: u64,
    pub expected_epoch: u64,
    pub expected_slot_index: u64,
    pub expected_slots_in_epoch: u64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct DurableNonceTestVector {
    pub name: String,
    pub blockhash: Vec<u8>,
    pub durable_nonce: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct BincodeTestVector {
    pub name: String,
    pub type_name: String,
    pub value_json: String,
    pub encoded: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct BorshTestVector {
    pub name: String,
    pub type_name: String,
    pub value_json: String,
    pub encoded: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SystemInstructionTestVector {
    pub name: String,
    pub instruction_type: String,
    pub encoded: Vec<u8>,
    pub from_pubkey: Option<[u8; 32]>,
    pub to_pubkey: Option<[u8; 32]>,
    pub lamports: Option<u64>,
    pub space: Option<u64>,
    pub owner: Option<[u8; 32]>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Keccak256TestVector {
    pub name: String,
    pub input: Vec<u8>,
    pub hash: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ComputeBudgetTestVector {
    pub name: String,
    pub instruction_type: String,
    pub encoded: Vec<u8>,
    pub value: u64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Ed25519VerifyTestVector {
    pub name: String,
    pub pubkey: Vec<u8>,
    pub message: Vec<u8>,
    pub signature: Vec<u8>,
    pub valid: bool,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct MessageHeaderTestVector {
    pub name: String,
    pub num_required_signatures: u8,
    pub num_readonly_signed_accounts: u8,
    pub num_readonly_unsigned_accounts: u8,
    pub encoded: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct CompiledInstructionTestVector {
    pub name: String,
    pub program_id_index: u8,
    pub accounts: Vec<u8>,
    pub data: Vec<u8>,
    pub encoded: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct FeatureStateTestVector {
    pub name: String,
    pub activated_at: Option<u64>,
    pub encoded: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct NonceVersionsTestVector {
    pub name: String,
    pub authority: Vec<u8>,
    pub durable_nonce: Vec<u8>,
    pub lamports_per_signature: u64,
    pub encoded: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct InstructionErrorTestVector {
    pub name: String,
    pub error_code: u32,
    pub custom_code: Option<u32>,
    pub encoded: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct TransactionErrorTestVector {
    pub name: String,
    pub error_type: String,
    pub instruction_index: Option<u8>,
    pub encoded: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AccountMetaTestVector {
    pub name: String,
    pub pubkey: [u8; 32],
    pub is_signer: bool,
    pub is_writable: bool,
    pub encoded: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct LoaderV3InstructionTestVector {
    pub name: String,
    pub instruction_type: String,
    pub encoded: Vec<u8>,
    pub write_offset: Option<u32>,
    pub write_bytes: Option<Vec<u8>>,
    pub max_data_len: Option<u64>,
    pub additional_bytes: Option<u32>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Blake3TestVector {
    pub name: String,
    pub input: Vec<u8>,
    pub hash: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct StakeInstructionTestVector {
    pub name: String,
    pub instruction_type: String,
    pub encoded: Vec<u8>,
    pub lamports: Option<u64>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AddressLookupTableInstructionTestVector {
    pub name: String,
    pub instruction_type: String,
    pub encoded: Vec<u8>,
    pub recent_slot: Option<u64>,
    pub bump_seed: Option<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct LoaderV4InstructionTestVector {
    pub name: String,
    pub instruction_type: String,
    pub encoded: Vec<u8>,
    pub offset: Option<u32>,
    pub bytes_len: Option<u32>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct VoteInstructionTestVector {
    pub name: String,
    pub instruction_type: String,
    pub encoded: Vec<u8>,
    pub vote_authorize: Option<u32>,
    pub commission: Option<u8>,
    pub lamports: Option<u64>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct MessageTestVector {
    pub name: String,
    pub num_required_signatures: u8,
    pub num_readonly_signed_accounts: u8,
    pub num_readonly_unsigned_accounts: u8,
    pub account_keys: Vec<[u8; 32]>,
    pub recent_blockhash: [u8; 32],
    pub instructions_count: u8,
    pub serialized: Vec<u8>,
}

pub fn generate_pubkey_vectors(output_dir: &Path) {
    let bpf_loader_upgradeable_id =
        Pubkey::from_str_const("BPFLoaderUpgradeab1e11111111111111111111111");

    let vectors = vec![
        PubkeyTestVector {
            name: "zero".to_string(),
            bytes: [0u8; 32],
            base58: Pubkey::default().to_string(),
        },
        PubkeyTestVector {
            name: "system_program".to_string(),
            bytes: SYSTEM_PROGRAM_ID.to_bytes(),
            base58: SYSTEM_PROGRAM_ID.to_string(),
        },
        PubkeyTestVector {
            name: "bpf_loader_upgradeable".to_string(),
            bytes: bpf_loader_upgradeable_id.to_bytes(),
            base58: bpf_loader_upgradeable_id.to_string(),
        },
        PubkeyTestVector {
            name: "max_bytes".to_string(),
            bytes: [0xff; 32],
            base58: Pubkey::new_from_array([0xff; 32]).to_string(),
        },
        PubkeyTestVector {
            name: "sequential".to_string(),
            bytes: [
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
                23, 24, 25, 26, 27, 28, 29, 30, 31,
            ],
            base58: Pubkey::new_from_array([
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
                23, 24, 25, 26, 27, 28, 29, 30, 31,
            ])
            .to_string(),
        },
    ];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("pubkey_vectors.json"), json).unwrap();
}

pub fn generate_hash_vectors(output_dir: &Path) {
    let vectors = vec![
        HashTestVector {
            name: "zero".to_string(),
            bytes: [0u8; 32],
            hex: Hash::default().to_string(),
        },
        HashTestVector {
            name: "max_bytes".to_string(),
            bytes: [0xff; 32],
            hex: Hash::new_from_array([0xff; 32]).to_string(),
        },
        HashTestVector {
            name: "sequential".to_string(),
            bytes: [
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
                23, 24, 25, 26, 27, 28, 29, 30, 31,
            ],
            hex: Hash::new_from_array([
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
                23, 24, 25, 26, 27, 28, 29, 30, 31,
            ])
            .to_string(),
        },
    ];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("hash_vectors.json"), json).unwrap();
}

pub fn generate_signature_vectors(output_dir: &Path) {
    let vectors = vec![
        SignatureTestVector {
            name: "zero".to_string(),
            bytes: vec![0u8; 64],
            base58: Signature::default().to_string(),
        },
        SignatureTestVector {
            name: "max_bytes".to_string(),
            bytes: vec![0xff; 64],
            base58: Signature::from([0xff; 64]).to_string(),
        },
    ];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("signature_vectors.json"), json).unwrap();
}

pub fn generate_pda_vectors(output_dir: &Path) {
    let bpf_loader_upgradeable_id =
        Pubkey::from_str_const("BPFLoaderUpgradeab1e11111111111111111111111");

    let test_cases: Vec<(Pubkey, Vec<Vec<u8>>)> = vec![
        (SYSTEM_PROGRAM_ID, vec![b"test".to_vec()]),
        (bpf_loader_upgradeable_id, vec![b"program".to_vec()]),
        (
            Pubkey::new_from_array([1u8; 32]),
            vec![b"seed1".to_vec(), b"seed2".to_vec()],
        ),
        (
            Pubkey::new_from_array([42u8; 32]),
            vec![b"long_seed_value_to_test".to_vec(), vec![1, 2, 3, 4, 5]],
        ),
    ];

    let mut vectors: Vec<PdaTestVector> = Vec::new();

    for (program_id, seeds) in test_cases {
        let seed_refs: Vec<&[u8]> = seeds.iter().map(|s| s.as_slice()).collect();
        let (pubkey, bump) = Pubkey::find_program_address(&seed_refs, &program_id);
        vectors.push(PdaTestVector {
            program_id: program_id.to_bytes(),
            seeds: seeds.clone(),
            expected_pubkey: pubkey.to_bytes(),
            expected_bump: bump,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("pda_vectors.json"), json).unwrap();
}

pub fn generate_keypair_vectors(output_dir: &Path) {
    let test_cases = vec![
        ("zero_seed", [0u8; 32], b"hello world".to_vec()),
        (
            "sequential_seed",
            {
                let mut seed = [0u8; 32];
                for i in 0..32 {
                    seed[i] = i as u8;
                }
                seed
            },
            b"test message".to_vec(),
        ),
        ("max_seed", [0xff; 32], b"".to_vec()),
        (
            "solana_example",
            {
                let mut seed = [0u8; 32];
                seed[0] = 1;
                seed
            },
            b"Sign this message for authentication".to_vec(),
        ),
    ];

    let mut vectors: Vec<KeypairTestVector> = Vec::new();

    for (name, seed, message) in test_cases {
        let keypair = Keypair::new_from_array(seed);
        let signature = keypair.sign_message(&message);
        let sig_bytes: [u8; 64] = signature.into();

        vectors.push(KeypairTestVector {
            name: name.to_string(),
            seed: seed.to_vec(),
            keypair_bytes: keypair.to_bytes().to_vec(),
            pubkey: keypair.pubkey().to_bytes().to_vec(),
            message: message.clone(),
            signature: sig_bytes.to_vec(),
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("keypair_vectors.json"), json).unwrap();
}

pub fn generate_epoch_info_vectors(output_dir: &Path) {
    let vectors = vec![
        EpochInfoTestVector {
            name: "mainnet_typical".to_string(),
            epoch: 500,
            slot_index: 216000,
            slots_in_epoch: 432000,
            absolute_slot: 216216000,
            block_height: 180000000,
            transaction_count: Some(5000000000),
        },
        EpochInfoTestVector {
            name: "epoch_start".to_string(),
            epoch: 100,
            slot_index: 0,
            slots_in_epoch: 432000,
            absolute_slot: 43200000,
            block_height: 35000000,
            transaction_count: Some(1000000000),
        },
        EpochInfoTestVector {
            name: "epoch_end".to_string(),
            epoch: 100,
            slot_index: 431999,
            slots_in_epoch: 432000,
            absolute_slot: 43631999,
            block_height: 35500000,
            transaction_count: Some(1100000000),
        },
        EpochInfoTestVector {
            name: "null_tx_count".to_string(),
            epoch: 0,
            slot_index: 0,
            slots_in_epoch: 432000,
            absolute_slot: 0,
            block_height: 0,
            transaction_count: None,
        },
        EpochInfoTestVector {
            name: "devnet".to_string(),
            epoch: 1000,
            slot_index: 50000,
            slots_in_epoch: 432000,
            absolute_slot: 432050000,
            block_height: 300000000,
            transaction_count: Some(10000000000),
        },
    ];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("epoch_info_vectors.json"), json).unwrap();
}

pub fn generate_short_vec_vectors(output_dir: &Path) {
    let test_values: Vec<(&str, u16)> = vec![
        ("zero", 0),
        ("one", 1),
        ("max_1byte", 0x7f),
        ("min_2byte", 0x80),
        ("mid_2byte", 0x3fff),
        ("max_2byte", 0x3fff),
        ("min_3byte", 0x4000),
        ("mid_3byte", 0x8000),
        ("max_u16", 0xffff),
    ];

    let mut vectors: Vec<ShortVecTestVector> = Vec::new();

    for (name, value) in test_values {
        let short_u16 = short_vec::ShortU16(value);
        let encoded = bincode::serialize(&short_u16).unwrap();
        vectors.push(ShortVecTestVector {
            name: name.to_string(),
            value,
            encoded,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("short_vec_vectors.json"), json).unwrap();
}

pub fn generate_sha256_vectors(output_dir: &Path) {
    use solana_sdk::hash::hashv;

    let test_cases: Vec<(&str, Vec<u8>)> = vec![
        ("empty", vec![]),
        ("hello", b"hello".to_vec()),
        ("hello_world", b"hello world".to_vec()),
        ("solana", b"solana".to_vec()),
        ("binary_data", vec![0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
        ("all_zeros", vec![0u8; 32]),
        ("all_ones", vec![0xff; 32]),
    ];

    let mut vectors: Vec<Sha256TestVector> = Vec::new();

    for (name, input) in test_cases {
        let hash = hashv(&[&input]);
        vectors.push(Sha256TestVector {
            name: name.to_string(),
            input: input.clone(),
            hash: hash.to_bytes().to_vec(),
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("sha256_vectors.json"), json).unwrap();
}

pub fn generate_lamports_vectors(output_dir: &Path) {
    let vectors = vec![
        LamportsTestVector {
            name: "zero".to_string(),
            sol_str: "0".to_string(),
            lamports: sol_str_to_lamports("0"),
        },
        LamportsTestVector {
            name: "zero_decimal".to_string(),
            sol_str: "0.0".to_string(),
            lamports: sol_str_to_lamports("0.0"),
        },
        LamportsTestVector {
            name: "one_sol".to_string(),
            sol_str: "1".to_string(),
            lamports: sol_str_to_lamports("1"),
        },
        LamportsTestVector {
            name: "one_sol_decimal".to_string(),
            sol_str: "1.0".to_string(),
            lamports: sol_str_to_lamports("1.0"),
        },
        LamportsTestVector {
            name: "half_sol".to_string(),
            sol_str: "0.5".to_string(),
            lamports: sol_str_to_lamports("0.5"),
        },
        LamportsTestVector {
            name: "one_and_half_sol".to_string(),
            sol_str: "1.5".to_string(),
            lamports: sol_str_to_lamports("1.5"),
        },
        LamportsTestVector {
            name: "one_lamport".to_string(),
            sol_str: "0.000000001".to_string(),
            lamports: sol_str_to_lamports("0.000000001"),
        },
        LamportsTestVector {
            name: "full_precision".to_string(),
            sol_str: "1.123456789".to_string(),
            lamports: sol_str_to_lamports("1.123456789"),
        },
        LamportsTestVector {
            name: "large_value".to_string(),
            sol_str: "1000".to_string(),
            lamports: sol_str_to_lamports("1000"),
        },
        LamportsTestVector {
            name: "complex_decimal".to_string(),
            sol_str: "8.50228288".to_string(),
            lamports: sol_str_to_lamports("8.50228288"),
        },
        LamportsTestVector {
            name: "empty_string".to_string(),
            sol_str: "".to_string(),
            lamports: sol_str_to_lamports(""),
        },
        LamportsTestVector {
            name: "just_dot".to_string(),
            sol_str: ".".to_string(),
            lamports: sol_str_to_lamports("."),
        },
        LamportsTestVector {
            name: "negative".to_string(),
            sol_str: "-1".to_string(),
            lamports: sol_str_to_lamports("-1"),
        },
        LamportsTestVector {
            name: "invalid_chars".to_string(),
            sol_str: "abc".to_string(),
            lamports: sol_str_to_lamports("abc"),
        },
        LamportsTestVector {
            name: "multiple_dots".to_string(),
            sol_str: "1.2.3".to_string(),
            lamports: sol_str_to_lamports("1.2.3"),
        },
    ];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("lamports_vectors.json"), json).unwrap();
}

pub fn generate_rent_vectors(output_dir: &Path) {
    let rent = Rent::default();

    // Test various data lengths
    let test_cases: Vec<(&str, u64)> = vec![
        ("empty", 0),
        ("small", 100),
        ("medium", 1000),
        ("large", 10000),
        ("account_data", 165), // Token account size
        ("mint_data", 82),     // Mint account size
        ("nonce_data", 80),    // Nonce account size
    ];

    let mut vectors: Vec<RentTestVector> = Vec::new();

    for (name, data_len) in test_cases {
        let minimum_balance = rent.minimum_balance(data_len as usize);
        vectors.push(RentTestVector {
            name: name.to_string(),
            data_len,
            minimum_balance,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("rent_vectors.json"), json).unwrap();
}

pub fn generate_clock_vectors(output_dir: &Path) {
    let vectors = vec![
        ClockTestVector {
            name: "genesis".to_string(),
            slot: 0,
            epoch_start_timestamp: 0,
            epoch: 0,
            leader_schedule_epoch: 0,
            unix_timestamp: 0,
        },
        ClockTestVector {
            name: "mainnet_typical".to_string(),
            slot: 250_000_000,
            epoch_start_timestamp: 1700000000,
            epoch: 578,
            leader_schedule_epoch: 579,
            unix_timestamp: 1700100000,
        },
        ClockTestVector {
            name: "negative_timestamp".to_string(),
            slot: 1000,
            epoch_start_timestamp: -86400,
            epoch: 0,
            leader_schedule_epoch: 0,
            unix_timestamp: -1,
        },
        ClockTestVector {
            name: "max_values".to_string(),
            slot: u64::MAX,
            epoch_start_timestamp: i64::MAX,
            epoch: u64::MAX,
            leader_schedule_epoch: u64::MAX,
            unix_timestamp: i64::MAX,
        },
    ];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("clock_vectors.json"), json).unwrap();
}

pub fn generate_epoch_schedule_vectors(output_dir: &Path) {
    let schedule_no_warmup = EpochSchedule::without_warmup();
    let schedule_with_warmup = EpochSchedule::custom(256, 256, true);

    let mut vectors: Vec<EpochScheduleTestVector> = Vec::new();

    let no_warmup_tests = vec![
        ("no_warmup_slot_0", 0u64),
        ("no_warmup_slot_100", 100),
        ("no_warmup_epoch_boundary", 432000),
        ("no_warmup_epoch_5", 432000 * 5 + 1000),
    ];

    for (name, slot) in no_warmup_tests {
        let (epoch, slot_index) = schedule_no_warmup.get_epoch_and_slot_index(slot);
        vectors.push(EpochScheduleTestVector {
            name: name.to_string(),
            slots_per_epoch: schedule_no_warmup.slots_per_epoch,
            warmup: false,
            first_normal_epoch: schedule_no_warmup.first_normal_epoch,
            first_normal_slot: schedule_no_warmup.first_normal_slot,
            test_slot: slot,
            expected_epoch: epoch,
            expected_slot_index: slot_index,
            expected_slots_in_epoch: schedule_no_warmup.get_slots_in_epoch(epoch),
        });
    }

    let warmup_tests = vec![
        ("warmup_epoch_0", 0u64),
        ("warmup_epoch_0_end", 31),
        ("warmup_epoch_1", 32),
        ("warmup_epoch_2", 96),
        ("warmup_first_normal", 224),
        ("warmup_normal_epoch", 480),
    ];

    for (name, slot) in warmup_tests {
        let (epoch, slot_index) = schedule_with_warmup.get_epoch_and_slot_index(slot);
        vectors.push(EpochScheduleTestVector {
            name: name.to_string(),
            slots_per_epoch: schedule_with_warmup.slots_per_epoch,
            warmup: true,
            first_normal_epoch: schedule_with_warmup.first_normal_epoch,
            first_normal_slot: schedule_with_warmup.first_normal_slot,
            test_slot: slot,
            expected_epoch: epoch,
            expected_slot_index: slot_index,
            expected_slots_in_epoch: schedule_with_warmup.get_slots_in_epoch(epoch),
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("epoch_schedule_vectors.json"), json).unwrap();
}

pub fn generate_durable_nonce_vectors(output_dir: &Path) {
    let test_blockhashes: Vec<(&str, [u8; 32])> = vec![
        ("zero", [0u8; 32]),
        ("one", [1u8; 32]),
        ("sequential", {
            let mut arr = [0u8; 32];
            for i in 0..32 {
                arr[i] = i as u8;
            }
            arr
        }),
        ("max", [0xFFu8; 32]),
    ];

    let mut vectors: Vec<DurableNonceTestVector> = Vec::new();

    for (name, blockhash_bytes) in test_blockhashes {
        let blockhash = Hash::new_from_array(blockhash_bytes);
        let durable_nonce = DurableNonce::from_blockhash(&blockhash);
        let nonce_hash = durable_nonce.as_hash();

        vectors.push(DurableNonceTestVector {
            name: name.to_string(),
            blockhash: blockhash_bytes.to_vec(),
            durable_nonce: nonce_hash.to_bytes().to_vec(),
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("durable_nonce_vectors.json"), json).unwrap();
}

pub fn generate_bincode_vectors(output_dir: &Path) {
    let mut vectors: Vec<BincodeTestVector> = Vec::new();

    vectors.push(BincodeTestVector {
        name: "u8_zero".to_string(),
        type_name: "u8".to_string(),
        value_json: "0".to_string(),
        encoded: bincode::serialize(&0u8).unwrap(),
    });

    vectors.push(BincodeTestVector {
        name: "u8_max".to_string(),
        type_name: "u8".to_string(),
        value_json: "255".to_string(),
        encoded: bincode::serialize(&255u8).unwrap(),
    });

    vectors.push(BincodeTestVector {
        name: "u16_value".to_string(),
        type_name: "u16".to_string(),
        value_json: "12345".to_string(),
        encoded: bincode::serialize(&12345u16).unwrap(),
    });

    vectors.push(BincodeTestVector {
        name: "u32_value".to_string(),
        type_name: "u32".to_string(),
        value_json: "305419896".to_string(),
        encoded: bincode::serialize(&0x12345678u32).unwrap(),
    });

    vectors.push(BincodeTestVector {
        name: "u64_value".to_string(),
        type_name: "u64".to_string(),
        value_json: "1311768467463790320".to_string(), // 0x123456789ABCDEF0
        encoded: bincode::serialize(&0x123456789ABCDEF0u64).unwrap(),
    });

    vectors.push(BincodeTestVector {
        name: "i32_negative".to_string(),
        type_name: "i32".to_string(),
        value_json: "-12345".to_string(),
        encoded: bincode::serialize(&-12345i32).unwrap(),
    });

    vectors.push(BincodeTestVector {
        name: "i64_negative".to_string(),
        type_name: "i64".to_string(),
        value_json: "-9876543210".to_string(),
        encoded: bincode::serialize(&-9876543210i64).unwrap(),
    });

    vectors.push(BincodeTestVector {
        name: "bool_true".to_string(),
        type_name: "bool".to_string(),
        value_json: "true".to_string(),
        encoded: bincode::serialize(&true).unwrap(),
    });

    vectors.push(BincodeTestVector {
        name: "bool_false".to_string(),
        type_name: "bool".to_string(),
        value_json: "false".to_string(),
        encoded: bincode::serialize(&false).unwrap(),
    });

    vectors.push(BincodeTestVector {
        name: "option_some_u32".to_string(),
        type_name: "Option<u32>".to_string(),
        value_json: "42".to_string(),
        encoded: bincode::serialize(&Some(42u32)).unwrap(),
    });

    vectors.push(BincodeTestVector {
        name: "option_none_u32".to_string(),
        type_name: "Option<u32>".to_string(),
        value_json: "null".to_string(),
        encoded: bincode::serialize(&None::<u32>).unwrap(),
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("bincode_vectors.json"), json).unwrap();
}

pub fn generate_borsh_vectors(output_dir: &Path) {
    use borsh::BorshSerialize;

    let mut vectors: Vec<BorshTestVector> = Vec::new();

    let mut buf = Vec::new();
    BorshSerialize::serialize(&0u8, &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "u8_zero".to_string(),
        type_name: "u8".to_string(),
        value_json: "0".to_string(),
        encoded: buf.clone(),
    });

    buf.clear();
    BorshSerialize::serialize(&255u8, &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "u8_max".to_string(),
        type_name: "u8".to_string(),
        value_json: "255".to_string(),
        encoded: buf.clone(),
    });

    buf.clear();
    BorshSerialize::serialize(&12345u16, &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "u16_value".to_string(),
        type_name: "u16".to_string(),
        value_json: "12345".to_string(),
        encoded: buf.clone(),
    });

    buf.clear();
    BorshSerialize::serialize(&0x12345678u32, &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "u32_value".to_string(),
        type_name: "u32".to_string(),
        value_json: "305419896".to_string(),
        encoded: buf.clone(),
    });

    buf.clear();
    BorshSerialize::serialize(&0x123456789ABCDEF0u64, &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "u64_value".to_string(),
        type_name: "u64".to_string(),
        value_json: "1311768467463790320".to_string(),
        encoded: buf.clone(),
    });

    buf.clear();
    BorshSerialize::serialize(&-12345i32, &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "i32_negative".to_string(),
        type_name: "i32".to_string(),
        value_json: "-12345".to_string(),
        encoded: buf.clone(),
    });

    buf.clear();
    BorshSerialize::serialize(&-9876543210i64, &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "i64_negative".to_string(),
        type_name: "i64".to_string(),
        value_json: "-9876543210".to_string(),
        encoded: buf.clone(),
    });

    buf.clear();
    BorshSerialize::serialize(&true, &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "bool_true".to_string(),
        type_name: "bool".to_string(),
        value_json: "true".to_string(),
        encoded: buf.clone(),
    });

    buf.clear();
    BorshSerialize::serialize(&false, &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "bool_false".to_string(),
        type_name: "bool".to_string(),
        value_json: "false".to_string(),
        encoded: buf.clone(),
    });

    buf.clear();
    BorshSerialize::serialize(&Some(42u32), &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "option_some_u32".to_string(),
        type_name: "Option<u32>".to_string(),
        value_json: "42".to_string(),
        encoded: buf.clone(),
    });

    buf.clear();
    BorshSerialize::serialize(&None::<u32>, &mut buf).unwrap();
    vectors.push(BorshTestVector {
        name: "option_none_u32".to_string(),
        type_name: "Option<u32>".to_string(),
        value_json: "null".to_string(),
        encoded: buf.clone(),
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("borsh_vectors.json"), json).unwrap();
}

pub fn generate_system_instruction_vectors(output_dir: &Path) {
    use solana_system_interface::instruction as system_instruction;

    let from_pubkey = Pubkey::from_str_const("4rL4RCWHz3iNCdCaveD8KcHfV9YagGbXgSYq9QWPZ4Zx");
    let to_pubkey = Pubkey::from_str_const("8opHzTAnfzRpPEx21XtnrVTX28YQuCpAjcn1PczScKh");
    let owner = Pubkey::from_str_const("BPFLoaderUpgradeab1e11111111111111111111111");

    let mut vectors: Vec<SystemInstructionTestVector> = Vec::new();

    let ix = system_instruction::transfer(&from_pubkey, &to_pubkey, 1_000_000_000);
    vectors.push(SystemInstructionTestVector {
        name: "transfer_1_sol".to_string(),
        instruction_type: "Transfer".to_string(),
        encoded: ix.data.clone(),
        from_pubkey: Some(from_pubkey.to_bytes()),
        to_pubkey: Some(to_pubkey.to_bytes()),
        lamports: Some(1_000_000_000),
        space: None,
        owner: None,
    });

    let ix = system_instruction::transfer(&from_pubkey, &to_pubkey, 0);
    vectors.push(SystemInstructionTestVector {
        name: "transfer_zero".to_string(),
        instruction_type: "Transfer".to_string(),
        encoded: ix.data.clone(),
        from_pubkey: Some(from_pubkey.to_bytes()),
        to_pubkey: Some(to_pubkey.to_bytes()),
        lamports: Some(0),
        space: None,
        owner: None,
    });

    let ix = system_instruction::transfer(&from_pubkey, &to_pubkey, u64::MAX);
    vectors.push(SystemInstructionTestVector {
        name: "transfer_max".to_string(),
        instruction_type: "Transfer".to_string(),
        encoded: ix.data.clone(),
        from_pubkey: Some(from_pubkey.to_bytes()),
        to_pubkey: Some(to_pubkey.to_bytes()),
        lamports: Some(u64::MAX),
        space: None,
        owner: None,
    });

    let ix = system_instruction::create_account(&from_pubkey, &to_pubkey, 1_000_000, 100, &owner);
    vectors.push(SystemInstructionTestVector {
        name: "create_account".to_string(),
        instruction_type: "CreateAccount".to_string(),
        encoded: ix.data.clone(),
        from_pubkey: Some(from_pubkey.to_bytes()),
        to_pubkey: Some(to_pubkey.to_bytes()),
        lamports: Some(1_000_000),
        space: Some(100),
        owner: Some(owner.to_bytes()),
    });

    let ix = system_instruction::assign(&to_pubkey, &owner);
    vectors.push(SystemInstructionTestVector {
        name: "assign".to_string(),
        instruction_type: "Assign".to_string(),
        encoded: ix.data.clone(),
        from_pubkey: None,
        to_pubkey: Some(to_pubkey.to_bytes()),
        lamports: None,
        space: None,
        owner: Some(owner.to_bytes()),
    });

    let ix = system_instruction::allocate(&to_pubkey, 200);
    vectors.push(SystemInstructionTestVector {
        name: "allocate".to_string(),
        instruction_type: "Allocate".to_string(),
        encoded: ix.data.clone(),
        from_pubkey: None,
        to_pubkey: Some(to_pubkey.to_bytes()),
        lamports: None,
        space: Some(200),
        owner: None,
    });

    let nonce_pubkey = Pubkey::from_str_const("9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin");
    let authority_pubkey = Pubkey::from_str_const("HWHvQhFmJB6gPtqJx3gjxHX1iDZhQ9WJorxwb3iTWVHi");

    let ix = system_instruction::advance_nonce_account(&nonce_pubkey, &authority_pubkey);
    vectors.push(SystemInstructionTestVector {
        name: "advance_nonce".to_string(),
        instruction_type: "AdvanceNonceAccount".to_string(),
        encoded: ix.data.clone(),
        from_pubkey: None,
        to_pubkey: None,
        lamports: None,
        space: None,
        owner: None,
    });

    let ix = system_instruction::withdraw_nonce_account(
        &nonce_pubkey,
        &authority_pubkey,
        &to_pubkey,
        500_000,
    );
    vectors.push(SystemInstructionTestVector {
        name: "withdraw_nonce".to_string(),
        instruction_type: "WithdrawNonceAccount".to_string(),
        encoded: ix.data.clone(),
        from_pubkey: None,
        to_pubkey: None,
        lamports: Some(500_000),
        space: None,
        owner: None,
    });

    let ix =
        system_instruction::authorize_nonce_account(&nonce_pubkey, &authority_pubkey, &to_pubkey);
    vectors.push(SystemInstructionTestVector {
        name: "authorize_nonce".to_string(),
        instruction_type: "AuthorizeNonceAccount".to_string(),
        encoded: ix.data.clone(),
        from_pubkey: None,
        to_pubkey: None,
        lamports: None,
        space: None,
        owner: None,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("system_instruction_vectors.json"), json).unwrap();
}

pub fn generate_keccak256_vectors(output_dir: &Path) {
    use solana_keccak_hasher::hash;

    let mut vectors: Vec<Keccak256TestVector> = Vec::new();

    vectors.push(Keccak256TestVector {
        name: "empty".to_string(),
        input: vec![],
        hash: hash(&[]).to_bytes().to_vec(),
    });

    vectors.push(Keccak256TestVector {
        name: "hello".to_string(),
        input: b"hello".to_vec(),
        hash: hash(b"hello").to_bytes().to_vec(),
    });

    vectors.push(Keccak256TestVector {
        name: "hello_world".to_string(),
        input: b"hello world".to_vec(),
        hash: hash(b"hello world").to_bytes().to_vec(),
    });

    vectors.push(Keccak256TestVector {
        name: "solana".to_string(),
        input: b"Solana".to_vec(),
        hash: hash(b"Solana").to_bytes().to_vec(),
    });

    vectors.push(Keccak256TestVector {
        name: "single_byte".to_string(),
        input: vec![0x42],
        hash: hash(&[0x42]).to_bytes().to_vec(),
    });

    vectors.push(Keccak256TestVector {
        name: "zeros_32".to_string(),
        input: vec![0u8; 32],
        hash: hash(&[0u8; 32]).to_bytes().to_vec(),
    });

    vectors.push(Keccak256TestVector {
        name: "ones_32".to_string(),
        input: vec![0xffu8; 32],
        hash: hash(&[0xffu8; 32]).to_bytes().to_vec(),
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("keccak256_vectors.json"), json).unwrap();
}

pub fn generate_compute_budget_vectors(output_dir: &Path) {
    use solana_compute_budget_interface::ComputeBudgetInstruction;

    let mut vectors: Vec<ComputeBudgetTestVector> = Vec::new();

    let ix = ComputeBudgetInstruction::set_compute_unit_limit(400_000);
    vectors.push(ComputeBudgetTestVector {
        name: "set_compute_unit_limit_400k".to_string(),
        instruction_type: "SetComputeUnitLimit".to_string(),
        encoded: ix.data.clone(),
        value: 400_000,
    });

    let ix = ComputeBudgetInstruction::set_compute_unit_limit(1_400_000);
    vectors.push(ComputeBudgetTestVector {
        name: "set_compute_unit_limit_max".to_string(),
        instruction_type: "SetComputeUnitLimit".to_string(),
        encoded: ix.data.clone(),
        value: 1_400_000,
    });

    let ix = ComputeBudgetInstruction::set_compute_unit_price(1_000);
    vectors.push(ComputeBudgetTestVector {
        name: "set_compute_unit_price_1000".to_string(),
        instruction_type: "SetComputeUnitPrice".to_string(),
        encoded: ix.data.clone(),
        value: 1_000,
    });

    let ix = ComputeBudgetInstruction::set_compute_unit_price(1_000_000);
    vectors.push(ComputeBudgetTestVector {
        name: "set_compute_unit_price_1m".to_string(),
        instruction_type: "SetComputeUnitPrice".to_string(),
        encoded: ix.data.clone(),
        value: 1_000_000,
    });

    let ix = ComputeBudgetInstruction::request_heap_frame(64 * 1024);
    vectors.push(ComputeBudgetTestVector {
        name: "request_heap_frame_64k".to_string(),
        instruction_type: "RequestHeapFrame".to_string(),
        encoded: ix.data.clone(),
        value: 64 * 1024,
    });

    let ix = ComputeBudgetInstruction::request_heap_frame(256 * 1024);
    vectors.push(ComputeBudgetTestVector {
        name: "request_heap_frame_256k".to_string(),
        instruction_type: "RequestHeapFrame".to_string(),
        encoded: ix.data.clone(),
        value: 256 * 1024,
    });

    let ix = ComputeBudgetInstruction::set_loaded_accounts_data_size_limit(1024 * 1024);
    vectors.push(ComputeBudgetTestVector {
        name: "set_loaded_accounts_data_size_1m".to_string(),
        instruction_type: "SetLoadedAccountsDataSizeLimit".to_string(),
        encoded: ix.data.clone(),
        value: 1024 * 1024,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("compute_budget_vectors.json"), json).unwrap();
}

pub fn generate_ed25519_verify_vectors(output_dir: &Path) {
    let mut vectors: Vec<Ed25519VerifyTestVector> = Vec::new();

    let keypair = Keypair::new();
    let message = b"test message for signature verification";
    let signature = keypair.sign_message(message);

    vectors.push(Ed25519VerifyTestVector {
        name: "valid_signature".to_string(),
        pubkey: keypair.pubkey().to_bytes().to_vec(),
        message: message.to_vec(),
        signature: <[u8; 64]>::from(signature).to_vec(),
        valid: true,
    });

    let wrong_message = b"wrong message";
    vectors.push(Ed25519VerifyTestVector {
        name: "wrong_message".to_string(),
        pubkey: keypair.pubkey().to_bytes().to_vec(),
        message: wrong_message.to_vec(),
        signature: <[u8; 64]>::from(signature).to_vec(),
        valid: false,
    });

    let other_keypair = Keypair::new();
    vectors.push(Ed25519VerifyTestVector {
        name: "wrong_pubkey".to_string(),
        pubkey: other_keypair.pubkey().to_bytes().to_vec(),
        message: message.to_vec(),
        signature: <[u8; 64]>::from(signature).to_vec(),
        valid: false,
    });

    let empty_message = b"";
    let empty_sig = keypair.sign_message(empty_message);
    vectors.push(Ed25519VerifyTestVector {
        name: "empty_message".to_string(),
        pubkey: keypair.pubkey().to_bytes().to_vec(),
        message: empty_message.to_vec(),
        signature: <[u8; 64]>::from(empty_sig).to_vec(),
        valid: true,
    });

    let long_message = vec![0x42u8; 1000];
    let long_sig = keypair.sign_message(&long_message);
    vectors.push(Ed25519VerifyTestVector {
        name: "long_message".to_string(),
        pubkey: keypair.pubkey().to_bytes().to_vec(),
        message: long_message,
        signature: <[u8; 64]>::from(long_sig).to_vec(),
        valid: true,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("ed25519_verify_vectors.json"), json).unwrap();
}

pub fn generate_message_header_vectors(output_dir: &Path) {
    use solana_sdk::message::MessageHeader;

    let mut vectors: Vec<MessageHeaderTestVector> = Vec::new();

    let header = MessageHeader {
        num_required_signatures: 1,
        num_readonly_signed_accounts: 0,
        num_readonly_unsigned_accounts: 1,
    };
    vectors.push(MessageHeaderTestVector {
        name: "simple_transfer".to_string(),
        num_required_signatures: header.num_required_signatures,
        num_readonly_signed_accounts: header.num_readonly_signed_accounts,
        num_readonly_unsigned_accounts: header.num_readonly_unsigned_accounts,
        encoded: vec![
            header.num_required_signatures,
            header.num_readonly_signed_accounts,
            header.num_readonly_unsigned_accounts,
        ],
    });

    let header = MessageHeader {
        num_required_signatures: 2,
        num_readonly_signed_accounts: 1,
        num_readonly_unsigned_accounts: 3,
    };
    vectors.push(MessageHeaderTestVector {
        name: "multi_sig".to_string(),
        num_required_signatures: header.num_required_signatures,
        num_readonly_signed_accounts: header.num_readonly_signed_accounts,
        num_readonly_unsigned_accounts: header.num_readonly_unsigned_accounts,
        encoded: vec![
            header.num_required_signatures,
            header.num_readonly_signed_accounts,
            header.num_readonly_unsigned_accounts,
        ],
    });

    let header = MessageHeader {
        num_required_signatures: 0,
        num_readonly_signed_accounts: 0,
        num_readonly_unsigned_accounts: 0,
    };
    vectors.push(MessageHeaderTestVector {
        name: "empty".to_string(),
        num_required_signatures: header.num_required_signatures,
        num_readonly_signed_accounts: header.num_readonly_signed_accounts,
        num_readonly_unsigned_accounts: header.num_readonly_unsigned_accounts,
        encoded: vec![0, 0, 0],
    });

    let header = MessageHeader {
        num_required_signatures: 255,
        num_readonly_signed_accounts: 128,
        num_readonly_unsigned_accounts: 64,
    };
    vectors.push(MessageHeaderTestVector {
        name: "max_values".to_string(),
        num_required_signatures: header.num_required_signatures,
        num_readonly_signed_accounts: header.num_readonly_signed_accounts,
        num_readonly_unsigned_accounts: header.num_readonly_unsigned_accounts,
        encoded: vec![255, 128, 64],
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("message_header_vectors.json"), json).unwrap();
}

pub fn generate_compiled_instruction_vectors(output_dir: &Path) {
    let mut vectors: Vec<CompiledInstructionTestVector> = Vec::new();

    fn encode_short_u16(val: u16) -> Vec<u8> {
        if val < 0x80 {
            vec![val as u8]
        } else if val < 0x4000 {
            vec![(val & 0x7f | 0x80) as u8, (val >> 7) as u8]
        } else {
            vec![
                (val & 0x7f | 0x80) as u8,
                ((val >> 7) & 0x7f | 0x80) as u8,
                (val >> 14) as u8,
            ]
        }
    }

    let accounts: Vec<u8> = vec![0, 1];
    let data: Vec<u8> = vec![2, 0, 0, 0, 0, 202, 154, 59, 0, 0, 0, 0];
    let mut encoded: Vec<u8> = Vec::new();
    encoded.push(2);
    encoded.extend(encode_short_u16(accounts.len() as u16));
    encoded.extend(&accounts);
    encoded.extend(encode_short_u16(data.len() as u16));
    encoded.extend(&data);

    vectors.push(CompiledInstructionTestVector {
        name: "transfer".to_string(),
        program_id_index: 2,
        accounts: accounts.clone(),
        data: data.clone(),
        encoded,
    });

    let accounts: Vec<u8> = vec![0];
    let data: Vec<u8> = vec![3, 232, 3, 0, 0, 0, 0, 0, 0];
    let mut encoded: Vec<u8> = Vec::new();
    encoded.push(1);
    encoded.extend(encode_short_u16(accounts.len() as u16));
    encoded.extend(&accounts);
    encoded.extend(encode_short_u16(data.len() as u16));
    encoded.extend(&data);

    vectors.push(CompiledInstructionTestVector {
        name: "compute_budget".to_string(),
        program_id_index: 1,
        accounts: accounts.clone(),
        data: data.clone(),
        encoded,
    });

    let accounts: Vec<u8> = vec![];
    let data: Vec<u8> = vec![];
    let mut encoded: Vec<u8> = Vec::new();
    encoded.push(0);
    encoded.extend(encode_short_u16(accounts.len() as u16));
    encoded.extend(encode_short_u16(data.len() as u16));

    vectors.push(CompiledInstructionTestVector {
        name: "empty".to_string(),
        program_id_index: 0,
        accounts,
        data,
        encoded,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("compiled_instruction_vectors.json"), json).unwrap();
}

pub fn generate_feature_state_vectors(output_dir: &Path) {
    let mut vectors: Vec<FeatureStateTestVector> = Vec::new();

    vectors.push(FeatureStateTestVector {
        name: "unactivated".to_string(),
        activated_at: None,
        encoded: vec![0, 0, 0, 0, 0, 0, 0, 0, 0],
    });

    vectors.push(FeatureStateTestVector {
        name: "activated_slot_0".to_string(),
        activated_at: Some(0),
        encoded: vec![1, 0, 0, 0, 0, 0, 0, 0, 0],
    });

    vectors.push(FeatureStateTestVector {
        name: "activated_slot_100".to_string(),
        activated_at: Some(100),
        encoded: vec![1, 100, 0, 0, 0, 0, 0, 0, 0],
    });

    vectors.push(FeatureStateTestVector {
        name: "activated_slot_max".to_string(),
        activated_at: Some(u64::MAX),
        encoded: vec![1, 255, 255, 255, 255, 255, 255, 255, 255],
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("feature_state_vectors.json"), json).unwrap();
}

pub fn generate_nonce_versions_vectors(output_dir: &Path) {
    use solana_nonce::state::{Data, DurableNonce, State};
    use solana_nonce::versions::Versions;

    let mut vectors: Vec<NonceVersionsTestVector> = Vec::new();

    let authority = Pubkey::from_str_const("4rL4RCWHz3iNCdCaveD8KcHfV9YagGbXgSYq9QWPZ4Zx");
    let blockhash = Hash::new_from_array([0x42; 32]);
    let durable_nonce = DurableNonce::from_blockhash(&blockhash);
    let fee_calculator_lamports = 5000u64;

    let data = Data::new(authority, durable_nonce, fee_calculator_lamports);
    let state = State::Initialized(data);
    let versions = Versions::new(state);
    let encoded = bincode::serialize(&versions).unwrap();

    vectors.push(NonceVersionsTestVector {
        name: "initialized".to_string(),
        authority: authority.to_bytes().to_vec(),
        durable_nonce: durable_nonce.as_hash().to_bytes().to_vec(),
        lamports_per_signature: fee_calculator_lamports,
        encoded,
    });

    let uninitialized = Versions::new(State::Uninitialized);
    let encoded = bincode::serialize(&uninitialized).unwrap();

    vectors.push(NonceVersionsTestVector {
        name: "uninitialized".to_string(),
        authority: vec![],
        durable_nonce: vec![],
        lamports_per_signature: 0,
        encoded,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("nonce_versions_vectors.json"), json).unwrap();
}

pub fn generate_instruction_error_vectors(output_dir: &Path) {
    use solana_sdk::instruction::InstructionError;

    let mut vectors: Vec<InstructionErrorTestVector> = Vec::new();

    let err = InstructionError::GenericError;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(InstructionErrorTestVector {
        name: "generic_error".to_string(),
        error_code: 0,
        custom_code: None,
        encoded,
    });

    let err = InstructionError::InvalidArgument;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(InstructionErrorTestVector {
        name: "invalid_argument".to_string(),
        error_code: 1,
        custom_code: None,
        encoded,
    });

    let err = InstructionError::InvalidInstructionData;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(InstructionErrorTestVector {
        name: "invalid_instruction_data".to_string(),
        error_code: 2,
        custom_code: None,
        encoded,
    });

    let err = InstructionError::Custom(42);
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(InstructionErrorTestVector {
        name: "custom_42".to_string(),
        error_code: 7,
        custom_code: Some(42),
        encoded,
    });

    let err = InstructionError::InsufficientFunds;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(InstructionErrorTestVector {
        name: "insufficient_funds".to_string(),
        error_code: 4,
        custom_code: None,
        encoded,
    });

    let err = InstructionError::AccountAlreadyInitialized;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(InstructionErrorTestVector {
        name: "account_already_initialized".to_string(),
        error_code: 8,
        custom_code: None,
        encoded,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("instruction_error_vectors.json"), json).unwrap();
}

pub fn generate_transaction_error_vectors(output_dir: &Path) {
    use solana_sdk::instruction::InstructionError;
    use solana_transaction_error::TransactionError;

    let mut vectors: Vec<TransactionErrorTestVector> = Vec::new();

    // AccountInUse
    let err = TransactionError::AccountInUse;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "account_in_use".to_string(),
        error_type: "AccountInUse".to_string(),
        instruction_index: None,
        encoded,
    });

    // AccountLoadedTwice
    let err = TransactionError::AccountLoadedTwice;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "account_loaded_twice".to_string(),
        error_type: "AccountLoadedTwice".to_string(),
        instruction_index: None,
        encoded,
    });

    // AccountNotFound
    let err = TransactionError::AccountNotFound;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "account_not_found".to_string(),
        error_type: "AccountNotFound".to_string(),
        instruction_index: None,
        encoded,
    });

    // InsufficientFundsForFee
    let err = TransactionError::InsufficientFundsForFee;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "insufficient_funds_for_fee".to_string(),
        error_type: "InsufficientFundsForFee".to_string(),
        instruction_index: None,
        encoded,
    });

    // InvalidAccountForFee
    let err = TransactionError::InvalidAccountForFee;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "invalid_account_for_fee".to_string(),
        error_type: "InvalidAccountForFee".to_string(),
        instruction_index: None,
        encoded,
    });

    // InstructionError with index
    let err = TransactionError::InstructionError(0, InstructionError::GenericError);
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "instruction_error_generic".to_string(),
        error_type: "InstructionError".to_string(),
        instruction_index: Some(0),
        encoded,
    });

    // InstructionError with different index
    let err = TransactionError::InstructionError(5, InstructionError::InvalidArgument);
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "instruction_error_invalid_arg".to_string(),
        error_type: "InstructionError".to_string(),
        instruction_index: Some(5),
        encoded,
    });

    // BlockhashNotFound
    let err = TransactionError::BlockhashNotFound;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "blockhash_not_found".to_string(),
        error_type: "BlockhashNotFound".to_string(),
        instruction_index: None,
        encoded,
    });

    // ProgramAccountNotFound - discriminant 3
    let err = TransactionError::ProgramAccountNotFound;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "program_account_not_found".to_string(),
        error_type: "ProgramAccountNotFound".to_string(),
        instruction_index: None,
        encoded,
    });

    // AlreadyProcessed - discriminant 6
    let err = TransactionError::AlreadyProcessed;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "already_processed".to_string(),
        error_type: "AlreadyProcessed".to_string(),
        instruction_index: None,
        encoded,
    });

    // CallChainTooDeep - discriminant 9
    let err = TransactionError::CallChainTooDeep;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "call_chain_too_deep".to_string(),
        error_type: "CallChainTooDeep".to_string(),
        instruction_index: None,
        encoded,
    });

    // SanitizeFailure - discriminant 12
    let err = TransactionError::SanitizeFailure;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "sanitize_failure".to_string(),
        error_type: "SanitizeFailure".to_string(),
        instruction_index: None,
        encoded,
    });

    // ClusterMaintenance - discriminant 13
    let err = TransactionError::ClusterMaintenance;
    let encoded = bincode::serialize(&err).unwrap();
    vectors.push(TransactionErrorTestVector {
        name: "cluster_maintenance".to_string(),
        error_type: "ClusterMaintenance".to_string(),
        instruction_index: None,
        encoded,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("transaction_error_vectors.json"), json).unwrap();
}

pub fn generate_account_meta_vectors(output_dir: &Path) {
    use solana_sdk::instruction::AccountMeta;

    let mut vectors: Vec<AccountMetaTestVector> = Vec::new();

    let pubkey = Pubkey::from_str_const("4rL4RCWHz3iNCdCaveD8KcHfV9YagGbXgSYq9QWPZ4Zx");

    // Signer + Writable
    let meta = AccountMeta::new(pubkey, true);
    let encoded = bincode::serialize(&meta).unwrap();
    vectors.push(AccountMetaTestVector {
        name: "signer_writable".to_string(),
        pubkey: pubkey.to_bytes(),
        is_signer: true,
        is_writable: true,
        encoded,
    });

    // Signer + ReadOnly
    let meta = AccountMeta::new_readonly(pubkey, true);
    let encoded = bincode::serialize(&meta).unwrap();
    vectors.push(AccountMetaTestVector {
        name: "signer_readonly".to_string(),
        pubkey: pubkey.to_bytes(),
        is_signer: true,
        is_writable: false,
        encoded,
    });

    // Non-Signer + Writable
    let meta = AccountMeta::new(pubkey, false);
    let encoded = bincode::serialize(&meta).unwrap();
    vectors.push(AccountMetaTestVector {
        name: "nonsigner_writable".to_string(),
        pubkey: pubkey.to_bytes(),
        is_signer: false,
        is_writable: true,
        encoded,
    });

    // Non-Signer + ReadOnly
    let meta = AccountMeta::new_readonly(pubkey, false);
    let encoded = bincode::serialize(&meta).unwrap();
    vectors.push(AccountMetaTestVector {
        name: "nonsigner_readonly".to_string(),
        pubkey: pubkey.to_bytes(),
        is_signer: false,
        is_writable: false,
        encoded,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("account_meta_vectors.json"), json).unwrap();
}

pub fn generate_loader_v3_instruction_vectors(output_dir: &Path) {
    use solana_loader_v3_interface::instruction::UpgradeableLoaderInstruction;

    let mut vectors: Vec<LoaderV3InstructionTestVector> = Vec::new();

    let ix = UpgradeableLoaderInstruction::InitializeBuffer;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV3InstructionTestVector {
        name: "initialize_buffer".to_string(),
        instruction_type: "InitializeBuffer".to_string(),
        encoded,
        write_offset: None,
        write_bytes: None,
        max_data_len: None,
        additional_bytes: None,
    });

    let offset = 100u32;
    let data = vec![1, 2, 3, 4, 5, 6, 7, 8];
    let ix = UpgradeableLoaderInstruction::Write {
        offset,
        bytes: data.clone(),
    };
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV3InstructionTestVector {
        name: "write".to_string(),
        instruction_type: "Write".to_string(),
        encoded,
        write_offset: Some(offset),
        write_bytes: Some(data),
        max_data_len: None,
        additional_bytes: None,
    });

    let ix = UpgradeableLoaderInstruction::SetAuthority;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV3InstructionTestVector {
        name: "set_authority".to_string(),
        instruction_type: "SetAuthority".to_string(),
        encoded,
        write_offset: None,
        write_bytes: None,
        max_data_len: None,
        additional_bytes: None,
    });

    let ix = UpgradeableLoaderInstruction::Close;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV3InstructionTestVector {
        name: "close".to_string(),
        instruction_type: "Close".to_string(),
        encoded,
        write_offset: None,
        write_bytes: None,
        max_data_len: None,
        additional_bytes: None,
    });

    let additional_bytes = 1024u32;
    let ix = UpgradeableLoaderInstruction::ExtendProgram { additional_bytes };
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV3InstructionTestVector {
        name: "extend_program".to_string(),
        instruction_type: "ExtendProgram".to_string(),
        encoded,
        write_offset: None,
        write_bytes: None,
        max_data_len: None,
        additional_bytes: Some(additional_bytes),
    });

    let max_data_len = 10000usize;
    let ix = UpgradeableLoaderInstruction::DeployWithMaxDataLen { max_data_len };
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV3InstructionTestVector {
        name: "deploy_with_max_data_len".to_string(),
        instruction_type: "DeployWithMaxDataLen".to_string(),
        encoded,
        write_offset: None,
        write_bytes: None,
        max_data_len: Some(max_data_len as u64),
        additional_bytes: None,
    });

    let ix = UpgradeableLoaderInstruction::Upgrade;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV3InstructionTestVector {
        name: "upgrade".to_string(),
        instruction_type: "Upgrade".to_string(),
        encoded,
        write_offset: None,
        write_bytes: None,
        max_data_len: None,
        additional_bytes: None,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("loader_v3_instruction_vectors.json"), json).unwrap();
}

pub fn generate_blake3_vectors(output_dir: &Path) {
    let mut vectors: Vec<Blake3TestVector> = Vec::new();

    // Empty input
    let hash = blake3::hash(b"");
    vectors.push(Blake3TestVector {
        name: "empty".to_string(),
        input: vec![],
        hash: hash.as_bytes().to_vec(),
    });

    // "hello"
    let hash = blake3::hash(b"hello");
    vectors.push(Blake3TestVector {
        name: "hello".to_string(),
        input: b"hello".to_vec(),
        hash: hash.as_bytes().to_vec(),
    });

    // "hello world"
    let hash = blake3::hash(b"hello world");
    vectors.push(Blake3TestVector {
        name: "hello_world".to_string(),
        input: b"hello world".to_vec(),
        hash: hash.as_bytes().to_vec(),
    });

    // "Solana"
    let hash = blake3::hash(b"Solana");
    vectors.push(Blake3TestVector {
        name: "solana".to_string(),
        input: b"Solana".to_vec(),
        hash: hash.as_bytes().to_vec(),
    });

    // Single byte
    let hash = blake3::hash(&[0x42]);
    vectors.push(Blake3TestVector {
        name: "single_byte".to_string(),
        input: vec![0x42],
        hash: hash.as_bytes().to_vec(),
    });

    // 32 bytes of zeros
    let hash = blake3::hash(&[0u8; 32]);
    vectors.push(Blake3TestVector {
        name: "zeros_32".to_string(),
        input: vec![0u8; 32],
        hash: hash.as_bytes().to_vec(),
    });

    // 32 bytes of 0xff
    let hash = blake3::hash(&[0xffu8; 32]);
    vectors.push(Blake3TestVector {
        name: "ones_32".to_string(),
        input: vec![0xffu8; 32],
        hash: hash.as_bytes().to_vec(),
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("blake3_vectors.json"), json).unwrap();
}

pub fn generate_stake_instruction_vectors(output_dir: &Path) {
    use solana_stake_interface::instruction::StakeInstruction;

    let mut vectors: Vec<StakeInstructionTestVector> = Vec::new();

    let ix = StakeInstruction::Initialize(
        solana_stake_interface::state::Authorized {
            staker: Pubkey::default(),
            withdrawer: Pubkey::default(),
        },
        solana_stake_interface::state::Lockup::default(),
    );
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "initialize".to_string(),
        instruction_type: "Initialize".to_string(),
        encoded,
        lamports: None,
    });

    let ix = StakeInstruction::DelegateStake;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "delegate_stake".to_string(),
        instruction_type: "DelegateStake".to_string(),
        encoded,
        lamports: None,
    });

    let lamports = 1_000_000_000u64;
    let ix = StakeInstruction::Split(lamports);
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "split".to_string(),
        instruction_type: "Split".to_string(),
        encoded,
        lamports: Some(lamports),
    });

    let lamports = 500_000_000u64;
    let ix = StakeInstruction::Withdraw(lamports);
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "withdraw".to_string(),
        instruction_type: "Withdraw".to_string(),
        encoded,
        lamports: Some(lamports),
    });

    let ix = StakeInstruction::Deactivate;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "deactivate".to_string(),
        instruction_type: "Deactivate".to_string(),
        encoded,
        lamports: None,
    });

    let ix = StakeInstruction::Merge;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "merge".to_string(),
        instruction_type: "Merge".to_string(),
        encoded,
        lamports: None,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("stake_instruction_vectors.json"), json).unwrap();
}

pub fn generate_address_lookup_table_instruction_vectors(output_dir: &Path) {
    use solana_address_lookup_table_interface::instruction::ProgramInstruction;

    let mut vectors: Vec<AddressLookupTableInstructionTestVector> = Vec::new();

    let recent_slot = 12345678u64;
    let bump_seed = 255u8;
    let ix = ProgramInstruction::CreateLookupTable {
        recent_slot,
        bump_seed,
    };
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(AddressLookupTableInstructionTestVector {
        name: "create_lookup_table".to_string(),
        instruction_type: "CreateLookupTable".to_string(),
        encoded,
        recent_slot: Some(recent_slot),
        bump_seed: Some(bump_seed),
    });

    let ix = ProgramInstruction::FreezeLookupTable;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(AddressLookupTableInstructionTestVector {
        name: "freeze_lookup_table".to_string(),
        instruction_type: "FreezeLookupTable".to_string(),
        encoded,
        recent_slot: None,
        bump_seed: None,
    });

    let ix = ProgramInstruction::ExtendLookupTable {
        new_addresses: vec![],
    };
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(AddressLookupTableInstructionTestVector {
        name: "extend_lookup_table_empty".to_string(),
        instruction_type: "ExtendLookupTable".to_string(),
        encoded,
        recent_slot: None,
        bump_seed: None,
    });

    let ix = ProgramInstruction::DeactivateLookupTable;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(AddressLookupTableInstructionTestVector {
        name: "deactivate_lookup_table".to_string(),
        instruction_type: "DeactivateLookupTable".to_string(),
        encoded,
        recent_slot: None,
        bump_seed: None,
    });

    let ix = ProgramInstruction::CloseLookupTable;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(AddressLookupTableInstructionTestVector {
        name: "close_lookup_table".to_string(),
        instruction_type: "CloseLookupTable".to_string(),
        encoded,
        recent_slot: None,
        bump_seed: None,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(
        output_dir.join("address_lookup_table_instruction_vectors.json"),
        json,
    )
    .unwrap();
}

pub fn generate_loader_v4_instruction_vectors(output_dir: &Path) {
    use solana_loader_v4_interface::instruction::LoaderV4Instruction;

    let mut vectors: Vec<LoaderV4InstructionTestVector> = Vec::new();

    let ix = LoaderV4Instruction::Write {
        offset: 0,
        bytes: vec![1, 2, 3, 4],
    };
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV4InstructionTestVector {
        name: "write".to_string(),
        instruction_type: "Write".to_string(),
        encoded,
        offset: Some(0),
        bytes_len: Some(4),
    });

    let ix = LoaderV4Instruction::Write {
        offset: 100,
        bytes: vec![0xAB; 8],
    };
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV4InstructionTestVector {
        name: "write_with_offset".to_string(),
        instruction_type: "Write".to_string(),
        encoded,
        offset: Some(100),
        bytes_len: Some(8),
    });

    let ix = LoaderV4Instruction::SetProgramLength { new_size: 1024 };
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV4InstructionTestVector {
        name: "set_program_length".to_string(),
        instruction_type: "SetProgramLength".to_string(),
        encoded,
        offset: None,
        bytes_len: None,
    });

    let ix = LoaderV4Instruction::Deploy;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV4InstructionTestVector {
        name: "deploy".to_string(),
        instruction_type: "Deploy".to_string(),
        encoded,
        offset: None,
        bytes_len: None,
    });

    let ix = LoaderV4Instruction::Retract;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV4InstructionTestVector {
        name: "retract".to_string(),
        instruction_type: "Retract".to_string(),
        encoded,
        offset: None,
        bytes_len: None,
    });

    let ix = LoaderV4Instruction::TransferAuthority;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(LoaderV4InstructionTestVector {
        name: "transfer_authority".to_string(),
        instruction_type: "TransferAuthority".to_string(),
        encoded,
        offset: None,
        bytes_len: None,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("loader_v4_instruction_vectors.json"), json).unwrap();
}

pub fn generate_vote_instruction_vectors(output_dir: &Path) {
    use solana_vote_interface::instruction::VoteInstruction;
    use solana_vote_interface::state::VoteAuthorize;

    let mut vectors: Vec<VoteInstructionTestVector> = Vec::new();

    let ix = VoteInstruction::Authorize(Pubkey::new_unique(), VoteAuthorize::Voter);
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(VoteInstructionTestVector {
        name: "authorize_voter".to_string(),
        instruction_type: "Authorize".to_string(),
        encoded,
        vote_authorize: Some(0),
        commission: None,
        lamports: None,
    });

    let ix = VoteInstruction::Authorize(Pubkey::new_unique(), VoteAuthorize::Withdrawer);
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(VoteInstructionTestVector {
        name: "authorize_withdrawer".to_string(),
        instruction_type: "Authorize".to_string(),
        encoded,
        vote_authorize: Some(1),
        commission: None,
        lamports: None,
    });

    let ix = VoteInstruction::Withdraw(1_000_000_000);
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(VoteInstructionTestVector {
        name: "withdraw".to_string(),
        instruction_type: "Withdraw".to_string(),
        encoded,
        vote_authorize: None,
        commission: None,
        lamports: Some(1_000_000_000),
    });

    let ix = VoteInstruction::UpdateCommission(50);
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(VoteInstructionTestVector {
        name: "update_commission".to_string(),
        instruction_type: "UpdateCommission".to_string(),
        encoded,
        vote_authorize: None,
        commission: Some(50),
        lamports: None,
    });

    let ix = VoteInstruction::UpdateValidatorIdentity;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(VoteInstructionTestVector {
        name: "update_validator_identity".to_string(),
        instruction_type: "UpdateValidatorIdentity".to_string(),
        encoded,
        vote_authorize: None,
        commission: None,
        lamports: None,
    });

    let ix = VoteInstruction::AuthorizeChecked(VoteAuthorize::Voter);
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(VoteInstructionTestVector {
        name: "authorize_checked_voter".to_string(),
        instruction_type: "AuthorizeChecked".to_string(),
        encoded,
        vote_authorize: Some(0),
        commission: None,
        lamports: None,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("vote_instruction_vectors.json"), json).unwrap();
}

pub fn generate_message_vectors(output_dir: &Path) {
    use solana_message::compiled_instruction::CompiledInstruction;
    use solana_message::legacy::Message;

    let mut vectors: Vec<MessageTestVector> = Vec::new();

    let account1 = Pubkey::from_str_const("4rL4RCWHz3iNCdCaveD8KcHfV9YagGbXgSYq9QWPZ4Zx");
    let account2 = Pubkey::from_str_const("8opHzTAnfzRpPEx21XtnrVTX28YQuCpAjcn1PczScKh");
    let program_id = SYSTEM_PROGRAM_ID;
    let recent_blockhash = Hash::new_unique();

    let message = Message::new_with_compiled_instructions(
        1,
        0,
        1,
        vec![account1, account2, program_id],
        recent_blockhash,
        vec![CompiledInstruction::new(
            2,
            &[2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            vec![0, 1],
        )],
    );
    let serialized = bincode::serialize(&message).unwrap();
    vectors.push(MessageTestVector {
        name: "simple_transfer".to_string(),
        num_required_signatures: 1,
        num_readonly_signed_accounts: 0,
        num_readonly_unsigned_accounts: 1,
        account_keys: vec![
            account1.to_bytes(),
            account2.to_bytes(),
            program_id.to_bytes(),
        ],
        recent_blockhash: recent_blockhash.to_bytes(),
        instructions_count: 1,
        serialized,
    });

    let message_empty =
        Message::new_with_compiled_instructions(0, 0, 0, vec![], Hash::default(), vec![]);
    let serialized = bincode::serialize(&message_empty).unwrap();
    vectors.push(MessageTestVector {
        name: "empty_message".to_string(),
        num_required_signatures: 0,
        num_readonly_signed_accounts: 0,
        num_readonly_unsigned_accounts: 0,
        account_keys: vec![],
        recent_blockhash: Hash::default().to_bytes(),
        instructions_count: 0,
        serialized,
    });

    let account3 = Pubkey::from_str_const("BPFLoaderUpgradeab1e11111111111111111111111");
    let message_multi = Message::new_with_compiled_instructions(
        2,
        1,
        1,
        vec![account1, account2, account3, program_id],
        recent_blockhash,
        vec![
            CompiledInstruction::new(3, &[2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], vec![0, 1]),
            CompiledInstruction::new(3, &[1, 0, 0, 0], vec![1, 2]),
        ],
    );
    let serialized = bincode::serialize(&message_multi).unwrap();
    vectors.push(MessageTestVector {
        name: "multi_instruction".to_string(),
        num_required_signatures: 2,
        num_readonly_signed_accounts: 1,
        num_readonly_unsigned_accounts: 1,
        account_keys: vec![
            account1.to_bytes(),
            account2.to_bytes(),
            account3.to_bytes(),
            program_id.to_bytes(),
        ],
        recent_blockhash: recent_blockhash.to_bytes(),
        instructions_count: 2,
        serialized,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("message_vectors.json"), json).unwrap();
}

pub fn generate_all_vectors(output_dir: &Path) {
    fs::create_dir_all(output_dir).unwrap();

    generate_pubkey_vectors(output_dir);
    generate_hash_vectors(output_dir);
    generate_signature_vectors(output_dir);
    generate_pda_vectors(output_dir);
    generate_keypair_vectors(output_dir);
    generate_epoch_info_vectors(output_dir);
    generate_short_vec_vectors(output_dir);
    generate_sha256_vectors(output_dir);
    generate_lamports_vectors(output_dir);
    generate_rent_vectors(output_dir);
    generate_clock_vectors(output_dir);
    generate_epoch_schedule_vectors(output_dir);
    generate_durable_nonce_vectors(output_dir);
    generate_bincode_vectors(output_dir);
    generate_borsh_vectors(output_dir);
    generate_system_instruction_vectors(output_dir);
    generate_keccak256_vectors(output_dir);
    generate_compute_budget_vectors(output_dir);
    generate_ed25519_verify_vectors(output_dir);
    generate_message_header_vectors(output_dir);
    generate_compiled_instruction_vectors(output_dir);
    generate_feature_state_vectors(output_dir);
    generate_nonce_versions_vectors(output_dir);
    generate_instruction_error_vectors(output_dir);
    generate_transaction_error_vectors(output_dir);
    generate_account_meta_vectors(output_dir);
    generate_loader_v3_instruction_vectors(output_dir);
    generate_blake3_vectors(output_dir);
    generate_stake_instruction_vectors(output_dir);
    generate_address_lookup_table_instruction_vectors(output_dir);
    generate_loader_v4_instruction_vectors(output_dir);
    generate_vote_instruction_vectors(output_dir);
    generate_message_vectors(output_dir);

    println!("Generated all test vectors in {:?}", output_dir);
}
