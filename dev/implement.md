---
allowed-tools: Edit, Bash(test*), Bash(git fetch:*), Bash(git checkout:*), Bash(git pull:*), Bash(git rebase:*), Bash(git branch:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git log:*), Bash(git remote:*), Bash(git symbolic-ref:*), Bash(git status:*), Bash(git grep:*), Bash(gh issue view:*), Bash(gh sub-issue:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(gh pr ready:*), Bash(npm *), Bash(pnpm *), Bash(yarn *), Bash(python *), Bash(pytest*), Bash(go test*), Bash(cargo test*), Bash(pre-commit *), Bash(jq *)
argument-hint: [ISSUE_NUMBER]
description: Implement a GitHub issue via strict Red→Green→Refactor TDD, small commits, and open a PR.
model: claude-sonnet-4-20250514
context-commands:
  - name: issue_json
    command: 'gh issue view $ARGUMENTS --json number,title,body,state,labels,assignees,url'
  - name: subissues_json
    command: 'gh sub-issue list "$ARGUMENTS" --json number,title,state 2>/dev/null || echo "[]"'
  - name: spec_requirements
    command: '[ -f .claude/spec.md ] && grep -E "FR-|NFR-" .claude/spec.md || echo ""'
  - name: spec_test_strategy
    command: '[ -f .claude/spec-state.json ] && jq ".test_strategy" .claude/spec-state.json || echo "{}"'
  - name: spec_review_criteria
    command: '[ -f .claude/spec-state.json ] && jq ".review_criteria" .claude/spec-state.json || echo "{}"'
  - name: git_status
    command: 'git status --short'
  - name: current_branch
    command: 'git branch --show-current'
  - name: default_branch
    command: 'git remote show origin 2>/dev/null | sed -n "s/.*HEAD branch: //p" || echo "main"'
---

## Initial Context
- Issue details: !{issue_json}
- Sub-issues: !{subissues_json}
- Current git status: !{git_status}
- Current branch: !{current_branch}
- Default branch: !{default_branch}

## Spec Context (if available)
- Relevant requirements: !{spec_requirements}
- Test strategy: !{spec_test_strategy}
- Review criteria: !{spec_review_criteria}

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
   - Determine `DEFAULT_BRANCH`:
     - Try: `DEFAULT_BRANCH="$(git remote show origin | sed -n 's/.*HEAD branch: //p')"`
     - If empty: `DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')"`
   - Run: `git checkout "$DEFAULT_BRANCH" && git pull --ff-only`

### 1) Read the issue and extract acceptance criteria
1. Review the issue details from context (!{issue_json})
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

### 2) Gather context from spec and sub-issues
1. Review spec context from initial context section above (requirements, test strategy, review criteria)
2. Review sub-issues from context (!{subissues_json})
3. For each completed sub-issue with merged PRs:
   ```bash
   # Get sub-issue numbers
   SUBISSUE_NUMS=$(cat .gh_subissues.json | jq -r '.[] | select(.state == "CLOSED") | .number')
   
   # For each sub-issue, find and review its PRs
   for SUBISSUE in $SUBISSUE_NUMS; do
     echo "=== Reviewing sub-issue #$SUBISSUE ==="
     
     # Find PRs that reference this sub-issue
     gh pr list --state merged --search "in:body #$SUBISSUE" --json number,title,mergedAt --limit 10 > .gh_pr_list_$SUBISSUE.json
     
     # For each PR, get the full diff and implementation details
     PR_NUMS=$(cat .gh_pr_list_$SUBISSUE.json | jq -r '.[].number')
     for PR in $PR_NUMS; do
       echo "  - PR #$PR:"
       # Get PR details including files changed
       gh pr view $PR --json title,body,files,additions,deletions
       # Get the actual diff to understand implementation
       gh pr diff $PR
     done
   done
   ```
4. Synthesize learnings from reviewed PRs and spec:
   - Implementation patterns used
   - Test strategies employed (cross-reference with spec test strategy)
   - Dependencies or APIs introduced
   - Design decisions made
   - Acceptance criteria from spec that apply to this issue
   - Review criteria that will be used for the PR
5. Save context summary to `.gh_context.md` for reference during implementation

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

### 6) TDD working rules (hard constraints)
- Strict **Red → Green → Refactor**; **one** acceptance-criterion (or sub-behavior) at a time.
- Keep commits small: aim ≤ ~200 changed LOC and ≤ ~5 files per commit. Split if exceeded.
- Tests **deterministic and hermetic**: no real network/time/fs; inject clocks/seeds; use fakes/stubs/mocks.
- Prefer unit tests first (test pyramid); add integration/E2E only to cover behavior seams.
- After each cycle: run targeted tests, then periodically the full suite.

### 7) TDD loop (repeat per acceptance criterion)
**RED**
1. Add the smallest failing test that demonstrates the desired behavior. Ensure the runner discovers it by filename/pattern.
2. Prove the test fails for the right reason: run `$TEST_CMD`.
3. Commit **only the test**:  
   - Stage precisely the test files.  
   - `git commit -m "test(#$ARGUMENTS): <short behavior>"`

**GREEN**
4. Implement the **minimal** production code to pass the new test.
5. Run `$TEST_CMD` until green.
6. Commit implementation:  
   `git commit -a -m "feat(#$ARGUMENTS): <minimal implementation>"`

**REFACTOR**
7. Improve internals without changing behavior. Run formatters/linters if configured (e.g., `pre-commit run -a`).
8. Run `$TEST_CMD`.
9. Commit refactor:  
   `git commit -a -m "refactor: <cleanup, no behavior change>"`

**Housekeeping**
10. Review staged diff before each commit: `git diff --staged`. If you need to adjust a prior commit, use fixups and autosquash:  
    - `git commit --fixup=<SHA>` then `git rebase --autosquash "$DEFAULT_BRANCH"`

### 8) Draft PR early if spec is ambiguous (recommended)
- Create a draft PR to get feedback after the first failing test commit if criteria are unclear:  
  `gh pr create --title "feat: $ARGUMENTS $SLUG" --body-file .gh_pr_body.md --draft`

### 9) Final validation
1. Ensure **all** new/affected tests pass: `$TEST_CMD`
2. Run formatters/linters (respect repo tooling; e.g., `pre-commit run -a`).
3. Rebase on latest default and re-run tests:  
   `git fetch origin && git rebase origin/"$DEFAULT_BRANCH" && $TEST_CMD`

### 10) Create/update PR
- If no PR exists:  
  `gh pr create --title "feat: $ARGUMENTS $SLUG" --body-file .gh_pr_body.md`
- Ensure the PR body contains **Closes #$ARGUMENTS** and the acceptance-criteria checklist.
- Mirror labels/assignees from the issue when appropriate:  
  `gh pr edit --add-assignee "@me"` (and add labels as needed)
- If previously draft, mark ready when CI is green:  
  `gh pr ready`

### 11) Merge policy and post-merge
- Do **not** merge unless every acceptance-criteria checkbox is ticked and tests are green.
- If the repo uses squash-merge, ensure the PR title follows **Conventional Commits**.
- After merge into the default branch, confirm the linked issue auto-closed. If not, update PR body with closing keyword and re-merge or push a new commit.
