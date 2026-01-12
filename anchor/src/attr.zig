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
    zero: void,
    dup: void,
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
    token_program: []const u8,
    mint_authority: []const u8,
    mint_freeze_authority: []const u8,
    mint_decimals: u8,
    mint_token_program: []const u8,
    init: void,
    payer: []const u8,
    close: []const u8,
    realloc: ReallocConfig,
    has_one: []const HasOneSpec,
    rent_exempt: void,
    constraint: ConstraintExpr,
    owner: PublicKey,
    owner_expr: []const u8,
    address: PublicKey,
    address_expr: []const u8,
    executable: void,
    space: usize,
    space_expr: []const u8,
};

/// Macro-style account attribute configuration.
///
/// This config mirrors common `#[account(...)]` fields and is intended
/// to be converted into an Attr list via `anchor.attr.account(...)`.
pub const AccountAttrConfig = struct {
    mut: bool = false,
    signer: bool = false,
    zero: bool = false,
    dup: bool = false,
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
    token_program: ?[]const u8 = null,
    mint_authority: ?[]const u8 = null,
    mint_freeze_authority: ?[]const u8 = null,
    mint_decimals: ?u8 = null,
    mint_token_program: ?[]const u8 = null,
    init: bool = false,
    payer: ?[]const u8 = null,
    close: ?[]const u8 = null,
    realloc: ?ReallocConfig = null,
    has_one: ?[]const HasOneSpec = null,
    has_one_fields: ?[]const []const u8 = null,
    rent_exempt: bool = false,
    constraint: ?[]const u8 = null,
    owner: ?PublicKey = null,
    owner_expr: ?[]const u8 = null,
    address: ?PublicKey = null,
    address_expr: ?[]const u8 = null,
    executable: bool = false,
    space: ?usize = null,
    space_expr: ?[]const u8 = null,
};

fn hasOneSpecsFromFields(comptime fields: []const []const u8) []const HasOneSpec {
    const specs = comptime blk: {
        var tmp: [fields.len]HasOneSpec = undefined;
        inline for (fields, 0..) |field_name, index| {
            tmp[index] = .{ .field = field_name, .target = field_name };
        }
        break :blk tmp;
    };
    return specs[0..];
}

fn countAccountAttrs(comptime config: AccountAttrConfig) usize {
    comptime var count: usize = 0;
    if (config.mut) count += 1;
    if (config.signer) count += 1;
    if (config.zero) count += 1;
    if (config.dup) count += 1;
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
    if (config.token_program != null) count += 1;
    if (config.mint_authority != null) count += 1;
    if (config.mint_freeze_authority != null) count += 1;
    if (config.mint_decimals != null) count += 1;
    if (config.mint_token_program != null) count += 1;
    if (config.init) count += 1;
    if (config.payer != null) count += 1;
    if (config.close != null) count += 1;
    if (config.realloc != null) count += 1;
    if (config.has_one != null) count += 1;
    if (config.has_one_fields != null) count += 1;
    if (config.rent_exempt) count += 1;
    if (config.constraint != null) count += 1;
    if (config.owner != null) count += 1;
    if (config.owner_expr != null) count += 1;
    if (config.address != null) count += 1;
    if (config.address_expr != null) count += 1;
    if (config.executable) count += 1;
    if (config.space != null) count += 1;
    if (config.space_expr != null) count += 1;
    return count;
}

