# Development Workflow Commands

Commands for software development from requirements through implementation.

## Quick Start

Starting a new project:
```bash
/spec                  # Define requirements interactively
/plan/create          # Generate task breakdown from spec
/plan                 # Resolve questions, analyze tasks (can stop/restart anytime)
/implement [issue#]   # Implement a task with TDD (don't need full plan)
```

Continuing work:
```bash
/plan                 # Finds next question or task automatically
/implement [issue#]   # Work on any analyzed task
/review [PR#]         # Review code quality
```

## Commands

### Planning
- **`/spec`** - Interactive requirements specification
- **`/plan/create`** - Generate initial task breakdown with GitHub issues
- **`/plan`** - Interactive loop for questions and task analysis
  - Presents technical questions for decisions
  - Analyzes tasks to identify blockers and decompose large work
  - Fully resumable - stop anytime, continues where left off
- **`/plan/complete`** - Freeze plan at v1.0 (optional)

### Implementation
- **`/implement [issue#]`** - TDD implementation
  - Red-Green-Refactor cycle enforcement
  - Automatic branch creation and PR drafting
  - Commit size limits for reviewability
- **`/review [PR#]`** - Multi-dimensional code analysis
  - Security, performance, maintainability checks
  - Generates specific recommendations
- **`/respond [PR#]`** - Handle review feedback systematically
- **`/walkthrough [PR#]`** - Educational code tour with progressive disclosure

## Common Workflows

### Starting a New Feature
```bash
/spec                    # Define what you're building
/plan/create            # Break it into tasks
/plan                   # Answer a few questions, analyze some tasks
# Stop when you have enough to start
/implement [issue#]     # Start coding analyzed tasks
```

### Continuing Planning
```bash
/plan                   # Automatically finds next item needing attention
# Ctrl+C to stop anytime
# WARNING: Don't stop when a Task(###) is running, or you may end up with an inconsistent state that's hard to recover from.
/plan                   # Resume later - picks up where you left off
```

### Parallel Work
- Planning and implementation can happen simultaneously
- Start implementing as soon as you have analyzed tasks
- Continue planning in another terminal/session
- No need to wait for complete analysis

### Handling Blockers
```bash
/plan                   # Questions appear as they're discovered
# Answer the question
# Task automatically unblocks and becomes ready for analysis
```

## What Gets Created

```
.claude/
├── spec.md                    # Requirements specification
├── spec-state.json           # Structured spec data
├── plan.md                   # Task breakdown (T-XXX tasks)
├── questions.json            # Technical decisions (Q-XXX questions)
├── ADRs/                     # Architecture Decision Records
│   ├── ADR-001-*.md         # Decisions from answered questions
│   └── ADR-002-*.md
└── sessions/                 # Audit trail
    ├── analyze-T-XXX-*.json  # Task analysis sessions
    └── answer-Q-XXX-*.json   # Question resolution sessions

# During implementation
.review_analysis.md           # Review findings
.review_response.md          # Response documentation
```

## Task and Question Flow

1. **Tasks** start as `ready` → become `blocked` (if questions found) or `analyzed` (if clear)
2. **Questions** start as `open` → become `answered` when resolved
3. **Blocked tasks** become `ready` again when their questions are answered
4. The `/plan` command automatically handles this flow

## Troubleshooting

### Spec too business oriented?
It defaults this way because it mimics best practices for extracting a usable specification from a client, but, just be honest; Claude is smart enough to adjust and it will still work. You don't need to conform your answers to the questions to get a good result.

### Planning stopped mid-way?
Just run `/plan` again - it resumes automatically by finding the next item.

### Want to implement before planning completes?
Go ahead - implement any analyzed tasks. Planning doesn't need to be complete.

### Need to see what's left to plan?
Check `.claude/plan.md` for task statuses - `ready` tasks need analysis.

### Session interrupted?
Everything is saved in files. Just restart the command and it will find the correcct context.

## Prerequisites

### Required Tools
```bash
gh --version     # GitHub CLI for issues and PRs
git --version    # Version control
jq --version     # JSON processing for questions/decisions
npm test         # Or your test runner (pytest, go test, cargo test)
```

### First Time Setup
```bash
gh auth login    # Authenticate with GitHub
gh extension install mintoolkit/gh-sub-issue  # For task hierarchy
```

## Tips

- **Start small** - You don't need complete requirements to begin
- **Implement early** - Start coding as soon as you have a few analyzed tasks
- **Trust the loop** - `/plan` always finds the next important item
- **Answer questions promptly** - They unblock the most work
- **Review session files** - Complete audit trail in `.claude/sessions/`
- **Claude Attention** - Claude gets lazy with long work sessions. Stop, clear, and restart planning when you see this.

## Implementation Standards

### TDD Cycle (enforced by `/implement`)
1. **Red** - Write failing test, verify it fails, commit test
2. **Green** - Write minimal code to pass, commit implementation
3. **Refactor** - Clean up without changing behavior, commit refactor

### Commit Limits
- ≤200 lines of code per commit
- ≤5 files per commit
- Automatic enforcement with clear messages

### Test Requirements
- Tests must be deterministic (no real network/filesystem/time)
- Tests must be isolated (proper mocks/stubs)
- Tests must fail before implementation (Red phase)

## GitHub Integration

- **Issues** - Created automatically from tasks (T-XXX)
- **Sub-issues** - Linked to show task decomposition
- **PRs** - Draft created early with acceptance criteria
- **Labels** - 'blocked' added/removed automatically
- **Comments** - Architecture decisions posted when questions answered
