# solana-client

Host-side Solana JSON-RPC client helpers for Zig.

This v0.1 package builds canonical request bodies into caller-provided
buffers, parses common response envelopes with `std.json`, and exposes a
small transport boundary plus a concrete `std.http.Client` POST adapter for
HTTP JSON-RPC. WebSocket subscriptions use the same caller-owned transport
boundary with typed request builders and response / notification parsers.

## Scope

- `getLatestBlockhash` request builder and response parser
- `getBalance` request builder and response parser
- `getAccountInfo` request builder, response parser, and base64 data decode helper
- Address Lookup Table account fetch/parse helper for v0 transaction builders
- `sendTransaction` request builder and response parser
- `simulateTransaction` request builder and response parser
- account, program, logs, signature, slot, and root subscription request
  builders plus unsubscribe builders
- subscription response parsers and account-notification parser
- `Transport` / `Client` abstractions for caller-owned network transport
- `StdHttpTransport` adapter around a caller-owned `std.http.Client`
- endpoint validation, round-robin endpoint selection, WebSocket URL
  derivation, and client-level WebSocket request dispatch
- default commitment, retry policy, HTTP request timeout, WebSocket
  subscription timeout, and typed RPC error normalization

The package does not yet ship its own WebSocket socket implementation; callers
plug a concrete WebSocket transport into `Transport`.

Transaction bytes should come from `solana_tx`; signatures and keypairs
should come from `solana_keypair`.
