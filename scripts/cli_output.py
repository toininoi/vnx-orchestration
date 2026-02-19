#!/usr/bin/env python3
"""Shared CLI output helpers for VNX scripts."""

from __future__ import annotations

import json
import sys
from typing import Any, Iterable, List, Tuple


def emit_json(payload: Any) -> None:
    """Emit JSON to stdout with a trailing newline."""
    sys.stdout.write(json.dumps(payload, ensure_ascii=False, default=str))
    if not str(payload).endswith("\n"):
        sys.stdout.write("\n")


def emit_human(text: str) -> None:
    """Emit human-readable text to stdout with a trailing newline."""
    if text.endswith("\n"):
        sys.stdout.write(text)
    else:
        sys.stdout.write(f"{text}\n")


def parse_human_flag(argv: Iterable[str]) -> Tuple[bool, List[str]]:
    """Return (human_requested, argv_without_human_flag)."""
    argv_list = list(argv)
    if "--human" not in argv_list:
        return False, argv_list
    filtered = [arg for arg in argv_list if arg != "--human"]
    return True, filtered
