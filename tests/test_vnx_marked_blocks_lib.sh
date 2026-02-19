#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/vnx_marked_blocks.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $msg (expected='$expected' actual='$actual')"
    exit 1
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local msg="$3"
  if ! grep -Fq "$pattern" "$file"; then
    echo "FAIL: $msg (missing '$pattern')"
    exit 1
  fi
}

MARKER_BEGIN="<!-- VNX:BEGIN BOOTSTRAP -->"
MARKER_END="<!-- VNX:END BOOTSTRAP -->"

snippet="$(mktemp)"
target="$(mktemp)"
block="$(mktemp)"

cat > "$snippet" <<'EOF'
Initial snippet line
EOF

vnx_build_block_file "$snippet" "$block" "$MARKER_BEGIN" "$MARKER_END"
assert_file_contains "$block" "$MARKER_BEGIN" "block should include begin marker"
assert_file_contains "$block" "Initial snippet line" "block should include snippet body"
assert_file_contains "$block" "$MARKER_END" "block should include end marker"

rm -f "$target"
set +e
vnx_upsert_marked_block "$target" "$snippet" "$MARKER_BEGIN" "$MARKER_END"
status=$?
set -e
assert_eq "1" "$status" "missing target should be created"
assert_file_contains "$target" "Initial snippet line" "created target should include snippet"

set +e
vnx_upsert_marked_block "$target" "$snippet" "$MARKER_BEGIN" "$MARKER_END"
status=$?
set -e
assert_eq "0" "$status" "same snippet should be unchanged"

cat > "$snippet" <<'EOF'
Updated snippet line
EOF

set +e
vnx_upsert_marked_block "$target" "$snippet" "$MARKER_BEGIN" "$MARKER_END"
status=$?
set -e
assert_eq "2" "$status" "changed snippet should update"
assert_file_contains "$target" "Updated snippet line" "updated target should include new snippet"

rm -f "$snippet" "$target" "$block"
echo "PASS: vnx marked block helpers"
