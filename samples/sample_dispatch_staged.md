[[TARGET:A]]
Role: backend-developer
Workflow: [[@.claude/terminals/library/templates/agents/backend-developer.md]]
Context: [[@docs/architecture/api-design.md]] [[@src/api/response_handler.py]]
Gate: implementation
Priority: P1; Cognition: normal
Instruction:
- Refactor response_handler.py (currently 340 lines) into two modules:
  - api_service.py: HTTP handling, routing, middleware
  - response_validator.py: Schema validation, error formatting, type coercion
- Preserve all existing public interfaces (no breaking changes)
- Each new file must stay under 200 lines
- Run existing tests to confirm no regressions
- Update imports in any file that references response_handler directly

---

[[TARGET:B]]
Role: test-engineer
Workflow: [[@.claude/terminals/library/templates/agents/test-engineer.md]]
Context: [[@src/api/response_handler.py]] [[@tests/test_api.py]]
Gate: testing
Priority: P1; Cognition: normal
Instruction:
- Create test_response_validator.py for the new validator module (created by Track A)
- Target: minimum 85% line coverage
- Must include: valid input, invalid input, edge cases (empty body, malformed JSON, oversized payload)
- Use existing test fixtures where available
- Do NOT modify existing test_api.py (Track A handles import updates)
