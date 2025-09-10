# Command Design Philosophy

## Core Principle: LLM as Stateless Transformation Engine

The LLM is NOT a reliable long-term memory store. It is a transformation engine that:
1. Reads explicit state from files
2. Performs ONE well-defined transformation
3. Writes updated state back to files
4. Exits

All context necessary for progress MUST be externalized to files. The LLM's role is to handle tasks that cannot be automated with traditional scripts - those requiring natural language understanding, creative decomposition, or fuzzy pattern matching. Mechanical, algorithmic operations should be delegated to scripts that the LLM invokes.

Commands must account for the LLM's tendency to optimize and take shortcuts. Explicit anti-patterns, violation detection, and progress tracking requirements are essential to ensure compliance with the intended algorithm.

## The 15 Core Principles

1. **State in files, not memory** - The LLM reads, transforms, writes, exits
2. **Atomic operations** - One thing per invocation
3. **Explicit marking** - Visible state drives control flow
4. **Measurement over judgment** - Numeric thresholds, not subjective decisions
5. **Failure leads to decomposition** - Don't retry, break down
6. **State field pattern** - State belongs in explicit fields, not embedded in data
7. **Immutable IDs** - Once created, never changed
8. **State machines** - Explicit states with clear transitions
9. **Session-based processing** - Atomic, resumable work units
10. **Algorithmic iteration** - Process items one at a time using explicit search-modify-repeat loops
11. **Discovery over extraction** - Complex information emerges during analysis, not upfront
12. **Script delegation** - Mechanical operations belong in scripts, not AI loops
13. **Command decomposition** - Complex workflows split into focused, single-purpose commands
14. **Fresh agent per iteration** - For loops without memory needs, use sequential fresh sub-agents
15. **Use proper tools over bash commands** - When a tool exists (Grep, Read, etc.), use it instead of bash equivalents

## Detailed Principles

### 1. State Management
Combines: State externalization, State fields, Immutable IDs, State machines

**Core concept:** All state lives in files with explicit fields and clear transitions.

**Implementation:**
- Store state in dedicated JSON/Markdown files
- Use explicit `status` or `state` fields (never embed in titles/names)
- IDs never change once created (T-001 remains T-001 forever)
- Define state machines with clear transitions

**Example state machine:**
```
States: ready → blocked → analyzed → complete
Transitions:
- ready→blocked: dependency added
- blocked→ready: dependency resolved  
- ready→analyzed: analysis complete
- any→obsolete: superseded
```

**File examples:**
```json
{
  "T-001": {
    "title": "Implement auth",
    "status": "ready",  // Explicit state field
    "id": "T-001"        // Immutable
  }
}
```

### 2. Processing Patterns
Combines: Atomic operations, Session-based processing, Algorithmic iteration, Fresh agent per iteration

**Core concept:** Process one thing completely before moving to next.

**Sequential fresh sub-agents pattern:**
```bash
# Build queue of all items upfront
grep "pattern" file > queue.txt

# Process with fresh sub-agent per item
while read -r item; do
  Launch Task sub-agent: "Process item $item"
  Wait for completion
done < queue.txt
```

**Why use sub-agents:**
- Each iteration gets fresh context (no fatigue)
- Sub-agent sees only one item (cannot batch)
- Main agent just dispatches (no analysis work)

**Session pattern:**
- Each operation creates timestamped session file
- Contains complete input/output/decisions
- Enables resumption and audit

### 3. Control Flow
Combines: File-driven flow, Explicit marking, Measurement, Failure handling

**Core concept:** Files determine next action, not memory.

**Implementation:**
- Check file state to determine next action
- Use markers for pending work: `needs_review: true`
- Numeric thresholds for decisions: `complexity > 10 → decompose`
- When something fails, decompose rather than retry

**Example:**
```javascript
// File-driven control
if (grep("Status: ready", "plan.md")) {
  // Process ready tasks
} else if (grep('"status": "open"', "questions.json")) {
  // Handle open questions  
}
```

### 4. Advanced Patterns

#### Discovery Over Extraction
Don't try to identify all questions/issues upfront. Let them emerge during analysis:
- Questions arise when analyzing specific tasks
- Complexity discovered during implementation planning
- Dependencies revealed through decomposition
- Technical decisions become apparent during detailed analysis

**Important:** Overly narrow criteria (e.g., "significant architectural decisions") will miss important choices. Many implementation decisions don't seem "architectural" but still need consistent resolution across the codebase.

#### Script Delegation  
When AI is doing mechanical loops, extract to a script:

**Signs you need a script:**
- Repetitive operations
- No natural language understanding required
- Deterministic transformation rules

**Example:** Creating 50 GitHub issues
- **Bad:** AI loops creating issues one by one
- **Good:** AI creates structured plan.md, script processes it

#### Sequential Fresh Sub-Agents
When processing multiple items that don't need memory between them:

**When to use:**
- Processing all ready tasks for analysis
- Answering multiple open questions
- Any loop where iterations are independent

