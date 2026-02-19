# CHANGELOG: Quality Advisory Pipeline

## [1.0.0] - 2026-02-15

### Added

#### Core Features
- **Quality Advisory Pipeline**: Post-completion code quality analysis for VNX receipts
  - File size gates (Python: 500/800 lines, Shell: 300/500 lines)
  - Function size gates (Python: 40/70 lines, Shell: 30/50 lines)
  - Linting integration (ruff for Python, shellcheck for Shell)
  - Dead code detection (vulture for Python)
  - Test coverage hygiene (src/ changes without test changes)

- **Terminal Snapshot Collection**: Full state capture of T0/T1/T2/T3
  - Status, claimed_by, provider, model
  - Last activity timestamps
  - Lease expiration tracking
  - Fallback to tmux when state files unavailable

- **T0 Decision Policy**: Deterministic decision-making for quality gates
  - `approve`: No significant issues (risk_score <50, warnings <2, blocking=0)
  - `approve_with_followup`: Minor issues (risk_score >=50 OR warnings >=2)
  - `hold`: Blocking issues detected
  - Suggested follow-up dispatches (refactoring, cleanup, testing)
  - Open items list for feature-plan integration

#### New Modules
- `scripts/lib/quality_advisory.py` (540 lines)
  - `generate_quality_advisory()` - Main entry point
  - `get_changed_files()` - Git diff integration
  - `check_file_size()` - File size validation
  - `check_function_sizes()` - Function size validation
  - `run_linting()` - Linting orchestration
  - `check_dead_code()` - Vulture integration
  - `check_test_coverage_hygiene()` - Test delta checking
  - `make_t0_decision()` - Policy engine
  - Risk scoring (0-100 scale, 50 points/blocking, 10 points/warning)

- `scripts/lib/terminal_snapshot.py` (175 lines)
  - `collect_terminal_snapshot()` - Main entry point
  - `get_terminal_state_from_files()` - State file parser
  - `get_terminal_state_from_tmux()` - tmux fallback
  - Reads from: terminal_status.ndjson, dashboard_status.json

#### Integration
- `scripts/append_receipt.py` (+84 lines)
  - `_enrich_completion_receipt()` - Best-effort enrichment
  - `_is_completion_event()` - Event type detection
  - Imports: quality_advisory, terminal_snapshot modules
  - Automatic enrichment for completion receipts
  - Failure-safe with status="unavailable" markers

#### Receipt Schema Extensions

**quality_advisory**:
```json
{
  "version": "1.0",
  "generated_at": "ISO-8601",
  "scope": ["changed_file_paths"],
  "checks": [
    {
      "check_id": "file_size_blocking",
      "severity": "info|warning|blocking",
      "file": "path",
      "symbol": "function_name",
      "message": "human-readable",
      "evidence": "machine-readable",
      "action_required": true|false
    }
  ],
  "summary": {
    "warning_count": 0,
    "blocking_count": 0,
    "risk_score": 0
  },
  "t0_recommendation": {
    "decision": "approve|approve_with_followup|hold",
    "reason": "explanation",
    "suggested_dispatches": [],
    "open_items": []
  }
}
```

**terminal_snapshot**:
```json
{
  "timestamp": "ISO-8601",
  "terminals": {
    "T0": {
      "status": "idle|active|working|unknown",
      "claimed_by": "task_id",
      "provider": "anthropic|openai",
      "model": "sonnet|opus|haiku",
      "last_activity": "ISO-8601",
      "lease_expires_at": "ISO-8601"
    }
  }
}
```

#### Tests
- `tests/test_quality_advisory_pipeline.py` (30 tests)
  - TestFileSizeGates: 5 tests (thresholds for Python/Shell)
  - TestFunctionSizeGates: 4 tests (thresholds for Python/Shell)
  - TestRiskScoring: 5 tests (scoring logic, cap at 100)
  - TestT0DecisionPolicy: 5 tests (approve/approve_with_followup/hold)
  - TestQualityAdvisoryGeneration: 3 tests (end-to-end, schema validation)
  - TestTerminalSnapshot: 3 tests (collection, fallback, schema)
  - TestReceiptEnrichment: 3 tests (completion detection, enrichment, failure handling)
  - TestNonRegression: 2 tests (existing flow preserved)

#### Documentation
- `docs/QUALITY_ADVISORY_EVIDENCE_BUNDLE.md` - Complete evidence package
- `scripts/demo_quality_advisory.py` - Live demonstration script
- Inline code documentation in all modules

### Changed

