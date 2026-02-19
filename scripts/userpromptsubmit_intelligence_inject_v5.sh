#!/bin/bash

# userpromptsubmit_intelligence_inject.sh - V5 Compatible with Claude Code 2.1+
# Purpose: Inject VNX intelligence updates into T0 terminal as hook
# Compatible with Claude Code 2.1.37 hook decision system
#
# Changes in V5:
# - Capture all output to inject into JSON additionalContext
# - Output proper JSON decision object for Claude Code 2.1+
# - Fix unbound variable errors
# - Output format: {"decision": "allow", "additionalContext": "message"}

set -euo pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${VNX_STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/.vnx-data/state}"
BRIEF="$CACHE_DIR/t0_brief.json"
TAGS_DIGEST="$CACHE_DIR/t0_tags_digest.json"
QUALITY_DIGEST="$CACHE_DIR/t0_quality_digest.json"
QUALITY="$CACHE_DIR/t0_quality_gates.json"
RECOMMENDATIONS="$CACHE_DIR/t0_recommendations.json"

# Cache files for change detection
LAST_HASH="$CACHE_DIR/.last_brief_hash"
LAST_TAGS_HASH="$CACHE_DIR/.last_tags_hash"
LAST_QUALITY_HASH="$CACHE_DIR/.last_quality_hash"
LAST_RECOMMENDATIONS_HASH="$CACHE_DIR/.last_recommendations_hash"

# Capture all output messages
OUTPUT_MESSAGES=""

# Initialize all change flags
brief_changed=false
tags_changed=false
quality_changed=false
recommendations_changed=false

