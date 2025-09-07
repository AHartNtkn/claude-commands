---
allowed-tools: Write, Edit, WebSearch, Bash(gh issue create:*), Bash(gh issue view:*), Bash(gh sub-issue:*), Bash(jq *)
context-commands:
  - name: spec_location
    command: '[ -f .claude/spec.md ] && echo ".claude/spec.md" || ([ -f spec.md ] && echo "spec.md" || echo "NOT_FOUND")'
  - name: spec_content
    command: '[ -f .claude/spec.md ] && cat .claude/spec.md || ([ -f spec.md ] && cat spec.md || echo "No spec found")'
  - name: spec_state
    command: '[ -f .claude/spec-state.json ] && cat .claude/spec-state.json || echo "{}"'
  - name: parent_issue
    command: '[ -f .claude/spec-state.json ] && jq -r ".meta.github_issue // empty" .claude/spec-state.json || echo ""'
  - name: setup_claude_dir
    command: 'mkdir -p .claude && echo "Directory ready"'
  - name: plan_exists
    command: '[ -f .claude/plan.md ] && echo "true" || echo "false"'
  - name: existing_plan
    command: '[ -f .claude/plan.md ] && cat .claude/plan.md || echo ""'
  - name: plan_version
    command: '[ -f .claude/plan.md ] && grep -oE "^# Plan \(v[0-9.]+\)" .claude/plan.md | grep -oE "v[0-9.]+" || echo "none"'
---

## Initial Context
- Spec location: !{spec_location}
- Parent issue from spec: !{parent_issue}
- Plan exists: !{plan_exists}
- Plan version: !{plan_version}
- Claude directory: !{setup_claude_dir}

## Creating New Plan (if plan_exists == "false")

If spec location is "NOT_FOUND", inform the user: "No spec found. Please run `/spec` first to create one."

Otherwise, you are creating a new plan from the spec. Follow the complete protocol below to:
1. Extract all requirements and deliverables from the spec
2. Create a comprehensive work breakdown structure
3. Generate GitHub issues for all tasks
4. Iterate with the user to resolve all open questions

## Resuming/Updating Existing Plan (if plan_exists == "true")

### Existing Plan Content
!{existing_plan}

You are resuming or updating an existing plan (version !{plan_version}). This typically happens when:
- The `/implement` command found tasks that need decomposition
- New requirements were added to the spec
- Architectural decisions were made that require plan updates

For updates:
1. Load the existing plan and preserve all task IDs
2. Apply only minimal, targeted edits
3. Update version number and changelog
4. Continue with any remaining open questions

## Spec Content
!{spec_content}

## Spec State Data
!{spec_state}

Follow these steps exactly. Do not invent content. Do not choose among alternatives. Do not produce a schedule/timeline. Your job is to extract and organize, then iterate by asking one question at a time and applying **minimal** edits to the plan.

**0) Output target**

* Maintain a single Markdown file named `.claude/plan.md`.
* After every iteration, overwrite `.claude/plan.md` with the updated content and bump a version number.
* Create GitHub issues immediately as tasks are defined.
* Outside the file, ask **exactly one** question to the user, then wait for the reply before the next iteration.

**1) Initial parsing (from the spec only)**
1.1 Extract a **Scope & Deliverables** list (deliverable nouns only; outcomes not actions). For each item, capture exact spec references (section/paragraph IDs).
1.2 Extract **Constraints & NFRs** (performance, compliance, security, platforms, interfaces, budgets if present). Keep the spec citations.
1.3 Extract **Interfaces/Contracts** (producers/consumers, data shapes, protocols) with spec citations.
1.4 Extract **Uncertainties/Ambiguities** verbatim as candidate questions (no rewording that alters meaning).
1.5 If the spec lacks requirement IDs, synthesize stable **Req-IDs** from location anchors, e.g., `REQ[S3.2-p4]` (section 3.2, paragraph 4). Do not alter wording.

**2) Work Breakdown Structure (deliverable‑oriented)**
2.1 Build a hierarchical WBS that satisfies **the 100% rule** (every task's decomposed tasks sum to exactly that task's scope; no overlap).
2.2 Name WBS nodes as outcomes/artifacts (e.g., "Parser module implemented" / "API contract defined")—never action verbs alone.
2.3 Assign each node a stable ID `T-XXX` (zero‑padded).
2.4 **Task/Dependency Relationships:**
   * A task can be a **dependency** of multiple other tasks (prerequisite that must be completed first)
   * A task can **decompose** into smaller tasks that collectively implement it
   * Only top-level tasks (not decomposed from others) become sub-issues of the spec issue
   * All other tasks become sub-issues of their immediate task in the decomposition hierarchy
   * GitHub sub-issues show decomposition; task lists show prerequisites
