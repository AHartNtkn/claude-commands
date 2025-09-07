# Development Workflow Commands

A comprehensive set of Claude Code slash commands that implement a complete software development lifecycle, from requirements specification through implementation, review, and maintenance. These commands emphasize quality, traceability, and rigorous engineering practices.

## Overview

This workflow system transforms software development into a systematic, traceable process:

1. **`/spec`** - Create comprehensive Software Requirements Specifications
2. **`/plan`** - Generate detailed work breakdown structures with GitHub integration
3. **`/implement`** - Execute strict Test-Driven Development with automated PR creation
4. **`/review`** - Perform multi-dimensional code quality analysis
5. **`/respond`** - Systematically handle PR review feedback
6. **`/walkthrough`** - Provide educational guided tours of code changes

## Prerequisites

### Required Tools
- **GitHub CLI** (`gh`) - For issue and PR management
- **Git** - For version control operations
- **Testing Framework** - One of: npm/Jest, pytest, Go test, cargo test

### Verification Commands
```bash
gh --version && gh auth status  # Verify GitHub CLI
git --version                   # Verify Git
npm test                       # Verify test runner (or pytest/go test/cargo test)
```

## Complete Development Workflow

### Phase 1: Requirements Specification
```bash
/spec MyProject
```
**What it does:**
- Conducts interactive requirements interview following ISO 29148 and NASA SE standards
- Uses EARS patterns for functional requirements with Gherkin acceptance criteria
- Applies FURPS+ taxonomy for non-functional requirements
- Implements MoSCoW prioritization with effort validation
- Auto-generates review criteria and glossary from interview content
- Creates parent GitHub issue and saves complete SRS to `.claude/spec.md`

**Quality Gates:**
- All requirements have unique IDs (FR-XXX, NFR-XXX) and measurable targets
- 100% traceability to business objectives
- Must-have requirements ≤60% of estimated effort
- Every functional requirement has Gherkin scenarios
- Every non-functional requirement has verification method

### Phase 2: Work Breakdown Planning
```bash
/plan
```
**Prerequisites:** Requires existing `.claude/spec.md`

**What it does:**
- Extracts scope and deliverables from specification
- Creates hierarchical work breakdown structure following 100% rule
- Generates stable task IDs (T-XXX format) with GitHub issue creation
- Establishes requirement-to-task traceability matrix
- Manages dependency relationships using sub-issue linking
- Interactive refinement through targeted questions

**Outputs:**
- `.claude/plan.md` - Versioned planning document
- GitHub issues for each task with sub-issue relationships
- Traceability matrix ensuring complete requirement coverage

### Phase 3: Test-Driven Implementation
```bash
/implement [ISSUE_NUMBER]
```
**What it does:**
- Implements GitHub issues using strict Red-Green-Refactor TDD methodology
- Creates feature branch with automated naming
- Enforces small commits (≤200 LOC, ≤5 files)
- Maintains deterministic, hermetic testing practices
- Creates draft PR with acceptance criteria tracking
- Performs baseline and final test validation with automatic rebasing

**TDD Workflow:**
1. **RED:** Write minimal failing test, verify failure, commit test only
2. **GREEN:** Implement minimal production code to pass, commit implementation
3. **REFACTOR:** Clean up without changing behavior, commit refactor
4. **REPEAT:** Until all acceptance criteria are met

**Quality Controls:**
- Automatic test framework detection (npm/pytest/go/cargo)
- Pre-commit hook integration for formatting/linting
- Continuous integration with main branch
- Clean working tree enforcement

### Phase 4: Comprehensive Review
```bash
/review [PR_NUMBER]
```
**What it does:**
- Performs algorithmic code quality analysis using specialized sub-agents
- Executes explicit security vulnerability checks (OWASP Top 10)
- Analyzes performance patterns, complexity metrics, and SOLID principles
- Cross-references changes against project specifications and standards
- Generates actionable recommendations with specific code fixes

**Review Dimensions:**
- **Correctness:** Error handling, resource management, concurrency
- **Security:** Injection prevention, access control, cryptographic issues
- **Performance:** Database patterns, algorithm complexity, resource usage
- **Maintainability:** Complexity metrics, SOLID principles, DRY violations
- **Testing:** Coverage analysis, test quality assessment

### Phase 5: Systematic Response Management
```bash
/respond [PR_NUMBER]
```
**What it does:**
- Categorizes review feedback by priority (Critical/High/Medium/Low)
- Addresses critical and high-priority issues directly in the PR
- Creates detailed GitHub issues for deferred medium-priority items
- Validates feedback against project standards and specifications
- Documents all decisions and maintains response traceability

**Response Categories:**
- **MUST FIX NOW:** Blocks merge, addressed immediately
- **SHOULD FIX NOW:** High priority, fixed before merge
- **CREATE FOLLOW-UP ISSUE:** Medium priority, tracked separately
- **OPTIONAL/FUTURE:** Low priority suggestions
- **DISPUTED:** Clarified with architectural reasoning