# Helper function to add message to output
add_message() {
  if [[ -n "$OUTPUT_MESSAGES" ]]; then
    OUTPUT_MESSAGES="${OUTPUT_MESSAGES}\n$1"
  else
    OUTPUT_MESSAGES="$1"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Part 1: Check brief changes
# ═══════════════════════════════════════════════════════════════

# Check if brief exists
if [[ ! -f "$BRIEF" ]]; then
  # Intelligence missing - output warning but allow prompt
  echo '{"decision": "allow", "additionalContext": "⚠️ VNX Intelligence not available - dispatcher not running"}'
  exit 0
fi

# Check if brief changed
current_hash=$(sha256sum "$BRIEF" | cut -d' ' -f1)

if [[ -f "$LAST_HASH" ]]; then
  last_hash=$(cat "$LAST_HASH")
  if [[ "$current_hash" != "$last_hash" ]]; then
    brief_changed=true
  fi
else
  # First run - treat as changed
  brief_changed=true
fi

# ═══════════════════════════════════════════════════════════════
# Part 2: Check tags digest changes
# ═══════════════════════════════════════════════════════════════

if [[ -f "$TAGS_DIGEST" ]]; then
  current_tags_hash=$(sha256sum "$TAGS_DIGEST" | cut -d' ' -f1)

  if [[ -f "$LAST_TAGS_HASH" ]]; then
    last_tags_hash=$(cat "$LAST_TAGS_HASH")
    if [[ "$current_tags_hash" != "$last_tags_hash" ]]; then
      tags_changed=true
    fi
  else
    tags_changed=true
  fi
fi

# ═══════════════════════════════════════════════════════════════
# Part 3: Check quality digest changes
# ═══════════════════════════════════════════════════════════════

if [[ -f "$QUALITY" ]]; then
  current_quality_hash=$(sha256sum "$QUALITY" | cut -d' ' -f1)

  if [[ -f "$LAST_QUALITY_HASH" ]]; then
    last_quality_hash=$(cat "$LAST_QUALITY_HASH")
    if [[ "$current_quality_hash" != "$last_quality_hash" ]]; then
      quality_changed=true
    fi
  else
    quality_changed=true
  fi
fi

# ═══════════════════════════════════════════════════════════════
# Part 4: Check recommendations changes
# ═══════════════════════════════════════════════════════════════

if [[ -f "$RECOMMENDATIONS" ]]; then
  current_recommendations_hash=$(cat "$RECOMMENDATIONS" | sha256sum | cut -d' ' -f1)

  if [[ ! -f "$LAST_RECOMMENDATIONS_HASH" ]] || [[ "$current_recommendations_hash" != "$(cat "$LAST_RECOMMENDATIONS_HASH" 2>/dev/null)" ]]; then
    recommendations_changed=true
  fi
fi

# ═══════════════════════════════════════════════════════════════
# Part 5: Build output messages based on changes
# ═══════════════════════════════════════════════════════════════

# Nothing changed - output nothing special
if [[ "$brief_changed" == false ]] && [[ "$tags_changed" == false ]] && [[ "$quality_changed" == false ]] && [[ "$recommendations_changed" == false ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# --- Brief Changed ---
if [[ "$brief_changed" == true ]]; then
  # Extract key metrics from brief
  T1_STATUS=$(jq -r '.terminals.T1.status // "unknown"' "$BRIEF")
  T1_GATE=$(jq -r '.tracks.A.current_gate // "unknown"' "$BRIEF")
  T2_STATUS=$(jq -r '.terminals.T2.status // "unknown"' "$BRIEF")
  T2_GATE=$(jq -r '.tracks.B.current_gate // "unknown"' "$BRIEF")
  T3_STATUS=$(jq -r '.terminals.T3.status // "unknown"' "$BRIEF")
  T3_GATE=$(jq -r '.tracks.C.current_gate // "unknown"' "$BRIEF")

  PENDING=$(jq -r '.queues.pending // 0' "$BRIEF")
  CONFLICTS=$(jq -r '.queues.conflicts // 0' "$BRIEF")

  # Build status message
  STATUS_MSG="📊 Intelligence Updated:\nT1=${T1_STATUS}@${T1_GATE} | T2=${T2_STATUS}@${T2_GATE} | T3=${T3_STATUS}@${T3_GATE}\nQueue=${PENDING} | Conflicts=${CONFLICTS}"

  # Add next steps hint
  STATUS_MSG="${STATUS_MSG}\n\nNext steps before creating dispatches:\n1. Check terminal readiness and gate positions\n2. Review active_work and blockers in t0_brief.json\n3. Verify no conflicts with existing dispatches"

  add_message "$STATUS_MSG"

  # Cache current hash
  echo "$current_hash" > "$LAST_HASH"
fi

# --- Tags Digest Changed ---
if [[ "$tags_changed" == true ]] && [[ -f "$TAGS_DIGEST" ]]; then
  REPORTS_7D=$(jq -r '.reports_7d // 0' "$TAGS_DIGEST")
  TOP_TAG=$(jq -r '.top_tags[0].tag // "none"' "$TAGS_DIGEST" 2>/dev/null)
  TOP_COUNT=$(jq -r '.top_tags[0].count // 0' "$TAGS_DIGEST" 2>/dev/null)

  MSG="📑 Intelligence Digest Updated: ${REPORTS_7D} new reports (7d), top tag: ${TOP_TAG} (${TOP_COUNT})\n   See: t0_tags_digest.json for historical context by tag"
  add_message "$MSG"

  # Cache current tags hash
  echo "$current_tags_hash" > "$LAST_TAGS_HASH"
fi

# --- Quality Digest Changed ---
if [[ "$quality_changed" == true ]] && [[ -f "$QUALITY_DIGEST" ]]; then
  HOTSPOTS=$(jq -r '.total_hotspots // 0' "$QUALITY_DIGEST")
  CRITICAL=$(jq -r '.risk_flags.critical_count // 0' "$QUALITY_DIGEST")

  MSG="⚠️ Quality Hotspots: ${HOTSPOTS} areas need attention"
  if [[ "$CRITICAL" -gt 0 ]]; then
    MSG="${MSG} (${CRITICAL} CRITICAL)"
  fi
  MSG="${MSG}\n   See: t0_quality_digest.json for detailed analysis"

  add_message "$MSG"

  # Cache current quality hash
  echo "$current_quality_hash" > "$LAST_QUALITY_HASH"
fi

# --- Recommendations Changed ---
if [[ "$recommendations_changed" == true ]] && [[ -f "$RECOMMENDATIONS" ]]; then
  TOTAL_REC=$(jq -r '.total_recommendations // 0' "$RECOMMENDATIONS")

  if [[ "$TOTAL_REC" -gt 0 ]]; then
    # Extract first 2 recommendations for display
    FIRST_REC=$(jq -r '.recommendations[0] | "\(.trigger): \(.gate // .action)"' "$RECOMMENDATIONS" 2>/dev/null || echo "none")
    SECOND_REC=$(jq -r '.recommendations[1] | "\(.trigger): \(.gate // .action)"' "$RECOMMENDATIONS" 2>/dev/null || echo "")

    MSG="🎯 Recommendations Available: ${TOTAL_REC} new dispatch suggestions\n   • ${FIRST_REC}"
    if [[ -n "$SECOND_REC" ]] && [[ "$SECOND_REC" != "null: null" ]]; then
      MSG="${MSG}\n   • ${SECOND_REC}"
    fi
    if [[ "$TOTAL_REC" -gt 2 ]]; then
      MSG="${MSG}\n   ... and $((TOTAL_REC - 2)) more in t0_recommendations.json"
    fi

    add_message "$MSG"
  fi

  # Cache current recommendations hash
  echo "$current_recommendations_hash" > "$LAST_RECOMMENDATIONS_HASH"
fi

# ═══════════════════════════════════════════════════════════════
# Part 6: Output JSON decision for Claude Code 2.1+
# ═══════════════════════════════════════════════════════════════

# Escape the output messages for JSON (replace newlines and quotes)
ESCAPED_MESSAGES=$(echo -e "$OUTPUT_MESSAGES" | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

# Output JSON decision object (required for Claude Code 2.1+)
if [[ -n "$ESCAPED_MESSAGES" ]]; then
  echo "{\"decision\": \"allow\", \"additionalContext\": \"${ESCAPED_MESSAGES}\"}"
else
  echo '{"decision": "allow"}'
fi