2.5 For each new task `T-XXX`:
   * Create GitHub issue immediately: `gh issue create --title "T-XXX: {Title}" --body "{Details}"`
   * Capture the issue number
   * Link as sub-issue based on hierarchy (see section 10 for details)

**3) For every work package (leaf `T-XXX`) record structured fields**

* **\[ ] T-XXX Title** (concise, outcome‑oriented) **[Issue #NNN]**
  - Titles may temporarily include markers: "(ready for analysis)", "(obsolete)"
* **Spec Refs:** list of `REQ[...]` or section anchors.
* **Dependencies:** list of `T-YYY` and/or `Q-ZZZ` this task depends on (prerequisites).
* **Decomposes into:** list of `T-ZZZ` if this task is broken down into smaller tasks.
* **Artifacts to produce:** code modules, configs, migrations, docs, tests, data, etc., as dictated by the spec (no invention).
* **Acceptance Criteria (DoD):** measurable, **testable** conditions traceable to spec (e.g., "Given/When/Then" or bullet checks).
* **Risks & Assumptions:** only if explicitly present in the spec; otherwise, do not include this line.

**4) Traceability (prove coverage)**
4.1 Generate a **Requirements → Tasks** table: every requirement ID maps to ≥1 `T-XXX`; every `T-XXX` maps back to ≥1 requirement. If a mapping is missing, add a **question** instead of guessing.
4.2 Add a **Tests Placeholder** task per requirement if the spec mandates testing; otherwise, add a question about test expectations.

**5) Dependencies (no timeline)**
5.1 Build an internal dependency DAG over `T-XXX` and decision nodes `Q-ZZZ` (see §6). Disallow cycles; if a cycle appears, add a question to break it.
5.2 In the WBS list, show both types of relationships:
   * **Decomposition**: Nest decomposed tasks under their task to show breakdown
   * **Dependencies**: List prerequisite tasks in the "Dependencies" field
   * A task can be a dependency of multiple tasks (shared prerequisite)
5.3 Do **not** add dates or durations.

**6) Questions (decision placeholders)**
6.1 Create decision nodes `Q-ZZZ` (stable IDs). Each question must:

* Be **single‑decision** and **unambiguous**.
* Prefer **closed** form with enumerated options. If the spec provides no options, research common industry practices using WebSearch and suggest 2-3 reasonable alternatives with brief rationale, or ask as an open-ended question if research isn't applicable.
* Include **Rationale**: which requirements/tasks are blocked and why.
  6.2 Insert each `Q-ZZZ` **inline** under the affected task(s) **and** list all open questions in a top "Open Questions" section.

**7) File format of `.claude/plan.md`**

* `# Plan (vX.Y)`

  * **Parent Issue:** `#NNN` (spec issue from which all top-level tasks derive).
  * **Change Log** (reverse‑chronological; each entry lists what changed and which IDs were touched).
  * **Scope & Deliverables** (with spec citations).
  * **Constraints & NFRs** (with spec citations).
  * **Interfaces/Contracts** (with spec citations).
  * **Open Questions** (each `Q-ZZZ`: text, options if any, rationale, blocked IDs).
  * **Traceability Matrix** (Requirement → `T-XXX` links and vice versa).
  * **Hierarchical TODO (WBS)** using Markdown checkboxes:
    - Show decomposition by nesting
    - Show dependencies in each task's "Dependencies" field
    - Mark shared prerequisites clearly
  * **Issue Mapping:** `T-XXX` → GitHub Issue # (maintained as tasks are created).
* Use two‑space indentation per level.
* Never remove IDs once issued; deprecate by marking "Superseded by …" in the Change Log.

**8) Iterative refinement protocol (strict)**
8.1 **Initial iteration**: 
   * Produce `.claude/plan.md` v0.1 with all sections populated
   * Create GitHub issues for any initial tasks defined
   * Write **questions directly in the plan** where decisions are needed.
8.2 **Select one question to ask**: choose the open `Q-ZZZ` that **unblocks the largest number of dependent tasks** (ties → pick the one closest to the root by WBS depth, then lowest ID).
8.3 **Ask the user exactly one question** (verbatim from `.claude/plan.md`). Do not add commentary.
8.4 **On user reply, execute these steps in order**:

