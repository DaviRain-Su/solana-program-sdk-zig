//! `solana_wallet` — host-side Solana CLI keypair JSON helpers.

const std = @import("std");
const keypair = @import("solana_keypair");

pub const Keypair = keypair.Keypair;
pub const Pubkey = keypair.Pubkey;
pub const SecretKeyBytes = keypair.SecretKeyBytes;
pub const SECRET_KEY_BYTES = keypair.SECRET_KEY_BYTES;
pub const Seed = keypair.Seed;
pub const Signature = keypair.Signature;
pub const BIP39_SEED_BYTES: usize = 64;
pub const BIP39_PBKDF2_ROUNDS: u32 = 2048;
pub const BIP39_MAX_WORDS: usize = 24;
pub const BIP39_MAX_ENTROPY_BYTES: usize = 32;
pub const KEYSTORE_KEY_BYTES: usize = 32;
pub const KEYSTORE_TAG_BYTES: usize = 16;
pub const KEYSTORE_XCHACHA20_POLY1305_NONCE_BYTES: usize = 24;
pub const KEYSTORE_AES_256_GCM_NONCE_BYTES: usize = 12;
pub const DEFAULT_KEYSTORE_PBKDF2_SHA256_ROUNDS: u32 = 210_000;
pub const DEFAULT_KEYSTORE_SCRYPT_PARAMS: std.crypto.pwhash.scrypt.Params = .{
    .ln = 15,
    .r = 8,
    .p = 1,
};
pub const MAX_DERIVATION_PATH_COMPONENTS: usize = 10;
pub const DEFAULT_SOLANA_DERIVATION_PATH: DerivationPath = .{
    .components = &[_]HardenedIndex{ 44, 501, 0, 0 },
};

pub const Error = error{
    InvalidJson,
    InvalidSecretKeyLength,
    InvalidSecretKeyByte,
    OutputTooSmall,
    InvalidMnemonic,
    InvalidMnemonicWord,
    InvalidMnemonicChecksum,
    TooManyDerivationPathComponents,
    InvalidDerivationPath,
    NonHardenedDerivationPath,
    InvalidKeystore,
    UnsupportedKeystoreCipher,
    UnsupportedKeystoreKdf,
    AuthenticationFailed,
};

const HmacSha512 = std.crypto.auth.hmac.sha2.HmacSha512;
const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;
const Aes256Gcm = std.crypto.aead.aes_gcm.Aes256Gcm;
const XChaCha20Poly1305 = std.crypto.aead.chacha_poly.XChaCha20Poly1305;

pub const Bip39Seed = [BIP39_SEED_BYTES]u8;
pub const HardenedIndex = u31;
pub const KeystoreKey = [KEYSTORE_KEY_BYTES]u8;

pub const WordlistResolver = struct {
    context: *anyopaque,
    indexFn: *const fn (context: *anyopaque, word: []const u8) Error!u16,

    pub fn indexOf(self: WordlistResolver, word: []const u8) Error!u16 {
        const index = try self.indexFn(self.context, word);
        if (index >= 2048) return error.InvalidMnemonicWord;
        return index;
    }
};

pub const DerivationPath = struct {
    components: []const HardenedIndex,
};

pub const ParsedDerivationPath = struct {
    components: [MAX_DERIVATION_PATH_COMPONENTS]HardenedIndex,
    len: usize,

    pub fn path(self: *const ParsedDerivationPath) DerivationPath {
        return .{ .components = self.components[0..self.len] };
    }
};

pub const KeystoreCipher = enum {
    xchacha20_poly1305,
    aes_256_gcm,

    pub fn jsonName(self: KeystoreCipher) []const u8 {
        return switch (self) {
            .xchacha20_poly1305 => "xchacha20-poly1305",
            .aes_256_gcm => "aes-256-gcm",
        };
    }
};

pub const KeystoreKdf = enum {
    scrypt,
    pbkdf2_sha256,

    pub fn jsonName(self: KeystoreKdf) []const u8 {
        return switch (self) {
            .scrypt => "scrypt",
            .pbkdf2_sha256 => "pbkdf2-sha256",
        };
    }
};

pub const KeystoreKdfConfig = union(enum) {
    scrypt: std.crypto.pwhash.scrypt.Params,
    pbkdf2_sha256: u32,

    pub fn default(kdf: KeystoreKdf) KeystoreKdfConfig {
        return switch (kdf) {
            .scrypt => .{ .scrypt = DEFAULT_KEYSTORE_SCRYPT_PARAMS },
            .pbkdf2_sha256 => .{ .pbkdf2_sha256 = DEFAULT_KEYSTORE_PBKDF2_SHA256_ROUNDS },
        };
    }
};

pub const EncryptedKeystore = struct {
    version: u8,
    public_key_base58: []const u8,
    cipher: KeystoreCipher,
    kdf: KeystoreKdf,
    nonce_base64: []const u8,
    salt_base64: []const u8,
    ciphertext_base64: []const u8,

    pub fn validate(self: EncryptedKeystore) Error!void {
        if (self.version == 0) return error.InvalidKeystore;
        try validateTextField(self.public_key_base58);
        try validateTextField(self.nonce_base64);
        try validateTextField(self.salt_base64);
        try validateTextField(self.ciphertext_base64);
        if (self.public_key_base58.len == 0 or self.nonce_base64.len == 0 or
            self.salt_base64.len == 0 or self.ciphertext_base64.len == 0)
        {
            return error.InvalidKeystore;
        }
    }
};

pub const ParsedEncryptedKeystore = struct {
    parsed: std.json.Parsed(std.json.Value),
    keystore: EncryptedKeystore,

    pub fn deinit(self: *ParsedEncryptedKeystore) void {
        self.parsed.deinit();
    }
};

