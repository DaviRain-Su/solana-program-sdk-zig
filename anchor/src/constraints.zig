//! Zig implementation of Anchor constraints
//!
//! Anchor source: https://github.com/coral-xyz/anchor/blob/master/lang/syn/src/codegen/accounts/constraints.rs
//!
//! Constraints define validation rules for accounts. In Anchor, these are
//! specified via `#[account(...)]` attributes. In sol-anchor-zig, they are
//! defined as struct fields with compile-time configuration.
//!
//! ## Phase 1 Constraints (implemented)
//! - `mut`: Account must be writable
//! - `signer`: Account must sign the transaction
//! - `owner`: Account must be owned by specified program
//! - `address`: Account must have exact public key
//! - `executable`: Account must be executable (for program accounts)
//!
//! ## Future Phases
//! - `rent_exempt`: Rent exemption check (requires Rent sysvar)
//! - `seeds`, `bump`: PDA derivation (Phase 2)
//! - `has_one`, `constraint`: Field validation (Phase 3)
//! - `close`, `realloc`: Account lifecycle (Phase 3)

const std = @import("std");
const anchor_error = @import("error.zig");
const AnchorError = anchor_error.AnchorError;
const sol = @import("solana_program_sdk");

// Import from parent SDK
const Account = sol.account.Account;
const PublicKey = sol.PublicKey;

/// Constraint expression descriptor
///
/// This is a lightweight placeholder for constraint expressions used
/// in account configs. It is currently emitted to IDL only.
pub const ConstraintExpr = struct {
    expr: []const u8,
};

/// Define a constraint expression.
///
/// Example:
/// ```zig
/// .constraint = anchor.constraint("authority.key() == vault.authority")
/// ```
pub fn constraint(comptime expr: []const u8) ConstraintExpr {
    if (expr.len == 0) {
        @compileError("constraint expression cannot be empty");
    }
    return .{ .expr = expr };
}

const ValueKind = enum {
    pubkey,
    int,
    bool,
    invalid,
};

const Value = union(ValueKind) {
    pubkey: [32]u8,
    int: i128,
    bool: bool,
    invalid: void,
};

const Op = enum {
    eq,
    ne,
};

const Access = struct {
    parts: [8][]const u8,
    len: usize,
    use_key: bool,
};

const Operand = union(enum) {
    access: Access,
    int: i128,
    bool: bool,
};

const Constraint = struct {
    lhs: Operand,
    op: Op,
    rhs: Operand,
};

