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

        return attrs[0..index];
    }
};
