---
allowed-tools: Read, Edit, Write, Grep, WebSearch, Task, Bash(gh issue view:*), Bash(gh issue edit:*), Bash(jq *)
description: Analyze ready tasks for technical decisions and decomposition
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

## Purpose
Analyze ready tasks from `.claude/plan.md` to identify technical decisions needed and decompose large tasks. Each task is handled by a fresh sub-agent to ensure consistent analysis quality.

## Core Principle: No Unauthorized Technical Decisions
The analysis phase identifies decisions that need to be made, it does NOT make those decisions. Any choice about algorithms, data structures, patterns, architectures, or tools must be deferred to user approval via questions.

## Current State
- Plan exists: !{plan_exists}
- Ready tasks to analyze: !{ready_count}
- Questions file exists: !{questions_exist}
- Open questions: !{open_questions}

## Preflight Checks

**If plan_exists is "false":**
Stop and inform user: "No plan found. Please run `/dev/plan/create` first."

**If ready_count is "0":**
Check if there are open questions:
- If yes: "No ready tasks. Run `/dev/plan/question` to answer !{open_questions} open questions."
- If no: "No ready tasks and no open questions. Run `/dev/plan/complete` to finalize the plan."

## Algorithm to Execute

### 1. Build Queue of Ready Tasks

Use Grep to find all ready tasks:
```bash
grep "\*\*Status:\*\* ready" .claude/plan.md -n
```

Extract task IDs and issue numbers from results.
Create numbered list: "1. T-001 (Issue #101), 2. T-002 (Issue #102), etc."

If no tasks found, skip to completion message.

### 2. Process Each Task Sequentially

FOR task X of Y total tasks:

a. **STATE:** "Processing task X of Y: T-XXX"

b. Launch EXACTLY ONE sub-agent:
   ```
   Task tool:
   - description: "Analyze T-XXX"
   - subagent_type: "general-purpose"
   - prompt: [Load from template below, substituting T-XXX and issue number]
   ```

c. **STATE:** "Waiting for T-XXX to complete..."

d. WAIT for sub-agent to fully complete

e. **STATE:** "✓ T-XXX complete. Moving to next task."

f. THEN AND ONLY THEN proceed to next task

### Sub-Agent Prompt Template

Load the prompt from: `~/.claude/commands/dev/plan/prompts/analyze-subagent.md`

**CRITICAL:** If this file cannot be found, STOP immediately and inform the user:
"Cannot find required template at ~/.claude/commands/dev/plan/prompts/analyze-subagent.md"
NEVER improvise or substitute the prompt - the template contains critical instructions for correct behavior.

Replace:
- `[TASK_ID]` with the actual task ID (e.g., T-001)
- `[ISSUE_NUM]` with the issue number WITHOUT # (e.g., 101)

The sub-agent will:
1. Gather all task data and create session file
2. **Perform mandatory complexity analysis** (NEW: estimates LOC explicitly)
3. Record analysis in session file for transparency
4. Choose path based on analysis: Block, Decompose, or Simple
5. Update plan.md and GitHub issue accordingly
6. Create questions or subtasks as needed
7. Finalize session file with complete audit trail

### 3. Provide Summary

```
✅ Task analysis complete:
- [N] tasks analyzed by sub-agents (processed sequentially)
- Check .claude/questions.json for any new technical questions
- Run `/dev/plan/question` if questions were created
- Run `/dev/plan/complete` if all tasks are analyzed
```

## Critical Rules

### SEQUENTIAL PROCESSING IS MANDATORY
- Launch only ONE Task tool call at a time
- Wait for completion before launching next
- Never launch multiple Task tools in one message

**Why:** Each sub-agent calculates next available IDs. Parallel execution causes ID collisions.

### PROGRESS TRACKING REQUIRED
You MUST provide these explicit statements:
- Before: "Processing task X of Y: T-XXX"
- After launch: "Waiting for T-XXX to complete..."
- After complete: "✓ T-XXX complete. Moving to next task."

### COMPLEXITY ANALYSIS ENFORCED
Sub-agents MUST perform explicit LOC estimation before choosing a path. This prevents defaulting to "simple" without proper analysis.

### SESSION FILES PROVIDE AUDIT TRAIL
Each task creates `.claude/sessions/analyze-T-XXX-*.json` for:
- Complete complexity analysis with LOC estimates
- Path decision and reasoning
- Actions taken (status changes, subtasks, questions)
- Performance metrics (duration)
- **Debugging transparency**: Can see exactly why tasks weren't decomposed

## What Each Analysis Produces

Depending on the path chosen by the sub-agent:

### PATH A - BLOCKED (Technical Decision Needed)
- New question in `.claude/questions.json`
- Task status: ready → blocked
- GitHub issue labeled 'blocked'
- Q-XXX added to task dependencies

### PATH B - DECOMPOSED (>500 LOC)
- New subtasks in `.claude/plan.md`
- Parent task status: ready → analyzed
- GitHub issues created for subtasks
- Parent issue shows decomposition

### PATH C - SIMPLE (<500 LOC)
- Task status: ready → analyzed
- GitHub issue updated with implementation guidance
- Specific algorithms, files, and tests documented

## Task Decomposition Guidelines

### Purpose
**Keep PRs to manageable size for review.** The 500 LOC threshold represents maximum single PR size.

### Decomposition Criteria
- Tasks >500 LOC: Too large for single PR, SHOULD decompose
- Tasks 300-500 LOC: Acceptable for single PR
- Tasks <300 LOC: Ideal PR size

### Requirements
- Minimum 2 subtasks (no single-child decomposition)
- Each subtask 100-300 LOC (optimal)
- Clear boundaries, no overlap
- 100% coverage of original task

## Common Anti-Patterns to Avoid

❌ **BATCHING:** Never launch multiple sub-agents at once
❌ **GUESSING:** Never estimate without explicit component analysis
❌ **SKIPPING:** Never skip complexity analysis phase
❌ **SHORTCUTS:** Always wait for each sub-agent to complete

✓ **CORRECT:** Process each task completely with full analysis

## Decision Creation Guidelines

### Good Questions (Create Q-XXX)
Algorithm/Data Structure Decisions:
- "Should we use binary search, hash lookup, or linear scan for finding items?"
- "Should data be stored in array, linked list, or tree structure?"
- "Should we use DFS or BFS for graph traversal?"
- "Should cache use LRU, LFU, or TTL-based eviction?"

Pattern/Architecture Decisions:
- "Should events use observer pattern, pub-sub, or callbacks?"
- "Should state be managed with Redux, MobX, or Context API?"
- "Should the API use REST or GraphQL?"

Implementation Decisions:
- "Should sessions be stored in Redis or PostgreSQL?"
- "Which testing framework: Jest, Vitest, or Mocha?"
- "Canvas API or SVG for rendering?"

### Bad Questions (Don't Create)
- "How should we implement this?" (too vague, no specific options)
- "What's the best approach?" (no concrete choices)
- "Should we write tests?" (always yes, not a choice)

## Why This Design

This command implements core workflow principles:
- **Fresh sub-agents:** Each task gets clean context, preventing fatigue
- **Atomic operations:** One task fully analyzed per sub-agent
- **Explicit analysis:** Mandatory LOC estimation prevents gut decisions
- **Sequential processing:** Ensures ID consistency
- **PR scope focus:** Decomposition based on reviewable size, not architecture