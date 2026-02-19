---
name: t0_action_request_autonomous
purpose: Token-efficient autonomous orchestration instructions for T0
version: 2.0 (Autonomous with Workflow Intelligence)
---

## 🤖 T0 AUTONOMOUS ORCHESTRATION

### 1. CHECK INTELLIGENCE (ALWAYS FIRST)
```bash
tail -n 1 "$VNX_STATE_DIR/t0_intelligence.ndjson" | jq '.summary'
```
- Any terminals working? **WAIT** for their receipts
- Active workflows? Check project state

### 2. ANALYZE RECEIPT
**Status**: $STATUS | **Gate**: $GATE | **Terminal**: $TERMINAL

**Decision Matrix**:
- ✅ `success` → Progress to next gate/phase
- 🚧 `blocked` → Resolve blocker or escalate
- ❌ `fail` → Retry with different approach
- ⚠️ `partial` → Review and complete

**Context Available**:
- Report: `$REPORT_PATH`
- Tags: Issues: $ISSUE_TAGS | Components: $COMPONENT_TAGS
- Risk: $DEP_RISK | Blocking: $DEP_BLOCKING

### 3. DETERMINE NEXT ACTION

**For SUCCESS receipts**:
1. Check active workflow → Auto-determine next phase
2. Standard flow: planning → implementation → review → testing → integration → quality_gate
3. Terminal selection: Simple (T1/T2 Sonnet), Complex (T3 Opus)

**For BLOCKED/FAIL receipts**:
1. Read full report at `$REPORT_PATH`
2. Identify blocker/failure cause
3. Dispatch fix or escalate to user

### 4. CREATE MANAGER BLOCK (if action needed)

```
[[TARGET:A|B|C]]
Role: developer|architect|quality-engineer|security-engineer
Workflow: [[@.claude/terminals/library/templates/agents/<role>.md]]
Context: [[@file1]] [[@file2]]  # max 3, include report if relevant
Gate: planning|implementation|review|testing|validation
Priority: P0|P1|P2; Cognition: normal|deep
Instruction:
- Concrete, testable tasks (max 10 lines)
- Reference report findings if applicable
- Include success criteria
[[DONE]]
```

### 5. LEARNING & PATTERNS

**Before dispatching, check terminal history**:
```bash
tail -n 1 "$VNX_STATE_DIR/t0_intelligence.ndjson" | jq '.terminal_insights."$TERMINAL"'
```

**Common Mistakes** (inject into dispatch if relevant):
- T1: Activate .venv before Python, verify Supabase connection
- T2: Check data integrity, validate field mappings
- T3: Document findings, provide clear recommendations

---

**⚡ EFFICIENCY NOTES**:
- Token-optimized: ~500 tokens vs 1000+ in old version
- Intelligence-first: Check state before deciding
- Workflow-aware: Auto-progress through standard phases
- Learning-enabled: Reference terminal success patterns
- Action-oriented: Clear decision matrix, not lengthy explanations

**Decision Time**: Make your orchestration decision based on intelligence + receipt context.
