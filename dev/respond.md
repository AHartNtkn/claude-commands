---
allowed-tools: Edit, Bash(git:*), Bash(gh pr:*), Bash(gh issue:*), Bash(gh sub-issue:*), Bash(test*), Bash(npm *), Bash(pnpm *), Bash(yarn *), Bash(python *), Bash(pytest*), Bash(go test*), Bash(cargo test*), Bash(jq *), Read, Grep, Task
argument-hint: [PR_NUMBER]
description: Systematically respond to PR review feedback with proper issue tracking and documentation
context-commands:
  - name: pr_number
    command: 'echo "${ARGUMENTS:-$(git branch --show-current | sed \"s/.*///\")}"'
  - name: pr_context
    command: 'PR="${ARGUMENTS:-$(git branch --show-current | sed \"s/.*///\")}"; gh pr view "$PR" --json number,title,body,state,reviews,comments'
  - name: latest_review
    command: 'PR="${ARGUMENTS:-$(git branch --show-current | sed \"s/.*///\")}"; gh pr view "$PR" --comments --json comments | jq -r ".comments[-1].body // empty"'
  - name: review_threads
    command: 'PR="${ARGUMENTS:-$(git branch --show-current | sed \"s/.*///\")}"; gh api "repos/:owner/:repo/pulls/$PR/comments" --paginate 2>/dev/null || echo "[]"'
  - name: pr_diff_files
    command: 'PR="${ARGUMENTS:-$(git branch --show-current | sed \"s/.*///\")}"; gh pr diff "$PR" --name-only | grep -v "\.claude/sessions/"'
  - name: pr_diff_full
    command: 'PR="${ARGUMENTS:-$(git branch --show-current | sed \"s/.*///\")}"; gh pr diff "$PR" | awk "/^diff --git.*\\.claude\\/sessions\\// { skip=1; next } /^diff --git/ { skip=0 } skip==0"'
  - name: plan_exists
    command: '[ -f .claude/plan.md ] && echo "true" || echo "false"'
  - name: spec_requirements
    command: '[ -f .claude/spec.md ] && grep -E "FR-|NFR-" .claude/spec.md || echo ""'
  - name: review_criteria
    command: '[ -f .claude/spec-state.json ] && jq ".review_criteria" .claude/spec-state.json || echo "{}"'
---

## Initial Context
- PR Number: !{pr_number}
- PR Details: !{pr_context}
- Latest Review Comment: !{latest_review}
- Review Threads: !{review_threads}
- Files Changed in PR: !{pr_diff_files}
- Plan exists: !{plan_exists}
- Spec requirements: !{spec_requirements}
- Review criteria: !{review_criteria}

## Full PR Diff
!{pr_diff_full}

## CRITICAL INSTRUCTION: INVESTIGATE BEFORE CLASSIFYING

This command has ONE rule: **INVESTIGATE FIRST, THEN FIX or PROVE WRONG WITH EVIDENCE**.

You are NOT allowed to:
- Classify feedback without reading the actual code
- Dispute claims without showing contradicting code
- Defer items without proving they weren't touched in this PR
- Make assumptions based on general programming knowledge

Every piece of feedback requires investigation. Default to FIX unless evidence proves otherwise.

## Review Analysis

### 1) Initialize Verification Session

1. Capture timestamp and create session filename:
   ```bash
   TIMESTAMP=$(date +%Y%m%d_%H%M%S)
   SESSION_FILE=".claude/sessions/respond-PR-$ARGUMENTS-${TIMESTAMP}.json"
   echo "Creating session: $SESSION_FILE"
   ```

2. Create session file using Write tool with the path from $SESSION_FILE variable:
   ```json
   {
     "pr_number": "$ARGUMENTS",
     "created_at": "[current ISO timestamp]",
     "updated_at": "[current ISO timestamp]",
  "status": "project_understanding",
  
  "project_context": {
    "core_purpose": null,
    "domain": null,
    "technology_stack": null,
    "specialized_requirements": [],
    "spec_refs_reviewed": [],
    "adrs_reviewed": []
  },
  
  "feedback_items": [],
  
  "verification_complete": false,
  "implementation_allowed": false
}
```

