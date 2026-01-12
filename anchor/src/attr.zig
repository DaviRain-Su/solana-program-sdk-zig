//! Zig implementation of Anchor account attribute DSL
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/syn/src/codegen/accounts/constraints.rs
//!
//! Provides a lightweight attribute list used to configure Account wrappers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const seeds_mod = @import("seeds.zig");
const has_one_mod = @import("has_one.zig");
const realloc_mod = @import("realloc.zig");
const constraints_mod = @import("constraints.zig");

const PublicKey = sol.PublicKey;
const SeedSpec = seeds_mod.SeedSpec;
const HasOneSpec = has_one_mod.HasOneSpec;
const ReallocConfig = realloc_mod.ReallocConfig;
const ConstraintExpr = constraints_mod.ConstraintExpr;

pub const Attr = union(enum) {
    mut: void,
    signer: void,
    seeds: []const SeedSpec,
    bump: void,
    bump_field: []const u8,
    seeds_program: SeedSpec,
    init_if_needed: void,
    associated_token_mint: []const u8,
    associated_token_authority: []const u8,
    associated_token_token_program: []const u8,
    token_mint: []const u8,
    token_authority: []const u8,
    init: void,
    payer: []const u8,
    close: []const u8,
    realloc: ReallocConfig,
    has_one: []const HasOneSpec,
    rent_exempt: void,
    constraint: ConstraintExpr,
    owner: PublicKey,
    address: PublicKey,
    executable: void,
    space: usize,
};

/// Macro-style account attribute configuration.
///
/// This config mirrors common `#[account(...)]` fields and is intended
/// to be converted into an Attr list via `anchor.attr.account(...)`.
pub const AccountAttrConfig = struct {
    mut: bool = false,
    signer: bool = false,
    seeds: ?[]const SeedSpec = null,
    bump: bool = false,
    bump_field: ?[]const u8 = null,
    seeds_program: ?SeedSpec = null,
    init_if_needed: bool = false,
    associated_token_mint: ?[]const u8 = null,
    associated_token_authority: ?[]const u8 = null,
    associated_token_token_program: ?[]const u8 = null,
    token_mint: ?[]const u8 = null,
    token_authority: ?[]const u8 = null,
    init: bool = false,
    payer: ?[]const u8 = null,
    close: ?[]const u8 = null,
    realloc: ?ReallocConfig = null,
    has_one: ?[]const HasOneSpec = null,
    has_one_fields: ?[]const []const u8 = null,
    rent_exempt: bool = false,
    constraint: ?[]const u8 = null,
    owner: ?PublicKey = null,
    address: ?PublicKey = null,
    executable: bool = false,
    space: ?usize = null,
};

fn hasOneSpecsFromFields(comptime fields: []const []const u8) []const HasOneSpec {
    comptime var specs: [fields.len]HasOneSpec = undefined;
    inline for (fields, 0..) |field_name, index| {
        specs[index] = .{ .field = field_name, .target = field_name };
    }
    return specs[0..];
}

fn countAccountAttrs(comptime config: AccountAttrConfig) usize {
    comptime var count: usize = 0;
    if (config.mut) count += 1;
    if (config.signer) count += 1;
    if (config.seeds != null) count += 1;
    if (config.bump) count += 1;
    if (config.bump_field != null) count += 1;
    if (config.seeds_program != null) count += 1;
    if (config.init_if_needed) count += 1;
    if (config.associated_token_mint != null) count += 1;
    if (config.associated_token_authority != null) count += 1;
    if (config.associated_token_token_program != null) count += 1;
    if (config.token_mint != null) count += 1;
    if (config.token_authority != null) count += 1;
    if (config.init) count += 1;
    if (config.payer != null) count += 1;
    if (config.close != null) count += 1;
    if (config.realloc != null) count += 1;
    if (config.has_one != null) count += 1;
    if (config.has_one_fields != null) count += 1;
    if (config.rent_exempt) count += 1;
    if (config.constraint != null) count += 1;
    if (config.owner != null) count += 1;
    if (config.address != null) count += 1;
    if (config.executable) count += 1;
    if (config.space != null) count += 1;
    return count;
}