const ExprParser = struct {
    input: []const u8,
    index: usize,

    fn init(comptime input: []const u8) ExprParser {
        return .{ .input = input, .index = 0 };
    }

    fn eof(self: *const ExprParser) bool {
        return self.index >= self.input.len;
    }

    fn peek(self: *const ExprParser) ?u8 {
        if (self.eof()) return null;
        return self.input[self.index];
    }

    fn skipWs(self: *ExprParser) void {
        while (self.peek()) |c| {
            if (c != ' ' and c != '\n' and c != '\t' and c != '\r') break;
            self.index += 1;
        }
    }

    fn consumeChar(self: *ExprParser, comptime expected: u8) bool {
        if (self.peek() == expected) {
            self.index += 1;
            return true;
        }
        return false;
    }

    fn expectChar(self: *ExprParser, comptime expected: u8) void {
        if (!self.consumeChar(expected)) {
            @compileError("constraint parse error: expected character");
        }
    }

    fn expectEof(self: *ExprParser) void {
        if (!self.eof()) {
            @compileError("constraint parse error: trailing input");
        }
    }

    fn isIdentChar(c: u8) bool {
        return std.ascii.isAlphabetic(c) or std.ascii.isDigit(c) or c == '_';
    }

    fn parseIdent(self: *ExprParser) []const u8 {
        const start = self.index;
        while (self.peek()) |c| {
            if (!isIdentChar(c)) break;
            self.index += 1;
        }
        if (self.index == start) {
            @compileError("constraint parse error: expected identifier");
        }
        return self.input[start..self.index];
    }

    fn parseInt(self: *ExprParser) i128 {
        const start = self.index;
        while (self.peek()) |c| {
            if (!std.ascii.isDigit(c)) break;
            self.index += 1;
        }
        if (self.index == start) {
            @compileError("constraint parse error: expected integer");
        }
        return std.fmt.parseInt(i128, self.input[start..self.index], 10) catch {
            @compileError("constraint parse error: invalid integer");
        };
    }

    fn parseOperand(self: *ExprParser) Operand {
        self.skipWs();
        if (self.peek()) |c| {
            if (std.ascii.isDigit(c)) {
                return .{ .int = self.parseInt() };
            }
        }
        const ident = self.parseIdent();
        if (std.mem.eql(u8, ident, "true")) return .{ .bool = true };
        if (std.mem.eql(u8, ident, "false")) return .{ .bool = false };

        var parts: [8][]const u8 = undefined;
        var count: usize = 0;
        parts[count] = ident;
        count += 1;

        var use_key = false;
        while (true) {
            self.skipWs();
            if (!self.consumeChar('.')) break;
            self.skipWs();
            const next = self.parseIdent();
            if (std.mem.eql(u8, next, "key")) {
                self.skipWs();
                self.expectChar('(');
                self.skipWs();
                self.expectChar(')');
                use_key = true;
                break;
            }
            if (count >= parts.len) {
                @compileError("constraint parse error: too many access segments");
            }
            parts[count] = next;
            count += 1;
        }

        return .{ .access = .{ .parts = parts, .len = count, .use_key = use_key } };
    }

    fn parseOp(self: *ExprParser) Op {
        self.skipWs();
        if (self.consumeChar('=')) {
            if (!self.consumeChar('=')) {
                @compileError("constraint parse error: expected ==");
            }
            return .eq;
        }
        if (self.consumeChar('!')) {
            if (!self.consumeChar('=')) {
                @compileError("constraint parse error: expected !=");
            }
            return .ne;
        }
        @compileError("constraint parse error: expected == or !=");
    }
};

fn parseConstraint(comptime expr: []const u8) Constraint {
    comptime var parser = ExprParser.init(expr);
    const lhs = parser.parseOperand();
    const op = parser.parseOp();
    const rhs = parser.parseOperand();
    parser.skipWs();
    parser.expectEof();
    return .{ .lhs = lhs, .op = op, .rhs = rhs };
}

fn hasField(comptime T: type, comptime name: []const u8) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") return false;
    inline for (info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, name)) return true;
    }
    return false;
}

fn fieldTypeByName(comptime T: type, comptime name: []const u8) ?type {
    const info = @typeInfo(T);
    if (info != .@"struct") return null;
    inline for (info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, name)) return field.type;
    }
    return null;
}

fn unwrapOptionalType(comptime T: type) type {
    const info = @typeInfo(T);
    if (info == .optional) {
        return info.optional.child;
    }
    return T;
}

fn unwrapPointerType(comptime T: type) type {
    const info = @typeInfo(T);
    if (info == .pointer) {
        return info.pointer.child;
    }
    return T;
}

fn isPubkeyLike(comptime T: type) bool {
    const Clean = unwrapPointerType(unwrapOptionalType(T));
    if (Clean == PublicKey) return true;
    if (@typeInfo(Clean) == .array) {
        const array = @typeInfo(Clean).array;
        return array.child == u8 and array.len == 32;
    }
    return false;
}

fn isIntType(comptime T: type) bool {
    return @typeInfo(unwrapPointerType(unwrapOptionalType(T))) == .int;
}

fn isBoolType(comptime T: type) bool {
    return unwrapPointerType(unwrapOptionalType(T)) == bool;
}

