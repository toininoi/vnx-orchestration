#!/bin/bash
set -euo pipefail
SERVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4173}"

if command -v python3 >/dev/null 2>&1; then
  echo "Serving dashboard from $SERVICE_DIR on http://localhost:$PORT (dashboard asset at /dashboard/index.html)"
  python3 "$SERVICE_DIR/dashboard/serve_dashboard.py"
else
  echo "python3 is required to serve the dashboard."
  exit 1
fi