pub const attr = struct {
    pub fn mut() Attr {
        return .{ .mut = {} };
    }

    pub fn signer() Attr {
        return .{ .signer = {} };
    }

    pub fn seeds(comptime value: []const SeedSpec) Attr {
        seeds_mod.validateSeeds(value);
        return .{ .seeds = value };
    }

    pub fn bump() Attr {
        return .{ .bump = {} };
    }

    pub fn bumpField(comptime value: []const u8) Attr {
        return .{ .bump_field = value };
    }

    pub fn seedsProgram(comptime value: SeedSpec) Attr {
        return .{ .seeds_program = value };
    }

    pub fn initIfNeeded() Attr {
        return .{ .init_if_needed = {} };
    }

    pub fn associatedTokenMint(comptime value: []const u8) Attr {
        return .{ .associated_token_mint = value };
    }

    pub fn associatedTokenAuthority(comptime value: []const u8) Attr {
        return .{ .associated_token_authority = value };
    }

    pub fn associatedTokenTokenProgram(comptime value: []const u8) Attr {
        return .{ .associated_token_token_program = value };
    }

    pub fn tokenMint(comptime value: []const u8) Attr {
        return .{ .token_mint = value };
    }

    pub fn tokenAuthority(comptime value: []const u8) Attr {
        return .{ .token_authority = value };
    }

    pub fn init() Attr {
        return .{ .init = {} };
    }

    pub fn payer(comptime value: []const u8) Attr {
        return .{ .payer = value };
    }

    pub fn close(comptime value: []const u8) Attr {
        return .{ .close = value };
    }

    pub fn realloc(comptime config: ReallocConfig) Attr {
        return .{ .realloc = config };
    }

    pub fn hasOne(comptime value: []const HasOneSpec) Attr {
        return .{ .has_one = value };
    }

    pub fn rentExempt() Attr {
        return .{ .rent_exempt = {} };
    }

    pub fn constraint(comptime expr: []const u8) Attr {
        return .{ .constraint = constraints_mod.constraint(expr) };
    }

    pub fn owner(value: PublicKey) Attr {
        return .{ .owner = value };
    }

    pub fn address(value: PublicKey) Attr {
        return .{ .address = value };
    }

    pub fn executable() Attr {
        return .{ .executable = {} };
    }

    pub fn space(value: usize) Attr {
        return .{ .space = value };
    }

    pub fn account(comptime config: AccountAttrConfig) []const Attr {
        if (config.has_one != null and config.has_one_fields != null) {
            @compileError("has_one and has_one_fields are mutually exclusive");
        }

        const attrs = comptime buildAccountAttrArray(config);
        return attrs[0..];
    }

    /// Parse `#[account(...)]`-style attributes into an Attr list.
    ///
    /// Supported keys (subset):
    /// - flags: mut, signer, init, rent_exempt, executable, bump
    /// - key/value: payer, close, constraint, space, owner, address
    /// - seeds: seeds = [ ... ]
    /// - bump field: bump = <field>
    /// - seeds program: seeds::program = <seed>
    /// - has_one: has_one = <field> or has_one = [a, b]
    /// - realloc: realloc = { payer = <field>, zero_init = true }
    pub fn parseAccount(comptime input: []const u8) []const Attr {
        return attr.account(parseAccountConfig(input));
    }
};

