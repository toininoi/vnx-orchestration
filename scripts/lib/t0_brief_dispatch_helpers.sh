#!/usr/bin/env bash

# Dispatch parsing helpers for generate_t0_brief.sh.

vnx_brief_extract_track_from_dispatch() {
  local file="$1"
  local track=""

  track=$(rg -n --no-heading "^[[:space:]]*\\[\\[TARGET:" "$file" 2>/dev/null | head -n 1 | sed -n 's/.*\\[\\[TARGET:\\([^]]*\\)\\]\\].*/\\1/p' || true)
  if [ -z "$track" ]; then
    track=$(sed -n 's/.*\[\[TARGET:\([^]]*\)\]\].*/\1/p' "$file" 2>/dev/null | head -n 1 || true)
  fi

  echo "$track"
}

vnx_brief_extract_gate_from_dispatch() {
  local file="$1"
  local gate=""

  gate=$(rg -n --no-heading "^[[:space:]]*Gate:" "$file" 2>/dev/null | head -n 1 | sed -n 's/^[^:]*:[[:space:]]*//p' || true)
  if [ -z "$gate" ]; then
    gate=$(sed -n 's/^[[:space:]]*Gate:[[:space:]]*//p' "$file" 2>/dev/null | head -n 1 || true)
  fi

  echo "$gate"
}

vnx_brief_derive_next_gate() {
  local current="$1"
  case "$current" in
    analysis) echo "planning" ;;
    investigation) echo "planning" ;;
    planning) echo "implementation" ;;
    implementation) echo "review" ;;
    review) echo "testing" ;;
    testing) echo "integration" ;;
    integration) echo "quality_gate" ;;
    quality_gate|validation) echo "planning" ;;
    escalation) echo "planning" ;;
    *) echo "" ;;
  esac
}