fn accessValueType(
    comptime access: Access,
    comptime account_name: []const u8,
    comptime Accounts: type,
) type {
    comptime var parts = access.parts[0..access.len];
    comptime var current: type = Accounts;

    if (parts.len > 0 and std.mem.eql(u8, parts[0], account_name)) {
        const FieldType = fieldTypeByName(Accounts, parts[0]) orelse {
            @compileError("constraint access references unknown account: " ++ parts[0]);
        };
        current = FieldType;
        parts = parts[1..];
    }

    inline for (parts) |name| {
        const Clean = unwrapPointerType(unwrapOptionalType(current));
        if (@hasDecl(Clean, "DataType")) {
            const DataType = Clean.DataType;
            if (hasField(DataType, name)) {
                current = fieldTypeByName(DataType, name).?;
                continue;
            }
        }
        if (hasField(Clean, name)) {
            current = fieldTypeByName(Clean, name).?;
            continue;
        }
        @compileError("constraint access references unknown field: " ++ name);
    }

    if (access.use_key) {
        const Clean = unwrapPointerType(unwrapOptionalType(current));
        if (!@hasDecl(Clean, "key")) {
            @compileError("constraint key() requires key() method");
        }
        return PublicKey;
    }

    return current;
}

fn operandKind(
    comptime operand: Operand,
    comptime account_name: []const u8,
    comptime Accounts: type,
) ValueKind {
    return switch (operand) {
        .int => .int,
        .bool => .bool,
        .access => |access| blk: {
            const T = accessValueType(access, account_name, Accounts);
            if (isPubkeyLike(T)) break :blk .pubkey;
            if (isIntType(T)) break :blk .int;
            if (isBoolType(T)) break :blk .bool;
            @compileError("constraint access type not supported");
        },
    };
}

fn validateConstraintTypes(
    comptime expr: Constraint,
    comptime account_name: []const u8,
    comptime Accounts: type,
) void {
    const lhs_kind = operandKind(expr.lhs, account_name, Accounts);
    const rhs_kind = operandKind(expr.rhs, account_name, Accounts);

    if (lhs_kind == .invalid or rhs_kind == .invalid) {
        @compileError("constraint contains invalid operand");
    }

    if (lhs_kind != rhs_kind) {
        @compileError("constraint operands must have matching types");
    }
}

fn valueFromAny(value: anytype) Value {
    const T = @TypeOf(value);
    if (@typeInfo(T) == .optional) {
        if (value == null) return .{ .invalid = {} };
        return valueFromAny(value.?);
    }
    if (@typeInfo(T) == .pointer) {
        return valueFromAny(value.*);
    }

    if (T == PublicKey) {
        return .{ .pubkey = value.bytes };
    }
    if (@typeInfo(T) == .array) {
        const array = @typeInfo(T).array;
        if (array.child == u8 and array.len == 32) {
            return .{ .pubkey = value };
        }
    }
    if (@typeInfo(T) == .int) {
        return .{ .int = @intCast(value) };
    }
    if (T == bool) {
        return .{ .bool = value };
    }

    @compileError("constraint value type not supported: " ++ @typeName(T));
}

fn resolveAccessValue(
    comptime access: Access,
    comptime account_name: []const u8,
    accounts: anytype,
) Value {
    var parts = access.parts[0..access.len];
    var current = accounts;

    if (parts.len > 0 and std.mem.eql(u8, parts[0], account_name)) {
        current = @field(current, parts[0]);
        parts = parts[1..];
    }

    inline for (parts) |name| {
        const CurrentType = @TypeOf(current);
        if (@typeInfo(CurrentType) == .optional) {
            if (current == null) {
                return .{ .invalid = {} };
            }
            current = current.?;
        }
        if (@typeInfo(@TypeOf(current)) == .pointer) {
            current = current.*;
        }

        const CleanType = @TypeOf(current);
        if (@hasDecl(CleanType, "DataType")) {
            const DataType = CleanType.DataType;
            if (hasField(DataType, name)) {
                current = @field(current.data.*, name);
                continue;
            }
        }

        if (hasField(CleanType, name)) {
            current = @field(current, name);
            continue;
        }

        @compileError("constraint access references unknown field: " ++ name);
    }

    if (access.use_key) {
        const CleanType = @TypeOf(current);
        if (!@hasDecl(CleanType, "key")) {
            @compileError("constraint key() requires key() method");
        }
        return valueFromAny(current.key().*);
    }

    return valueFromAny(current);
}

