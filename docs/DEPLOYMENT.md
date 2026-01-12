# Deployment Guide

This guide describes how to build and deploy Solana programs compiled with `solana-zig`.

## Prerequisites

- `solana-zig` installed (`./install-solana-zig.sh`)
- Solana CLI installed and configured

```bash
# Install Solana CLI (official)
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"

# Verify
solana --version
```

## Build for SBF

Use the Solana SBF target and the custom compiler:

```bash
./solana-zig/zig build -Dtarget=sbf-solana
```

Output example:

```bash
zig-out/lib/<program-name>.so
```

## Deploy to Localnet

```bash
# Terminal 1
solana-test-validator

# Terminal 2
solana config set --url localhost
solana program deploy zig-out/lib/<program-name>.so
```

## Deploy to Devnet

```bash
solana config set --url devnet
solana airdrop 2
solana program deploy zig-out/lib/<program-name>.so
```

## Deploy to Mainnet

```bash
solana config set --url mainnet-beta
solana balance
solana program deploy zig-out/lib/<program-name>.so
```

## Upgrade Authority

```bash
# Upgrade program
solana program deploy zig-out/lib/<program-name>.so --program-id <PROGRAM_ID>

# Transfer upgrade authority
solana program set-upgrade-authority <PROGRAM_ID> --new-upgrade-authority <NEW_AUTHORITY>

# Make program immutable (irreversible)
solana program set-upgrade-authority <PROGRAM_ID> --final
```

## Troubleshooting

- **Insufficient funds**: `solana airdrop 2 --url devnet` (devnet only)
- **Missing .so output**: confirm `./solana-zig/zig` is used, not system zig

## References

- https://solana.com/docs/programs/deploying
- https://docs.solana.com/cli
