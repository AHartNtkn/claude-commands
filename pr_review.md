---
allowed-tools: Bash(gh:*)
argument-hint: [pr-number]
description: Hunk-window PR review with single diff fetch; per-window annotations then aggregated actions and patches.
---

## Inputs
- PR number: `$ARGUMENTS`

## Data to load exactly once (do not run any additional shell after this block)
- PR metadata (JSON): !`gh pr view $ARGUMENTS --json number,title,body,url,headRefName,baseRefName,additions,deletions,changedFiles`
- Unified diff (colorless, patch format): !`gh pr diff $ARGUMENTS --patch --color=never`

## Review mode (follow literally; no role fluff)
1) **Scope discipline**
   - Treat the loaded diff text as the single source. Do **not** request more files. Do **not** re-run shell.
   - Keep only the current “window” in active context; compress/discard previous windows after emitting their note.

2) **Parse**
   - Split the diff by file blocks (“`diff --git a/... b/...`”).
   - Within each file block, split by hunk headers matching `@@ -<oldStart>[,<oldLen>] +<newStart>[,<newLen>] @@` per unified diff spec. :contentReference[oaicite:1]{index=1}
   - For each hunk, create windows covering at most **7 changed lines** (`+` or `-`) with **±2** unchanged context lines. Slide forward until the hunk is fully covered.

3) **Per-window checks** (deterministic heuristics; evaluate only the window text)
   - **Correctness**
     - IO, network, subprocess, FS calls without adjacent error handling keywords (`try|catch|except|rescue|Result|error|err`) ⇒ flag **missing-error-handling**; suggest a minimal error path (propagate or default).
     - Suspicious APIs / insecure ops:
       - dynamic code: `eval(` or `exec(` ⇒ replace with dispatch/map or parser.
       - shell execution with interpolation (e.g., `subprocess.*(shell=True)` / backticks) ⇒ pass argv list; escape user data.
       - unsafe deserialization: `pickle.loads(` ⇒ use JSON/CBOR or a safe schema.
       - crypto/security randomness: `random.(random|randint|randrange)` in security context ⇒ use `secrets`/OS RNG.
   - **Complexity & clarity**
     - Count branch tokens per window (`if|elif|else if|for|while|case|switch|catch|&&|\|\||\?:`). If >12, flag **high-branching**; recommend extracting pure helpers boundary by boundary (name the boundaries visible in the window).
     - **Magic numbers**: numeric literals other than -1/0/1 not in enums/consts ⇒ introduce a named constant at the nearest file scope; propose a specific identifier.
     - **Logging**: statements like `print/console.log/logging.*` without structured fields (no key=value or placeholders) ⇒ add identifiers/parameters as structured metadata.
   - **Tests**
     - If **no** test files appear in the diff and the window adds behavior, flag **missing-tests** for this window; recommend concrete test names and inputs derived from the visible API lines.
   - **Style**
     - Identify shadowed variables, unused error values, partially handled errors (log-and-continue without action), and non-idempotent init in constructors; propose exact line edits.
   - Assign `risk = min(10, Σ weights)`, with weights:
     - 5: dangerous-eval/exec/shell-true/unsafe-deserialize
     - 3: missing-error-handling, insecure-random
     - 2: high-branching, missing-tests
     - 1: magic-number, unstructured-logging, style nits

4) **Per-window output (emit immediately, then discard the window)**
   - Header: `### <file>:<newStart>-<newEnd> (risk=<0-10>, +<adds>/-<dels>, cx=<branch-tokens>)`
   - Show the exact window snippet, preserving `+/-/ ` prefixes.
   - **Findings**: bullet for each issue → `kind @ L<line>: <evidence>` and a **concrete fix**.
   - **Patch** (only when a precise, minimal edit is safe): show a small unified diff with correct line header `@@ +<line>,<n> @@` and the edited lines.

5) **Aggregation after final window**
   - Group identical issue kinds by file; list counts and the highest window risk encountered.
   - **Top actions (max 10)**: order by highest risk desc, then total occurrences desc. Each action includes: file, kind, one example evidence, and a concrete next step (e.g., “extract validator; rename const; add try/except around X”).
   - **Suggested patches**: concatenate the safe per-window patches (skip any that conflict by overlapping ranges).
   - Output structure:
     - `# PR Hunk Review: <title> (<url>)`
     - `## PR Stats` (additions, deletions, changedFiles from metadata)
     - `## Per-Window Notes` (all window sections)
     - `## Aggregated Actions`
     - `## Suggested Patches`

6) **PR description sanity check (metadata only, no extra shell)**
   - If body lacks any of: **what**, **why**, **how tested**, add a short fill-in template block with those headings.

7) **Cost guardrails**
   - Never reload the diff. Never open full files. Keep at most one window’s text plus the ongoing aggregated list in working context.

