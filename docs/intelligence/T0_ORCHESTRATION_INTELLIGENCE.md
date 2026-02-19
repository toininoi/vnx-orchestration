# T0 Orchestration Intelligence Guide
**Status**: Active
**Last Updated**: 2026-02-05
**Owner**: T-MANAGER
**Purpose**: Documentation for T0 Orchestration Intelligence Guide.

**Date**: 2025-09-27
**Author**: T-MANAGER
**Version**: 2.0
**Critical**: T0 must evolve from reactive to proactive orchestration with progressive context management

## NEW: T0 Intelligence System (Progressive Context Management)

### Single Source of Truth Architecture

**Problem Solved**: T0 previously had to check 4-5 different systems to understand state, consuming excessive tokens and creating cognitive overhead.

**Solution**: Unified T0 Intelligence System with progressive reading capabilities.

### Intelligence Files
- **Primary**: `.claude/vnx-system/state/t0_intelligence.ndjson` - Rolling window (100 events)
- **Full**: `.claude/vnx-system/state/t0_intelligence_full.ndjson` - Complete history
- **Archive**: `.claude/vnx-system/state/t0_intelligence_archive.ndjson` - Historical data

### Progressive Reading Strategy

**Level 1 - Quick Snapshot (< 1K tokens)**
```bash
tail -n 1 .claude/vnx-system/state/t0_intelligence.ndjson | jq .
```
Provides: Terminal status, critical issues, summary stats, last 10 events

**Level 2 - Recent Context (2-5K tokens)**
```bash
tail -n 10 .claude/vnx-system/state/t0_intelligence.ndjson
```
Use for: Routine orchestration decisions, pattern detection

**Level 3 - Extended Context (5-10K tokens)**
```bash
tail -n 25 .claude/vnx-system/state/t0_intelligence.ndjson
```
Use for: Complex coordination, cross-track dependencies

**Level 4 - Full Window (10-20K tokens)**
```bash
cat .claude/vnx-system/state/t0_intelligence.ndjson
```
Use for: System-wide analysis, architectural decisions

### Token Efficiency Benefits
- **Before**: 20-30K tokens to check all systems
- **After**: 1-5K tokens for most decisions
- **Savings**: 80-95% token reduction
- **Speed**: Single file read vs multiple system checks

### Integration with State Manager
The T0 Intelligence Aggregator is automatically invoked by the unified state manager every 5 seconds, ensuring continuous updates of:
- Terminal status and availability
- Critical issues and blockers
- Recent receipts and dispatches
- System metrics and health

## Core Orchestration Principles

### 1. CRITICAL: Monitor Parallel Work Before Acting

**The Problem**: T0 currently makes decisions immediately upon receipt, missing critical information from other terminals still working.

**The Solution**: **WAIT-OBSERVE-DECIDE Pattern**

When T0 receives a receipt:
1. **WAIT** - Check dashboard for other terminals in "working" state
2. **OBSERVE** - If others working, wait 5-10 seconds for their receipts
3. **DECIDE** - Make informed decision with complete information

**Example Scenario**:
```
T1 completes crawler task → sends receipt
T2 still working on related storage task (will complete in 5 seconds)
❌ OLD: T0 immediately dispatches new task, missing T2's critical findings
✅ NEW: T0 waits, gets T2's receipt, makes better decision with full context
```

### 2. Terminal State Awareness

**Before dispatching ANY task, T0 must check**:
```python
for terminal in ['T1', 'T2', 'T3']:
    status = dashboard['terminals'][terminal]['status']
    last_update = dashboard['terminals'][terminal]['last_update']

    if status == 'working':
        # Terminal busy - don't assign
    elif time_since(last_update) > 60:
        # Terminal may be dead - verify health
    else:
        # Terminal available - can assign
```

### 3. Model-Based Task Routing

**Move from Track-Based to Capability-Based**:
```
Old Thinking: "This is Track A work, must go to T1"
New Thinking: "This is complex work, needs Opus model (T3)"
```

**Routing Decision Matrix**:
| Task Complexity | Model Needed | Available Terminals |
|-----------------|--------------|-------------------|
| Simple (<0.5) | Sonnet | T1 or T2 |
| Standard (0.5-0.7) | Sonnet | T1 or T2 |
| Complex (>0.7) | Opus | T3 |
| Critical | Opus | T3 (priority) |

