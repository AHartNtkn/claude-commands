# /dev/prove - Incremental Proof Development

A principled command for formal verification that enforces incremental proof development, particularly for Lean theorem proving.

## Quick Start

```bash
# Start proving a theorem
/dev/prove my_theorem

# Continue development (run repeatedly)
/dev/prove my_theorem

# Each invocation does exactly ONE action
# Keep running until proof is complete
```

## Philosophy

This command implements a proven approach to formal proof development:

1. **Start Small**: Begin with theorem skeleton containing `sorry`
2. **Incremental Progress**: Each step makes exactly one small change
3. **Complexity Control**: Proofs limited to 5 lines, forcing decomposition
4. **State Persistence**: All progress tracked in `.claude/proof-state.json`
5. **Atomic Operations**: One action per invocation prevents over-reach
6. **Forward Only**: Never undo, only refine forward

## How It Works

### State Machine

The proof development follows these states:

```
skeleton → identifying → proving → complete → collapsing → simplified
```

- **skeleton**: Theorem stated with `sorry`, ready to begin
- **identifying**: Analyzing what lemma or tactic would help
- **proving**: Actively proving lemmas or main theorem
- **complete**: All `sorry` statements replaced with proofs
- **collapsing**: Simplifying by inlining helper lemmas
- **simplified**: Final optimized proof

### One Action Per Run

Each invocation performs exactly ONE of:
- **IDENTIFY**: Determine next step needed
- **INTRODUCE**: Add one helper lemma with `sorry`
- **PROVE**: Replace one `sorry` with proof (≤5 lines)
- **DECOMPOSE**: Break complex proof into smaller lemmas
- **COLLAPSE**: Inline one helper lemma to simplify
- **COMPLETE**: Mark proof as finished

This enforces discipline and prevents over-ambitious attempts.

## Workflow Example

```bash
# Initial state: theorem with sorry
theorem foo : P ∧ Q := by sorry

# Run 1: Identifies need for conjunction split
/dev/prove foo
> "Need to prove P and Q separately"

# Run 2: Introduces first helper lemma
/dev/prove foo
> "Added lemma foo_p : P with sorry"

# Run 3: Introduces second helper lemma
/dev/prove foo
> "Added lemma foo_q : Q with sorry"

# Run 4: Proves main theorem using helpers
/dev/prove foo
> "Proved foo using foo_p and foo_q"

# Run 5: Proves foo_p
/dev/prove foo
> "Proved foo_p (3 lines)"

# Run 6: Proves foo_q
/dev/prove foo
> "Proved foo_q (4 lines)"

# Run 7: Marks complete
/dev/prove foo
> "✅ Proof complete! 2 lemmas, 7 total lines"

# Run 8: Begins simplification
/dev/prove foo
> "Collapsed foo_q into main proof"

# Run 9: Continues simplification
/dev/prove foo
> "Collapsed foo_p into main proof"

# Final state: Single proof, properly sized
```

## Proof State Tracking

All progress is tracked in `.claude/proof-state.json`:

```json
{
  "theorem": "foo",
  "file_path": "Foo.lean",
  "status": "proving",
  "lemmas": [
    {
      "id": "L-001",
      "name": "foo_p",
      "status": "proved",
      "lines_of_proof": 3,
      "introduced_at": "2024-01-15T10:00:00Z",
      "proved_at": "2024-01-15T10:05:00Z"
    }
  ],
  "proof_complexity": {
    "total_lemmas": 2,
    "active_lemmas": 1,
    "total_proof_lines": 7
  }
}
```

## Complexity Rules

### 5-Line Maximum for Individual Proofs

Any proof exceeding 5 lines must be decomposed:

```lean
-- ❌ Too complex - will trigger decomposition
lemma complex : P := by
  intro x
  have h1 := ...
  have h2 := ...
  have h3 := ...
  simp [h1, h2]
  exact h3  -- 6 lines!

-- ✅ Decomposed into simpler pieces
lemma helper1 : ... := by
  intro x
  exact ...  -- 2 lines

lemma helper2 : ... := by
  simp
  exact ...  -- 2 lines

lemma complex : P := by
  exact helper1 helper2  -- 1 line!
```

### 10-Line Maximum for Collapsed Proofs

When simplifying, inlined proofs can be up to 10 lines:

```lean
-- After collapsing helpers back in
theorem final : P := by
  intro x
  have h1 : Q := by
    simp
    exact ...
  have h2 : R := by
    intro y
    exact ...
  simp [h1, h2]
  exact ...  -- 9 lines total, OK for final form
```