fn buildAccountAttrArray(comptime config: AccountAttrConfig) [countAccountAttrs(config)]Attr {
    const attr_count = comptime countAccountAttrs(config);
    comptime var attrs: [attr_count]Attr = undefined;
    comptime var index: usize = 0;

    if (config.mut) {
        attrs[index] = attr.mut();
        index += 1;
    }
    if (config.signer) {
        attrs[index] = attr.signer();
        index += 1;
    }
    if (config.seeds) |value| {
        attrs[index] = attr.seeds(value);
        index += 1;
    }
    if (config.bump) {
        attrs[index] = attr.bump();
        index += 1;
    }
    if (config.bump_field) |value| {
        attrs[index] = attr.bumpField(value);
        index += 1;
    }
    if (config.seeds_program) |value| {
        attrs[index] = attr.seedsProgram(value);
        index += 1;
    }
    if (config.init_if_needed) {
        attrs[index] = attr.initIfNeeded();
        index += 1;
    }
    if (config.associated_token_mint) |value| {
        attrs[index] = attr.associatedTokenMint(value);
        index += 1;
    }
    if (config.associated_token_authority) |value| {
        attrs[index] = attr.associatedTokenAuthority(value);
        index += 1;
    }
    if (config.associated_token_token_program) |value| {
        attrs[index] = attr.associatedTokenTokenProgram(value);
        index += 1;
    }
    if (config.token_mint) |value| {
        attrs[index] = attr.tokenMint(value);
        index += 1;
    }
    if (config.token_authority) |value| {
        attrs[index] = attr.tokenAuthority(value);
        index += 1;
    }
    if (config.init) {
        attrs[index] = attr.init();
        index += 1;
    }
    if (config.payer) |value| {
        attrs[index] = attr.payer(value);
        index += 1;
    }
    if (config.close) |value| {
        attrs[index] = attr.close(value);
        index += 1;
    }
    if (config.realloc) |value| {
        attrs[index] = attr.realloc(value);
        index += 1;
    }
    if (config.has_one) |value| {
        attrs[index] = attr.hasOne(value);
        index += 1;
    }
    if (config.has_one_fields) |value| {
        attrs[index] = attr.hasOne(hasOneSpecsFromFields(value));
        index += 1;
    }
    if (config.rent_exempt) {
        attrs[index] = attr.rentExempt();
        index += 1;
    }
    if (config.constraint) |value| {
        attrs[index] = attr.constraint(value);
        index += 1;
    }
    if (config.owner) |value| {
        attrs[index] = attr.owner(value);
        index += 1;
    }
    if (config.address) |value| {
        attrs[index] = attr.address(value);
        index += 1;
    }
    if (config.executable) {
        attrs[index] = attr.executable();
        index += 1;
    }
    if (config.space) |value| {
        attrs[index] = attr.space(value);
        index += 1;
    }

    return attrs;
}

