//! Package metadata for `spl_transfer_hook`.
//!
//! Unlike fixed-program SPL packages, transfer-hook consumers supply
//! the hook program id at the call site, so this scaffold does not
//! expose a single canonical `PROGRAM_ID`.

pub const PACKAGE_NAME = "spl-transfer-hook";
pub const MODULE_NAME = "spl_transfer_hook";
pub const INTERFACE_VERSION = "0.1.0";
pub const SCOPE = "on-chain/interface";
