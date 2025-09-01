---
allowed-tools: Write, Read, Bash(gh issue create:*), Task, Bash(jq *)
argument-hint: [PROJECT_NAME]
description: Interactive requirements interview producing a complete SRS integrated with the development workflow
context-commands:
  - name: claude_dir_exists
    command: '[ -d .claude ] && echo "true" || echo "false"'
  - name: spec_exists
    command: '[ -f .claude/spec.md ] && echo "true" || echo "false"'
  - name: spec_version
    command: '[ -f .claude/spec-state.json ] && jq -r ".meta.version" .claude/spec-state.json || echo "none"'
  - name: setup_dirs
    command: 'mkdir -p .claude .claude/ADRs && echo "Directories created"'
---

# /spec $ARGUMENTS

## Purpose
Run a rigorous, *interactive* requirements interview and produce a complete, unambiguous Software/System Requirements Specification (SRS) for **$ARGUMENTS**. The spec will be saved to `.claude/spec.md` and integrated with GitHub issues and the planning workflow.

## Operating Rules
- Ask **one focused question per turn**. After each answer, update a working draft and show a compact diff.
- Use standard terminology and IDs. Every requirement gets an ID (`FR-###` or `NFR-###`) and MoSCoW priority.
- Never accept vague terms. If the user uses ambiguous language, challenge it and propose measurable replacements.
- Continue until the **Quality Gates** below all pass. Only then present the final SRS.
- Save all outputs to `.claude/` directory for integration with other commands.

## References to Apply (do not cite to user unless asked)
- ISO/IEC/IEEE 29148: characteristics of a good requirement & SRS info items.
- INCOSE Guide to Writing Requirements: well-formed single requirements, well-formed sets.
- NASA SE Handbook Appendix C: checklists; ban ambiguous terms.
- EARS patterns (Mavin): gently constrained requirement grammar.
- BDD/Gherkin: `Given/When/Then` acceptance criteria.
- FURPS+ for NFR taxonomy.
- MoSCoW prioritization with ≤60% Must-Have effort, ~20% Could-Haves pool guidance.

## Initial Context
- Claude directory exists: !{claude_dir_exists}
- Existing spec found: !{spec_exists}
- Current spec version: !{spec_version}
- Setup status: !{setup_dirs}

## Data Structures (maintained during the interview)
Maintain and show a JSON "spec_state" after every turn, saving to `.claude/spec-state.json`:

```json
{
  "meta": {
    "project": "$ARGUMENTS",
    "version": "0.1-draft",
    "authors": [],
    "date": null,
    "github_issue": null
  },
  "overview": {
    "vision": "",
    "business_objectives": [],
    "success_metrics": [],
    "stakeholders": [],
    "assumptions": [],
    "out_of_scope": []
  },
  "context": {
    "users_personas": [],
    "operational_context": "",
    "dependencies": [],
    "interfaces_external": []
  },
  "functional_requirements": [
    {
      "id": "FR-001",
      "title": "",
      "statement": "",
      "ears_pattern": "",
      "rationale": "",
      "acceptance_criteria_gherkin": [],
      "priority": "MUST|SHOULD|COULD|WONT",
      "trace_to_objectives": [],
      "deliverables": {
        "components": [],
        "apis": [],
        "configs": [],
        "schemas": []
      }
    }
  ],
  "nonfunctional_requirements": [
    {
      "id": "NFR-001",
      "category_furps": "Usability|Reliability|Performance|Supportability|Security|Compliance|Availability|Maintainability|Portability",
      "statement": "",
      "metric": {"unit": "", "target": "", "method_of_verification": "Test|Analysis|Inspection|Demonstration"},
      "priority": "MUST|SHOULD|COULD|WONT",
      "trace_to_objectives": [],
      "review_criteria": []
    }
  ],
  "test_strategy": {
    "test_levels": {
      "unit": {"coverage_target": "", "framework": ""},
      "integration": {"coverage_target": "", "approach": ""},
      "e2e": {"coverage_target": "", "approach": ""}
    },
    "performance_benchmarks": [],
    "test_data_requirements": [],
    "ci_cd_requirements": []
  },
  "work_breakdown": {
    "major_components": [],
    "implementation_phases": [],
    "technical_dependencies": [],
    "estimated_effort": {
      "must_have_percentage": 0,
      "should_have_percentage": 0,
      "could_have_percentage": 0
    }
  },
  "data_model": {
    "entities": [],
    "critical_fields": [],
    "privacy_retention_rules": []
  },
  "constraints": {
    "business": [],
    "technical": [],
    "regulatory": []
  },
  "risks": [
    {"id": "R-001", "description": "", "impact": "", "mitigation": ""}
  ],
  "review_criteria": {
    "definition_of_done": [],
    "pr_checklist": [],
    "security_review": [],
    "performance_review": []
  },
  "architectural_decisions": [],
  "glossary": [],
  "open_items": []
}
```

