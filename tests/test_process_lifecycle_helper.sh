#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export VNX_HOME="$ROOT_DIR/.claude/vnx-system"
export VNX_DATA_DIR="$(mktemp -d /tmp/vnx-proc-test.XXXXXX)"

# shellcheck source=lib/process_lifecycle.sh
source "$VNX_HOME/scripts/lib/process_lifecycle.sh"

LOG_FILE="$VNX_DATA_DIR/process_lifecycle_test.log"

cleanup() {
  pkill -P $$ 2>/dev/null || true
  rm -rf "$VNX_DATA_DIR"
}
trap cleanup EXIT

echo "== process_lifecycle helper tests =="

mkdir -p "$VNX_PIDS_DIR" "$VNX_LOCKS_DIR"


echo "[1] fingerprint mismatch does not kill process"
sleep 30 &
sleep_pid=$!
pid_file="$VNX_PIDS_DIR/mismatch_test.pid"
vnx_proc_write_pidfile "$pid_file" "$sleep_pid" "/tmp/does_not_match"
if vnx_proc_stop_pidfile "mismatch_test" "$pid_file" "$LOG_FILE" "mismatch_test" 1; then
  echo "expected mismatch stop to fail"
  exit 1
fi
if ! kill -0 "$sleep_pid" 2>/dev/null; then
  echo "mismatched process was killed unexpectedly"
  exit 1
fi
kill -KILL "$sleep_pid" 2>/dev/null || true

echo "[2] graceful shutdown path"
graceful_script="$VNX_DATA_DIR/graceful.sh"
cat > "$graceful_script" <<'EOF'
#!/bin/bash
while true; do sleep 1; done
EOF
chmod +x "$graceful_script"
"$graceful_script" &
graceful_pid=$!
graceful_fingerprint="$graceful_script"
pid_file="$VNX_PIDS_DIR/graceful_test.pid"
vnx_proc_write_pidfile "$pid_file" "$graceful_pid" "$graceful_fingerprint"
vnx_proc_stop_pidfile "graceful_test" "$pid_file" "$LOG_FILE" "graceful_test" 3
sleep 0.5
if kill -0 "$graceful_pid" 2>/dev/null && vnx_proc_matches_fingerprint "$graceful_pid" "$graceful_fingerprint"; then
  echo "graceful process still running"
  exit 1
fi
if ! grep -q "process=graceful_test event=stop" "$LOG_FILE"; then
  echo "expected stop event missing for graceful shutdown"
  exit 1
fi
if grep -q "event=forced_kill" "$LOG_FILE"; then
  echo "unexpected forced kill during graceful shutdown"
  exit 1
fi

echo "[3] forced kill only after timeout"
stubborn_script="$VNX_DATA_DIR/stubborn.py"
cat > "$stubborn_script" <<'EOF'
import signal
import time

signal.signal(signal.SIGTERM, signal.SIG_IGN)

while True:
    time.sleep(1)
EOF
python3 "$stubborn_script" &
stubborn_pid=$!
stubborn_fingerprint="$stubborn_script"
pid_file="$VNX_PIDS_DIR/stubborn_test.pid"
vnx_proc_write_pidfile "$pid_file" "$stubborn_pid" "$stubborn_fingerprint"
sleep 0.5
vnx_proc_stop_pidfile "stubborn_test" "$pid_file" "$LOG_FILE" "stubborn_test" 1
sleep 0.5
if kill -0 "$stubborn_pid" 2>/dev/null && vnx_proc_matches_fingerprint "$stubborn_pid" "$stubborn_fingerprint"; then
  echo "stubborn process still running after forced kill"
  exit 1
fi
if ! grep -q "event=forced_kill" "$LOG_FILE"; then
  echo "expected forced_kill log entry missing"
  echo "stubborn_fingerprint=$stubborn_fingerprint"
  echo "stubborn_cmdline=$(vnx_proc_cmdline "$stubborn_pid")"
  ps -p "$stubborn_pid" -o pid=,command= 2>/dev/null || true
  cat "$LOG_FILE" || true
  exit 1
fi

echo "OK"