pub const WalletAdapter = struct {
    context: *anyopaque,
    publicKeyFn: *const fn (context: *anyopaque) Pubkey,
    signMessageFn: *const fn (context: *anyopaque, message: []const u8) anyerror!Signature,

    pub fn publicKey(self: WalletAdapter) Pubkey {
        return self.publicKeyFn(self.context);
    }

    pub fn signMessage(self: WalletAdapter, message: []const u8) anyerror!Signature {
        return self.signMessageFn(self.context, message);
    }
};

pub const KeypairWallet = struct {
    keypair: Keypair,

    pub fn adapter(self: *KeypairWallet) WalletAdapter {
        return .{
            .context = self,
            .publicKeyFn = publicKeyImpl,
            .signMessageFn = signMessageImpl,
        };
    }

    fn publicKeyImpl(context: *anyopaque) Pubkey {
        const self: *KeypairWallet = @ptrCast(@alignCast(context));
        return self.keypair.publicKey();
    }

    fn signMessageImpl(context: *anyopaque, message: []const u8) anyerror!Signature {
        const self: *KeypairWallet = @ptrCast(@alignCast(context));
        return self.keypair.sign(message);
    }
};

pub fn parseSecretKeyJson(json: []const u8) Error!SecretKeyBytes {
    var parser: Parser = .{ .input = json };
    try parser.skipWhitespace();
    try parser.expect('[');

    var secret: SecretKeyBytes = undefined;
    var index: usize = 0;
    try parser.skipWhitespace();

    if (parser.peek() == ']') return error.InvalidSecretKeyLength;

    while (true) {
        if (index >= SECRET_KEY_BYTES) return error.InvalidSecretKeyLength;
        secret[index] = try parser.parseByte();
        index += 1;

        try parser.skipWhitespace();
        const next = parser.next() orelse return error.InvalidJson;
        if (next == ']') break;
        if (next != ',') return error.InvalidJson;
        try parser.skipWhitespace();
    }

    if (index != SECRET_KEY_BYTES) return error.InvalidSecretKeyLength;
    try parser.skipWhitespace();
    if (!parser.eof()) return error.InvalidJson;
    return secret;
}

pub fn parseKeypairJson(json: []const u8) (Error || anyerror)!Keypair {
    return keypair.Keypair.fromSecretKeyBytes(try parseSecretKeyJson(json));
}

pub fn writeSecretKeyJson(secret: *const SecretKeyBytes, out: []u8) Error![]u8 {
    var pos: usize = 0;
    try appendByte('[', out, &pos);

    for (secret, 0..) |byte, i| {
        if (i != 0) try appendByte(',', out, &pos);
        const written = std.fmt.bufPrint(out[pos..], "{}", .{byte}) catch |err| switch (err) {
            error.NoSpaceLeft => return error.OutputTooSmall,
        };
        pos += written.len;
    }

    try appendByte(']', out, &pos);
    return out[0..pos];
}

pub fn keypairToJson(kp: Keypair, out: []u8) Error![]u8 {
    const secret = kp.secretKeyBytes();
    return writeSecretKeyJson(&secret, out);
}

pub fn mnemonicToSeed(
    mnemonic: []const u8,
    passphrase: []const u8,
    out: *Bip39Seed,
) (Error || std.crypto.errors.WeakParametersError || std.crypto.errors.OutputTooLongError)!void {
    try validateMnemonicPhrase(mnemonic);
    var salt_buf: [256]u8 = undefined;
    if (passphrase.len > salt_buf.len - "mnemonic".len) return error.OutputTooSmall;
    @memcpy(salt_buf[0.."mnemonic".len], "mnemonic");
    @memcpy(salt_buf["mnemonic".len..][0..passphrase.len], passphrase);
    const salt = salt_buf[0 .. "mnemonic".len + passphrase.len];
    try std.crypto.pwhash.pbkdf2(out[0..], mnemonic, salt, BIP39_PBKDF2_ROUNDS, HmacSha512);
}

pub fn mnemonicWordCountToEntropyBytes(word_count: usize) Error!usize {
    return switch (word_count) {
        12 => 16,
        15 => 20,
        18 => 24,
        21 => 28,
        24 => 32,
        else => error.InvalidMnemonic,
    };
}

pub fn mnemonicToEntropy(
    mnemonic: []const u8,
    resolver: WordlistResolver,
    entropy_out: []u8,
) Error![]const u8 {
    var indexes: [BIP39_MAX_WORDS]u16 = undefined;
    const word_count = try resolveMnemonicWords(mnemonic, resolver, &indexes);
    const entropy_len = try mnemonicWordCountToEntropyBytes(word_count);
    if (entropy_out.len < entropy_len) return error.OutputTooSmall;

    const entropy = entropy_out[0..entropy_len];
    @memset(entropy, 0);

    const entropy_bits = entropy_len * 8;
    const checksum_bits = entropy_len / 4;
    for (0..entropy_bits) |bit_index| {
        if (readMnemonicBit(indexes[0..word_count], bit_index)) {
            entropy[bit_index / 8] |= @as(u8, 1) << @intCast(7 - (bit_index % 8));
        }
    }

    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(entropy, &digest, .{});
    for (0..checksum_bits) |checksum_index| {
        const expected = ((digest[checksum_index / 8] >> @intCast(7 - (checksum_index % 8))) & 1) != 0;
        const actual = readMnemonicBit(indexes[0..word_count], entropy_bits + checksum_index);
        if (actual != expected) return error.InvalidMnemonicChecksum;
    }

    return entropy;
}

