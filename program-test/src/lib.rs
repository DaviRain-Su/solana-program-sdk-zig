use serde::{Deserialize, Serialize};
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

    println!("Generated all test vectors in {:?}", output_dir);
}
