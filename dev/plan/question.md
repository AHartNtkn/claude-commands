---
allowed-tools: Read, Edit, Write, Bash(gh issue edit:*), Bash(jq *)
description: Present and answer all open technical questions
context-commands:
  - name: plan_exists
    command: '[ -f .claude/plan.md ] && echo "true" || echo "false"'
  - name: questions_exist
    command: '[ -f .claude/questions.json ] && echo "true" || echo "false"'
  - name: open_questions
    command: '[ -f .claude/questions.json ] && jq -r "to_entries | map(select(.value.status == \"open\")) | length" .claude/questions.json || echo "0"'
  - name: open_question_ids
    command: '[ -f .claude/questions.json ] && jq -r "to_entries | map(select(.value.status == \"open\")) | .[].key" .claude/questions.json || echo ""'
---

# Question Resolution Phase

## Preflight Checks

- Plan exists: !{plan_exists}
- Questions file exists: !{questions_exist}
- Open questions count: !{open_questions}
- Open question IDs: !{open_question_ids}

**If plan_exists is "false":**
Stop and inform user: "No plan found. Please run `/dev/plan/create` first."

**If open_questions is "0":**
Stop and inform user: "No open questions. Run `/dev/plan/analyze` to continue task analysis."

## CRITICAL REQUIREMENTS

**MANDATORY SEQUENTIAL PROCESSING:**
- Process questions in the order they appear in questions.json
- Complete ALL steps for each question before moving to the next
- DO NOT skip questions or cherry-pick "interesting" ones
- Each question requires full processing including ADR creation and task updates

**VERIFICATION REQUIRED:**
- Before processing any question, explicitly state: "Now processing Q-XXX"
- After creating ADR, state: "Created ADR-XXX"
- After updating tasks, state: "Updated [N] tasks in plan.md"
- After updating GitHub issues, state: "Updated GitHub issues for affected tasks"

**ZERO TOLERANCE FOR SHORTCUTS:**
- Skipping questions destroys planning integrity
- Every decision must be documented in an ADR
- All affected tasks must be updated
- All GitHub issues must be updated with implementation implications

## Algorithm to Execute

### Process ALL Open Questions ONE AT A TIME

```
FOR EACH open question in .claude/questions.json:

  1. Read question details from questions.json
     - STATE EXPLICITLY: "Now processing Q-XXX"
  
  2. Present question to user:
     ## Question [Q-XXX]: [Question Text]
     
     **Context:** [Why this decision matters]
     
     **Options:**
     1. **[Option 1]**
        - Pros: [advantages]
        - Cons: [disadvantages]
     
     2. **[Option 2]**
        - Pros: [advantages]
        - Cons: [disadvantages]
     
     [Additional options if any]
     
     **Affects tasks:** [List of T-XXX that depend on this]
     
     Which option should we choose? (Enter 1, 2, etc. or explain preference)
  
  3. Wait for user answer
  
  4. Process the answer:
     
     a. Create Architecture Decision Record (ADR):
        Create .claude/ADRs/ADR-XXX-[topic].md with:
        ```markdown
        # ADR-XXX: [Question that was answered]
        
        ## Status
        Accepted
        
        ## Context
        [Why this decision was needed - from question context]
        
        ## Decision
        We will use [chosen option] because [user's reasoning if provided].
        
        ## Consequences
        - [Impact on affected tasks]
        - [Technical implications]
        - [Trade-offs accepted]
        
        ## Affected Tasks
        - T-XXX: [How this affects the task]
        - T-YYY: [How this affects the task]
        ```
     
     b. Update questions.json:
        - Change status: "open" → "answered"
        - Add "answer": "[chosen option]"
        - Add "adr": "ADR-XXX"
        - Add "answered_at": "[timestamp]"
     
     c. Update all affected tasks in plan.md:
        FOR EACH task with this Q-XXX in Dependencies:
          - Remove Q-XXX from Dependencies field
          - If no Q-XXX dependencies remain:
            → Change Status: blocked → ready
          - Add reference to ADR in task notes
     
     d. Update GitHub issues for affected tasks:
        - Remove "blocked" label if no longer blocked
        - Add comment with decision's implementation implications:
          ```bash
          gh issue comment [ISSUE_NUMBER] --body "Decision: [chosen option]. 
          Implementation approach for this task: [specific guidance based on decision]"
          ```
  
  5. Save all changes and verify completion:
     - STATE: "Created ADR-XXX"
     - STATE: "Updated [N] tasks in plan.md"
     - STATE: "Updated GitHub issues for affected tasks"
  
  6. ONLY THEN continue to next question

END FOR
```

## Question Presentation Format

Keep questions focused and actionable:
- One decision point per question
- Concrete options (not open-ended)
- Clear trade-offs
- Visible impact scope

## Answer Processing

### Valid Answer Formats:
- Number (1, 2, 3, etc.) - selects that option
- Option name - selects that option
- Explanation with choice - captures reasoning

### Creating ADRs:
- Use sequential numbering (ADR-001, ADR-002, etc.)
- Filename format: `ADR-XXX-topic-name.md`
- Always reference the original question
- Document the "why" behind the decision

### Updating Tasks:
```
WHILE (grep finds "Dependencies:.*Q-XXX" in plan.md):
  1. Find first occurrence using Grep tool
  2. Remove Q-XXX from that task's Dependencies field
  3. If no Q-XXX dependencies remain, update Status: blocked → ready
  4. Update GitHub issue with implementation implications
  5. Save changes and repeat search
```

## ANTI-PATTERNS - DO NOT DO THIS

**❌ SKIPPING QUESTIONS (FORBIDDEN):**
```markdown
# WRONG - Never do this:
Q-001 looks complex, let me check Q-003 first...
```

**❌ INCOMPLETE PROCESSING (FORBIDDEN):**
```markdown
# WRONG - Never do this:
Updated questions.json, moving to next question...
[No ADR created, no tasks updated, no GitHub issues updated]
```

**❌ DUPLICATING QUESTIONS IN ISSUES (FORBIDDEN):**
```markdown
# WRONG - Never do this:
gh issue comment 123 --body "Q-001: Should we use REST or GraphQL?..."
```

**❌ BATCH PROCESSING (FORBIDDEN):**
```markdown
# WRONG - Never do this:
Answering Q-001, Q-002, and Q-003 all at once...
```

**CORRECT APPROACH:**
```markdown
Now processing Q-001
[Present question to user]
[Wait for answer]
Created ADR-001
Updated 3 tasks in plan.md
Updated GitHub issues for affected tasks

Now processing Q-002
[Present question to user]
[Wait for answer]
Created ADR-002
Updated 2 tasks in plan.md
Updated GitHub issues for affected tasks
```

## Completion

After answering all questions:

```
✅ Question resolution complete:
- Answered [N] technical questions
- Created [N] Architecture Decision Records
- Updated [X] blocked tasks → ready
- Updated [Y] GitHub issues

Architecture decisions documented in .claude/ADRs/

Next step: Run `/dev/plan/analyze` to continue task analysis.
```

## Important Notes

**ENFORCEMENT:**
- Present questions ONE AT A TIME - NO EXCEPTIONS
- Wait for user response before continuing
- Create ADR immediately after each answer
- Update ALL affected tasks before moving to next question
- Update ALL GitHub issues with implementation implications
- If you skip any step, the planning has FAILED

**Remember:** Each decision affects real implementation work. Proper documentation and communication through ADRs and GitHub issues is critical for successful execution.