pub fn validateMnemonicChecksum(
    mnemonic: []const u8,
    resolver: WordlistResolver,
) Error!void {
    var entropy: [BIP39_MAX_ENTROPY_BYTES]u8 = undefined;
    _ = try mnemonicToEntropy(mnemonic, resolver, &entropy);
}

pub fn parseDerivationPath(path: []const u8) Error!ParsedDerivationPath {
    if (path.len < 2 or path[0] != 'm') return error.InvalidDerivationPath;
    var parsed: ParsedDerivationPath = .{
        .components = undefined,
        .len = 0,
    };
    if (path.len == 1) {
        return parsed;
    }
    if (path[1] != '/') return error.InvalidDerivationPath;

    var pos: usize = 2;
    var count: usize = 0;
    while (pos < path.len) {
        if (count >= MAX_DERIVATION_PATH_COMPONENTS) return error.TooManyDerivationPathComponents;
        var value: u64 = 0;
        var digits: usize = 0;
        while (pos < path.len and path[pos] >= '0' and path[pos] <= '9') : (pos += 1) {
            digits += 1;
            value = value * 10 + (path[pos] - '0');
            if (value > std.math.maxInt(HardenedIndex)) return error.InvalidDerivationPath;
        }
        if (digits == 0) return error.InvalidDerivationPath;
        if (pos >= path.len or path[pos] != '\'') return error.NonHardenedDerivationPath;
        pos += 1;
        parsed.components[count] = @intCast(value);
        count += 1;
        if (pos == path.len) break;
        if (path[pos] != '/') return error.InvalidDerivationPath;
        pos += 1;
        if (pos == path.len) return error.InvalidDerivationPath;
    }
    parsed.len = count;
    return parsed;
}

pub fn writeDerivationPath(path: DerivationPath, out: []u8) Error![]const u8 {
    var pos: usize = 0;
    try appendByte('m', out, &pos);
    for (path.components) |component| {
        try appendByte('/', out, &pos);
        const written = std.fmt.bufPrint(out[pos..], "{}", .{component}) catch |err| switch (err) {
            error.NoSpaceLeft => return error.OutputTooSmall,
        };
        pos += written.len;
        try appendByte('\'', out, &pos);
    }
    return out[0..pos];
}

pub fn deriveSeedFromBip39Seed(seed: *const Bip39Seed, path: DerivationPath) Error!Seed {
    var digest: [HmacSha512.mac_length]u8 = undefined;
    HmacSha512.create(&digest, seed, "ed25519 seed");
    var secret_seed: Seed = digest[0..keypair.SEED_BYTES].*;
    var chain_code: [32]u8 = digest[32..64].*;

    for (path.components) |component| {
        var data: [1 + keypair.SEED_BYTES + 4]u8 = undefined;
        data[0] = 0;
        @memcpy(data[1..33], &secret_seed);
        std.mem.writeInt(u32, data[33..37], @as(u32, component) | 0x80000000, .big);
        HmacSha512.create(&digest, &data, &chain_code);
        secret_seed = digest[0..keypair.SEED_BYTES].*;
        chain_code = digest[32..64].*;
    }

    return secret_seed;
}

pub fn deriveKeypairFromMnemonic(
    mnemonic: []const u8,
    passphrase: []const u8,
    path: DerivationPath,
) (Error || std.crypto.errors.WeakParametersError || std.crypto.errors.OutputTooLongError || anyerror)!Keypair {
    var seed: Bip39Seed = undefined;
    try mnemonicToSeed(mnemonic, passphrase, &seed);
    const secret_seed = try deriveSeedFromBip39Seed(&seed, path);
    return Keypair.fromSeed(secret_seed);
}

pub fn writeEncryptedKeystoreEnvelope(
    keystore: EncryptedKeystore,
    out: []u8,
) Error![]const u8 {
    try keystore.validate();
    return std.fmt.bufPrint(
        out,
        "{{\"version\":{},\"publicKey\":\"{s}\",\"crypto\":{{\"cipher\":\"{s}\",\"kdf\":\"{s}\",\"nonce\":\"{s}\",\"salt\":\"{s}\",\"ciphertext\":\"{s}\"}}}}",
        .{
            keystore.version,
            keystore.public_key_base58,
            keystore.cipher.jsonName(),
            keystore.kdf.jsonName(),
            keystore.nonce_base64,
            keystore.salt_base64,
            keystore.ciphertext_base64,
        },
    ) catch |err| switch (err) {
        error.NoSpaceLeft => return error.OutputTooSmall,
    };
}

pub fn parseEncryptedKeystoreEnvelope(
    allocator: std.mem.Allocator,
    json: []const u8,
) !ParsedEncryptedKeystore {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    errdefer parsed.deinit();

    const root = try jsonObject(parsed.value);
    const version = try jsonU8Field(root, "version");
    const public_key_base58 = try jsonStringField(root, "publicKey");
    const crypto = try jsonObjectField(root, "crypto");
    const cipher = try parseKeystoreCipher(try jsonStringField(crypto, "cipher"));
    const kdf = try parseKeystoreKdf(try jsonStringField(crypto, "kdf"));
    const nonce_base64 = try jsonStringField(crypto, "nonce");
    const salt_base64 = try jsonStringField(crypto, "salt");
    const ciphertext_base64 = try jsonStringField(crypto, "ciphertext");

    const keystore: EncryptedKeystore = .{
        .version = version,
        .public_key_base58 = public_key_base58,
        .cipher = cipher,
        .kdf = kdf,
        .nonce_base64 = nonce_base64,
        .salt_base64 = salt_base64,
        .ciphertext_base64 = ciphertext_base64,
    };
    try keystore.validate();
    return .{
        .parsed = parsed,
        .keystore = keystore,
    };
}

