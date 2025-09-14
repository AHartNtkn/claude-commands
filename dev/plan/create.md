---
allowed-tools: Read, Write, Grep, WebSearch, Bash(gh issue create:*), Bash(gh issue view:*), Bash(gh issue list:*), Bash(gh sub-issue:*), Bash(jq:*), Bash([:*), Bash(echo:*), Bash(cat:*)
description: Create initial plan from specification
---

# Plan Creation Phase

## Preflight Checks

### Check 1: Specification exists
- Spec location: !`[ -f .claude/spec.md ] && echo ".claude/spec.md" || ([ -f spec.md ] && echo "spec.md" || echo "NOT_FOUND")`
- Plan already exists: !`[ -f .claude/plan.md ] && echo "true" || echo "false"`

**If spec_location is "NOT_FOUND":**
Stop and inform user: "No specification found. Please run `/dev/spec` first to create one."

**If plan_exists is "true":**
Stop and inform user: "Plan already exists at .claude/plan.md. Run `/dev/plan/analyze` to continue analysis."

## Specification Content
!`[ -f .claude/spec.md ] && cat .claude/spec.md || ([ -f spec.md ] && cat spec.md || echo "")`

## Spec State
!`[ -f .claude/spec-state.json ] && cat .claude/spec-state.json || echo "{}"`

## Algorithm to Execute

### Step 1: Parse Specification
Extract from the spec:
1. **Scope & Deliverables** (deliverable nouns only, with exact spec references)
2. **Constraints & NFRs** (performance, security, platforms, with spec citations)
3. **Interfaces/Contracts** (data shapes, protocols, with spec citations)
4. **Requirement IDs** - If missing, synthesize as `REQ[S3.2-p4]` (section 3.2, paragraph 4)

### Step 1.5: Analyze Foundation Requirements
Before creating tasks, determine what technical foundation is needed:

1. **Create analysis session file:**
   ```bash
   TIMESTAMP=$(date +%Y%m%d_%H%M%S)
   SESSION_FILE=".claude/sessions/plan-create-${TIMESTAMP}.json"
   echo "Creating session: $SESSION_FILE"
   ```
   Then create the session file using Write tool with the path from $SESSION_FILE variable

2. **Analyze the spec to identify technical constraints:**
   - Read through ALL requirements and constraints
   - Note any mentions of specific technologies, languages, platforms
   - Consider what the deliverables imply about technology choices
   - Document your reasoning in the session file

3. **Determine which foundation decisions are needed:**
   Consider these categories, but ONLY create questions for what's truly undecided:
   - **Runtime/Language**: Is this constrained by the spec? By the deliverables?
   - **Build System**: Does the language/platform choice determine this?
   - **Test Framework**: Are there specific testing requirements that constrain this?
   - **Project Structure**: Does the scope suggest a particular organization?
   - **CI/CD Pipeline**: GitHub Actions, GitLab CI, CircleCI, Jenkins?
   - **Code Quality Tools**: Linter choice, formatter, pre-commit hooks?

4. **For each needed decision, formulate a question with relevant options:**
   - Options must be compatible with spec constraints
   - Include pros/cons relevant to this specific project
   - Don't include options that would violate requirements

5. **Document your analysis in the session file:**
   Use the $SESSION_FILE path from step 1 with Write tool:
   ```json
   {
     "created_at": "[current ISO timestamp]",
     "updated_at": "[current ISO timestamp]",
     "spec_analysis": {
       "explicit_tech_mentions": ["List what spec explicitly states"],
       "implicit_constraints": ["What the requirements imply"],
       "deliverable_implications": ["What the deliverables require"]
     },
     "decisions_already_made": {
       "language": "TypeScript (spec requires TypeScript types)",
       "platform": "Node.js (spec mentions npm package)"
     },
     "decisions_needed": [
       {
         "decision": "build_system",
         "reasoning": "Need to compile TypeScript and bundle for distribution",
         "viable_options": ["Vite", "Webpack", "ESBuild"]
       },
       {
         "decision": "test_framework", 
         "reasoning": "Spec requires 90% test coverage, need framework for TypeScript",
         "viable_options": ["Jest", "Vitest", "Mocha with ts-node"]
       },
       {
         "decision": "ci_platform",
         "reasoning": "Need automated testing and builds on PR/merge",
         "viable_options": ["GitHub Actions", "GitLab CI", "CircleCI"]
       },
       {
         "decision": "code_quality",
         "reasoning": "Need consistent code style and catch issues early",
         "viable_options": ["ESLint + Prettier", "Biome", "Standard"]
       }
     ]
   }
   ```

**CRITICAL**: Think through the actual implications of the spec. Don't just create generic questions - analyze what THIS project specifically needs.

### Step 2: Build Work Breakdown Structure
Create hierarchical WBS following these rules:
- **100% rule**: Complete coverage, no overlap
- **Outcome-oriented names**: "Parser module implemented" not "Implement parser"
- **Stable IDs**: T-000 for environment setup, then T-001, T-002, etc. (zero-padded)
- **T-000 is special**: Development environment setup task (always first)
- **All tasks start with**:
  - `[Issue #TBD]` placeholder
  - `Status:` field (T-000 is `blocked`, others are `ready`)
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

**T-000 is special:**
- Always create T-000 "Development environment initialized" first
- T-000 has status: blocked
- T-000 dependencies: Q-001, Q-002, Q-003, Q-004
- First implementation tasks depend on T-000

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

### Phase 0: Development Foundation
* **[ ] T-000 Development environment initialized** [Issue #TBD]
  * **Status:** blocked
  * **Spec Refs:** All (foundation for entire project)
  * **Dependencies:** Q-001, Q-002, Q-003, Q-004 (or whatever questions were created in Step 5)
  * **Parent:** []
  * **Decomposes into:** []
  * **Artifacts to produce:** package.json/requirements.txt/go.mod, build config, test setup, CI/CD config, linter config, directory structure
  * **Acceptance Criteria:** Can write, build, test, and run code

### Phase 1: Core Infrastructure
* **[ ] T-001 Task Title** [Issue #TBD]
  * **Status:** ready
  * **Dependencies:** T-000 (if this is a first implementation task)
  * [other fields...]

### Phase 2: Another Section
* **[ ] T-002 Task Title** [Issue #TBD]
  * **Status:** ready
  * [other fields...]

NOTE: Phase headers (### Phase X:) are organizational only - do NOT add [Issue #TBD] to them
```

### Step 5: Initialize questions.json
Based on your analysis from Step 1.5, create `.claude/questions.json` with the foundation questions identified.

For each decision needed (from your session file), create a question with:
- Unique ID (Q-001, Q-002, etc.)
- Clear question text
- Context explaining why this decision is needed
- Options that are viable given the spec constraints
- Pros/cons relevant to THIS project's requirements
- Status: "open"
- Affects: ["T-000"]

Example structure (customize based on your analysis):
```json
{
  "Q-001": {
    "question": "[First decision needed]?",
    "context": "[Why this decision is needed based on spec]",
    "options": [
      {"id": 1, "name": "[Option 1]", "pros": ["..."], "cons": ["..."]},
      {"id": 2, "name": "[Option 2]", "pros": ["..."], "cons": ["..."]}
    ],
    "affects": ["T-000"],
    "status": "open"
  }
}
```

**IMPORTANT**: 
- Only create questions for decisions that are truly needed
- If the spec constrains a choice, don't create a question for it
- Options should be appropriate for the project's constraints
- Empty {} if no foundation questions are needed (rare but possible)

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
- Top-level tasks → sub-issues of spec issue #!`[ -f .claude/spec-state.json ] && jq -r ".meta.github_issue // empty" .claude/spec-state.json || echo ""`
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

Next step: Run `/dev/plan` to further detail the plan.
```
