#!/usr/bin/env bash
#
# Locate a solana-zig fork binary that can build this generated project's
# SBF program surface without the known false-positive probe problem where
# `-target sbf-solana -mcpu v2` succeeds but the real build still warns about
# unsupported `+jmp-ext` / `+store-imm` features.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
BUILD_ZON="$ROOT_DIR/build.zig.zon"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to resolve the solana_program_sdk path from build.zig.zon" >&2
  exit 1
fi

SDK_ROOT="$({ python3 - <<'PY' "$BUILD_ZON"
import pathlib, re, sys
path = pathlib.Path(sys.argv[1]).resolve()
text = path.read_text()
match = re.search(r'\.solana_program_sdk\s*=\s*\{[^}]*\.path\s*=\s*"([^"]+)"', text, re.S)
if not match:
    raise SystemExit(1)
print((path.parent / match.group(1)).resolve())
PY
} )"

is_solana_zig() {
  local zig_bin="$1"
  [[ -x "$zig_bin" ]] || return 1

  local targets_out
  targets_out="$("$zig_bin" targets 2>/dev/null)" || return 1
  grep -q '"sbf",' <<<"$targets_out" || return 1
  return 0
}

supports_project_sbf_build() {
  local zig_bin="$1"
  local tmp_dir linker_script stderr_file
  tmp_dir="$(mktemp -d)" || return 1
  linker_script="$tmp_dir/bpf.ld"
  stderr_file="$tmp_dir/stderr.txt"

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
      -Mroot="$ROOT_DIR/src/main.zig" \
      -OReleaseFast \
      -target sbf-solana \
      -mcpu v2 \
      -Msolana_program_sdk="$SDK_ROOT/src/root.zig" \
      -z notext \
      --cache-dir "$tmp_dir/cache" \
      --global-cache-dir "${ZIG_GLOBAL_CACHE_DIR:-$HOME/.cache/zig}" \
      --name ensure-solana-zig-probe \
      -dynamic \
      --script "$linker_script"
  ) >/dev/null 2>"$stderr_file"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  if grep -q 'not a recognized feature for this target' "$stderr_file"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  rm -rf "$tmp_dir"
  return 0
}

try_candidate() {
  local cand="$1"
  if is_solana_zig "$cand" && supports_project_sbf_build "$cand"; then
    printf '%s\n' "$cand"
    exit 0
  fi
}

if [[ -n "${SOLANA_ZIG_BIN:-}" ]]; then
  try_candidate "$SOLANA_ZIG_BIN"
  echo "SOLANA_ZIG_BIN is set but is not project-compatible: $SOLANA_ZIG_BIN" >&2
  exit 1
fi

if [[ -n "${ZIG:-}" ]]; then
  try_candidate "$ZIG"
fi

if command -v solana-zig >/dev/null 2>&1; then
  try_candidate "$(command -v solana-zig)"
fi

for cand in "$HOME"/tools/zig-*-baseline/zig; do
  try_candidate "$cand"
done

cat <<EOF >&2
solana-zig fork not found.

This starter project's SBF build requires a solana-zig fork that passes the
same probe shape as the real project build. Candidates that still warn about
unsupported '+jmp-ext' / '+store-imm' target features are rejected.

Options:
  - Set SOLANA_ZIG_BIN=/path/to/a compatible solana-zig fork
  - Add a compatible solana-zig binary to PATH as 'solana-zig'
  - Re-run ./scripts/ensure-solana-zig.sh after installing the fork
EOF
exit 1