Note: The SESSION_FILE variable contains the path to the current session file.

### 2) Understand Project Context

Before analyzing any feedback, populate the project_context in the session file:

1. **Read specification** (`.claude/spec.md` or `spec.md`):
   - Extract core purpose and domain
   - Note specialized requirements (performance, precision, domain-specific needs)
   - Document technology choices

2. **Review Architecture Decision Records**:
   ```bash
   for adr in .claude/ADRs/ADR-*.md; do
     if [ -f "$adr" ]; then
       # Read and extract relevant architectural decisions
     fi
   done
   ```

3. **Update session** with project understanding:
   ```json
   "project_context": {
     "core_purpose": "[What this project does]",
     "domain": "[Problem domain]",
     "technology_stack": "[Languages, frameworks, libraries]",
     "specialized_requirements": ["List any special requirements"],
     "spec_refs_reviewed": ["spec sections reviewed"],
     "adrs_reviewed": ["ADR-001", "ADR-002"]
   },
   "status": "feedback_analysis"
   ```

### 3) Sequential Feedback Investigation

**Process feedback items ONE AT A TIME. Complete each investigation before moving to the next.**

#### Step 3.1: Build Feedback List

Parse review comments and list ALL feedback items in session:
```json
"feedback_items": [
  {"id": "F001", "reviewer_comment": "[exact quote]", "status": "pending"},
  {"id": "F002", "reviewer_comment": "[exact quote]", "status": "pending"},
  {"id": "F003", "reviewer_comment": "[exact quote]", "status": "pending"}
]
```

#### Step 3.2: Investigation Loop

FOR each feedback item with status: "pending":

1. STATE: "Investigating F001: [first 50 chars of comment]..."

2. Complete ALL investigation steps:
   - Locate the code
   - Check if file was modified in PR
   - Read the implementation
   - Validate the claim
   - Classify based on evidence

3. Update session with investigation results

4. STATE: "F001 investigated. Moving to next item."

5. Continue to next pending item

When no pending items remain: STATE: "All feedback investigated."

#### Step 3.3: Investigation Requirements (per item)

For the CURRENT item only (not all items at once):

**A. LOCATE THE CODE**
```bash
# Find the specific code location mentioned
# Record exact file:line or "could not locate"
```
Update session: `"location_found": "src/foo.ts:45-60"`

**B. CHECK PR SCOPE**
```bash
# Check if this file appears in pr_diff_files
echo "Checking if [filename] was modified in PR..."
grep [filename] # (from pr_diff_files context)
```
Update session: `"pr_touched": true/false, "diff_evidence": "A src/foo.ts"`

**C. READ IMPLEMENTATION**
```bash
# Use Read tool on the specific file and lines
Read [file] [start_line] [end_line]
```
Update session: `"code_examined": "implements X pattern at lines Y-Z"`

**D. VALIDATE CLAIM**
Compare what reviewer said vs what code actually does.
Update session: `"claim_validation": "reviewer correct: [specific issue found]"`

**E. CLASSIFY WITH EVIDENCE**

**DEFAULT = FIX** (unless evidence shows otherwise)

Classification rules:
- If claim validated AND file in PR → `action: "fix"`
- If claim false (show contradicting code) → `action: "dispute"`
- If file NOT in PR (show diff proof) → `action: "defer"`

Update session with complete investigation record:
```json
{
  "id": "F001",
  "reviewer_comment": "[original]",
  "status": "investigated",
  "investigation": {
    "location_found": "src/foo.ts:45",
    "pr_touched": true,
    "diff_evidence": "M src/foo.ts",
    "code_examined": "null check missing",
    "claim_validation": "reviewer correct"
  },
  "action": "fix",
  "evidence": "Investigation confirms missing null check at line 45"
}
```

#### Step 3.4: Required Progress Statements

You MUST output these statements to prove sequential processing:
- Before each item: `"Processing feedback item X of Y..."`
- After investigation: `"Item X complete. Investigation recorded."`
- After all items: `"All Y items investigated."`

**VIOLATION**: If these statements are missing or out of order, you have violated the algorithm.

#### Step 3.5: Completion Verification

Only after ALL items show status: "investigated":
```json
"verification_complete": true,
"implementation_allowed": true,
"processing_complete": true
```

