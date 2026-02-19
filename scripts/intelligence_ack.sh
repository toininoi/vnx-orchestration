#!/bin/bash
# Intelligence Acknowledgement Script
# Purpose: Validate T0 has read intelligence files and set ACK flag
# Token budget: ~50 tokens output
# Returns: approve/deny for hook enforcement

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
STATE_DIR="$VNX_STATE_DIR"
CACHE_DIR="${STATE_DIR}/cache"
BRIEF="${STATE_DIR}/t0_brief.json"
PROGRESS="${STATE_DIR}/progress_state.yaml"
ACK_FLAG="${CACHE_DIR}/intelligence_ack.flag"
HASH_CACHE="${CACHE_DIR}/intelligence.hash"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Function: Calculate hash of intelligence files
calculate_hash() {
  if [[ -f "$BRIEF" ]] && [[ -f "$PROGRESS" ]]; then
    cat "$BRIEF" "$PROGRESS" | sha256sum | cut -d' ' -f1
  else
    echo "missing"
  fi
}

# Function: Check if ACK flag is valid for current intelligence
check_ack() {
  local current_hash
  current_hash=$(calculate_hash)

  # If intelligence files missing, deny
  if [[ "$current_hash" == "missing" ]]; then
    echo "deny: Intelligence files missing (t0_brief.json or progress_state.yaml)"
    exit 1
  fi

  # If ACK flag doesn't exist, deny
  if [[ ! -f "$ACK_FLAG" ]]; then
    echo "deny: No intelligence acknowledgement. Read t0_brief.json and progress_state.yaml, then run: touch ${ACK_FLAG}"
    exit 1
  fi

  # If hash cache doesn't exist, deny
  if [[ ! -f "$HASH_CACHE" ]]; then
    echo "deny: No intelligence hash cached. Run intelligence refresh."
    exit 1
  fi

  # Check if cached hash matches current intelligence
  local cached_hash
  cached_hash=$(cat "$HASH_CACHE")

  if [[ "$cached_hash" != "$current_hash" ]]; then
    # Intelligence changed since last ACK - require re-read
    rm -f "$ACK_FLAG"
    echo "deny: Intelligence stale (hash mismatch). Re-read t0_brief.json and progress_state.yaml, then run: touch ${ACK_FLAG}"
    exit 1
  fi

  # ACK is valid
  echo "approve"
  exit 0
}

# Main execution
check_ack
