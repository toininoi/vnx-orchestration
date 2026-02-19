[[TARGET:A]]
Role: backend-developer
Workflow: [[@.claude/terminals/library/templates/agents/backend-developer.md]]
Context: [[@docs/architecture/api-design.md]] [[@src/api/response_handler.py]]
Completed gate:
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
[[DONE]]
