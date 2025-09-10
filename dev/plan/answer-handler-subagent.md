# Answer Handler Sub-Agent Instructions

Process answered question [QUESTION_ID] from .claude/questions.json

## CONTEXT
- Question ID: [QUESTION_ID]
- User has already provided answer (logged in questions.json)
- Your job: Process all updates based on that answer

## PHASE 1: GATHER DATA

1. Read questions.json and extract [QUESTION_ID] entry:
   - Check status is "answered_pending_processing"
   - Extract user_choice (e.g., "Option 2: Tagged Unions")
   - Extract user_reasoning (if provided)
   - Extract affects list (task IDs affected by this decision)
   - Extract original question text and context
   - Extract the chosen option's details (pros/cons)

2. Calculate next ADR number:
   - Use Bash: ls .claude/ADRs/ADR-*.md 2>/dev/null | grep -oE "ADR-[0-9]{3}" | sort -V | tail -1
   - Extract number, increment by 1
   - Format as ADR-XXX (e.g., ADR-001, ADR-002)
   - If no ADRs exist, start with ADR-001

3. For each task ID in affects list:
   - Use Grep to find task in plan.md with pattern "T-XXX"
   - Extract current status
   - Extract GitHub issue number from [Issue #NNN]
   - Record task title for later reference

4. Create session tracking file:
   Create .claude/sessions/answer-[QUESTION_ID]-$(date +%Y%m%d_%H%M%S).json with:
   ```json
   {
     "question_id": "[QUESTION_ID]",
     "start_time": "$(date -Iseconds)",
     "user_choice": "[from questions.json]",
     "user_reasoning": "[from questions.json]",
     "affects_tasks": [list from step 3],
     "status": "in_progress"
   }
   ```

## PHASE 2: CREATE ARCHITECTURE DECISION RECORD

1. Determine ADR filename:
   - Format: ADR-XXX-[topic-slug].md
   - Topic slug: Convert question topic to lowercase with hyphens
   - Example: "REST vs GraphQL" → "rest-vs-graphql"

2. Create .claude/ADRs/ADR-XXX-[topic-slug].md with this content:

```markdown
# ADR-XXX: [Original question text from questions.json]

## Status
Accepted

## Context
[Context from questions.json explaining why this decision was needed]

## Decision
We will use [user_choice] because [user_reasoning if provided, otherwise default to the pros of the chosen option].

## Consequences

### Positive
[List positive consequences from the chosen option's pros]

### Trade-offs
[List trade-offs accepted from the chosen option's cons]

### Impact on Implementation
[Explain how this decision affects the implementation approach]

## Affected Tasks
[For each task in affects list:]
- T-XXX: [Task title] - [Specific guidance on how to implement this task given the decision]
```

## PHASE 3: UPDATE QUESTIONS.JSON

Use Edit tool to update the [QUESTION_ID] entry:
1. Change status: "answered_pending_processing" → "answered"
2. Add field: "adr": "ADR-XXX"
3. Keep user_choice and user_reasoning fields
4. Keep answered_at timestamp

## PHASE 4: UPDATE AFFECTED TASKS IN PLAN.MD

FOR EACH task ID in the affects list:

1. Use Grep to find the task section with pattern "T-XXX" and context lines
2. Look for Dependencies field containing [QUESTION_ID]
3. Use Edit tool to:
   - Remove [QUESTION_ID] from Dependencies field
   - If Dependencies becomes "none" or empty after removal, update to "none"
4. Check if any other Q-XXX remain in dependencies:
   - If NO other Q-XXX present AND status is "blocked":
     - Change Status: blocked → ready
   - If other Q-XXX still present:
     - Keep status as blocked
5. Add to task notes (if notes field exists) or create one:
   - "**Decision:** See ADR-XXX for [topic]"

## PHASE 5: UPDATE GITHUB ISSUES

FOR EACH task that was updated in Phase 4:

1. If task status changed from blocked to ready:
   ```bash
   gh issue edit [ISSUE_NUM] --remove-label 'blocked'
   ```

2. Add implementation guidance comment to issue:
   ```bash
   gh issue comment [ISSUE_NUM] --body "### Architectural Decision Made

   Question [QUESTION_ID] has been resolved: **[user_choice]**
   
   See ADR-XXX for full decision context and rationale.
   
   **Implementation guidance for this task:**
   [Extract specific guidance for this task based on the decision made]
   
   [Include relevant technical details from the chosen option that apply to this task]"
   ```

## PHASE 6: FINALIZE SESSION

Update .claude/sessions/answer-[QUESTION_ID]-*.json:
```json
{
  ...previous fields...,
  "adr_created": "ADR-XXX",
  "adr_file": "ADR-XXX-[topic-slug].md",
  "tasks_updated": [
    {
      "task_id": "T-XXX",
      "status_change": "blocked → ready" or "no change",
      "issue_updated": true
    }
  ],
  "issues_commented": [list of issue numbers],
  "end_time": "$(date -Iseconds)",
  "status": "completed"
}
```

## PHASE 7: FINAL VERIFICATION

Verify all updates completed:
1. STATE: "✓ Created ADR-XXX for [QUESTION_ID]"
2. STATE: "✓ Updated [N] tasks in plan.md"
3. STATE: "✓ Updated GitHub issues: #[list]"
4. STATE: "✓ Session recorded in .claude/sessions/"

## CRITICAL RULES

- Only process question [QUESTION_ID]
- Do not read or modify other questions
- Complete ALL updates atomically
- If user_choice doesn't match any option exactly, interpret best match
- Always create ADR even if reasoning is minimal
- Session file must track all changes for audit trail

## SUCCESS CRITERIA

✓ ADR created with user's decision and reasoning
✓ questions.json status updated to "answered"
✓ All affected tasks updated in plan.md
✓ Q-XXX removed from task dependencies
✓ Tasks unblocked where appropriate
✓ GitHub issues updated with guidance
✓ Complete session file for audit trail