pub fn keystoreNonceLen(cipher: KeystoreCipher) usize {
    return switch (cipher) {
        .xchacha20_poly1305 => KEYSTORE_XCHACHA20_POLY1305_NONCE_BYTES,
        .aes_256_gcm => KEYSTORE_AES_256_GCM_NONCE_BYTES,
    };
}

pub fn encryptedKeystorePayloadLen(plaintext_len: usize) usize {
    return plaintext_len + KEYSTORE_TAG_BYTES;
}

pub fn deriveKeystoreKey(
    allocator: std.mem.Allocator,
    kdf: KeystoreKdf,
    config: KeystoreKdfConfig,
    passphrase: []const u8,
    salt: []const u8,
    out: *KeystoreKey,
) (Error || anyerror)!void {
    switch (kdf) {
        .scrypt => {
            const params = switch (config) {
                .scrypt => |params| params,
                else => return error.UnsupportedKeystoreKdf,
            };
            try std.crypto.pwhash.scrypt.kdf(allocator, out[0..], passphrase, salt, params);
        },
        .pbkdf2_sha256 => {
            const rounds = switch (config) {
                .pbkdf2_sha256 => |rounds| rounds,
                else => return error.UnsupportedKeystoreKdf,
            };
            try std.crypto.pwhash.pbkdf2(out[0..], passphrase, salt, rounds, HmacSha256);
        },
    }
}

pub fn encryptKeystorePayload(
    allocator: std.mem.Allocator,
    cipher: KeystoreCipher,
    kdf: KeystoreKdf,
    config: KeystoreKdfConfig,
    passphrase: []const u8,
    salt: []const u8,
    nonce: []const u8,
    plaintext: []const u8,
    associated_data: []const u8,
    out: []u8,
) (Error || anyerror)![]const u8 {
    const needed = encryptedKeystorePayloadLen(plaintext.len);
    if (out.len < needed) return error.OutputTooSmall;
    if (nonce.len != keystoreNonceLen(cipher)) return error.InvalidKeystore;

    var key: KeystoreKey = undefined;
    try deriveKeystoreKey(allocator, kdf, config, passphrase, salt, &key);
    defer std.crypto.secureZero(u8, &key);

    const ciphertext = out[0..plaintext.len];
    const tag = out[plaintext.len..needed][0..KEYSTORE_TAG_BYTES];
    switch (cipher) {
        .xchacha20_poly1305 => XChaCha20Poly1305.encrypt(
            ciphertext,
            tag,
            plaintext,
            associated_data,
            nonce[0..KEYSTORE_XCHACHA20_POLY1305_NONCE_BYTES].*,
            key,
        ),
        .aes_256_gcm => Aes256Gcm.encrypt(
            ciphertext,
            tag,
            plaintext,
            associated_data,
            nonce[0..KEYSTORE_AES_256_GCM_NONCE_BYTES].*,
            key,
        ),
    }
    return out[0..needed];
}

pub fn decryptKeystorePayload(
    allocator: std.mem.Allocator,
    cipher: KeystoreCipher,
    kdf: KeystoreKdf,
    config: KeystoreKdfConfig,
    passphrase: []const u8,
    salt: []const u8,
    nonce: []const u8,
    ciphertext_and_tag: []const u8,
    associated_data: []const u8,
    out: []u8,
) (Error || anyerror)![]const u8 {
    if (ciphertext_and_tag.len < KEYSTORE_TAG_BYTES) return error.InvalidKeystore;
    if (nonce.len != keystoreNonceLen(cipher)) return error.InvalidKeystore;
    const ciphertext_len = ciphertext_and_tag.len - KEYSTORE_TAG_BYTES;
    if (out.len < ciphertext_len) return error.OutputTooSmall;

    var key: KeystoreKey = undefined;
    try deriveKeystoreKey(allocator, kdf, config, passphrase, salt, &key);
    defer std.crypto.secureZero(u8, &key);

    const ciphertext = ciphertext_and_tag[0..ciphertext_len];
    const tag = ciphertext_and_tag[ciphertext_len..][0..KEYSTORE_TAG_BYTES].*;
    const plaintext = out[0..ciphertext_len];
    switch (cipher) {
        .xchacha20_poly1305 => XChaCha20Poly1305.decrypt(
            plaintext,
            ciphertext,
            tag,
            associated_data,
            nonce[0..KEYSTORE_XCHACHA20_POLY1305_NONCE_BYTES].*,
            key,
        ) catch return error.AuthenticationFailed,
        .aes_256_gcm => Aes256Gcm.decrypt(
            plaintext,
            ciphertext,
            tag,
            associated_data,
            nonce[0..KEYSTORE_AES_256_GCM_NONCE_BYTES].*,
            key,
        ) catch return error.AuthenticationFailed,
    }
    return plaintext;
}

pub fn writeEncryptedKeystoreEnvelopeFromRaw(
    version: u8,
    public_key_base58: []const u8,
    cipher: KeystoreCipher,
    kdf: KeystoreKdf,
    nonce: []const u8,
    salt: []const u8,
    ciphertext_and_tag: []const u8,
    nonce_base64_out: []u8,
    salt_base64_out: []u8,
    ciphertext_base64_out: []u8,
    json_out: []u8,
) Error![]const u8 {
    const nonce_base64 = try encodeBase64(nonce, nonce_base64_out);
    const salt_base64 = try encodeBase64(salt, salt_base64_out);
    const ciphertext_base64 = try encodeBase64(ciphertext_and_tag, ciphertext_base64_out);
    return writeEncryptedKeystoreEnvelope(.{
        .version = version,
        .public_key_base58 = public_key_base58,
        .cipher = cipher,
        .kdf = kdf,
        .nonce_base64 = nonce_base64,
        .salt_base64 = salt_base64,
        .ciphertext_base64 = ciphertext_base64,
    }, json_out);
}

