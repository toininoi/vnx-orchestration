#!/usr/bin/env bash
set -euo pipefail

TERMINAL="${1:?Usage: vnx_rotate.sh TERMINAL /path/to/handover.md}"
HANDOVER_PATH="${2:?Usage: vnx_rotate.sh TERMINAL /path/to/handover.md}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

_early_cleanup() {
  rm -rf "$_PROJECT_ROOT/.vnx-data/locks/rotation_${TERMINAL}.lock" 2>/dev/null || true
}
trap _early_cleanup EXIT INT TERM

if [[ "${VNX_CONTEXT_ROTATION_ENABLED:-0}" != "1" ]]; then
  exit 0
fi

source "$SCRIPT_DIR/lib/_vnx_hook_common.sh"
source "$SCRIPT_DIR/../scripts/pane_config.sh"

mkdir -p "$VNX_LOGS_DIR" "$VNX_STATE_DIR" 2>/dev/null || true
LOG="$VNX_LOGS_DIR/vnx_rotate_${TERMINAL}.log"
SIGNAL_FILE="$VNX_STATE_DIR/rotation_clear_done_${TERMINAL}"

log() {
  echo "[$(date +%H:%M:%S)] $*" >> "$LOG" 2>/dev/null || true
}

cleanup() {
  vnx_release_lock "rotation_${TERMINAL}"
  log "Lock released (cleanup)"
}
trap cleanup EXIT INT TERM

PANE_ID="$(get_pane_id "$TERMINAL")"
log "Pane resolved: $TERMINAL -> $PANE_ID"

if ! tmux has-session -t vnx 2>/dev/null; then
  log "ERROR: No vnx tmux session found"
  exit 1
fi

log "Starting context rotation for $TERMINAL"
rm -f "$SIGNAL_FILE"

sleep 3

log "Sending /clear to pane $PANE_ID"
tmux send-keys -t "$PANE_ID" Escape
sleep 1
tmux send-keys -t "$PANE_ID" "/clear" Enter

log "Waiting for /clear completion..."
WAITED=0
while [[ ! -f "$SIGNAL_FILE" ]] && (( WAITED < 15 )); do
  sleep 1
  WAITED=$((WAITED + 1))
done

if [[ ! -f "$SIGNAL_FILE" ]]; then
  log "WARNING: Signal file not created after 15s, proceeding with fallback delay"
  sleep 5
fi
rm -f "$SIGNAL_FILE"

PROMPT="Context rotation voltooid. Lees het handover document op:
${HANDOVER_PATH}

Ga verder met het resterende werk zoals beschreven in het handover document. Begin met het lezen van dat bestand."

log "Sending continuation prompt"
echo "$PROMPT" | tmux load-buffer -
tmux paste-buffer -t "$PANE_ID"
sleep 0.5
tmux send-keys -t "$PANE_ID" Enter

log "Rotation complete for $TERMINAL"
exit 0
