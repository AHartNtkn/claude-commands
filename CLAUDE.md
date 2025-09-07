# Command Design Philosophy

## Core Principle: LLM as Stateless Transformation Engine

The LLM is NOT a reliable long-term memory store. It is a transformation engine that:
1. Reads explicit state from files
2. Performs ONE well-defined transformation
3. Writes updated state back to files
4. Exits

All context necessary for progress MUST be externalized to files. The LLM's role is to handle tasks that cannot be automated with traditional scripts - those requiring natural language understanding, creative decomposition, or fuzzy pattern matching.

## Key Design Principles

1. **State in files, not memory** - The LLM reads, transforms, writes, exits
2. **Atomic operations** - One thing per invocation
3. **Explicit marking** - Visible state drives control flow
4. **Measurement over judgment** - Numeric thresholds, not subjective decisions
5. **Failure leads to decomposition** - Don't retry, break down
6. **Immutable IDs** - Once created, never changed
7. **State machines** - Explicit states with clear transitions
8. **Session-based processing** - Atomic, resumable work units

## Detailed Principles

### 1. State Externalization

**Principle:** Everything lives in files, not in the LLM's context

**What this means:**
- Current state: where we are in any process
- Pending work: what still needs to be done
- History: what has been done and when
- Relationships: how different pieces connect
- Decisions: what choices have been made or need to be made

**Examples:**
- `spec-state.json` - structured specification state
- `plan.md` versions - v0.1, v0.2, tracking each iteration
- `.walkthrough-state.json` - current chunk, visited chunks, session data
- `skills.json` - skill states and relationships
- GitHub issues - external state for task tracking

### 2. Atomic Operations

**Principle:** Each LLM invocation does exactly ONE thing

**What this means:**
- Single transformation per call
- Clear input → process → output
- No bundled operations
- Each step verifiable

**Examples:**

Bad:
- "Identify tasks that need decomposition and decompose them"
- "Answer the question and update all affected tasks"

Good:
- "Answer question Q-001"
- "Decompose task T-005"
- "Mark T-005 as needing decomposition"

Enforcement in commands:
- `/spec` - one question per turn
- `/plan` - one Q-XXX per iteration
- `/implement` - one test, then one implementation, then one refactor

### 3. File-Driven Control Flow

**Principle:** Files determine what happens next, not LLM memory

**What this means:**
- Next action determined by file state
- No implicit "remember to do X"
- Explicit markers for pending work
- Algorithmic progression

**Examples:**

State-driven actions:
- Is there an open Q-XXX? → Ask it
- Task marked "(ready for analysis)"? → Analyze it
- current_chunk < total_chunks? → Continue walkthrough

Never memory-driven:
- ❌ "Remember to check task T-005 after answering Q-003"
- ✅ Mark T-005 with "blocked_by: Q-003", then scan for this marker later

### 4. Measurement-Based Decisions

**Principle:** All decisions based on numeric thresholds, not subjective judgment

**What this means:**
- Every decision has a measurable criterion
- Thresholds are explicit and documented
- No "seems like" or "probably"
- Formulas and constants visible in files