const Parser = struct {
    input: []const u8,
    pos: usize = 0,

    fn eof(self: Parser) bool {
        return self.pos == self.input.len;
    }

    fn peek(self: Parser) ?u8 {
        if (self.eof()) return null;
        return self.input[self.pos];
    }

    fn next(self: *Parser) ?u8 {
        const byte = self.peek() orelse return null;
        self.pos += 1;
        return byte;
    }

    fn skipWhitespace(self: *Parser) Error!void {
        while (self.peek()) |byte| {
            switch (byte) {
                ' ', '\n', '\r', '\t' => self.pos += 1,
                else => return,
            }
        }
    }

    fn expect(self: *Parser, expected: u8) Error!void {
        const actual = self.next() orelse return error.InvalidJson;
        if (actual != expected) return error.InvalidJson;
    }

    fn parseByte(self: *Parser) Error!u8 {
        var value: u16 = 0;
        var digits: usize = 0;

        while (self.peek()) |byte| {
            if (byte < '0' or byte > '9') break;
            digits += 1;
            value = value * 10 + (byte - '0');
            if (value > std.math.maxInt(u8)) return error.InvalidSecretKeyByte;
            self.pos += 1;
        }

        if (digits == 0) return error.InvalidJson;
        return @intCast(value);
    }
};

fn appendByte(byte: u8, out: []u8, pos: *usize) Error!void {
    if (pos.* >= out.len) return error.OutputTooSmall;
    out[pos.*] = byte;
    pos.* += 1;
}

fn encodeBase64(input: []const u8, out: []u8) Error![]const u8 {
    const encoded_len = std.base64.standard.Encoder.calcSize(input.len);
    if (out.len < encoded_len) return error.OutputTooSmall;
    return std.base64.standard.Encoder.encode(out[0..encoded_len], input);
}

fn validateMnemonicPhrase(mnemonic: []const u8) Error!void {
    if (mnemonic.len == 0) return error.InvalidMnemonic;
    var word_count: usize = 0;
    var in_word = false;
    var prev_space = false;
    for (mnemonic) |byte| {
        switch (byte) {
            'a'...'z' => {
                if (!in_word) {
                    word_count += 1;
                    in_word = true;
                }
                prev_space = false;
            },
            ' ' => {
                if (!in_word or prev_space) return error.InvalidMnemonic;
                in_word = false;
                prev_space = true;
            },
            else => return error.InvalidMnemonic,
        }
    }
    if (!in_word or prev_space) return error.InvalidMnemonic;
    switch (word_count) {
        12, 15, 18, 21, 24 => {},
        else => return error.InvalidMnemonic,
    }
}

fn resolveMnemonicWords(
    mnemonic: []const u8,
    resolver: WordlistResolver,
    indexes: *[BIP39_MAX_WORDS]u16,
) Error!usize {
    try validateMnemonicPhrase(mnemonic);
    var count: usize = 0;
    var word_start: usize = 0;
    for (mnemonic, 0..) |byte, pos| {
        if (byte != ' ') continue;
        indexes[count] = try resolver.indexOf(mnemonic[word_start..pos]);
        count += 1;
        word_start = pos + 1;
    }
    indexes[count] = try resolver.indexOf(mnemonic[word_start..]);
    count += 1;
    return count;
}

fn readMnemonicBit(indexes: []const u16, bit_index: usize) bool {
    const word_index = bit_index / 11;
    const bit_in_word = bit_index % 11;
    return ((indexes[word_index] >> @intCast(10 - bit_in_word)) & 1) != 0;
}

fn validateTextField(value: []const u8) Error!void {
    for (value) |byte| {
        if (byte < 0x20 or byte == '"' or byte == '\\') return error.InvalidKeystore;
    }
}

fn parseKeystoreCipher(name: []const u8) Error!KeystoreCipher {
    if (std.mem.eql(u8, name, KeystoreCipher.xchacha20_poly1305.jsonName())) return .xchacha20_poly1305;
    if (std.mem.eql(u8, name, KeystoreCipher.aes_256_gcm.jsonName())) return .aes_256_gcm;
    return error.UnsupportedKeystoreCipher;
}

fn parseKeystoreKdf(name: []const u8) Error!KeystoreKdf {
    if (std.mem.eql(u8, name, KeystoreKdf.scrypt.jsonName())) return .scrypt;
    if (std.mem.eql(u8, name, KeystoreKdf.pbkdf2_sha256.jsonName())) return .pbkdf2_sha256;
    return error.UnsupportedKeystoreKdf;
}

fn jsonObject(value: std.json.Value) Error!std.json.ObjectMap {
    return switch (value) {
        .object => |object| object,
        else => error.InvalidKeystore,
    };
}

fn jsonObjectField(object: std.json.ObjectMap, name: []const u8) Error!std.json.ObjectMap {
    const value = object.get(name) orelse return error.InvalidKeystore;
    return jsonObject(value);
}

fn jsonStringField(object: std.json.ObjectMap, name: []const u8) Error![]const u8 {
    const value = object.get(name) orelse return error.InvalidKeystore;
    return switch (value) {
        .string => |string| string,
        else => error.InvalidKeystore,
    };
}

fn jsonU8Field(object: std.json.ObjectMap, name: []const u8) Error!u8 {
    const value = object.get(name) orelse return error.InvalidKeystore;
    const integer = switch (value) {
        .integer => |integer| integer,
        else => return error.InvalidKeystore,
    };
    if (integer < 0 or integer > std.math.maxInt(u8)) return error.InvalidKeystore;
    return @intCast(integer);
}

