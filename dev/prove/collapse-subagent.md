# Proof Collapse Sub-Agent

Collapse exactly ONE helper lemma back into its usage site for theorem [THEOREM_NAME].

## CRITICAL RULES

1. **One Lemma Only** - Collapse exactly ONE lemma per invocation
2. **10-Line Maximum** - Resulting proof must be ≤10 lines or skip
3. **Preserve Correctness** - Collapsed proof must still work
4. **Delete After Inline** - Remove the lemma after inlining
5. **Build Verification** - Must compile after collapse

## Your Task

Theorem: [THEOREM_NAME]
Target Lemma: [LEMMA_NAME] (or auto-select if not specified)
File Path: [FILE_PATH]

## Phase 1: Setup and Analysis

1. **Read proof state**: `.claude/proof-state.json`
   - Get list of active lemmas (status: "proved")
   - Check collapse history
   - Verify we're in "complete" or "collapsing" status

2. **Read the Lean file**: [FILE_PATH]
   - Locate all helper lemmas
   - Find where each lemma is used
   - Count lines in each proof

3. **Create session file**:
   ```bash
   TIMESTAMP=$(date +%Y%m%d_%H%M%S)
   SESSION_FILE=".claude/sessions/prove-collapse-${TIMESTAMP}.json"
   ```
   Record:
   ```json
   {
     "theorem": "[THEOREM_NAME]",
     "action": "collapse",
     "started_at": "[ISO timestamp]",
     "target_lemma": null,
     "candidates_analyzed": []
   }
   ```

## Phase 2: Select Lemma to Collapse

If no specific lemma provided, select automatically:

1. **Identify candidates**:
   - List all proved helper lemmas
   - For each, find where it's used
   - Check if it's used only once (best candidates)

2. **Evaluate collapsibility**:
   For each candidate lemma:
   ```
   Lemma: [name]
   - Current proof lines: N
   - Usage locations: [count]
   - Usage site current lines: M
   - Estimated combined lines: N + M - 1
   - Collapsible: YES if (N + M - 1) ≤ 10
   ```

3. **Selection priority**:
   1. Most recently introduced (work backwards)
   2. Single-use lemmas (easier to inline)
   3. Shortest proofs (less complexity added)
   4. Leaf lemmas (don't depend on others)

4. **Record selection**:
   ```json
   {
     "candidates_analyzed": [
       {
         "name": "[lemma_name]",
         "proof_lines": N,
         "usage_count": 1,
         "estimated_inline_size": M,
         "collapsible": true/false,
         "reason": "[why selected or skipped]"
       }
     ],
     "selected": "[chosen_lemma]"
   }
   ```

## Phase 3: Perform Collapse

For the selected lemma:

1. **Extract lemma proof**:
   - Get the complete proof body
   - Note any dependencies it uses
   - Prepare for inlining

2. **Locate usage site**:
   - Find where lemma is called
   - Understand the context
   - Check available tactics

3. **Inline the proof**:
   Replace the lemma call with its proof:

   **Before:**
   ```lean
   theorem foo : P := by
     have h := helper_lemma x y
     exact h
   ```

   **After:**
   ```lean
   theorem foo : P := by
     -- Inlined from helper_lemma
     have h : [lemma_type] := by
       [lemma_proof_line_1]
       [lemma_proof_line_2]
       [...]
     exact h
   ```

4. **Delete the lemma**:
   - Remove the entire lemma definition
   - Clean up any extra blank lines

5. **Simplification pass** (optional):
   - If inlining created redundancy, simplify
   - Combine tactics where possible
   - Keep under 10 lines total

## Phase 4: Verification

1. **Line count check**:
   - Count lines in modified proof
   - If >10 lines:
     - Revert the change
     - Mark lemma as "not collapsible"
     - Try next candidate

2. **Build verification**:
   ```bash
   lake build [module_name]
   ```
   - Must compile without errors
   - Check no type errors introduced
   - Verify proof still works

3. **Dependency check**:
   - Ensure no other proofs depended on deleted lemma
   - If dependencies found, revert

## Phase 5: Update State

After successful collapse:

1. **Update `.claude/proof-state.json`**:
   ```json
   {
     "status": "collapsing",
     "lemmas": [
       {
         "id": "[L-XXX]",
         "name": "[collapsed_lemma]",
         "status": "collapsed",
         "lines_of_proof": 0,
         "collapsed_at": "[timestamp]",
         "collapsed_into": "[usage_location]"
       }
     ],
     "proof_complexity": {
       "active_lemmas": N-1,
       "total_proof_lines": [updated]
     },
     "history": [
       {
         "timestamp": "[ISO timestamp]",
         "action": "collapse_lemma",
         "target": "[lemma_name]",
         "description": "Inlined [lemma] into [location]",
         "lines_before": X,
         "lines_after": Y,
         "success": true
       }
     ]
   }
   ```

2. **Check if more collapsible**:
   - Any remaining active lemmas?
   - Any that could be collapsed?
   - Update status if simplification complete

3. **Finalize session**:
   ```json
   {
     ...previous fields...,
     "completed_at": "[ISO timestamp]",
     "success": true,
     "lemma_collapsed": "[name]",
     "final_line_count": N,
     "build_verified": true
   }
   ```

## Phase 6: Report Result

Generate clear output:

```markdown
### Lemma Collapsed Successfully

**Collapsed:** [lemma_name]
**Into:** [theorem/lemma where inlined]

**Metrics:**
- Proof lines before: X
- Proof lines after: Y
- Net reduction: X - Y lines
- Active lemmas remaining: N

**Simplification Progress:**
- Total lemmas introduced: A
- Currently active: B
- Successfully collapsed: C

### Next Step
[If more collapsible]: Another lemma can be collapsed. Run again to continue.
[If none collapsible]: Simplification complete. All remaining lemmas needed for clarity.
```

## Error Cases

1. **No collapsible lemmas**:
   ```markdown
   ### Simplification Complete

   No more lemmas can be collapsed without exceeding complexity limits.

   **Final state:**
   - Active lemmas: N (all necessary)
   - Total proof lines: X
   - Average lines per proof: Y
   ```

2. **Would exceed 10 lines**:
   ```markdown
   ### Cannot Collapse: [lemma_name]

   Inlining would result in [N] lines (exceeds 10-line limit).
   Lemma remains separate for clarity.

   Trying next candidate...
   ```

3. **Build failure after collapse**:
   - Revert changes
   - Report specific error
   - Mark lemma as required

## Success Criteria

Collapse succeeds when:
- ✓ Exactly ONE lemma collapsed
- ✓ Resulting proof ≤10 lines
- ✓ Build still passes
- ✓ State correctly updated
- ✓ Clear report generated
- ✓ Next action identified