#!/usr/bin/env python3
"""Checksum utilities for VNX state integrity checks."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

CHECKSUM_SUFFIX = ".sha256"
CHUNK_SIZE = 1024 * 1024


def compute_checksum(path: str | Path) -> str:
    """Compute a SHA-256 checksum for a file."""
    file_path = Path(path)
    digest = hashlib.sha256()
    with file_path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _checksum_path(path: str | Path) -> Path:
    return Path(f"{path}{CHECKSUM_SUFFIX}")


def write_checksum(path: str | Path) -> str:
    """Compute and persist checksum to a sidecar file."""
    file_path = Path(path)
    checksum = compute_checksum(file_path)
    checksum_path = _checksum_path(file_path)
    checksum_path.write_text(f"{checksum}\n", encoding="utf-8")
    return checksum


def verify_checksum(path: str | Path) -> bool:
    """Verify checksum against a sidecar file."""
    file_path = Path(path)
    checksum_path = _checksum_path(file_path)
    if not checksum_path.exists():
        raise FileNotFoundError(f"Missing checksum file: {checksum_path}")
    expected = checksum_path.read_text(encoding="utf-8").strip().split()[0]
    actual = compute_checksum(file_path)
    return actual == expected


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="VNX state integrity helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    compute = subparsers.add_parser("compute", help="Compute checksum for file")
    compute.add_argument("path", help="File path")

    write = subparsers.add_parser("write", help="Write checksum sidecar")
    write.add_argument("path", help="File path")

    verify = subparsers.add_parser("verify", help="Verify checksum sidecar")
    verify.add_argument("path", help="File path")

    return parser


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()

    try:
        if args.command == "compute":
            print(compute_checksum(args.path))
            return 0
        if args.command == "write":
            checksum = write_checksum(args.path)
            print(checksum)
            return 0
        if args.command == "verify":
            if verify_checksum(args.path):
                print("ok")
                return 0
            print("mismatch")
            return 2
    except FileNotFoundError as exc:
        print(str(exc))
        return 3
    except Exception as exc:
        print(f"error: {exc}")
        return 4

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