test "parseSecretKeyJson accepts Solana CLI keypair arrays" {
    const json =
        \\[
        \\  128,82,3,3,118,212,113,18,190,127,115,237,122,1,146,147,
        \\  221,18,173,145,11,101,68,85,121,180,102,125,115,222,22,6,
        \\  45,111,116,85,217,123,74,58,16,215,41,57,9,209,164,242,
        \\  5,140,185,163,112,228,63,168,21,75,178,128,219,131,144,131
        \\]
    ;

    const secret = try parseSecretKeyJson(json);
    try std.testing.expectEqual(@as(u8, 128), secret[0]);
    try std.testing.expectEqual(@as(u8, 131), secret[63]);

    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings(
        try std.fmt.bufPrint(&buf, "{X}", .{&secret}),
        "8052030376D47112BE7F73ED7A019293DD12AD910B65445579B4667D73DE16062D6F7455D97B4A3A10D7293909D1A4F2058CB9A370E43FA8154BB280DB839083",
    );
}

test "writeSecretKeyJson emits compact canonical JSON" {
    const kp = try keypair.Keypair.fromSeed(.{7} ** keypair.SEED_BYTES);
    const secret = kp.secretKeyBytes();
    var out: [256]u8 = undefined;

    const json = try writeSecretKeyJson(&secret, &out);
    const parsed = try parseSecretKeyJson(json);
    try std.testing.expectEqualSlices(u8, &secret, &parsed);
    try std.testing.expect(json[0] == '[');
    try std.testing.expect(json[json.len - 1] == ']');
}

test "parser rejects malformed keypair JSON" {
    try std.testing.expectError(error.InvalidSecretKeyLength, parseSecretKeyJson("[]"));
    try std.testing.expectError(error.InvalidSecretKeyByte, parseSecretKeyJson("[256]"));
    try std.testing.expectError(error.InvalidJson, parseSecretKeyJson("[1,,2]"));

    const short = "[1,2,3]";
    try std.testing.expectError(error.InvalidSecretKeyLength, parseSecretKeyJson(short));
}

test "keypairToJson round-trips through parseKeypairJson" {
    const kp = try keypair.Keypair.fromSeed(.{9} ** keypair.SEED_BYTES);
    var out: [256]u8 = undefined;
    const json = try keypairToJson(kp, &out);
    const recovered = try parseKeypairJson(json);

    try std.testing.expectEqualSlices(u8, &kp.publicKey(), &recovered.publicKey());
    try std.testing.expectEqualSlices(u8, &kp.secretKeyBytes(), &recovered.secretKeyBytes());
}

test "mnemonicToSeed matches BIP39 PBKDF2 test vector" {
    const mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    var seed: Bip39Seed = undefined;
    try mnemonicToSeed(mnemonic, "TREZOR", &seed);

    var buf: [BIP39_SEED_BYTES * 2]u8 = undefined;
    try std.testing.expectEqualStrings(
        "C55257C360C07C72029AEBC1B53C05ED0362ADA38EAD3E3E9EFA3708E53495531F09A6987599D18264C1E1C92F2CF141630C7A3C4AB7C81B2F001698E7463B04",
        try std.fmt.bufPrint(&buf, "{X}", .{&seed}),
    );
}

const TestBip39Wordlist = struct {
    fn indexOf(context: *anyopaque, word: []const u8) Error!u16 {
        _ = context;
        if (std.mem.eql(u8, word, "abandon")) return 0;
        if (std.mem.eql(u8, word, "about")) return 3;
        return error.InvalidMnemonicWord;
    }
};

fn testBip39WordlistResolver() WordlistResolver {
    const Holder = struct {
        var context: u8 = 0;
    };
    return .{
        .context = &Holder.context,
        .indexFn = TestBip39Wordlist.indexOf,
    };
}

test "mnemonicToEntropy validates BIP39 checksum with caller wordlist" {
    const mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    var entropy: [BIP39_MAX_ENTROPY_BYTES]u8 = undefined;
    const result = try mnemonicToEntropy(mnemonic, testBip39WordlistResolver(), &entropy);

    try std.testing.expectEqual(@as(usize, 16), result.len);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 16), result);
    try validateMnemonicChecksum(mnemonic, testBip39WordlistResolver());
    try std.testing.expectEqual(@as(usize, 16), try mnemonicWordCountToEntropyBytes(12));
    try std.testing.expectEqual(@as(usize, 32), try mnemonicWordCountToEntropyBytes(24));
}

test "mnemonicToEntropy rejects checksum and unknown words" {
    const wrong_checksum = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon";
    var entropy: [BIP39_MAX_ENTROPY_BYTES]u8 = undefined;
    try std.testing.expectError(
        error.InvalidMnemonicChecksum,
        mnemonicToEntropy(wrong_checksum, testBip39WordlistResolver(), &entropy),
    );

    const unknown_word = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon zoo";
    try std.testing.expectError(
        error.InvalidMnemonicWord,
        mnemonicToEntropy(unknown_word, testBip39WordlistResolver(), &entropy),
    );
    try std.testing.expectError(error.InvalidMnemonic, mnemonicWordCountToEntropyBytes(13));
    try std.testing.expectError(
        error.OutputTooSmall,
        mnemonicToEntropy(
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
            testBip39WordlistResolver(),
            entropy[0..15],
        ),
    );
}

