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