## Best Practices

### 1. Let the Tool Guide You

Don't plan the entire proof upfront. Let each run analyze and suggest the next step:

```bash
/dev/prove my_theorem
# Read the suggestion, then run again
/dev/prove my_theorem
# Repeat until complete
```

### 2. Trust the Decomposition

When the tool says a proof is too complex, don't fight it. The 5-line limit ensures maintainable proofs:

```
"Proof would be 8 lines - decomposing into helpers"
> Creates helper lemmas automatically
```

### 3. Use Descriptive Lemma Names

The tool generates meaningful names, but you can guide it:

```lean
lemma list_concat_assoc : ...  -- Clear purpose
lemma helper_1 : ...           -- Avoid generic names
```

### 4. Simplification is Optional

Once complete, you can choose to:
- Keep all helper lemmas for clarity
- Collapse them for conciseness
- Stop mid-simplification if you like the balance

## Common Patterns

### Pattern: Conjunction/Disjunction

For `P ∧ Q` or `P ∨ Q`, expect:
1. Lemmas for each component
2. Main proof combining them
3. Optional collapse for simple cases

### Pattern: Induction

For inductive proofs, expect:
1. Base case lemma
2. Inductive step lemma
3. Main proof applying induction
4. Usually keep lemmas separate (clarity)

### Pattern: Complex Calculations

For involved computations:
1. Intermediate step lemmas
2. Each lemma proves one transformation
3. Chain them in main proof
4. Consider keeping for documentation

## Troubleshooting

### "Build failed after edit"

The tool validates each edit:
- Checks for type errors
- Ensures imports are present
- Reverts if compilation fails
- Reports specific error for fixing

### "Cannot make progress"

If stuck:
- Check that prerequisites are proved
- Verify imports are sufficient
- Consider if theorem statement is correct
- May need domain-specific lemmas

### "Proof too complex to decompose"

Rare, but if 5 lines isn't enough even with helpers:
- Review theorem statement
- Consider if you're proving the right thing
- May need different approach/tactics

## Session History

Each run creates a session in `.claude/sessions/prove-*.json`:

```json
{
  "theorem": "foo",
  "action_taken": "prove_lemma",
  "target": "foo_p",
  "success": true,
  "lines_of_proof": 3
}
```

This provides a complete audit trail of the proof development process.

## Integration with Lean Projects

### Lake Projects

The command automatically detects and uses Lake:

```bash
lake build  # Validates after each edit
```

### Mathlib4

Works seamlessly with Mathlib4:
- Uses standard `Equiv` definitions
- Leverages existing tactics
- Follows Mathlib proof style

### File Organization

Maintains your project structure:
- Finds theorems across multiple files
- Preserves module organization
- Respects import hierarchy

## Command Options

```bash
# Basic usage
/dev/prove theorem_name

# After completion, continues with simplification
/dev/prove theorem_name

# Process continues until you stop it
```

## Comparison with Manual Proving

### Traditional Approach
- Write entire proof at once
- Debug complex type errors
- Refactor when too complex
- Easy to get stuck

### Incremental Approach
- One small step at a time
- Each step validated immediately
- Complexity managed automatically
- Steady, predictable progress

## Tips for Success

1. **State theorem correctly first** - Get the type right before proving
2. **Run frequently** - Each invocation is cheap and safe
3. **Read the suggestions** - The tool analyzes what's blocking progress
4. **Trust the process** - Many small steps reach the goal reliably
5. **Keep proofs readable** - Decomposition improves maintainability

## Limitations

- Designed for Lean 4 (may work with other provers with adaptation)
- Requires proofs to be tactic-based (not term mode)
- Best for theorems that decompose naturally
- May need manual intervention for very specialized tactics

## Future Enhancements

Potential improvements being considered:
- Parallel lemma proving (when independent)
- Tactic suggestion based on goal type
- Automatic import detection
- Proof strategy patterns library

## Philosophy Reference

Based on the principle: "Never attempt a whole proof at once. Each finished proof should be only about five lines."

This enforces:
- Manageable complexity
- Clear proof structure
- Incremental progress
- Maintainable code

## Summary

The `/dev/prove` command transforms theorem proving from a complex, error-prone process into a series of simple, validated steps. By enforcing incremental development and complexity limits, it ensures steady progress toward correct, maintainable proofs.