**Implementation:**
```bash
# Queue all work upfront
grep "Status: ready" plan.md > tasks.txt

# Process sequentially with fresh agents
while read -r task; do
  Task tool: "Analyze task $task"
  # Wait for completion before next
done < tasks.txt
```

**Why sequential (not parallel):**
- Avoids file conflicts (plan.md, questions.json)
- Prevents ID collisions (each agent sees updated state)
- Ensures correct dependency tracking

**When sequential is MANDATORY (not just preferred):**
- Shared state modifications (IDs, counters, indexes)
- File sections that could conflict
- Any resource that doesn't handle concurrent access

**Enforcement techniques:**
- Require explicit progress statements ("Processing X of Y")
- Require waiting confirmation ("Waiting for completion...")
- Make parallel execution a named violation
- Include examples of forbidden patterns (multiple Task calls at once)

**Key insight:** The purpose of externalizing state to files is to enable stateless processing. Sequential fresh sub-agents extend this principle to the loop level - stateless between iterations, not just between commands.

#### Command Decomposition
Complex workflows need separate commands per phase:

**Structure:**
```
/workflow/         # Router command
/workflow/create   # Phase 1
/workflow/process  # Phase 2  
/workflow/complete # Phase 3
```

Each command:
- Single responsibility
- Completes phase entirely
- Tells user next command

## Command Workflow Design Principles

### Explicit Phase Integration
Never rely on vague instructions like "consider X when deciding" or "identify Y during analysis". Create dedicated numbered phases with specific steps and clear deliverables.

❌ **Vague:** "Consider performance implications when choosing algorithms"  
✅ **Explicit:** "Phase 3: Performance Analysis - examine each algorithm option for time/space complexity"

❌ **Implicit:** "Identify technical decisions needed"
✅ **Explicit:** "Phase 2: Technical Decision Discovery" with systematic examination checklist

### Priority Through Placement  
Phase order communicates importance and ensures critical work isn't skipped:
- Blocking conditions/prerequisites → Phase 1
- Core required analysis → Phase 2-3  
- Optional/conditional work → Later phases

### Early Exit Patterns
Check blocking conditions immediately with explicit exit rules:
```bash
Phase 1: Check existing blockers → Exit to PATH A if found
Phase 2: Check for new blockers → Exit to PATH A if found
Phase 3: Proceed with main analysis only if no blockers
```

### Session Integration Requirement
Every major workflow step must update session/state files for audit trails and resumability. Don't just track final outcomes - track the decision-making process.

**Why These Principles Matter:**
Commands that say "consider X" without dedicated phases for that consideration will have that consideration done by gut feeling, inconsistently, or skipped entirely. Explicit phases with clear deliverables ensure systematic execution.

## Command Design Principles

### Resource References
Always use absolute paths for scripts, templates, and resources:
- ✓ `~/.claude/commands/dev/script-name` 
- ❌ `dev/script-name`
Commands run from user's project directory, not command directory.

### Required Resources
If a command requires a template/script/file:
1. Specify full absolute path
2. Include explicit failure instruction: "If [resource] cannot be found, STOP and inform user"
3. NEVER allow improvisation or substitution

### Technical Decisions
Commands must NEVER make technical choices for the user:
- Algorithm choices (sorting, searching, traversal)
- Data structure choices (arrays vs lists vs trees)  
- Design pattern choices (observer vs pub-sub)
- Library/framework/tool choices

If multiple valid approaches exist, create a question. Being vague about unchosen implementations is CORRECT.

### Pattern Matching Precision
Be specific about context to avoid false matches:
- ✓ `grep '^\* \*\*\[ \] T-[0-9].*\[Issue #TBD\]'` (only task lines)
- ❌ `grep '\[Issue #TBD\]'` (matches anywhere including comments)

### Progress Statements as Enforcement
Required progress statements prevent violations:
- "Processing X of Y" - proves not batching
- "Waiting for completion" - proves sequential  
- "Complete" - proves finished before next
Missing statements indicate algorithm violation.

### Mandatory vs Optional
Command instructions are MANDATORY unless explicitly marked optional:
- "Load from template" = MUST load, not "try to load"
- "Process sequentially" = MUST be sequential
- "Create session file" = MUST create
Mark optional steps explicitly: "OPTIONAL: ..."

### Audit Trail Pattern
For complex operations, use session files:
```json
{
  "start_time": "ISO-8601",
  "initial_state": {...},
  "decisions": {...},
  "actions_taken": [...],
  "end_time": "ISO-8601",
  "status": "completed"
}
```
Location: `.claude/sessions/[command]-[id]-[timestamp].json`

## Implementation Patterns

### Pattern: Grep-Based Iteration
```bash
# Process items one at a time
WHILE (grep finds "pattern"):
  item=$(grep -m1 "pattern" file)
  # Process item completely
  # Apply changes
  # Continue
```

