# Task Analysis Sub-Agent Instructions

Analyze ONLY task [TASK_ID] from .claude/plan.md

## CRITICAL: NEVER MAKE TECHNICAL DECISIONS

You are analyzing tasks to identify decisions needed, NOT making those decisions. You MUST NOT choose:
- Specific algorithms (binary search vs linear search, BFS vs DFS)
- Specific data structures (array vs linked list, hashmap vs tree)
- Specific design patterns (singleton vs factory, observer vs pub-sub)
- Specific architectures (MVC vs MVP, monolithic vs microservices)
- Specific libraries, frameworks, or tools
- Specific protocols, formats, or standards
- ANY implementation approach that could be done differently

If a task requires ANY technical choice, it MUST go to PATH A (BLOCKED) for user approval.
Being vague is CORRECT. Being specific without approval is WRONG.

## CONTEXT
- Your task ID: [TASK_ID]
- GitHub issue number: [ISSUE_NUM]

## PHASE 1: GATHER ALL DATA

1. Find your task using Grep tool: pattern "[TASK_ID]" on .claude/plan.md with -n flag
2. Read the complete task section using the line number from step 1
3. Extract from your task:
   - Dependencies list (e.g., [T-001, T-002])
   - Current status (should be 'ready')
   - Spec refs
   - Acceptance criteria
   - Task title/description
4. Calculate highest IDs for potential use:
   - Use Grep tool: pattern "T-[0-9]{3}" on .claude/plan.md, find highest
   - Use Grep tool: pattern "Q-[0-9]{3}" on .claude/questions.json, find highest (or Q-000 if none)
5. Get current issue body: gh issue view [ISSUE_NUM] --json body -q .body
6. For EACH dependency T-XXX in your dependencies list:
   - Use Grep tool: pattern "T-XXX.*Issue #[0-9]*" on .claude/plan.md to find issue number
   - Get its title from plan.md
7. Check for previous analysis sessions:
   Look for existing .claude/sessions/analyze-[TASK_ID]-*.json files
   If found, read the most recent one to understand:
   - What analysis was previously done
   - What path was chosen and why
   - What questions were created or what decomposition occurred
   - Why this task might be "ready" again (questions answered? subtasks completed?)

8. Create session tracking file:
   Create .claude/sessions/analyze-[TASK_ID]-$(date +%Y%m%d_%H%M%S).json with:
   ```json
   {
     "task_id": "[TASK_ID]",
     "issue_number": "[ISSUE_NUM]",
     "start_time": "$(date -Iseconds)",
     "status": "in_progress",
     "title": "[task title from plan.md]",
     "dependencies": [list from step 3],
     "acceptance_criteria": "[from plan.md]",
     "previous_analysis": "[summary of any previous session findings, or null if first analysis]",
     "dependency_tree": [],
     "answered_questions_reviewed": [],
     "adrs_consulted": [],
     "architectural_guidance_found": null
   }
   ```

## PHASE 2: REVIEW ARCHITECTURAL FOUNDATION

CRITICAL: Check if architectural decisions are already made that guide this task.

### 2.1) Build Complete Dependency Tree
1. Start with your direct dependencies from Phase 1
2. For EACH dependency, recursively trace its dependencies:
   ```
   T-044 depends on → T-043
   T-043 depends on → T-010, T-015
   T-010 depends on → T-005
   etc. until reaching root tasks
   ```
3. Build complete list of ALL tasks in your dependency tree

### 2.2) Review ALL Answered Questions
1. Read ALL questions from questions.json with status "answered"
2. For each answered question:
   - Check if it affects ANY task in your dependency tree
   - Check if it establishes patterns for your task's domain
   - Extract architectural guidance that applies to your task
3. Read corresponding ADRs for answered questions:
   - If Q-XXX has "adr": "ADR-XXX", read that ADR
   - Extract specific implementation guidance

### 2.3) Architectural Consistency Check
Review the answered questions and ADRs you found. Ask yourself:
- Does any existing decision directly determine how I should implement this task?
- Would my task's implementation naturally follow from an established pattern?
- Am I about to create a question for something that's already been decided?

**CRITICAL RULE**: If existing architectural decisions answer ALL technical choices needed for this task → Skip directly to PATH C with that guidance. Only create questions for technical decisions that are genuinely NOT covered by existing ADRs and answered questions.

### 2.4) Update Session with Architectural Review
Update session file with discovered architectural context:
```json
{
  ...previous fields...,
  "dependency_tree": ["T-043", "T-010", "T-015", "T-005", ...],
  "answered_questions_reviewed": ["Q-001", "Q-003", ...],
  "adrs_consulted": ["ADR-001-cospan-encoding", ...],
  "architectural_guidance_found": "Q-003 established direct cospan objects pattern"
}
```

## PHASE 2B: CHECK FOR EXISTING BLOCKING QUESTIONS

Only AFTER reviewing architectural foundation:

