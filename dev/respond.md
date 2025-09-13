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
- Plan exists: !{plan_exists}
- Spec requirements: !{spec_requirements}
- Review criteria: !{review_criteria}

## CRITICAL INSTRUCTION: NO PRIORITY JUDGMENTS

This command has ONE rule: **FIX ALL FEEDBACK or PROVE IT'S WRONG**.

You are NOT allowed to:
- Assess whether feedback is "critical" or "minor"
- Decide what's "important" vs "unimportant"
- Categorize issues by severity
- Make ANY priority judgments

Every single piece of feedback gets fixed unless you can provide concrete evidence it's factually incorrect.

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

### 3) Analyze and Classify Feedback

**DEFAULT BEHAVIOR: Fix ALL feedback about code in this PR.**

**MANDATORY: Every feedback item has exactly THREE possible outcomes:**
1. **FIX** - Make code changes to address it (DEFAULT)
2. **DISPUTE** - With CONCRETE EVIDENCE proving it's factually wrong
3. **DEFER** - ONLY if it's about code not touched by this PR or genuinely unrelated to the PR's purpose (must show evidence)

**NO OTHER OPTIONS EXIST. NO EXCEPTIONS.**

Only skip feedback if you can PROVE:
1. It's factually incorrect (show the evidence)
2. It contradicts a documented decision (cite the ADR/spec)
3. It's about code not modified in this PR (show the diff)
4. It's unrelated to what this PR is fixing (show PR description/issue)

**VIOLATION WARNING: If you use ANY of these words/phrases, you are FAILING:**
- "critical" / "non-critical" / "criticality"
- "minor" / "major" / "severity"
- "low priority" / "high priority"
- "architectural concern" vs "bug"
- "not important" / "can be deferred"
- "should be addressed later"
- "already resolved the critical issues"

**INVALID EXCUSES (NEVER acceptable):**
- "This is more of an architectural concern than a critical bug"
- "This isn't critical"
- "The critical issues have been resolved"
- "This can be addressed in a follow-up"
- "This is a minor issue"
- "This seems low priority"

**DEFAULT ACTION FOR ALL FEEDBACK: FIX IT**
The burden of proof is on YOU to show why NOT to fix something.

For each piece of review feedback:

1. **Add to session.feedback_items**:
   ```json
   {
     "id": "F001",
     "reviewer_comment": "[exact quote]",
     "scope": "in-pr|out-of-pr",
     "action": "fix|dispute|defer-to-existing|create-issue",
     "evidence": null,
     "defer_to": null,
     "implementation_status": "pending"
   }
   ```

2. **Determine scope**:
   - Is this about code changed in this PR? → `scope: "in-pr"`
   - Is this about other code? → `scope: "out-of-pr"`
   Check the PR diff to verify what was actually changed.

3. **Determine action (DEFAULT IS TO FIX)**:
   - For `in-pr` feedback:
     - Can you fix it? → `action: "fix"` (DEFAULT)
     - Is it factually wrong? → `action: "dispute"` (REQUIRES EVIDENCE)
   - For `out-of-pr` feedback:
     - Does an existing task/issue cover this? → `action: "defer-to-existing"`
     - Is it a new concern not covered? → `action: "create-issue"` (RARE)
     - Is it not applicable? → `action: "dispute"` (with explanation)

   **Dispute ONLY with concrete evidence**:
   ```json
   "evidence": "Test output shows all tests pass: [paste output]"
   "evidence": "File exists at src/auth.js:45, not missing"
   "evidence": "ADR-003 explicitly chose synchronous processing"
   "evidence": "This code is in main branch, not changed in PR"
   ```

4. **Mark verification complete** when all items verified:
   ```json
   "verification_complete": true,
   "implementation_allowed": true
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