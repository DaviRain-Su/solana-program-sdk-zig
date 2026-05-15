# solana-feature-gate

Feature Gate Program helpers.

This package exposes the Feature Program ID, the bincode-compatible
feature account layout, and activation instruction-pair assembly using
the shared `solana_system` builders.

## Scope

- `Feature` account encode/decode for activated and inactive states
- Feature activation instruction sequence with caller-owned buffers
- Constants for feature program and account size
