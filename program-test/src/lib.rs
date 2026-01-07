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
pub struct Secp256k1InstructionTestVector {
    pub name: String,
    pub num_signatures: u8,
    pub signature_offset: u16,
    pub signature_instruction_index: u8,
    pub eth_address_offset: u16,
    pub eth_address_instruction_index: u8,
    pub message_data_offset: u16,
    pub message_data_size: u16,
    pub message_instruction_index: u8,
    pub serialized_offsets: Vec<u8>,
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

#[derive(Serialize, Deserialize, Debug)]
pub struct TransactionTestVector {
    pub name: String,
    pub num_signatures: u8,
    pub message_header: [u8; 3],
    pub account_keys_count: u8,
    pub recent_blockhash: [u8; 32],
    pub serialized: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SysvarIdTestVector {
    pub name: String,
    pub pubkey: [u8; 32],
    pub base58: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SlotHashTestVector {
    pub name: String,
    pub slot: u64,
    pub hash: [u8; 32],
    pub serialized: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct EpochRewardsTestVector {
    pub name: String,
    pub distribution_starting_block_height: u64,
    pub num_partitions: u64,
    pub parent_blockhash: [u8; 32],
    pub total_points: u128,
    pub total_rewards: u64,
    pub distributed_rewards: u64,
    pub active: bool,
    pub serialized: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct LastRestartSlotTestVector {
    pub name: String,
    pub last_restart_slot: u64,
    pub serialized: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Secp256r1InstructionTestVector {
    pub name: String,
    pub num_signatures: u8,
    pub signature_offset: u16,
    pub signature_instruction_index: u8,
    pub public_key_offset: u16,
    pub public_key_instruction_index: u8,
    pub message_data_offset: u16,
    pub message_data_size: u16,
    pub message_instruction_index: u8,
    pub serialized_offsets: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct FeatureGateInstructionTestVector {
    pub name: String,
    pub feature_id: [u8; 32],
    pub lamports: u64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ProgramDataTestVector {
    pub name: String,
    pub slot: u64,
    pub upgrade_authority: Option<[u8; 32]>,
    pub serialized_header: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Ed25519InstructionTestVector {
    pub name: String,
    pub num_signatures: u8,
    pub signature_offset: u16,
    pub signature_instruction_index: u16,
    pub public_key_offset: u16,
    pub public_key_instruction_index: u16,
    pub message_data_offset: u16,
    pub message_data_size: u16,
    pub message_instruction_index: u16,
    pub serialized_offsets: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SystemInstructionExtendedTestVector {
    pub name: String,
    pub instruction_type: String,
    pub encoded: Vec<u8>,
    pub base: Option<[u8; 32]>,
    pub seed: Option<String>,
    pub lamports: Option<u64>,
    pub space: Option<u64>,
    pub owner: Option<[u8; 32]>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AddressLookupTableStateTestVector {
    pub name: String,
    pub deactivation_slot: u64,
    pub last_extended_slot: u64,
    pub last_extended_slot_start_index: u8,
    pub authority: Option<[u8; 32]>,
    pub addresses: Vec<[u8; 32]>,
    pub serialized: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct VersionedMessageTestVector {
    pub name: String,
    pub version: u8,
    pub num_required_signatures: u8,
    pub num_readonly_signed: u8,
    pub num_readonly_unsigned: u8,
    pub static_account_keys_count: u8,
    pub address_table_lookups_count: u8,
    pub serialized_prefix: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct UpgradeableLoaderStateTestVector {
    pub name: String,
    pub state_type: String,
    pub discriminant: u32,
    pub authority: Option<[u8; 32]>,
    pub programdata_address: Option<[u8; 32]>,
    pub slot: Option<u64>,
    pub serialized: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Bn254ConstantsTestVector {
    pub name: String,
    pub field_size: usize,
    pub g1_point_size: usize,
    pub g2_point_size: usize,
    pub g1_add_input_size: usize,
    pub g1_mul_input_size: usize,
    pub pairing_element_size: usize,
    pub pairing_output_size: usize,
    pub g1_add_be_op: u64,
    pub g1_sub_be_op: u64,
    pub g1_mul_be_op: u64,
    pub pairing_be_op: u64,
    pub le_flag: u64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SlotHistoryConstantsTestVector {
    pub name: String,
    pub max_entries: u64,
    pub bitvec_words: usize,
    pub sysvar_id: [u8; 32],
    pub sysvar_id_base58: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct BigModExpTestVector {
    pub name: String,
    pub base: Vec<u8>,
    pub exponent: Vec<u8>,
    pub modulus: Vec<u8>,
    pub expected_result: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AuthorizeTestVector {
    pub name: String,
    pub staker: [u8; 32],
    pub withdrawer: [u8; 32],
    pub serialized: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AccountLayoutTestVector {
    pub name: String,
    pub data_header_size: usize,
    pub account_data_padding: usize,
    pub duplicate_index_offset: usize,
    pub is_signer_offset: usize,
    pub is_writable_offset: usize,
    pub is_executable_offset: usize,
    pub original_data_len_offset: usize,
    pub id_offset: usize,
    pub owner_id_offset: usize,
    pub lamports_offset: usize,
    pub data_len_offset: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PrimitiveTypeSizesTestVector {
    pub name: String,
    pub u8_size: usize,
    pub u16_size: usize,
    pub u32_size: usize,
    pub u64_size: usize,
    pub u128_size: usize,
    pub i8_size: usize,
    pub i16_size: usize,
    pub i32_size: usize,
    pub i64_size: usize,
    pub i128_size: usize,
    pub pubkey_size: usize,
    pub hash_size: usize,
    pub signature_size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct LockupTestVector {
    pub name: String,
    pub unix_timestamp: i64,
    pub epoch: u64,
    pub custodian: [u8; 32],
    pub serialized: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct RentExemptTestVector {
    pub name: String,
    pub data_len: usize,
    pub lamports_per_byte_year: u64,
    pub exemption_threshold: f64,
    pub account_storage_overhead: u64,
    pub minimum_balance: u64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct BlsConstantsTestVector {
    pub name: String,
    pub pubkey_compressed_size: usize,
    pub pubkey_affine_size: usize,
    pub signature_compressed_size: usize,
    pub signature_affine_size: usize,
    pub pop_compressed_size: usize,
    pub pop_affine_size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SignerSeedsTestVector {
    pub name: String,
    pub program_id: [u8; 32],
    pub seeds: Vec<Vec<u8>>,
    pub expected_pubkey: [u8; 32],
    pub expected_bump: u8,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct VoteInitTestVector {
    pub name: String,
    pub node_pubkey: [u8; 32],
    pub authorized_voter: [u8; 32],
    pub authorized_withdrawer: [u8; 32],
    pub commission: u8,
    pub serialized: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct VoteStateConstantsTestVector {
    pub name: String,
    pub max_lockout_history: usize,
    pub initial_lockout: usize,
    pub max_epoch_credits_history: usize,
    pub vote_credits_grace_slots: u8,
    pub vote_credits_maximum_per_slot: u8,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct LookupTableMetaTestVector {
    pub name: String,
    pub deactivation_slot: u64,
    pub last_extended_slot: u64,
    pub last_extended_slot_start_index: u8,
    pub authority_option: u8,
    pub authority: Option<[u8; 32]>,
    pub serialized: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ComputeBudgetConstantsTestVector {
    pub name: String,
    pub max_compute_unit_limit: u32,
    pub default_instruction_compute_unit_limit: u32,
    pub max_heap_frame_bytes: u32,
    pub min_heap_frame_bytes: u32,
    pub max_loaded_accounts_data_size_bytes: u32,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct NonceConstantsTestVector {
    pub name: String,
    pub nonce_account_length: usize,
    pub nonced_tx_marker_ix_index: u8,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AltConstantsTestVector {
    pub name: String,
    pub max_addresses: usize,
    pub meta_size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct BpfLoaderStateSizesTestVector {
    pub name: String,
    pub uninitialized_size: usize,
    pub buffer_size: usize,
    pub program_size: usize,
    pub programdata_size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Ed25519ConstantsTestVector {
    pub name: String,
    pub pubkey_size: usize,
    pub signature_size: usize,
    pub offsets_size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct EpochScheduleConstantsTestVector {
    pub name: String,
    pub default_slots_per_epoch: u64,
    pub default_leader_schedule_slot_offset: u64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AccountLimitsTestVector {
    pub name: String,
    pub max_permitted_data_increase: usize,
    pub max_accounts: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SysvarSizesTestVector {
    pub name: String,
    pub clock_size: usize,
    pub rent_size: usize,
    pub epoch_schedule_size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct NativeTokenConstantsTestVector {
    pub name: String,
    pub lamports_per_sol: u64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Secp256k1ConstantsTestVector {
    pub name: String,
    pub pubkey_size: usize,
    pub private_key_size: usize,
    pub hashed_pubkey_size: usize,
    pub signature_size: usize,
    pub offsets_size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SignatureSizesTestVector {
    pub name: String,
    pub ed25519_signature_size: usize,
    pub ed25519_pubkey_size: usize,
    pub secp256k1_signature_size: usize,
    pub secp256r1_signature_size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct HashSizesTestVector {
    pub name: String,
    pub sha256_size: usize,
    pub keccak256_size: usize,
    pub blake3_size: usize,
    pub solana_hash_size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SpecialAddressesTestVector {
    pub name: String,
    pub incinerator: [u8; 32],
    pub incinerator_base58: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PubkeySizesTestVector {
    pub name: String,
    pub pubkey_size: usize,
    pub max_seed_len: usize,
    pub max_seeds: usize,
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

    let ix = StakeInstruction::SetLockup(solana_stake_interface::instruction::LockupArgs {
        unix_timestamp: Some(1700000000),
        epoch: Some(500),
        custodian: Some(Pubkey::from_str_const(
            "Vote111111111111111111111111111111111111111",
        )),
    });
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "set_lockup".to_string(),
        instruction_type: "SetLockup".to_string(),
        encoded,
        lamports: None,
    });

    let ix = StakeInstruction::GetMinimumDelegation;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "get_minimum_delegation".to_string(),
        instruction_type: "GetMinimumDelegation".to_string(),
        encoded,
        lamports: None,
    });

    let ix = StakeInstruction::DeactivateDelinquent;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "deactivate_delinquent".to_string(),
        instruction_type: "DeactivateDelinquent".to_string(),
        encoded,
        lamports: None,
    });

    #[allow(deprecated)]
    let ix = StakeInstruction::Redelegate;
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "redelegate".to_string(),
        instruction_type: "Redelegate".to_string(),
        encoded,
        lamports: None,
    });

    let lamports = 3_000_000_000u64;
    let ix = StakeInstruction::MoveStake(lamports);
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "move_stake".to_string(),
        instruction_type: "MoveStake".to_string(),
        encoded,
        lamports: Some(lamports),
    });

    let lamports = 1_500_000_000u64;
    let ix = StakeInstruction::MoveLamports(lamports);
    let encoded = bincode::serialize(&ix).unwrap();
    vectors.push(StakeInstructionTestVector {
        name: "move_lamports".to_string(),
        instruction_type: "MoveLamports".to_string(),
        encoded,
        lamports: Some(lamports),
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

pub fn generate_transaction_vectors(output_dir: &Path) {
    use solana_message::compiled_instruction::CompiledInstruction;
    use solana_message::legacy::Message;
    use solana_sdk::transaction::Transaction;

    let mut vectors: Vec<TransactionTestVector> = Vec::new();

    let payer = Keypair::new();
    let recipient = Pubkey::new_unique();
    let recent_blockhash = Hash::new_unique();

    let message = Message::new_with_compiled_instructions(
        1,
        0,
        1,
        vec![payer.pubkey(), recipient, SYSTEM_PROGRAM_ID],
        recent_blockhash,
        vec![CompiledInstruction::new(
            2,
            &[2, 0, 0, 0, 0, 202, 154, 59, 0, 0, 0, 0],
            vec![0, 1],
        )],
    );

    let mut tx = Transaction::new_unsigned(message);
    tx.sign(&[&payer], recent_blockhash);
    let serialized = bincode::serialize(&tx).unwrap();

    vectors.push(TransactionTestVector {
        name: "signed_transfer".to_string(),
        num_signatures: 1,
        message_header: [1, 0, 1],
        account_keys_count: 3,
        recent_blockhash: recent_blockhash.to_bytes(),
        serialized,
    });

    let message_empty =
        Message::new_with_compiled_instructions(0, 0, 0, vec![], Hash::default(), vec![]);
    let tx_empty = Transaction::new_unsigned(message_empty);
    let serialized = bincode::serialize(&tx_empty).unwrap();

    vectors.push(TransactionTestVector {
        name: "empty_unsigned".to_string(),
        num_signatures: 0,
        message_header: [0, 0, 0],
        account_keys_count: 0,
        recent_blockhash: Hash::default().to_bytes(),
        serialized,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("transaction_vectors.json"), json).unwrap();
}

pub fn generate_secp256k1_instruction_vectors(output_dir: &Path) {
    let mut vectors: Vec<Secp256k1InstructionTestVector> = Vec::new();

    let offsets_data: &[(&str, u8, u16, u8, u16, u8, u16, u16, u8)] = &[
        ("basic_offsets", 1, 12, 0, 76, 0, 141, 32, 0),
        ("multiple_sigs", 2, 24, 0, 88, 0, 153, 64, 0),
        ("different_instruction", 1, 12, 1, 76, 1, 141, 32, 1),
        ("zero_offsets", 1, 0, 0, 0, 0, 0, 0, 0),
        ("max_message_size", 1, 12, 0, 76, 0, 141, 1232, 0),
        ("alt_instruction_indices", 1, 12, 2, 76, 3, 141, 32, 4),
    ];

    for (
        name,
        num_sigs,
        sig_offset,
        sig_instr_idx,
        eth_addr_offset,
        eth_addr_instr_idx,
        msg_data_offset,
        msg_data_size,
        msg_instr_idx,
    ) in offsets_data
    {
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&sig_offset.to_le_bytes());
        serialized.push(*sig_instr_idx);
        serialized.extend_from_slice(&eth_addr_offset.to_le_bytes());
        serialized.push(*eth_addr_instr_idx);
        serialized.extend_from_slice(&msg_data_offset.to_le_bytes());
        serialized.extend_from_slice(&msg_data_size.to_le_bytes());
        serialized.push(*msg_instr_idx);

        vectors.push(Secp256k1InstructionTestVector {
            name: name.to_string(),
            num_signatures: *num_sigs,
            signature_offset: *sig_offset,
            signature_instruction_index: *sig_instr_idx,
            eth_address_offset: *eth_addr_offset,
            eth_address_instruction_index: *eth_addr_instr_idx,
            message_data_offset: *msg_data_offset,
            message_data_size: *msg_data_size,
            message_instruction_index: *msg_instr_idx,
            serialized_offsets: serialized,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("secp256k1_instruction_vectors.json"), json).unwrap();
}

pub fn generate_native_program_id_vectors(output_dir: &Path) {
    use solana_sdk::bpf_loader;
    use solana_sdk::bpf_loader_deprecated;

    let system_program_id = Pubkey::from_str_const("11111111111111111111111111111111");
    let bpf_loader_upgradeable_id =
        Pubkey::from_str_const("BPFLoaderUpgradeab1e11111111111111111111111");
    let vote_program_id = Pubkey::from_str_const("Vote111111111111111111111111111111111111111");
    let stake_program_id = Pubkey::from_str_const("Stake11111111111111111111111111111111111111");
    let config_program_id = Pubkey::from_str_const("Config1111111111111111111111111111111111111");
    let ed25519_program_id = Pubkey::from_str_const("Ed25519SigVerify111111111111111111111111111");
    let secp256k1_program_id =
        Pubkey::from_str_const("KeccakSecp256k11111111111111111111111111111");
    let compute_budget_program_id =
        Pubkey::from_str_const("ComputeBudget111111111111111111111111111111");
    let address_lookup_table_program_id =
        Pubkey::from_str_const("AddressLookupTab1e1111111111111111111111111");
    let loader_v4_program_id =
        Pubkey::from_str_const("LoaderV411111111111111111111111111111111111");
    let secp256r1_program_id =
        Pubkey::from_str_const("Secp256r11111111111111111111111111111111111");
    let feature_program_id = Pubkey::from_str_const("Feature111111111111111111111111111111111111");

    let vectors = vec![
        SysvarIdTestVector {
            name: "system_program".to_string(),
            pubkey: system_program_id.to_bytes(),
            base58: system_program_id.to_string(),
        },
        SysvarIdTestVector {
            name: "bpf_loader_deprecated".to_string(),
            pubkey: bpf_loader_deprecated::ID.to_bytes(),
            base58: bpf_loader_deprecated::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "bpf_loader".to_string(),
            pubkey: bpf_loader::ID.to_bytes(),
            base58: bpf_loader::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "bpf_loader_upgradeable".to_string(),
            pubkey: bpf_loader_upgradeable_id.to_bytes(),
            base58: bpf_loader_upgradeable_id.to_string(),
        },
        SysvarIdTestVector {
            name: "vote_program".to_string(),
            pubkey: vote_program_id.to_bytes(),
            base58: vote_program_id.to_string(),
        },
        SysvarIdTestVector {
            name: "stake_program".to_string(),
            pubkey: stake_program_id.to_bytes(),
            base58: stake_program_id.to_string(),
        },
        SysvarIdTestVector {
            name: "config_program".to_string(),
            pubkey: config_program_id.to_bytes(),
            base58: config_program_id.to_string(),
        },
        SysvarIdTestVector {
            name: "ed25519_program".to_string(),
            pubkey: ed25519_program_id.to_bytes(),
            base58: ed25519_program_id.to_string(),
        },
        SysvarIdTestVector {
            name: "secp256k1_program".to_string(),
            pubkey: secp256k1_program_id.to_bytes(),
            base58: secp256k1_program_id.to_string(),
        },
        SysvarIdTestVector {
            name: "compute_budget_program".to_string(),
            pubkey: compute_budget_program_id.to_bytes(),
            base58: compute_budget_program_id.to_string(),
        },
        SysvarIdTestVector {
            name: "address_lookup_table_program".to_string(),
            pubkey: address_lookup_table_program_id.to_bytes(),
            base58: address_lookup_table_program_id.to_string(),
        },
        SysvarIdTestVector {
            name: "loader_v4_program".to_string(),
            pubkey: loader_v4_program_id.to_bytes(),
            base58: loader_v4_program_id.to_string(),
        },
        SysvarIdTestVector {
            name: "secp256r1_program".to_string(),
            pubkey: secp256r1_program_id.to_bytes(),
            base58: secp256r1_program_id.to_string(),
        },
        SysvarIdTestVector {
            name: "feature_program".to_string(),
            pubkey: feature_program_id.to_bytes(),
            base58: feature_program_id.to_string(),
        },
    ];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("native_program_id_vectors.json"), json).unwrap();
}

pub fn generate_slot_hash_vectors(output_dir: &Path) {
    let test_cases: &[(&str, u64, [u8; 32])] = &[
        ("genesis_slot", 0, [0u8; 32]),
        ("slot_100", 100, {
            let mut h = [0u8; 32];
            h[0] = 100;
            h
        }),
        ("slot_1000", 1000, {
            let mut h = [0u8; 32];
            h[0] = 0xe8;
            h[1] = 0x03;
            h
        }),
        ("max_slot", u64::MAX, [0xff; 32]),
    ];

    let mut vectors: Vec<SlotHashTestVector> = Vec::new();

    for (name, slot, hash_bytes) in test_cases {
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&slot.to_le_bytes());
        serialized.extend_from_slice(hash_bytes);

        vectors.push(SlotHashTestVector {
            name: name.to_string(),
            slot: *slot,
            hash: *hash_bytes,
            serialized,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("slot_hash_vectors.json"), json).unwrap();
}

pub fn generate_epoch_rewards_vectors(output_dir: &Path) {
    let test_cases: &[(&str, u64, u64, [u8; 32], u128, u64, u64, bool)] = &[
        (
            "initial_rewards",
            1000,
            4,
            [1u8; 32],
            1_000_000_000_000,
            500_000_000,
            0,
            true,
        ),
        (
            "partial_distribution",
            2000,
            8,
            [2u8; 32],
            2_000_000_000_000,
            1_000_000_000,
            500_000_000,
            true,
        ),
        (
            "completed_distribution",
            3000,
            16,
            [3u8; 32],
            3_000_000_000_000,
            1_500_000_000,
            1_500_000_000,
            false,
        ),
        ("zero_rewards", 0, 1, [0u8; 32], 0, 0, 0, false),
    ];

    let mut vectors: Vec<EpochRewardsTestVector> = Vec::new();

    for (
        name,
        distribution_starting_block_height,
        num_partitions,
        parent_blockhash,
        total_points,
        total_rewards,
        distributed_rewards,
        active,
    ) in test_cases
    {
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&distribution_starting_block_height.to_le_bytes());
        serialized.extend_from_slice(&num_partitions.to_le_bytes());
        serialized.extend_from_slice(parent_blockhash);
        serialized.extend_from_slice(&total_points.to_le_bytes());
        serialized.extend_from_slice(&total_rewards.to_le_bytes());
        serialized.extend_from_slice(&distributed_rewards.to_le_bytes());
        serialized.push(if *active { 1 } else { 0 });

        vectors.push(EpochRewardsTestVector {
            name: name.to_string(),
            distribution_starting_block_height: *distribution_starting_block_height,
            num_partitions: *num_partitions,
            parent_blockhash: *parent_blockhash,
            total_points: *total_points,
            total_rewards: *total_rewards,
            distributed_rewards: *distributed_rewards,
            active: *active,
            serialized,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("epoch_rewards_vectors.json"), json).unwrap();
}

pub fn generate_last_restart_slot_vectors(output_dir: &Path) {
    let test_cases: &[(&str, u64)] = &[
        ("zero_slot", 0),
        ("recent_slot", 123456789),
        ("large_slot", 1_000_000_000),
        ("max_slot", u64::MAX),
    ];

    let mut vectors: Vec<LastRestartSlotTestVector> = Vec::new();

    for (name, slot) in test_cases {
        let serialized = slot.to_le_bytes().to_vec();

        vectors.push(LastRestartSlotTestVector {
            name: name.to_string(),
            last_restart_slot: *slot,
            serialized,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("last_restart_slot_vectors.json"), json).unwrap();
}

pub fn generate_secp256r1_instruction_vectors(output_dir: &Path) {
    let offsets_data: &[(&str, u8, u16, u8, u16, u8, u16, u16, u8)] = &[
        ("basic_offsets", 1, 14, 0, 78, 0, 143, 32, 0),
        ("multiple_sigs", 2, 28, 0, 92, 0, 157, 64, 0),
        ("different_instruction", 1, 14, 1, 78, 1, 143, 32, 1),
        ("zero_offsets", 1, 0, 0, 0, 0, 0, 0, 0),
        ("max_message_size", 1, 14, 0, 78, 0, 143, 1232, 0),
    ];

    let mut vectors: Vec<Secp256r1InstructionTestVector> = Vec::new();

    for (
        name,
        num_sigs,
        sig_offset,
        sig_instr_idx,
        pk_offset,
        pk_instr_idx,
        msg_data_offset,
        msg_data_size,
        msg_instr_idx,
    ) in offsets_data
    {
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&sig_offset.to_le_bytes());
        serialized.push(*sig_instr_idx);
        serialized.extend_from_slice(&pk_offset.to_le_bytes());
        serialized.push(*pk_instr_idx);
        serialized.extend_from_slice(&msg_data_offset.to_le_bytes());
        serialized.extend_from_slice(&msg_data_size.to_le_bytes());
        serialized.push(*msg_instr_idx);

        vectors.push(Secp256r1InstructionTestVector {
            name: name.to_string(),
            num_signatures: *num_sigs,
            signature_offset: *sig_offset,
            signature_instruction_index: *sig_instr_idx,
            public_key_offset: *pk_offset,
            public_key_instruction_index: *pk_instr_idx,
            message_data_offset: *msg_data_offset,
            message_data_size: *msg_data_size,
            message_instruction_index: *msg_instr_idx,
            serialized_offsets: serialized,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("secp256r1_instruction_vectors.json"), json).unwrap();
}

pub fn generate_feature_gate_instruction_vectors(output_dir: &Path) {
    let feature_id = Pubkey::from_str_const("Feature111111111111111111111111111111111111");

    let test_cases: &[(&str, [u8; 32], u64)] = &[
        ("activate_basic", feature_id.to_bytes(), 1_500_000),
        ("activate_min_rent", [1u8; 32], 890_880),
        ("activate_large_rent", [2u8; 32], 10_000_000),
        ("activate_zero_bytes", [0u8; 32], 0),
    ];

    let mut vectors: Vec<FeatureGateInstructionTestVector> = Vec::new();

    for (name, feature_id, lamports) in test_cases {
        vectors.push(FeatureGateInstructionTestVector {
            name: name.to_string(),
            feature_id: *feature_id,
            lamports: *lamports,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(
        output_dir.join("feature_gate_instruction_vectors.json"),
        json,
    )
    .unwrap();
}

pub fn generate_program_data_vectors(output_dir: &Path) {
    let upgrade_authority = Pubkey::from_str_const("11111111111111111111111111111111");

    let test_cases: &[(&str, u64, Option<[u8; 32]>)] = &[
        (
            "with_authority",
            12345678,
            Some(upgrade_authority.to_bytes()),
        ),
        ("no_authority", 87654321, None),
        ("slot_zero", 0, Some([1u8; 32])),
        ("max_slot", u64::MAX, Some([0xff; 32])),
    ];

    let mut vectors: Vec<ProgramDataTestVector> = Vec::new();

    for (name, slot, authority) in test_cases {
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&3u32.to_le_bytes());
        serialized.extend_from_slice(&slot.to_le_bytes());
        if let Some(auth) = authority {
            serialized.push(1);
            serialized.extend_from_slice(auth);
        } else {
            serialized.push(0);
        }

        vectors.push(ProgramDataTestVector {
            name: name.to_string(),
            slot: *slot,
            upgrade_authority: *authority,
            serialized_header: serialized,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("program_data_vectors.json"), json).unwrap();
}

pub fn generate_ed25519_instruction_vectors(output_dir: &Path) {
    let offsets_data: &[(&str, u8, u16, u16, u16, u16, u16, u16, u16)] = &[
        (
            "single_sig_current_instr",
            1,
            16,
            0xFFFF,
            80,
            0xFFFF,
            112,
            32,
            0xFFFF,
        ),
        ("single_sig_other_instr", 1, 0, 0, 64, 0, 96, 128, 0),
        ("single_sig_mixed_instr", 1, 16, 0xFFFF, 0, 1, 32, 64, 2),
        ("multiple_sigs", 2, 16, 0xFFFF, 80, 0xFFFF, 112, 32, 0xFFFF),
        (
            "zero_message_size",
            1,
            16,
            0xFFFF,
            80,
            0xFFFF,
            112,
            0,
            0xFFFF,
        ),
        (
            "large_message",
            1,
            16,
            0xFFFF,
            80,
            0xFFFF,
            112,
            1232,
            0xFFFF,
        ),
    ];

    let mut vectors: Vec<Ed25519InstructionTestVector> = Vec::new();

    for (
        name,
        num_sigs,
        sig_offset,
        sig_instr_idx,
        pk_offset,
        pk_instr_idx,
        msg_offset,
        msg_size,
        msg_instr_idx,
    ) in offsets_data
    {
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&sig_offset.to_le_bytes());
        serialized.extend_from_slice(&sig_instr_idx.to_le_bytes());
        serialized.extend_from_slice(&pk_offset.to_le_bytes());
        serialized.extend_from_slice(&pk_instr_idx.to_le_bytes());
        serialized.extend_from_slice(&msg_offset.to_le_bytes());
        serialized.extend_from_slice(&msg_size.to_le_bytes());
        serialized.extend_from_slice(&msg_instr_idx.to_le_bytes());

        vectors.push(Ed25519InstructionTestVector {
            name: name.to_string(),
            num_signatures: *num_sigs,
            signature_offset: *sig_offset,
            signature_instruction_index: *sig_instr_idx,
            public_key_offset: *pk_offset,
            public_key_instruction_index: *pk_instr_idx,
            message_data_offset: *msg_offset,
            message_data_size: *msg_size,
            message_instruction_index: *msg_instr_idx,
            serialized_offsets: serialized,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("ed25519_instruction_vectors.json"), json).unwrap();
}

pub fn generate_system_instruction_extended_vectors(output_dir: &Path) {
    use solana_system_interface::instruction::SystemInstruction;

    let base = Pubkey::from_str_const("11111111111111111111111111111111");
    let owner = Pubkey::from_str_const("BPFLoaderUpgradeab1e11111111111111111111111");

    let mut vectors: Vec<SystemInstructionExtendedTestVector> = Vec::new();

    let instr = SystemInstruction::CreateAccountWithSeed {
        base: base,
        seed: "test_seed".to_string(),
        lamports: 1_000_000,
        space: 100,
        owner: owner,
    };
    let encoded = bincode::serialize(&instr).unwrap();
    vectors.push(SystemInstructionExtendedTestVector {
        name: "create_account_with_seed".to_string(),
        instruction_type: "CreateAccountWithSeed".to_string(),
        encoded,
        base: Some(base.to_bytes()),
        seed: Some("test_seed".to_string()),
        lamports: Some(1_000_000),
        space: Some(100),
        owner: Some(owner.to_bytes()),
    });

    let instr = SystemInstruction::AllocateWithSeed {
        base: base,
        seed: "alloc_seed".to_string(),
        space: 200,
        owner: owner,
    };
    let encoded = bincode::serialize(&instr).unwrap();
    vectors.push(SystemInstructionExtendedTestVector {
        name: "allocate_with_seed".to_string(),
        instruction_type: "AllocateWithSeed".to_string(),
        encoded,
        base: Some(base.to_bytes()),
        seed: Some("alloc_seed".to_string()),
        lamports: None,
        space: Some(200),
        owner: Some(owner.to_bytes()),
    });

    let instr = SystemInstruction::AssignWithSeed {
        base: base,
        seed: "assign_seed".to_string(),
        owner: owner,
    };
    let encoded = bincode::serialize(&instr).unwrap();
    vectors.push(SystemInstructionExtendedTestVector {
        name: "assign_with_seed".to_string(),
        instruction_type: "AssignWithSeed".to_string(),
        encoded,
        base: Some(base.to_bytes()),
        seed: Some("assign_seed".to_string()),
        lamports: None,
        space: None,
        owner: Some(owner.to_bytes()),
    });

    let instr = SystemInstruction::TransferWithSeed {
        lamports: 500_000,
        from_seed: "from_seed".to_string(),
        from_owner: owner,
    };
    let encoded = bincode::serialize(&instr).unwrap();
    vectors.push(SystemInstructionExtendedTestVector {
        name: "transfer_with_seed".to_string(),
        instruction_type: "TransferWithSeed".to_string(),
        encoded,
        base: None,
        seed: Some("from_seed".to_string()),
        lamports: Some(500_000),
        space: None,
        owner: Some(owner.to_bytes()),
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(
        output_dir.join("system_instruction_extended_vectors.json"),
        json,
    )
    .unwrap();
}

pub fn generate_address_lookup_table_state_vectors(output_dir: &Path) {
    let authority = Pubkey::from_str_const("11111111111111111111111111111111");
    let addr1 = Pubkey::from_str_const("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    let addr2 = Pubkey::from_str_const("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL");

    let test_cases: &[(&str, u64, u64, u8, Option<[u8; 32]>, Vec<[u8; 32]>)] = &[
        (
            "active_with_authority",
            u64::MAX,
            1000,
            0,
            Some(authority.to_bytes()),
            vec![addr1.to_bytes(), addr2.to_bytes()],
        ),
        (
            "deactivating",
            500,
            1000,
            2,
            Some(authority.to_bytes()),
            vec![addr1.to_bytes()],
        ),
        (
            "frozen_no_authority",
            u64::MAX,
            2000,
            0,
            None,
            vec![addr1.to_bytes(), addr2.to_bytes()],
        ),
        (
            "empty_table",
            u64::MAX,
            0,
            0,
            Some(authority.to_bytes()),
            vec![],
        ),
    ];

    let mut vectors: Vec<AddressLookupTableStateTestVector> = Vec::new();

    for (
        name,
        deactivation_slot,
        last_extended_slot,
        last_extended_slot_start_index,
        auth,
        addresses,
    ) in test_cases
    {
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&1u32.to_le_bytes());
        serialized.extend_from_slice(&deactivation_slot.to_le_bytes());
        serialized.extend_from_slice(&last_extended_slot.to_le_bytes());
        serialized.push(*last_extended_slot_start_index);
        if let Some(a) = auth {
            serialized.push(1);
            serialized.extend_from_slice(a);
        } else {
            serialized.push(0);
        }
        serialized.extend_from_slice(&[0u8; 2]);
        for addr in addresses {
            serialized.extend_from_slice(addr);
        }

        vectors.push(AddressLookupTableStateTestVector {
            name: name.to_string(),
            deactivation_slot: *deactivation_slot,
            last_extended_slot: *last_extended_slot,
            last_extended_slot_start_index: *last_extended_slot_start_index,
            authority: *auth,
            addresses: addresses.clone(),
            serialized,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(
        output_dir.join("address_lookup_table_state_vectors.json"),
        json,
    )
    .unwrap();
}

pub fn generate_versioned_message_vectors(output_dir: &Path) {
    let test_cases: &[(&str, u8, u8, u8, u8, u8, u8)] = &[
        ("v0_simple", 0, 1, 0, 1, 2, 0),
        ("v0_with_lookups", 0, 2, 1, 2, 3, 2),
        ("v0_readonly_signed", 0, 3, 2, 1, 4, 1),
        ("v0_max_signers", 0, 255, 127, 127, 10, 5),
    ];

    let mut vectors: Vec<VersionedMessageTestVector> = Vec::new();

    for (
        name,
        version,
        num_required_signatures,
        num_readonly_signed,
        num_readonly_unsigned,
        static_keys_count,
        lookups_count,
    ) in test_cases
    {
        let mut serialized = Vec::new();
        serialized.push(0x80 | version);
        serialized.push(*num_required_signatures);
        serialized.push(*num_readonly_signed);
        serialized.push(*num_readonly_unsigned);
        serialized.push(*static_keys_count);

        vectors.push(VersionedMessageTestVector {
            name: name.to_string(),
            version: *version,
            num_required_signatures: *num_required_signatures,
            num_readonly_signed: *num_readonly_signed,
            num_readonly_unsigned: *num_readonly_unsigned,
            static_account_keys_count: *static_keys_count,
            address_table_lookups_count: *lookups_count,
            serialized_prefix: serialized,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("versioned_message_vectors.json"), json).unwrap();
}

pub fn generate_upgradeable_loader_state_vectors(output_dir: &Path) {
    let authority = Pubkey::from_str_const("11111111111111111111111111111111");
    let programdata_addr = Pubkey::from_str_const("Vote111111111111111111111111111111111111111");

    let mut vectors: Vec<UpgradeableLoaderStateTestVector> = Vec::new();

    // Uninitialized state - discriminant 0, 4 bytes total
    vectors.push(UpgradeableLoaderStateTestVector {
        name: "uninitialized".to_string(),
        state_type: "Uninitialized".to_string(),
        discriminant: 0,
        authority: None,
        programdata_address: None,
        slot: None,
        serialized: 0u32.to_le_bytes().to_vec(),
    });

    // Buffer state with authority - discriminant 1
    // Format: discriminant (4) + Some(1) + authority (32) = 37 bytes
    {
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&1u32.to_le_bytes());
        serialized.push(1); // Some
        serialized.extend_from_slice(&authority.to_bytes());

        vectors.push(UpgradeableLoaderStateTestVector {
            name: "buffer_with_authority".to_string(),
            state_type: "Buffer".to_string(),
            discriminant: 1,
            authority: Some(authority.to_bytes()),
            programdata_address: None,
            slot: None,
            serialized,
        });
    }

    // Buffer state without authority - discriminant 1
    // Format: discriminant (4) + None(0) = 5 bytes
    {
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&1u32.to_le_bytes());
        serialized.push(0); // None

        vectors.push(UpgradeableLoaderStateTestVector {
            name: "buffer_no_authority".to_string(),
            state_type: "Buffer".to_string(),
            discriminant: 1,
            authority: None,
            programdata_address: None,
            slot: None,
            serialized,
        });
    }

    // Program state - discriminant 2
    // Format: discriminant (4) + programdata_address (32) = 36 bytes
    {
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&2u32.to_le_bytes());
        serialized.extend_from_slice(&programdata_addr.to_bytes());

        vectors.push(UpgradeableLoaderStateTestVector {
            name: "program".to_string(),
            state_type: "Program".to_string(),
            discriminant: 2,
            authority: None,
            programdata_address: Some(programdata_addr.to_bytes()),
            slot: None,
            serialized,
        });
    }

    // ProgramData with authority - discriminant 3
    // Format: discriminant (4) + slot (8) + Some(1) + authority (32) = 45 bytes
    {
        let slot: u64 = 12345678;
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&3u32.to_le_bytes());
        serialized.extend_from_slice(&slot.to_le_bytes());
        serialized.push(1); // Some
        serialized.extend_from_slice(&authority.to_bytes());

        vectors.push(UpgradeableLoaderStateTestVector {
            name: "program_data_with_authority".to_string(),
            state_type: "ProgramData".to_string(),
            discriminant: 3,
            authority: Some(authority.to_bytes()),
            programdata_address: None,
            slot: Some(slot),
            serialized,
        });
    }

    // ProgramData without authority - discriminant 3
    // Format: discriminant (4) + slot (8) + None(0) = 13 bytes
    {
        let slot: u64 = 87654321;
        let mut serialized = Vec::new();
        serialized.extend_from_slice(&3u32.to_le_bytes());
        serialized.extend_from_slice(&slot.to_le_bytes());
        serialized.push(0); // None

        vectors.push(UpgradeableLoaderStateTestVector {
            name: "program_data_no_authority".to_string(),
            state_type: "ProgramData".to_string(),
            discriminant: 3,
            authority: None,
            programdata_address: None,
            slot: Some(slot),
            serialized,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(
        output_dir.join("upgradeable_loader_state_vectors.json"),
        json,
    )
    .unwrap();
}

pub fn generate_bn254_constants_vectors(output_dir: &Path) {
    let vectors = vec![Bn254ConstantsTestVector {
        name: "bn254_constants".to_string(),
        field_size: 32,
        g1_point_size: 64,
        g2_point_size: 128,
        g1_add_input_size: 128,
        g1_mul_input_size: 96,
        pairing_element_size: 192,
        pairing_output_size: 32,
        g1_add_be_op: 0,
        g1_sub_be_op: 1,
        g1_mul_be_op: 2,
        pairing_be_op: 3,
        le_flag: 0x80,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("bn254_constants_vectors.json"), json).unwrap();
}

pub fn generate_slot_history_constants_vectors(output_dir: &Path) {
    const MAX_ENTRIES: u64 = 1024 * 1024;

    let vectors = vec![SlotHistoryConstantsTestVector {
        name: "slot_history_constants".to_string(),
        max_entries: MAX_ENTRIES,
        bitvec_words: (MAX_ENTRIES / 64) as usize,
        sysvar_id: solana_sdk::sysvar::slot_history::ID.to_bytes(),
        sysvar_id_base58: solana_sdk::sysvar::slot_history::ID.to_string(),
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("slot_history_constants_vectors.json"), json).unwrap();
}

pub fn generate_big_mod_exp_vectors(output_dir: &Path) {
    let mut vectors: Vec<BigModExpTestVector> = Vec::new();

    vectors.push(BigModExpTestVector {
        name: "simple_2_3_mod_5".to_string(),
        base: vec![2],
        exponent: vec![3],
        modulus: vec![5],
        expected_result: vec![3],
    });

    vectors.push(BigModExpTestVector {
        name: "2_10_mod_1000".to_string(),
        base: vec![2, 0, 0, 0, 0, 0, 0, 0],
        exponent: vec![10, 0, 0, 0, 0, 0, 0, 0],
        modulus: vec![0xE8, 0x03, 0, 0, 0, 0, 0, 0],
        expected_result: vec![24, 0, 0, 0, 0, 0, 0, 0],
    });

    vectors.push(BigModExpTestVector {
        name: "any_pow_0_mod_m".to_string(),
        base: vec![42],
        exponent: vec![0],
        modulus: vec![17],
        expected_result: vec![1],
    });

    vectors.push(BigModExpTestVector {
        name: "base_pow_exp_mod_1".to_string(),
        base: vec![42],
        exponent: vec![10],
        modulus: vec![1],
        expected_result: vec![0],
    });

    vectors.push(BigModExpTestVector {
        name: "7_pow_13_mod_123".to_string(),
        base: vec![7, 0, 0, 0, 0, 0, 0, 0],
        exponent: vec![13, 0, 0, 0, 0, 0, 0, 0],
        modulus: vec![123, 0, 0, 0, 0, 0, 0, 0],
        expected_result: vec![94, 0, 0, 0, 0, 0, 0, 0],
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("big_mod_exp_vectors.json"), json).unwrap();
}

pub fn generate_authorize_vectors(output_dir: &Path) {
    use solana_stake_interface::state::Authorized;

    let mut vectors: Vec<AuthorizeTestVector> = Vec::new();

    let staker = Pubkey::from_str_const("11111111111111111111111111111111");
    let withdrawer = Pubkey::from_str_const("Vote111111111111111111111111111111111111111");

    let auth = Authorized { staker, withdrawer };
    let serialized = bincode::serialize(&auth).unwrap();

    vectors.push(AuthorizeTestVector {
        name: "basic_authorized".to_string(),
        staker: staker.to_bytes(),
        withdrawer: withdrawer.to_bytes(),
        serialized,
    });

    let auth2 = Authorized {
        staker: Pubkey::default(),
        withdrawer: Pubkey::default(),
    };
    let serialized2 = bincode::serialize(&auth2).unwrap();

    vectors.push(AuthorizeTestVector {
        name: "default_authorized".to_string(),
        staker: Pubkey::default().to_bytes(),
        withdrawer: Pubkey::default().to_bytes(),
        serialized: serialized2,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("authorize_vectors.json"), json).unwrap();
}

pub fn generate_account_layout_vectors(output_dir: &Path) {
    let vectors = vec![AccountLayoutTestVector {
        name: "account_data_layout".to_string(),
        data_header_size: 88,
        account_data_padding: 10 * 1024,
        duplicate_index_offset: 0,
        is_signer_offset: 1,
        is_writable_offset: 2,
        is_executable_offset: 3,
        original_data_len_offset: 4,
        id_offset: 8,
        owner_id_offset: 40,
        lamports_offset: 72,
        data_len_offset: 80,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("account_layout_vectors.json"), json).unwrap();
}

pub fn generate_primitive_type_sizes_vectors(output_dir: &Path) {
    let vectors = vec![PrimitiveTypeSizesTestVector {
        name: "primitive_type_sizes".to_string(),
        u8_size: std::mem::size_of::<u8>(),
        u16_size: std::mem::size_of::<u16>(),
        u32_size: std::mem::size_of::<u32>(),
        u64_size: std::mem::size_of::<u64>(),
        u128_size: std::mem::size_of::<u128>(),
        i8_size: std::mem::size_of::<i8>(),
        i16_size: std::mem::size_of::<i16>(),
        i32_size: std::mem::size_of::<i32>(),
        i64_size: std::mem::size_of::<i64>(),
        i128_size: std::mem::size_of::<i128>(),
        pubkey_size: std::mem::size_of::<Pubkey>(),
        hash_size: std::mem::size_of::<Hash>(),
        signature_size: std::mem::size_of::<Signature>(),
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("primitive_type_sizes_vectors.json"), json).unwrap();
}

pub fn generate_lockup_vectors(output_dir: &Path) {
    use solana_stake_interface::state::Lockup;

    let mut vectors: Vec<LockupTestVector> = Vec::new();

    let lockup1 = Lockup {
        unix_timestamp: 1700000000,
        epoch: 500,
        custodian: Pubkey::from_str_const("Vote111111111111111111111111111111111111111"),
    };
    let serialized1 = bincode::serialize(&lockup1).unwrap();
    vectors.push(LockupTestVector {
        name: "with_custodian".to_string(),
        unix_timestamp: lockup1.unix_timestamp,
        epoch: lockup1.epoch,
        custodian: lockup1.custodian.to_bytes(),
        serialized: serialized1,
    });

    let lockup2 = Lockup::default();
    let serialized2 = bincode::serialize(&lockup2).unwrap();
    vectors.push(LockupTestVector {
        name: "default".to_string(),
        unix_timestamp: lockup2.unix_timestamp,
        epoch: lockup2.epoch,
        custodian: lockup2.custodian.to_bytes(),
        serialized: serialized2,
    });

    let lockup3 = Lockup {
        unix_timestamp: i64::MAX,
        epoch: u64::MAX,
        custodian: Pubkey::from([0xff; 32]),
    };
    let serialized3 = bincode::serialize(&lockup3).unwrap();
    vectors.push(LockupTestVector {
        name: "max_values".to_string(),
        unix_timestamp: lockup3.unix_timestamp,
        epoch: lockup3.epoch,
        custodian: lockup3.custodian.to_bytes(),
        serialized: serialized3,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("lockup_vectors.json"), json).unwrap();
}

pub fn generate_rent_exempt_vectors(output_dir: &Path) {
    use solana_sdk::rent::Rent;

    let rent = Rent::default();
    let mut vectors: Vec<RentExemptTestVector> = Vec::new();

    let test_cases: &[(&str, usize)] = &[
        ("zero_data", 0),
        ("small_account", 100),
        ("medium_account", 1000),
        ("large_account", 10000),
        ("token_account", 165),
        ("mint_account", 82),
    ];

    for (name, data_len) in test_cases {
        let min_balance = rent.minimum_balance(*data_len);
        vectors.push(RentExemptTestVector {
            name: name.to_string(),
            data_len: *data_len,
            lamports_per_byte_year: rent.lamports_per_byte_year,
            exemption_threshold: rent.exemption_threshold,
            account_storage_overhead: 128,
            minimum_balance: min_balance,
        });
    }

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("rent_exempt_vectors.json"), json).unwrap();
}

pub fn generate_bls_constants_vectors(output_dir: &Path) {
    let vectors = vec![BlsConstantsTestVector {
        name: "bls12_381_constants".to_string(),
        pubkey_compressed_size: 48,
        pubkey_affine_size: 96,
        signature_compressed_size: 96,
        signature_affine_size: 192,
        pop_compressed_size: 96,
        pop_affine_size: 192,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("bls_constants_vectors.json"), json).unwrap();
}

pub fn generate_signer_seeds_vectors(output_dir: &Path) {
    let mut vectors: Vec<SignerSeedsTestVector> = Vec::new();

    let program_id = Pubkey::from_str_const("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    let seed1 = b"metadata";
    let mint = Pubkey::from_str_const("So11111111111111111111111111111111111111112");

    let (pda, bump) = Pubkey::find_program_address(&[seed1.as_ref(), mint.as_ref()], &program_id);

    vectors.push(SignerSeedsTestVector {
        name: "token_metadata_pda".to_string(),
        program_id: program_id.to_bytes(),
        seeds: vec![seed1.to_vec(), mint.to_bytes().to_vec()],
        expected_pubkey: pda.to_bytes(),
        expected_bump: bump,
    });

    let program_id2 = Pubkey::from_str_const("11111111111111111111111111111111");
    let seed_simple = b"test";
    let (pda2, bump2) = Pubkey::find_program_address(&[seed_simple.as_ref()], &program_id2);

    vectors.push(SignerSeedsTestVector {
        name: "simple_pda".to_string(),
        program_id: program_id2.to_bytes(),
        seeds: vec![seed_simple.to_vec()],
        expected_pubkey: pda2.to_bytes(),
        expected_bump: bump2,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("signer_seeds_vectors.json"), json).unwrap();
}

pub fn generate_vote_init_vectors(output_dir: &Path) {
    use solana_vote_interface::state::VoteInit;

    let mut vectors: Vec<VoteInitTestVector> = Vec::new();

    let node = Pubkey::from_str_const("4rL4RCWHz3iNCdCaveD8KcHfV9YagGbXgSYq9QWPZ4Zx");
    let voter = Pubkey::from_str_const("8opHzTAnfzRpPEx21XtnrVTX28YQuCpAjcn1PczScKh");
    let withdrawer = Pubkey::from_str_const("CiDwVBFgWV9E5MvXWoLgnEgn2hK7rJikbvfWavzAQz3");

    let vote_init = VoteInit {
        node_pubkey: node,
        authorized_voter: voter,
        authorized_withdrawer: withdrawer,
        commission: 10,
    };
    let serialized = bincode::serialize(&vote_init).unwrap();
    vectors.push(VoteInitTestVector {
        name: "basic_vote_init".to_string(),
        node_pubkey: node.to_bytes(),
        authorized_voter: voter.to_bytes(),
        authorized_withdrawer: withdrawer.to_bytes(),
        commission: 10,
        serialized,
    });

    let vote_init_zero = VoteInit {
        node_pubkey: node,
        authorized_voter: voter,
        authorized_withdrawer: withdrawer,
        commission: 0,
    };
    let serialized_zero = bincode::serialize(&vote_init_zero).unwrap();
    vectors.push(VoteInitTestVector {
        name: "zero_commission".to_string(),
        node_pubkey: node.to_bytes(),
        authorized_voter: voter.to_bytes(),
        authorized_withdrawer: withdrawer.to_bytes(),
        commission: 0,
        serialized: serialized_zero,
    });

    let vote_init_max = VoteInit {
        node_pubkey: node,
        authorized_voter: voter,
        authorized_withdrawer: withdrawer,
        commission: 100,
    };
    let serialized_max = bincode::serialize(&vote_init_max).unwrap();
    vectors.push(VoteInitTestVector {
        name: "max_commission".to_string(),
        node_pubkey: node.to_bytes(),
        authorized_voter: voter.to_bytes(),
        authorized_withdrawer: withdrawer.to_bytes(),
        commission: 100,
        serialized: serialized_max,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("vote_init_vectors.json"), json).unwrap();
}

pub fn generate_vote_state_constants_vectors(output_dir: &Path) {
    use solana_vote_interface::state::{
        INITIAL_LOCKOUT, MAX_EPOCH_CREDITS_HISTORY, MAX_LOCKOUT_HISTORY, VOTE_CREDITS_GRACE_SLOTS,
        VOTE_CREDITS_MAXIMUM_PER_SLOT,
    };

    let vectors = vec![VoteStateConstantsTestVector {
        name: "vote_state_constants".to_string(),
        max_lockout_history: MAX_LOCKOUT_HISTORY,
        initial_lockout: INITIAL_LOCKOUT,
        max_epoch_credits_history: MAX_EPOCH_CREDITS_HISTORY,
        vote_credits_grace_slots: VOTE_CREDITS_GRACE_SLOTS,
        vote_credits_maximum_per_slot: VOTE_CREDITS_MAXIMUM_PER_SLOT,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("vote_state_constants_vectors.json"), json).unwrap();
}

pub fn generate_lookup_table_meta_vectors(output_dir: &Path) {
    use solana_address_lookup_table_interface::state::LookupTableMeta;

    let mut vectors: Vec<LookupTableMetaTestVector> = Vec::new();
    let authority = Pubkey::from_str_const("4rL4RCWHz3iNCdCaveD8KcHfV9YagGbXgSYq9QWPZ4Zx");

    let meta_active = LookupTableMeta {
        deactivation_slot: u64::MAX,
        last_extended_slot: 100,
        last_extended_slot_start_index: 5,
        authority: Some(authority),
        _padding: 0,
    };
    let serialized = bincode::serialize(&meta_active).unwrap();
    vectors.push(LookupTableMetaTestVector {
        name: "active_with_authority".to_string(),
        deactivation_slot: u64::MAX,
        last_extended_slot: 100,
        last_extended_slot_start_index: 5,
        authority_option: 1,
        authority: Some(authority.to_bytes()),
        serialized,
    });

    let meta_deactivated = LookupTableMeta {
        deactivation_slot: 50,
        last_extended_slot: 40,
        last_extended_slot_start_index: 10,
        authority: Some(authority),
        _padding: 0,
    };
    let serialized_deact = bincode::serialize(&meta_deactivated).unwrap();
    vectors.push(LookupTableMetaTestVector {
        name: "deactivated".to_string(),
        deactivation_slot: 50,
        last_extended_slot: 40,
        last_extended_slot_start_index: 10,
        authority_option: 1,
        authority: Some(authority.to_bytes()),
        serialized: serialized_deact,
    });

    let meta_frozen = LookupTableMeta {
        deactivation_slot: u64::MAX,
        last_extended_slot: 200,
        last_extended_slot_start_index: 0,
        authority: None,
        _padding: 0,
    };
    let serialized_frozen = bincode::serialize(&meta_frozen).unwrap();
    vectors.push(LookupTableMetaTestVector {
        name: "frozen_no_authority".to_string(),
        deactivation_slot: u64::MAX,
        last_extended_slot: 200,
        last_extended_slot_start_index: 0,
        authority_option: 0,
        authority: None,
        serialized: serialized_frozen,
    });

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("lookup_table_meta_vectors.json"), json).unwrap();
}

pub fn generate_compute_budget_constants_vectors(output_dir: &Path) {
    let vectors = vec![ComputeBudgetConstantsTestVector {
        name: "compute_budget_constants".to_string(),
        max_compute_unit_limit: 1_400_000,
        default_instruction_compute_unit_limit: 200_000,
        max_heap_frame_bytes: 256 * 1024,
        min_heap_frame_bytes: 32 * 1024,
        max_loaded_accounts_data_size_bytes: 64 * 1024 * 1024,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(
        output_dir.join("compute_budget_constants_vectors.json"),
        json,
    )
    .unwrap();
}

pub fn generate_nonce_constants_vectors(output_dir: &Path) {
    let vectors = vec![NonceConstantsTestVector {
        name: "nonce_constants".to_string(),
        nonce_account_length: 80,
        nonced_tx_marker_ix_index: 0,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("nonce_constants_vectors.json"), json).unwrap();
}

pub fn generate_alt_constants_vectors(output_dir: &Path) {
    use solana_address_lookup_table_interface::state::{
        LOOKUP_TABLE_MAX_ADDRESSES, LOOKUP_TABLE_META_SIZE,
    };

    let vectors = vec![AltConstantsTestVector {
        name: "alt_constants".to_string(),
        max_addresses: LOOKUP_TABLE_MAX_ADDRESSES,
        meta_size: LOOKUP_TABLE_META_SIZE,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("alt_constants_vectors.json"), json).unwrap();
}

pub fn generate_bpf_loader_state_sizes_vectors(output_dir: &Path) {
    let vectors = vec![BpfLoaderStateSizesTestVector {
        name: "bpf_loader_state_sizes".to_string(),
        uninitialized_size: 4,
        buffer_size: 37,
        program_size: 36,
        programdata_size: 45,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("bpf_loader_state_sizes_vectors.json"), json).unwrap();
}

pub fn generate_ed25519_constants_vectors(output_dir: &Path) {
    let vectors = vec![Ed25519ConstantsTestVector {
        name: "ed25519_constants".to_string(),
        pubkey_size: 32,
        signature_size: 64,
        offsets_size: 14,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("ed25519_constants_vectors.json"), json).unwrap();
}

pub fn generate_epoch_schedule_constants_vectors(output_dir: &Path) {
    let vectors = vec![EpochScheduleConstantsTestVector {
        name: "epoch_schedule_constants".to_string(),
        default_slots_per_epoch: 432_000,
        default_leader_schedule_slot_offset: 432_000,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(
        output_dir.join("epoch_schedule_constants_vectors.json"),
        json,
    )
    .unwrap();
}

pub fn generate_account_limits_vectors(output_dir: &Path) {
    use solana_sdk::account_info::MAX_PERMITTED_DATA_INCREASE;

    let vectors = vec![AccountLimitsTestVector {
        name: "account_limits".to_string(),
        max_permitted_data_increase: MAX_PERMITTED_DATA_INCREASE,
        max_accounts: 64,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("account_limits_vectors.json"), json).unwrap();
}

pub fn generate_sysvar_sizes_vectors(output_dir: &Path) {
    use solana_epoch_schedule::EpochSchedule;
    use solana_sdk::clock::Clock;
    use solana_sdk::rent::Rent;

    let vectors = vec![SysvarSizesTestVector {
        name: "sysvar_sizes".to_string(),
        clock_size: std::mem::size_of::<Clock>(),
        rent_size: std::mem::size_of::<Rent>(),
        epoch_schedule_size: std::mem::size_of::<EpochSchedule>(),
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("sysvar_sizes_vectors.json"), json).unwrap();
}

pub fn generate_native_token_constants_vectors(output_dir: &Path) {
    let vectors = vec![NativeTokenConstantsTestVector {
        name: "native_token_constants".to_string(),
        lamports_per_sol: 1_000_000_000,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("native_token_constants_vectors.json"), json).unwrap();
}

pub fn generate_secp256k1_constants_vectors(output_dir: &Path) {
    let vectors = vec![Secp256k1ConstantsTestVector {
        name: "secp256k1_constants".to_string(),
        pubkey_size: 64,
        private_key_size: 32,
        hashed_pubkey_size: 20,
        signature_size: 64,
        offsets_size: 11,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("secp256k1_constants_vectors.json"), json).unwrap();
}

pub fn generate_signature_sizes_vectors(output_dir: &Path) {
    let vectors = vec![SignatureSizesTestVector {
        name: "signature_sizes".to_string(),
        ed25519_signature_size: 64,
        ed25519_pubkey_size: 32,
        secp256k1_signature_size: 64,
        secp256r1_signature_size: 64,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("signature_sizes_vectors.json"), json).unwrap();
}

pub fn generate_hash_sizes_vectors(output_dir: &Path) {
    let vectors = vec![HashSizesTestVector {
        name: "hash_sizes".to_string(),
        sha256_size: 32,
        keccak256_size: 32,
        blake3_size: 32,
        solana_hash_size: 32,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("hash_sizes_vectors.json"), json).unwrap();
}

pub fn generate_special_addresses_vectors(output_dir: &Path) {
    let incinerator = Pubkey::from_str_const("1nc1nerator11111111111111111111111111111111");

    let vectors = vec![SpecialAddressesTestVector {
        name: "special_addresses".to_string(),
        incinerator: incinerator.to_bytes(),
        incinerator_base58: incinerator.to_string(),
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("special_addresses_vectors.json"), json).unwrap();
}

pub fn generate_pubkey_sizes_vectors(output_dir: &Path) {
    use solana_sdk::pubkey::{MAX_SEEDS, MAX_SEED_LEN, PUBKEY_BYTES};

    let vectors = vec![PubkeySizesTestVector {
        name: "pubkey_sizes".to_string(),
        pubkey_size: PUBKEY_BYTES,
        max_seed_len: MAX_SEED_LEN,
        max_seeds: MAX_SEEDS,
    }];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("pubkey_sizes_vectors.json"), json).unwrap();
}

pub fn generate_sysvar_id_vectors(output_dir: &Path) {
    use solana_sdk::sysvar;

    let vectors = vec![
        SysvarIdTestVector {
            name: "clock".to_string(),
            pubkey: sysvar::clock::ID.to_bytes(),
            base58: sysvar::clock::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "epoch_schedule".to_string(),
            pubkey: sysvar::epoch_schedule::ID.to_bytes(),
            base58: sysvar::epoch_schedule::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "fees".to_string(),
            pubkey: sysvar::fees::ID.to_bytes(),
            base58: sysvar::fees::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "instructions".to_string(),
            pubkey: sysvar::instructions::ID.to_bytes(),
            base58: sysvar::instructions::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "recent_blockhashes".to_string(),
            pubkey: sysvar::recent_blockhashes::ID.to_bytes(),
            base58: sysvar::recent_blockhashes::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "rent".to_string(),
            pubkey: sysvar::rent::ID.to_bytes(),
            base58: sysvar::rent::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "slot_hashes".to_string(),
            pubkey: sysvar::slot_hashes::ID.to_bytes(),
            base58: sysvar::slot_hashes::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "slot_history".to_string(),
            pubkey: sysvar::slot_history::ID.to_bytes(),
            base58: sysvar::slot_history::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "epoch_rewards".to_string(),
            pubkey: sysvar::epoch_rewards::ID.to_bytes(),
            base58: sysvar::epoch_rewards::ID.to_string(),
        },
        SysvarIdTestVector {
            name: "last_restart_slot".to_string(),
            pubkey: sysvar::last_restart_slot::ID.to_bytes(),
            base58: sysvar::last_restart_slot::ID.to_string(),
        },
    ];

    let json = serde_json::to_string_pretty(&vectors).unwrap();
    fs::write(output_dir.join("sysvar_id_vectors.json"), json).unwrap();
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
    generate_transaction_vectors(output_dir);
    generate_sysvar_id_vectors(output_dir);
    generate_native_program_id_vectors(output_dir);
    generate_secp256k1_instruction_vectors(output_dir);
    generate_slot_hash_vectors(output_dir);
    generate_epoch_rewards_vectors(output_dir);
    generate_last_restart_slot_vectors(output_dir);
    generate_secp256r1_instruction_vectors(output_dir);
    generate_feature_gate_instruction_vectors(output_dir);
    generate_program_data_vectors(output_dir);
    generate_ed25519_instruction_vectors(output_dir);
    generate_system_instruction_extended_vectors(output_dir);
    generate_address_lookup_table_state_vectors(output_dir);
    generate_versioned_message_vectors(output_dir);
    generate_upgradeable_loader_state_vectors(output_dir);
    generate_bn254_constants_vectors(output_dir);
    generate_slot_history_constants_vectors(output_dir);
    generate_big_mod_exp_vectors(output_dir);
    generate_authorize_vectors(output_dir);
    generate_account_layout_vectors(output_dir);
    generate_primitive_type_sizes_vectors(output_dir);
    generate_lockup_vectors(output_dir);
    generate_rent_exempt_vectors(output_dir);
    generate_bls_constants_vectors(output_dir);
    generate_signer_seeds_vectors(output_dir);
    generate_vote_init_vectors(output_dir);
    generate_vote_state_constants_vectors(output_dir);
    generate_lookup_table_meta_vectors(output_dir);
    generate_compute_budget_constants_vectors(output_dir);
    generate_nonce_constants_vectors(output_dir);
    generate_alt_constants_vectors(output_dir);
    generate_bpf_loader_state_sizes_vectors(output_dir);
    generate_ed25519_constants_vectors(output_dir);
    generate_epoch_schedule_constants_vectors(output_dir);
    generate_account_limits_vectors(output_dir);
    generate_sysvar_sizes_vectors(output_dir);
    generate_native_token_constants_vectors(output_dir);
    generate_secp256k1_constants_vectors(output_dir);
    generate_signature_sizes_vectors(output_dir);
    generate_hash_sizes_vectors(output_dir);
    generate_special_addresses_vectors(output_dir);
    generate_pubkey_sizes_vectors(output_dir);

    println!("Generated all test vectors in {:?}", output_dir);
}
