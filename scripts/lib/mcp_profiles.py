#!/usr/bin/env python3
"""MCP Profile Manager - Generate per-terminal .mcp.json files.

Reads T3's .mcp.json as the source of truth (contains all servers + API keys),
filters servers per terminal profile, and writes reduced .mcp.json files.

Result: 50 → 18 MCP processes, ~1.8GB → ~660MB (63% reduction).
"""

import json
import shutil
import sys
from pathlib import Path

# Terminal MCP profiles
PROFILES = {
    "worker": ["github", "sequential-thinking"],  # T0, T1, T2, T-MANAGER
    "mcp_hub": None,  # T3: ALL servers (no filtering)
}

TERMINAL_PROFILES = {
    "T0": "worker",
    "T1": "worker",
    "T2": "worker",
    "T3": "mcp_hub",
    "T-MANAGER": "worker",
}


def load_source_config(source_path: Path) -> dict:
    """Load the full MCP config from T3 (source of truth)."""
    with open(source_path, "r", encoding="utf-8") as f:
        return json.load(f)


def filter_servers(full_config: dict, profile_name: str) -> dict:
    """Filter MCP servers based on profile. Returns new config dict."""
    allowed = PROFILES.get(profile_name)
    if allowed is None:
        # mcp_hub: return full config unchanged
        return full_config

    servers = full_config.get("mcpServers", {})
    filtered = {k: v for k, v in servers.items() if k in allowed}
    return {"mcpServers": filtered}


def generate_terminal_config(
    terminal: str,
    source_config: dict,
    terminals_dir: Path,
    backup: bool = True,
) -> Path:
    """Generate .mcp.json for a single terminal."""
    profile_name = TERMINAL_PROFILES.get(terminal)
    if profile_name is None:
        raise ValueError(f"Unknown terminal: {terminal}")

    target_path = terminals_dir / terminal / ".mcp.json"

    if not target_path.parent.exists():
        raise FileNotFoundError(f"Terminal directory not found: {target_path.parent}")

    # Backup original if it exists and backup requested
    if backup and target_path.exists():
        bak_path = target_path.with_suffix(".json.bak")
        if not bak_path.exists():
            shutil.copy2(target_path, bak_path)

    # Filter and write
    filtered_config = filter_servers(source_config, profile_name)

    with open(target_path, "w", encoding="utf-8") as f:
        json.dump(filtered_config, f, indent=2)
        f.write("\n")

    server_count = len(filtered_config.get("mcpServers", {}))
    return target_path, server_count


def generate_all(terminals_dir: Path, source_path: Path, backup: bool = True):
    """Generate .mcp.json for all terminals."""
    source_config = load_source_config(source_path)
    results = []

    for terminal in TERMINAL_PROFILES:
        path, count = generate_terminal_config(
            terminal, source_config, terminals_dir, backup
        )
        results.append((terminal, count, path))

    return results


def show_profile(terminal: str, terminals_dir: Path):
    """Show the current MCP profile for a terminal."""
    profile_name = TERMINAL_PROFILES.get(terminal)
    if profile_name is None:
        print(f"Unknown terminal: {terminal}", file=sys.stderr)
        return 1

    target_path = terminals_dir / terminal / ".mcp.json"
    if not target_path.exists():
        print(f"No .mcp.json found at {target_path}", file=sys.stderr)
        return 1

    with open(target_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    servers = list(config.get("mcpServers", {}).keys())
    print(f"Terminal: {terminal}")
    print(f"Profile: {profile_name}")
    print(f"Servers ({len(servers)}): {', '.join(servers)}")
    return 0


def main():
    if len(sys.argv) < 2:
        print("Usage: mcp_profiles.py <command> [args]")
        print("Commands: generate-all, generate <terminal>, show <terminal>")
        sys.exit(1)

    # Resolve paths
    script_dir = Path(__file__).resolve().parent
    vnx_dir = script_dir.parent.parent  # vnx root
    claude_dir = vnx_dir.parent  # .claude
    terminals_dir = claude_dir / "terminals"
    source_path = terminals_dir / "T3" / ".mcp.json"

    command = sys.argv[1]

    if command == "generate-all":
        results = generate_all(terminals_dir, source_path)
        for terminal, count, path in results:
            profile = TERMINAL_PROFILES[terminal]
            print(f"  {terminal:10s} [{profile:8s}] → {count} servers")
        total = sum(c for _, c, _ in results)
        print(f"\nTotal MCP processes: {total} (was {len(TERMINAL_PROFILES) * 10})")

    elif command == "generate":
        if len(sys.argv) < 3:
            print("Usage: mcp_profiles.py generate <terminal>", file=sys.stderr)
            sys.exit(1)
        terminal = sys.argv[2]
        source_config = load_source_config(source_path)
        path, count = generate_terminal_config(terminal, source_config, terminals_dir)
        print(f"Generated {path} ({count} servers)")

    elif command == "show":
        if len(sys.argv) < 3:
            print("Usage: mcp_profiles.py show <terminal>", file=sys.stderr)
            sys.exit(1)
        sys.exit(show_profile(sys.argv[2], terminals_dir))

    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
