---
name: t0_action_request_enhanced
purpose: Enhanced footer with context reading instructions for T0
---

## ACTION REQUIRED: T0 Orchestrator Response

Based on this receipt, you must now:

### 1. READ CONTEXT (CRITICAL for Track C)
**BEFORE making decisions, READ additional context:**

#### For Track C (T3) Receipts:
- **ALWAYS READ**: `$VNX_REPORTS_DIR/latest-T3-status.md` - Current investigation status
- **IF report_path exists**: READ the full report at the specified path
- **CHECK**: `$VNX_REPORTS_DIR/` for recent investigation reports

#### For Track A/B Receipts with report_path:
- **READ**: The report file specified in report_path
- **SCAN**: Last 2-3 files in `$VNX_REPORTS_DIR/` for recent work context

### 2. ASSESS the Situation
After reading context:
- What was completed? What failed? What was discovered?
- Are we still on track for the sprint goal?
- Any blockers or dependencies emerged?
- For Track C: What are T3's recommendations?

### 3. SELECT Next Action
Choose ONE of these responses:
- **Continue**: Next task in current phase
- **Switch**: Different track needs attention  
- **Escalate**: Blocker needs resolution (consider Track C investigation)
- **Review**: Gate checkpoint reached
- **Complete**: Phase/sprint finished
- **Investigate**: Send to Track C (T3) for deep analysis

### 4. CREATE Dispatch Block
If action needed, create a dispatch block:

```
[[TARGET:A|B|C]]
Role: <developer|quality-engineer|architect-opus|security-engineer>
Workflow: [[@.claude/terminals/library/templates/agents/<role>.md]]
Context: [[@path1]] [[@path2]] [[@path3]]   # Include reports!
Previous Gate: planning|implementation|review|testing|validation
Gate: planning|implementation|review|testing|validation  
Priority: P0|P1|P2; Cognition: normal|deep
Instruction:
- Max 12 lines of concrete, testable instructions
- Reference findings from reports if applicable
- Include specific recommendations from T3 if Track C
[[DONE]]
```

### 5. TRACK C SPECIAL HANDLING
When Track C sends a receipt:
- **Status: blocked** → T3 found issues requiring resolution
- **Status: success** → T3 completed investigation with findings
- **Always include** T3's report in next dispatch Context field
- **Consider** T3's recommendations for all tracks

### 6. RETURN to Terminal
Post your dispatch block directly to the terminal for processing.

**Remember**: 
- Track C reports contain strategic insights - READ THEM
- report_path is your gateway to detailed information
- `$VNX_REPORTS_DIR/` contains recent implementation work
- Make informed decisions based on evidence, not assumptions

**Decision Time**: Read context FIRST, then make your orchestration decision.
