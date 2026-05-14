# solana_loader_v3

Upgradeable BPF Loader v3 helpers for Unchain programs and host tooling.

The package keeps the same no-allocation shape as the other ecosystem
packages in this repository: callers provide account-meta and instruction-data
buffers, and builders return slices into those buffers.

Covered surface:

- Loader v3 program ids and metadata size helpers.
- Fixed-size account-state encoders for `Uninitialized`, `Buffer`, `Program`,
  and `ProgramData`.
- Instruction builders for buffer initialization, write, deploy, upgrade,
  authority changes, close, extend, checked extend, and migration to loader v4.
- Chunked program write planning via `writeProgramChunks` for caller-owned
  instruction, account-meta, and data buffers.
- Composite `createBuffer` and `deployWithMaxProgramLen` helpers that pair the
  System Program account creation with the loader instruction.

Rust parity lives under `rust-parity/` and compares against
`solana-loader-v3-interface = 6.1.1`.
