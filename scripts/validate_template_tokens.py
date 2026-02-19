#!/usr/bin/env python3
"""Detect missing template placeholders and mandatory sections."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from vnx_paths import ensure_env

PATHS = ensure_env()
PROJECT_ROOT = Path(PATHS["PROJECT_ROOT"])
VNX_HOME = Path(PATHS["VNX_HOME"])


@dataclass(frozen=True)
class TemplateCheck:
    key: str
    label: str
    rel_path: str
    required_tokens: List[str]
    required_sections: List[str]
    base_dir: str = "project_root"

    def resolve_path(self, project_root: Path) -> Path:
        if self.base_dir == "vnx_home":
            return VNX_HOME / self.rel_path
        return project_root / self.rel_path


@dataclass
class TemplateValidationResult:
    check: TemplateCheck
    path: Path
    missing_tokens: List[str]
    missing_sections: List[str]
    file_missing: bool

    @property
    def is_valid(self) -> bool:
        return not self.file_missing and not self.missing_tokens and not self.missing_sections


TEMPLATE_CHECKS: List[TemplateCheck] = [
    TemplateCheck(
        key="report_template",
        label="Unified report template (terminals)",
        rel_path=".claude/terminals/library/templates/report_template.md",
        required_tokens=[
            "dispatch-id",
            "pr-id",
            "track",
            "terminal",
            "gate",
            "status",
            "timestamp",
        ],
        required_sections=[
            "## Metadata",
            "## Summary",
            "## Tags (Required)",
            "## Open Items",
        ],
    ),
    TemplateCheck(
        key="unified_report_template",
        label="Unified report template (vnx-system)",
        rel_path="templates/unified_report_template.md",
        required_tokens=[],  # static placeholders only; rely on sections
        required_sections=[
            "## Summary",
            "## Tags (Required)",
            "## Work Completed",
            "## Open Items",
        ],
        base_dir="vnx_home",
    ),
    TemplateCheck(
        key="receipt_lean",
        label="Lean receipt template",
        rel_path="templates/receipt_lean.md",
        required_tokens=[
            "DISPATCH_ID",
            "TERMINAL",
            "STATUS",
            "GATE",
            "BRIEF_SUMMARY",
        ],
        required_sections=["**ID**", "**Terminal**", "**Status**", "**Gate**"],
        base_dir="vnx_home",
    ),
    TemplateCheck(
        key="receipt_verbose_footer",
        label="Verbose receipt footer",
        rel_path=".claude/terminals/library/templates/footers/receipt_verbose.md",
        required_tokens=[
            "TASK_NARRATIVE",
            "IMPACT_DESCRIPTION",
            "DEPENDENCIES_LIST",
            "NEXT_ACTIONS",
        ],
        required_sections=[
            "### Task Details",
            "### Impact Analysis",
            "### Dependencies",
            "### Next Steps",
        ],
    ),
    TemplateCheck(
        key="quality_gate_verification",
        label="Quality gate verification dispatch",
        rel_path=".claude/terminals/library/templates/dispatches/quality_gate_verification.md",
        required_tokens=[
            "TERMINAL",
            "DATE",
            "TYPE",
            "DESCRIPTION",
            "REPORT_PATH",
        ],
        required_sections=[
            "## When to Use This Template",
            "## Dispatch Template (V2 Format)",
            "## Template Variables",
        ],
    ),
    TemplateCheck(
        key="quality_gate_rejection",
        label="Quality gate rejection dispatch",
        rel_path=".claude/terminals/library/templates/dispatches/quality_gate_rejection.md",
        required_tokens=[
            "ORIGINAL_TRACK",
            "ORIGINAL_ROLE",
            "ORIGINAL_GATE",
            "VERIFICATION_REPORT",
            "SPECIFIC_ISSUE_1",
            "SPECIFIC_ISSUE_2",
            "SPECIFIC_ISSUE_3",
        ],
        required_sections=[
            "## When to Use This Template",
            "## Dispatch Template (V2 Format)",
            "## Template Variables",
        ],
    ),
]


TOKEN_PATTERNS = (
    re.compile(r"\{\{\s*%s\s*\}\}"),
    re.compile(r"\{\s*%s\s*\}"),
)


def _find_missing_tokens(content: str, tokens: Iterable[str]) -> List[str]:
    missing = []
    for token in tokens:
        patterns = (
            re.compile(pattern.pattern % re.escape(token))
            for pattern in TOKEN_PATTERNS
        )
        if any(pattern.search(content) for pattern in patterns):
            continue
        if token in content:
            continue
        missing.append(token)
    return missing


def validate_template(check: TemplateCheck, project_root: Path) -> TemplateValidationResult:
    path = check.resolve_path(project_root)
    if not path.exists():
        return TemplateValidationResult(
            check=check,
            path=path,
            missing_tokens=list(check.required_tokens),
            missing_sections=list(check.required_sections),
            file_missing=True,
        )

    content = path.read_text()
    missing_tokens = _find_missing_tokens(content, check.required_tokens)
    missing_sections = [s for s in check.required_sections if s not in content]

    return TemplateValidationResult(
        check=check,
        path=path,
        missing_tokens=missing_tokens,
        missing_sections=missing_sections,
        file_missing=False,
    )


def get_checks(keys: Optional[List[str]] = None) -> List[TemplateCheck]:
    if not keys:
        return TEMPLATE_CHECKS
    normalized = {check.key: check for check in TEMPLATE_CHECKS}
    requested = []
    for key in keys:
        if key not in normalized:
            raise ValueError(f"Unknown template key: {key}")
        requested.append(normalized[key])
    return requested


def validate_all_templates(
    keys: Optional[List[str]] = None, project_root: Optional[Path] = None
) -> List[TemplateValidationResult]:
    project_root = project_root or PROJECT_ROOT
    checks = get_checks(keys)
    return [validate_template(check, project_root) for check in checks]


def print_results(results: List[TemplateValidationResult], quiet: bool = False) -> int:
    failures = 0
    for result in results:
        if result.is_valid:
            if not quiet:
                print(f"✅ {result.check.label}: {result.path}")
            continue
        failures += 1
        print(f"❌ {result.check.label}: {result.path}")
        if result.file_missing:
            print("   Missing template file")
            continue
        if result.missing_tokens:
            print(f"   Missing tokens: {', '.join(result.missing_tokens)}")
        if result.missing_sections:
            print(f"   Missing sections: {', '.join(result.missing_sections)}")
    if failures and not quiet:
        print("\nTemplate validation failed. Fix templates before dispatching.")
    return failures


def list_checks() -> None:
    for check in TEMPLATE_CHECKS:
        print(f"{check.key}: {check.label} ({check.rel_path})")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate template placeholders before dispatch")
    parser.add_argument(
        "-t",
        "--templates",
        action="append",
        help="Run validation for named templates (key).",
        metavar="KEY",
    )
    parser.add_argument("-q", "--quiet", action="store_true", help="Only print failures")
    parser.add_argument("-l", "--list", action="store_true", help="List available template keys")
    args = parser.parse_args()

    if args.list:
        list_checks()
        return 0

    try:
        results = validate_all_templates(keys=args.templates)
    except ValueError as exc:
        print(f"Error: {exc}")
        return 2

    failures = print_results(results, quiet=args.quiet)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
