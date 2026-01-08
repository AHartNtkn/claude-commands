# Proof State Analysis Sub-Agent

Analyze the current proof state for theorem [THEOREM_NAME] and determine the next atomic action.

## CRITICAL RULES

1. **One Action Only** - Identify exactly ONE next action, never multiple
2. **Atomic Steps** - Each action must be completable in a single edit
3. **Complexity Limits** - Flag any proof exceeding 5 lines for decomposition
4. **No Speculation** - Base analysis only on actual file content
5. **Forward Only** - Never suggest undoing previous work

## Your Task

Analyze proof state for: [THEOREM_NAME]

## Phase 1: Load Current State

1. **Read proof state file**: `.claude/proof-state.json`
   - Extract theorem name, file path, status
   - List all lemmas and their statuses
   - Check complexity metrics

2. **Read the Lean file**: Read the file at the path specified in proof state
   - Locate the main theorem
   - Find all helper lemmas (if any)
   - Check for `sorry` statements
   - Count proof lines for each proved item

3. **Build status snapshot**:
   ```
   Theorem: [name]
   Status: [skeleton|identifying|proving|complete|collapsing]
   Lemmas with sorry: [count]
   Lemmas proved: [count]
   Lemmas collapsed: [count]
   ```

## Phase 2: Validate Current State

Check for inconsistencies:

1. **File vs State Mismatch**:
   - Do all lemmas in state exist in file?
   - Are there lemmas in file not tracked in state?
   - Do the statuses match (sorry vs proved)?

2. **Complexity Violations**:
   - Any proof >5 lines that isn't flagged?
   - Any lemma that should be decomposed?

3. **Build Status**:
   ```bash
   lake build [module name]
   ```
   - Does the file compile?
   - Are there type errors?
   - Are there missing imports?

## Phase 3: Determine Next Action

Based on current state, determine EXACTLY ONE of these actions:

### Decision Tree

1. **Is main theorem still `sorry`?**
   - YES → Check if we can prove directly (≤5 lines)
     - Can prove directly → Action: PROVE_THEOREM
     - Too complex → Action: IDENTIFY_NEXT_STEP
   - NO → Continue to next check

2. **Are there lemmas with `sorry`?**
   - YES → Find simplest sorry lemma
     - Can prove in ≤5 lines → Action: PROVE_LEMMA (specify which)
     - Too complex → Action: DECOMPOSE_LEMMA (specify which)
   - NO → Continue to next check

3. **Are all proofs complete (no sorry)?**
   - YES → Update status to "complete" → Action: MARK_COMPLETE
   - NO → Should not reach here, error in logic

4. **Is status "complete" and user wants simplification?**
   - Check if any lemma can be collapsed
   - Find most recent collapsible lemma → Action: COLLAPSE_LEMMA (specify which)
   - No collapsible lemmas → Action: SIMPLIFICATION_COMPLETE

## Phase 4: Analyze Complexity for Chosen Action

If action involves proving something:

1. **Estimate proof complexity**:
   - What tactics would be needed?
   - How many steps approximately?
   - Any dependent lemmas needed?

2. **Decomposition strategy** (if needed):
   - What would be good intermediate lemmas?
   - How to break down the proof goal?
   - Names for helper lemmas?

## Phase 5: Generate Report

Output a structured analysis:

```json
{
  "theorem": "[THEOREM_NAME]",
  "current_status": "[status]",
  "consistency_check": {
    "file_matches_state": true/false,
    "build_succeeds": true/false,
    "issues_found": []
  },
  "proof_inventory": {
    "main_theorem": "sorry|proved|[line_count]",
    "lemmas": [
      {
        "name": "[lemma_name]",
        "status": "sorry|proved|collapsed",
        "line_count": 0,
        "needs_decomposition": false
      }
    ],
    "total_sorrys": 0,
    "total_proof_lines": 0
  },
  "recommended_action": {
    "type": "IDENTIFY|INTRODUCE|PROVE|DECOMPOSE|COLLAPSE|COMPLETE",
    "target": "[theorem or lemma name]",
    "reasoning": "[why this is the next logical step]",
    "complexity_estimate": "trivial|simple|moderate|complex",
    "decomposition_hint": "[if applicable]"
  },
  "next_steps_preview": [
    "[What would come after this action]",
    "[And after that]"
  ]
}
```

## Phase 6: Specific Guidance for Action

Based on recommended action, provide specific guidance:

### If IDENTIFY_NEXT_STEP:
- What aspect of the theorem is blocking progress?
- What kind of lemma would help?
- Suggested approach direction?

### If INTRODUCE_LEMMA:
- Exact lemma statement to add
- Where to place it in the file
- How it helps the main proof

### If PROVE_LEMMA:
- Which lemma to prove
- Suggested tactics/approach
- Keep under 5 lines

### If DECOMPOSE_LEMMA:
- Which lemma is too complex
- How to break it down
- Suggested helper lemma names

### If COLLAPSE_LEMMA:
- Which lemma to collapse
- Where it's used
- Will result stay under 10 lines?

## Success Criteria

Your analysis succeeds when:
- ✓ Current state fully understood
- ✓ All inconsistencies identified
- ✓ Exactly ONE action recommended
- ✓ Specific, actionable guidance provided
- ✓ Complexity correctly estimated
- ✓ No multi-step plans suggested