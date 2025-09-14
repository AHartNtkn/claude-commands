---
allowed-tools: Task, Bash(gh:*), WebFetch, Bash(find:*), Bash(cargo:*), Bash([:*), Bash(echo:*), Bash(grep:*), Bash(jq:*), Bash(bash -c:*), Bash(~/.claude/commands/dev/filter-diff.sh:*)
argument-hint: [pr-number]
description: Comprehensive PR review with explicit algorithmic checks for code quality, security, performance, and maintainability
---

## Initial Context
- PR metadata: !`gh pr view $ARGUMENTS --json number,title,body,url,headRefName,baseRefName,additions,deletions,changedFiles`
- Changed files (excluding sessions): !`bash -c "gh pr diff $ARGUMENTS --name-only | grep -v '\.claude/sessions/'"`
- Spec exists: !`[ -f .claude/spec.md ] && echo "true" || echo "false"`
- Review criteria from spec: !`[ -f .claude/spec-state.json ] && jq ".review_criteria" .claude/spec-state.json || echo "{}"`
- Plan tasks (if available): !`[ -f .claude/plan.md ] && grep -E "T-[0-9]+" .claude/plan.md || echo ""`

## Full PR Diff (excluding session files)
!`~/.claude/commands/dev/filter-diff.sh $ARGUMENTS`

## Comprehensive Review Strategy

This command will use the Task tool to delegate review to multiple specialized sub-agents, each focusing on specific aspects of code quality. Each sub-agent receives explicit algorithmic checks to perform.

### Phase 1: File-by-File Deep Analysis

For each changed file or group of related files (max 3), launch a sub-agent with these EXPLICIT checks:

#### CORRECTNESS & ROBUSTNESS CHECKS
1. **Error Handling Patterns**
   - **Performance-critical paths (if identified in project docs):**
     - Flag expensive error handling in tight loops
     - Flag error propagation that could cause performance issues
     - Suggest: validate at boundaries, handle errors outside hot paths
   - **Library vs Application code:**
     - Flag inconsistent error handling strategies
     - Flag string errors instead of typed errors in libraries
     - Flag missing error context in application code
   - **General patterns:**
     - Flag any I/O operations (file, network, database) without error handling
     - Flag subprocess calls without error checking
     - Flag array/dict access without bounds checking
     - Flag division operations without zero checks
     - Flag unwrap() or expect() in production code (prefer ? or proper handling)
   - Suggest: consistent error handling appropriate to code context

2. **Resource Management**
   - Flag file/socket/connection opens without corresponding close in finally/defer/using blocks
   - Flag manual memory allocation without RAII/smart pointers (C/C++)
   - Flag event subscriptions without unsubscription logic
   - Flag locks/mutexes without unlock in finally blocks
   - Suggest: use context managers, RAII, try-with-resources

3. **Concurrency Issues**
   - Flag shared state access without synchronization
   - Flag async operations without await
   - Flag race conditions in check-then-act patterns
   - Flag deadlock potential in nested locks
   - Suggest: use atomic operations, proper synchronization primitives

#### SECURITY VULNERABILITY CHECKS (OWASP Top 10)
1. **Injection Prevention**
   - Flag SQL queries with string concatenation/interpolation
   - Flag shell commands with user input (subprocess with shell=True)
   - Flag eval/exec with any external input
   - Flag regex construction from user input
   - Suggest: use parameterized queries, argument arrays, safe parsers

2. **Access Control**
   - Flag missing authentication checks on sensitive operations
   - Flag authorization checks after resource access
   - Flag IDOR vulnerabilities (direct object references)
   - Flag missing CSRF tokens on state-changing operations
   - Suggest: check auth first, use UUIDs, validate ownership

3. **Cryptographic Issues**
   - Flag hardcoded secrets/keys/passwords
   - Flag use of weak algorithms (MD5, SHA1, DES)
   - Flag random.random() for security purposes (should use secrets/OS RNG)
   - Flag missing HTTPS/TLS for sensitive data
   - Suggest: use environment variables, strong algorithms, cryptographic RNG

4. **Input Validation**
   - Flag missing input sanitization on user data
   - Flag missing output encoding for HTML/JS/SQL contexts
   - Flag file upload without type/size validation
   - Flag deserialization of untrusted data (pickle, eval)
   - Suggest: whitelist validation, context-aware encoding

#### PERFORMANCE & SCALABILITY CHECKS
1. **Database Anti-patterns**
   - Flag N+1 query patterns (loop with DB query inside)
   - Flag SELECT * usage
   - Flag missing indexes on WHERE/JOIN columns
   - Flag queries without LIMIT on large tables
   - Flag LIKE queries with leading wildcards (%term)
   - Suggest: eager loading, specific columns, add indexes

2. **Memory & Resource Usage**
   - Flag unbounded collections/caches
   - Flag large objects in loops without clearing
   - Flag recursive functions without depth limits
   - Flag string concatenation in loops (use StringBuilder/join)
   - Flag unnecessary object copies/clones
   - Suggest: use streaming, pagination, object pools

3. **Algorithm Complexity**
   - Flag nested loops over same collection (O(n²))
   - Flag linear search where hash/tree could work (O(n) vs O(1)/O(log n))
   - Flag repeated computations without memoization
   - Flag sorting when only min/max needed
   - Suggest: use appropriate data structures, cache results

#### CODE QUALITY & MAINTAINABILITY CHECKS
1. **Complexity Metrics**
   - Flag functions with cyclomatic complexity > 10
   - Flag functions with > 20 lines of code
   - Flag classes with > 7 methods (high cohesion)
   - Flag methods with > 5 parameters
   - Flag nesting depth > 4 levels
   - Suggest: extract methods, use composition, simplify logic

2. **SOLID Principles Violations**
   - Flag classes with multiple responsibilities (SRP)
   - Flag modifications to existing classes for new features (OCP)
   - Flag LSP violations in inheritance hierarchies
   - Flag fat interfaces with unused methods (ISP)
   - Flag high-level modules depending on low-level details (DIP)
   - Suggest: split classes, use interfaces, dependency injection

3. **DRY/KISS/YAGNI Violations**
   - Flag duplicated code blocks > 3 lines
   - Flag copy-pasted functions with minor variations
   - Flag over-engineered solutions for simple problems
   - Flag unused parameters/variables/imports
   - Flag future-proofing without current requirements
   - Suggest: extract common code, simplify, remove unused

4. **Magic Numbers & Literals**
   - Flag numeric literals other than -1, 0, 1 not in constants
   - Flag string literals used multiple times
   - Flag hardcoded URLs/paths/configurations
   - Flag array indices without named constants
   - Suggest: extract to named constants with descriptive names

5. **Naming & Readability**
   - Flag single-letter variables (except loop counters)
   - Flag misleading names (opposite of behavior)
   - Flag abbreviations without context
   - Flag inconsistent naming conventions
   - Flag missing/outdated comments on complex logic
   - Suggest: descriptive names, consistent style, clarify intent

#### TESTING & VALIDATION CHECKS
1. **Test Coverage**
   - Flag new functions without corresponding tests
   - Flag modified logic without updated tests
   - Flag error paths without test cases
   - Flag boundary conditions without tests
   - Suggest: add unit tests, integration tests, edge cases

2. **Test Quality**
   - Flag tests without assertions
   - Flag tests with hardcoded dates/times
   - Flag tests dependent on execution order
   - Flag tests using production resources
   - Suggest: add assertions, use mocks, isolate tests

#### DOMAIN-SPECIFIC CHECKS
1. **Frontend/UI**
   - Flag missing accessibility attributes (alt, aria-labels)
   - Flag inline styles instead of CSS classes
   - Flag missing error boundaries (React)
   - Flag direct DOM manipulation in frameworks
   - Flag missing loading/error states

2. **API/Backend**
   - Flag missing rate limiting
   - Flag missing pagination on list endpoints
   - Flag missing API versioning
   - Flag synchronous operations that should be async
   - Flag missing timeout configurations

3. **Infrastructure/DevOps**
   - Flag hardcoded environment-specific values
   - Flag missing health checks
   - Flag missing graceful shutdown handlers
   - Flag unbounded queue/buffer sizes
   - Flag missing circuit breakers for external services

### Phase 2: Cross-Cutting Concern Analysis

Launch specialized agents to analyze patterns across all files:

#### ARCHITECTURAL COHERENCE AGENT
- Check for layering violations (UI calling DB directly)
- Check for circular dependencies between modules
- Check for inconsistent patterns across similar components
- Check for proper separation of concerns
- Verify adherence to project's architectural decisions (ADRs)

#### SECURITY AUDIT AGENT
- Scan for secrets/tokens across all files
- Check for consistent authentication/authorization
- Verify all external inputs are validated
- Check for secure defaults
- Verify security headers and configurations

#### PERFORMANCE ANALYSIS AGENT
- Identify repeated expensive operations
- Check for proper caching strategies
- Verify async/await usage patterns
- Check for database query optimization
- Identify potential bottlenecks

#### DEPENDENCY ANALYSIS AGENT
- Check for outdated dependencies with known vulnerabilities
- Verify license compatibility
- Check for unnecessary dependencies
- Verify dependency version pinning
- Check for circular dependencies

### Phase 3: Aggregation and Reporting

Collect all findings from sub-agents and produce:

## Final Report Structure

```markdown
# Comprehensive PR Review: [Title] (#[Number])

## Executive Summary
- Total files reviewed: X
- Total lines changed: +Y -Z
- Critical issues found: N
- Risk level: [LOW/MEDIUM/HIGH/CRITICAL]
- Spec compliance: [PASS/FAIL with requirement IDs]
- Test coverage meets spec: [YES/NO - target vs actual]

## Critical Issues (Must Fix)
[Issues that block merge, grouped by type]

## High Priority Issues (Should Fix)
[Issues that should be addressed before merge]

## Medium Priority Issues (Consider Fixing)
[Issues that can be addressed in follow-up PRs]

## Low Priority Suggestions
[Nice-to-have improvements]

## Security Analysis
- OWASP Top 10 coverage: [checklist]
- Secrets/credentials: [PASS/FAIL]
- Input validation: [status]

## Performance Analysis
- Database query patterns: [status]
- Algorithm complexity: [findings]
- Resource management: [status]

## Code Quality Metrics
- Cyclomatic complexity: [max/avg]
- Test coverage delta: [+X%]
- Code duplication: [X% duplicated]
- SOLID compliance: [findings]

## Automated Fixes Available
[Patches that can be automatically applied]

## Specific File Reviews
[Detailed findings per file with line numbers]

## Recommendations
1. [Prioritized action items]
2. [With specific fixes]
3. [And responsible patterns to follow]
```

## Sub-Agent Prompt Template

Each sub-agent receives:
```
Review the following code diff for file(s): [files]
PR Context: [title, description, acceptance criteria]

FIRST: Check for project-specific docs and requirements:
- .claude/spec.md - Verify implementation matches functional/non-functional requirements
- .claude/spec-state.json - Apply project-specific review criteria
- .claude/plan.md - Verify task completion and dependencies
- .claude/ADRs/*.md - Check architectural decisions
- ARCHITECTURE.md, CONTRIBUTING.md - Apply project conventions
Incorporate all project-specific constraints and patterns into your review.

Then perform ALL of these checks and report findings with specific line numbers:

[Include all relevant checks from above based on file type]

For each issue found, provide:
1. File and line number
2. Issue type and severity
3. Specific evidence (code snippet)
4. Concrete fix with code example
5. Risk score (1-10)

Output format:
- Group by severity (Critical/High/Medium/Low)
- Include suggested patches where safe
- Note patterns that appear multiple times
```

## Execution Instructions

1. Assess the PR scope and create file groupings
2. Launch parallel sub-agents for each file group with appropriate checks
3. Launch cross-cutting analysis agents
4. Wait for all agents to complete
5. Aggregate findings and generate comprehensive report
6. Present actionable recommendations with specific fixes
7. Post your final review as a comment under the PR you are reviewing

This approach ensures:
- **Complete coverage**: Every line is reviewed
- **Explicit checks**: Nothing left to agent interpretation
- **Actionable output**: Specific fixes provided
- **No truncation**: Sub-agents handle manageable chunks
- **Comprehensive analysis**: All aspects of code quality covered
