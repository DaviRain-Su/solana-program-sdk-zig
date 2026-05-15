# spl-elgamal-registry

Allocation-free Zig client helpers for the SPL ElGamal Registry program.

## Scope

- Registry PDA derivation with the canonical `elgamal-registry` seed.
- `ElGamalRegistry` account layout constants.
- `CreateRegistry` / `UpdateRegistry` instruction builders for context-state,
  instruction-offset, and record-account proof locations.
- Low-CU `*ForRegistry` builders that accept a precomputed registry PDA, plus
  convenience wrappers that derive the PDA into caller-owned scratch.
- Host-side Zig tests plus Rust parity against `spl-elgamal-registry = 0.2.0`.

## Non-goals

The package does not generate ZK pubkey-validity proof instructions. Callers can
compose those with the proof program directly and use these builders for the
registry instruction shape.
