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
    seeds: []const SeedSpec,
    bump: void,
    init: void,
    payer: []const u8,
    close: []const u8,
    realloc: ReallocConfig,
    has_one: []const HasOneSpec,
    rent_exempt: void,
    constraint: ConstraintExpr,
    owner: PublicKey,
    space: usize,
};

pub const attr = struct {
    pub fn seeds(comptime value: []const SeedSpec) Attr {
        seeds_mod.validateSeeds(value);
        return .{ .seeds = value };
    }

    pub fn bump() Attr {
        return .{ .bump = {} };
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

    pub fn space(value: usize) Attr {
        return .{ .space = value };
    }
};
