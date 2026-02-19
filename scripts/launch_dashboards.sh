#!/usr/bin/env bash
# Launch both VNX and API monitoring dashboards

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vnx_paths.sh"
# shellcheck source=lib/ops_process_control.sh
source "$SCRIPT_DIR/lib/ops_process_control.sh"
VNX_DASHBOARD="$VNX_HOME/dashboard_enhanced.html"
API_DASHBOARD_DIR="$PROJECT_ROOT/src/api/templates"
ORCHESTRATION_DIR="$PROJECT_ROOT/.claude/orchestration"
PROCESS_LOG="$ORCHESTRATION_DIR/logs/process_lifecycle.log"

# Create logs directory if it doesn't exist
mkdir -p "$ORCHESTRATION_DIR/logs"

echo "🚀 Starting Dashboard Services..."
echo ""

# Gracefully stop existing dashboard servers before restart.
vnx_stop_listening_port_processes "dashboard_server" "8080" "$PROCESS_LOG" "dashboard_restart" 3 "http.server 8080" || true
vnx_stop_by_fingerprints "dashboard_server" "$PROCESS_LOG" "dashboard_restart" 3 "http.server 8080" || true
vnx_stop_listening_port_processes "dashboard_server" "8081" "$PROCESS_LOG" "dashboard_restart" 3 "http.server 8081" || true
vnx_stop_by_fingerprints "dashboard_server" "$PROCESS_LOG" "dashboard_restart" 3 "http.server 8081" || true
sleep 1

# 1. Start VNX System Dashboard (port 8080)
if [ -f "$VNX_DASHBOARD" ]; then
    cd "$(dirname "$VNX_DASHBOARD")"
    nohup python3 -m http.server 8080 > "$ORCHESTRATION_DIR/logs/vnx_dashboard.log" 2>&1 &
    VNX_PID=$!
    echo "✅ VNX System Dashboard started (PID: $VNX_PID)"
    echo "   📊 URL: http://localhost:8080/dashboard_enhanced.html"
    echo ""
else
    echo "⚠️  VNX dashboard not found at: $VNX_DASHBOARD"
fi

# 2. Start API Monitoring Dashboard (port 8081)
if [ -f "$API_DASHBOARD_DIR/monitoring_dashboard.html" ]; then
    cd "$API_DASHBOARD_DIR"
    nohup python3 -m http.server 8081 > "$ORCHESTRATION_DIR/logs/api_dashboard.log" 2>&1 &
    API_PID=$!
    echo "✅ API Monitoring Dashboard started (PID: $API_PID)"
    echo "   📊 URL: http://localhost:8081/monitoring_dashboard.html"
    echo ""
else
    echo "⚠️  API monitoring dashboard not found"
fi

# 3. Check if the main API is running for live data
if lsof -i:8077 >/dev/null 2>&1; then
    echo "✅ API server detected on port 8077 (development)"
    echo "   The monitoring dashboard will show live data"
elif lsof -i:8000 >/dev/null 2>&1; then
    echo "✅ API server detected on port 8000 (production)"
    echo "   The monitoring dashboard will show live data"
else
    echo "⚠️  No API server detected - monitoring dashboard will work in offline mode"
    echo "   To start API: uvicorn src.api.main:app --host 0.0.0.0 --port 8077 --reload"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "                       DASHBOARDS AVAILABLE                        "
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "📊 VNX System Dashboard:     http://localhost:8080/dashboard_enhanced.html"
echo "   - VNX orchestration status"
echo "   - Dispatch queue monitoring"
echo "   - Terminal states"
echo ""
echo "📊 API Monitoring Dashboard: http://localhost:8081/monitoring_dashboard.html"
echo "   - Real-time crawl monitoring"
echo "   - Memory and performance metrics"
echo "   - SSE event streams"
echo "   - Browser pool status"
echo ""
echo "📋 Logs:"
echo "   - VNX: tail -f $ORCHESTRATION_DIR/logs/vnx_dashboard.log"
echo "   - API: tail -f $ORCHESTRATION_DIR/logs/api_dashboard.log"
echo "   - Lifecycle: tail -f $PROCESS_LOG"
echo ""
echo "🛑 To stop dashboards:"
echo "   bash \"$VNX_HOME/scripts/launch_dashboards.sh\""
echo "   (restart path gracefully stops existing dashboard servers first)"
echo ""

# Optional: Auto-open in browser (Mac only)
if command -v open >/dev/null 2>&1; then
    read -t 5 -p "Open dashboards in browser? (y/N) " -n 1 -r || true
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sleep 1
        open "http://localhost:8080/dashboard_enhanced.html"
        open "http://localhost:8081/monitoring_dashboard.html"
    fi
fi
