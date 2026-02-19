"""Skill and agent directory loading helpers for gather_intelligence."""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import List

import yaml


def _normalize_skill_names(skills: List[str]) -> List[str]:
    """Normalize skill names to dispatcher-compatible form."""
    return [skill.replace("_", "-") for skill in skills]


def _load_skills_yaml(skills_file: Path) -> List[str]:
    with open(skills_file, "r") as f:
        data = yaml.safe_load(f) or {}
    skills = list(data.get("skills", {}).keys())
    return _normalize_skill_names(skills)


def load_agent_directory(vnx_path: Path, project_root: Path) -> List[str]:
    """Load valid skills (preferred) or fall back to legacy agent directory."""
    skills_dir = Path(os.environ.get("VNX_SKILLS_DIR") or (project_root / ".claude" / "skills"))
    skills_candidates = [
        skills_dir / "skills.yaml",
        vnx_path / "skills" / "skills.yaml",
        project_root / "skills" / "skills.yaml",
    ]

    # Fallback to agent directory for backwards compatibility
    agent_file = (
        project_root
        / ".claude"
        / "terminals"
        / "library"
        / "templates"
        / "agents"
        / "agent_template_directory.yaml"
    )

    for skills_file in skills_candidates:
        if not skills_file.exists():
            continue
        try:
            normalized_skills = _load_skills_yaml(skills_file)
            if normalized_skills:
                return normalized_skills
        except Exception as e:
            print(f"⚠️ Warning: Could not load skills.yaml: {e}", file=sys.stderr)

    if not agent_file.exists():
        print("⚠️ Warning: Neither skills.yaml nor agent directory found", file=sys.stderr)
        return []

    try:
        with open(agent_file, "r") as f:
            data = yaml.safe_load(f)
        return list(data.get("agents", {}).keys())
    except Exception as e:
        print(f"❌ Error loading agent directory: {e}", file=sys.stderr)
        return []
