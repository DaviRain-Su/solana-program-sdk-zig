# solana-zk-elgamal-proof (Zig)

Status: 🚧 **v0.1 raw instruction builders** — allocation-free builders for
the native ZK ElGamal proof program. The package accepts caller-provided proof
bytes or a proof account plus byte offset; it does not generate cryptographic
proofs.

## Scope

- canonical `PROGRAM_ID`
- `CloseContextState` builder
- raw verify-proof builders for inline proof bytes
- raw verify-proof-from-account builders for pre-written proof accounts
- optional context-state account metas for proof verification output
- Rust parity fixtures against `solana-zk-sdk = 2.3.13`

## Not in scope

- proof generation
- proof verification on the host
- RPC / transaction / keypair orchestration

## Commands

```console
zig build --build-file packages/solana-zk-elgamal-proof/build.zig test --summary all
RUSTC_WRAPPER= cargo test --manifest-path packages/solana-zk-elgamal-proof/rust-parity/Cargo.toml --locked
```