### Phase 6: Educational Understanding
```bash
/walkthrough [PR_NUMBER]
```
**What it does:**
- Provides guided, educational exploration of PR changes
- Combines comprehensive review findings with pedagogical explanations
- Uses progressive disclosure with multiple depth levels
- Organizes changes into semantic chunks for optimal comprehension
- Maintains interactive state for session resumption

**Navigation Features:**
- Executive, developer, and deep-dive explanation levels
- Semantic chunking respecting cognitive load limits
- Interactive navigation (continue, back, jump, search)
- Contextual review integration showing both fixes and new issues
- Persistent session state for interrupted walkthroughs

## File Structure and Artifacts

The workflow creates and maintains several key files:

```
.claude/
├── spec.md                    # Complete SRS document
├── spec-state.json           # Structured specification data
├── spec-v1.0.md             # Versioned specification backup
├── plan.md                   # Work breakdown structure
├── .walkthrough-state.json   # Interactive session state
├── .review-findings.json     # Comprehensive review results
└── ADRs/                     # Architecture Decision Records
    ├── ADR-001-*.md
    └── ADR-002-*.md

# Generated during workflow
.review_analysis.md          # Categorized review feedback
.review_response.md         # Response documentation
.gh_pr_body.md             # PR template with acceptance criteria
.gh_context.md             # Implementation context summary
```

## GitHub Integration

### Issue Management
- **Parent Issues:** Created from specifications for epic tracking
- **Task Issues:** Generated from work breakdown with T-XXX identifiers
- **Sub-Issue Relationships:** Maintained using `gh sub-issue` for hierarchy
- **Follow-up Issues:** Created from deferred review feedback

### Pull Request Lifecycle
- **Draft PRs:** Created early with acceptance criteria checklists
- **Review Integration:** Automated posting of comprehensive review reports
- **Response Tracking:** Documented feedback handling with issue links
- **Merge Policies:** Enforced completion of acceptance criteria

## Quality Standards

### Test-Driven Development
- **Red-Green-Refactor:** Strict adherence to TDD cycles
- **Deterministic Tests:** No real network/time/filesystem dependencies
- **Hermetic Testing:** Isolated tests using mocks/fakes/stubs
- **Small Commits:** Atomic changes with clear intent

### Code Quality
- **Complexity Limits:** Cyclomatic complexity ≤10, functions ≤20 lines
- **SOLID Principles:** Enforced through automated analysis
- **Security Standards:** OWASP Top 10 vulnerability prevention
- **Performance Patterns:** Database optimization, algorithm efficiency

### Documentation Standards
- **Requirements Traceability:** Every implementation traced to requirements
- **Architectural Decisions:** Documented in ADR format
- **Review Criteria:** Auto-generated from specifications
- **Glossary Management:** Automated term extraction and definition

## Best Practices

### Getting Started
1. Start every project with `/spec` to establish clear requirements
2. Use `/plan` to create structured work breakdown before implementation
3. Implement one issue at a time using `/implement` for TDD discipline
4. Use `/review` for comprehensive quality analysis on every PR
5. Apply `/respond` systematically to handle all review feedback
6. Use `/walkthrough` for knowledge transfer and code education

### Workflow Discipline
- **Never skip specifications** - All implementation should trace to documented requirements
- **Maintain small PRs** - Each PR should address one coherent issue
- **Address all feedback** - Use systematic categorization and tracking
- **Keep tests green** - Continuous validation with automatic rebasing
- **Document decisions** - Use ADRs for architectural choices

### Quality Gates
- **Specification:** All requirements have IDs, priorities, and acceptance criteria
- **Planning:** Complete traceability matrix, no orphaned requirements
- **Implementation:** All tests pass, acceptance criteria met
- **Review:** All critical and high-priority issues resolved
- **Response:** All feedback categorized, deferred items have issues

## Advanced Features

### Specialized Sub-Agents
The system uses specialized AI agents for focused analysis:
- **File Analyzer:** Summarizes verbose outputs and logs
- **Code Analyzer:** Traces logic flow and identifies vulnerabilities
- **Test Runner:** Executes and analyzes test results
- **Review Agents:** Perform domain-specific quality analysis

### Progressive Disclosure
The walkthrough system adapts to user needs:
- **Executive Level:** Business impact focus for stakeholders
- **Developer Level:** Balanced technical explanation
- **Deep Dive Level:** Line-by-line analysis for learning

### State Management
Persistent state enables workflow resumption:
- **Specification State:** Structured JSON with all requirement data
- **Planning State:** Version-controlled plan with change history
- **Walkthrough State:** Session progress for interrupted learning
- **Review State:** Comprehensive findings for integration

## Integration with Project Standards

### Specification Integration
- Requirements checked against project constraints and standards
- Review criteria auto-generated from specification NFRs
- Acceptance criteria integrated into PR templates

### Architecture Integration
- ADR (Architecture Decision Record) creation and maintenance
- Consistency checking against existing architectural decisions
- Cross-cutting concern analysis across all changed files

### Testing Integration
- Framework auto-detection (npm/pytest/go/cargo)
- Coverage target enforcement from specification
- Test strategy validation against implementation

This workflow system transforms ad-hoc development into a systematic, quality-focused process that maintains complete traceability from business requirements through implementation and maintenance.