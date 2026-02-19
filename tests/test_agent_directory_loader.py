#!/usr/bin/env python3
"""Unit tests for gather_intelligence agent/skill directory loader."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "scripts" / "lib"))

from agent_directory_loader import load_agent_directory


def test_load_agent_directory_prefers_skills_yaml(tmp_path, monkeypatch):
    project_root = tmp_path / "project"
    vnx_path = tmp_path / "vnx"
    skills_dir = project_root / ".claude" / "skills"
    skills_dir.mkdir(parents=True)
    (vnx_path / "skills").mkdir(parents=True)

    (skills_dir / "skills.yaml").write_text(
        """
skills:
  backend_developer: {}
  quality-engineer: {}
""".strip()
    )

    monkeypatch.delenv("VNX_SKILLS_DIR", raising=False)

    loaded = load_agent_directory(vnx_path=vnx_path, project_root=project_root)
    assert loaded == ["backend-developer", "quality-engineer"]


def test_load_agent_directory_falls_back_to_agent_templates(tmp_path, monkeypatch):
    project_root = tmp_path / "project"
    vnx_path = tmp_path / "vnx"
    fallback_path = (
        project_root
        / ".claude"
        / "terminals"
        / "library"
        / "templates"
        / "agents"
    )
    fallback_path.mkdir(parents=True)

    (fallback_path / "agent_template_directory.yaml").write_text(
        """
agents:
  architect: {}
  reviewer: {}
""".strip()
    )

    monkeypatch.setenv("VNX_SKILLS_DIR", str(tmp_path / "missing-skills"))

    loaded = load_agent_directory(vnx_path=vnx_path, project_root=project_root)
    assert loaded == ["architect", "reviewer"]