const Parser = struct {
    input: []const u8,
    index: usize,

    fn init(comptime input: []const u8) Parser {
        return .{ .input = input, .index = 0 };
    }

    fn eof(self: *const Parser) bool {
        return self.index >= self.input.len;
    }

    fn peek(self: *const Parser) ?u8 {
        if (self.eof()) return null;
        return self.input[self.index];
    }

    fn skipWs(self: *Parser) void {
        while (self.peek()) |c| {
            if (c != ' ' and c != '\n' and c != '\t' and c != '\r') break;
            self.index += 1;
        }
    }

    fn consumeChar(self: *Parser, comptime expected: u8) bool {
        if (self.peek() == expected) {
            self.index += 1;
            return true;
        }
        return false;
    }

    fn expectChar(self: *Parser, comptime expected: u8) void {
        if (!self.consumeChar(expected)) {
            @compileError("attribute parse error: expected character");
        }
    }

    fn expectEof(self: *Parser) void {
        if (!self.eof()) {
            @compileError("attribute parse error: trailing input");
        }
    }

    fn consumeColonColon(self: *Parser) bool {
        if (self.index + 1 >= self.input.len) return false;
        if (self.input[self.index] == ':' and self.input[self.index + 1] == ':') {
            self.index += 2;
            return true;
        }
        return false;
    }

    fn isIdentChar(c: u8) bool {
        return std.ascii.isAlphabetic(c) or std.ascii.isDigit(c) or c == '_';
    }

    fn parseIdent(self: *Parser) []const u8 {
        const start = self.index;
        while (self.peek()) |c| {
            if (!isIdentChar(c)) break;
            self.index += 1;
        }
        if (self.index == start) {
            @compileError("attribute parse error: expected identifier");
        }
        return self.input[start..self.index];
    }

    fn parseStringLiteral(self: *Parser) []const u8 {
        self.expectChar('"');
        const start = self.index;
        while (self.peek()) |c| {
            if (c == '"') break;
            if (c == '\\') {
                @compileError("attribute parse error: string escapes not supported");
            }
            self.index += 1;
        }
        const end = self.index;
        self.expectChar('"');
        return self.input[start..end];
    }

    fn parseIdentOrString(self: *Parser) []const u8 {
        self.skipWs();
        if (self.peek() == '"') {
            return self.parseStringLiteral();
        }
        return self.parseIdent();
    }

    fn parseBool(self: *Parser) bool {
        const value = self.parseIdent();
        if (std.mem.eql(u8, value, "true")) return true;
        if (std.mem.eql(u8, value, "false")) return false;
        @compileError("attribute parse error: expected boolean");
    }

    fn parseInt(self: *Parser) usize {
        const start = self.index;
        while (self.peek()) |c| {
            if (!std.ascii.isDigit(c)) break;
            self.index += 1;
        }
        if (self.index == start) {
            @compileError("attribute parse error: expected integer");
        }
        return std.fmt.parseInt(usize, self.input[start..self.index], 10) catch {
            @compileError("attribute parse error: invalid integer");
        };
    }

    fn parseSeedSpec(self: *Parser) SeedSpec {
        self.skipWs();
        if (self.peek() == '"') {
            const lit = self.parseStringLiteral();
            return seeds_mod.seed(lit);
        }

        const ident = self.parseIdent();
        self.skipWs();
        if (!self.consumeChar('(')) {
            @compileError("attribute parse error: seed must be string literal or function form");
        }
        self.skipWs();
        const value = self.parseIdentOrString();
        self.skipWs();
        self.expectChar(')');

        if (std.mem.eql(u8, ident, "account")) {
            return seeds_mod.seedAccount(value);
        }
        if (std.mem.eql(u8, ident, "field") or std.mem.eql(u8, ident, "arg")) {
            return seeds_mod.seedField(value);
        }
        if (std.mem.eql(u8, ident, "bump")) {
            return seeds_mod.seedBump(value);
        }
        if (std.mem.eql(u8, ident, "const") or std.mem.eql(u8, ident, "literal")) {
            return seeds_mod.seed(value);
        }

        @compileError("attribute parse error: unknown seed function");
    }

    fn parseSeedsList(self: *Parser) []const SeedSpec {
        var seeds: [seeds_mod.MAX_SEEDS]SeedSpec = undefined;
        var count: usize = 0;

        self.expectChar('[');
        while (true) {
            self.skipWs();
            if (self.consumeChar(']')) break;
            if (count >= seeds.len) {
                @compileError("attribute parse error: too many seeds");
            }
            seeds[count] = self.parseSeedSpec();
            count += 1;
            self.skipWs();
            if (self.consumeChar(',')) continue;
            self.skipWs();
            self.expectChar(']');
            break;
        }
        return seeds[0..count];
    }

    fn parseHasOneFields(self: *Parser) []const []const u8 {
        var fields: [seeds_mod.MAX_SEEDS][]const u8 = undefined;
        var count: usize = 0;

        if (self.consumeChar('[')) {
            while (true) {
                self.skipWs();
                if (self.consumeChar(']')) break;
                if (count >= fields.len) {
                    @compileError("attribute parse error: too many has_one entries");
                }
                fields[count] = self.parseIdentOrString();
                count += 1;
                self.skipWs();
                if (self.consumeChar(',')) continue;
                self.skipWs();
                self.expectChar(']');
                break;
            }
            return fields[0..count];
        }

        fields[0] = self.parseIdentOrString();
        return fields[0..1];
    }

    fn parseRealloc(self: *Parser) ReallocConfig {
        var config: ReallocConfig = .{};
        self.expectChar('{');
        while (true) {
            self.skipWs();
            if (self.consumeChar('}')) break;
            const key = self.parseIdent();
            self.skipWs();
            self.expectChar('=');
            self.skipWs();
            if (std.mem.eql(u8, key, "payer")) {
                if (config.payer != null) {
                    @compileError("attribute parse error: realloc payer already set");
                }
                config.payer = self.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "zero_init")) {
                config.zero_init = self.parseBool();
            } else {
                @compileError("attribute parse error: unknown realloc field");
            }
            self.skipWs();
            if (self.consumeChar(',')) continue;
            self.skipWs();
            self.expectChar('}');
            break;
        }
        return config;
    }
};

