---
allowed-tools: Read, Write, Grep, WebSearch, Bash(gh issue create:*), Bash(gh issue view:*), Bash(gh issue list:*), Bash(gh sub-issue:*), Bash(jq *)
description: Create initial plan from specification
context-commands:
  - name: spec_location
    command: '[ -f .claude/spec.md ] && echo ".claude/spec.md" || ([ -f spec.md ] && echo "spec.md" || echo "NOT_FOUND")'
  - name: spec_content
    command: '[ -f .claude/spec.md ] && cat .claude/spec.md || ([ -f spec.md ] && cat spec.md || echo "")'
  - name: spec_state
    command: '[ -f .claude/spec-state.json ] && cat .claude/spec-state.json || echo "{}"'
  - name: parent_issue
    command: '[ -f .claude/spec-state.json ] && jq -r ".meta.github_issue // empty" .claude/spec-state.json || echo ""'
  - name: plan_exists
    command: '[ -f .claude/plan.md ] && echo "true" || echo "false"'
---

# Plan Creation Phase

## Preflight Checks

### Check 1: Specification exists
- Spec location: !{spec_location}
- Plan already exists: !{plan_exists}

**If spec_location is "NOT_FOUND":**
Stop and inform user: "No specification found. Please run `/dev/spec` first to create one."

**If plan_exists is "true":**
Stop and inform user: "Plan already exists at .claude/plan.md. Run `/dev/plan/analyze` to continue analysis."

## Specification Content
!{spec_content}

## Spec State
!{spec_state}

## Algorithm to Execute

### Step 1: Parse Specification
Extract from the spec:
1. **Scope & Deliverables** (deliverable nouns only, with exact spec references)
2. **Constraints & NFRs** (performance, security, platforms, with spec citations)
3. **Interfaces/Contracts** (data shapes, protocols, with spec citations)
4. **Requirement IDs** - If missing, synthesize as `REQ[S3.2-p4]` (section 3.2, paragraph 4)

### Step 2: Build Work Breakdown Structure
Create hierarchical WBS following these rules:
- **100% rule**: Complete coverage, no overlap
- **Outcome-oriented names**: "Parser module implemented" not "Implement parser"
- **Stable IDs**: T-001, T-002, etc. (zero-padded)
- **All tasks start with**:
  - `[Issue #TBD]` placeholder
  - `Status: ready` field
  - Complete field set (dependencies, artifacts, acceptance criteria)

### Step 3: Task Field Structure
Each task must have:
```markdown
* **[ ] T-XXX Title** [Issue #TBD]
* **Status:** ready
* **Spec Refs:** [requirement IDs]
* **Dependencies:** [T-YYY list if any]
* **Parent:** []
* **Decomposes into:** []
* **Artifacts to produce:** [specific deliverables]
* **Acceptance Criteria:** [testable conditions]
```

**IMPORTANT**: 
- Parent and "Decomposes into" fields must start EMPTY. Decomposition only happens during the analyze phase, NOT during creation.
- ONLY tasks (T-XXX) get [Issue #TBD] placeholders
- Phase headers, section titles, and organizational text do NOT get issues
- If it doesn't have a T-XXX ID, it doesn't get an issue

### Step 4: Create plan.md
Generate `.claude/plan.md` with structure:
```markdown
# Plan (v0.1)

**Parent Issue:** #[parent_issue_number]
**Change Log:** 
- v0.1: Initial plan created from spec

**Scope & Deliverables**
[List with spec citations]

**Constraints & NFRs**
[List with spec citations]

**Interfaces/Contracts**
[List with spec citations]

**Traceability Matrix**
| Requirement | Tasks | Coverage |
|------------|-------|----------|
| REQ[...] | T-XXX, T-YYY | ✓ |

**Hierarchical TODO (WBS)**

### Phase 1: Core Infrastructure
* **[ ] T-001 Task Title** [Issue #TBD]
  * **Status:** ready
  * [other fields...]

### Phase 2: Another Section
* **[ ] T-002 Task Title** [Issue #TBD]
  * **Status:** ready
  * [other fields...]

NOTE: Phase headers (### Phase X:) are organizational only - do NOT add [Issue #TBD] to them
```

### Step 5: Initialize questions.json
Create an empty `.claude/questions.json` file:
```json
{}
```

This ensures the analyze phase can add questions without file-not-found errors.

### Step 6: Create GitHub Issues
After creating plan.md and questions.json, run the issue creation script:
```bash
~/.claude/commands/dev/claude-plan-issues
```

This script will:
- Create GitHub issues for all tasks with [Issue #TBD]
- Update plan.md with actual issue numbers
- Establish sub-issue relationships

## Important Notes

### Task Relationships
- **Dependencies**: Prerequisites that must complete first (tracked in task lists)
- **Decomposition**: Parent-child breakdown (tracked as sub-issues)
- Top-level tasks → sub-issues of spec issue #!{parent_issue}
- Decomposed tasks → sub-issues of their parent task

### Prohibitions
- Do NOT invent requirements not in spec
- Do NOT add estimates or timelines
- Do NOT skip the GitHub issue creation
- Do NOT use existing IDs if updating
- Do NOT decompose tasks during creation (that's for analyze phase)
- Do NOT set Parent or "Decomposes into" fields (MUST BE EMPTY)
- Do NOT add [Issue #TBD] to phase headers or section titles
- Do NOT create issues for non-task organizational text

## Completion

When complete, inform the user:
```
✅ Plan created successfully:
- Created .claude/plan.md v0.1
- Created .claude/questions.json (empty)
- Generated [N] tasks in WBS
- Created GitHub issues #XXX-#YYY
- Established sub-issue relationships

Next step: Run `/dev/plan/analyze` to analyze tasks for decisions and decomposition.
```
