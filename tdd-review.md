---
allowed-tools: Task, Glob, Grep, Read
description: Review test suite as a TDD specification, auditing for completeness, correctness, and API design quality
---

Review the test suite as a specification for TDD development. The codebase should have a stubbed API with a comprehensive test suite that specifies expected behavior before implementation.

## Execution Steps

1. **Discovery Phase** - Launch 2 parallel Haiku agents:

   **Agent A: File Discovery**
   - Find all test files in the repository
   - Find the stubbed API/source files
   - Return the file lists and a brief summary of the test structure

   **Agent B: Correctness Source Discovery**
   - Find all sources that define what "correct" means for this project:
     - Whitepapers or academic papers the implementation is based on
     - Algorithm descriptions or pseudocode
     - Formal grammars, schemas, or protocol definitions
     - Reference implementations or golden outputs
     - Domain standards or RFCs being implemented
     - README/docs describing the intended semantics
     - Any other authoritative source of truth
   - Return: List of correctness sources with a summary of what each defines
   - If no correctness sources are found, flag this - the review can still check internal consistency but cannot verify the tests capture the right behavior

2. **Parallel Deep Analysis** - Launch 5 parallel Sonnet agents. Each agent receives the correctness sources from Agent B. The test suite IS the specification for the API; these agents verify the tests correctly and completely capture the intended behavior:

   **Agent #1: Completeness Audit**
   - Compare correctness sources against the test suite: are all described behaviors captured in tests?
   - Are there any API components in the stub that lack corresponding tests?
   - Are there behaviors described in the correctness sources that have no corresponding API or tests?
   - Are edge cases, error conditions, and boundary conditions from the correctness sources tested?
   - Return: List of coverage gaps with severity (critical/high/medium/low), citing which correctness source requirement is unspecified

   **Agent #2: Correctness - Strictness Analysis**
   - Are any tests overly strict, testing implementation details rather than observable behavior?
   - Are any tests enforcing formal aspects not required by the correctness sources (e.g., exact error messages, internal state, ordering that doesn't matter)?
   - Are any tests testing incidental behavior that could validly change?
   - Return: List of overly strict tests with specific concerns

   **Agent #3: Correctness - Weakness Analysis**
   - Are any tests weaker than what the correctness sources require?
   - Are there behaviors in the correctness sources that need additional test cases?
   - Are there assertions that are too permissive to catch violations?
   - Are there missing negative tests (testing what the correctness sources say should NOT happen)?
   - Return: List of weak tests with suggested strengthening, citing the relevant correctness source

   **Agent #4: Vision Consistency Audit**
   - Do all tests present a coherent, unified vision for the API?
   - Are there tests with mutually inconsistent expectations?
   - Are there tests that contradict what the correctness sources describe?
   - Are there conflicting assumptions about behavior across different test files?
   - Is terminology consistent across tests and with the correctness sources?
   - Return: List of inconsistencies, distinguishing test-vs-test conflicts from test-vs-correctness-source conflicts

   **Agent #5: API Design Quality**
   - Does the API design (as revealed by the tests) cleanly capture the correctness sources?
   - Are there multiple representations of the same concept when there should be one?
   - Is the API surface minimal or bloated beyond what's needed?
   - Are there naming inconsistencies or confusing abstractions?
   - Does the API follow the principle of least surprise for the domain?
   - Return: List of design issues with suggested improvements

3. **Confidence Scoring** - For each issue found in #2, launch a parallel Haiku agent that scores confidence (0-100):
   - 0: False positive - not actually an issue upon closer inspection
   - 25: Possible issue - might be intentional design choice
   - 50: Likely issue - worth discussing but not blocking
   - 75: Definite issue - should be addressed before implementation
   - 100: Critical issue - will cause problems if not fixed

4. **Filter and Report** - Filter out issues with confidence < 60. Compile remaining issues into the final report.

## Final Report Format

```markdown
# TDD Specification Review

## Correctness Sources
[List the documents/sources used to judge correctness, with brief description of each]

## Summary
- Correctness sources: N
- Test files reviewed: N
- API files reviewed: N
- Issues found: N (N critical, N high, N medium, N low)

## Critical Issues (Must Fix Before Implementation)

### Completeness Gaps
[List coverage gaps that will leave behavior unspecified]

### Inconsistent Vision
[List tests that contradict each other]

## High Priority Issues (Should Fix)

### Overly Strict Tests
[Tests that will break on valid implementation changes]

### Weak Tests
[Tests that won't catch bugs they should]

### API Design Problems
[Design issues visible through the test structure]

## Medium Priority Suggestions

[Issues worth considering but not blocking]

## Detailed Findings

### By File
[Specific issues with file:line references]

### Cross-Cutting Patterns
[Issues that appear across multiple files]
```

## Notes

- Focus on the tests as specification, not as code quality
- The goal is to ensure the test suite correctly and completely specifies the API before implementation begins
- Prefer false negatives over false positives - only flag issues you're confident about
- Consider that some apparent inconsistencies may be intentional design choices
- API design feedback should be constructive, suggesting alternatives where possible
