---
allowed-tools: Read, Edit, Write, Grep, WebSearch, Task, Bash(gh issue view:*), Bash(gh issue edit:*), Bash(jq *)
description: Analyze all ready tasks for decisions and decomposition
context-commands:
  - name: plan_exists
    command: '[ -f .claude/plan.md ] && echo "true" || echo "false"'
  - name: ready_count
    command: 'grep -c "\*\*Status:\*\* ready" .claude/plan.md 2>/dev/null || echo "0"'
  - name: questions_exist
    command: '[ -f .claude/questions.json ] && echo "true" || echo "false"'
  - name: open_questions
    command: '[ -f .claude/questions.json ] && jq -r "to_entries | map(select(.value.status == \"open\")) | length" .claude/questions.json || echo "0"'
---

# Task Analysis Phase

## Preflight Checks

- Plan exists: !{plan_exists}
- Ready tasks to analyze: !{ready_count}
- Questions file exists: !{questions_exist}
- Open questions: !{open_questions}

**If plan_exists is "false":**
Stop and inform user: "No plan found. Please run `/dev/plan/create` first."

**If ready_count is "0":**
Check if there are open questions:
- If yes: "No ready tasks. Run `/dev/plan/question` to answer !{open_questions} open questions."
- If no: "No ready tasks and no open questions. Run `/dev/plan/complete` to finalize the plan."

## Algorithm to Execute

### Queue All Tasks Then Process Sequentially

1. Build queue of ALL ready tasks:

Use the Grep tool to find ready tasks:
- Use Grep with pattern "\*\*Status:\*\* ready" on .claude/plan.md
- Use output_mode="content" with -n flag to get line numbers
- Count the results

If no tasks found, skip to completion.

2. Process the queue SEQUENTIALLY (one at a time):