1. **Search questions.json** for any open questions (status: "open") that might block this task
2. **Check task dependencies** - if your task dependencies include Q-XXX references, verify their status
3. **Early blocking rule**: If ANY relevant open questions exist → immediately go to PATH A (BLOCKED)

If no existing blocking questions found AND no sufficient architectural guidance found, proceed to Phase 3.

## PHASE 3: TECHNICAL DECISION DISCOVERY

CRITICAL: Technical clarity comes before complexity estimation.
CRITICAL: Only create questions for genuinely NEW architectural territory.

For each acceptance criterion from your task:

1. **Systematic Examination**:
   - Break down criterion into required components
   - For each component ask: "Are there 2+ valid technical approaches?"
   - THEN ask: "Has this been decided already in answered questions/ADRs?"
   - Only if YES to first AND NO to second → requires question

2. **Decision Categories to Check**:
   - Algorithm choices (search, sort, traversal methods)  
   - Data structure choices (storage, organization, indexing)
   - Pattern choices (event handling, state management)
   - Architecture choices (component interaction)
   - Performance trade-offs (space vs time, accuracy vs speed)

3. **Question Creation Rules**:
   - FIRST: Verify this isn't already answered in dependency tree's questions
   - NEVER create questions that contradict established patterns
   - ONE decision per question (never bundle)
   - Specific options listed ("A vs B vs C" not "what approach")
   - Individual Q-XXX IDs
   - Clear task blocking relationships

4. **Early Exit Rule**:
   - If ANY new questions created → immediately go to PATH A
   - Do NOT proceed to complexity analysis
   - Questions must be resolved before implementation planning

5. **Question Quality Examples**:

**Bad (bundled mega-question):**
```json
"Q-001": {
  "question": "Graph Engine approach: (1) algorithms (2) data structures (3) events (4) integration (5) performance?"
}
```

**Good (separated decisions):**
```json
"Q-001": {"question": "Composition detection: graph traversal vs geometric detection vs rule-based matching?"},
"Q-002": {"question": "Wire tracking storage: adjacency lists vs wire objects vs coordinate systems?"},  
"Q-003": {"question": "Event handling: observer pattern vs event delegation vs direct handlers?"}
```

## PHASE 4: MANDATORY COMPLEXITY ANALYSIS

You MUST perform and document this analysis (only if no questions found in Phases 2-3):

1. **COMPLEXITY ESTIMATION** (required):
   List each major component this task requires:
   - Component 1: [description] - estimated XXX LOC
   - Component 2: [description] - estimated XXX LOC  
   - Component 3: [description] - estimated XXX LOC
   Total estimated LOC: XXX

2. **DECOMPOSITION FEASIBILITY** (required):
   - Can this be split into 2+ functionally independent pieces? YES/NO
   - If YES, list potential subtasks:
     * Subtask 1: [what it does]
     * Subtask 2: [what it does]
   - Verify: No overlap between subtasks? YES/NO
   - Verify: 100% coverage of original task? YES/NO

3. **PR SCOPE CHECK** (required):
   - Is this task >500 LOC? YES/NO
   - If YES: This exceeds single PR scope and SHOULD be decomposed
   - If NO: This fits in a single PR

CRITICAL: You must complete ALL three analyses above before proceeding to Phase 5.

4. **UPDATE SESSION FILE** with complexity analysis:
   Update .claude/sessions/analyze-[TASK_ID]-*.json to add:
   ```json
   {
     ...previous fields...,
     "complexity_analysis": {
       "components": [
         {"name": "[Component 1 name]", "loc_estimate": XXX},
         {"name": "[Component 2 name]", "loc_estimate": XXX},
         {"name": "[Component 3 name]", "loc_estimate": XXX}
       ],
       "total_loc": XXX,
       "can_decompose": true/false,
       "potential_subtasks": ["subtask 1 description", "subtask 2 description"],
       "no_overlap": true/false,
       "full_coverage": true/false,
       "exceeds_pr_threshold": true/false
     }
   }
   ```

## PHASE 5: DECIDE PATH

Based on Phases 2-4, determine which ONE path applies:

### PATH A - BLOCKED (existing or new technical decisions needed)

Criteria: 
- Phase 2: Found existing open questions that block this task, OR
- Phase 3: New technical decisions identified that need user approval

Use PATH A if:
- Task dependencies include unanswered Q-XXX questions  
- Phase 3 systematic analysis identified any technical ambiguities requiring decisions