### 4) Generate Review Analysis

Create `.review_analysis.md` based on session data:

```markdown
# Review Analysis for PR #[NUMBER]

## Feedback to Fix
[All items with action: "fix" - these will be implemented]

## Disputed Feedback
[Items with action: "dispute" - include concrete evidence]

## Out of Scope - Deferred to Existing Issues
[Items with action: "defer-to-existing" - note which issue/task]

## Out of Scope - New Issues Needed
[Items with action: "create-issue" - truly new concerns not covered elsewhere]
```

## Implementation

### 5) Verification Gate Check

Before implementing any fixes, verify the session is complete:

```bash
# Verify session file exists (use the SESSION_FILE variable from earlier)
if [ ! -f "$SESSION_FILE" ]; then
  echo "ERROR: Session file $SESSION_FILE not found. Must complete verification first."
  exit 1
fi

VERIFIED=$(jq -r '.verification_complete' "$SESSION_FILE")
ALLOWED=$(jq -r '.implementation_allowed' "$SESSION_FILE")

if [ "$VERIFIED" != "true" ] || [ "$ALLOWED" != "true" ]; then
  echo "ERROR: Verification incomplete. Review session file: $SESSION_FILE"
  echo "Verification complete: $VERIFIED"
  echo "Implementation allowed: $ALLOWED"
  exit 1
fi

echo "✓ Verification complete. Proceeding with implementation."
```

### 6) Fix All Feedback Items

For each feedback item marked with action: "fix" in the session file:

```bash
# Get items to implement from session
ITEMS_TO_FIX=$(jq -r '.feedback_items[] | select(.action == "fix") | "\(.id): \(.reviewer_comment)"' "$SESSION_FILE")

# Update session as you implement each item
jq '.feedback_items[] | select(.id == "F001") | .implementation_status = "in_progress"' "$SESSION_FILE" > tmp.json && mv tmp.json "$SESSION_FILE"
```

For each issue to implement:

1. Create a test that demonstrates the issue (if applicable):
   ```bash
   # Run existing tests first
   npm test  # or appropriate test command
   ```

2. Fix the issue with minimal, focused changes

3. Verify the fix:
   - Run tests again
   - Check for regressions
   - Ensure fix aligns with standards

4. Commit with descriptive message:
   ```bash
   git add [files]
   git commit -m "fix(review): address [specific issue]

   Addresses review feedback from PR #$PR_NUM
   - [Specific change made]
   - [Why this fixes the issue]"
   ```

### 7) Handle Out-of-Scope Items

For each feedback item with action: "create-issue" in the session:

1. **First check if an existing task/issue covers this**:
   ```bash
   # Search plan.md for related tasks
   grep -i "[relevant keywords]" .claude/plan.md

   # Search existing GitHub issues
   gh issue list --search "[relevant keywords]"
   ```

2. **If an existing task/issue covers it**:
   - Add a comment to the PR: "This will be addressed in issue #XXX [title]"
   - Update the existing issue with a note about this feedback if needed
   - DO NOT create a duplicate issue

3. **Only if truly not covered anywhere**:

1. **Update the specified task in plan.md**:
   ```bash
   # Get the task ID from session
   DEFER_TASK=$(jq -r '.feedback_items[] | select(.id == "F001") | .defer_to_task' "$SESSION_FILE")
   
   # Add requirement to task's acceptance criteria in plan.md
   # Using Edit tool, add to the task's acceptance criteria:
   # "- [From PR #XXX review]: [specific requirement from feedback]"
   ```

2. If creating a new task (when no existing task fits), create GitHub issue:
   ```bash
   ISSUE_TITLE="[Follow-up from PR #$PR_NUM] [Description]"
   ISSUE_BODY="## Context
   This issue was identified during review of PR #$PR_NUM but deferred because:
   [Justification]
   
   ## Original Feedback
   > [Quote reviewer comment]
   
   ## Acceptance Criteria
   - [ ] [Specific requirement 1]
   - [ ] [Specific requirement 2]
   
   ## Technical Details
   - File: [path:line]
   - Current behavior: [description]
   - Desired behavior: [description]
   
   ## Dependencies
   - Blocked by: [if any]
   - Blocks: [if any]"
   
   ISSUE_NUM=$(gh issue create --title "$ISSUE_TITLE" --body "$ISSUE_BODY" --label "follow-up,technical-debt" | grep -oE '[0-9]+$')
   echo "Created issue #$ISSUE_NUM"
   ```

