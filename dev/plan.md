---
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
---

## Initial Context
- Spec location: !{spec_location}
- Parent issue from spec: !{parent_issue}
- Claude directory: !{setup_claude_dir}

## Spec Content
!{spec_content}

## Spec State Data
!{spec_state}

If spec location is "NOT_FOUND", inform the user: "No spec found. Please run `/spec` first to create one."

Otherwise, proceed with the spec from the location above. Follow these steps exactly. Do not invent content. Do not choose among alternatives. Do not produce a schedule/timeline. Your job is to extract and organize, then iterate by asking one question at a time and applying **minimal** edits to the plan.

**0) Output target**

* Maintain a single Markdown file named `.claude/plan.md` (create `.claude` directory if it doesn't exist).
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
2.1 Build a hierarchical WBS that satisfies **the 100% rule** (every parent's children sum to exactly that parent's scope; no overlap).
2.2 Decompose until each leaf is a **work package** small enough to be reasonably completed in **\~8–80 person‑hours**; if uncertain, keep as an open question and do **not** guess.
2.3 Name WBS nodes as outcomes/artifacts (e.g., "Parser module implemented" / "API contract defined")—never action verbs alone.
2.4 Assign each node a stable ID `T-XXX` (zero‑padded).
2.5 For each new task `T-XXX`:
   * Create GitHub issue immediately: `gh issue create --title "T-XXX: {Title}" --body "{Details}"`
   * Capture the issue number
   * If task has prerequisites, use `gh sub-issue add` to link to parent tasks

**3) For every work package (leaf `T-XXX`) record structured fields**

* **\[ ] T-XXX Title** (concise, outcome‑oriented) **[Issue #NNN]**
* **Spec Refs:** list of `REQ[...]` or section anchors.
* **Prerequisites:** list of `T-YYY` and/or `Q-ZZZ` this task depends on.
* **Artifacts to produce:** code modules, configs, migrations, docs, tests, data, etc., as dictated by the spec (no invention).
* **Acceptance Criteria (DoD):** measurable, **testable** conditions traceable to spec (e.g., "Given/When/Then" or bullet checks).
* **Risks & Assumptions:** only if explicitly present in the spec; otherwise, do not include this line.

**4) Traceability (prove coverage)**
4.1 Generate a **Requirements → Tasks** table: every requirement ID maps to ≥1 `T-XXX`; every `T-XXX` maps back to ≥1 requirement. If a mapping is missing, add a **question** instead of guessing.
4.2 Add a **Tests Placeholder** task per requirement if the spec mandates testing; otherwise, add a question about test expectations.

**5) Dependencies (no timeline)**
5.1 Build an internal dependency DAG over `T-XXX` and decision nodes `Q-ZZZ` (see §6). Disallow cycles; if a cycle appears, add a question to break it.
5.2 In the WBS list, **nest** follow‑up tasks under their prerequisites to make parallelizable branches explicit. Do **not** add dates or durations.

**6) Questions (decision placeholders)**
6.1 Create decision nodes `Q-ZZZ` (stable IDs). Each question must:

* Be **single‑decision** and **unambiguous**.
* Prefer **closed** form with enumerated options quoted from the spec; if the spec provides no options, explicitly say “Options unknown—please specify.”
* Include **Rationale**: which requirements/tasks are blocked and why.
  6.2 Insert each `Q-ZZZ` **inline** under the affected parent task(s) **and** list all open questions in a top “Open Questions” section.

**7) File format of `.claude/plan.md`**

* `# Plan (vX.Y)`

  * **Parent Issue:** `#NNN` (if this plan is for a specific parent issue).
  * **Change Log** (reverse‑chronological; each entry lists what changed and which IDs were touched).
  * **Scope & Deliverables** (with spec citations).
  * **Constraints & NFRs** (with spec citations).
  * **Interfaces/Contracts** (with spec citations).
  * **Open Questions** (each `Q-ZZZ`: text, options if any, rationale, blocked IDs).
  * **Traceability Matrix** (Requirement → `T-XXX` links and vice versa).
  * **Hierarchical TODO (WBS)** using Markdown checkboxes; children are nested under prerequisites.
  * **Issue Mapping:** `T-XXX` → GitHub Issue # (maintained as tasks are created).
* Use two‑space indentation per level.
* Never remove IDs once issued; deprecate by marking "Superseded by …" in the Change Log.

**8) Iterative refinement protocol (strict)**
8.1 **Initial iteration**: 
   * Create `.claude` directory if needed: `mkdir -p .claude`
   * Produce `.claude/plan.md` v0.1 with all sections populated
   * Create GitHub issues for any initial tasks defined
   * Write **questions directly in the plan** where decisions are needed.
8.2 **Select one question to ask**: choose the open `Q-ZZZ` that **unblocks the largest number of dependent tasks** (ties → pick the one closest to the root by WBS depth, then lowest ID).
8.3 **Ask the user exactly one question** (verbatim from `.claude/plan.md`). Do not add commentary.
8.4 **On user reply**:

* Apply **minimal edits only** to `.claude/plan.md`. Do **not** rewrite or reorder unaffected sections.
* If new tasks are created: immediately create GitHub issues and establish sub-issue relationships
* Update impacted tasks/questions, possibly add new questions uncovered by the answer.
* Bump version (v0.2, v0.3, …) and append a precise Change Log entry listing touched IDs and the reason.
* Repeat 8.2–8.4 until **no open questions remain**.
  8.5 When no questions remain, set version to **v1.0 (frozen)** and stop asking.

**9) Prohibitions**

* Do not decide among alternatives.
* Do not invent requirements, options, estimates, or timelines.
* Do not collapse multiple decisions into one question.
* Do not discard or renumber existing IDs.
* Do not refactor the whole `plan.md`; only targeted, minimal edits per iteration.

**10) GitHub Issue Management**
* Parent issue from spec: Already available as !{parent_issue} from context
* When creating a new task `T-XXX`:
  1. Create issue: `gh issue create --title "T-XXX: {Title}" --body "{spec refs, artifacts, acceptance criteria}"`
  2. Capture issue number from output
  3. Update task in plan with `[Issue #NNN]`
  4. If task has prerequisite tasks with issues, link them:
     `gh sub-issue add PARENT_ISSUE_NUM CHILD_ISSUE_NUM`
  5. If parent spec issue exists, link task as sub-issue:
     `gh sub-issue add $PARENT_ISSUE TASK_ISSUE_NUM`
* Maintain bidirectional traceability in `.claude/plan.md`

Begin now with the **Initial iteration**: create `.claude/plan.md` v0.1 per §§1–7, then proceed with §8.2.

