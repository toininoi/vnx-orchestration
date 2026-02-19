# VNX Learning System

## Purpose
Capture and analyze conversation patterns to identify process inefficiencies and optimization opportunities.

## Data Collection

### Conversation Logs
- `../state/t1_conversation.log` - Track A worker conversations
- `../state/t2_conversation.log` - Track B worker conversations
- `../state/t0_conversation.log` - T0 orchestrator conversations

### Log Structure
```
[Timestamp] User input
[Timestamp] Claude response
[Timestamp] Tool usage and results
```

## Analysis Framework

### Phase 1: Silent Collection (Days 1-3)
- Collect complete conversation data
- No automatic flagging or intervention
- Focus on natural workflow patterns

### Phase 2: Pattern Analysis (Day 4)
- LLM analysis of collected conversations
- Identify inefficiency patterns
- Develop trigger algorithms

### Phase 3: Trigger Development (Day 5+)
- Implement deterministic flagging
- Test trigger accuracy
- Refine based on real patterns

## Target Patterns

### Inefficiency Indicators
- Manual repetition >3 iterations
- Time investment >2 days on single issue
- Late discovery of better solutions
- Available infrastructure not used initially

### Success Patterns
- Quick problem resolution
- Efficient tool usage
- Proper discovery processes
- Optimal solution paths

## Analysis Tools
- `conversation_analyzer.py` - Pattern detection
- `trigger_generator.py` - Rule creation
- `learning_extractor.py` - Context updates