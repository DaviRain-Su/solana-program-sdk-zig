//! Zig implementation of Anchor-style comptime derives
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/syn/src/codegen/accounts/mod.rs
//!
//! This module provides lightweight comptime helpers that validate account and
//! event structs while keeping the original types intact.

const std = @import("std");
const sol = @import("solana_program_sdk");
const account_mod = @import("account.zig");
const signer_mod = @import("signer.zig");
const program_mod = @import("program.zig");

const AccountInfo = sol.account.Account.Info;
const Signer = signer_mod.Signer;
const SignerMut = signer_mod.SignerMut;
const UncheckedProgram = program_mod.UncheckedProgram;

/// Validate Accounts struct and return it unchanged.
pub fn Accounts(comptime T: type) type {
    comptime validateAccounts(T);
    return T;
}

/// Validate Event struct and return it unchanged.
pub fn Event(comptime T: type) type {
    comptime validateEvent(T);
    return T;
}

fn validateAccounts(comptime T: type) void {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("Accounts must be a struct type");
    }

    const fields = info.@"struct".fields;
    if (fields.len == 0) {
        @compileError("Accounts struct must have at least one field");
    }

    inline for (fields) |field| {
        const FieldType = field.type;
        if (@hasDecl(FieldType, "load")) {
            continue;
        }
        if (FieldType == *const AccountInfo) {
            continue;
        }

        @compileError("Unsupported account field type: " ++ field.name);
    }
}

fn validateEvent(comptime T: type) void {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("Event must be a struct type");
    }

    const fields = info.@"struct".fields;
    if (fields.len == 0) {
        @compileError("Event struct must have at least one field");
    }
}

// Ensure account wrappers expose load()
test "dsl: accounts validation accepts anchor account types" {
    const CounterData = struct {
        value: u64,
    };

    const Counter = account_mod.Account(CounterData, .{
        .discriminator = @import("discriminator.zig").accountDiscriminator("Counter"),
    });

    const AccountsType = Accounts(struct {
        authority: Signer,
        payer: SignerMut,
        counter: Counter,
    });

    const AccountsValue = AccountsType{
        .authority = undefined,
        .payer = undefined,
        .counter = undefined,
    };

    try std.testing.expectEqualStrings(@typeName(AccountsType), @typeName(@TypeOf(AccountsValue)));
}

test "dsl: event validation accepts struct" {
    const EventType = Event(struct {
        amount: u64,
        owner: sol.PublicKey,
    });

    _ = EventType;
}
