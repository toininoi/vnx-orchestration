#!/usr/bin/env python3
"""CLI wrapper for terminal_state.json shadow writes."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))

from terminal_state_shadow import (  # noqa: E402
    TerminalUpdate,
    default_lease_expires,
    update_terminal_state,
)
from vnx_paths import ensure_env  # noqa: E402


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Write terminal_state.json in shadow mode")
    parser.add_argument("--terminal-id", required=True, help="Terminal id, e.g. T1")
    parser.add_argument("--status", required=True, help="Terminal status")
    parser.add_argument("--claimed-by", default=None, help="Claim owner (e.g. dispatch id)")
    parser.add_argument("--claimed-at", default=None, help="Claim timestamp (ISO8601)")
    parser.add_argument("--lease-expires-at", default=None, help="Lease expiration timestamp (ISO8601)")
    parser.add_argument("--last-activity", default=None, help="Last activity timestamp (ISO8601)")
    parser.add_argument("--lease-seconds", type=int, default=None, help="Auto-generate lease_expires_at from now")
    parser.add_argument("--clear-claim", action="store_true", help="Clear claim fields")
    parser.add_argument("--state-dir", default=None, help="Override state directory (defaults to VNX_STATE_DIR)")
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    paths = ensure_env()
    state_dir = args.state_dir or paths["VNX_STATE_DIR"]

    lease_expires_at = args.lease_expires_at
    if args.lease_seconds is not None and args.lease_seconds > 0:
        lease_expires_at = default_lease_expires(args.lease_seconds)

    update = TerminalUpdate(
        terminal_id=args.terminal_id,
        status=args.status,
        claimed_by=args.claimed_by,
        claimed_at=args.claimed_at,
        lease_expires_at=lease_expires_at,
        last_activity=args.last_activity,
        clear_claim=args.clear_claim,
    )

    record = update_terminal_state(state_dir=state_dir, update=update)
    print(json.dumps(record))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
