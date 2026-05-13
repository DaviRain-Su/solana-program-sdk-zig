# Packages

Sub-packages of [`solana-sdk-mono`](../README.md). Each directory is
an independent Zig package with its own `build.zig.zon`, depending on
the root SDK via a path import.

## Layout

| Package | Target | Status | Purpose |
|---|---|---|---|
| [`spl-token`](./spl-token) | dual (on-chain CPI + off-chain ix builder) | ✅ v0.2 | SPL Token (transfer / authority / multisig / …) |
| [`spl-ata`](./spl-ata) | dual | ✅ v0.1 | Associated Token Account address derivation + create CPI |
| [`spl-memo`](./spl-memo) | dual | ✅ v0.1 | SPL Memo program CPI |

See [`../ROADMAP.md`](../ROADMAP.md#monorepo-分层) for the full
package-naming convention and dependency layout rationale.

## Conventions

Every sub-package follows the same shape:

```
packages/<name>/
├── README.md
├── build.zig                    # builds the package + its examples
├── build.zig.zon                # depends on solana_program_sdk via path
├── src/
│   ├── root.zig                 # public re-exports
│   ├── id.zig                   # Program ID + well-known constants
│   ├── state.zig                # account-state extern structs (dual)
│   ├── instruction.zig          # ix builders — raw byte construction (dual)
│   └── cpi.zig                  # on-chain invoke() wrappers (syntactic sugar)
├── examples/                    # demo programs using the package
└── program-test/                # Rust integration tests (real .so)
```

The split between `instruction.zig` (dual-target) and `cpi.zig`
(on-chain only) mirrors the Rust ecosystem's pattern of having a
single SPL crate usable both on-chain (CPI) and off-chain (transaction
building) — `instruction.zig` constructs `sol.cpi.Instruction` /
`sol.cpi.AccountMeta` byte buffers that work in either context, while
`cpi.zig` adds a thin wrapper around `sol_invoke_signed_c` for the
common on-chain case.

## Adding a new package

1. `mkdir packages/<name>` and copy the scaffold from an existing
   package (start with `spl-memo` — it's the simplest).
2. Update `build.zig.zon` with the package's own name and version.
3. Add a row to the table above and to the top-level README.
4. Wire the package into `.github/workflows/ci.yml` so CI runs its
   tests + SBF build.
