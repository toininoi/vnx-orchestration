#!/usr/bin/env bash
# VNX package hygiene check (Phase P3)
# Ensures runtime artifacts live under .vnx-data/ and not inside the dist root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"

DIST_ROOT="$VNX_HOME"
RUNTIME_DIRS=(
  "state"
  "logs"
  "dispatches"
  "receipts"
  "pids"
  "unified_reports"
  "database"
  "locks"
  ".vnx-data"
)

failures=()
for rel_path in "${RUNTIME_DIRS[@]}"; do
  target="$DIST_ROOT/$rel_path"
  if [ -e "$target" ]; then
    failures+=("$target")
  fi
done

if [ "${#failures[@]}" -gt 0 ]; then
  echo "[vnx package-check] FAILED: runtime artifacts were found inside the dist root ($DIST_ROOT):"
  for hit in "${failures[@]}"; do
    printf '  - %s\n' "$hit"
  done
  echo '[vnx package-check] Suggested fix: move runtime directories/files under ".vnx-data/" before packaging.'
  exit 1
fi

log_prefix="[vnx package-check]"
printf "%s OK: No runtime directories live inside %s.\n" "$log_prefix" "$DIST_ROOT"
