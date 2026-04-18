#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
TEMPLATE_DIR="$ROOT_DIR/template/hello-world"
TARGET_DIR="${1:-}"

usage() {
  cat <<'EOF'
Create a new project directory from the current starter template.

Usage:
  ./scripts/new.sh <target-dir>

Example:
  ./scripts/new.sh ../my-solana-program
EOF
}

if [[ -z "$TARGET_DIR" || "$TARGET_DIR" == "-h" || "$TARGET_DIR" == "--help" ]]; then
  usage
  exit 0
fi

TARGET_DIR="$(python3 - <<'PY' "$TARGET_DIR"
import os, sys
print(os.path.abspath(sys.argv[1]))
PY
)"

if [[ -e "$TARGET_DIR" ]]; then
  echo "target already exists: $TARGET_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp -R "$TEMPLATE_DIR"/. "$TARGET_DIR"/

python3 - <<'PY' "$TARGET_DIR/build.zig.zon.in" "$TARGET_DIR/program-test/build.zig.zon.in" "$ROOT_DIR"
import os, pathlib, sys
root = pathlib.Path(sys.argv[3]).resolve()
for file_name in sys.argv[1:3]:
    path = pathlib.Path(file_name).resolve()
    rel = os.path.relpath(root, path.parent)
    text = path.read_text()
    text = text.replace('__SOLANA_PROGRAM_SDK_PATH__', rel.replace('\\', '/'))
    out_path = path.with_suffix('')
    out_path.write_text(text)
    path.unlink()
PY

chmod +x \
  "$TARGET_DIR/scripts/bootstrap.sh" \
  "$TARGET_DIR/scripts/ensure-elf2sbpf.sh" \
  "$TARGET_DIR/scripts/new.sh" \
  "$TARGET_DIR/program-test/test.sh" \
  "$TARGET_DIR/program-test/install-build-deps.sh"

cat <<EOF
Created starter project at:
  $TARGET_DIR

Next steps:
  cd "$TARGET_DIR"
  ./scripts/bootstrap.sh
  zig build test --summary all
  ./program-test/test.sh

Then edit:
  src/main.zig
EOF