fn parseAccountConfig(comptime input: []const u8) AccountAttrConfig {
    @setEvalBranchQuota(4000);
    comptime var parser = Parser.init(input);
    comptime var config: AccountAttrConfig = .{};

    parser.skipWs();
    if (parser.eof()) return config;

    while (true) {
        const ident = parser.parseIdent();
        var key = ident;
        parser.skipWs();
        if (std.mem.eql(u8, ident, "seeds") and parser.consumeColonColon()) {
            parser.skipWs();
            const sub = parser.parseIdent();
            if (!std.mem.eql(u8, sub, "program")) {
                @compileError("attribute parse error: expected seeds::program");
            }
            key = "seeds::program";
        } else if (std.mem.eql(u8, ident, "token") and parser.consumeColonColon()) {
            parser.skipWs();
            const sub = parser.parseIdent();
            if (std.mem.eql(u8, sub, "mint")) {
                key = "token::mint";
            } else if (std.mem.eql(u8, sub, "authority")) {
                key = "token::authority";
            } else {
                @compileError("attribute parse error: expected token::mint or token::authority");
            }
        } else if (std.mem.eql(u8, ident, "associated_token") and parser.consumeColonColon()) {
            parser.skipWs();
            const sub = parser.parseIdent();
            if (std.mem.eql(u8, sub, "mint")) {
                key = "associated_token::mint";
            } else if (std.mem.eql(u8, sub, "authority")) {
                key = "associated_token::authority";
            } else if (std.mem.eql(u8, sub, "token_program")) {
                key = "associated_token::token_program";
            } else {
                @compileError("attribute parse error: expected associated_token::mint/authority/token_program");
            }
        }

        parser.skipWs();
        if (parser.consumeChar('=')) {
            parser.skipWs();
            if (std.mem.eql(u8, key, "seeds")) {
                if (config.seeds != null) @compileError("seeds already set");
                config.seeds = parser.parseSeedsList();
            } else if (std.mem.eql(u8, key, "seeds::program")) {
                if (config.seeds_program != null) @compileError("seeds::program already set");
                config.seeds_program = parser.parseSeedSpec();
            } else if (std.mem.eql(u8, key, "bump")) {
                if (config.bump or config.bump_field != null) {
                    @compileError("bump already set");
                }
                config.bump_field = parser.parseIdentOrString();
                config.bump = true;
            } else if (std.mem.eql(u8, key, "token::mint")) {
                if (config.token_mint != null) @compileError("token::mint already set");
                config.token_mint = parser.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "token::authority")) {
                if (config.token_authority != null) @compileError("token::authority already set");
                config.token_authority = parser.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "associated_token::mint")) {
                if (config.associated_token_mint != null) @compileError("associated_token::mint already set");
                config.associated_token_mint = parser.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "associated_token::authority")) {
                if (config.associated_token_authority != null) @compileError("associated_token::authority already set");
                config.associated_token_authority = parser.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "associated_token::token_program")) {
                if (config.associated_token_token_program != null) {
                    @compileError("associated_token::token_program already set");
                }
                config.associated_token_token_program = parser.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "payer")) {
                if (config.payer != null) @compileError("payer already set");
                config.payer = parser.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "close")) {
                if (config.close != null) @compileError("close already set");
                config.close = parser.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "realloc")) {
                if (config.realloc != null) @compileError("realloc already set");
                config.realloc = parser.parseRealloc();
            } else if (std.mem.eql(u8, key, "has_one")) {
                if (config.has_one_fields != null or config.has_one != null) {
                    @compileError("has_one already set");
                }
                config.has_one_fields = parser.parseHasOneFields();
            } else if (std.mem.eql(u8, key, "constraint")) {
                if (config.constraint != null) @compileError("constraint already set");
                config.constraint = parser.parseStringLiteral();
            } else if (std.mem.eql(u8, key, "owner")) {
                if (config.owner != null) @compileError("owner already set");
                const key_str = parser.parseStringLiteral();
                config.owner = PublicKey.comptimeFromBase58(key_str);
            } else if (std.mem.eql(u8, key, "address")) {
                if (config.address != null) @compileError("address already set");
                const key_str = parser.parseStringLiteral();
                config.address = PublicKey.comptimeFromBase58(key_str);
            } else if (std.mem.eql(u8, key, "space")) {
                if (config.space != null) @compileError("space already set");
                config.space = parser.parseInt();
            } else {
                @compileError("attribute parse error: unsupported key/value attribute");
            }
        } else {
            if (std.mem.eql(u8, key, "mut")) {
                if (config.mut) @compileError("mut already set");
                config.mut = true;
            } else if (std.mem.eql(u8, key, "signer")) {
                if (config.signer) @compileError("signer already set");
                config.signer = true;
            } else if (std.mem.eql(u8, key, "init")) {
                if (config.init) @compileError("init already set");
                config.init = true;
            } else if (std.mem.eql(u8, key, "init_if_needed")) {
                if (config.init_if_needed) @compileError("init_if_needed already set");
                config.init_if_needed = true;
            } else if (std.mem.eql(u8, key, "rent_exempt")) {
                if (config.rent_exempt) @compileError("rent_exempt already set");
                config.rent_exempt = true;
            } else if (std.mem.eql(u8, key, "executable")) {
                if (config.executable) @compileError("executable already set");
                config.executable = true;
            } else if (std.mem.eql(u8, key, "bump")) {
                if (config.bump) @compileError("bump already set");
                config.bump = true;
            } else {
                @compileError("attribute parse error: expected key/value");
            }
        }

        parser.skipWs();
        if (parser.consumeChar(',')) {
            parser.skipWs();
            if (parser.eof()) {
                @compileError("attribute parse error: trailing comma");
            }
            continue;
        }
        parser.expectEof();
        break;
    }

    return config;
}

