use bytemuck::{bytes_of, try_from_bytes};
use serde::Deserialize;
use spl_discriminator::SplDiscriminate;
use spl_token_group_interface::state::{TokenGroup, TokenGroupMember};

const FIXTURE_JSON: &str = include_str!("../../src/official_parity_fixture.json");

#[derive(Debug, Deserialize)]
struct Discriminators {
    token_group: [u8; 8],
    token_group_member: [u8; 8],
}

#[derive(Debug, Deserialize)]
struct TokenGroupCase {
    update_authority: [u8; 32],
    mint: [u8; 32],
    size: u64,
    max_size: u64,
    data: Vec<u8>,
}

#[derive(Debug, Deserialize)]
struct TokenGroupMemberCase {
    mint: [u8; 32],
    group: [u8; 32],
    member_number: u64,
    data: Vec<u8>,
}

#[derive(Debug, Deserialize)]
struct Fixture {
    discriminators: Discriminators,
    token_groups: Vec<TokenGroupCase>,
    token_group_members: Vec<TokenGroupMemberCase>,
}

#[test]
fn fixture_matches_official_group_state_discriminators() {
    let fixture: Fixture = serde_json::from_str(FIXTURE_JSON).unwrap();

    assert_eq!(fixture.discriminators.token_group, TokenGroup::SPL_DISCRIMINATOR_SLICE);
    assert_eq!(
        fixture.discriminators.token_group_member,
        TokenGroupMember::SPL_DISCRIMINATOR_SLICE
    );
}

#[test]
fn fixture_matches_official_group_state_layouts() {
    let fixture: Fixture = serde_json::from_str(FIXTURE_JSON).unwrap();

    for case in &fixture.token_groups {
        assert_eq!(fixture.discriminators.token_group.as_slice(), &case.data[..8]);
        let parsed = try_from_bytes::<TokenGroup>(&case.data[8..]).unwrap();
        assert_eq!(case.update_authority.as_slice(), bytes_of(&parsed.update_authority));
        assert_eq!(case.mint, parsed.mint.to_bytes());
        assert_eq!(case.size, u64::from(parsed.size));
        assert_eq!(case.max_size, u64::from(parsed.max_size));

        let mut expected = TokenGroup::SPL_DISCRIMINATOR_SLICE.to_vec();
        expected.extend_from_slice(bytes_of(parsed));
        assert_eq!(case.data, expected);
    }

    for case in &fixture.token_group_members {
        assert_eq!(fixture.discriminators.token_group_member.as_slice(), &case.data[..8]);
        let parsed = try_from_bytes::<TokenGroupMember>(&case.data[8..]).unwrap();
        assert_eq!(case.mint, parsed.mint.to_bytes());
        assert_eq!(case.group, parsed.group.to_bytes());
        assert_eq!(case.member_number, u64::from(parsed.member_number));

        let mut expected = TokenGroupMember::SPL_DISCRIMINATOR_SLICE.to_vec();
        expected.extend_from_slice(bytes_of(parsed));
        assert_eq!(case.data, expected);
    }
}
