# Packages

Sub-packages of [`solana-sdk-mono`](../README.md). Each directory is
an independent Zig package with its own `build.zig.zon`, depending on
the root SDK via a path import.

## Layout

| Package | Target | Status | Purpose |
|---|---|---|---|
| [`spl-token`](./spl-token) | dual (on-chain CPI + off-chain ix builder) | ✅ v0.3 | SPL Token (transfer / authority / multisig / syncNative / …) |
| [`spl-token-2022`](./spl-token-2022) | host + on-chain-safe parsing | ✅ v0.1 parsing-only | Token-2022 TLV + fixed-length extension parsing |
| [`spl-ata`](./spl-ata) | dual | ✅ v0.1 | Associated Token Account address derivation + create CPI |
| [`spl-memo`](./spl-memo) | dual | ✅ v0.1 | SPL Memo program CPI |

See [`../ROADMAP.md`](../ROADMAP.md#monorepo-分层) for the full
package-naming convention and dependency layout rationale.

## Conventions

Most sub-packages follow the same shape:

```
packages/<name>/
├── README.md
├── build.zig                    # builds the package + its examples
├── build.zig.zon                # depends on solana_program_sdk via path
├── src/
│   ├── root.zig                 # public re-exports
│   ├── id.zig                   # Program ID + well-known constants
│   ├── state.zig                # account-state extern structs / base views
│   ├── instruction.zig          # ix builders — when the package exposes them
│   ├── cpi.zig                  # on-chain invoke() wrappers when needed
│   ├── tlv.zig                  # parsing-only packages such as spl_token_2022
│   └── extension.zig            # fixed extension views when applicable
└── examples/                    # demo programs using the package
```

Integration tests live under [`../program-test/tests/`](../program-test/tests/)
and load the built `.so` artifacts from `program-test/zig-out/lib`.

For client-style packages, the split between `instruction.zig` (dual-target) and `cpi.zig`
(on-chain only) mirrors the Rust ecosystem's pattern of having a
single SPL crate usable both on-chain (CPI) and off-chain (transaction
building) — `instruction.zig` constructs `sol.cpi.Instruction` /
`sol.cpi.AccountMeta` byte buffers that work in either context, while
`cpi.zig` adds a thin wrapper around `sol_invoke_signed_c` for the
common on-chain case. `spl-token-2022` is the current parsing-only
exception: v0.1 intentionally exports `id.zig`, `state.zig`, `tlv.zig`,
and `extension.zig`, but no instruction-builder or CPI surface.

## Adding a new package

1. `mkdir packages/<name>` and copy the scaffold from an existing
   package (start with `spl-memo` for CPI/builder packages, or
   `spl-token-2022` for parsing-only packages).
2. Update `build.zig.zon` with the package's own name and version.
3. Add a row to the table above and to the top-level README.
4. Wire the package into `.github/workflows/ci.yml` so CI runs its
   tests + SBF build.