## Question Sequence (loop until Quality Gates pass)

**Phase 0 — Kickoff (1 question)**
* Ask for a one-sentence vision and the top 3 business objectives with measurable success metrics (e.g., KPI deltas or SLAs with numbers/time bounds).

**Phase 1 — Scope & stakeholders**
* Ask for in-scope capabilities (bullets) and an explicit out-of-scope list.
* Enumerate stakeholders (roles, responsibilities, decision rights). Ask who approves the spec.

**Phase 2 — Users & context**
* Identify primary personas, operational environments, external systems/interfaces, and dependencies.
* Check for existing architecture docs: `ls -la .claude/ADRs/ ARCHITECTURE.md docs/architecture/`

**Phase 3 — Functional requirements (EARS)**
For each capability, elicit FRs using EARS patterns. Offer choices and instantiate one by one:

* *Ubiquitous*: "The <system> shall <response>."
* *Event-driven*: "When <trigger>, the <system> shall <response>."
* *State-driven*: "While <state>, the <system> shall <response>."
* *Unwanted behavior*: "If <undesired condition>, the <system> shall <mitigation response>."

For each FR, also ask about:
* What components/modules will implement this?
* What APIs or interfaces are needed?
* What configuration will be required?
* What data schemas are involved?

Enforce: single intent per requirement; active voice; no design/implementation constraints in FR statements.

**Phase 4 — Acceptance criteria (Gherkin)**
For each FR, ask for 1–3 scenarios:

```
Scenario: <behavior slice>
  Given <preconditions and data>
  When <action/event>
  Then <observable outcome with precise thresholds>
```

**Phase 5 — NFRs (FURPS+)**
Walk categories and capture measurable targets:

* Performance (e.g., P95 latency ms, throughput/s, startup time)
* Reliability (MTBF/MTTR, error budgets, durability)
* Availability (SLA %, RTO/RPO)
* Security (authn/authz model, crypto levels, audit)
* Usability (task-success %, SUS score, learnability minutes)
* Supportability/Maintainability (SLOs for triage/fix, upgrade time, observability)
* Portability/Compatibility/Interoperability

For each:
* Record metric and **verification method** (Test/Analysis/Inspection/Demonstration)
* Define review criteria: what to check in PRs

**Phase 6 — Test Strategy**
* Define test levels and coverage targets for unit/integration/e2e
* Identify performance benchmarks and how to measure them
* Specify test data requirements
* Define CI/CD requirements

**Phase 7 — Work Breakdown**
* Identify major components/modules
* Suggest implementation phases (what can be built in parallel vs sequential)
* Map technical dependencies between components
* Estimate effort distribution across priorities

**Phase 8 — Data model & policies**
* Identify core entities, critical fields, PII categorization, retention/anonymization rules, import/export formats.

**Phase 9 — Constraints & risks**
* Business/market, regulatory/compliance, technical (runtime, languages, legacy integration), deadlines/budgets.
* Top risks with mitigations.

**Phase 10 — Prioritization (MoSCoW)**
* Assign M/S/C/W per requirement. Keep **Must-Have effort ≤ 60%** and maintain ~**20%** Could-Have buffer. If limits are exceeded, ask to re-prioritize.

**Phase 11 — Review Criteria**
* Define "Definition of Done" for the project
* Create PR review checklist items
* Specify security review requirements
* Define performance review criteria

**Phase 12 — Glossary**
* Build a glossary for all domain terms and acronyms referenced anywhere in the spec.

**Phase 13 — Ambiguity purge (NASA/INCOSE/29148 Gate)**
Scan all text for ambiguity and flag replacements. Challenge terms such as:
* "as appropriate", "etc.", "and/or", "user-friendly", "maximize/minimize", adverbs ending in "-ly", verbs ending in "-ize".
Also flag: passive voice, compound requirements, hidden design, "TBD/TBR".

**Phase 14 — Traceability**
* Ensure every requirement traces to at least one business objective; show a matrix `[ReqID -> Objectives]`. Ask to fill any gaps.

## Quality Gates (all must be true before finishing)

1. **Completeness:** All sections populated; no `open_items`; no `TBD/TBR`.
2. **Clarity & Singularity:** Each requirement is single-intent, active voice, with a unique ID and title.
3. **Verifiability:** Every FR has ≥1 Gherkin scenario; every NFR has a numeric metric + verification method.
4. **Consistency:** No conflicting statements; terminology matches the glossary; cross-references valid.
5. **Prioritization bounds:** Must-Haves ≤60% of total estimated effort; Could-Haves ≈20% pool exists.
6. **Traceability:** 100% of requirements trace to ≥1 objective.
7. **Deliverables:** Every FR maps to concrete deliverables (components, APIs, configs, schemas).
8. **Testability:** Test strategy defined with coverage targets and approach.

