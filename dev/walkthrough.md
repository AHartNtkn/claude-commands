---
allowed-tools: Task, Bash(gh:*), WebFetch, Read, Grep, Glob, Edit, Write, Bash([:*), Bash(echo:*), Bash(grep:*), Bash(jq:*), Bash(cat:*), Bash(bash -c:*), Bash(~/.claude/commands/dev/filter-diff.sh:*)
argument-hint: [pr-number]
description: Interactive PR walkthrough with comprehensive review and guided explanation using progressive disclosure
---

## Initial Context
- PR metadata: !`gh pr view $ARGUMENTS --json number,title,body,url,headRefName,baseRefName,additions,deletions,changedFiles,files`
- Changed files (excluding sessions): !`bash -c "gh pr diff $ARGUMENTS --name-only | grep -v '\.claude/sessions/'"`
- Commit messages: !`bash -c "gh pr view $ARGUMENTS --json commits | jq -r '.commits[].messageHeadline'"`
- PR comments and review threads: !`bash -c "gh pr view $ARGUMENTS --json comments,reviews --jq '.comments[].body, .reviews[].body' 2>/dev/null || echo ''"`
- Referenced issues: !`bash -c "gh pr view $ARGUMENTS --json body,commits --jq '[.body, .commits[].messageHeadline] | join(\" \")' | grep -oE '#[0-9]+' | sort -u | head -10 || echo ''"`
- Previous walkthrough state: !`[ -f .claude/.walkthrough-state.json ] && cat .claude/.walkthrough-state.json || echo "{}"`

## Full PR Diff (excluding session files)
!`~/.claude/commands/dev/filter-diff.sh $ARGUMENTS`

## Interactive PR Walkthrough Protocol

This command provides an interactive, educational walkthrough of PR changes. Its purpose is **understanding** — helping the reader see what the PR does, why each change exists, and how the pieces fit together.

**This is NOT a code review.** Use `dev:review` for finding bugs, security issues, and quality problems. This command focuses exclusively on explanation and comprehension.

### Phase 1: Parallel Design (4 Subagents)

Launch 4 subagents **in parallel**. Each focuses on one aspect of the walkthrough design. They all receive the full diff, PR metadata, and commit messages.

**Agent A — External Context (Haiku):**

This agent gathers and summarizes context from outside the diff itself: linked issues, PR discussion, and design decisions mentioned in comments.

```
You are gathering external context for a PR walkthrough.

PR #[number]: "[title]"
PR body: [body]
Commit messages: [commits]
PR comments/reviews: [comments]
Referenced issue numbers: [issue_numbers]

YOUR TASKS:
1. For each referenced issue number, fetch its content using `gh issue view [number] --json title,body,labels`
2. Read the PR body, commit messages, and any PR comments/review threads

PRODUCE:
{
  "problem_statement": "What problem is this PR solving? Synthesize from the linked issues, PR description, and commit messages. Be specific.",
  "design_decisions": ["List any design decisions or rationale mentioned in PR comments, issue discussions, or commit messages"],
  "external_references": [
    {
      "type": "issue" | "comment",
      "ref": "#123 or comment author",
      "summary": "One sentence: what relevant information this provides"
    }
  ]
}

If no issues are referenced and no comments exist, produce what you can from the PR body and commit messages alone.
```

**Agent B — Big Picture + Narrative (Sonnet):**

```
You are designing the narrative structure for a PR walkthrough.

PR #[number]: "[title]"
PR body: [body]
Commit messages: [commits]
Full diff: [diff]

YOUR TASK: Determine the big picture and narrative arc for explaining this PR.

PRODUCE:
{
  "big_picture": "2-3 sentence summary of what this PR accomplishes and WHY it exists. What problem does it solve? What was the motivation?",
  "narrative_arc": "1-2 sentences describing the logical order for understanding these changes. What should be explained first? What builds on what?",
  "key_concepts": ["Domain concepts the reader needs to understand to follow the walkthrough"]
}

Focus on the WHY, not just the WHAT. The reader wants to understand the motivation and design intent, not just see a list of changes.
```

**Agent C — Semantic Chunking (Sonnet):**

```
You are decomposing a PR diff into walkthrough chunks.

PR #[number]: "[title]"
Full diff: [diff]

YOUR TASK: Break the diff into properly-sized chunks, each covering ONE concept.

PRODUCE:
{
  "chunks": [
    {
      "id": "chunk-001",
      "file": "path/to/file.rs",
      "lines": "45-90",
      "title": "Short descriptive title",
      "concept": "One sentence: what this chunk does",
      "estimated_lines_to_show": 15
    }
  ]
}

RULES:
1. Each chunk should show ~10-20 lines of code. Target ONE concept per chunk.
2. If a file has multiple unrelated changes, split them into separate chunks.
3. If changes are trivially mechanical (e.g., renaming an import across 10 files), group them into one chunk with a note.
4. Don't create chunks for pure noise (generated files, lockfiles, whitespace-only changes).
5. If a function is 50+ lines, break it into multiple chunks by phase/concept.
```

**Agent D — Dependency + Grouping (Sonnet):**

```
You are analyzing the relationships between changes in a PR diff.

PR #[number]: "[title]"
Full diff: [diff]

YOUR TASK: Identify how the changes relate to each other — what depends on what, and how they group into logical units.

PRODUCE:
{
  "groups": [
    {
      "id": "group-1",
      "title": "Descriptive title for this logical group",
      "description": "What sub-goal do these changes accomplish together?",
      "file_patterns": ["Which files/regions belong in this group"]
    }
  ],
  "dependencies": [
    {
      "from_file": "path/to/file.rs",
      "from_region": "45-90",
      "to_file": "path/to/other.rs",
      "to_region": "10-30",
      "reason": "Why this dependency exists (uses type defined there, calls function, etc.)"
    }
  ],
  "suggested_reading_order": "Description of what order makes sense and why"
}

A dependency exists when one change uses a type, function, constant, or concept introduced by another change. Focus on what the READER needs to have seen first to understand each piece.
```

**Merging the 4 agents' outputs:**

After all 4 agents complete, the **top-level agent** (you) assembles the combined walkthrough plan:

1. Use Agent A's external context to enrich Agent B's big_picture — incorporate the problem statement and design decisions so the narrative reflects the full motivation, not just what's visible in the diff
2. Take Agent C's chunks and assign each to a group from Agent D's grouping
3. Use Agent D's dependencies to populate each chunk's `depends_on` and to determine reading order
4. Write each chunk's `big_picture_connection` yourself — you have the full context from all 4 agents to make these specific and accurate
5. Produce the final plan in this structure:

```json
{
  "big_picture": "...",
  "narrative_arc": "...",
  "external_context": {
    "problem_statement": "...",
    "design_decisions": ["..."]
  },
  "groups": [
    {
      "id": "group-1",
      "title": "...",
      "big_picture_role": "...",
      "chunks": [
        {
          "id": "chunk-1-1",
          "file": "...",
          "lines": "...",
          "title": "...",
          "concept": "...",
          "big_picture_connection": "...",
          "depends_on": [],
          "estimated_lines_to_show": 15
        }
      ]
    }
  ],
  "reading_order": ["chunk-1-1", ...],
  "key_concepts": ["..."]
}
```

### Phase 2: Parallel Decomposition Review (6 Subagents)

Launch 6 Sonnet subagents **in parallel**, each checking one quality criterion of the walkthrough plan. Each agent receives the plan from Phase 1 and the full diff.

Every agent uses this shared preamble:
```
You are reviewing a walkthrough plan for PR #[number]: "[title]".
Someone designed this plan to explain the PR to a reader. Your job is to check ONE specific quality criterion.

WALKTHROUGH PLAN:
[JSON from Phase 1]

FULL DIFF:
[diff]

RESPOND WITH:
{
  "criterion": "[your criterion name]",
  "pass": true | false,
  "issues": [
    {
      "description": "What's wrong",
      "location": "Which chunk/group is affected",
      "suggestion": "How to fix it"
    }
  ]
}
```

**Agent 1 — Completeness:**
```
CRITERION: Does every meaningful change in the diff appear in at least one chunk?

Walk through the diff file-by-file and hunk-by-hunk. For each changed region, verify it is covered by a chunk. List any changes that are missing from the plan entirely. Ignore generated files, lockfiles, and pure whitespace changes.
```

**Agent 2 — Granularity:**
```
CRITERION: Are chunks properly sized?

For each chunk, estimate how many lines of diff it covers based on the file and line range. Flag any chunk that covers >30 lines (too large — should be split) or <5 lines (too small — should be merged with a neighbor). The target is ~10-20 lines per chunk.
```

**Agent 3 — Narrative Coherence:**
```
CRITERION: Does the reading_order tell a logical story?

Walk through the reading_order sequence. At each step, ask: does the reader have enough context from previous chunks to understand this one? Flag any chunk that references concepts, types, or functions introduced in a LATER chunk. The reader should never be confused by a forward reference.
```

**Agent 4 — Big Picture Connections:**
```
CRITERION: Is every chunk's big_picture_connection specific and accurate?

For each chunk, read its big_picture_connection and check two things:
1. Is it SPECIFIC? ("This adds the Borsh serialization needed for Solana" is specific. "This is part of the PR" is not.)
2. Is it ACCURATE? Does the chunk's actual code change match what the connection claims?
Flag any chunk with a vague or inaccurate connection.
```

**Agent 5 — Grouping:**
```
CRITERION: Are the semantic groups logical?

For each group, check that all chunks within it are genuinely related — they work together toward the same sub-goal. Flag any chunk that seems to belong in a different group. Flag any group that mixes unrelated concerns. Flag cases where two groups should be merged or one group should be split.
```

**Agent 6 — Dependencies:**
```
CRITERION: Are the depends_on references correct and complete?

For each chunk, check its depends_on list. A dependency exists when chunk A uses a type, function, or concept that chunk B introduces. Flag:
- Missing dependencies (chunk uses something from another chunk but doesn't declare it)
- False dependencies (declared dependency but no actual relationship)
- Circular dependencies (A depends on B depends on A)
```

### Phase 3: Finalize Walkthrough Plan

After all 6 review agents complete, the **top-level agent** (you) incorporates their feedback into the final walkthrough plan. This is not delegated to a subagent — you do this yourself because you have full context of the PR, the design agent's intent, and all 6 review verdicts.

**Process:**
1. Collect all 6 review results
2. For each criterion that failed, read the issues and suggestions
3. Apply the necessary changes to the plan:
   - Add missing chunks (completeness failures)
   - Split or merge chunks (granularity failures)
   - Reorder the reading_order (narrative coherence failures)
   - Rewrite vague big_picture_connections (connection failures)
   - Move chunks between groups (grouping failures)
   - Fix depends_on references (dependency failures)
4. Produce the final walkthrough plan — this is what Phase 4 uses

If all 6 agents pass, you still review the plan briefly before adopting it. The review agents check specific criteria but don't see the whole picture the way you do.

Also initialize `.claude/.walkthrough-state.json`:
```json
{
  "pr_number": "123",
  "big_picture": "...",
  "total_chunks": 45,
  "current_chunk_index": 0,
  "chunks_viewed": [],
  "chunks_skipped": [],
  "depth_level": 4,
  "user_questions": [],
  "session_start": "2024-01-15T10:00:00Z"
}
```

### Phase 4: Interactive Walkthrough Execution

#### 4.1 Start with Executive Summary

```markdown
# PR Walkthrough: [Title] (#[Number])

## The Big Picture
[big_picture from the walkthrough plan — what this PR does and WHY]

## Scope
- Files modified: X
- Lines added: +Y / removed: -Z

## How the Changes Fit Together
[ASCII diagram showing the architecture of the changes — which components are touched and how they relate]
```
┌──────────────┐     ┌──────────────┐
│  Component A │────▶│  Component B │
│  (modified)  │     │  (new)       │
└──────────────┘     └──────────────┘
        │
        ▼
┌──────────────┐
│  Component C │
│  (modified)  │
└──────────────┘
```

## Narrative Arc
[narrative_arc — the logical story of how these changes fit together]

## Walkthrough Structure
I'll guide you through [N] chunks organized into [M] groups:

1. **[Group 1 title]** — [big_picture_role] ([X chunks])
2. **[Group 2 title]** — [big_picture_role] ([Y chunks])
3. **[Group 3 title]** — [big_picture_role] ([Z chunks])

## Key Concepts
[List any domain concepts that will come up during the walkthrough]

Ready? Type **'continue'** to start, or **'menu'** for navigation.
```

**DIAGRAM REQUIREMENT:** The executive summary MUST include an ASCII diagram showing the architecture of the changes. Use box-drawing characters to show which components/modules are touched and how they relate.

#### 4.2 Present Each Chunk

For each chunk, structure the explanation as:

```markdown
## [Chunk X/Y] [Title]
`path/to/file.rs:45-60` | Progress: ▓▓▓▓░░░░░░ 40%

> **Big picture:** [big_picture_connection — how this fits into the PR's overall story]

### What's happening here
[1-3 sentences explaining the concept in plain English]

[OPTIONAL diagram — include when the chunk involves any of:]
[- Data flow through a pipeline or sequence of steps]
[- State transitions or lifecycle changes]
[- Call relationships between functions/methods]
[- Data structure relationships (e.g., tree, graph, linked structures)]
```
Input ──▶ validate() ──▶ transform() ──▶ Output
                              │
                              ▼
                         cache_result()
```

### Before → After (if applicable)
**Before:** [Brief description of previous behavior]
**After:** [Brief description of new behavior]

```language
[10-20 lines of code from the diff]
```

### Key details
- Line N: [brief explanation of non-obvious logic]
- Line M: [brief explanation]

### Connections
- **Builds on:** [chunk-id] — [why]
- **Leads to:** [chunk-id] — [why]

---
`continue` | `deeper` | `skip` | `question` | `menu`
```

**Mandatory per-chunk rules:**
- The "Big picture" blockquote at the top of every chunk is **required**. It keeps the reader oriented in the overall PR narrative.
- Include an ASCII diagram whenever the chunk involves data flow, state transitions, call graphs, or data structure relationships. Skip diagrams only for simple value changes, renames, or config tweaks.
- Brief explanations only — no lengthy prose between code blocks.
- One concept per chunk.

#### 4.3 Group Transitions

When moving from one group to the next, present a brief transition:

```markdown
---

## Moving on: [Next Group Title]

We've covered [previous group summary — one sentence].

Next, we'll look at **[next group title]** — [big_picture_role]. This is where [brief preview of what comes next and how it connects to what we just saw].

---
```

#### 4.4 Progressive Disclosure Controls

```markdown
## Navigation Menu

**Progress:** [X] of [Y] chunks viewed

**Navigation:**
- `continue` — next chunk
- `back` — previous chunk
- `jump [chunk-id]` — go to specific chunk
- `overview` — return to PR summary
- `group [N]` — jump to start of group N
- `search [term]` — find chunks containing term

**Depth:**
- `deeper` — more detailed explanation of current chunk
- `simpler` — simplified explanation
- `context` — show surrounding code (full file context)
- `history` — git history for this section

**Understanding:**
- `why` — explain the design reasoning
- `alternatives` — what other approaches could have been used?
- `pattern` — is this a common pattern? where else is it used?
- `test` — show tests that cover this code
- `big-picture` — re-show the overall PR narrative and where we are

**Session:**
- `save` — save progress and exit
- `reset` — start from beginning
- `complete` — mark walkthrough as complete
```

#### 4.5 Handle User Questions

When the user asks a question or types 'question', answer it in context of both the current chunk AND the big picture. Always connect the answer back to the PR's overall narrative.

### Phase 5: Completion

```markdown
## Walkthrough Complete

**Stats:**
- Chunks reviewed: [X/Y]
- Questions asked: [count]

**Summary**
[Restate the big_picture, now enriched by everything the reader has seen]

**Key Takeaways:**
1. [Main architectural/design insight]
2. [Important pattern or technique used]
3. [How the pieces connect together]

**Questions to consider:**
- [Thought-provoking question about the design]
- [Question about potential implications]

Would you like to:
- `questions` — review your Q&A history
- `overview` — see the full structure again
- `exit` — complete walkthrough
```

### Phase 6: State Persistence

After each interaction, update `.claude/.walkthrough-state.json`:
- Current position
- Chunks viewed/skipped
- User questions and answers
- Depth level preferences

This allows resuming interrupted walkthroughs.

## Design Principles

1. **Big picture first, always** — Every chunk starts with its connection to the whole
2. **Tell a story** — Changes are presented in narrative order, not file order
3. **One concept per chunk** — Respect cognitive load
4. **No review** — This is for understanding, not for finding problems
5. **Separate concerns** — Design is split by concern (context, narrative, chunking, dependencies); review is split by criterion (completeness, granularity, coherence, connections, grouping, dependencies)
6. **Verify the decomposition** — 6 independent review agents check the plan before it's used
7. **External context matters** — Linked issues and PR discussion inform the narrative
8. **Progressive disclosure** — Start simple, let the reader drill down on demand
