[[TARGET:A]]
Role: architect
Track: A
Terminal: T1
Gate: planning
Priority: P1
Cognition: normal
Mode: planning          # NEW FIELD: Should activate plan mode
ClearContext: true      # NEW FIELD: Should send /clear first
Requires-Model: opus    # EXISTING FIELD: Should switch to opus
Dispatch-ID: TEST-MODE-001-A

Workflow: [[@.claude/terminals/library/templates/agents/architect.md]]

Instruction:
- TEST: Explicit mode configuration test
- This dispatch has Mode: planning field
- This dispatch has ClearContext: true field
- This dispatch has Requires-Model: opus field
- If mode control works, you should be in plan mode with opus model
- Please respond: "TEST MODE SUCCESS: In plan mode with opus"

[[DONE]]