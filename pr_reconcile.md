---
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checks:*)
argument-hint: [pr_number]
description: Reconcile a PR with plan.md: diff, highlight deviations, then iterate via one-question/minimal-edit updates until all deviations are resolved.
---

## Context

- **Plan file**: @plan.md  # must exist in repo root. If missing, ask the single question: “Where is plan.md located?” and stop.
- **PR metadata**: !`gh pr view $ARGUMENTS --json number,title,body,author,mergeStateStatus,baseRefName,headRefName,commits,files,reviews`
- **Changed files**: !`gh pr diff $ARGUMENTS --name-only`
- **Unified diff (patch)**: !`gh pr diff $ARGUMENTS --patch`

## Invariants (do not deviate)

1) **No creativity; no choices.** Never pick among alternatives. Only extract, compare, ask, and minimally update the plan.  
2) **Single-question loop.** After producing/refreshing `plan.md`, ask **exactly one** question outside the file, then wait for the answer before the next iteration.  
3) **Minimal edits only.** Never rewrite or reorder unaffected sections. Preserve all IDs (`T-XXX`, `Q-ZZZ`, `REQ[...]`). If something is replaced, mark the old item “Superseded by …” in the Change Log, do not delete.  
4) **No timeline.** Maintain a hierarchical TODO (nest follow-up items under prerequisites) to enable parallel work; no dates/durations.  
5) **WBS, traceability, testability remain enforced:**  
   - WBS **100% rule**: children sum to the parent’s scope; no overlap; outcomes not actions.
   - **Traceability** between requirements ↔ tasks ↔ tests; fill gaps with questions, not guesses.
   - **Definition of Done** expressed as testable acceptance criteria.
6) **Decision prioritization:** choose the next question that unblocks the largest number of downstream tasks in the dependency DAG; ties → shallower WBS depth, then lowest ID. (This is standard DAG/toposort reasoning.)

## Procedure

### A) Parse the current plan (from @plan.md)
A1. Read sections: **Scope & Deliverables**, **Constraints & NFRs**, **Interfaces/Contracts**, **Open Questions**, **Traceability Matrix**, **Hierarchical TODO (WBS)**, and **Change Log**.  
A2. Build in-memory indices:
   - **Tasks**: map `T-XXX` → {title, spec refs, prerequisites, artifacts, DoD, “Implementation Needed” flag}.  
   - **Questions**: map `Q-ZZZ` → {text, options, rationale, blocked IDs}.  
   - **Reqs**: `REQ[...]` identifiers from the plan.  
   - **Deps DAG** over tasks and questions; validate acyclicity (if a cycle is present, record a new `Q-ZZZ` asking how to break it).

### B) Parse the PR
B1. From PR metadata and diff:
   - **Changed files set** and **hunks**. 
   - **Commits** (scan messages for `T-XXX`, `REQ[...]`, “BREAKING CHANGE”, Conventional Commit types if present).
   - **PR body**: extract any explicit intents, scope notes, and linked issues.  
   - **CI checks** snapshot (pass/fail/pending).
B2. Attempt lightweight mapping:
   - **Map by ID references**: if commits/diff mention `T-XXX` or `REQ[...]`, link them directly.  
   - **Map by artifact names/paths** from each task’s “Artifacts to produce”.  
   - **Map by interface signatures** where tasks define APIs/protocols; compare to changed files touching those surfaces.

### C) Compute deltas (Plan vs. PR)
C1. **Planned & done:** tasks whose artifacts/IDs are clearly addressed in this PR.  
C2. **Planned & missing:** tasks expected (per WBS path prerequisites for this PR’s scope) but not touched.  
C3. **Unplanned work present:** changes with no corresponding `T-XXX`. These require **decision questions** whether to (a) add tasks, (b) mark as superseding existing tasks, or (c) drop/revert later.  
C4. **Spec/Interface deviation:** any change that alters previously planned interfaces, contracts, or NFRs requires a **question** citing affected `REQ[...]`.  
C5. **Acceptance criteria variance:** tests/docs differ from DoD; raise a **question** per affected task.  
C6. **Traceability gaps:** any requirement with changed code but no updated tests/links → **question** to fill the mapping, not a guess.

### D) Produce/Update `plan.md` (iteration output)
D1. **Version bump** (`vX.Y → vX.(Y+1)`), append **Change Log** entry “PR $ARGUMENTS Reconciliation – touched: {IDs}”.  
D2. **Open Questions**: create new `Q-ZZZ` items for **each deviation/gap**, with this structure:
   - **Text**: single-decision, closed if options exist; else “Options unknown—please specify.”  
   - **Rationale**: which `REQ[...]`/`T-XXX` are blocked and why.  
   - **Blocked IDs**: list.  
D3. **Traceability Matrix**: add rows/links only where user-authorized; for gaps, reference the responsible `Q-ZZZ`.
D4. **Hierarchical TODO (WBS)**:
   - For unplanned but accepted-in-principle items, add **placeholder tasks** (no DoD text beyond quotations from spec/PR) under the correct parent deliverable to preserve the **100% rule**; mark “Implementation Needed: Yes”. 
   - For superseded tasks, mark original `T-XXX` “Superseded by T-YYY (PR $ARGUMENTS)”—do **not** delete.  
   - Never alter unrelated sections or renumber existing IDs.

### E) Ask exactly one question (outside the file)
E1. Choose the `Q-ZZZ` that **unblocks the largest number of dependent tasks** (ties: shallower WBS depth, then lowest ID). State the question **verbatim** from `plan.md`. (This is equivalent to selecting the highest-out-degree decision node in a dependency DAG.)

### F) On user reply (next iteration)
F1. Apply **minimal edits** only to the impacted tasks/questions/traceability; update Change Log with the specific IDs changed and reason (e.g., “Accepted deviation D‑1: rename endpoint X→Y”).  
F2. If the answer implies more information is needed, add new **narrower `Q-ZZZ`** rather than rewriting existing parts.  
F3. Repeat E1–F2 until no open questions remain regarding this PR’s deviations. If no questions remain, finalize this PR’s reconciliation entry and stop.

## Report layout to return to user

- **PR $ARGUMENTS – Reconciliation Summary**
  - **Planned & done**: list of `T-XXX` with evidence (file paths/commit IDs).  
  - **Planned & missing**: list with rationale (blocked by what).  
  - **Unplanned work present**: list with proposed `Q-ZZZ` references.  
  - **Spec/Interface deviations**: list with affected `REQ[...]` and `Q-ZZZ`.  
  - **Acceptance criteria variances**: list with `T-XXX` and test/doc gaps.  
  - **Traceability deltas**: reqs lacking coverage → `Q-ZZZ`.  
  - **CI snapshot** (if available): pass/fail/pending summary.

## Prohibitions

- Do not decide whether deviations are “good” or “bad”.  
- Do not add acceptance criteria beyond what is explicit in the spec/plan/PR; unresolved details must become questions.  
- Do not remove IDs or rebase the plan.  
- Do not collapse multiple decisions into one question.