test "derivation path parses writes and rejects unsafe paths" {
    const parsed = try parseDerivationPath("m/44'/501'/7'/0'");
    const path = parsed.path();
    try std.testing.expectEqual(@as(usize, 4), path.components.len);
    try std.testing.expectEqual(@as(HardenedIndex, 44), path.components[0]);
    try std.testing.expectEqual(@as(HardenedIndex, 501), path.components[1]);
    try std.testing.expectEqual(@as(HardenedIndex, 7), path.components[2]);
    try std.testing.expectEqual(@as(HardenedIndex, 0), path.components[3]);

    var out: [32]u8 = undefined;
    try std.testing.expectEqualStrings("m/44'/501'/7'/0'", try writeDerivationPath(path, &out));
    try std.testing.expectError(error.NonHardenedDerivationPath, parseDerivationPath("m/44/501'"));
    try std.testing.expectError(error.InvalidDerivationPath, parseDerivationPath("n/44'"));
}

test "deriveKeypairFromMnemonic uses Solana hardened derivation paths" {
    const mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    const first = try deriveKeypairFromMnemonic(mnemonic, "", DEFAULT_SOLANA_DERIVATION_PATH);
    const parsed_other = try parseDerivationPath("m/44'/501'/1'/0'");
    const other_path = parsed_other.path();
    const second = try deriveKeypairFromMnemonic(mnemonic, "", other_path);

    try std.testing.expect(!std.mem.eql(u8, &first.publicKey(), &second.publicKey()));
    const sig = try first.sign("wallet-message");
    const pubkey = first.publicKey();
    try keypair.verify(sig, "wallet-message", &pubkey);
}

test "wallet adapter signs with keypair-backed adapter" {
    var wallet: KeypairWallet = .{ .keypair = try keypair.Keypair.fromSeed(.{5} ** keypair.SEED_BYTES) };
    const adapter = wallet.adapter();
    const signature = try adapter.signMessage("adapter-message");
    const pubkey = adapter.publicKey();
    try keypair.verify(signature, "adapter-message", &pubkey);
}

test "encrypted keystore envelope validates and writes metadata" {
    const keystore: EncryptedKeystore = .{
        .version = 1,
        .public_key_base58 = "11111111111111111111111111111111",
        .cipher = .xchacha20_poly1305,
        .kdf = .scrypt,
        .nonce_base64 = "bm9uY2U=",
        .salt_base64 = "c2FsdA==",
        .ciphertext_base64 = "Y2lwaGVydGV4dA==",
    };
    var out: [256]u8 = undefined;
    const json = try writeEncryptedKeystoreEnvelope(keystore, &out);
    try std.testing.expectEqualStrings(
        "{\"version\":1,\"publicKey\":\"11111111111111111111111111111111\",\"crypto\":{\"cipher\":\"xchacha20-poly1305\",\"kdf\":\"scrypt\",\"nonce\":\"bm9uY2U=\",\"salt\":\"c2FsdA==\",\"ciphertext\":\"Y2lwaGVydGV4dA==\"}}",
        json,
    );

    try std.testing.expectError(error.InvalidKeystore, (EncryptedKeystore{
        .version = 0,
        .public_key_base58 = "",
        .cipher = .aes_256_gcm,
        .kdf = .pbkdf2_sha256,
        .nonce_base64 = "",
        .salt_base64 = "",
        .ciphertext_base64 = "",
    }).validate());
}

test "parseEncryptedKeystoreEnvelope reads metadata JSON" {
    const allocator = std.testing.allocator;
    const json =
        \\{"version":1,"publicKey":"11111111111111111111111111111111","crypto":{"cipher":"aes-256-gcm","kdf":"pbkdf2-sha256","nonce":"MTIzNDU2Nzg5MDEy","salt":"c2FsdA==","ciphertext":"Y2lwaGVydGV4dC1hbmQtdGFn"}}
    ;

    var parsed = try parseEncryptedKeystoreEnvelope(allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u8, 1), parsed.keystore.version);
    try std.testing.expectEqualStrings("11111111111111111111111111111111", parsed.keystore.public_key_base58);
    try std.testing.expectEqual(KeystoreCipher.aes_256_gcm, parsed.keystore.cipher);
    try std.testing.expectEqual(KeystoreKdf.pbkdf2_sha256, parsed.keystore.kdf);
    try std.testing.expectEqualStrings("MTIzNDU2Nzg5MDEy", parsed.keystore.nonce_base64);
    try std.testing.expectEqualStrings("c2FsdA==", parsed.keystore.salt_base64);
    try std.testing.expectEqualStrings("Y2lwaGVydGV4dC1hbmQtdGFn", parsed.keystore.ciphertext_base64);

    try std.testing.expectError(
        error.UnsupportedKeystoreCipher,
        parseEncryptedKeystoreEnvelope(
            allocator,
            "{\"version\":1,\"publicKey\":\"11111111111111111111111111111111\",\"crypto\":{\"cipher\":\"bad\",\"kdf\":\"pbkdf2-sha256\",\"nonce\":\"x\",\"salt\":\"y\",\"ciphertext\":\"z\"}}",
        ),
    );
    try std.testing.expectError(
        error.InvalidKeystore,
        parseEncryptedKeystoreEnvelope(
            allocator,
            "{\"version\":0,\"publicKey\":\"11111111111111111111111111111111\",\"crypto\":{\"cipher\":\"aes-256-gcm\",\"kdf\":\"pbkdf2-sha256\",\"nonce\":\"x\",\"salt\":\"y\",\"ciphertext\":\"z\"}}",
        ),
    );
}

