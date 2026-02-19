import sys
from pathlib import Path

import pytest

TEST_DIR = Path(__file__).resolve().parent
VNX_DIR = TEST_DIR.parent
SCRIPTS_DIR = VNX_DIR / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from validate_template_tokens import TemplateCheck, validate_all_templates, validate_template  # noqa: E402


def test_validate_template_reports_missing_tokens_and_sections(tmp_path):
    template_path = tmp_path / "custom_template.md"
    template_path.write_text(
        "## Summary\n"
        "\n"
        "- Work item\n"
        "\n"
        "{{PRESENT_TOKEN}}\n"
    )

    check = TemplateCheck(
        key="custom",
        label="Custom Template",
        rel_path="custom_template.md",
        required_tokens=["PRESENT_TOKEN", "MISSING_TOKEN"],
        required_sections=["## Summary", "## Tags (Required)"],
    )

    result = validate_template(check, tmp_path)

    assert not result.is_valid
    assert result.missing_tokens == ["MISSING_TOKEN"]
    assert result.missing_sections == ["## Tags (Required)"]


def test_validate_template_handles_missing_file(tmp_path):
    check = TemplateCheck(
        key="missing",
        label="Missing Template",
        rel_path="does_not_exist.md",
        required_tokens=["TOKEN_A"],
        required_sections=["## Section"],
    )

    result = validate_template(check, tmp_path)

    assert result.file_missing
    assert result.missing_tokens == ["TOKEN_A"]
    assert result.missing_sections == ["## Section"]


def test_validate_all_templates_rejects_unknown_key(tmp_path):
    with pytest.raises(ValueError):
        validate_all_templates(keys=["nonexistent"], project_root=tmp_path)
