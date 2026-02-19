[[TARGET:A]]
Manager Block

Role: developer
Track: A
Terminal: T1
Gate: planning
Priority: P1
Cognition: normal
Program: test-planning-mode
Dispatch-ID: test-planning-001
Mode: planning
ClearContext: true
On-Success: implementation
On-Failure: review
Reason: Test planning mode with Opus activation

Workflow: [[@.claude/terminals/library/templates/agents/developer.md]]
Context: None

Instruction:
Create a comprehensive FEATURE_PLAN.md for implementing a user authentication system with the following requirements:
- JWT-based authentication
- Role-based access control (admin, user, guest)
- Password reset functionality
- Session management
- Security best practices

The plan should include:
1. Architecture overview
2. Implementation phases
3. Risk analysis
4. Testing strategy
5. Resource requirements

[[DONE]]