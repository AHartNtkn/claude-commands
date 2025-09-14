---
allowed-tools: Read, Task, Grep, Bash(jq:*), Bash([:*), Bash(echo:*), Bash(grep:*)
description: Integrated planning loop - interleaves questions and analysis
---

# Integrated Planning Loop

## Current State
- Spec exists: !`[ -f .claude/spec.md ] && echo "true" || [ -f spec.md ] && echo "true" || echo "false"`
- Plan exists: !`[ -f .claude/plan.md ] && echo "true" || echo "false"`
- Plan frozen: !`[ -f .claude/plan.md ] && grep -q "^# Plan (v1.0)" .claude/plan.md && echo "true" || echo "false"`
- Open questions: !`[ -f .claude/questions.json ] && jq "if type == \"object\" then [.[] | select(type == \"object\" and .status == \"open\")] | length else 0 end" .claude/questions.json 2>/dev/null || echo "0"`

## Preflight Checks

**If spec_exists is "false":**
Stop: "No specification found. Run `/dev/spec` first."

**If plan_exists is "false":**
Stop: "No plan found. Run `/dev/plan/create` first."

**If plan_frozen is "true":**
Stop: "Plan is frozen at v1.0. Run `/dev/implement [ISSUE_NUMBER]` to start implementation."

## CRITICAL: Anti-Improvisation Rules

1. **NEVER substitute your own analysis for templates** - When instructed to load a template, you MUST Read it first
2. **NEVER optimize the workflow** - Process ONE item then restart from Phase 1
3. **NEVER skip phases** - Always check questions before tasks, even if you just processed a task
4. **Templates are MANDATORY** - They contain GitHub updates, file modifications, and tracking that your improvisation will miss

Improvising breaks the entire system. Follow the exact process.

## Main Loop Algorithm

The loop processes ONE item at a time then RESTARTS:
- Process ONE question OR ONE task
- Then immediately restart from Phase 1
- Questions always get priority over tasks
- Never batch or continue processing similar items

WHILE work remains:

### Phase 1: Check for Open Questions

Use jq to check if any open questions exist in .claude/questions.json.
If found:
  1. Load first open question from .claude/questions.json using jq
  2. Extract question details (text, context, options, affects)
  3. Present question to user with clear format
  4. Wait for user response (natural command pause)
  5. Log answer in questions.json:
     - status: "open" → "answered_pending_processing"
     - user_choice: "Option X: [chosen option]"
     - user_reasoning: "[any explanation provided]"
     - answered_at: "$(date -Iseconds)"
  6. YOU MUST FIRST:
     - Read file: ~/.claude/commands/dev/plan/answer-handler-subagent.md
     - If file not found, STOP and inform user
     - Replace [QUESTION_ID] with actual Q-XXX value in the file contents
     THEN launch sub-agent:
     ```
     Task tool:
     - description: "Process answer for Q-XXX"
     - subagent_type: "general-purpose"
     - prompt: [The entire contents of the template file with replacements made]
     ```
  7. Wait for sub-agent completion
  8. Continue to next question (loop back to Phase 1)

### Phase 2: Check for Ready Tasks

Use Grep tool with pattern "\*\*Status:\*\* ready" on .claude/plan.md:
- output_mode: "content"
- -B: 3 (to see task ID above the status line)
- -A: 1 (for context)
- head_limit: 5 (to get just the first ready task)
If any matches found:
  1. Find first ready task using Grep tool
  2. Extract task ID and issue number
  3. STATE: "Analyzing task T-XXX..."
  4. YOU MUST FIRST:
     - Read file: ~/.claude/commands/dev/plan/analyze-subagent.md (336 lines)
     - If file not found, STOP and inform user
     - Replace [TASK_ID] with actual T-XXX value in the file contents
     - Replace [ISSUE_NUM] with actual issue number in the file contents
     THEN launch sub-agent:
     ```
     Task tool:
     - description: "Analyze T-XXX"
     - subagent_type: "general-purpose"
     - prompt: [The entire contents of the template file with replacements made]
     ```
  5. Wait for sub-agent completion
  6. GO BACK TO PHASE 1 (Check for Open Questions)

### Phase 3: Complete Planning

If no open questions AND no ready tasks found:
  - STATE: "✅ All tasks analyzed and questions answered!"
  - Exit loop

## Question Presentation Format

When presenting a question to the user:

```
## Question Q-XXX: [Question text]

**Context:** [Why this decision matters]

**Options:**
1. **[Option 1 name]**
   - Pros: [list pros]
   - Cons: [list cons]

2. **[Option 2 name]**
   - Pros: [list pros]
   - Cons: [list cons]

[Additional options if present]

**Affects tasks:**
- T-XXX: [task title]
- T-YYY: [task title]

Which option should we choose? (Enter 1, 2, etc. or explain your preference)
```

## Progress Tracking

Provide clear status updates:
- Before question: "📝 Found open question Q-XXX"
- After answer: "Processing your decision..."
- Before analysis: "🔍 Analyzing task T-XXX..."
- After each iteration: "✓ Complete. Checking for more work..."

## Session Tracking

Each iteration creates session files:
- Questions: `.claude/sessions/answer-Q-XXX-*.json`
- Analysis: `.claude/sessions/analyze-T-XXX-*.json`

These provide a complete audit trail of the planning process.

