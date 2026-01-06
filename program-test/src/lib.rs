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

    println!("Generated all test vectors in {:?}", output_dir);
}