#### Modified Files
- `scripts/append_receipt.py`
  - Added quality advisory and terminal snapshot imports
  - Added enrichment function (`_enrich_completion_receipt`)
  - Hooked enrichment into append flow (line 220)
  - Best-effort execution (failures don't crash)

### Architecture Decisions

#### Model-Agnostic Design
- **Decision**: Run all quality checks from VNX scripts, not provider hooks
- **Rationale**: Maintain model-agnostic behavior across Claude/Codex/Gemini
- **Implementation**: Post-ingestion enrichment in append_receipt.py

#### Best-Effort Execution
- **Decision**: Advisory generation failures must not crash receipt append
- **Rationale**: Receipt flow is critical infrastructure; quality checks are enhancement
- **Implementation**: Try/except blocks with status="unavailable" fallback

#### Changed Files Scope
- **Decision**: Operate only on git-changed files
- **Rationale**: Bounded latency for real-time receipt processing
- **Implementation**: `git diff --name-status HEAD` for file detection

#### Threshold Values
- **Decision**: Conservative thresholds with warning/blocking separation
- **Rationale**: Balance between catching issues and avoiding false positives
- **Implementation**:
  - Python files: 500 (warn) / 800 (block)
  - Shell files: 300 (warn) / 500 (block)
  - Python functions: 40 (warn) / 70 (block)
  - Shell functions: 30 (warn) / 50 (block)

### Performance

#### Latency
- File operations: Changed files only (not full repo scan)
- Linting: 10-second timeout per tool (ruff, shellcheck, vulture)
- Git operations: Standard git command timeouts
- Total expected latency: <5 seconds for typical completion receipts

#### Resource Usage
- Memory: Minimal (one file at a time, text processing)
- CPU: Bounded by linting tools with timeouts
- I/O: Read-only operations on changed files

### Testing

#### Coverage
- **Unit Tests**: 30 tests covering all major components
- **Integration Tests**: Receipt enrichment flow
- **Non-Regression Tests**: Existing receipt flow preserved
- **Live Proof**: Clean and high-risk completion scenarios

#### Test Execution
```bash
$ python3 -m pytest tests/test_quality_advisory_pipeline.py -v
30 passed in 0.14s
```

### Evidence

#### Test Results
- ✅ 30/30 tests passing
- ✅ All threshold behaviors validated
- ✅ Decision policy deterministic
- ✅ Terminal snapshot collection working
- ✅ Failure handling verified

#### Live Demonstrations
- ✅ Clean completion → approve decision
- ✅ High-risk completion (2 blocking issues) → hold decision
- ✅ Enriched receipt includes both quality_advisory and terminal_snapshot
- ✅ Terminal snapshot captures all 4 terminals (T0/T1/T2/T3)

#### Schema Validation
- ✅ Grep proof shows proper schema field integration
- ✅ Receipt enrichment preserves existing fields
- ✅ New fields properly structured as JSON objects

### Migration

#### Backward Compatibility
- **Existing Receipts**: Non-completion receipts unchanged
- **Completion Receipts**: Automatically enriched (additive change)
- **Failure Mode**: Graceful degradation with status="unavailable"

#### Rollout
- **Phase 1**: Deploy implementation (model-agnostic, best-effort)
- **Phase 2**: Monitor advisory generation success rate
- **Phase 3**: T0 integration for dispatch decision-making

### Future Enhancements

#### Potential Additions
- Coverage metrics integration (pytest-cov, coverage.py)
- Complexity metrics (cyclomatic complexity, maintainability index)
- Security scanning (bandit for Python, custom rules for Shell)
- Performance profiling (line profiling, memory profiling)
- Custom quality gates per project/terminal

#### T0 Integration Roadmap
- Receipt ingestion with quality advisory parsing
- Dispatch decision based on T0 recommendation
- Automated follow-up task creation from suggested_dispatches
- Open items integration with feature-plan workflow

---

## Statistics

### Lines of Code
- **Production Code**: 799 lines (quality_advisory.py + terminal_snapshot.py + append_receipt.py changes)
- **Test Code**: 495 lines (test_quality_advisory_pipeline.py)
- **Demo Code**: 194 lines (demo_quality_advisory.py)
- **Total**: 1,488 lines

### Test Metrics
- **Total Tests**: 30
- **Pass Rate**: 100%
- **Execution Time**: 0.14s
- **Coverage**: All major code paths tested

### Threshold Matrix
| Check Type | Language | Warning | Blocking |
|------------|----------|---------|----------|
| File Size  | Python   | 500     | 800      |
| File Size  | Shell    | 300     | 500      |
| Function   | Python   | 40      | 70       |
| Function   | Shell    | 30      | 50       |

### Risk Scoring
- Blocking Issue: +50 points
- Warning: +10 points
- Maximum Score: 100 (capped)

### Decision Policy
| Condition | Decision | Threshold |
|-----------|----------|-----------|
| blocking_count > 0 | hold | Any blocking |
| warning_count >= 2 OR risk_score >= 50 | approve_with_followup | 2 warnings OR 50 points |
| Otherwise | approve | Clean |

---

## References

- **Evidence Bundle**: docs/QUALITY_ADVISORY_EVIDENCE_BUNDLE.md
- **Demo Script**: scripts/demo_quality_advisory.py
- **Test Suite**: tests/test_quality_advisory_pipeline.py
- **Core Module**: scripts/lib/quality_advisory.py
- **Snapshot Module**: scripts/lib/terminal_snapshot.py