## T0 Decision Workflow 2.0

### Receipt Processing Flow

```mermaid
Receipt Arrives
    ↓
Check Other Terminal States
    ↓
Any "working"? → YES → Wait 5-10 seconds
    ↓ NO               ↓
    ↓            Collect all receipts
    ↓                   ↓
Read All Context ←─────┘
    ↓
Analyze Complete Picture
    ↓
Make Orchestration Decision
```

### Intelligent Waiting Strategy

**When to Wait**:
- Multiple terminals dispatched to related tasks
- Cross-track dependencies identified
- Phase gates requiring validation
- Critical architectural decisions pending

**How Long to Wait**:
- Default: 5 seconds if others working
- Extended: 10 seconds for critical gates
- Maximum: 30 seconds for phase completion

**What to Do While Waiting**:
1. Read recent reports in `unified_reports/`
2. Check dashboard metrics
3. Review dispatch history
4. Prepare contingency plans

## Enhanced T0 Instructions

### Updated ACTION REQUIRED Section

Add this to T0's dispatch response template:

```markdown
## ACTION REQUIRED: T0 Orchestrator Response

### 0. CHECK PARALLEL WORK (NEW - CRITICAL!)
**BEFORE making any decision:**
- Check dashboard: Are other terminals still "working"?
- If YES: WAIT 5-10 seconds for their receipts
- Collect ALL information before deciding
- Remember: Better decisions with complete context

### 1. READ CONTEXT
[existing instructions...]
```

### Parallel Work Coordination Rules

**Rule 1**: Never dispatch conflicting tasks to parallel terminals
**Rule 2**: Always wait for related work to complete
**Rule 3**: Consider dependencies before parallel dispatch
**Rule 4**: Monitor terminal health continuously

## Implementation Checklist

### Immediate Actions
- [ ] Update T0 CLAUDE.md with wait-observe-decide pattern
- [ ] Modify dispatch templates to include parallel check
- [ ] Add dashboard monitoring before dispatch

### Next Phase
- [ ] Implement intelligent waiting algorithm
- [ ] Create dependency tracking system
- [ ] Build terminal health scoring

### Future Enhancements
- [ ] Predictive completion time estimates
- [ ] Automatic dependency detection
- [ ] Load balancing optimization

## Common Orchestration Mistakes to Avoid

### ❌ Mistake 1: Immediate Reaction
**Problem**: Dispatching immediately on receipt
**Solution**: Always check parallel work first

### ❌ Mistake 2: Ignoring Terminal Health
**Problem**: Sending to unresponsive terminals
**Solution**: Verify heartbeat < 30 seconds old

### ❌ Mistake 3: Track-Rigid Thinking
**Problem**: "T1 must do crawler work"
**Solution**: "Any Sonnet can do standard work"

### ❌ Mistake 4: Missing Dependencies
**Problem**: Starting Phase 2 before Phase 1 complete
**Solution**: Wait for ALL phase receipts

## Monitoring Dashboard Integration

T0 should continuously monitor:
```json
{
  "terminals": {
    "T1": {"status": "idle", "last_update": "2025-09-25T16:39:40Z"},
    "T2": {"status": "working", "last_update": "2025-09-25T16:39:40Z"},
    "T3": {"status": "idle", "last_update": "2025-09-25T16:39:40Z"}
  },
  "queues": {
    "pending": 2,  // Work waiting
    "active": 1    // Currently processing
  }
}
```

**Key Insights**:
- T2 working = wait for completion
- 2 pending = prioritize dispatch
- All idle = maximum parallelization opportunity

## Success Metrics

### Current State (Problematic)
- Decision speed: <1 second (too fast!)
- Context awareness: 40% (missing parallel work)
- Coordination success: 60%

### Target State (Intelligent)
- Decision speed: 3-5 seconds (thoughtful)
- Context awareness: 95% (full picture)
- Coordination success: 90%

## Conclusion

The evolution from reactive to proactive orchestration requires T0 to:
1. **ALWAYS** check for parallel work before deciding
2. **WAIT** for complete information when others are working
3. **ROUTE** based on model capabilities, not track assignments
4. **MONITOR** terminal health continuously

This patience and awareness will dramatically improve orchestration quality and reduce wasted work from premature decisions.