test "keystore payload encrypts and decrypts with XChaCha20-Poly1305 and PBKDF2" {
    const allocator = std.testing.allocator;
    const salt = "wallet-salt-0001";
    const nonce: [KEYSTORE_XCHACHA20_POLY1305_NONCE_BYTES]u8 = .{7} ** KEYSTORE_XCHACHA20_POLY1305_NONCE_BYTES;
    const plaintext = "secret-key-json";
    const aad = "11111111111111111111111111111111";

    var payload: [encryptedKeystorePayloadLen(plaintext.len)]u8 = undefined;
    var encrypted = try encryptKeystorePayload(
        allocator,
        .xchacha20_poly1305,
        .pbkdf2_sha256,
        .{ .pbkdf2_sha256 = 2_048 },
        "passphrase",
        salt,
        &nonce,
        plaintext,
        aad,
        &payload,
    );
    try std.testing.expectEqual(@as(usize, plaintext.len + KEYSTORE_TAG_BYTES), encrypted.len);
    try std.testing.expect(!std.mem.eql(u8, plaintext, encrypted[0..plaintext.len]));

    var decrypted: [plaintext.len]u8 = undefined;
    try std.testing.expectEqualStrings(
        plaintext,
        try decryptKeystorePayload(
            allocator,
            .xchacha20_poly1305,
            .pbkdf2_sha256,
            .{ .pbkdf2_sha256 = 2_048 },
            "passphrase",
            salt,
            &nonce,
            encrypted,
            aad,
            &decrypted,
        ),
    );

    payload[0] ^= 1;
    try std.testing.expectError(
        error.AuthenticationFailed,
        decryptKeystorePayload(
            allocator,
            .xchacha20_poly1305,
            .pbkdf2_sha256,
            .{ .pbkdf2_sha256 = 2_048 },
            "passphrase",
            salt,
            &nonce,
            encrypted,
            aad,
            &decrypted,
        ),
    );
}

test "keystore payload encrypts and decrypts with AES-256-GCM and scrypt" {
    const allocator = std.testing.allocator;
    const salt = "wallet-salt-0002";
    const nonce: [KEYSTORE_AES_256_GCM_NONCE_BYTES]u8 = .{9} ** KEYSTORE_AES_256_GCM_NONCE_BYTES;
    const plaintext = "another-secret";
    var payload: [encryptedKeystorePayloadLen(plaintext.len)]u8 = undefined;

    const encrypted = try encryptKeystorePayload(
        allocator,
        .aes_256_gcm,
        .scrypt,
        .{ .scrypt = .{ .ln = 1, .r = 1, .p = 1 } },
        "passphrase",
        salt,
        &nonce,
        plaintext,
        "",
        &payload,
    );
    var decrypted: [plaintext.len]u8 = undefined;
    try std.testing.expectEqualStrings(
        plaintext,
        try decryptKeystorePayload(
            allocator,
            .aes_256_gcm,
            .scrypt,
            .{ .scrypt = .{ .ln = 1, .r = 1, .p = 1 } },
            "passphrase",
            salt,
            &nonce,
            encrypted,
            "",
            &decrypted,
        ),
    );

    try std.testing.expectError(
        error.InvalidKeystore,
        encryptKeystorePayload(
            allocator,
            .aes_256_gcm,
            .scrypt,
            .{ .scrypt = .{ .ln = 1, .r = 1, .p = 1 } },
            "passphrase",
            salt,
            nonce[0..11],
            plaintext,
            "",
            &payload,
        ),
    );
}

test "writeEncryptedKeystoreEnvelopeFromRaw base64 encodes encrypted payload" {
    const nonce = "123456789012";
    const salt = "salt";
    const payload = "ciphertext-and-tag";
    var nonce_b64: [32]u8 = undefined;
    var salt_b64: [16]u8 = undefined;
    var payload_b64: [64]u8 = undefined;
    var json: [256]u8 = undefined;

    const written = try writeEncryptedKeystoreEnvelopeFromRaw(
        1,
        "11111111111111111111111111111111",
        .aes_256_gcm,
        .pbkdf2_sha256,
        nonce,
        salt,
        payload,
        &nonce_b64,
        &salt_b64,
        &payload_b64,
        &json,
    );

    try std.testing.expectEqualStrings(
        "{\"version\":1,\"publicKey\":\"11111111111111111111111111111111\",\"crypto\":{\"cipher\":\"aes-256-gcm\",\"kdf\":\"pbkdf2-sha256\",\"nonce\":\"MTIzNDU2Nzg5MDEy\",\"salt\":\"c2FsdA==\",\"ciphertext\":\"Y2lwaGVydGV4dC1hbmQtdGFn\"}}",
        written,
    );
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "parseSecretKeyJson"));
    try std.testing.expect(@hasDecl(@This(), "writeSecretKeyJson"));
    try std.testing.expect(@hasDecl(@This(), "parseKeypairJson"));
    try std.testing.expect(@hasDecl(@This(), "mnemonicToSeed"));
    try std.testing.expect(@hasDecl(@This(), "mnemonicToEntropy"));
    try std.testing.expect(@hasDecl(@This(), "validateMnemonicChecksum"));
    try std.testing.expect(@hasDecl(@This(), "WordlistResolver"));
    try std.testing.expect(@hasDecl(@This(), "deriveKeypairFromMnemonic"));
    try std.testing.expect(@hasDecl(@This(), "WalletAdapter"));
    try std.testing.expect(@hasDecl(@This(), "EncryptedKeystore"));
    try std.testing.expect(@hasDecl(@This(), "parseEncryptedKeystoreEnvelope"));
    try std.testing.expect(@hasDecl(@This(), "encryptKeystorePayload"));
    try std.testing.expect(@hasDecl(@This(), "decryptKeystorePayload"));
    try std.testing.expect(@hasDecl(@This(), "writeEncryptedKeystoreEnvelopeFromRaw"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "transaction"));
}
