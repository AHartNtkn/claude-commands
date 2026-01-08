---
allowed-tools: Edit, Read, Bash(test*), Bash(git fetch:*), Bash(git checkout:*), Bash(git pull:*), Bash(git rebase:*), Bash(git branch:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git log:*), Bash(git remote:*), Bash(git symbolic-ref:*), Bash(git status:*), Bash(git grep:*), Bash(gh issue view:*), Bash(gh issue edit:*), Bash(gh sub-issue:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(gh pr ready:*), Bash(npm *), Bash(pnpm *), Bash(yarn *), Bash(python *), Bash(pytest*), Bash(go test*), Bash(cargo test*), Bash(pre-commit *), Bash(jq *), Bash([:*), Bash(grep:*), Bash(sed:*), Bash(echo:*), Bash(cat:*), Bash(xargs:*)
argument-hint: [ISSUE_NUMBER]
description: Implement a GitHub issue via strict Red→Green→Refactor TDD, small commits, and open a PR.
model: claude-sonnet-4-20250514
---

## Initial Context
- Issue details: !`gh issue view $ARGUMENTS --json number,title,body,state,labels,assignees,url`
- Current git status: !`git status --short`
- Current branch: !`git branch --show-current`
- Default branch: !`git remote show origin | grep "HEAD branch" | cut -d: -f2 | xargs`

## Spec Context (if available)
- Spec exists: !`[ -f .claude/spec.md ] && echo "true" || echo "false"`
- Spec state exists: !`[ -f .claude/spec-state.json ] && echo "true" || echo "false"`
- Relevant requirements: !`grep -E "FR-|NFR-" .claude/spec.md`
- Test strategy: !`cat .claude/spec-state.json | jq ".test_strategy"`
- Review criteria: !`cat .claude/spec-state.json | jq ".review_criteria"`

## Procedure (execute in order; do not skip)
### 0) Preflight
1. Verify tools:
   - Run: `gh --version && gh auth status`
   - Run: `git --version`
   - If any fails, stop and report which prerequisite is missing.
2. Ensure clean tree:
   - Run: `git diff --quiet && git diff --cached --quiet || { echo "Working tree dirty"; exit 1; }`
3. Sync and detect default branch:
   - Run: `git fetch --all --prune`
   - Determine `DEFAULT_BRANCH` with simple detection:
     ```bash
     # Simple, reliable default branch detection
     DEFAULT_BRANCH=$(git remote show origin | grep "HEAD branch" | cut -d: -f2 | xargs)
     if [ -z "$DEFAULT_BRANCH" ]; then
       DEFAULT_BRANCH="main"  # Fallback to common default
       echo "Warning: Could not detect default branch, using 'main'"
     fi
     echo "Using default branch: $DEFAULT_BRANCH"
     ```
   - Run: `git checkout "$DEFAULT_BRANCH" && git pull --ff-only`

### 1) Read the issue and extract acceptance criteria
1. Review the issue details from context shown above
2. Abort if state ≠ `"OPEN"` (or `"OPEN"` equivalent in output).
3. Derive a **numbered acceptance-criteria checklist** from the issue body. Keep each item testable and behavior-specific. Save a draft PR body to `.gh_pr_body.md`:

```

Closes #\$ARGUMENTS

## Summary

Implement the feature in issue #\$ARGUMENTS with test-driven development (tests specify behavior).

## Acceptance Criteria (check all)

* [ ] \<criterion 1>
* [ ] \<criterion 2>
* [ ] \<criterion 3>

## Tests

* Unit tests: \<files / areas>
* Integration/E2E (if any): \<files / areas>

## Notes

* Deterministic tests only (no real network/time/fs); inject clocks/seeds; use fakes/mocks where needed.
* Small diffs/commits; fixups + autosquash for cleanup.

```

### 2) Comprehensive Context Discovery
This phase ensures you understand the complete context before implementation.

#### 2.1) Create Session Tracking File
1. Capture timestamp and create session filename:
   ```bash
   TIMESTAMP=$(date +%Y%m%d_%H%M%S)
   SESSION_FILE=".claude/sessions/implement-$ARGUMENTS-${TIMESTAMP}.json"
   echo "Creating session: $SESSION_FILE"
   ```

2. Create session file using Write tool with the path from $SESSION_FILE variable:
   ```json
   {
     "issue_number": "$ARGUMENTS",
     "created_at": "[current ISO timestamp]",
     "updated_at": "[current ISO timestamp]",
     "status": "context_gathering",
     "task_id": null,
     "parent_hierarchy": [],
     "dependencies_analyzed": [],
     "adrs_read": [],
     "acceptance_criteria": [],
     "progress": {}
   }
   ```

#### 2.2) Trace Parent Task Hierarchy
1. Read `.claude/plan.md` to find the task ID (T-XXX) for this issue
2. Trace the parent hierarchy all the way to the top:
   ```bash
   # Find task ID for this issue
   TASK_ID=$(grep -E "T-[0-9]+.*\[Issue #$ARGUMENTS\]" .claude/plan.md | grep -oE "T-[0-9]+" | head -1)
   
   # Build parent hierarchy by following Parent: fields
   CURRENT_TASK=$TASK_ID
   while [ -n "$CURRENT_TASK" ]; do
     # Extract parent task
     PARENT=$(grep -A10 "$CURRENT_TASK" .claude/plan.md | grep "Parent:" | sed 's/.*Parent: *//' | grep -oE "T-[0-9]+" | head -1)
     # Add to hierarchy tracking
     echo "Task $CURRENT_TASK -> Parent: ${PARENT:-ROOT}"
     CURRENT_TASK=$PARENT
   done
   ```
3. For each task in the hierarchy, understand its purpose and how it contributes to the overall goal

#### 2.3) Read and Apply ALL Relevant ADRs
1. List all ADRs and read them:
   ```bash
   # Find all ADRs
   ADR_FILES=$(ls .claude/ADRs/ADR-*.md 2>/dev/null || echo "")
   
   if [ -n "$ADR_FILES" ]; then
     echo "=== Reading Architecture Decision Records ==="
     for ADR in $ADR_FILES; do
       echo "Reading: $ADR"
       # Read the ADR using Read tool
       # Extract decisions that affect this task
       # Add to architectural constraints list
     done
   else
     echo "No ADRs found"
   fi
   ```
2. For each ADR:
   - Read it completely using Read tool
   - Identify if it affects this task (check "Affected Tasks" section)
   - Extract specific implementation guidance
   - Add constraints to session file

#### 2.4) Analyze ALL Dependency Implementations
1. Extract dependencies from plan.md for this task
2. For EACH dependency task:
   ```bash
   # Get dependency issue numbers
   DEPS=$(grep -A20 "$TASK_ID" .claude/plan.md | grep "Dependencies:" | sed 's/.*Dependencies: *//')
   
   for DEP in $DEPS; do
     if [[ $DEP == T-* ]]; then
       # Find issue number for dependency
       DEP_ISSUE=$(grep "$DEP.*\[Issue #" .claude/plan.md | grep -oE "#[0-9]+" | sed 's/#//')
       
       # Find and analyze merged PRs
       echo "=== Analyzing dependency $DEP (Issue #$DEP_ISSUE) ==="
       
       # Use Task tool for comprehensive analysis with EXPLICIT instructions
       # Task prompt MUST include:
       #
       # "Analyze the LOCAL codebase in THIS repository for issue #$DEP_ISSUE.
       #
       # CRITICAL INSTRUCTIONS:
       # - This is a LOCAL issue in THIS repository only
       # - Task IDs (T-XXX) are internal to this project - DO NOT web search for them
       # - Use ONLY these tools: Read, Grep, Glob, Bash (for gh commands)
       # - DO NOT use WebSearch or WebFetch for any T-XXX or #XXX references
       #
       # WHERE TO LOOK:
       # 1. Find the PR that closed issue #$DEP_ISSUE:
       #    gh pr list --state merged --search '#$DEP_ISSUE'
       # 2. Get files changed in that PR:
       #    gh pr diff [PR#] --name-only
       # 3. Read the actual implementation files in src/
       # 4. Review test files that were added/modified
       # 5. Check the PR body and commits for context
       #
       # EXTRACT:
       # - Key APIs and interfaces created (with exact function signatures)
       # - Design patterns used (with code examples)
       # - Test strategies employed (with test file references)
       # - Conventions established (naming, structure, error handling)
       #
       # Focus on code in THIS repository only. All analysis must be based on
       # actual files you read, not external documentation."
     fi
   done
   ```
3. Use Task tool with appropriate sub-agent (file-analyzer or code-analyzer) following the template above:
   - MUST specify this is LOCAL repository analysis
   - MUST prohibit WebSearch/WebFetch for task IDs
   - MUST provide specific file paths or gh commands to use
   - Extract APIs, patterns, and test strategies from ACTUAL CODE, not web docs

#### 2.5) Review Completed Sub-issues
For each completed sub-issue with merged PRs:
   ```bash
   # Get sub-issue numbers
   SUBISSUE_NUMS=$(gh sub-issue list "$ARGUMENTS" --json number,title,state 2>/dev/null | jq -r '.[] | select(.state == "CLOSED") | .number')
   
   for SUBISSUE in $SUBISSUE_NUMS; do
     echo "=== Reviewing sub-issue #$SUBISSUE ==="
     
     # Find PRs that reference this sub-issue
     gh pr list --state merged --search "in:body #$SUBISSUE" --json number,title,mergedAt --limit 10 > .gh_pr_list_$SUBISSUE.json
     
     # For each PR, use Task tool for deep analysis
     PR_NUMS=$(cat .gh_pr_list_$SUBISSUE.json | jq -r '.[].number')
     for PR in $PR_NUMS; do
       # Task: "Review LOCAL PR #$PR in THIS repository.
       # CRITICAL: This is a LOCAL PR - use 'gh pr view $PR' and 'gh pr diff $PR'
       # DO NOT web search. Extract patterns from actual code files in this repo."
     done
   done
   ```

#### 2.6) Synthesize Complete Context
Create `.claude/context-$ARGUMENTS.md` with:
```markdown
# Implementation Context for Issue #$ARGUMENTS

## Task Hierarchy
- Root Goal: [from spec]
- Parent Chain: [T-001 → T-005 → T-023]
- This Task: T-XXX - [purpose]

## Architectural Constraints (from ADRs)
- ADR-001: Must use [specific decision]
- ADR-002: Follow [specific pattern]

## Building On (from dependencies)
- T-XXX (PR #Y): Provides [APIs/interfaces]
- T-YYY (PR #Z): Established [patterns]

## Patterns to Follow (from sub-issues)
- Testing: [specific approach seen]
- Error handling: [established pattern]
- API design: [conventions used]

## Implementation Approach
Based on all context:
1. [Specific approach following ADRs]
2. [Using APIs from dependencies]
3. [Following patterns from related work]
```

#### 2.7) Update Session File
Update the session file with all discovered context:
```json
{
  ...previous fields...,
  "status": "context_complete",
  "task_id": "T-XXX",
  "parent_hierarchy": ["T-001", "T-005", "T-023"],
  "dependencies_analyzed": ["T-010", "T-015"],
  "adrs_read": ["ADR-001", "ADR-002"],
  "architectural_constraints": [...],
  "implementation_approach": "..."
}

### 2.5) Consult development plan
1. Read `.claude/plan.md` using Read tool
2. Locate this task (T-XXX) in the plan and review:
   - Prerequisites and dependencies  
   - Acceptance criteria specific to this task
   - Any architectural constraints or decisions
3. Verify all prerequisite tasks are completed
4. Check if any dependencies are marked as open questions (Q-XXX) - if so, stop and inform user these must be resolved first
5. If plan doesn't exist, stop with error: "No development plan found. Run `/plan` first."

### 2.6) Task scope validation
Analyze if this task is appropriately scoped for a single PR:
- Acceptance criteria complexity - can this be implemented in <500 LOC changes?
- Multiple major components involved - does this span too many systems?
- Significant architectural changes required - is this really multiple tasks?

If task appears too large for a single PR:
1. Read current plan.md using Read tool
2. Break down task into logical implementation steps that collectively complete the parent task
3. Add new T-XXX sub-tasks to plan's WBS section with proper hierarchy
4. Create GitHub issues for new sub-tasks immediately
5. Update plan version and add changelog entry
6. Write updated plan.md using Edit tool
7. Stop implementation and inform user: "Task broken down into sub-tasks - see updated plan"

### 3) Create feature branch
1. Compute a slug from the issue title:  
   `SLUG="$(gh issue view "$ARGUMENTS" --json title --jq '.title' | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g;s/^-+|-+$//g' | cut -c1-50)"`
2. `BRANCH="feat/${ARGUMENTS}-${SLUG}"`
3. `git checkout -b "$BRANCH" "$DEFAULT_BRANCH"`

### 4) Detect test command (set TEST_CMD env; fail if unknown)
Detection order:
- If `package.json` exists and `npm -v` works and `.scripts.test` is nonempty → `export TEST_CMD="npm test --silent"`
- Else if `pyproject.toml` or `pytest.ini` present → `export TEST_CMD="pytest -q"` (or `python -m pytest -q` if needed)
- Else if `go.mod` present → `export TEST_CMD="go test ./..."`
- Else if `Cargo.toml` present → `export TEST_CMD="cargo test"`
- Else: stop and ask for the project’s canonical test command.

### 5) Baseline test run
- Run: `$TEST_CMD`
- If failing unrelated to the issue:
  - `git fetch origin && git rebase origin/"$DEFAULT_BRANCH"`
  - Re-run `$TEST_CMD`. If still failing and unrelated, open a **draft PR** with failing logs attached and pause implementation.

### 6) Implementation approach analysis
Before starting TDD, thoroughly analyze this specific task and plan any needed updates:

1. **Analyze implementation approach for each acceptance criterion:**
   - What technical approach will you take to implement each one?
   - What components, modules, or systems need to be created or modified?
   - What are the key implementation challenges or complexities?

2. **Identify specific architectural decisions required:**
   - What technical choices need to be made that aren't specified in the plan/spec?
   - What are the viable alternatives and their trade-offs?
   - What design patterns, frameworks, or approaches need to be chosen?

3. **Check for missing dependencies:**
   - What prerequisites or foundation work is needed that isn't in the current plan?
   - What other tasks should be completed before this one can succeed?

4. **Update plan.md if needed:**
   - Read current plan.md using Read tool
   - Add missing T-XXX prerequisite tasks with GitHub issues
   - Add Q-XXX questions for architectural decisions requiring user choice
   - Follow exact plan versioning: bump version, add changelog entry
   - Write updated plan.md using Edit tool
   
5. **If architectural questions added:** Stop and inform user "Architectural questions added to plan - run `/plan` to continue"

### 7) TDD working rules (hard constraints)
- Strict **Red → Green → Refactor**; **one** acceptance-criterion (or sub-behavior) at a time.
- Keep commits small: aim ≤ ~200 changed LOC and ≤ ~5 files per commit. Split if exceeded.
- Tests **deterministic and hermetic**: no real network/time/fs; inject clocks/seeds; use fakes/stubs/mocks.
- Prefer unit tests first (test pyramid); add integration/E2E only to cover behavior seams.
- After each cycle: run targeted tests, then periodically the full suite.
### 8) Plan update procedure (used by TDD loop)
When plan updates are needed during implementation:
1. Read current plan.md using Read tool
2. Add missing T-XXX tasks or Q-XXX questions as appropriate
3. Update plan version and add changelog entry explaining the addition
4. Write updated plan.md using Edit tool
5. Create GitHub issues for any new T-XXX tasks immediately
6. Stop and inform user: "Plan updated - run `/plan` to continue" or "Questions added - run `/plan` to continue"

### 9) TDD loop (repeat per acceptance criterion)

#### 9.1) Check Session for Resume Point
If resuming from a previous session:
```bash
# Check for most recent session file for this issue
LATEST_SESSION=$(ls -t .claude/sessions/implement-$ARGUMENTS-*.json 2>/dev/null | head -1)
if [ -n "$LATEST_SESSION" ]; then
  echo "Found previous session: $LATEST_SESSION"
  # Read the session file using Read tool to extract progress
  # Continue from last completed criterion
else
  echo "No previous session found, starting fresh"
fi
```

#### 9.2) Track Progress Per Criterion
For each acceptance criterion, update session file:
```json
{
  ...previous fields...,
  "acceptance_criteria": [
    {"id": 1, "description": "...", "status": "completed"},
    {"id": 2, "description": "...", "status": "in_progress"},
    {"id": 3, "description": "...", "status": "pending"}
  ],
  "current_criterion": 2
}
```

#### 9.3) Red-Green-Refactor Cycle

**RED**
1. Select next acceptance criterion to implement
2. Update session: Mark criterion as "in_progress"
3. **Pre-flight check**: Can you write a meaningful test for this behavior?
   - Check against architectural constraints from ADRs
   - Verify dependencies provide needed APIs
   - If foundational work is missing → Use plan update procedure and stop
   - If architectural choice needed → Use plan update procedure and stop
   - If clear what to test → proceed
4. Write smallest failing test that demonstrates the desired behavior
5. Verify test fails for the right reason: run `$TEST_CMD`
6. Commit **only the test**:
   - Stage precisely the test files
   - `git commit -m "test(#$ARGUMENTS): <short behavior>"`
7. Update session: Mark phase as "red_complete"

**GREEN**
8. **Implementation check**: Is the approach to make this test pass clear?
   - Verify approach aligns with ADR decisions
   - Use patterns from dependency implementations
   - If missing foundation work → Use plan update procedure and stop
   - If multiple approaches with significant trade-offs → Use plan update procedure and stop
   - If straightforward → proceed
9. Write minimal code to pass the test
10. Run `$TEST_CMD` until green
11. Commit implementation:
    `git commit -a -m "feat(#$ARGUMENTS): <minimal implementation>"`
12. Update session: Mark phase as "green_complete"

**REFACTOR**
13. Improve internals without changing behavior. Run formatters/linters if configured (e.g., `pre-commit run -a`).
14. Run `$TEST_CMD`.
15. Commit refactor:  
    `git commit -a -m "refactor: <cleanup, no behavior change>"`
16. Update session: Mark criterion as "completed"

**Housekeeping**
17. Review staged diff before each commit: `git diff --staged`. If you need to adjust a prior commit, use fixups and autosquash:  
    - `git commit --fixup=<SHA>` then `git rebase --autosquash "$DEFAULT_BRANCH"`
18. Update session file with completed criterion

### 10) Draft PR early if spec is ambiguous (recommended)
- Create a draft PR to get feedback after the first failing test commit if criteria are unclear:  
  `gh pr create --title "feat: $ARGUMENTS $SLUG" --body-file .gh_pr_body.md --draft`

### 11) Final validation
1. Ensure **all** new/affected tests pass: `$TEST_CMD`
2. Run formatters/linters (respect repo tooling; e.g., `pre-commit run -a`).
3. Rebase on latest default and re-run tests:  
   `git fetch origin && git rebase origin/"$DEFAULT_BRANCH" && $TEST_CMD`

### 12) Create/update PR
- If no PR exists:  
  `gh pr create --title "feat: $ARGUMENTS $SLUG" --body-file .gh_pr_body.md`
- Ensure the PR body contains **Closes #$ARGUMENTS** and the acceptance-criteria checklist.
- Mirror labels/assignees from the issue when appropriate:  
  `gh pr edit --add-assignee "@me"` (and add labels as needed)
- If previously draft, mark ready when CI is green:  
  `gh pr ready`

### 13) Merge policy and post-merge
- Do **not** merge unless every acceptance-criteria checkbox is ticked and tests are green.
- If the repo uses squash-merge, ensure the PR title follows **Conventional Commits**.
- After merge into the default branch, confirm the linked issue auto-closed. If not, update PR body with closing keyword and re-merge or push a new commit.

### 14) Finalize Session
Update session file with completion status using Edit tool (use the $SESSION_FILE path from earlier):
   ```json
   {
     ...all previous fields...,
     "status": "completed",
     "completed_at": "[current ISO timestamp]",
     "updated_at": "[current ISO timestamp]",
  "pr_number": "[PR number created]",
  "all_criteria_completed": true,
  "adrs_followed": ["ADR-001", "ADR-002"],
  "patterns_from_dependencies": ["API pattern from T-010", "Test pattern from T-015"]
}
```

This session file provides a complete audit trail of:
- What context was gathered before implementation
- Which ADRs were followed
- What patterns were reused from dependencies
- Progress through each acceptance criterion
- Final PR created