// ============================================================================
// Tests
// ============================================================================

test "parseAccount maps account attributes into DSL config" {
    const account_mod = @import("account.zig");
    const discriminator_mod = @import("discriminator.zig");

    const attrs = attr.parseAccount(
        "mut, signer, seeds = [\"seed\", account(authority)], bump = bump, seeds::program = account(authority), " ++
        "payer = payer, has_one = [authority], close = destination, realloc = { payer = payer, zero_init = true }, " ++
        "token::mint = mint, token::authority = authority, associated_token::mint = mint, associated_token::authority = authority, " ++
        "init_if_needed, rent_exempt, constraint = \"authority.key() == counter.authority\", executable, space = 128",
    );

    const Data = struct {
        authority: PublicKey,
    };

    const Parsed = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("Parsed"),
        .attrs = attrs,
    });

    try std.testing.expect(Parsed.HAS_MUT);
    try std.testing.expect(Parsed.HAS_SIGNER);
    try std.testing.expect(Parsed.HAS_SEEDS);
    try std.testing.expect(Parsed.HAS_BUMP);
    try std.testing.expect(Parsed.BUMP_FIELD != null);
    try std.testing.expect(Parsed.SEEDS_PROGRAM != null);
    try std.testing.expect(Parsed.PAYER != null);
    try std.testing.expect(Parsed.HAS_HAS_ONE);
    try std.testing.expect(Parsed.HAS_CLOSE);
    try std.testing.expect(Parsed.HAS_REALLOC);
    try std.testing.expect(Parsed.RENT_EXEMPT);
    try std.testing.expect(Parsed.CONSTRAINT != null);
    try std.testing.expect(Parsed.EXECUTABLE);
    try std.testing.expectEqual(@as(usize, 128), Parsed.SPACE);
    try std.testing.expect(Parsed.TOKEN_MINT != null);
    try std.testing.expect(Parsed.TOKEN_AUTHORITY != null);
    try std.testing.expect(Parsed.ASSOCIATED_TOKEN != null);
    try std.testing.expect(Parsed.IS_INIT_IF_NEEDED);
}

test "parseAccount handles owner and address keys" {
    const account_mod = @import("account.zig");
    const discriminator_mod = @import("discriminator.zig");

    const attrs = attr.parseAccount(
        "owner = \"11111111111111111111111111111111\", address = \"SysvarRent111111111111111111111111111111111\"",
    );

    const Data = struct {
        authority: PublicKey,
    };

    const Parsed = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("ParsedOwner"),
        .attrs = attrs,
    });

    try std.testing.expect(Parsed.OWNER != null);
    try std.testing.expect(Parsed.ADDRESS != null);
}
