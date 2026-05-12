//! Cryptographic primitives — aggregated namespace.
//!
//! Solana exposes seven hash / curve / signature syscalls in total.
//! Rather than scatter them across the SDK, this module groups them
//! so on-chain code can write `sol.crypto.sha256(...)` /
//! `sol.crypto.secp256k1_recover.recover(...)` etc., and IDE
//! auto-completion narrows the search.
//!
//! Layout:
//!
//! | Sub-module | Syscalls wrapped |
//! |------------|------------------|
//! | `hash`     | `sol_sha256`, `sol_keccak256`, `sol_blake3` |
//! | `secp256k1_recover` | `sol_secp256k1_recover` |
//! | `alt_bn128` | `sol_alt_bn128_group_op` (G1 add/sub/mul, pairing) |
//! | `poseidon` | `sol_poseidon` |
//!
//! Each sub-module is also re-exported at the top level
//! (`sol.hash`, `sol.secp256k1_recover`, …) for backwards
//! compatibility and ergonomics — pick whichever spelling reads
//! better at the call site.

pub const hash = @import("hash.zig");
pub const secp256k1_recover = @import("secp256k1_recover.zig");
pub const alt_bn128 = @import("alt_bn128.zig");
pub const poseidon = @import("poseidon.zig");

// Most-used helpers re-exported flat so the common case is short:
//
//   sol.crypto.sha256(...)
//   sol.crypto.keccak256(...)
//   sol.crypto.blake3(...)
//   sol.crypto.hashv(...)   // alias for sha256
//
pub const Hash = hash.Hash;
pub const sha256 = hash.sha256;
pub const keccak256 = hash.keccak256;
pub const blake3 = hash.blake3;
pub const hashv = hash.hashv;
