//! Package metadata for `spl_token_metadata`.
//!
//! Token-metadata interface consumers supply the metadata program id
//! at the call site, so this scaffold intentionally does not expose a
//! single canonical `PROGRAM_ID`.

pub const PACKAGE_NAME = "spl-token-metadata";
pub const MODULE_NAME = "spl_token_metadata";
pub const INTERFACE_VERSION = "0.1.0";
pub const INTERFACE_NAMESPACE = "spl_token_metadata_interface";
pub const SCOPE = "on-chain/interface";