If any gate fails, continue questioning with minimal, targeted prompts.

## Final Deliverable

When all gates pass:

1. **Save versioned SRS** to `.claude/spec.md` and `.claude/spec-v1.0.md`:
```bash
# Save the state file
echo '[spec_state JSON]' | jq '.' > .claude/spec-state.json

# Save the markdown spec
cat > .claude/spec.md << 'EOF'
[Full SRS in Markdown format - see structure below]
EOF

# Keep versioned copy
cp .claude/spec.md .claude/spec-v1.0.md
```

2. **Create GitHub parent issue**:
```bash
ISSUE_TITLE="[Spec] $ARGUMENTS - $(jq -r '.overview.vision' .claude/spec-state.json)"
ISSUE_BODY="# Software Requirements Specification

$(cat .claude/spec.md)

## Implementation Tracking
This is the parent issue for implementing this specification.
Sub-issues will be created for each major component.

## Acceptance Criteria
All functional requirements (FR-*) implemented and tested.
All non-functional requirements (NFR-*) met and verified.

Generated from spec.md v1.0"

SPEC_ISSUE=$(gh issue create --title "$ISSUE_TITLE" --body "$ISSUE_BODY" --label "epic,specification" | grep -oE '[0-9]+$')
echo "Created GitHub issue #$SPEC_ISSUE"

# Update the spec state with issue number
jq ".meta.github_issue = $SPEC_ISSUE" .claude/spec-state.json > tmp.json && mv tmp.json .claude/spec-state.json
```

3. **Create initial ADRs if needed**:
```bash
# For each architectural decision captured during the interview
echo "Creating Architecture Decision Records..."
# ADR-001-technology-stack.md
# ADR-002-data-persistence.md
# etc.
```

## SRS Markdown Structure

```markdown
# Software Requirements Specification: [Project Name]

**Version:** 1.0  
**Date:** [Date]  
**GitHub Issue:** #[Number]  
**Approvers:** [List]

## 1. Introduction & Vision
[Vision statement and executive summary]

## 2. Business Objectives & Success Metrics
[Numbered list with measurable KPIs]

## 3. Stakeholders & Scope
### 3.1 Stakeholders
[Table of stakeholders with roles and responsibilities]

### 3.2 In Scope
[Bulleted list of capabilities]

### 3.3 Out of Scope
[Explicit exclusions]

## 4. Context & Interfaces
### 4.1 User Personas
[Detailed personas]

### 4.2 System Context
[Operational environment, external systems, dependencies]

## 5. Functional Requirements
[For each FR, include ID, title, EARS statement, rationale, Gherkin scenarios, priority, deliverables]

## 6. Non-Functional Requirements
[For each NFR, include ID, category, statement, metrics, verification method, review criteria]

## 7. Test Strategy
### 7.1 Test Levels
[Unit, integration, E2E with coverage targets]

### 7.2 Performance Benchmarks
[Specific benchmarks to meet]

### 7.3 Test Data Requirements
[Data needed for testing]

## 8. Work Breakdown Structure
### 8.1 Major Components
[List of components/modules]

### 8.2 Implementation Phases
[Suggested phases with dependencies]

### 8.3 Effort Distribution
[MoSCoW percentages]

## 9. Data Model & Policies
[Entities, schemas, retention, privacy]

## 10. Constraints
[Business, technical, regulatory]

## 11. Risks & Mitigations
[Risk register with mitigations]

## 12. Review Criteria
### 12.1 Definition of Done
[Project-wide DoD]

### 12.2 PR Review Checklist
[Standard review items]

## 13. Prioritization Summary
[MoSCoW table with effort estimates]

## 14. Traceability Matrix
[Requirements to objectives mapping]

## 15. Glossary
[All terms and acronyms]

## 16. Appendices
### A. Assumptions
### B. Architectural Decisions
### C. References

## Next Steps
1. Run `/plan_from_spec` to create detailed task breakdown
2. Review generated plan in `.claude/plan.md`
3. Begin implementation with `/implement_issue [task-number]`
4. Use `/pr_review` for comprehensive reviews against this spec
```

## Start

Introduce the process in one paragraph, then ask the first kickoff question:

"I'll guide you through creating a comprehensive Software Requirements Specification that will serve as the foundation for your entire development workflow. The spec will be saved to `.claude/spec.md` and integrated with GitHub issues for tracking. Let's begin:

**Question 1:** Give me a one-sentence vision and your top 3 measurable business objectives (each with a metric + target + timeframe)."