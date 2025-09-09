# Question Sub-Agent Instructions

Process ONLY question [QUESTION_ID] from .claude/questions.json

## CONTEXT
- Your question ID: [QUESTION_ID]
- Questions file: .claude/questions.json
- Plan file: .claude/plan.md

## PHASE 1: GATHER ALL DATA

1. Read questions.json and extract your question [QUESTION_ID]:
   - Question text
   - Context
   - Options with pros/cons
   - Affects list (task IDs)
   - Current status (should be 'open')

2. Calculate next ADR number:
   - Check .claude/ADRs/ directory for existing ADRs
   - Find highest ADR-XXX number
   - Your ADR will be next sequential (e.g., if highest is ADR-003, yours is ADR-004)

3. For EACH task ID in the 'affects' list:
   - Use Grep tool: pattern 'T-XXX.*\*\*Status:\*\*' on .claude/plan.md to find status
   - Use Grep tool: pattern 'T-XXX.*Issue #[0-9]*' on .claude/plan.md to find issue number
   - Record task title and current status

4. Create session tracking file:
   Create .claude/sessions/question-[QUESTION_ID]-$(date +%Y%m%d_%H%M%S).json with:
   ```json
   {
     "question_id": "[QUESTION_ID]",
     "start_time": "$(date -Iseconds)",
     "question_text": "[from questions.json]",
     "affects_tasks": [list from step 3],
     "status": "in_progress"
   }
   ```

## PHASE 2: PRESENT QUESTION TO USER

Present the question with this EXACT format:

## Question [QUESTION_ID]: [Question Text]

**Context:** [Why this decision matters - from questions.json]

**Options:**
1. **[Option 1 name]**
   - Pros: [list pros from questions.json]
   - Cons: [list cons from questions.json]

2. **[Option 2 name]**
   - Pros: [list pros from questions.json]
   - Cons: [list cons from questions.json]

[Additional options if present in questions.json]

**Affects tasks:**
- T-XXX: [task title] (Currently: [status])
- T-YYY: [task title] (Currently: [status])
[List all affected tasks]

Which option should we choose? (Enter 1, 2, etc. or explain preference)

## PHASE 3: WAIT FOR USER ANSWER

STOP HERE and wait for the user to respond with their choice.
Do NOT proceed until you receive an answer.
The user will provide a number (1, 2, etc.) or explain their choice.

## PHASE 4: PROCESS THE ANSWER

Once user provides answer:

### 1. Create Architecture Decision Record

a. Determine ADR number from Phase 1 calculation
b. Create filename: ADR-XXX-[topic-slugified].md
   (e.g., Q-001 about 'REST vs GraphQL' → ADR-001-rest-vs-graphql.md)
c. Write to .claude/ADRs/ADR-XXX-[topic].md:

```markdown
# ADR-XXX: [Question text from questions.json]

## Status
Accepted

## Context
[Context from questions.json explaining why this decision was needed]

## Decision
We will use [chosen option name] because [user's reasoning if provided, otherwise default to pros from the option].

## Consequences
- [List positive consequences from chosen option's pros]
- [List trade-offs accepted from chosen option's cons]
- [Explain impact on each affected task]

## Affected Tasks
- T-XXX: [How this decision guides implementation of this task]
- T-YYY: [How this decision guides implementation of this task]
[One line per affected task with specific guidance]
```

### 2. Update questions.json

Use Edit tool to modify your question [QUESTION_ID]:
- Change 'status': 'open' → 'answered'
- Add 'answer': '[chosen option name]'
- Add 'adr': 'ADR-XXX'
- Add 'answered_at': '$(date -Iseconds)'

### 3. Update all affected tasks in plan.md

FOR EACH task in the affects list that has [QUESTION_ID] in dependencies:
  a. Use Grep tool to find the task with pattern 'T-XXX' and -B2 -A10 flags
  b. Remove [QUESTION_ID] from Dependencies field
  c. Check if any other Q-XXX remain in dependencies
  d. If no Q-XXX dependencies remain:
     - Change Status: blocked → ready
  e. Add to task notes: 'Decision: See ADR-XXX'

### 4. Update GitHub issues for affected tasks

FOR EACH task that was updated:
  a. Get issue number from plan.md
  b. If status changed from blocked to ready:
     ```bash
     gh issue edit [ISSUE_NUM] --remove-label 'blocked'
     ```
  c. Add implementation guidance comment:
     ```bash
     gh issue comment [ISSUE_NUM] --body "### Architectural Decision
     
     Question [QUESTION_ID] has been resolved: **[chosen option]**
     
     See ADR-XXX for full context.
     
     **Implementation approach for this task:**
     [Specific guidance based on the chosen option and how it affects this particular task]
     
     [Extract relevant technical details from the decision that apply to this task]"
     ```

### 5. Update session file

Update .claude/sessions/question-[QUESTION_ID]-*.json:
```json
{
  ...previous fields...,
  "answer": "[chosen option]",
  "adr_created": "ADR-XXX",
  "tasks_updated": [list of T-XXX that were modified],
  "issues_updated": [list of issue numbers],
  "end_time": "$(date -Iseconds)",
  "status": "completed"
}
```

### 6. Final verification

STATE: "Created ADR-XXX for [QUESTION_ID]"
STATE: "Updated [N] tasks in plan.md"  
STATE: "Updated GitHub issues: #[list of issue numbers]"
STATE: "Session recorded in .claude/sessions/"

## CRITICAL RULES

- Only process question [QUESTION_ID]
- Do not read or process other questions
- Do not look at remaining work
- Complete ALL steps before exiting
- Wait for user input before proceeding to Phase 4
- If you process any other question ID, you have failed

## Success Criteria

✓ User has made an explicit choice
✓ ADR created with sequential number
✓ questions.json updated with answer
✓ All affected tasks updated in plan.md
✓ GitHub issues updated with guidance
✓ Session file created and completed