**Step A: Apply Answer**
* Apply **minimal edits only** to `.claude/plan.md`. Do **not** rewrite or reorder unaffected sections.
* Remove the answered Q-XXX from all tasks' Dependencies fields
* For any task where Q-XXX was just removed:
  - If task has no remaining Q-XXX in Dependencies, append "(ready for analysis)" to its title

**Step B: Process Answer Implications**
1. **Implementation implications**: What new tasks does this choice require?
2. **Technical dependencies**: What other decisions does this choice force or enable?
3. **WBS updates**: Create any new tasks required
   - Mark each new task with "(ready for analysis)" in its title
4. **Downstream effects**: Mark obsolete tasks with "(obsolete)" in title
5. **New questions**: Add any new Q-XXX that arise

**Step C: Task Breakdown Analysis**
* Find all tasks with "(ready for analysis)" in title
* For each one:
  - Estimate if implementation would exceed 500 LOC
  - If yes, decompose it:
    1. Identify the distinct pieces of functionality within the task
    2. Create a new T-XXX ID for each piece (non-overlapping scope)
    3. Make the original task decompose into these new tasks
    4. Each new task should have its own acceptance criteria subset
    5. Ensure decomposed tasks collectively implement 100% of the original task (no gaps, no overlaps)
    6. Update the original task to show "Decomposes into: T-XXX, T-YYY"
  - Remove "(ready for analysis)" from title

**Step D: GitHub Updates**
* If new tasks were created: immediately create GitHub issues and establish sub-issue relationships
* Update existing issues if they now depend on newly created tasks (see section 10)

**Step E: Finalize Iteration**
* Bump version (v0.2, v0.3, …)
* Append a precise Change Log entry listing touched IDs and the reason
* Write the updated `.claude/plan.md`

Repeat 8.2–8.4 until **no open questions remain**.
  8.5 When no questions remain, set version to **v1.0 (frozen)** and stop asking.

**9) Prohibitions**

* Do not decide among alternatives.
* Do not invent requirements, options, estimates, or timelines.
* Do not collapse multiple decisions into one question.
* Do not discard or renumber existing IDs.
* Do not refactor the whole `plan.md`; only targeted, minimal edits per iteration.

**10) GitHub Issue Management**
* Parent issue from spec: Already available as !{parent_issue} from context
* **Sub-issue Hierarchy Rules:**
  - **Top-level tasks** (not decomposed from others) → become sub-issues of spec issue #!{parent_issue}
  - **Decomposed tasks** → become sub-issues of their immediate task (not the spec)
  - **Dependencies** are tracked using GitHub task lists in issue body (auto-check when complete)
  - Note: GitHub only allows single-parent sub-issue relationships
* When creating a new task `T-XXX`:
  1. Build issue body with dependency tracking:
     ```markdown
     ## Task: T-XXX
     **Spec Refs:** [list of requirements]
     
     ## Dependencies
     <!-- GitHub will auto-check these when the referenced issues close -->
     - [ ] #YYY T-YYY: [Title of dependency]
     - [ ] #ZZZ T-ZZZ: [Title of dependency]
     
     ## Artifacts to Produce
     - [List artifacts]
     
     ## Acceptance Criteria
     - [ ] [Criterion 1]
     - [ ] [Criterion 2]
     ```
  2. Create issue: `gh issue create --title "T-XXX: {Title}" --body "$ISSUE_BODY"`
  3. Capture issue number from output
  4. Update task in plan with `[Issue #NNN]`
  5. Determine sub-issue relationship:
     - If task decomposes from `T-YYY`: `gh sub-issue add ISSUE_YYY ISSUE_XXX`
     - If top-level task: `gh sub-issue add $PARENT_ISSUE ISSUE_XXX`
  6. Dependencies will show as "2 of 2 tasks" in GitHub issue lists
  7. **Update existing issues when new dependencies are created:**
     - When a new task `T-NEW` is created that existing tasks depend on
     - For each existing task that lists `T-NEW` as a dependency:
       ```bash
       # Get current issue body
       CURRENT_BODY=$(gh issue view ISSUE_NUM --json body -q .body)
       
       # Add the new dependency to the Dependencies section
       # Insert after "## Dependencies" line
       UPDATED_BODY=$(echo "$CURRENT_BODY" | sed '/## Dependencies/a\
       - [ ] #NEW_ISSUE_NUM T-NEW: New Task Title')
       
       # Update the issue
       gh issue edit ISSUE_NUM --body "$UPDATED_BODY"
       ```
     - This ensures dependency tracking remains accurate as plan evolves
* Maintain bidirectional traceability in `.claude/plan.md`

Begin now with the **Initial iteration**: create `.claude/plan.md` v0.1 per §§1–7, then proceed with §8.2.

