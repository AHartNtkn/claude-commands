---
allowed-tools: Edit, Bash(git:*), Bash(gh pr:*), Bash(gh issue:*), Bash(gh sub-issue:*), Bash(gh api:*), Bash(test*), Bash(npm *), Bash(pnpm *), Bash(yarn *), Bash(python *), Bash(pytest*), Bash(go test*), Bash(cargo test*), Bash(jq *), Bash(echo:*), Bash(sed:*), Bash(grep:*), Bash(awk:*), Bash([:*), Bash(perl:*), Bash(bash -c:*), Bash(~/.claude/commands/dev/filter-diff.sh:*), Read, Grep, Task
argument-hint: [PR_NUMBER]
description: Systematically respond to PR review feedback with proper issue tracking and documentation
---

## Initial Context
- PR Number: $ARGUMENTS
- PR Details: !`gh pr view $ARGUMENTS --json number,title,body,state,reviews,comments`
- Latest Review: !`bash -c "gh pr view $ARGUMENTS --comments --json comments | jq -r '.comments[-1].body // empty'"`
- Review Threads: !`bash -c "gh pr view $ARGUMENTS --json comments | jq '.comments'"`
- Files Changed (excluding sessions): !`bash -c "gh pr diff $ARGUMENTS --name-only | grep -v '\.claude/sessions/'"`
- Plan exists: !`test -f .claude/plan.md && echo "true" || echo "false"`
- Spec requirements: !`test -f .claude/spec.md && grep -E "FR-|NFR-" .claude/spec.md || echo ""`
- Review criteria: !`test -f .claude/spec-state.json && jq ".review_criteria" .claude/spec-state.json || echo "{}"`

## Full PR Diff (excluding session files)
!`~/.claude/commands/dev/filter-diff.sh $ARGUMENTS`

## CORE RULE: INVESTIGATE → FIX (or prove wrong with evidence)

Default to FIX. Only dispute with concrete counter-evidence from code. Never defer without proving file wasn't touched in PR.

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

#### Step 3.1: Extract Feedback from Standard Review Sections

The `/dev/review` command produces these standard sections. Check for ALL of them:

1. **Check for "## Critical Issues (Must Fix)"**
   - STATE: "Checking for Critical Issues section..."
   - Search for this exact heading in the review
   - Extract all items listed under this heading until the next ## heading
   - STATE: "Found [N] critical issues" or "No Critical Issues section found"

2. **Check for "## High Priority Issues (Should Fix)"**
   - STATE: "Checking for High Priority Issues section..."
   - Search for this exact heading in the review
   - Extract all items listed under this heading until the next ## heading
   - STATE: "Found [N] high priority issues" or "No High Priority Issues section found"

3. **Check for "## Medium Priority Issues (Consider Fixing)"**
   - STATE: "Checking for Medium Priority Issues section..."
   - Search for this exact heading in the review
   - Extract all items listed under this heading until the next ## heading
   - STATE: "Found [N] medium priority issues" or "No Medium Priority Issues section found"

4. **Check for "## Low Priority Suggestions"**
   - STATE: "Checking for Low Priority Suggestions section..."
   - Search for this exact heading in the review
   - Extract all items listed under this heading until the next ## heading
   - STATE: "Found [N] low priority suggestions" or "No Low Priority Suggestions section found"

5. **Verification Before Proceeding:**
   - STATE: "Extraction complete. Sections checked: [✓ Critical, ✓ High, ✓ Medium, ✓ Low]"
   - STATE: "Total items extracted: [X]"
   - If any standard section wasn't found, STATE which ones were missing
   - List all extracted items in session as:
   ```json
   "feedback_items": [
     {"id": "F001", "severity": "critical", "reviewer_comment": "[exact quote]", "status": "pending"},
     {"id": "F002", "severity": "high", "reviewer_comment": "[exact quote]", "status": "pending"},
     {"id": "F003", "severity": "medium", "reviewer_comment": "[exact quote]", "status": "pending"}
   ]
   ```

**MANDATORY**: You must check all four sections even if some are empty. The STATE outputs are required to prove you checked each section.

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

### 5) Verify & Plan Implementation

1. **Verification gate**:
   ```bash
   VERIFIED=$(jq -r '.verification_complete' "$SESSION_FILE")
   [ "$VERIFIED" != "true" ] && echo "ERROR: Investigation incomplete" && exit 1
   ```

2. **Find existing implementations** (for each fix):
   ```bash
   # Search for existing code
   grep -r "[function_name]" src/ --include="*.ts" --include="*.js"
   ```

3. **Record implementation plan**:
   ```json
   "implementation_plan": {
     "existing_code_found": "src/utils.ts:45-67",
     "action": "modify",  // or "delete_replace" or "create_new"
   }
   ```
   - Code exists → MODIFY
   - Wrong architecture → DELETE+REPLACE
   - Nothing exists → CREATE NEW

### 6) Fix Feedback Using Implementation Hierarchy

**CRITICAL RULES - Follow in this EXACT order:**

#### Rule 1: MODIFY existing code (DEFAULT)
If implementation_plan.action = "modify":
- Use Edit/MultiEdit on the existing file
- Modify the current implementation to fix the issue
- Do NOT create a parallel implementation
- Do NOT add V2/New/Updated versions

Example:
```bash
# If existing code at src/utils.ts:45-67
# Use Edit to modify it directly
Edit src/utils.ts
# Change the existing function, don't create generateUUIDv2
```

#### Rule 2: DELETE AND REPLACE (for architectural issues)
If implementation_plan.action = "delete_replace":
- First DELETE the old implementation COMPLETELY
- Then create the new implementation
- Update ALL references to use new implementation
- NEVER leave both versions

Signs requiring DELETE+REPLACE:
- Wrong data structure fundamentally
- Incorrect algorithm approach
- Misunderstood requirements
- Reviewer says "this approach is wrong"

Example:
```bash
# Delete old implementation
Edit src/old.ts  # Remove entire function/class
# Create new implementation
Edit src/new.ts  # Add replacement
# Update all imports/references
grep -r "oldFunction" src/  # Find all references
# Update each reference to use new implementation
```

#### Rule 3: CREATE NEW (ONLY if nothing exists)
If implementation_plan.action = "create_new":
- Verify once more that nothing similar exists
- Create the new implementation
- Add appropriate tests

**FORBIDDEN PATTERNS:**
❌ Creating `functionV2` while `function` exists
❌ Adding `newImplementation` alongside `oldImplementation`
❌ Creating `utils2.ts` when `utils.ts` has the feature
❌ Leaving old code "for backwards compatibility"
❌ Adding duplicate functionality with slightly different names

**REQUIRED PATTERN:**
✓ Found existing → Modified it directly
✓ Wrong approach → Deleted old, replaced completely
✓ Didn't exist → Created new (after verification)
✓ One implementation per feature
✓ No dead code remains

#### Implementation Process

For each fix:

1. **Follow the implementation_plan.action**:
   - Check session for action decision from Phase 5.5
   - Execute according to hierarchy rules above

2. **Test the change**: `npm test` (or appropriate)

3. **Commit**: `git commit -m "fix(review): [modify|replace|add] [what] to address [issue]"`


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

### 8) Document & Close

1. **Add clarifying comments for disputes** (if needed):
   ```python
   # Uses synchronous processing per ADR-003 (transaction boundaries)
   ```

2. **Create response document** `.review_response.md`:
   ```markdown
   # Response to PR Review

   ## Summary
   Addressed X of Y items, created Z follow-ups.

   ## Fixed
   ✅ **[Issue]**: [What was fixed] - Commit: [sha]

   ## Disputed
   ❌ **[Claim]**: [Why incorrect] - Evidence: [code quote]

   ## Deferred
   📝 **Issue #[NUM]**: [What was deferred] - Reason: [Out of PR scope]
   ```

3. **Post and update**:
   ```bash
   gh pr comment "$PR_NUM" --body-file .review_response.md
   git push
   gh pr review "$PR_NUM" --request-changes --body "Addressed feedback. Please re-review."
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