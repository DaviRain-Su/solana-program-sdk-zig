use solana_sdk_zig_program_test::generate_all_vectors;
use std::path::Path;

fn main() {
    let output_dir = Path::new("test-vectors");
    generate_all_vectors(output_dir);
}
