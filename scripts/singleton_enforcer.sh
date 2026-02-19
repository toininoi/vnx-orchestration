#!/bin/bash
# Singleton Enforcer - PID-safe lifecycle management with atomic lock + fingerprint validation
# Usage: source this script at the beginning of any script that needs singleton enforcement

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/process_lifecycle.sh
source "$SCRIPT_DIR/lib/process_lifecycle.sh"

enforce_singleton() {
    local script_name="${1:-$(basename "$0")}"
    local log_file="${2:-}"
    local script_path="${3:-$0}"
    local fingerprint
    # Canonicalize fingerprint to realpath first so relative invocation forms
    # (e.g. "bash receipt_processor_v4.sh") and absolute forms dedupe correctly.
    fingerprint="$(vnx_proc_realpath "$script_path")"
    if [ -z "$fingerprint" ]; then
        fingerprint="$(vnx_proc_cmdline "$$")"
    fi

    if ! vnx_proc_acquire_lock "$script_name" "$fingerprint" "$log_file" "stop_existing" "singleton_start"; then
        echo "[SINGLETON] Another instance of $script_name is already running"
        exit 0
    fi

    trap "rm -rf '$VNX_LOCKS_DIR/${script_name}.lock'; rm -f '$VNX_PIDS_DIR/${script_name}.pid' '${VNX_PIDS_DIR}/${script_name}.pid.fingerprint'" EXIT INT TERM

    echo "[SINGLETON] Lock acquired for $script_name (PID: $$)"
}

export -f enforce_singleton
