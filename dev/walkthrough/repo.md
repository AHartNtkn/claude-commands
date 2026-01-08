---
allowed-tools: Task, Read, Grep, Glob, Edit, Write, Bash(git:*), Bash(ls:*), Bash(find:*), Bash(rg:*), Bash(jq:*), Bash(cat:*), Bash(sed:*), Bash(head:*), Bash(tail:*), Bash(wc:*), Bash(bash -c:*), Bash([:*), Bash(echo:*)
argument-hint: [path]
description: Interactive repository walkthrough with comprehensive review and guided explanation using progressive disclosure
---

## Initial Context
- Target path: !`bash -c 'echo "${ARGUMENTS:-.}"'`
- Git root: !`bash -c 'TARGET="${ARGUMENTS:-.}"; git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || echo ""'`
- Current branch: !`bash -c 'TARGET="${ARGUMENTS:-.}"; ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || exit 0; git -C "$ROOT" rev-parse --abbrev-ref HEAD'`
- Remotes: !`bash -c 'TARGET="${ARGUMENTS:-.}"; ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || exit 0; git -C "$ROOT" remote -v || true'`
- Last commit: !`bash -c 'TARGET="${ARGUMENTS:-.}"; ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || exit 0; git -C "$ROOT" log -1 --pretty=fuller'`
- Working tree status: !`bash -c 'TARGET="${ARGUMENTS:-.}"; ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || exit 0; git -C "$ROOT" status --porcelain=v1'`
- Tracked file count: !`bash -c 'TARGET="${ARGUMENTS:-.}"; ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || exit 0; git -C "$ROOT" ls-files | wc -l'`
- Top-level listing: !`bash -c 'TARGET="${ARGUMENTS:-.}"; ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || exit 0; ls -la "$ROOT"'`
- Top-level tree (depth 2, excluding common vendor dirs): !`bash -c 'TARGET="${ARGUMENTS:-.}"; ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || exit 0; find "$ROOT" -maxdepth 2 \( -name .git -o -name node_modules -o -name dist -o -name build -o -name .venv -o -name vendor \) -prune -o -type d -print | sed "s#^$ROOT/##" | sed "s#^$ROOT$#.#" | sort'`
- Common build/config manifests present: !`bash -c 'TARGET="${ARGUMENTS:-.}"; ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || exit 0; for f in README.md CONTRIBUTING.md CODE_OF_CONDUCT.md LICENSE package.json pnpm-lock.yaml yarn.lock bun.lockb pyproject.toml poetry.lock requirements.txt Pipfile Cargo.toml go.mod pom.xml build.gradle build.gradle.kts Makefile Dockerfile docker-compose.yml compose.yml .github/workflows; do [ -e "$ROOT/$f" ] && echo "$f"; done; true'`
- Previous walkthrough state: !`bash -c 'TARGET="${ARGUMENTS:-.}"; ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || exit 0; [ -f "$ROOT/.claude/.repo-walkthrough-state.json" ] && cat "$ROOT/.claude/.repo-walkthrough-state.json" || echo "{}"'`

## README (first 200 lines if present)
!`bash -c 'TARGET="${ARGUMENTS:-.}"; ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || exit 0; [ -f "$ROOT/README.md" ] && sed -n "1,200p" "$ROOT/README.md" || echo ""'`

## Interactive Repository Walkthrough Protocol

This command provides an interactive, educational walkthrough of an entire repository using progressive disclosure, visual diagrams, and pedagogical best practices.

### Phase 0: Preflight

If `git root` is empty, stop and ask the user to run this command from inside a git repository (or pass a path inside one).

### Phase 1: Repository Chunking

Analyze the repo and organize it into semantic chunks.

**CRITICAL CHUNKING RULE:** Each chunk MUST contain **~10-15 lines of code** to show the user. The user should be able to read and understand each chunk in under 60 seconds. Exceptions: repetitive/boilerplate data that conveys no new information may be summarized.

#### 1.1 Use Subagents for Large Files

For any file >100 lines, launch a Task subagent to analyze and recommend chunks:

```
Analyze this file and recommend how to chunk it for a walkthrough.

File: {path}
Lines: {line_count}

Rules:
- Each chunk = 10-15 lines of code showing ONE concept
- Identify logical boundaries: function signatures, struct definitions, phases within functions
- Return a JSON array of recommended chunks

Output format:
{
  "file": "{path}",
  "chunks": [
    {"name": "...", "line_start": N, "line_end": M, "concept": "one sentence"},
    ...
  ]
}
```

Run these subagents in parallel for multiple large files to speed up chunking.

#### 1.2 Chunking Algorithm

One chunk = ONE of the following:
- A single function signature + brief body overview (~10 lines)
- A single struct/type definition (~5-15 lines)
- A single concept within a larger function (~10-15 lines of that function)
- A group of 2-3 trivially simple related items (e.g., 3 one-line constants)

**If a function is 50 lines, it becomes 3-5 chunks, each covering one phase/concept.**

#### 1.3 Chunk Granularity Examples

**WRONG (too much):**
```
Chunk: "execute_settlement() function"
Shows: 300 lines of code
```

**CORRECT (properly granular):**
```
Chunk 1: "execute_settlement() - function signature and overview" (5 lines + explanation)
Chunk 2: "execute_settlement() - Phase 1: Root validation loop" (12 lines)
Chunk 3: "execute_settlement() - Phase 2: Nullifier extraction" (10 lines)
Chunk 4: "execute_settlement() - Phase 3a: Aggregated proof path" (15 lines)
Chunk 5: "execute_settlement() - Phase 3b: Non-aggregated proof path intro" (10 lines)
... etc
```

**Each chunk presents ONE idea with ~10-15 lines of supporting code.**

#### 1.4 Chunk Hierarchy

```
Level 1: Repo Overview (no code - plain English description only)
Level 2: System Map (architecture relationships, no code)
Level 3: Module signatures (just pub fn/struct signatures, 10-15 lines)
Level 4: Single concept (one idea + its code, 10-15 lines)
Level 5: Line-by-line annotation (only on explicit request)
```

**Default is Level 4.** Never show more than ~15 lines of code per chunk unless the user explicitly requests deeper detail.

#### 1.5 Chunk Metadata Schema

```json
{
  "chunks": [
    {
      "id": "chunk-023",
      "level": 4,
      "file": "src/lib.rs",
      "line_start": 560,
      "line_end": 580,
      "name": "Root validation loop",
      "concept": "Iterates compliance units, validates each consumed_commitment_tree_root",
      "lines_shown": 12,
      "parent_function": "execute_settlement",
      "depends_on": ["chunk-022"]
    }
  ]
}
```

#### 1.6 Presentation Rule

When presenting a chunk:
1. State the concept in 1-2 sentences
2. Show ~10-15 lines of code (the minimum needed to understand)
3. Explain what those specific lines do
4. Note connections to other chunks

**Do NOT dump large code blocks. The user's cognitive load matters.**

### Phase 2: Initialize Walkthrough State

Create or update `.claude/.repo-walkthrough-state.json`:
```json
{
  "repo_root": "/abs/path/to/repo",
  "target_path": ".",
  "total_chunks": 45,
  "current_chunk": 0,
  "chunks_viewed": [],
  "chunks_skipped": [],
  "depth_level": 4,
  "user_questions": [],
  "session_start": "2024-01-15T10:00:00Z"
}
```

### Phase 3: Interactive Walkthrough Execution

#### 3.1 Start with Executive Summary

```markdown
# Repository Walkthrough: [Repo Name]

## What This Repo Is
[Plain-English description of what the repo provides and who it's for]

## How To Run / Test
- Install/setup: [commands]
- Run: [commands]
- Test: [commands]

## Architecture Diagram
```
┌─────────────┐     ┌─────────────┐
│  Module A   │────▶│  Module B   │
└─────────────┘     └─────────────┘
       │                   │
       ▼                   ▼
┌─────────────┐     ┌─────────────┐
│  Module C   │◀───▶│  Module D   │
└─────────────┘     └─────────────┘
```
[Use ASCII box-drawing to show component relationships]

## Walkthrough Structure
- Total chunks: [N]
- Estimated time: [N chunks × 1 min]

Ready to begin? Type **'continue'** to start, or **'menu'** for navigation options.
```

**DIAGRAM REQUIREMENT:** Always include ASCII diagrams to illustrate:
- Architecture overview in executive summary
- Data flow when explaining pipelines/sequences
- State transitions when explaining state machines
- Call graphs when explaining function relationships

#### 3.2 Present Each Chunk

Each chunk follows this compact format:

```markdown
## [Chunk X/Y] [Title]
`file.rs:123-135` | Progress: ▓▓▓░░░░░░░ 30%

**Concept:** [One sentence explaining what this code does]

[OPTIONAL: Flow diagram if this chunk involves sequences/state/calls]
```
Input ──▶ Step1 ──▶ Step2 ──▶ Output
```

```language
[10-15 lines of code - NO MORE]
```

**What's happening:**
- Line N: [brief explanation]
- Line M: [brief explanation]

**Connects to:** [chunk-id] (next logical step)

---
`continue` | `deeper` | `skip` | `menu`
```

**STRICT RULES:**
- Maximum 15 lines of code per chunk
- One concept per chunk
- Brief explanations only
- No lengthy prose between code blocks
- Include a diagram when explaining flows, sequences, or state transitions

#### 3.3 Progressive Disclosure Controls

```markdown
## 📚 Navigation Menu

**Progress:** You've viewed [X] of [Y] chunks

**Navigation Commands:**
- `continue` - Next chunk in sequence
- `back` - Previous chunk
- `jump [chunk-id]` - Go to specific chunk
- `overview` - Return to repo summary
- `map` - Show architecture diagram
- `files [pattern]` - Find chunks by file pattern
- `search [term]` - Find chunks containing term

**Depth Controls:**
- `deeper` - More detailed explanation of current chunk
- `simpler` - Simplified explanation
- `context` - Show surrounding code
- `history` - Show git history for this area

**Learning Tools:**
- `why` - Explain why this design exists
- `alternatives` - What other approaches could work?
- `pattern` - Where else is this pattern used?
- `test` - Show tests that cover this area

**Session Controls:**
- `save` - Save progress and exit
- `reset` - Start walkthrough from beginning
- `complete` - Mark walkthrough as complete
```

### Phase 4: Completion

When walkthrough completes:

```markdown
## Walkthrough Complete

**Stats:**
- Chunks reviewed: [X/Y]
- Questions asked: [count]

**Key Takeaways:**
- [Main architectural insight]
- [Important pattern to remember]
- [Critical flow to understand]
```

### Phase 5: State Persistence

After each interaction, update `.claude/.repo-walkthrough-state.json`:
- Current position
- Chunks viewed/skipped
- User questions and answers
- Time spent per chunk
- Depth level preferences
