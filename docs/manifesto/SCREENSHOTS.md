# Screenshot Pack (Placeholders)

This document defines where screenshots should be placed in the public story (blog + repo), and what each screenshot must prove.

**Rule**: Use a demo repo. Sanitize all paths, repo names, branch names, customer/product names, and any absolute `/Users/...` traces.

---

## S1. Dashboard (Parallel Visibility)

**Purpose**: Prove multiple terminals are running in parallel with clear status.

**Placeholder**:
- `![VNX orchestration in action: T0 managing parallel worker tracks](assets/screenshots/s1-orchestration-in-action.png)`

**Recommended capture** (best “hero”): a single split-screen image that includes:
- Left: T0 orchestrator status summary + a small table (T1/T2 working, T3 idle) + an explicit decision line (e.g. `Decision: WAIT ...`).
- Right: at least one worker terminal (preferably Codex) actively executing a dispatch plan.

This reads as “flight control” and also proves multi-provider orchestration in one frame.

---

## S2. Chain of Custody (Receipt ↔ Git)

**Purpose**: Prove "audit trail" is real: receipt connects to a concrete code change.

**Placeholder**:
- `![Receipt linking agent decision to a git commit](assets/screenshots/s2-chain-of-custody.png)`

---

## S3. Human Gate (Queue Manager UI)

**Purpose**: Make the human-in-the-loop gate tangible (accept/reject/skip/edit).

**Placeholder**:
- `![Queue manager UI showing dispatch details and accept/reject actions](assets/screenshots/s3-queue-manager.png)`

---

## S4. Governance Across Providers (Worker Refusal)

**Purpose**: Prove governance is provider-agnostic (Codex/Gemini can be governed without hooks).

**Placeholder**:
- `![Worker terminal refuses to proceed without an approved dispatch](assets/screenshots/s4-worker-refusal.png)`

---

## S5. Quality Advisory (Warnings + Decision)

**Purpose**: Prove async quality gates run from receipts and produce a deterministic decision.

**Placeholder**:
- `![Completion receipt with automated quality advisory warnings and decision](assets/screenshots/s5-quality-advisory.png)`

---

## S6. Orchestrator Decision (Explicit WAIT)

**Purpose**: Prove T0 behaves like a manager (blocks work until dependencies clear).

**Placeholder**:
- `![Orchestrator decision screen showing WAIT and reasoning](assets/screenshots/s6-orchestrator-decision.png)`

**Note**: If you use the recommended split-screen from S1 as your hero, you can reuse that same image for this proof point and skip a separate S6 screenshot.