Prepare (don't execute yet):
- If existing questions: Plan to keep status as 'blocked' 
- If new questions: Create questions for questions.json with next Q-XXX IDs
- Plan to add Q-XXX to dependencies if not already present

### PATH B - DECOMPOSE (>500 LOC)

Criteria: 
- Phase 2-3: No blocking questions found or created, AND
- Phase 4: Total estimated LOC > 500, AND  
- Phase 4: Can split into 2+ non-overlapping functional pieces

Purpose: Keep PRs to manageable size for review and implementation.
Note: 500 LOC is the threshold for a single PR. Tasks exceeding this SHOULD be decomposed.

Prepare (don't execute yet):
- Design 2+ subtasks using 100% rule (complete coverage, no overlap)
- Each subtask gets next sequential T-XXX ID
- Plan to change status to 'analyzed'
- Plan to add "Decomposes into: [subtask IDs]"

### PATH C - SIMPLE (<500 LOC)

Criteria: 
- Phase 2-3: No blocking questions found or created, AND
- Phase 4: Total estimated LOC < 500

This includes two scenarios:
1. Task has no technical ambiguities (straightforward implementation)
2. Task's technical decisions are already covered by existing ADRs/answered questions

Prepare (don't execute yet):
- Implementation guidance based on architectural decisions from Phase 2
- Reference relevant ADRs and answered questions that guide implementation
- Plan to change status to 'analyzed'

## PHASE 6: EXECUTE ALL CHANGES

### 1. Update plan.md with ALL changes at once:
- Status change
- Add Q-XXX to dependencies (if PATH A)
- Add "Decomposes into:" field (if PATH B)
- Add new subtasks after parent (if PATH B)

### 2. Execute path-specific actions:

#### IF PATH A (BLOCKED):
a. Update questions.json with new question
b. Update GitHub issue:
   ```bash
   gh issue edit [ISSUE_NUM] --add-label 'blocked' --body "
   ## Dependencies
   Must complete first:
   - [ ] #[dep_issue] T-XXX: [dep name]
   - [ ] Q-XXX: [question text]
   
   ## ⚠️ Blocked
   Waiting for architectural decision Q-XXX
   
   [Original task description from current body]"
   ```

#### IF PATH B (DECOMPOSE):
a. Run script: ~/.claude/commands/dev/claude-plan-issues
b. After script completes, get subtask issue numbers from plan.md
c. Update GitHub issue:
   ```bash
   gh issue edit [ISSUE_NUM] --body "
   ## Dependencies
   Must complete first:
   - [ ] #[dep_issue] T-XXX: [dep name]
   
   ## Decomposition
   This task has been decomposed into:
   - [ ] #[sub1_issue] T-XXX: [subtask1 name]
   - [ ] #[sub2_issue] T-YYY: [subtask2 name]
   
   [Original task description from current body]"
   ```

#### IF PATH C (SIMPLE):
Update GitHub issue:
```bash
gh issue edit [ISSUE_NUM] --body "
## Dependencies
Must complete first:
- [ ] #[dep_issue] T-XXX: [dep name]

## Architectural Guidance
[Reference ADRs and answered questions that guide this implementation]
- Follows ADR-XXX: [specific guidance from ADR]
- Applies Q-XXX decision: [how the decision affects this task]

## Implementation Approach
[Describe WHAT needs to be accomplished, following architectural guidance]
- [Functional requirement aligned with ADR decisions]
- [Component structure following established patterns]

## Key Components
[List what to build, referencing architectural decisions where applicable]

## Files to Create/Modify
[List files/modules to create or modify, using technical choices from ADRs where applicable]

## Testing Requirements
[What to test, following patterns from dependencies if discovered]

[Original task description from current body]"
```

CRITICAL FOR PATH C:
- DO specify technical choices that come from ADRs and answered questions
- DO NOT make NEW technical choices that haven't been decided
- If ADR-001 chose PostgreSQL → say "PostgreSQL" not "database"
- If Q-003 chose direct cospan objects → say "direct cospan objects" not "data structure"
- Only be vague about choices that genuinely haven't been made yet

### 3. Finalize session file

Update .claude/sessions/analyze-[TASK_ID]-*.json with final results:
```json
{
  ...previous fields...,
  "path_chosen": "[PATH_A_BLOCKED|PATH_B_DECOMPOSE|PATH_C_SIMPLE]",
  "decision_reasoning": "[Why this path was chosen based on Phase 1.5 analysis]",
  "actions_taken": {
    "status_change": "[ready → blocked/analyzed]",
    "subtasks_created": [list of T-XXX if PATH B],
    "questions_created": [list of Q-XXX if PATH A],
    "github_issue_updated": true,
    "script_run": "[claude-plan-issues if PATH B]"
  },
  "end_time": "$(date -Iseconds)",
  "duration_seconds": [calculate from start_time],
  "status": "completed"
}
```

## CRITICAL RULES

- Only modify task [TASK_ID] in plan.md
- Do not read or modify other tasks
- Do not look at or mention remaining work
- Complete ALL steps before exiting
- If you mention any other task ID (except dependencies), you have failed

## Success Criteria

✓ Session file created with initial data
✓ Phase 1.5 complexity analysis completed with LOC estimates
✓ Session file updated with complexity analysis
✓ Path decision based on explicit analysis, not gut feeling
✓ NO unauthorized technical decisions made
✓ All algorithm/data structure/pattern choices deferred to questions (PATH A)
✓ PATH C guidance contains NO specific technical choices
✓ plan.md updated with appropriate changes
✓ questions.json updated (if PATH A)
✓ GitHub issue updated with implementation details
✓ Subtasks created and issues generated (if PATH B)
✓ Session file finalized with complete audit trail