2. If there's a parent issue for this PR, link as sub-issue:
   ```bash
   PARENT_ISSUE=$(gh pr view "$PR_NUM" --json body | jq -r '.body' | grep -oE 'Closes #[0-9]+' | grep -oE '[0-9]+')
   if [ -n "$PARENT_ISSUE" ]; then
     gh sub-issue add "$PARENT_ISSUE" "$ISSUE_NUM"
     echo "Linked as sub-issue of #$PARENT_ISSUE"
   fi
   ```

3. Update `.claude/plan.md` if it exists:
   - Add new task with issue number
   - Update dependencies if needed
   - Increment version

### 5) Add Clarifying Comments

For disputed/invalid feedback where there's confusion:

1. Identify the code location that caused confusion
2. Add a clarifying comment that explains:
   - Why the current approach is correct
   - What architectural decision or standard it follows
   - Why alternative approaches were not used

Example:
```python
# This uses synchronous processing intentionally - see ADR-003
# Async would violate our transaction boundaries requirement
def process_payment(order):
    # Implementation...
```

3. Commit clarifications:
   ```bash
   git commit -am "docs: add clarifying comments for review feedback"
   ```

## Documentation

### 6) Create Response Document

Create `.review_response.md`:
```markdown
# Response to PR Review

## Summary
Addressed X of Y review comments directly, created Z follow-up issues.

## Changes Made in This PR

### Critical Issues Fixed
✅ **Issue 1**: [What was fixed]
- Commit: [sha]
- Change: [Brief description]

### High Priority Issues Fixed
✅ **Issue 2**: [What was fixed]
- Commit: [sha]
- Change: [Brief description]

## Deferred to Follow-up Issues

### Created Issues
📝 **Issue #NNN**: [Title]
- Priority: Medium
- Justification for deferral: [Reason - e.g., requires broader refactoring, separate concern, etc.]

## Disputed/Clarified Points

### Point 1: [Reviewer concern]
**Response**: [Explanation with reference to standards/ADRs]
**Action taken**: Added clarifying comment at [file:line]

## Testing
- [ ] All existing tests pass
- [ ] New tests added for fixes
- [ ] No regressions detected
- [ ] Test coverage maintained/improved

## Next Steps
1. Request re-review on addressed items
2. Track follow-up issues in project board
3. Update documentation if needed
```

### 7) Post Response to PR

Post the response as a PR comment:
```bash
gh pr comment "$PR_NUM" --body-file .review_response.md
```

## Final Steps

### 8) Update PR and Request Re-review

1. Update PR description if needed:
   ```bash
   # Update acceptance criteria checkboxes
   gh pr edit "$PR_NUM" --body-file .updated_pr_body.md
   ```

2. Push all changes:
   ```bash
   git push
   ```

3. Request re-review:
   ```bash
   gh pr review "$PR_NUM" --request-changes --body "Addressed review feedback. Please re-review the changes."
   ```

### 9) Validation Checklist

Before considering the response complete:
- [ ] Session file shows verification_complete: true
- [ ] All feedback items have verification_status != "pending"
- [ ] All critical issues addressed or have detailed justification
- [ ] All high priority issues addressed or converted to issues
- [ ] All deferred items added to plan.md tasks or new issues created
- [ ] Tests pass with changes
- [ ] No regressions introduced
- [ ] Response documented and posted
- [ ] Code comments added where confusion existed
- [ ] PR updated with current status

## Important Principles

1. **Every valid issue must be addressed** - either fixed now or tracked as a follow-up issue
2. **No silent deferrals** - always justify why something is deferred
3. **Maintain functionality** - if deferring would break something, it MUST be fixed now
4. **Clear communication** - document all decisions and responses
5. **Respect standards** - verify changes against project architecture and conventions
6. **Test everything** - ensure fixes don't introduce new problems
7. **Track everything** - use GitHub issues and sub-issues for proper project management