**Examples:**
- Mastery: probability ≥ 0.85 (from Bloom's research)
- Decomposition: estimated LOC > 500
- Precision: SE(θ) < 0.30 for statistical significance
- Review timing: calculated from forgetting curve formula
- Complexity: cyclomatic complexity > 10 triggers refactor

Never:
- "Check if this seems too complex"
- "Decide if the student understands"

Always:
- "If complexity_score > 10, decompose"
- "If mastery_probability ≥ 0.85, mark MASTERED"

### 5. Explicit Marking and Tracking

**Principle:** If something needs attention, mark it visibly in the file

**What this means:**
- States and needs are visible markers
- Procedures scan for markers mechanically
- Process and remove markers atomically
- No hidden state or implicit tracking

**Examples:**
- Task titles: "T-005: Implement auth (ready for analysis)"
- Status fields: `"state": "NEEDS_REVIEW"`
- Dependencies: `"blocked_by": ["Q-001", "Q-003"]`
- Markers: `"needs_decomposition": true`

The procedure becomes mechanical:
1. Find all items with marker X
2. Process each one
3. Remove marker X

### 6. Immutable IDs and Traceability

**Principle:** Once created, IDs never change

**What this means:**
- IDs are permanent references
- History preserved even after completion
- Relationships remain traceable over time
- Deprecation over deletion

**Examples:**
- Task T-005 remains T-005 even if superseded
- Question Q-003 stays in history after answering
- Version progression: v0.1 → v0.2 → v1.0 (never reused)
- Git commits provide permanent audit trail
- Session IDs: session_20241207_143025 is immutable

### 7. State Machine Pattern

**Principle:** Entities progress through explicit states with clear transitions

**What this means:**
- Every entity has defined states
- Transitions follow rules, not judgment
- Current state determines valid actions
- Progress is logged and irreversible

**Examples:**
- Skills: UNTESTED → UNREADY → MASTERED → NEEDS_REVIEW
- Tasks: pending → in_progress → completed
- Questions: open → answered → integrated
- Plan versions: draft (v0.x) → frozen (v1.0)
- Markers: "(ready for analysis)" → analyzed → removed

### 8. Session-Based Processing

**Principle:** Work happens in atomic, resumable sessions

**What this means:**
- Each interaction creates a session record
- Sessions have clear boundaries
- Complete input/output/decisions in one file
- Failed sessions can be analyzed
- Work can resume from session state

**Examples:**
- `session_20241207_143025.json` - complete assessment record
- `teach_20241207_150000.json` - teaching session with all materials
- `review_20241207_160000.json` - review session with responses
- Git commits per session for versioning
- Timestamped work products for audit trail

### 9. Failure Through Decomposition

**Principle:** When something fails, decompose rather than retry

**What this means:**
- Failure indicates excessive complexity
- Break into simpler prerequisite parts
- Add prerequisites to queue
- Don't repeat the same approach

**Examples:**
- Failed skill assessment → expand into prerequisite skills
- Task estimated >500 LOC → decompose into subtasks
- Q-XXX reveals complexity → create clarifying sub-questions
- Failed test → write simpler test cases first
- Complex requirement → break into testable components

## Implementation Patterns

### Pattern 1: Iterative Refinement
```
while (open_questions exist):
    1. Read plan.md
    2. Select next Q-XXX (by specific algorithm)
    3. Ask user
    4. Apply answer to plan.md
    5. Mark affected tasks
    6. Process marked tasks
    7. Write plan.md with new version
```

### Pattern 2: Explicit Work Queue
```
When Q-XXX answered:
    1. Remove Q-XXX from all Dependencies fields
    2. For each task where Q-XXX was removed:
        - Add "needs_analysis: true"
    3. Save file

Later:
    1. Find all tasks with needs_analysis = true
    2. For each one:
        - Analyze for decomposition
        - Remove needs_analysis marker
```

### Pattern 3: Sub-Agent Delegation
```
When context would overflow:
    1. Main agent identifies specific work scope
    2. Launch sub-agent with ONLY that scope
    3. Sub-agent returns structured findings
    4. Main agent integrates findings into tracked state
```

### Pattern 4: State Machine Progression
```
while (not in terminal state):
    1. Read current state from file
    2. Determine valid transitions
    3. Execute transition based on rules
    4. Update state in file
    5. Log transition for audit
```

### Pattern 5: Failure Recovery Through Decomposition
```
When assessment/task fails:
    1. Don't retry the same thing
    2. Analyze failure patterns
    3. Decompose into simpler prerequisites
    4. Add prerequisites to queue
    5. Mark original as blocked
```

### Pattern 6: Algorithm Externalization
```
For complex algorithms (spacing, IRT, etc):
    1. Document formula in command file
    2. Store parameters in config.json
    3. Show calculations explicitly
    4. Reference research sources
    5. Make all constants configurable
```

## Anti-Patterns to Avoid

### ❌ Implicit Memory
"Remember to check X after Y" - Everything must be written to files

### ❌ Bundled Operations
"Identify and fix all issues" - Each operation must be atomic

### ❌ LLM Judgment Calls
"Decide if this needs attention" - Use explicit markers and rules

### ❌ Context Accumulation
"Keep track of all previous..." - State lives in files, not context

### ❌ Vague Instructions
"Identify tasks" - What does identify mean? Mark them? List them? Process them?

### ❌ Hidden Logic
"Use appropriate algorithm" - All algorithms must be explicit with documented formulas

### ❌ Subjective Thresholds
"If it seems complex" - Use measurable metrics with numeric thresholds

### ❌ Stateless Retries
"Try again if it fails" - Failures should trigger decomposition or state changes

## File Structure Requirements

Every command should specify:
1. What files it reads/writes
2. The exact schema/format of those files
3. How state transitions are tracked
4. What markers/flags are used
5. How relationships are maintained
6. Session file naming and structure
7. Cache/temporary file management
8. Version control integration (git commits)

## Testing the Design

A well-designed command should be able to:
1. Resume from any interruption by reading file state
2. Handle iterative refinement without losing context
3. Maintain correctness across hundreds of iterations
4. Delegate work without losing track of progress
5. Provide complete traceability of all decisions

## Summary

The LLM is powerful but unreliable for long-term memory. By externalizing all state to files and using the LLM only for transformations that require natural language understanding, we create robust, resumable, traceable workflows that can handle complex, long-running tasks without degradation.

The key insight: treat the LLM as a stateless function that transforms file state, not as a stateful agent that maintains context. This approach leverages the LLM's strengths (language understanding, pattern matching, creative problem solving) while mitigating its weaknesses (context limits, memory unreliability, inconsistent behavior across sessions).