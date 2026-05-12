//! Public ATA derivation surface.
//!
//! The real PDA derivation implementation lands in the follow-up
//! `spl-ata-address-derivation` feature. This foundation feature only
//! establishes the package/module API shape so callers can import the
//! names from `@import("spl_ata")`.

const sol = @import("solana_program_sdk");

const Pubkey = sol.Pubkey;

pub const ProgramDerivedAddress = sol.pda.ProgramDerivedAddress;

pub fn findAddress(
    _: *const Pubkey,
    _: *const Pubkey,
    _: *const Pubkey,
) ProgramDerivedAddress {
    @panic("spl_ata.findAddress is not implemented yet");
}

pub fn findAddressClassic(
    _: *const Pubkey,
    _: *const Pubkey,
) ProgramDerivedAddress {
    @panic("spl_ata.findAddressClassic is not implemented yet");
}

pub fn findAddressToken2022(
    _: *const Pubkey,
    _: *const Pubkey,
) ProgramDerivedAddress {
    @panic("spl_ata.findAddressToken2022 is not implemented yet");
}