Extract ALL task IDs and issue numbers from step 1 results.
Create a numbered list: 1. T-001 (Issue #101), 2. T-002 (Issue #102), etc.

Then process EACH task ONE AT A TIME:

FOR task X of Y total tasks:
  a. STATE EXPLICITLY: "Processing task X of Y: T-XXX"
  b. Launch EXACTLY ONE sub-agent:
     Task tool: description="Analyze T-XXX" subagent_type="general-purpose" 
     prompt="[see template below with T-XXX and #XXX substituted]"
  c. STATE EXPLICITLY: "Waiting for T-XXX to complete..."
  d. WAIT for the sub-agent to fully complete
  e. STATE EXPLICITLY: "✓ T-XXX complete. Moving to next task."
  f. THEN AND ONLY THEN proceed to the next task

CRITICAL ENFORCEMENT:
- You MUST launch only ONE Task tool call at a time
- You MUST wait for it to complete before launching the next
- You MUST NOT launch multiple Task tools in one message
- If your output shows Task(...) immediately followed by another Task(...), you have FAILED

VIOLATION EXAMPLES (FORBIDDEN):
❌ Task(Analyze T-001)
   Task(Analyze T-002)  <- FAILURE: Multiple tasks launched at once

✓ CORRECT:
Processing task 1 of 31: T-001
Task(Analyze T-001)
Waiting for T-001 to complete...
[... sub-agent executes ...]
✓ T-001 complete. Moving to next task.
Processing task 2 of 31: T-002
Task(Analyze T-002)
Waiting for T-002 to complete...
  
Sub-agent prompt template (replace [TASK_ID] with actual task ID, [ISSUE_NUM] with actual issue number *without* a #):
  ```
  "Analyze ONLY task [TASK_ID] from .claude/plan.md
  
  CONTEXT:
  - Your task ID: [TASK_ID]
  - GitHub issue number: [ISSUE_NUM]
  
  PHASE 1: GATHER ALL DATA
  
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
  
  PHASE 2: ANALYZE AND DECIDE PATH
  
  Determine which ONE path applies:
  
  PATH A - BLOCKED (needs technical decision):
    Criteria: ANY of these conditions:
    - Multiple technically valid approaches exist (e.g., JWT vs sessions, REST vs GraphQL)
    - Choice of library/framework/pattern needed (e.g., which state management, which test framework)
    - Algorithm selection required (e.g., search strategy, caching approach)
    - Data structure or storage decisions (e.g., normalized vs denormalized, SQL vs NoSQL)
    - Implementation would be hard to change later
    - Decision affects other tasks or components
    
    Prepare (don't execute yet):
    - Question for questions.json with next Q-XXX ID
    - Plan to change status to 'blocked'
    - Plan to add Q-XXX to dependencies
  
  PATH B - DECOMPOSE (>500 LOC):
    Criteria: Can split into 2+ non-overlapping functional pieces
    Prepare (don't execute yet):
    - Design 2+ subtasks using 100% rule (complete coverage, no overlap)
    - Each subtask gets next sequential T-XXX ID
    - Plan to change status to 'analyzed'
    - Plan to add "Decomposes into: [subtask IDs]"
  
  PATH C - SIMPLE (<500 LOC):
    Criteria: Clear, focused implementation under 500 LOC
    Prepare (don't execute yet):
    - SPECIFIC implementation guidance (algorithms, files, tests)
    - Plan to change status to 'analyzed'
  
  PHASE 3: EXECUTE ALL CHANGES
  
  1. Update plan.md with ALL changes at once:
     - Status change
     - Add Q-XXX to dependencies (if PATH A)
     - Add "Decomposes into:" field (if PATH B)
     - Add new subtasks after parent (if PATH B)
  
  2. Execute path-specific actions:
  
  IF PATH A (BLOCKED):
    a. Write updated questions.json with new question
    b. Update GitHub issue:
       gh issue edit [ISSUE_NUM] --add-label 'blocked' --body "
       ## Dependencies
       Must complete first:
       - [ ] #[dep_issue] T-XXX: [dep name]
       - [ ] Q-XXX: [question text]
       
       ## ⚠️ Blocked
       Waiting for architectural decision Q-XXX
       
       [Original task description from current body]"
  
  IF PATH B (DECOMPOSE):
    a. Run script: ~/.claude/commands/dev/claude-plan-issues
    b. After script completes, get subtask issue numbers from plan.md
    c. Update GitHub issue:
       gh issue edit [ISSUE_NUM] --body "
       ## Dependencies
       Must complete first:
       - [ ] #[dep_issue] T-XXX: [dep name]
       
       ## Decomposition
       This task has been decomposed into:
       - [ ] #[sub1_issue] T-XXX: [subtask1 name]
       - [ ] #[sub2_issue] T-YYY: [subtask2 name]
       
       [Original task description from current body]"
  
  IF PATH C (SIMPLE):
    Update GitHub issue:
    gh issue edit [ISSUE_NUM] --body "
    ## Dependencies
    Must complete first:
    - [ ] #[dep_issue] T-XXX: [dep name]
    
    ## Implementation Approach
    [Your SPECIFIC guidance - algorithms, patterns, architecture]
    
    ## Key Components
    [SPECIFIC components to build]
    
    ## Files to Create/Modify
    [SPECIFIC file paths]
    
    ## Testing Requirements
    [SPECIFIC test scenarios]
    
    [Original task description from current body]"
  
  CRITICAL RULES:
  - Only modify task [TASK_ID] in plan.md
  - Do not read or modify other tasks
  - Do not look at or mention remaining work
  - Complete ALL steps before exiting
  - If you mention any other task ID, you have failed"
  ```

3. After all sub-agents complete, provide summary:
```
✅ Task analysis complete:
- [N] tasks analyzed by sub-agents (processed sequentially)
- Check .claude/questions.json for any new technical questions
- Run `/dev/plan/question` if questions were created
- Run `/dev/plan/complete` if all tasks are analyzed
```

## ANTI-BATCHING ENFORCEMENT

**FORBIDDEN BEHAVIORS:**
- Launching multiple Task tools at once to "save time"
- Saying "I'll process these efficiently" or "Let me batch these"
- Trying to "optimize" by running tasks in parallel
- Skipping the wait statements between tasks

**WHY SEQUENTIAL IS MANDATORY:**
- Each sub-agent calculates the next available ID
- Parallel execution causes ID collisions (multiple T-032s)
- Sequential ensures each agent sees updated state from previous agents

**REMEMBER:** You've failed every time you tried to be "efficient" by batching. Follow the sequential process exactly as specified.

## Decision Creation Guidelines

### Good Questions (Create Q-XXX):
- "Should the API use REST or GraphQL?" 
- "Should sessions be stored in Redis or PostgreSQL?"
- "Should we use JWT or session cookies for auth?"
- "Which testing framework: Jest, Vitest, or Mocha?"
- "Canvas API or SVG for rendering?"
- "Recursive or iterative graph traversal?"
- "Synchronous or async event handling?"
- "In-memory caching or file-based caching?"

### Bad Questions (Don't Create):
- "How should we implement this?" (too vague)
- "What's the best approach?" (no concrete options)
- "Should we write tests?" (always yes)
- "Is this a good idea?" (too subjective)
- Trivial choices with no meaningful trade-offs (e.g., variable names)
- Decisions already covered by project conventions
- Purely stylistic preferences (use linter/formatter instead)

### Question Format
```json
{
  "Q-001": {
    "question": "Should the API use REST or GraphQL?",
    "context": "T-005 requires API design decision",
    "options": [
      {"choice": "REST", "pros": "Simple, standard", "cons": "Over-fetching"},
      {"choice": "GraphQL", "pros": "Flexible", "cons": "Complexity"}
    ],
    "affects": ["T-005", "T-006", "T-012"],
    "status": "open"
  }
}
```

## Task Decomposition Guidelines

### When to Decompose:
- Estimated implementation >500 LOC
- Multiple distinct functional pieces
- Can split with no overlap (100% rule)

### How to Decompose:
- MINIMUM 2 subtasks (single-child decomposition is invalid)
- Each subtask should be 100-300 LOC
- Subtasks should have clear boundaries
- No shared code between subtasks
- Clear integration points
- If you can't split into 2+ pieces, task is probably <500 LOC

## Important Notes

**How This Works:**
- Main agent builds a queue of all tasks upfront
- Sub-agents are launched sequentially from the queue
- Each sub-agent handles exactly ONE task in complete isolation
- IDs are checked fresh before each sub-agent

**Why This Prevents Issues:**
- No fatigue: Each task gets a fresh agent
- No batching: Sub-agents literally cannot see other tasks  
- No shortcuts: Each agent has explicit instructions
- No laziness: Main agent doesn't do analysis work

**File Safety:**
- Each sub-agent only modifies its assigned task in plan.md
- Sequential execution prevents ID collisions (each agent sees updated state)
- IDs are calculated fresh by each sub-agent when it runs
- Always use gh issue edit --body, NEVER gh issue comment

**Progress Tracking Requirements:**
- You MUST state "Processing task X of Y" before each sub-agent
- You MUST state "Waiting for T-XXX to complete..." after launching
- You MUST state "✓ T-XXX complete" before moving to next
- This makes batching violations immediately visible

**Violation Detection:**
- If console shows multiple Task(...) entries without intervening completion messages, you've violated the sequential requirement
- If you process tasks out of order (T-003 before T-002), you've failed
- If you say anything about "efficiency" or "batching", you've failed
