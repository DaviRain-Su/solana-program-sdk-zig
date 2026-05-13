const std = @import("std");
const spl_transfer_hook = @import("spl_transfer_hook");

test "consumer-style imports see only the intended transfer-hook scaffold surface" {
    try std.testing.expect(@hasDecl(spl_transfer_hook, "id"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "PACKAGE_NAME"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "MODULE_NAME"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "INTERFACE_VERSION"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "SCOPE"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "instruction"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "meta"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "resolve"));

    try std.testing.expect(!@hasDecl(spl_transfer_hook, "PROGRAM_ID"));
    try std.testing.expect(!@hasDecl(spl_transfer_hook, "rpc"));
    try std.testing.expect(!@hasDecl(spl_transfer_hook, "client"));
    try std.testing.expect(!@hasDecl(spl_transfer_hook, "keypair"));
    try std.testing.expect(!@hasDecl(spl_transfer_hook, "searcher"));
    try std.testing.expect(!@hasDecl(spl_transfer_hook, "transaction"));
}

test "consumer-style imports expose validation PDA helpers" {
    try std.testing.expect(@hasDecl(spl_transfer_hook, "ProgramDerivedAddress"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "DuplicatePolicy"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "Seed"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "PubkeyData"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "AccountKeyData"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "EXTRA_ACCOUNT_METAS_SEED"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "findValidationAddress"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "resolveExtraAccountMeta"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "resolveExtraAccountMetaList"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "unpackExecuteExtraAccountMetaListFromAccount"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "validateResolvedExtraAccountInfosWithPolicy"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "validateResolvedExtraAccountInfos"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "validateExecuteExtraAccountInfosWithPolicy"));
    try std.testing.expect(@hasDecl(spl_transfer_hook, "validateExecuteExtraAccountInfos"));
}
