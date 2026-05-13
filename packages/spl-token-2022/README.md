# spl-token-2022 (Zig)

Status: ✅ **v0.1 parsing-only** — read-only Token-2022 mint/account
TLV parsing plus fixed-length extension views, validated by host tests
and the real `example_spl_token_2022_parse.so` program-test artifact.

`spl_token_2022` is an on-chain-safe parsing package for the
[SPL Token-2022](https://github.com/solana-program/token-2022)
account layout. It exports the canonical program id, account-type
parsing, base layout constants, TLV scanning, and typed fixed-length
extension views.

## Scope (v0.1)

- canonical Token-2022 `PROGRAM_ID`
- mint/account base layout parsing
- TLV iterator + lookup helpers
- fixed-length mint/account extension views
- parsing demo wired into `program-test/build.zig`

## Not in scope

- instruction builders or CPI wrappers
- confidential extension parsing
- variable-length TokenMetadata / TokenGroup / TokenGroupMember parsers
- off-chain RPC / transaction / keypair packages

## Commands

```console
# Package host tests
zig build --build-file packages/spl-token-2022/build.zig test --summary all

# Full SBF + Mollusk regression suite
SOLANA_ZIG="${SOLANA_ZIG:-$(scripts/ensure-solana-zig.sh)}" && ./program-test/test.sh "$SOLANA_ZIG"
```
