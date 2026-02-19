# VNX Skills (Shipped)

This directory contains a minimal, generic skill set that VNX can ship as part of the packaged install (`./.vnx/skills`).

Notes:
- VNX validates roles against `skills.yaml`.
- Claude Code skills are expected under `./.claude/skills/` in the target project.
- `vnx init` bootstraps `./.claude/skills/` by linking or copying from `./.vnx/skills/`.