pub const attr = struct {
    pub fn mut() Attr {
        return .{ .mut = {} };
    }

    pub fn signer() Attr {
        return .{ .signer = {} };
    }

    pub fn zero() Attr {
        return .{ .zero = {} };
    }

    pub fn dup() Attr {
        return .{ .dup = {} };
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

    pub fn tokenProgram(comptime value: []const u8) Attr {
        return .{ .token_program = value };
    }

    pub fn mintAuthority(comptime value: []const u8) Attr {
        return .{ .mint_authority = value };
    }

    pub fn mintFreezeAuthority(comptime value: []const u8) Attr {
        return .{ .mint_freeze_authority = value };
    }

    pub fn mintDecimals(value: u8) Attr {
        return .{ .mint_decimals = value };
    }

    pub fn mintTokenProgram(comptime value: []const u8) Attr {
        return .{ .mint_token_program = value };
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

    pub fn ownerExpr(comptime value: []const u8) Attr {
        return .{ .owner_expr = value };
    }

    pub fn address(value: PublicKey) Attr {
        return .{ .address = value };
    }

    pub fn addressExpr(comptime value: []const u8) Attr {
        return .{ .address_expr = value };
    }

    pub fn executable() Attr {
        return .{ .executable = {} };
    }

    pub fn space(value: usize) Attr {
        return .{ .space = value };
    }

    pub fn spaceExpr(comptime value: []const u8) Attr {
        return .{ .space_expr = value };
    }

    pub fn account(comptime config: AccountAttrConfig) []const Attr {
        if (config.has_one != null and config.has_one_fields != null) {
            @compileError("has_one and has_one_fields are mutually exclusive");
        }
        if (config.owner != null and config.owner_expr != null) {
            @compileError("owner and owner_expr are mutually exclusive");
        }
        if (config.address != null and config.address_expr != null) {
            @compileError("address and address_expr are mutually exclusive");
        }
        if (config.space != null and config.space_expr != null) {
            @compileError("space and space_expr are mutually exclusive");
        }

        const attrs = comptime buildAccountAttrArray(config);
        return attrs[0..];
    }

    /// Parse `#[account(...)]`-style attributes into an Attr list.
    ///
    /// Supported keys (subset):
    /// - flags: mut, signer, zero, dup, init, rent_exempt, executable, bump
    /// - key/value: payer, close, constraint, space, owner, address
    /// - seeds: seeds = [ ... ]
    /// - bump field: bump = <field>
    /// - seeds program: seeds::program = <seed>
    /// - has_one: has_one = <field> or has_one = [a, b]
    /// - realloc: realloc = { payer = <field>, zero_init = true } or realloc::payer/realloc::zero
    /// - token: token::mint/token::authority/token::token_program
    /// - mint: mint::authority/mint::freeze_authority/mint::decimals/mint::token_program
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
    if (config.zero) {
        attrs[index] = attr.zero();
        index += 1;
    }
    if (config.dup) {
        attrs[index] = attr.dup();
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
    if (config.token_program) |value| {
        attrs[index] = attr.tokenProgram(value);
        index += 1;
    }
    if (config.mint_authority) |value| {
        attrs[index] = attr.mintAuthority(value);
        index += 1;
    }
    if (config.mint_freeze_authority) |value| {
        attrs[index] = attr.mintFreezeAuthority(value);
        index += 1;
    }
    if (config.mint_decimals) |value| {
        attrs[index] = attr.mintDecimals(value);
        index += 1;
    }
    if (config.mint_token_program) |value| {
        attrs[index] = attr.mintTokenProgram(value);
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
    if (config.owner_expr) |value| {
        attrs[index] = attr.ownerExpr(value);
        index += 1;
    }
    if (config.address) |value| {
        attrs[index] = attr.address(value);
        index += 1;
    }
    if (config.address_expr) |value| {
        attrs[index] = attr.addressExpr(value);
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
    if (config.space_expr) |value| {
        attrs[index] = attr.spaceExpr(value);
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

    fn parseByteStringLiteral(self: *Parser) []const u8 {
        self.expectChar('b');
        return self.parseStringLiteral();
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
        if (self.peek() == 'b' and self.index + 1 < self.input.len and self.input[self.index + 1] == '"') {
            const lit = self.parseByteStringLiteral();
            return seeds_mod.seed(lit);
        }
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

    fn parseExprSlice(self: *Parser, comptime stop_at_at: bool) []const u8 {
        self.skipWs();
        const start = self.index;
        var depth_paren: usize = 0;
        var depth_brack: usize = 0;
        var depth_brace: usize = 0;
        var in_string = false;

        while (self.peek()) |c| {
            if (in_string) {
                if (c == '"') {
                    in_string = false;
                }
                self.index += 1;
                continue;
            }

            switch (c) {
                '"' => {
                    in_string = true;
                },
                '(' => depth_paren += 1,
                ')' => if (depth_paren > 0) depth_paren -= 1,
                '[' => depth_brack += 1,
                ']' => if (depth_brack > 0) depth_brack -= 1,
                '{' => depth_brace += 1,
                '}' => if (depth_brace > 0) depth_brace -= 1,
                ',' => if (depth_paren == 0 and depth_brack == 0 and depth_brace == 0) break,
                '@' => if (stop_at_at and depth_paren == 0 and depth_brack == 0 and depth_brace == 0) break,
                else => {},
            }
            self.index += 1;
        }

        const end = self.index;
        return std.mem.trim(u8, self.input[start..end], " \t\r\n");
    }

    fn consumeOptionalError(self: *Parser) void {
        self.skipWs();
        if (self.consumeChar('@')) {
            _ = self.parseExprSlice(false);
        }
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
        const parsed = comptime blk: {
            var tmp: [count]SeedSpec = undefined;
            inline for (seeds[0..count], 0..) |spec, index| {
                tmp[index] = spec;
            }
            break :blk tmp;
        };
        return parsed[0..];
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
            const parsed = comptime blk: {
                var tmp: [count][]const u8 = undefined;
                inline for (fields[0..count], 0..) |value, index| {
                    tmp[index] = value;
                }
                break :blk tmp;
            };
            return parsed[0..];
        }

        fields[0] = self.parseIdentOrString();
        const single = comptime blk: {
            const tmp = [_][]const u8{fields[0]};
            break :blk tmp;
        };
        return single[0..];
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
    comptime var rent_exempt_seen: bool = false;

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
            } else if (std.mem.eql(u8, sub, "token_program")) {
                key = "token::token_program";
            } else {
                @compileError("attribute parse error: expected token::mint/authority/token_program");
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
        } else if (std.mem.eql(u8, ident, "mint") and parser.consumeColonColon()) {
            parser.skipWs();
            const sub = parser.parseIdent();
            if (std.mem.eql(u8, sub, "authority")) {
                key = "mint::authority";
            } else if (std.mem.eql(u8, sub, "freeze_authority")) {
                key = "mint::freeze_authority";
            } else if (std.mem.eql(u8, sub, "decimals")) {
                key = "mint::decimals";
            } else if (std.mem.eql(u8, sub, "token_program")) {
                key = "mint::token_program";
            } else {
                @compileError("attribute parse error: expected mint::authority/freeze_authority/decimals/token_program");
            }
        } else if (std.mem.eql(u8, ident, "realloc") and parser.consumeColonColon()) {
            parser.skipWs();
            const sub = parser.parseIdent();
            if (std.mem.eql(u8, sub, "payer")) {
                key = "realloc::payer";
            } else if (std.mem.eql(u8, sub, "zero") or std.mem.eql(u8, sub, "zero_init")) {
                key = "realloc::zero";
            } else {
                @compileError("attribute parse error: expected realloc::payer or realloc::zero");
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
            } else if (std.mem.eql(u8, key, "token::token_program")) {
                if (config.token_program != null) @compileError("token::token_program already set");
                config.token_program = parser.parseIdentOrString();
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
            } else if (std.mem.eql(u8, key, "realloc::payer")) {
                if (config.realloc == null) config.realloc = .{};
                if (config.realloc.?.payer != null) {
                    @compileError("realloc payer already set");
                }
                config.realloc.?.payer = parser.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "realloc::zero")) {
                if (config.realloc == null) config.realloc = .{};
                config.realloc.?.zero_init = parser.parseBool();
            } else if (std.mem.eql(u8, key, "has_one")) {
                if (config.has_one_fields != null or config.has_one != null) {
                    @compileError("has_one already set");
                }
                config.has_one_fields = parser.parseHasOneFields();
            } else if (std.mem.eql(u8, key, "constraint")) {
                if (config.constraint != null) @compileError("constraint already set");
                if (parser.peek() == '"') {
                    config.constraint = parser.parseStringLiteral();
                } else {
                    const expr = parser.parseExprSlice(true);
                    if (expr.len == 0) @compileError("attribute parse error: empty constraint expression");
                    config.constraint = expr;
                }
            } else if (std.mem.eql(u8, key, "owner")) {
                if (config.owner != null) @compileError("owner already set");
                if (parser.peek() == '"') {
                    const key_str = parser.parseStringLiteral();
                    config.owner = PublicKey.comptimeFromBase58(key_str);
                } else {
                    const expr = parser.parseExprSlice(true);
                    if (expr.len == 0) @compileError("attribute parse error: empty owner expression");
                    config.owner_expr = expr;
                }
            } else if (std.mem.eql(u8, key, "address")) {
                if (config.address != null) @compileError("address already set");
                if (parser.peek() == '"') {
                    const key_str = parser.parseStringLiteral();
                    config.address = PublicKey.comptimeFromBase58(key_str);
                } else {
                    const expr = parser.parseExprSlice(true);
                    if (expr.len == 0) @compileError("attribute parse error: empty address expression");
                    config.address_expr = expr;
                }
            } else if (std.mem.eql(u8, key, "space")) {
                if (config.space != null) @compileError("space already set");
                const expr = parser.parseExprSlice(true);
                if (expr.len == 0) @compileError("attribute parse error: empty space expression");
                var all_digits = true;
                for (expr) |ch| {
                    if (!std.ascii.isDigit(ch)) {
                        all_digits = false;
                        break;
                    }
                }
                if (all_digits) {
                    config.space = std.fmt.parseInt(usize, expr, 10) catch {
                        @compileError("attribute parse error: invalid integer");
                    };
                } else {
                    config.space_expr = expr;
                }
            } else if (std.mem.eql(u8, key, "rent_exempt")) {
                if (rent_exempt_seen) @compileError("rent_exempt already set");
                const mode = parser.parseIdent();
                if (std.mem.eql(u8, mode, "enforce")) {
                    config.rent_exempt = true;
                } else if (std.mem.eql(u8, mode, "skip")) {
                    config.rent_exempt = false;
                } else {
                    @compileError("attribute parse error: expected rent_exempt = skip|enforce");
                }
                rent_exempt_seen = true;
            } else if (std.mem.eql(u8, key, "mint::authority")) {
                if (config.mint_authority != null) @compileError("mint::authority already set");
                config.mint_authority = parser.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "mint::freeze_authority")) {
                if (config.mint_freeze_authority != null) @compileError("mint::freeze_authority already set");
                config.mint_freeze_authority = parser.parseIdentOrString();
            } else if (std.mem.eql(u8, key, "mint::decimals")) {
                if (config.mint_decimals != null) @compileError("mint::decimals already set");
                const value = parser.parseInt();
                if (value > std.math.maxInt(u8)) {
                    @compileError("attribute parse error: mint::decimals out of range");
                }
                config.mint_decimals = @as(u8, @intCast(value));
            } else if (std.mem.eql(u8, key, "mint::token_program")) {
                if (config.mint_token_program != null) @compileError("mint::token_program already set");
                config.mint_token_program = parser.parseIdentOrString();
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
            } else if (std.mem.eql(u8, key, "zero")) {
                if (config.zero) @compileError("zero already set");
                config.zero = true;
            } else if (std.mem.eql(u8, key, "dup")) {
                if (config.dup) @compileError("dup already set");
                config.dup = true;
            } else if (std.mem.eql(u8, key, "init")) {
                if (config.init) @compileError("init already set");
                config.init = true;
            } else if (std.mem.eql(u8, key, "init_if_needed")) {
                if (config.init_if_needed) @compileError("init_if_needed already set");
                config.init_if_needed = true;
            } else if (std.mem.eql(u8, key, "rent_exempt")) {
                if (rent_exempt_seen or config.rent_exempt) @compileError("rent_exempt already set");
                config.rent_exempt = true;
                rent_exempt_seen = true;
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

        parser.consumeOptionalError();
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
        "mut, signer, zero, dup, seeds = [b\"seed\", account(authority)], bump = bump, seeds::program = account(authority), " ++
        "payer = payer, has_one = [authority], close = destination, realloc::payer = payer, realloc::zero = true, " ++
        "token::mint = mint, token::authority = authority, token::token_program = token_program, " ++
        "mint::authority = mint_authority, mint::freeze_authority = mint_freeze, mint::decimals = 6, mint::token_program = mint_program, " ++
        "associated_token::mint = mint, associated_token::authority = authority, " ++
        "init_if_needed, rent_exempt = enforce, constraint = authority.key() == counter.authority @ CustomError, executable, space = 128",
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
    try std.testing.expect(Parsed.IS_ZERO);
    try std.testing.expect(Parsed.IS_DUP);
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
    try std.testing.expect(Parsed.TOKEN_PROGRAM != null);
    try std.testing.expect(Parsed.MINT_AUTHORITY != null);
    try std.testing.expect(Parsed.MINT_FREEZE_AUTHORITY != null);
    try std.testing.expectEqual(@as(u8, 6), Parsed.MINT_DECIMALS.?);
    try std.testing.expect(Parsed.MINT_TOKEN_PROGRAM != null);
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

test "parseAccount handles owner/address/space expressions" {
    const account_mod = @import("account.zig");
    const discriminator_mod = @import("discriminator.zig");

    const Data = struct {
        pub const INIT_SPACE: usize = 24;
        authority: PublicKey,
    };

    const attrs = attr.parseAccount(
        "owner = authority.key(), address = authority.key(), space = 8 + INIT_SPACE",
    );

    const Parsed = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("ParsedExpr"),
        .attrs = attrs,
    });

    try std.testing.expect(Parsed.OWNER_EXPR != null);
    try std.testing.expect(Parsed.ADDRESS_EXPR != null);
    try std.testing.expectEqual(@as(usize, 32), Parsed.SPACE);
}

test "parseAccount handles rent_exempt skip" {
    const account_mod = @import("account.zig");
    const discriminator_mod = @import("discriminator.zig");

    const attrs = attr.parseAccount("rent_exempt = skip");

    const Data = struct {
        authority: PublicKey,
    };

    const Parsed = account_mod.Account(Data, .{
        .discriminator = discriminator_mod.accountDiscriminator("ParsedRentSkip"),
        .attrs = attrs,
    });

    try std.testing.expect(!Parsed.RENT_EXEMPT);
}
