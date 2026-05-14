# solana-client

Host-side Solana JSON-RPC client helpers for Zig.

This v0.1 package builds canonical request bodies into caller-provided
buffers, parses common response envelopes with `std.json`, and exposes a
small transport boundary plus concrete HTTP and WebSocket adapters. HTTP uses
a caller-owned `std.http.Client`; WebSocket uses caller-owned read/write stream
callbacks and performs the JSON-RPC handshake/frame exchange itself.

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
- `WebSocketTransport` adapter for caller-owned socket streams, including HTTP
  Upgrade validation, masked client text frames, and text-frame response reads
- endpoint validation, round-robin endpoint selection, WebSocket URL
  derivation, and client-level WebSocket request dispatch
- default commitment, retry policy, HTTP request timeout, WebSocket
  subscription timeout, optional caller-owned `std.Io` deadline enforcement,
  and typed RPC error normalization

The package still keeps socket/TLS lifetime and entropy ownership with the
caller. `WebSocketTransport` expects an already connected stream and a mask-key
provider rather than opening network sockets internally.

Transaction bytes should come from `solana_tx`; signatures and keypairs
should come from `solana_keypair`.
