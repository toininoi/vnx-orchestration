from pathlib import Path
import sys

SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import code_quality_scanner


def _touch(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("# test\n", encoding="utf-8")


def test_archive_and_backup_paths_excluded(tmp_path: Path) -> None:
    active = tmp_path / "active" / "module.py"
    archived = tmp_path / "archived" / "old.py"
    archived_dated = tmp_path / "archived_202501" / "legacy.py"
    archive = tmp_path / "archive" / "old.py"
    backup = tmp_path / "backup" / "snapshot.py"
    backup_named = tmp_path / "backup_202401" / "snapshot.py"

    for path in [active, archived, archived_dated, archive, backup, backup_named]:
        _touch(path)

    scanner = code_quality_scanner.QualityScanner(
        [tmp_path],
        tmp_path / "quality_intelligence.db",
        exclude_globs=code_quality_scanner.EXCLUDE_GLOBS,
        allowlist_globs=[]
    )

    found = {path.relative_to(tmp_path) for path in scanner.find_python_files()}

    assert found == {Path("active/module.py")}


def test_allowlist_filters_scan_dirs(tmp_path: Path) -> None:
    active = tmp_path / "active" / "module.py"
    other = tmp_path / "other" / "keep.py"

    _touch(active)
    _touch(other)

    scanner = code_quality_scanner.QualityScanner(
        [tmp_path],
        tmp_path / "quality_intelligence.db",
        exclude_globs=code_quality_scanner.EXCLUDE_GLOBS,
        allowlist_globs=["active/**"]
    )

    found = {path.relative_to(tmp_path) for path in scanner.find_python_files()}

    assert found == {Path("active/module.py")}
