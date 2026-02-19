#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
SCRIPTS_DIR="$VNX_HOME/scripts"
source "$SCRIPTS_DIR/singleton_enforcer.sh"
enforce_singleton "recommendations_engine_daemon"

LOOKBACK_MINUTES="${LOOKBACK_MINUTES:-60}"
SLEEP_SECONDS="${SLEEP_SECONDS:-30}"

if [ -f "$PROJECT_ROOT/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/.venv/bin/activate"
fi

while true; do
  python3 "$SCRIPTS_DIR/generate_t0_recommendations.py" --lookback "$LOOKBACK_MINUTES"
  sleep "$SLEEP_SECONDS"
done