fn evalOperand(
    comptime operand: Operand,
    comptime account_name: []const u8,
    accounts: anytype,
) Value {
    return switch (operand) {
        .int => |value| .{ .int = value },
        .bool => |value| .{ .bool = value },
        .access => |access| resolveAccessValue(access, account_name, accounts),
    };
}

fn compareValues(lhs: Value, op: Op, rhs: Value) bool {
    return switch (lhs) {
        .invalid => false,
        .pubkey => |l| switch (rhs) {
            .pubkey => |r| (op == .eq) == std.mem.eql(u8, &l, &r),
            else => false,
        },
        .int => |l| switch (rhs) {
            .int => |r| (op == .eq) == (l == r),
            else => false,
        },
        .bool => |l| switch (rhs) {
            .bool => |r| (op == .eq) == (l == r),
            else => false,
        },
    };
}

fn evalConstraint(
    comptime expr: Constraint,
    comptime account_name: []const u8,
    accounts: anytype,
) bool {
    const lhs = evalOperand(expr.lhs, account_name, accounts);
    const rhs = evalOperand(expr.rhs, account_name, accounts);
    return compareValues(lhs, expr.op, rhs);
}

pub fn validateConstraintExpr(
    comptime expr: []const u8,
    comptime account_name: []const u8,
    accounts: anytype,
) !void {
    const parsed = comptime parseConstraint(expr);
    comptime validateConstraintTypes(parsed, account_name, @TypeOf(accounts));
    if (!evalConstraint(parsed, account_name, accounts)) {
        return error.ConstraintRaw;
    }
}

/// Constraint specification for account validation
///
/// Used to define validation rules for accounts in an instruction context.
/// Each field corresponds to an Anchor constraint attribute.
///
/// Example:
/// ```zig
/// const my_constraints = Constraints{
///     .mut = true,
///     .signer = true,
///     .owner = my_program_id,
/// };
/// ```
pub const Constraints = struct {
    /// Account must be mutable (writable)
    ///
    /// Anchor equivalent: `#[account(mut)]`
    mut: bool = false,

    /// Account must be a signer of the transaction
    ///
    /// Anchor equivalent: `#[account(signer)]`
    signer: bool = false,

    /// Account must be owned by specified program
    ///
    /// Anchor equivalent: `#[account(owner = <program>)]`
    owner: ?PublicKey = null,

    /// Account must have exact public key address
    ///
    /// Anchor equivalent: `#[account(address = <pubkey>)]`
    address: ?PublicKey = null,

    /// Account must be executable (for program accounts)
    ///
    /// Anchor equivalent: `#[account(executable)]`
    executable: bool = false,

    // Note: rent_exempt constraint is planned for future phases.
    // It requires access to the Rent sysvar for proper validation.
};

/// Validate constraints against an account
///
/// Checks all specified constraints and returns the first violation found.
/// Returns null if all constraints pass.
///
/// Example:
/// ```zig
/// const constraints = Constraints{ .mut = true, .signer = true };
/// if (validateConstraints(&account_info, constraints)) |err| {
///     return err;
/// }
/// ```
pub fn validateConstraints(info: *const Account.Info, constraints: Constraints) ?AnchorError {
    // Check mut constraint
    if (constraints.mut and info.is_writable == 0) {
        return AnchorError.ConstraintMut;
    }

    // Check signer constraint
    if (constraints.signer and info.is_signer == 0) {
        return AnchorError.ConstraintSigner;
    }

    // Check owner constraint
    if (constraints.owner) |expected_owner| {
        if (!info.owner_id.equals(expected_owner)) {
            return AnchorError.ConstraintOwner;
        }
    }

    // Check address constraint
    if (constraints.address) |expected_address| {
        if (!info.id.equals(expected_address)) {
            return AnchorError.ConstraintAddress;
        }
    }

    // Check executable constraint
    if (constraints.executable and info.is_executable == 0) {
        return AnchorError.ConstraintExecutable;
    }

    // All constraints passed
    return null;
}

