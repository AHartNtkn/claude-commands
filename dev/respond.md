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

## Review Analysis

### 1) Categorize Review Feedback

Based on the latest review comment and review threads from context above, create a categorized list:

Create `.review_analysis.md` with this structure:
```markdown
# Review Analysis for PR #[NUMBER]

## Critical Issues (Block Merge)
- [ ] Issue 1: [Description]
  - File: [path:line]
  - Reviewer comment: [quote]
  - Action: MUST FIX NOW

## High Priority (Should Fix)
- [ ] Issue 2: [Description]
  - File: [path:line]
  - Reviewer comment: [quote]
  - Action: SHOULD FIX NOW

## Medium Priority (Can Defer)
- [ ] Issue 3: [Description]
  - File: [path:line]
  - Reviewer comment: [quote]
  - Action: CREATE FOLLOW-UP ISSUE
  - Justification for deferral: [reason]

## Low Priority Suggestions
- [ ] Suggestion 1: [Description]
  - File: [path:line]
  - Reviewer comment: [quote]
  - Action: OPTIONAL / FUTURE WORK

## Invalid/Disputed Feedback
- [ ] Disputed 1: [Description]
  - Reviewer comment: [quote]
  - Why invalid: [explanation with reference to standards]
  - Action: ADD CLARIFYING COMMENT
```

### 2) Verify Against Standards

1. Review spec requirements and review criteria from context above

2. Check other project documentation:
   ```bash
   # Check other project docs
   for doc in .claude/ADRs/*.md ARCHITECTURE.md CONTRIBUTING.md docs/standards.md; do
     if [ -f "$doc" ]; then
       echo "Checking against: $doc"
       # Review recommendations against documented standards
     fi
   done
   ```

3. For each recommendation, verify:
   - Does it align with spec requirements (FR-*/NFR-*)?
   - Does it meet the defined review criteria from spec?
   - Does it align with architectural decisions (ADRs)?
   - Does it follow project conventions?
   - Is it consistent with existing patterns?
   - Would it break existing functionality?
   - Does it maintain the test coverage targets from spec?

4. Update `.review_analysis.md` with findings

## Implementation

### 3) Address Critical and High Priority Issues

For each issue marked as MUST FIX NOW or SHOULD FIX NOW:

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

### 4) Create Follow-up Issues

For each issue marked as CREATE FOLLOW-UP ISSUE:

1. Create a detailed GitHub issue:
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
- [ ] All critical issues addressed or have detailed justification
- [ ] All high priority issues addressed or converted to issues
- [ ] Tests pass with changes
- [ ] No regressions introduced
- [ ] Follow-up issues created and linked
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