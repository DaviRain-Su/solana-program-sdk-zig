//! `solana_keypair` — host-side Ed25519 signing foundations.
//!
//! v0.1 intentionally exposes only byte-level key recovery and detached
//! signatures. Wallet-file parsing, mnemonic derivation, RPC, and
//! transaction assembly are separate concerns.

const std = @import("std");
const sol = @import("solana_program_sdk");

const Ed25519 = std.crypto.sign.Ed25519;

pub const Pubkey = sol.Pubkey;
pub const SEED_BYTES: usize = Ed25519.KeyPair.seed_length;
pub const PUBLIC_KEY_BYTES: usize = Ed25519.PublicKey.encoded_length;
pub const SECRET_KEY_BYTES: usize = Ed25519.SecretKey.encoded_length;
pub const SIGNATURE_BYTES: usize = Ed25519.Signature.encoded_length;

pub const Seed = [SEED_BYTES]u8;
pub const SecretKeyBytes = [SECRET_KEY_BYTES]u8;
pub const Signature = [SIGNATURE_BYTES]u8;

pub const Keypair = struct {
    inner: Ed25519.KeyPair,

    pub fn fromSeed(secret_seed: Seed) !Keypair {
        return .{ .inner = try Ed25519.KeyPair.generateDeterministic(secret_seed) };
    }

    /// Recover from Solana CLI-style secret-key bytes:
    /// `seed[32] || public_key[32]`.
    pub fn fromSecretKeyBytes(bytes: SecretKeyBytes) !Keypair {
        const secret = try Ed25519.SecretKey.fromBytes(bytes);
        return .{ .inner = try Ed25519.KeyPair.fromSecretKey(secret) };
    }

    pub fn publicKey(self: Keypair) Pubkey {
        return self.inner.public_key.toBytes();
    }

    pub fn seed(self: Keypair) Seed {
        return self.inner.secret_key.seed();
    }

    pub fn secretKeyBytes(self: Keypair) SecretKeyBytes {
        return self.inner.secret_key.toBytes();
    }

    pub fn sign(self: Keypair, message: []const u8) !Signature {
        const sig = try self.inner.sign(message, null);
        return sig.toBytes();
    }
};

pub fn verify(signature: Signature, message: []const u8, public_key: *const Pubkey) !void {
    const pk = try Ed25519.PublicKey.fromBytes(public_key.*);
    const sig = Ed25519.Signature.fromBytes(signature);
    try sig.verify(message, pk);
}

test "Keypair.fromSeed matches std Ed25519 deterministic vector" {
    var seed: Seed = undefined;
    _ = try std.fmt.hexToBytes(seed[0..], "8052030376d47112be7f73ed7a019293dd12ad910b654455798b4667d73de166");

    const kp = try Keypair.fromSeed(seed);
    var buf: [256]u8 = undefined;

    try std.testing.expectEqualStrings(
        try std.fmt.bufPrint(&buf, "{X}", .{&kp.publicKey()}),
        "2D6F7455D97B4A3A10D7293909D1A4F2058CB9A370E43FA8154BB280DB839083",
    );
    try std.testing.expectEqualStrings(
        try std.fmt.bufPrint(&buf, "{X}", .{&kp.secretKeyBytes()}),
        "8052030376D47112BE7F73ED7A019293DD12AD910B654455798B4667D73DE1662D6F7455D97B4A3A10D7293909D1A4F2058CB9A370E43FA8154BB280DB839083",
    );
}

test "Keypair signs and verifies detached Solana message bytes" {
    var seed: Seed = undefined;
    _ = try std.fmt.hexToBytes(seed[0..], "8052030376d47112be7f73ed7a019293dd12ad910b654455798b4667d73de166");

    const kp = try Keypair.fromSeed(seed);
    const sig = try kp.sign("test");

    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings(
        try std.fmt.bufPrint(&buf, "{X}", .{&sig}),
        "10A442B4A80CC4225B154F43BEF28D2472CA80221951262EB8E0DF9091575E2687CC486E77263C3418C757522D54F84B0359236ABBBD4ACD20DC297FDCA66808",
    );

    const pubkey = kp.publicKey();
    try verify(sig, "test", &pubkey);
    try std.testing.expectError(error.SignatureVerificationFailed, verify(sig, "TEST", &pubkey));
}

test "Keypair round-trips through Solana-style 64-byte secret key" {
    const seed: Seed = .{7} ** SEED_BYTES;
    const from_seed = try Keypair.fromSeed(seed);
    const recovered = try Keypair.fromSecretKeyBytes(from_seed.secretKeyBytes());

    try std.testing.expectEqualSlices(u8, &from_seed.publicKey(), &recovered.publicKey());
    try std.testing.expectEqualSlices(u8, &from_seed.seed(), &recovered.seed());
}

test "@import(\"solana_keypair\") exposes signing only" {
    try std.testing.expect(@hasDecl(@This(), "Keypair"));
    try std.testing.expect(@hasDecl(@This(), "verify"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "client"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
    try std.testing.expect(!@hasDecl(@This(), "transaction"));
}
