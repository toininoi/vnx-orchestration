#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/t0_brief_dispatch_helpers.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $msg (expected='$expected' actual='$actual')"
    exit 1
  fi
}

dispatch_file="$(mktemp)"
cat > "$dispatch_file" <<'EOF'
[[TARGET:C]]
Gate: review
EOF

assert_eq "C" "$(vnx_brief_extract_track_from_dispatch "$dispatch_file")" "track extraction"
assert_eq "Gate: review" "$(vnx_brief_extract_gate_from_dispatch "$dispatch_file")" "gate extraction"
assert_eq "implementation" "$(vnx_brief_derive_next_gate "planning")" "gate progression"
assert_eq "" "$(vnx_brief_derive_next_gate "unknown")" "unknown gate progression"

rm -f "$dispatch_file"
echo "PASS: t0 brief dispatch helpers"
