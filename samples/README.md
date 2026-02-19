# Sample Receipts & Dispatches

Sanitized examples from real VNX usage. All project-specific data (repo names, file paths, URLs, API keys, customer names) has been replaced with generic placeholders. Timestamps and structural patterns are authentic.

## Contents

- `sample_receipts.ndjson` — 10 receipts showing the full dispatch lifecycle
- `sample_dispatch_staged.md` — A dispatch in staging (pre-promotion)
- `sample_dispatch_promoted.md` — The same dispatch after promotion to queue
- `sample_quality_advisory.json` — Quality gate output for a completed task

## How to Read the Receipt Chain

The receipts in `sample_receipts.ndjson` tell this story:

1. **Line 1**: T0 drafts a dispatch (2 implementation tasks)
2. **Line 2**: Human promotes the dispatch from staging to queue
3. **Line 3**: T1 acknowledges task A (backend implementation)
4. **Line 4**: T2 acknowledges task B (test engineering)
5. **Line 5**: T1 completes task A (success, quality gate: approve)
6. **Line 6**: T2 completes task B (success, quality gate: approve_with_followup)
7. **Line 7**: Quality gate issues a follow-up refactor dispatch for T2's output
8. **Line 8**: T0 generates intelligence digest from completed work
9. **Line 9**: System heartbeat showing all terminals healthy
10. **Line 10**: Cost aggregation receipt for the batch

This chain demonstrates: staging gate → human promotion → parallel execution → quality gates → follow-up dispatch → intelligence loop.
