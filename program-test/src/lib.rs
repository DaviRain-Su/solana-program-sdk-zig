use serde::{Deserialize, Serialize};
use solana_sdk::{
    hash::Hash,
    pubkey::Pubkey,
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

pub fn generate_all_vectors(output_dir: &Path) {
    fs::create_dir_all(output_dir).unwrap();

    generate_pubkey_vectors(output_dir);
    generate_hash_vectors(output_dir);
    generate_signature_vectors(output_dir);
    generate_pda_vectors(output_dir);
    generate_keypair_vectors(output_dir);
    generate_epoch_info_vectors(output_dir);

    println!("Generated all test vectors in {:?}", output_dir);
}
