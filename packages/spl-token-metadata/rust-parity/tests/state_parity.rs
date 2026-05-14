use borsh::{from_slice, to_vec};
use serde::Deserialize;
use solana_address::Address;
use spl_token_metadata_interface::state::TokenMetadata;

const FIXTURE_JSON: &str = include_str!("../../src/official_parity_fixture.json");
const TOKEN_METADATA_DISCRIMINATOR: [u8; 8] = [112, 132, 90, 90, 11, 88, 157, 87];

#[derive(Debug, Deserialize)]
struct AdditionalMetadataFixture {
    key: String,
    value: String,
}

#[derive(Debug, Deserialize)]
struct StateCase {
    update_authority: [u8; 32],
    mint: [u8; 32],
    name: String,
    symbol: String,
    uri: String,
    additional_metadata: Vec<AdditionalMetadataFixture>,
    data: Vec<u8>,
}

#[derive(Debug, Deserialize)]
struct Fixture {
    states: Vec<StateCase>,
}

fn address(bytes: [u8; 32]) -> Address {
    Address::new_from_array(bytes)
}

fn option_address_bytes(value: Option<Address>) -> Option<[u8; 32]> {
    value.map(|address| address.to_bytes())
}

#[test]
fn fixture_matches_official_state_borsh_encoding() {
    let fixture: Fixture = serde_json::from_str(FIXTURE_JSON).unwrap();

    for case in &fixture.states {
        let state = TokenMetadata {
            update_authority: if case.update_authority == [0u8; 32] {
                Default::default()
            } else {
                address(case.update_authority).into()
            },
            mint: address(case.mint),
            name: case.name.clone(),
            symbol: case.symbol.clone(),
            uri: case.uri.clone(),
            additional_metadata: case
                .additional_metadata
                .iter()
                .map(|entry| (entry.key.clone(), entry.value.clone()))
                .collect(),
        };

        let mut expected = TOKEN_METADATA_DISCRIMINATOR.to_vec();
        expected.extend(to_vec(&state).unwrap());
        assert_eq!(case.data, expected);

        let parsed: TokenMetadata = from_slice(&case.data[8..]).unwrap();
        assert_eq!(
            option_address_bytes(Option::<Address>::from(parsed.update_authority)),
            option_address_bytes(Option::<Address>::from(state.update_authority))
        );
        assert_eq!(parsed.mint.to_bytes(), state.mint.to_bytes());
        assert_eq!(parsed.name, state.name);
        assert_eq!(parsed.symbol, state.symbol);
        assert_eq!(parsed.uri, state.uri);
        assert_eq!(parsed.additional_metadata, state.additional_metadata);
    }
}
