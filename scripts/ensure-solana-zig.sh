#!/usr/bin/env bash
#
# Locate a solana-zig fork binary that can build this repository's SBF
# programs and actually emit usable artifacts for the repo's real build shape.
#
# Some release builds still print `+jmp-ext` / `+store-imm` target-feature
# warnings while successfully emitting working `.so` artifacts, so the probe
# keys off real build success + emitted output rather than warning-free stderr.
#
# Prints the absolute path to stdout on success; exits non-zero otherwise.
#
# Search order:
#   1. $SOLANA_ZIG_BIN env var (if set and executable)
#   2. $ZIG env var (if it points to a compatible solana-zig fork)
#   3. .tools/solana-zig/bin/zig under repo root
#   4. Sibling checkout ../solana-zig-bootstrap/out-smoke/host/bin/zig
#   5. $HOME/tools/zig-*-baseline/zig
#   6. Sibling checkout ../solana-zig-bootstrap/out/*/zig
#   7. $PATH lookup for `solana-zig`
#
# If nothing is found, prints a guidance message to stderr and exits 1.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"

is_solana_zig() {
  local zig_bin="$1"
  [[ -x "$zig_bin" ]] || return 1

  local targets_out
  targets_out="$("$zig_bin" targets 2>/dev/null)" || return 1
  grep -q '"sbf",' <<<"$targets_out" || return 1
  return 0
}

supports_repo_sbf_build() {
  local zig_bin="$1"
  local tmp_dir linker_script stderr_file out_file
  tmp_dir="$(mktemp -d)" || return 1
  linker_script="$tmp_dir/bpf.ld"
  stderr_file="$tmp_dir/stderr.txt"
  out_file="$tmp_dir/ensure-solana-zig-probe.so"

  cat >"$linker_script" <<'EOF'
PHDRS
{
text PT_LOAD  ;
rodata PT_LOAD ;
data PT_LOAD ;
dynamic PT_DYNAMIC ;
}

SECTIONS
{
. = SIZEOF_HEADERS;
.text : { *(.text*) } :text
.rodata : { *(.rodata*) } :rodata
.data.rel.ro : { *(.data.rel.ro*) } :rodata
.dynamic : { *(.dynamic) } :dynamic
.dynsym : { *(.dynsym) } :data
.dynstr : { *(.dynstr) } :data
.rel.dyn : { *(.rel.dyn) } :data
/DISCARD/ : {
*(.eh_frame*)
*(.gnu.hash*)
*(.hash*)
}
}
EOF

  # Intentionally mirror the repository's real build-lib surface closely.
  if ! (
    cd "$tmp_dir"
    "$zig_bin" build-lib \
      -fentry=entrypoint \
      --stack 4096 \
      -fstrip \
      -fPIC \
      -OReleaseFast \
      -target sbf-solana \
      -mcpu v2 \
      --dep solana_program_sdk \
      -Mroot="$ROOT_DIR/examples/hello.zig" \
      -OReleaseFast \
      -target sbf-solana \
      -mcpu v2 \
      -Msolana_program_sdk="$ROOT_DIR/src/root.zig" \
      -z notext \
      --cache-dir "$tmp_dir/cache" \
      --global-cache-dir "${ZIG_GLOBAL_CACHE_DIR:-$HOME/.cache/zig}" \
      --name ensure-solana-zig-probe \
      -dynamic \
      -femit-bin="$out_file" \
      --script "$linker_script"
  ) >/dev/null 2>"$stderr_file"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  [[ -s "$out_file" ]] || {
    rm -rf "$tmp_dir"
    return 1
  }

  rm -rf "$tmp_dir"
  return 0
}

try_candidate() {
  local cand="$1"
  if is_solana_zig "$cand" && supports_repo_sbf_build "$cand"; then
    printf '%s\n' "$cand"
    exit 0
  fi
}

host_bootstrap_target() {
  local os arch
  os="$(uname -s 2>/dev/null || true)"
  arch="$(uname -m 2>/dev/null || true)"

  case "$os:$arch" in
    Darwin:arm64|Darwin:aarch64) printf '%s\n' "aarch64-macos-none" ;;
    Darwin:x86_64) printf '%s\n' "x86_64-macos-none" ;;
    Linux:aarch64|Linux:arm64) printf '%s\n' "aarch64-linux-gnu" ;;
    Linux:x86_64) printf '%s\n' "x86_64-linux-gnu" ;;
    *) printf '%s\n' "native-$(printf '%s' "$os" | tr '[:upper:]' '[:lower:]')-gnu" ;;
  esac
}

if [[ -n "${SOLANA_ZIG_BIN:-}" ]]; then
  try_candidate "$SOLANA_ZIG_BIN"
  echo "SOLANA_ZIG_BIN is set but is not repository-compatible: $SOLANA_ZIG_BIN" >&2
  exit 1
fi

if [[ -n "${ZIG:-}" ]]; then
  try_candidate "$ZIG"
fi

try_candidate "$ROOT_DIR/.tools/solana-zig/bin/zig"
try_candidate "$ROOT_DIR/../solana-zig-bootstrap/out-smoke/host/bin/zig"

for cand in "$HOME"/tools/zig-*-baseline/zig; do
  try_candidate "$cand"
done

if [[ -d "$ROOT_DIR/../solana-zig-bootstrap/out" ]]; then
  for cand in "$ROOT_DIR/../solana-zig-bootstrap/out"/*/zig; do
    try_candidate "$cand"
  done
fi

if command -v solana-zig >/dev/null 2>&1; then
  try_candidate "$(command -v solana-zig)"
fi

bootstrap_dir="$ROOT_DIR/../solana-zig-bootstrap"
bootstrap_target="$(host_bootstrap_target)"

cat <<EOF >&2
solana-zig fork not found.

This repository's SBF build requires a solana-zig fork that passes the
same probe shape as the real repo build and actually emits an SBF artifact.

Options:
  - Set SOLANA_ZIG_BIN=/path/to/a compatible solana-zig fork
  - Clone and build https://github.com/joncinque/solana-zig-bootstrap
    (branch solana-1.52) into a sibling directory
  - Re-run ./scripts/ensure-solana-zig.sh after installing the fork
EOF

if [[ -d "$bootstrap_dir" ]]; then
  cat <<EOF >&2

Detected local bootstrap source checkout:
  $bootstrap_dir

No compatible compiler binary was found under that checkout. To build it:
  cd "$bootstrap_dir"
  git submodule update --init --recursive
  ./build "$bootstrap_target" baseline

Expected output:
  $bootstrap_dir/out/zig-$bootstrap_target-baseline/zig
EOF
fi
exit 1
