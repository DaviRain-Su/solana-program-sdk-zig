# solana_loader_v4

Loader v4 helpers for Unchain host tooling and transaction builders.

The public API mirrors the repository's other instruction packages:
callers own the storage for account metas and instruction data, while
builders return slices into those buffers without allocating.

Covered surface:

- Loader v4 program id, deployment cooldown, and `LoaderV4State` layout.
- Instruction builders for write, copy, set program length, deploy,
  deploy-from-source, retract, transfer authority, and finalize.
- Composite `createBuffer` helper combining System Program account creation
  with the initial `SetProgramLength` instruction.

Rust parity lives under `rust-parity/` and compares against
`solana-loader-v4-interface = 3.1.0`.
