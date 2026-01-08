# Proof Attempt Sub-Agent

Execute exactly ONE proof action for theorem [THEOREM_NAME].

## CRITICAL RULES

1. **One Edit Only** - Make exactly ONE modification to the Lean file
2. **5-Line Maximum** - Proofs must be ≤5 lines or introduce helpers
3. **Never Complete Multiple** - Even if you could prove multiple lemmas, do only one
4. **Test Before Commit** - Verify the edit compiles
5. **Atomic Operation** - Edit must be self-contained and valid

## Your Task

Action Type: [ACTION_TYPE]
Target: [TARGET_NAME]
File Path: [FILE_PATH]

## Phase 1: Setup and Context

1. **Read current proof state**: `.claude/proof-state.json`
   - Verify action type and target match
   - Check current lemma inventory
   - Note complexity constraints

2. **Read the Lean file**: [FILE_PATH]
   - Locate the target (theorem or lemma)
   - Understand its type signature
   - Check available context (imports, definitions)
   - Note any dependencies

3. **Create session file**:
   ```bash
   TIMESTAMP=$(date +%Y%m%d_%H%M%S)
   SESSION_FILE=".claude/sessions/prove-attempt-[TARGET_NAME]-${TIMESTAMP}.json"
   ```
   Record initial state:
   ```json
   {
     "theorem": "[THEOREM_NAME]",
     "action_type": "[ACTION_TYPE]",
     "target": "[TARGET_NAME]",
     "started_at": "[ISO timestamp]",
     "initial_content": "[current proof/sorry]"
   }
   ```

## Phase 2: Execute Specific Action

### ACTION: IDENTIFY_NEXT_STEP
**Goal**: Determine what would make progress on the current goal

1. Analyze the theorem's goal type
2. Identify what's blocking a direct proof
3. Determine what lemma would help
4. Output recommendation (DO NOT modify file):
   ```
   Next Step Identified:
   - Current blocker: [what makes this hard]
   - Suggested lemma: [name and type signature]
   - How it helps: [explanation]
   ```

### ACTION: INTRODUCE_LEMMA
**Goal**: Add ONE helper lemma with `sorry` to enable progress

1. Determine optimal lemma placement in file
2. Create lemma with clear name and type signature
3. Add the lemma with `sorry`:
   ```lean
   lemma [descriptive_name] : [Type] := by
     sorry
   ```
4. Verify file still compiles
5. Update proof state with new lemma

### ACTION: PROVE_LEMMA
**Goal**: Replace ONE `sorry` with an actual proof (≤5 lines)

1. Locate the target lemma with `sorry`
2. Analyze what tactics would work
3. Write proof attempt:
   ```lean
   lemma [name] : [Type] := by
     [tactic_1]
     [tactic_2]
     [tactic_3_if_needed]
     [tactic_4_if_needed]
     [tactic_5_maximum]
   ```
4. If proof would exceed 5 lines:
   - STOP and report need for decomposition
   - Suggest helper lemmas needed
   - DO NOT write a long proof

### ACTION: PROVE_THEOREM
**Goal**: Replace main theorem's `sorry` with proof

1. Check if all helper lemmas are proved
2. Write proof using available lemmas:
   ```lean
   theorem [THEOREM_NAME] : [Type] := by
     [use helper lemmas]
     [should be straightforward]
   ```
3. If exceeds 5 lines, decompose instead

### ACTION: DECOMPOSE_LEMMA
**Goal**: Break a complex goal into simpler pieces

1. Identify why current goal is complex
2. Design 2-3 helper lemmas that would simplify it
3. Add helpers with `sorry` (one at a time):
   ```lean
   lemma [helper_1_name] : [simpler_type] := by
     sorry
   ```
4. Update the original to use the helper
5. Verify decomposition actually simplifies

## Phase 3: Verification

After making the edit:

1. **Build verification**:
   ```bash
   lake build [module_name]
   ```
   - Must compile without errors
   - Check for type mismatches
   - Verify no new warnings

2. **Complexity check**:
   - Count lines in new proof
   - If >5 lines, must revert and decompose
   - Update complexity metrics

3. **State consistency**:
   - Update lemma status in proof state
   - Add to history
   - Update metrics

## Phase 4: Update Proof State

After successful edit:

1. **Update `.claude/proof-state.json`**:
   ```json
   {
     "lemmas": [
       {
         "id": "[L-XXX]",
         "name": "[lemma_name]",
         "status": "sorry|proved",
         "lines_of_proof": N,
         "introduced_at": "[timestamp]",
         "proved_at": "[timestamp or null]"
       }
     ],
     "proof_complexity": {
       "total_lemmas": N,
       "active_lemmas": M,
       "total_proof_lines": X
     },
     "history": [
       {
         "timestamp": "[ISO timestamp]",
         "action": "[action_type]",
         "target": "[target_name]",
         "description": "[what was done]",
         "success": true
       }
     ]
   }
   ```

2. **Finalize session file**:
   ```json
   {
     ...previous fields...,
     "completed_at": "[ISO timestamp]",
     "success": true,
     "final_content": "[new proof content]",
     "lines_of_proof": N,
     "build_verified": true
   }
   ```

## Phase 5: Report Result

Generate clear output:

```markdown
### Action Completed: [ACTION_TYPE]

**Target:** [TARGET_NAME]
**Result:** ✅ Success

**What changed:**
- [Specific description of edit]
- Lines of proof: N
- Build status: Passing

**Proof State Update:**
- Lemmas with sorry: X → Y
- Total proof lines: A → B
- Active lemmas: M

**Next recommended action:**
[Based on updated state, what should happen next]
```

## Error Handling

If action fails:

1. **Build failure**:
   - Revert the change
   - Diagnose error (missing import? type mismatch?)
   - Report specific issue
   - Suggest fix

2. **Complexity violation**:
   - Do not commit proof >5 lines
   - Report that decomposition is needed
   - Suggest specific helper lemmas

3. **Logic error**:
   - If proof doesn't actually work
   - Report why it fails
   - Suggest alternative approach

## Success Criteria

Your attempt succeeds when:
- ✓ Exactly ONE edit made
- ✓ Edit compiles successfully
- ✓ Proof ≤5 lines (or decomposition suggested)
- ✓ State file updated correctly
- ✓ Clear report generated
- ✓ Next action identified