### Pattern: Single-Pass Completeness
```bash
# Do everything for an item before moving on
For each task:
  1. Create task
  2. Add to plan
  3. Create GitHub issue
  4. Link relationships
  # Never: create now, update later
```

### Pattern: Sub-Agent Delegation
```bash
When context would overflow:
  1. Identify specific scope
  2. Launch sub-agent with ONLY that scope
  3. Integrate structured findings
```

### Pattern: Multi-Phase Commands
```bash
# Separate commands per phase
/cmd/phase1   # Complete phase 1 entirely
/cmd/phase2   # Complete phase 2 entirely
/cmd          # Router checking state
```

### Pattern: Violation Detection
Include in commands to prevent common failures:
```
FORBIDDEN BEHAVIORS:
- Launching multiple tasks at once
- Saying "I'll optimize this"
- Skipping progress statements

REQUIRED TRACKING:
✓ State "Processing X of Y" before each task
✓ State "Waiting for completion" after launch
✓ State "Task complete" before next

VIOLATION EXAMPLES:
❌ Task(Analyze T-001) Task(Analyze T-002)  <- FAILURE
✓ Task(Analyze T-001) [wait] Task(Analyze T-002)  <- CORRECT
```

## Anti-Patterns (Avoid These)

❌ **Implicit Memory** → Write everything to files  
❌ **Bundled Operations** → Make each operation atomic  
❌ **LLM Judgment** → Use measurable thresholds  
❌ **Vague Instructions** → Use explicit search patterns  
❌ **Hidden Logic** → Document all algorithms  
❌ **Stateless Retries** → Decompose on failure  
❌ **Deferred Operations** → Complete items in one pass  
❌ **Embedded State** → Use dedicated state fields  
❌ **AI Mechanical Loops** → Extract to scripts  
❌ **HTML Conditional Comments** → Split into separate commands  
❌ **Information Overload** → Show only relevant phase  
❌ **Long loops in single agent** → Use sequential fresh sub-agents  
❌ **"Efficient" batching** → Follow the specified algorithm exactly  
❌ **Relative Resource Paths** → Use absolute paths (~/.claude/commands/...)  
❌ **Assuming Technical Decisions** → Create questions for all choices  
❌ **Improvising When Resources Missing** → Fail explicitly with error  

## Case Studies

### Case Study: Algorithmic Loop Fix

**Problem:** "For any task where Q-XXX was removed" requires implicit tracking

**Solution:** Explicit algorithm:
```bash
WHILE (grep finds Q-XXX):
  1. Find FIRST task with Q-XXX
  2. Remove Q-XXX
  3. Update status if needed
  4. REPEAT
```

No tracking needed - search drives iteration.

### Case Study: GitHub Issue Script Extraction

**Problem:** AI creating 50+ issues one by one (slow, expensive, inconsistent)

**Solution:** 
1. AI creates structured plan.md
2. Script `claude-plan-issues` handles mechanical loop
3. 50 issues created in 30 seconds vs 15 minutes

**Lesson:** Extract mechanical operations to scripts.

## Quick Reference

### Common Good Examples
- Question: "Should API use REST or GraphQL?"
- Status field: `"status": "ready"`
- Task ID: `T-001` (never changes)
- Session file: `session_20241207_143025.json`

### Common Bad Examples  
- Question: "How should we implement this?" (too vague)
- Embedded state: "T-001: Auth (ready)" (state in title)
- Changing IDs: T-001 → TASK-001 (IDs must be immutable)
- No session tracking: Results lost on failure

### Standard File Structure
```
.claude/
├── plan.md           # Task breakdown structure
├── questions.json    # Open decisions
├── spec-state.json   # Specification state
├── ADRs/            # Architecture Decision Records
└── sessions/        # Session records
```

### Common State Machines

**Task States:**
```
ready → blocked → ready → analyzed → complete
```

**Question States:**
```
open → answered → integrated
```

**Plan Versions:**
```
v0.1 → v0.2 → ... → v1.0 (frozen)
```

## Summary

The LLM is powerful but unreliable for long-term memory. By externalizing all state to files and using the LLM only for transformations that require natural language understanding, we create robust, resumable, traceable workflows that can handle complex, long-running tasks without degradation.

**Key insight:** Treat the LLM as a stateless function that transforms file state, not as a stateful agent that maintains context.

## Criteria Design Principles

When creating decision criteria in commands:

**Inclusive over exclusive:**
- Start with broad criteria and provide examples
- "Any technical decision" better than "significant architectural decisions"  
- Include normal cases, not just edge cases

**Concrete examples over abstract rules:**
- Good: "JWT vs sessions, REST vs GraphQL, Jest vs Vitest"
- Bad: "Significant trade-offs affecting architecture"

**Multiple paths to qualification:**
- Use "ANY of these conditions" not "ALL of these conditions"
- List specific scenarios that qualify
- Lower the bar for inclusion rather than raising it

**Why this matters:** Overly narrow criteria cause important decisions to be missed. It's better to capture too many decisions than to miss critical ones.