---
allowed-tools: Read, Edit, Write, Bash(gh issue edit:*), Bash(gh issue comment:*), Bash(jq *), Grep, Task
description: Process open technical questions to create ADRs and unblock tasks
context-commands:
  - name: plan_exists
    command: '[ -f .claude/plan.md ] && echo "true" || echo "false"'
  - name: questions_exist
    command: '[ -f .claude/questions.json ] && echo "true" || echo "false"'
  - name: open_questions
    command: '[ -f .claude/questions.json ] && jq -r "to_entries | map(select(.value.status == \"open\")) | length" .claude/questions.json || echo "0"'
  - name: open_question_ids
    command: '[ -f .claude/questions.json ] && jq -r "to_entries | map(select(.value.status == \"open\")) | .[].key" .claude/questions.json || echo ""'
  - name: highest_adr
    command: '[ -d .claude/ADRs ] && ls .claude/ADRs/ADR-*.md 2>/dev/null | grep -oE "ADR-[0-9]{3}" | sort -V | tail -1 | grep -oE "[0-9]{3}" || echo "000"'
---

# Question Resolution Phase

## Purpose
Process technical questions from `.claude/questions.json` to create Architecture Decision Records (ADRs) and unblock tasks. Each question is handled by a fresh sub-agent to ensure consistent quality and proper documentation.

## Current State
- Plan exists: !{plan_exists}
- Questions file exists: !{questions_exist}
- Open questions: !{open_questions}
- Question IDs to process: !{open_question_ids}
- Highest ADR number: !{highest_adr}

## Preflight Checks

**If plan_exists is "false":**
Stop and inform user: "No plan found. Please run `/dev/plan/create` first."

**If open_questions is "0":**
Stop and inform user: "No open questions. Run `/dev/plan/analyze` to continue task analysis."

## Algorithm to Execute

### 1. Build Queue of Questions

Extract all open question IDs using jq:
```bash
jq -r 'to_entries | map(select(.value.status == "open")) | .[].key' .claude/questions.json
```

Count results and create numbered list (e.g., "1. Q-001, 2. Q-002").

If no questions found, skip to completion message.

### 2. Process Each Question Sequentially

FOR question X of Y total questions:

a. **STATE:** "Processing question X of Y: Q-XXX"

b. Launch EXACTLY ONE sub-agent:
   ```
   Task tool: 
   - description: "Answer Q-XXX"
   - subagent_type: "general-purpose"
   - prompt: [Load from template below, substituting Q-XXX]
   ```

c. **STATE:** "Waiting for Q-XXX to complete..."

d. WAIT for sub-agent to fully complete

e. **STATE:** "✓ Q-XXX complete. Moving to next question."

f. THEN AND ONLY THEN proceed to next question

### Sub-Agent Prompt Template

Load the prompt from: `~/.claude/commands/dev/plan/prompts/question-subagent.md`

**CRITICAL:** If this file cannot be found, STOP immediately and inform the user:
"Cannot find required template at ~/.claude/commands/dev/plan/prompts/question-subagent.md"
NEVER improvise or substitute the prompt - the template contains critical instructions for correct behavior.

Replace `[QUESTION_ID]` with the actual question ID (e.g., Q-001).

The sub-agent will:
1. Gather all data about the question
2. Present options to the user
3. Wait for user's decision
4. Create ADR with sequential numbering
5. Update questions.json, plan.md, and GitHub issues
6. Create session file for audit trail

### 3. Validate Results

After all sub-agents complete:

```bash
# Verify all questions answered
jq -r 'to_entries | map(select(.value.status == "open")) | length' .claude/questions.json

# Check ADRs created
ls -la .claude/ADRs/

# Verify session files
ls -la .claude/sessions/question-*
```

### 4. Provide Summary

```
✅ Question resolution complete:
- Processed [N] questions sequentially
- Created [N] Architecture Decision Records
- Updated [X] blocked tasks → ready
- Updated [Y] GitHub issues with guidance
- Session files: .claude/sessions/

Next step: Run `/dev/plan/analyze` to continue task analysis.
```

## Critical Rules

### SEQUENTIAL PROCESSING IS MANDATORY
- Launch only ONE Task tool call at a time
- Wait for completion before launching next
- Never launch multiple Task tools in one message

**Why:** Each sub-agent needs to see updated state from previous decisions. ADR numbering must be sequential. Tasks may be affected by multiple questions.

### PROGRESS TRACKING REQUIRED
You MUST provide these explicit statements:
- Before: "Processing question X of Y: Q-XXX"
- After launch: "Waiting for Q-XXX to complete..."
- After complete: "✓ Q-XXX complete. Moving to next question."

### SESSION FILES PROVIDE AUDIT TRAIL
Each question creates `.claude/sessions/question-Q-XXX-*.json` for:
- Decision history
- Task updates performed
- Issues modified
- Ability to resume if interrupted

## What Each Question Produces

For each open question, the sub-agent will create:

1. **Architecture Decision Record** (`.claude/ADRs/ADR-XXX-*.md`)
   - Documents the decision and reasoning
   - Explains consequences and trade-offs
   - Provides implementation guidance

2. **Updated questions.json**
   - Status: open → answered
   - Records chosen option and ADR reference
   - Timestamps the decision

3. **Updated plan.md**
   - Removes Q-XXX from task dependencies
   - Changes task status: blocked → ready (if no other blockers)
   - Adds ADR reference to task notes

4. **GitHub Issue Updates**
   - Removes 'blocked' label when appropriate
   - Adds comment with implementation guidance
   - References ADR for full context

5. **Session File** (`.claude/sessions/question-Q-XXX-*.json`)
   - Complete audit trail of the decision process
   - Lists all files and issues modified

## Common Anti-Patterns to Avoid

❌ **BATCHING:** Never launch multiple sub-agents at once
❌ **SKIPPING:** Never skip questions that "look complex"  
❌ **ASSUMING:** Never make decisions without user input
❌ **PARTIAL:** Always complete all updates for each question

✓ **CORRECT:** Process each question completely before moving to next

## Why This Design

This command implements core workflow principles:
- **Fresh sub-agents:** Each question gets clean context, preventing fatigue
- **Atomic operations:** One question fully resolved per sub-agent
- **Explicit state:** All decisions recorded in files
- **Sequential processing:** Ensures consistency and proper numbering
- **Audit trail:** Session files enable resumption and review