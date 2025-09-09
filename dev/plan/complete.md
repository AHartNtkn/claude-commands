---
allowed-tools: Read, Edit, Bash(gh issue list:*), Bash(jq *)
description: Finalize plan to v1.0 frozen state
context-commands:
  - name: plan_exists
    command: '[ -f .claude/plan.md ] && echo "true" || echo "false"'
  - name: plan_version
    command: '[ -f .claude/plan.md ] && grep -oE "^# Plan \\(v[0-9.]+\\)" .claude/plan.md | grep -oE "v[0-9.]+" || echo "none"'
  - name: ready_count
    command: 'grep -c "\*\*Status:\*\* ready" .claude/plan.md 2>/dev/null || echo "0"'
  - name: blocked_count
    command: 'grep -c "\*\*Status:\*\* blocked" .claude/plan.md 2>/dev/null || echo "0"'
  - name: analyzed_count
    command: 'grep -c "\*\*Status:\*\* analyzed" .claude/plan.md 2>/dev/null || echo "0"'
  - name: open_questions
    command: '[ -f .claude/questions.json ] && jq -r "to_entries | map(select(.value.status == \"open\")) | length" .claude/questions.json || echo "0"'
  - name: total_tasks
    command: 'grep -cE "^\\* \\*\\*\\[ \\] T-[0-9]+" .claude/plan.md 2>/dev/null || echo "0"'
  - name: total_issues
    command: 'grep -oE "\\[Issue #[0-9]+\\]" .claude/plan.md 2>/dev/null | sort -u | wc -l || echo "0"'
---

# Plan Completion Phase

## Preflight Checks

- Plan exists: !{plan_exists}
- Current version: !{plan_version}
- Ready tasks: !{ready_count}
- Blocked tasks: !{blocked_count}
- Analyzed tasks: !{analyzed_count}
- Open questions: !{open_questions}
- Total tasks: !{total_tasks}
- GitHub issues created: !{total_issues}

**If plan_exists is "false":**
Stop and inform user: "No plan found. Please run `/dev/plan/create` first."

**If ready_count > 0:**
Stop and inform user: "Still have !{ready_count} ready tasks. Run `/dev/plan/analyze` to analyze them."

**If blocked_count > 0:**
Stop and inform user: "Still have !{blocked_count} blocked tasks. Check for unanswered questions with `/dev/plan/question`."

**If open_questions > 0:**
Stop and inform user: "Still have !{open_questions} open questions. Run `/dev/plan/question` to answer them."

## Algorithm to Execute

### Step 1: Verify Completion State

All tasks should be in "analyzed" or "obsolete" state:
```bash
# Check that all tasks are analyzed
if [ !{ready_count} -eq 0 ] && [ !{blocked_count} -eq 0 ]; then
  echo "✓ All tasks have been analyzed"
else
  echo "⚠️ Warning: Some tasks may not be fully analyzed"
fi
```

### Step 2: Update Plan Version

Update the plan to version 1.0 (frozen):

1. Edit `.claude/plan.md`:
   - Change `# Plan (vX.Y)` to `# Plan (v1.0)`
   - Update Change Log:
     ```markdown
     **Change Log:**
     - v1.0: Plan frozen - all tasks analyzed, all decisions made
     - [previous entries...]
     ```

### Step 3: Generate Completion Summary

Create a summary of the planning process:

```markdown
## Planning Summary

### Scope
- Total tasks created: !{total_tasks}
- GitHub issues created: !{total_issues}
- Tasks analyzed: !{analyzed_count}

### Decisions Made
- Technical questions answered: [Count from questions.json]
- ADRs created: [Count from .claude/ADRs/]

### Work Breakdown
- Top-level tasks: [Count tasks with no Parent field]
- Decomposed tasks: [Count tasks with Parent field]
- Average task complexity: ~[Estimate] LOC

### Ready for Implementation
All tasks have been:
✓ Analyzed for technical decisions
✓ Decomposed to implementable size
✓ Assigned GitHub issues
✓ Linked with dependencies
```

### Step 4: Verify GitHub Issues

Check that all GitHub issues are properly created and linked:
```bash
# List all issues created for this plan
gh issue list --label "plan" --limit 100 --json number,title,state
```

### Step 5: Create Final Change Log Entry

Add final entry to plan.md Change Log:
```markdown
- v1.0 (!{timestamp}): Planning complete
  - All tasks analyzed and sized appropriately
  - All technical decisions documented in ADRs
  - All GitHub issues created and linked
  - Ready for implementation phase
```

## Completion Output

```
✅ Plan Successfully Completed!

📋 Final Statistics:
- Plan version: v1.0 (FROZEN)
- Total tasks: !{total_tasks}
- All tasks analyzed: !{analyzed_count}
- GitHub issues: !{total_issues}
- Questions answered: [N]
- ADRs created: [N]

📁 Deliverables:
- .claude/plan.md (v1.0) - Complete work breakdown
- .claude/questions.json - All decisions documented
- .claude/ADRs/*.md - Architecture decisions
- GitHub Issues #XXX-#YYY - Ready for implementation

🚀 Next Steps:
1. Review the complete plan at .claude/plan.md
2. Check GitHub project board for issue organization
3. Run `/dev/implement [ISSUE_NUMBER]` to start implementation

The plan is now frozen at v1.0. Any changes require a new planning cycle.
```

## Important Notes

- Version 1.0 indicates planning is complete and frozen
- No further changes should be made without explicit version bump
- All tasks must be in "analyzed" state before completion
- This phase is primarily verification and finalization