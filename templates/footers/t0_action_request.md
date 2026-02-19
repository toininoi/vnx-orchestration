---
name: t0_action_request
purpose: Footer for receipt consumer to trigger T0 orchestration
---

## ACTION REQUIRED: T0 Orchestrator Response

Based on this receipt, you must now:

### 1. ASSESS the Situation
- What was completed? What failed?
- Are we still on track for the sprint goal?
- Any blockers or dependencies emerged?

### 2. SELECT Next Action
Choose ONE of these responses:
- **Continue**: Next task in current phase
- **Switch**: Different track needs attention
- **Escalate**: Blocker needs resolution
- **Review**: Gate checkpoint reached
- **Complete**: Phase/sprint finished

### 3. CREATE Dispatch Block
If action needed, create a dispatch block as outlined in @$VNX_HOME/templates/footers/t0_action_request.md
```
[[TARGET:A|B|C]]
Role: <role key uit agent_template_directory.yaml, bv: developer|quality-engineer|architect-opus|senior-developer>
Workflow: [[@.claude/library/templates/agents/<role>.md]]
Context: [[@path1]] [[@path2]] [[@path3]]   # max 3 refs
Previous Gate:  planning|implementation|review|testing|validation
Gate: planning|implementation|review|testing|validation
Priority: P0|P1|P2; Cognition: normal|deep
Instruction: <max 7 regels, concreet en toetsbaar>
[[DONE]]
```

### 4. RETURN to Terminal
Post your dispatch block directly to the terminal for processing.

**Decision Time**: Make your orchestration decision NOW based on the receipt above.
