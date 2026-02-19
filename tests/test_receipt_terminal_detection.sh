#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/receipt_terminal_detection.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $msg (expected='$expected' actual='$actual')"
    exit 1
  fi
}

assert_eq "T1" "$(vnx_receipt_terminal_from_report_name "20260211-T1-report.md")" "T1 detection"
assert_eq "T2" "$(vnx_receipt_terminal_from_report_name "report-T2-output.md")" "T2 detection"
assert_eq "T3" "$(vnx_receipt_terminal_from_report_name "work-T3.md")" "T3 detection"
assert_eq "T1" "$(vnx_receipt_terminal_from_report_name "20260218-110750-A-behavioral-pattern-analysis.md")" "Track A detection"
assert_eq "T2" "$(vnx_receipt_terminal_from_report_name "20260218-110750-B-analysis.md")" "Track B detection"
assert_eq "T3" "$(vnx_receipt_terminal_from_report_name "20260218-110750-C-review.md")" "Track C detection"
assert_eq "T-MANAGER" "$(vnx_receipt_terminal_from_report_name "2026-T-MANAGER-summary.md")" "T-MANAGER detection"
assert_eq "T-MANAGER" "$(vnx_receipt_terminal_from_report_name "MANAGER-queue.md")" "MANAGER fallback detection"
assert_eq "" "$(vnx_receipt_terminal_from_report_name "unknown-terminal.md")" "unknown terminal"

echo "PASS: receipt terminal detection"
