# Feature: Production Funnel Hardening (SSE, Reports, Leads, Payments, Deploy)

**Status**: In progress
**Priority**: P0
**Source of queue truth**: `PR_QUEUE.md` and `.vnx-data/state/pr_queue_state.json`

## PR-1: SSE Correctness and Contract Hygiene

**Track**: A
**Priority**: P0
**Skill**: api-developer
**Complexity**: Medium
**Estimated Time**: 1 day

Dependencies: []

### Description
Harden SSE event correctness and contract consistency for preview and stream consumers.

### Scope
- Validate SSE event payload/schema consistency.
- Eliminate contract drift and duplicate event semantics.

### Success Criteria
- SSE event contract checks pass.
- No schema regressions in stream output.

### Quality Gate
`gate_pr1_sse_contract`:
- [ ] Contract checks pass
- [ ] No SSE schema regressions

---

## PR-2: SSE Preview Design Approval (No Implementation)

**Track**: A
**Priority**: P0
**Skill**: architect
**Complexity**: Medium
**Estimated Time**: 1 day

Dependencies: [PR-1]

### Description
Finalize and approve preview UX/flow design before implementation.

### Scope
- Confirm UX direction, event flow, and API assumptions.
- Produce approved implementation constraints.

### Success Criteria
- Design sign-off is documented.
- Implementation constraints are clear.

### Quality Gate
`gate_pr2_design_signoff`:
- [ ] Design sign-off approved
- [ ] Implementation constraints documented

---

## PR-3: SSE Preview Implementation (Post-Design)

**Track**: A
**Priority**: P0
**Skill**: backend-developer
**Complexity**: High
**Estimated Time**: 1.5 days

Dependencies: [PR-2]

### Description
Implement approved SSE preview behavior and integrate with current stream pipeline.

### Scope
- Build preview path according to approved design.
- Ensure compatibility with existing stream/controller paths.

### Success Criteria
- Preview flow works end-to-end.
- No regressions in existing SSE behavior.

### Quality Gate
`gate_pr3_sse_impl`:
- [ ] Preview flow verified end-to-end
- [ ] Existing SSE behavior remains stable

---

## PR-4: Excel Report Quality

**Track**: A
**Priority**: P1
**Skill**: backend-developer
**Complexity**: Medium
**Estimated Time**: 1 day

Dependencies: [PR-3]

### Description
Improve Excel report structure, consistency, and output quality.

### Scope
- Align Excel generator output with reporting expectations.
- Validate key fields and layout consistency.

### Success Criteria
- Golden output checks pass.
- Required fields are present and consistent.

### Quality Gate
`gate_pr4_excel_quality`:
- [ ] Golden output diff checks pass
- [ ] Required fields present and consistent

---

## PR-5: PDF Branding and Content Quality

**Track**: A
**Priority**: P1
**Skill**: backend-developer
**Complexity**: Medium
**Estimated Time**: 1 day

Dependencies: [PR-3]

### Description
Align PDF branding with product identity and improve content quality/readability.

### Scope
- Normalize PDF branding styles/assets.
- Validate PDF content assembly output.

### Success Criteria
- Branding review approved.
- Data consistency checks pass.

### Quality Gate
`gate_pr5_pdf_branding`:
- [ ] Branding review approved
- [ ] Data consistency check passes

---

## PR-6: ActiveCampaign Integration

**Track**: B
**Priority**: P1
**Skill**: api-developer
**Complexity**: Medium
**Estimated Time**: 1 day

Dependencies: [PR-3]

### Description
Implement and harden ActiveCampaign integration for lead/contact workflows.

### Scope
- Integrate contact sync and tagging flow.
- Ensure idempotent retry and reliability behavior.

### Success Criteria
- Sandbox end-to-end flow passes.
- Duplicate-send prevention is verified.

### Quality Gate
`gate_pr6_activecampaign`:
- [ ] Sandbox end-to-end flow passes
- [ ] Duplicate-send prevention verified

---

## PR-7: Mollie Integration

**Track**: B
**Priority**: P1
**Skill**: api-developer
**Complexity**: Medium
**Estimated Time**: 1 day

Dependencies: [PR-3]

### Description
Integrate Mollie payment flow with robust webhook and download-link handling.

### Scope
- Implement checkout, webhook, status, and download-token flow.
- Ensure webhook idempotency and failure handling.

### Success Criteria
- Happy path and failure path both pass.
- Webhook replay does not duplicate side effects.

### Quality Gate
`gate_pr7_mollie`:
- [ ] Happy path and failure path pass
- [ ] Webhook replay does not duplicate side effects

---

## PR-8: Endurance Stress Testing

**Track**: C
**Priority**: P1
**Skill**: test-engineer
**Complexity**: High
**Estimated Time**: 1 day

Dependencies: [PR-4, PR-5, PR-6, PR-7]

### Description
Run endurance and stress validation across the hardened funnel.

### Scope
- Execute long-run and high-load scenarios.
- Validate stability, reliability, and no critical regressions.

### Success Criteria
- Endurance suite passes.
- No critical regressions under sustained load.

### Quality Gate
`gate_pr8_stress`:
- [ ] Endurance suite passes
- [ ] No critical regressions under sustained load

---

## PR-9: Supabase Reset and GCP Deployment Runbooks

**Track**: C
**Priority**: P1
**Skill**: backend-developer
**Complexity**: Medium
**Estimated Time**: 1 day

Dependencies: [PR-8]

### Description
Finalize operational runbooks for Supabase reset and GCP deployment workflows.

### Scope
- Document/reset procedures and rollback expectations.
- Provide deployment validation checklist.

### Success Criteria
- Runbooks are complete and executable.
- Deployment validation checklist passes.

### Quality Gate
`gate_pr9_ops_runbooks`:
- [ ] Runbooks complete and reviewed
- [ ] Deployment validation checklist passes
