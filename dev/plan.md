---
allowed-tools: Read, Bash(ls:*)
description: Router for plan workflow - directs to appropriate phase command
context-commands:
  - name: spec_exists
    command: '[ -f .claude/spec.md ] && echo "true" || [ -f spec.md ] && echo "true" || echo "false"'
  - name: plan_exists
    command: '[ -f .claude/plan.md ] && echo "true" || echo "false"'
  - name: plan_version
    command: '[ -f .claude/plan.md ] && grep -oE "^# Plan \\(v[0-9.]+\\)" .claude/plan.md | grep -oE "v[0-9.]+" || echo "none"'
  - name: ready_count
    command: '[ -f .claude/plan.md ] && grep -c "\*\*Status:\*\* ready" .claude/plan.md || echo "0"'
  - name: blocked_count
    command: '[ -f .claude/plan.md ] && grep -c "\*\*Status:\*\* blocked" .claude/plan.md || echo "0"'
  - name: analyzed_count
    command: '[ -f .claude/plan.md ] && grep -c "\*\*Status:\*\* analyzed" .claude/plan.md || echo "0"'
  - name: open_questions
    command: '[ -f .claude/questions.json ] && jq -r "to_entries | map(select(.value.status == \"open\")) | length" .claude/questions.json 2>/dev/null || echo "0"'
---

# Plan Workflow Router

## Current State
- Spec exists: !{spec_exists}
- Plan exists: !{plan_exists}
- Plan version: !{plan_version}
- Ready tasks: !{ready_count}
- Blocked tasks: !{blocked_count}
- Analyzed tasks: !{analyzed_count}
- Open questions: !{open_questions}

## What To Do Next

Based on your current state, here's the next command to run:

### If spec doesn't exist (!{spec_exists} = false):
```
❌ No specification found.
👉 Run: /dev/spec
```

### If plan doesn't exist (!{plan_exists} = false):
```
📋 Ready to create initial plan from spec.
👉 Run: /dev/plan/create
```

### If plan exists and version is not 1.0:

#### If there are ready tasks (!{ready_count} > 0):
```
🔍 Need to analyze !{ready_count} ready tasks.
👉 Run: /dev/plan/analyze
```

#### If there are open questions (!{open_questions} > 0):
```
❓ Need to answer !{open_questions} technical questions.
👉 Run: /dev/plan/question
```

#### If all tasks analyzed and no questions (!{ready_count} = 0, !{open_questions} = 0):
```
✅ Ready to finalize the plan.
👉 Run: /dev/plan/complete
```

### If plan version is 1.0:
```
🎉 Plan is complete and frozen!
👉 Run: /dev/implement [ISSUE_NUMBER]
```

## Plan Workflow Overview

The planning process follows these phases:

### 1. `/dev/plan/create` - Create Initial Plan
- Parses specification
- Builds Work Breakdown Structure (WBS)
- Creates tasks with T-XXX IDs
- Generates GitHub issues
- **Output:** `.claude/plan.md` v0.1

### 2. `/dev/plan/analyze` - Analyze Tasks
- Reviews each "ready" task
- Creates questions for technical decisions (Q-XXX)
- Decomposes large tasks (>500 LOC)
- Marks simple tasks as analyzed
- **Output:** Questions in `.claude/questions.json`, updated task statuses

### 3. `/dev/plan/question` - Answer Questions
- Presents each open question with options
- Creates Architecture Decision Records (ADRs)
- Updates blocked tasks when decisions made
- **Output:** ADRs in `.claude/ADRs/`, tasks unblocked

### 4. `/dev/plan/complete` - Finalize Plan
- Verifies all tasks analyzed
- Updates version to v1.0 (frozen)
- Generates completion summary
- **Output:** Frozen plan ready for implementation

## Workflow Cycles

The workflow cycles between phases:
```
create → analyze → question → analyze → question → ... → complete
```

You'll alternate between analyzing tasks and answering questions until all tasks are analyzed and no questions remain.

## Files Created

- `.claude/plan.md` - Task breakdown structure
- `.claude/questions.json` - Technical decisions needed
- `.claude/ADRs/*.md` - Architecture Decision Records
- GitHub Issues - One per task, linked as sub-issues

## Quick Status Check

Current recommendation based on your state:
**👉 Next command: [Determined from context above]**