/// Validate constraints, returning error union for try/catch usage
///
/// Example:
/// ```zig
/// try validateConstraintsOrError(&account_info, constraints);
/// ```
pub fn validateConstraintsOrError(info: *const Account.Info, constraints: Constraints) !void {
    if (validateConstraints(info, constraints)) |err| {
        return switch (err) {
            .ConstraintMut => error.ConstraintMut,
            .ConstraintSigner => error.ConstraintSigner,
            .ConstraintOwner => error.ConstraintOwner,
            .ConstraintAddress => error.ConstraintAddress,
            .ConstraintExecutable => error.ConstraintExecutable,
            else => error.ConstraintRaw,
        };
    }
}

/// Constraint validation errors
pub const ConstraintError = error{
    ConstraintMut,
    ConstraintSigner,
    ConstraintOwner,
    ConstraintAddress,
    ConstraintExecutable,
    ConstraintRaw,
    // Reserved for future phases:
    ConstraintSeeds, // Phase 2: PDA validation
    ConstraintHasOne, // Phase 3: Field validation
    ConstraintRentExempt, // Future: Requires Rent sysvar
};

// ============================================================================
// Tests
// ============================================================================

test "validateConstraints passes with no constraints" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{};
    try std.testing.expect(validateConstraints(&info, constraints) == null);
}

test "validateConstraints fails mut when not writable" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .mut = true };
    try std.testing.expectEqual(AnchorError.ConstraintMut, validateConstraints(&info, constraints).?);
}

test "validateConstraints passes mut when writable" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
    };

    const constraints = Constraints{ .mut = true };
    try std.testing.expect(validateConstraints(&info, constraints) == null);
}

test "validateConstraints fails signer when not signing" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .signer = true };
    try std.testing.expectEqual(AnchorError.ConstraintSigner, validateConstraints(&info, constraints).?);
}

test "validateConstraints passes signer when signing" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .signer = true };
    try std.testing.expect(validateConstraints(&info, constraints) == null);
}

test "validateConstraints fails owner mismatch" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    // Use TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA (Token Program) - different from default (all zeros)
    const expected_owner = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .owner = expected_owner };
    try std.testing.expectEqual(AnchorError.ConstraintOwner, validateConstraints(&info, constraints).?);
}

test "validateConstraints passes owner match" {
    var id = PublicKey.default();
    // Use Token Program ID for both owner and expected to test matching
    var owner = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .owner = owner };
    try std.testing.expect(validateConstraints(&info, constraints) == null);
}

test "validateConstraints fails address mismatch" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    // Use Token Program ID as expected address - different from default (all zeros)
    const expected_address = comptime PublicKey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
    };

    const constraints = Constraints{ .address = expected_address };
    try std.testing.expectEqual(AnchorError.ConstraintAddress, validateConstraints(&info, constraints).?);
}

test "validateConstraints checks multiple constraints" {
    var id = PublicKey.default();
    var owner = PublicKey.default();
    var lamports: u64 = 1000;
    const info = Account.Info{
        .id = &id,
        .owner_id = &owner,
        .lamports = &lamports,
        .data_len = 0,
        .data = undefined,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
    };

    const constraints = Constraints{
        .mut = true,
        .signer = true,
    };
    try std.testing.expect(validateConstraints(&info, constraints) == null);
}
