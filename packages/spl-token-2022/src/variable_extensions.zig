//! Token-2022 variable-length TLV extension parsers.

const std = @import("std");
const spl_token_metadata = @import("spl_token_metadata");
const spl_token_group = @import("spl_token_group");

const extension = @import("extension.zig");
const tlv = @import("tlv.zig");

pub const MetadataAdditional = spl_token_metadata.state.AdditionalMetadata;
pub const TokenMetadata = spl_token_metadata.state.TokenMetadata;
pub const TokenGroup = spl_token_group.state.TokenGroup;
pub const TokenGroupMember = spl_token_group.state.TokenGroupMember;

pub const TokenMetadataParseError = tlv.Error || TokenMetadata.ParseError;
pub const TokenGroupParseError = tlv.Error || TokenGroup.ParseError;
pub const TokenGroupMemberParseError = tlv.Error || TokenGroupMember.ParseError;

pub fn findTokenMetadataRecord(parsed: tlv.Parsed) tlv.Error!tlv.Record {
    return parsed.findExtension(@intFromEnum(extension.ExtensionType.token_metadata));
}

pub fn findTokenGroupRecord(parsed: tlv.Parsed) tlv.Error!tlv.Record {
    return parsed.findExtension(@intFromEnum(extension.ExtensionType.token_group));
}

pub fn findTokenGroupMemberRecord(parsed: tlv.Parsed) tlv.Error!tlv.Record {
    return parsed.findExtension(@intFromEnum(extension.ExtensionType.token_group_member));
}

pub fn parseTokenMetadata(parsed: tlv.Parsed, additional_metadata_out: []MetadataAdditional) TokenMetadataParseError!TokenMetadata {
    const record = try findTokenMetadataRecord(parsed);
    return TokenMetadata.parseBody(record.value, additional_metadata_out);
}

pub fn parseTokenMetadataMint(bytes: []const u8, additional_metadata_out: []MetadataAdditional) TokenMetadataParseError!TokenMetadata {
    return parseTokenMetadata(try tlv.parseMint(bytes), additional_metadata_out);
}

pub fn parseTokenGroup(parsed: tlv.Parsed) TokenGroupParseError!TokenGroup {
    const record = try findTokenGroupRecord(parsed);
    return TokenGroup.parseBody(record.value);
}

pub fn parseTokenGroupMint(bytes: []const u8) TokenGroupParseError!TokenGroup {
    return parseTokenGroup(try tlv.parseMint(bytes));
}

pub fn parseTokenGroupMember(parsed: tlv.Parsed) TokenGroupMemberParseError!TokenGroupMember {
    const record = try findTokenGroupMemberRecord(parsed);
    return TokenGroupMember.parseBody(record.value);
}

pub fn parseTokenGroupMemberMint(bytes: []const u8) TokenGroupMemberParseError!TokenGroupMember {
    return parseTokenGroupMember(try tlv.parseMint(bytes));
}

test "public variable-extension helpers expose metadata and group parser bridge" {
    try std.testing.expect(@hasDecl(@This(), "parseTokenMetadataMint"));
    try std.testing.expect(@hasDecl(@This(), "parseTokenGroupMint"));
    try std.testing.expect(@hasDecl(@This(), "parseTokenGroupMemberMint"));
}
