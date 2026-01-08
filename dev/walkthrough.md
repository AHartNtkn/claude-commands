---
allowed-tools: Task, Bash(gh:*), WebFetch, Read, Grep, Glob, Edit, Write, Bash([:*), Bash(echo:*), Bash(grep:*), Bash(jq:*), Bash(cat:*), Bash(bash -c:*), Bash(~/.claude/commands/dev/filter-diff.sh:*)
argument-hint: [pr-number]
description: Interactive PR walkthrough with comprehensive review and guided explanation using progressive disclosure
---

## Initial Context
- PR metadata: !`gh pr view $ARGUMENTS --json number,title,body,url,headRefName,baseRefName,additions,deletions,changedFiles,files`
- Changed files (excluding sessions): !`bash -c "gh pr diff $ARGUMENTS --name-only | grep -v '\.claude/sessions/'"`
- Spec exists: !`[ -f .claude/spec.md ] && echo "true" || echo "false"`
- Review criteria: !`[ -f .claude/spec-state.json ] && jq ".review_criteria" .claude/spec-state.json || echo "{}"`
- Commit messages: !`bash -c "gh pr view $ARGUMENTS --json commits | jq -r '.commits[].messageHeadline'"`
- Previous walkthrough state: !`[ -f .claude/.walkthrough-state.json ] && cat .claude/.walkthrough-state.json || echo "{}"`

## Full PR Diff (excluding session files)
!`~/.claude/commands/dev/filter-diff.sh $ARGUMENTS`

## Interactive PR Walkthrough Protocol

This command provides an interactive, educational walkthrough of all PR changes, combining comprehensive review with progressive disclosure and pedagogical best practices.

### Phase 1: Comprehensive Critical Review

First, use the Task tool to launch specialized review agents that perform TWO types of analysis:

**A. Context Analysis (What the PR Fixes):**
- Identify issues in the original code that this PR addresses
- Understand the problems being solved
- Document the improvements being made

**B. Critical Review (Problems WITH the PR):**
- Find bugs and logic errors INTRODUCED by this PR
- Identify security vulnerabilities CREATED by these changes
- Spot performance problems ADDED by this implementation
- Catch documentation errors (typos, grammar, unclear explanations)
- Find code quality issues (poor naming, high complexity, duplication)
- Identify missing tests for NEW functionality
- Detect architecture violations and poor design choices

**IMPORTANT:** Review agents must be explicitly instructed to:
1. NOT assume the PR is correct or well-implemented
2. Actively look for flaws, no matter how minor
3. Check every line for issues, including comments and documentation
4. Apply the same rigorous standards from review.md
5. Report ALL issues found, from critical bugs to minor typos

**Sub-Agent Prompt Template for Critical Review:**
```
You are reviewing PR #[number]. Your job is to find PROBLEMS WITH THIS PR.

CRITICAL: You must identify issues IN the PR itself, not just explain what it does.
Look for:
- Bugs introduced by the changes
- Typos and grammar errors in comments/docs
- Performance problems created
- Security vulnerabilities added
- Missing error handling
- Inadequate test coverage
- Poor variable/function naming
- Code that doesn't follow project conventions
- Any other flaws, no matter how minor

For EVERY file and EVERY change:
1. First understand what issue it's trying to fix (context)
2. Then critically examine if the fix is correct and complete
3. Look for side effects and edge cases not handled
4. Check if it introduces new problems
5. Verify documentation accuracy (spelling, grammar, clarity)

DO NOT assume the code is correct. DO NOT skip over "minor" issues like typos.
Report EVERYTHING wrong, from critical bugs to style violations.

Review the following changes and report ALL issues found:
[diff content]
```

Example review findings structure:
```json
{
  "issues_fixed": [
    {
      "id": "fixed-001",
      "description": "SQL injection vulnerability in user input handling",
      "original_location": "src/db.js:45-50"
    }
  ],
  "issues_introduced": [
    {
      "id": "new-issue-001",
      "severity": "critical",
      "type": "bug",
      "file": "src/auth.js",
      "line": 45,
      "description": "Null pointer exception when user.email is undefined",
      "suggestion": "Add null check before accessing user.email"
    },
    {
      "id": "new-issue-002", 
      "severity": "minor",
      "type": "documentation",
      "file": "README.md",
      "line": 12,
      "description": "Typo: 'recieve' should be 'receive'",
      "suggestion": "Fix spelling error"
    },
    {
      "id": "new-issue-003",
      "severity": "medium",
      "type": "performance",
      "file": "src/api.js",
      "line": 78,
      "description": "N+1 query pattern introduced when fetching user roles",
      "suggestion": "Use eager loading or batch queries"
    }
  ]
}
```

Store raw review findings in `.claude/.review-findings-raw.json` for verification.

### Phase 1B: Issue Verification

**CRITICAL: Verify each surfaced issue before presenting to user.**

For each issue in `issues_introduced`, spawn a dedicated verification agent that:

1. **Reads the actual code** - Not just the diff, but the full file context
2. **Traces the logic** - Follows the code path to verify the issue exists
3. **Checks for mitigations** - Looks for guards, error handling, or other patterns that may address the concern
4. **Renders a verdict** - Marks the issue as `verified`, `false_positive`, or `uncertain`

**Verification Agent Prompt Template:**
```
You are VERIFYING whether a reported issue is real or a false positive.

ISSUE BEING VERIFIED:
- File: {file}
- Line: {line}
- Type: {type}
- Severity: {severity}
- Description: {description}
- Suggestion: {suggestion}

YOUR TASK:
1. Read the FULL file at {file} (not just the diff)
2. Examine the code at line {line} and surrounding context
3. Trace the logic flow to determine if this issue is real
4. Check if there are mitigating factors (guards, validation elsewhere, framework guarantees)
5. Consider if the reviewer may have misunderstood the code

VERDICTS:
- "verified" - The issue is real and should be reported
- "false_positive" - The issue does not actually exist (explain why)
- "uncertain" - Cannot determine; needs human review

RESPOND WITH JSON:
{
  "original_issue_id": "{id}",
  "verdict": "verified|false_positive|uncertain",
  "reasoning": "[Detailed explanation of your analysis]",
  "evidence": "[Specific code snippets or facts that support your verdict]",
  "mitigating_factors": "[Any guards or patterns that address the concern, if any]"
}

BE SKEPTICAL of the original finding. Your job is to DISPROVE false positives, not rubber-stamp findings.
```

**Verification Execution:**

1. Load raw findings from `.claude/.review-findings-raw.json`
2. For each issue in `issues_introduced`:
   - Spawn a verification agent with the template above
   - Collect the verdict
3. Filter results:
   - `verified` issues → Include in final findings
   - `false_positive` issues → Log but exclude from user presentation
   - `uncertain` issues → Include but mark as needing human verification
4. Store verified findings in `.claude/.review-findings.json`

**Verification Summary:**
```json
{
  "total_issues_found": 15,
  "verified_issues": 8,
  "false_positives": 5,
  "uncertain_issues": 2,
  "verification_details": [
    {
      "original_issue_id": "new-issue-001",
      "verdict": "false_positive",
      "reasoning": "The null check exists on line 42, which guards this access path"
    }
  ]
}
```

Store verification summary in `.claude/.verification-summary.json`.

**Parallel Verification:**
- Launch verification agents in parallel for independent issues
- Group issues by file to allow agents to share context
- Limit concurrency to avoid overwhelming the system (max 5 parallel agents)

### Phase 2: Change Organization and Chunking

Analyze the PR diff and organize changes into semantic chunks:

1. **Semantic Grouping Rules:**
   - Group by logical unit (complete functions/methods)
   - Keep class changes together
   - Include relevant context (imports, declarations)
   - Target 100-500 lines per chunk for optimal comprehension
   - Never split mid-function or mid-logical-block

2. **Chunk Hierarchy:**
   ```
   Level 1: PR Overview (what problem does this solve?)
   Level 2: File Groups (related files that work together)
   Level 3: File Changes (what each file accomplishes)
   Level 4: Semantic Chunks (function/class level changes)
   Level 5: Line-by-line details (only when requested)
   ```

3. **Create Chunk Metadata:**
   ```json
   {
     "chunks": [
       {
         "id": "chunk-001",
         "level": 3,
         "file": "src/auth/login.js",
         "lines": "45-120",
         "type": "function",
         "name": "validateCredentials",
         "dependencies": ["chunk-002", "chunk-003"],
         "review_issues": ["sec-001", "perf-002"],
         "complexity": "medium",
         "purpose": "Validates user credentials against database",
         "context_needed": ["Understanding of auth flow", "Database schema"]
       }
     ]
   }
   ```

### Phase 3: Initialize Walkthrough State

Create or update `.claude/.walkthrough-state.json`:
```json
{
  "pr_number": "123",
  "total_chunks": 45,
  "current_chunk": 0,
  "chunks_viewed": [],
  "chunks_skipped": [],
  "depth_level": 3,
  "review_findings_integrated": false,
  "user_questions": [],
  "session_start": "2024-01-15T10:00:00Z"
}
```

### Phase 4: Interactive Walkthrough Execution

#### 4.1 Start with Executive Summary

```markdown
# PR Walkthrough: [Title] (#[Number])

## 🎯 What This PR Accomplishes
[Explain in plain English the problem being solved and the approach taken]

## 📊 Scope of Changes
- Files modified: X
- Lines added: +Y
- Lines removed: -Z
- Test coverage: N%

## ✅ Issues Fixed by This PR
- Security vulnerabilities: [Count]
- Performance problems: [Count]  
- Bugs resolved: [Count]

## ⚠️ Problems Found WITH This PR (Verified)
- Critical issues to fix: [Count]
- Documentation errors: [Count]
- Code quality concerns: [Count]
- Missing test coverage: [Count]

## 🔍 Verification Stats
- Issues initially flagged: [Total from Phase 1]
- Verified as real: [Count]
- Filtered as false positives: [Count]
- Marked uncertain (needs human review): [Count]

## 🗺️ Walkthrough Structure
I'll guide you through [N] semantic chunks organized into:
1. [High-level area 1] - [X chunks]
2. [High-level area 2] - [Y chunks]
3. [High-level area 3] - [Z chunks]

Ready to begin? Type **'continue'** to start with the first area, or **'menu'** for navigation options.
```

#### 4.2 Present Each Chunk Using EiPE Method

For each chunk, structure the explanation as:

```markdown
## 📍 [Chunk X of Y] - [Descriptive Title]
**File:** `path/to/file.js` (lines 45-120)
**Progress:** ▓▓▓▓░░░░░░ 40%

### 🎯 Purpose (Why This Change Exists)
[Explain in plain English why this change was needed, connecting to requirements/user stories]

### 🔄 What Changed
**Before:** [Brief description of previous behavior]
**After:** [Brief description of new behavior]

### 💡 How It Works
[Step-by-step explanation in plain English, avoiding jargon]
1. First, [what happens]
2. Then, [next step]
3. Finally, [outcome]

### 📋 The Code
```language
[Show the actual code diff with + and - indicators]
```

### ✅ What This Fixes
[If this chunk addresses issues from the original code, explain them here]
- **Fixed:** SQL injection vulnerability that existed in previous implementation
- **Improved:** Performance by reducing database calls from O(n) to O(1)

### ⚠️ Problems Found in This Change
[Issues identified WITH this PR's implementation - VERIFIED by dedicated agents]

**✓ Verified Issues:**
🐛 **Critical Bug:** Missing null check on line 47 - will crash if user.email undefined
📝 **Documentation:** Typo in comment line 52: "recieve" should be "receive"
⚡ **Performance:** Introduced N+1 query when fetching related data

**? Uncertain (Needs Human Review):**
🎨 **Code Quality:** Function exceeds 20 lines (currently 35) - consider breaking up
🧪 **Testing Gap:** No test coverage for error handling path

💡 **Suggestion:** Add input validation before processing user data

### 🔗 Connections
- **Depends on:** [Other chunks this relies on]
- **Used by:** [Chunks that depend on this]
- **Related specs:** [Requirement IDs]

---
**Options:**
- Type **'continue'** for the next chunk
- Type **'deeper'** to see line-by-line explanation
- Type **'skip'** to skip similar chunks
- Type **'question'** to ask about this chunk
- Type **'menu'** for navigation options
```

#### 4.3 Progressive Disclosure Controls

Implement navigation commands:

```markdown
## 📚 Navigation Menu

**Progress:** You've viewed [X] of [Y] chunks

**Navigation Commands:**
- `continue` - Next chunk in sequence
- `back` - Previous chunk
- `jump [chunk-id]` - Go to specific chunk
- `overview` - Return to PR summary
- `files` - List all changed files
- `issues` - Show all verified review findings
- `false-positives` - Show filtered false positives with reasoning
- `uncertain` - Show issues needing human review
- `search [term]` - Find chunks containing term

**Depth Controls:**
- `deeper` - More detailed explanation of current chunk
- `simpler` - Simplified explanation
- `context` - Show surrounding code
- `history` - Show git history for this section

**Learning Tools:**
- `why` - Explain the reasoning behind this change
- `alternatives` - What other approaches could have been used?
- `pattern` - Is this a common pattern? Where else is it used?
- `test` - Show tests that cover this code

**Session Controls:**
- `save` - Save progress and exit
- `reset` - Start walkthrough from beginning
- `complete` - Mark walkthrough as complete
```

#### 4.4 Adaptive Explanation Depth

Based on user interaction, adjust explanation style:

**Level 1 - Executive (Default for managers/stakeholders):**
- Focus on business impact
- Minimal technical details
- Emphasis on requirements fulfilled

**Level 2 - Developer (Default for team members):**
- Balance of why and how
- Technical concepts explained clearly
- Focus on design decisions

**Level 3 - Deep Dive (For learning/debugging):**
- Line-by-line analysis
- Performance implications
- Alternative approaches discussed

#### 4.5 Handle User Questions

When user types 'question' or asks directly:

```markdown
## 💬 Understanding Check

I see you have a question about [current chunk]. 

**Quick Answers:**
1. Why was this approach chosen?
2. What are the performance implications?
3. How does this relate to the requirements?
4. What tests cover this code?
5. Are there security considerations?

Or type your specific question:
```

### Phase 5: Completion and Summary

When walkthrough completes:

```markdown
## ✅ Walkthrough Complete!

### 📊 Your Review Stats
- Chunks reviewed: [X/Y]
- Time spent: [duration]
- Questions asked: [count]
- Depth level used: [level]

### 🔍 Verification Summary
- Issues initially flagged by review: [total]
- Verified as real problems: [count]
- Filtered as false positives: [count]
- Marked uncertain: [count]

*Type `false-positives` to review what was filtered out and why.*

### 🎓 Key Takeaways
1. [Main architectural change]
2. [Important pattern introduced]
3. [Critical issue to watch]

### 📝 Review Summary

**What This PR Successfully Fixed:**
✅ [List of issues from original code that were properly addressed]

**Problems Found WITH This PR (Must Fix):**
🚨 Critical Issues:
- [List critical bugs/security issues introduced]

⚠️ Important Issues:  
- [List significant problems that should be fixed]

📝 Minor Issues:
- [List typos, style issues, minor improvements needed]

**Missing Coverage:**
🧪 [List areas lacking tests or documentation]

### 🔄 Next Steps
1. [ ] Address critical review findings
2. [ ] Run test suite
3. [ ] Update documentation
4. [ ] Request re-review

Would you like to:
- `review` - See detailed review report
- `questions` - Review your Q&A history
- `export` - Export walkthrough notes
- `exit` - Complete walkthrough
```

### Phase 6: State Persistence

After each interaction, update `.claude/.walkthrough-state.json`:
- Current position
- Chunks viewed/skipped
- User questions and answers
- Time spent per chunk
- Depth level preferences

This allows resuming interrupted walkthroughs and tracking learning patterns.

## Implementation Guidelines

### Pedagogical Principles
1. **Start with Why** - Always explain purpose before implementation
2. **Chunk Appropriately** - Respect cognitive load limits
3. **Use Plain English** - Avoid jargon, explain technical terms
4. **Show Connections** - How pieces fit together
5. **Integrate Review** - Contextual quality feedback
6. **Allow Exploration** - Let users control pace and depth

### Technical Principles
1. **Semantic Boundaries** - Never split logical units
2. **Context Preservation** - Include necessary context with each chunk
3. **Progressive Enhancement** - Start simple, add detail on demand
4. **State Management** - Track progress persistently
5. **Error Recovery** - Handle interruptions gracefully

### Quality Checks
Before presenting each chunk, verify:
- [ ] Chunk is self-contained and understandable
- [ ] Review findings are integrated if relevant
- [ ] Explanation follows EiPE method
- [ ] Navigation options are clear
- [ ] Progress is saved

## User Experience Flow

1. User runs command with PR number
2. System performs comprehensive review (background)
3. System organizes changes into semantic chunks
4. User sees executive summary
5. User navigates through chunks at their own pace
6. System provides contextual review findings
7. User can ask questions at any point
8. Progress is saved automatically
9. User completes walkthrough with full understanding

This approach ensures the user thoroughly understands all changes, their context, quality implications, and can make informed decisions about the PR.