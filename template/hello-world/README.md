# hello-world template

A minimal Solana Zig starter based on stock Zig + `elf2sbpf`.

## Quick start

```bash
./scripts/bootstrap.sh
zig build test --summary all
./program-test/test.sh
```

Then edit:

- `src/main.zig`

## Build the program

```bash
zig build
```

## Run integration tests

```bash
./program-test/test.sh
```
