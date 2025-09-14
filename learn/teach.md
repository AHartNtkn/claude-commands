---
allowed-tools: Task, Write, Read, Edit, Bash(jq:*), Bash(git:*), Bash(if:*), Bash([:*), Bash(echo:*), Bash(date:*), Bash(sed:*), Bash(head:*), Bash(tr:*), Bash(while:*), Bash(read:*)
argument-hint: [SKILL_ID_OR_AUTO]
description: Research-based skill teaching with worked examples, faded practice, and mastery assessment
---

# /learn/teach $ARGUMENTS

## Purpose
Implement research-grounded skill teaching using Cognitive Load Theory, worked examples with faded guidance, and immediate formative assessment. This command handles the instruction phase when all prerequisites are mastered and the student is ready to learn the target skill.

## Initial Context
- Ready skill: !`if [ "$ARGUMENTS" = "auto" ]; then jq -r ".stack[] as \$skill | select((.[\$skill].state == \"UNREADY\") and (.[\$skill].prerequisites | length == 0 or all(.[\$skill].prerequisites[] as \$prereq | .skill_estimates[\$prereq].mastery_probability >= 0.85))) | \$skill" .claude/learn/skills.json .claude/learn/student.json | head -1 | tr -d "\n" || echo "none"; else echo "$ARGUMENTS"; fi`
- Skill details: !`SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".stack[] as \$skill | select((.[\$skill].state == \"UNREADY\") and (.[\$skill].prerequisites | length == 0 or all(.[\$skill].prerequisites[] as \$prereq | .skill_estimates[\$prereq].mastery_probability >= 0.85))) | \$skill" .claude/learn/skills.json .claude/learn/student.json | head -1 | tr -d "\n" || echo "none"; else echo "$ARGUMENTS"; fi); jq -r ".[\$SKILL] // \"NOT_FOUND\"" .claude/learn/skills.json`
- Prerequisites status: !`SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".stack[] as \$skill | select((.[\$skill].state == \"UNREADY\") and (.[\$skill].prerequisites | length == 0 or all(.[\$skill].prerequisites[] as \$prereq | .skill_estimates[\$prereq].mastery_probability >= 0.85))) | \$skill" .claude/learn/skills.json .claude/learn/student.json | head -1 | tr -d "\n" || echo "none"; else echo "$ARGUMENTS"; fi); jq -r ".[\$SKILL].prerequisites[]?" .claude/learn/skills.json | while read prereq; do echo "$prereq: $(jq -r ".skill_estimates[\"$prereq\"].mastery_probability // 0.0" .claude/learn/student.json)"; done`
- Teaching configuration: !`jq -r ".teaching" .claude/learn/config.json`
- Teaching session ID: !`date +"%Y%m%d_%H%M%S" | sed "s/^/teach_/"`

## Teaching Framework

### Research Foundation
- **Cognitive Load Theory**: Manage intrinsic, extraneous, and germane cognitive load
- **Worked Example Effect**: Lead with complete solutions, fade to independent practice
- **Expertise Reversal Effect**: Adapt guidance level to student's current ability
- **Testing Effect**: Frequent low-stakes retrieval practice with immediate feedback
- **Desirable Difficulties**: Strategic challenges that improve long-term retention

## Teaching Procedure

### Phase 1: Teaching Readiness Verification

#### 1.1 Prerequisite Mastery Confirmation
```bash
SKILL_ID=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".stack[] as \$skill | select((.\[\$skill].state == \"UNREADY\") and (.\[\$skill].prerequisites | length == 0 or all(.\[\$skill].prerequisites[] as \$prereq | .skill_estimates\[\$prereq].mastery_probability >= 0.85))) | \$skill" .claude/learn/skills.json .claude/learn/student.json | head -1 | tr -d "\n" || echo "none"; else echo "$ARGUMENTS"; fi)

if [ "$SKILL_ID" = "none" ]; then
    echo "ERROR: No skill ready for teaching. All skills either lack mastered prerequisites or are already mastered."
    exit 1
fi

# Verify all prerequisites are mastered (≥85% mastery probability)
UNMASTERED_PREREQS=$(jq -r --arg skill "$SKILL_ID" '
    .[$skill].prerequisites[]? as $prereq |
    select(.skill_estimates[$prereq].mastery_probability < 0.85) |
    $prereq
' .claude/learn/skills.json .claude/learn/student.json)

if [ -n "$UNMASTERED_PREREQS" ]; then
    echo "ERROR: Prerequisites not yet mastered: $UNMASTERED_PREREQS"
    echo "Run assessment on these skills first."
    exit 1
fi
```

#### 1.2 Teaching Materials Preparation Check
```bash
# Check if teaching materials exist
MATERIALS_EXIST=$(jq -r --arg skill "$SKILL_ID" '
    .[$skill].teaching_materials.explanation != null and
    (.[$skill].teaching_materials.worked_examples | length) > 0
' .claude/learn/skills.json)

if [ "$MATERIALS_EXIST" = "false" ]; then
    echo "Generating teaching materials for $SKILL_ID..."
    # Trigger material generation
fi
```

### Phase 2: Teaching Content Generation

#### 2.1 Skill Explanation Generation
Create comprehensive skill explanation using Task tool:
```markdown
**Agent Prompt for Skill Explanation:**

Generate a complete teaching explanation for: "$SKILL_ID"

**Context:**
- Skill details: From skills.json for this skill
- Prerequisites mastered: From student.json mastery probabilities
- Student's estimated ability: $(jq -r ".skill_estimates[\"$SKILL_ID\"].theta // 0.0" .claude/learn/student.json)

**Explanation Requirements:**
1. **Motivation**: Why is this skill important? What problems does it solve?
2. **Conceptual Foundation**: Core principles and concepts (building on mastered prerequisites)
3. **Procedure/Algorithm**: Step-by-step method for applying the skill
4. **Key Insights**: Critical understanding points that prevent common errors
5. **Connection to Prerequisites**: How this builds on what they already know
6. **Application Context**: When and where to use this skill

**Cognitive Load Management:**
- Use familiar examples that connect to prerequisites
- Present information in digestible chunks
- Avoid extraneous details that don't aid skill acquisition
- Use visual/spatial organization when helpful
- Provide memory aids for complex procedures

**Output Format:**
- Clear, conversational explanation
- Logical progression from concepts to application
- Concrete examples throughout
- Anticipate and address likely confusion points

Generate a complete explanation that prepares the student for the worked examples phase.
```

#### 2.2 Worked Examples Creation
Generate progressive worked examples using research principles:
```markdown
**Agent Prompt for Worked Examples:**

Create 3 worked examples for skill: "$SKILL_ID"

**Example Progression (CLT-Based):**
1. **Foundational Example**: Demonstrates core procedure with minimal complexity
2. **Elaborated Example**: Adds realistic complexity while maintaining clear structure  
3. **Transfer Example**: Shows application in slightly different context

**For Each Example:**
- **Problem Statement**: Clear, concrete problem
- **Complete Solution**: Every step explicitly shown
- **Strategic Commentary**: Why each step was taken (not just what)
- **Common Pitfalls**: What errors to avoid and why
- **Connection to Concept**: How this illustrates the underlying principle

**Worked Example Best Practices:**
- Show ALL intermediate steps, don't skip "obvious" ones
- Use consistent notation and terminology
- Highlight decision points and reasoning
- Include self-explanation prompts (optional, not mandatory)
- Use problems that will have analogous practice items

**Cognitive Load Considerations:**
- Start simple, add complexity gradually
- Use split-attention prevention (integrate text/visuals)
- Provide completion problems (partially worked examples) in later phases
- Ensure examples are directly relevant to skill mastery

Create examples that will enable successful independent practice.
```

#### 2.3 Practice Problem Generation with Faded Guidance
Create three difficulty levels with graduated support:
```python
# Use Task tool for practice problem generation
practice_structure = {
    "trivial": {
        "problem_count": 2,
        "guidance_level": "high",
        "scaffolding": "step_prompts",
        "feedback": "immediate_corrective"
    },
    "easy": {
        "problem_count": 2, 
        "guidance_level": "moderate",
        "scaffolding": "strategic_hints",
        "feedback": "immediate_with_explanation"
    },
    "realistic": {
        "problem_count": 2,
        "guidance_level": "minimal", 
        "scaffolding": "error_detection_only",
        "feedback": "delayed_comprehensive"
    }
}

# Generate problems for each level
for level, config in practice_structure.items():
    generate_practice_problems(skill_id, level, config)
```

### Phase 3: Interactive Teaching Sequence

#### 3.1 Conceptual Teaching Phase
Present explanation with comprehension checks:
```markdown
# Teaching Session: $SKILL_ID

## 📚 Understanding the Skill

[Generated explanation will appear here]

### 🎯 Key Takeaways
- [Bullet point summary of critical concepts]
- [Essential procedures to remember]
- [Common applications and contexts]

### ❓ Quick Understanding Check
Before we proceed to examples, let's verify understanding:

**Question**: [Conceptual question about the skill]
A) [Plausible option focusing on surface features]
B) [Correct conceptual understanding]  
C) [Common misconception]

*Think about your answer, then continue to see the worked examples.*
```

#### 3.2 Worked Examples Phase
Present examples with strategic commentary:
```markdown
## 📖 Worked Examples

### Example 1: Foundational Application
**Problem**: [Clear, concrete problem statement]

**Solution Approach**:
*Step 1*: [First action with reasoning]
- Why we do this: [Strategic explanation]
- Watch out for: [Common error]

*Step 2*: [Next action]
- This connects to [prerequisite skill] because...
- The key insight here is...

*Step 3*: [Final steps]
- Final answer: [Result]
- Verification: [How to check correctness]

**🔑 Key Pattern**: [What makes this approach work]

### Example 2: [Continue with elaborated example]
[Similar structure with increased complexity]

### Example 3: [Transfer example]
[Different context, same underlying skill]
```

### Phase 4: Faded Practice Implementation

#### 4.1 Trivial Level Practice (High Guidance)
```markdown
## 🏃‍♂️ Practice: Getting Started

### Problem 1
**Setup**: [Simple problem statement]

**Your Turn**: Follow these steps:
1. First, identify [key element]. What do you see?
2. Next, apply [specific procedure]. Show your work.
3. Finally, [verification step]. Does this make sense?

**Hints Available**: 
- Hint 1: [Procedural reminder]
- Hint 2: [Strategic guidance]  
- Solution: [Complete solution if needed]

*Response*: [Student provides answer]
**Feedback**: [Immediate corrective with explanation]
```

#### 4.2 Easy Level Practice (Moderate Guidance)
```markdown
## 🚶‍♂️ Practice: Building Confidence

### Problem 1  
**Problem**: [Realistic but straightforward]

**Strategy Reminder**: Remember the key steps are [brief procedure summary]

*Your approach*: [Student works independently]
**Feedback**: [Immediate with strategic commentary]

### Problem 2
[Similar structure, different surface features]
```

#### 4.3 Realistic Level Practice (Minimal Guidance)
```markdown
## 🏋️‍♂️ Practice: Mastery Challenge

### Problem 1
**Real-World Application**: [Authentic problem context]

*Complete solution*: [Student works with minimal support]
**Self-Check**: Does your answer [verification criteria]?

**Feedback**: [Comprehensive analysis after completion]

### Problem 2  
[Transfer problem with different surface features]
```

### Phase 5: Mastery Assessment

#### 5.1 Generate Assessment Quiz
Create final mastery quiz with research-based design:
```bash
# Generate 3-option MCQ quiz
SESSION_ID=$(date +"%Y%m%d_%H%M%S" | sed "s/^/teach_/")
cat > .claude/learn/quizzes/${SESSION_ID}_mastery_quiz.json << EOF
{
  "quiz_id": "${SESSION_ID}_mastery",
  "skill_id": "$SKILL_ID",
  "quiz_type": "MASTERY_ASSESSMENT",
  "items": [
    $(for i in {1..6}; do
        # Generate quiz item using task agent
        ITEM=$(generate_quiz_item "$SKILL_ID" "realistic")
        echo "$ITEM,"
    done | sed '$ s/,$//') 
  ],
  "passing_criteria": {
    "minimum_correct": 5,
    "mastery_threshold": 0.83
  },
  "metadata": {
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "teaching_session": "${SESSION_ID}"
  }
}
EOF
```

#### 5.2 Quiz Item Generation with Misconception-Based Distractors
```markdown
**Agent Prompt for Quiz Items:**

Generate 6 quiz items for skill mastery assessment: "$SKILL_ID"

**Item Requirements:**
- **3-option multiple choice** (A, B, C)
- **Realistic difficulty**: Problems representative of actual skill use
- **Misconception-based distractors**: Wrong answers based on common errors
- **Randomized correct position**: Don't always put correct answer in same position
- **Anti-gaming**: Prevent pattern recognition or elimination strategies

**For Each Item:**
1. **Stem**: Clear problem requiring skill application
2. **Correct Answer**: Demonstrably right solution
3. **Distractor 1**: Based on common procedural error
4. **Distractor 2**: Based on conceptual misunderstanding
5. **Rationale**: Why correct answer is right, why distractors are wrong

**Quality Criteria:**
- All options must be plausible to someone with partial knowledge
- Distractors should reflect actual student thinking patterns
- No "all of the above" or "none of the above" options
- Surface features shouldn't give away correct answer
- Items should require genuine skill application, not memorization

**Cognitive Level**: Focus on application and analysis level problems that demonstrate skill mastery.

Generate items that reliably distinguish mastery from partial knowledge.
```

### Phase 6: Assessment Administration and Scoring

#### 6.1 Administer Mastery Quiz
```bash
# Present quiz items one at a time
QUIZ_FILE=".claude/learn/quizzes/${SESSION_ID}_mastery_quiz.json"
RESPONSE_FILE=".claude/learn/sessions/${SESSION_ID}_responses.json"

# Initialize response tracking
echo '{"responses": [], "start_time": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$RESPONSE_FILE"

# For each quiz item (simplified - actual implementation would be interactive)
jq -c '.items[]' "$QUIZ_FILE" | while read -r item; do
    ITEM_ID=$(echo "$item" | jq -r '.item_id')
    
    # Present item and collect response (simulated for command specification)
    echo "Presenting item: $ITEM_ID"
    # STUDENT_RESPONSE would be collected interactively
    
    # Record response with timing
    RESPONSE_DATA='{
        "item_id": "'$ITEM_ID'",
        "response": "'$STUDENT_RESPONSE'",
        "correct": '$(echo "$item" | jq '.correct_answer == env.STUDENT_RESPONSE')',
        "response_time": 45,
        "confidence": 0.8,
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }'
    
    jq --argjson resp "$RESPONSE_DATA" '.responses += [$resp]' "$RESPONSE_FILE" > tmp.json
    mv tmp.json "$RESPONSE_FILE"
done
```

#### 6.2 Mastery Classification
```bash
# Calculate quiz performance
TOTAL_ITEMS=$(jq '.responses | length' "$RESPONSE_FILE")
CORRECT_ITEMS=$(jq '[.responses[] | select(.correct == true)] | length' "$RESPONSE_FILE")
ACCURACY=$(jq -n "$CORRECT_ITEMS / $TOTAL_ITEMS")

# Apply mastery criteria (5/6 correct = 83% threshold)
MASTERY_THRESHOLD=0.83
MASTERY_ACHIEVED=$(jq -n "($ACCURACY >= $MASTERY_THRESHOLD)")

if [ "$MASTERY_ACHIEVED" = "true" ]; then
    SKILL_STATE="MASTERED"
    echo "🎉 Mastery achieved: $CORRECT_ITEMS/$TOTAL_ITEMS correct ($ACCURACY)"
else
    SKILL_STATE="FAILED_TEACHING"
    echo "📚 More practice needed: $CORRECT_ITEMS/$TOTAL_ITEMS correct ($ACCURACY)"
fi
```

### Phase 7: Learning State Updates

#### 7.1 Update Skill Mastery Status
```bash
if [ "$SKILL_STATE" = "MASTERED" ]; then
    # Mark skill as mastered
    jq --arg skill "$SKILL_ID" --argjson accuracy "$ACCURACY" '
        .[$skill].state = "MASTERED" |
        .[$skill].mastery_data.mastery_probability = 0.95 |
        .[$skill].mastery_data.last_assessed = (now | strftime("%Y-%m-%dT%H:%M:%SZ")) |
        .[$skill].mastery_data.successive_passes = 1 |
        .[$skill].teaching_history += [{
            "session_id": env.SESSION_ID,
            "result": "MASTERED",
            "quiz_accuracy": $accuracy,
            "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }]
    ' .claude/learn/skills.json > .claude/learn/skills_temp.json
    mv .claude/learn/skills_temp.json .claude/learn/skills.json
    
    # Update student mastery boundary
    jq --arg skill "$SKILL_ID" '
        .mastery_boundary += [$skill] |
        .mastery_boundary |= unique |
        .learning_history.skills_mastered += 1
    ' .claude/learn/student.json > .claude/learn/student_temp.json
    mv .claude/learn/student_temp.json .claude/learn/student.json
    
    # Remove from stack
    jq --arg skill "$SKILL_ID" '
        .stack = (.stack - [$skill]) |
        .processed += [$skill] |
        .current_focus = (.stack[0] // null)
    ' .claude/learn/stack.json > .claude/learn/stack_temp.json
    mv .claude/learn/stack_temp.json .claude/learn/stack.json
    
else
    # Teaching failed - needs more work
    jq --arg skill "$SKILL_ID" --argjson accuracy "$ACCURACY" '
        .[$skill].state = "NEEDS_RETEACHING" |
        .[$skill].teaching_history += [{
            "session_id": env.SESSION_ID,
            "result": "FAILED",
            "quiz_accuracy": $accuracy,
            "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }]
    ' .claude/learn/skills.json > .claude/learn/skills_temp.json
    mv .claude/learn/skills_temp.json .claude/learn/skills.json
    
    # Move to bottom of stack for retry later
    jq --arg skill "$SKILL_ID" '
        .stack = ((.stack - [$skill]) + [$skill]) |
        .failed_skills[$skill] = {
            "fail_count": ((.failed_skills[$skill].fail_count // 0) + 1),
            "last_failed": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            "failure_type": "TEACHING_FAILED"
        }
    ' .claude/learn/stack.json > .claude/learn/stack_temp.json
    mv .claude/learn/stack_temp.json .claude/learn/stack.json
fi
```

#### 7.2 Unlock Dependent Skills
```bash
if [ "$SKILL_STATE" = "MASTERED" ]; then
    # Find skills that now have all prerequisites mastered
    NEWLY_READY=$(jq -r --arg mastered "$SKILL_ID" '
        to_entries[] |
        select(.value.state == "UNREADY" and (.value.prerequisites // []) != [] and 
               all(.value.prerequisites[] as $prereq | 
                   .[$prereq].state == "MASTERED" or 
                   ($prereq == $mastered))) |
        .key
    ' .claude/learn/skills.json)
    
    # Add newly ready skills to stack
    for READY_SKILL in $NEWLY_READY; do
        jq --arg ready "$READY_SKILL" '
            if (.stack | contains([$ready]) | not) then
                .stack = [$ready] + .stack |
                .current_focus = .stack[0]
            else . end
        ' .claude/learn/stack.json > .claude/learn/stack_temp.json
        mv .claude/learn/stack_temp.json .claude/learn/stack.json
        
        echo "✅ Unlocked skill for teaching: $READY_SKILL"
    done
fi
```

### Phase 8: Session Documentation and Reporting

#### 8.1 Complete Teaching Session Log
```bash
cat > .claude/learn/sessions/${SESSION_ID}.json << EOF
{
  "session_id": "${SESSION_ID}",
  "session_type": "TEACHING",
  "skill_id": "$SKILL_ID", 
  "start_time": "$START_TIME",
  "end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_minutes": $((($(date +%s) - $(date -d "$START_TIME" +%s)) / 60)),
  "teaching_phases": {
    "explanation": {"completed": true, "duration_minutes": 5},
    "worked_examples": {"completed": true, "examples_count": 3},
    "trivial_practice": {"completed": true, "problems_solved": 2, "accuracy": 1.0},
    "easy_practice": {"completed": true, "problems_solved": 2, "accuracy": $(calculate_easy_accuracy)},
    "realistic_practice": {"completed": true, "problems_solved": 2, "accuracy": $(calculate_realistic_accuracy)}
  },
  "mastery_assessment": {
    "quiz_items": $TOTAL_ITEMS,
    "correct_responses": $CORRECT_ITEMS,
    "accuracy": $ACCURACY,
    "mastery_achieved": $MASTERY_ACHIEVED,
    "response_times": $(jq '[.responses[].response_time]' "$RESPONSE_FILE"),
    "confidence_ratings": $(jq '[.responses[].confidence]' "$RESPONSE_FILE")
  },
  "learning_outcomes": {
    "skill_state_before": "UNREADY",
    "skill_state_after": "$SKILL_STATE",
    "prerequisite_leverage": $(calculate_prerequisite_effectiveness),
    "teaching_effectiveness": $(calculate_teaching_effectiveness)
  },
  "next_actions": [
    $(if [ "$SKILL_STATE" = "MASTERED" ]; then
        echo '"Skill mastered - unlocked dependent skills"'
        for skill in $NEWLY_READY; do echo ', "Ready to teach: '$skill'"'; done
    else
        echo '"Reteaching needed with modified approach"'
    fi)
  ]
}
EOF
```

#### 8.2 Generate Teaching Report
```markdown
# Teaching Session Report: $SKILL_ID

## 🎯 Session Overview
- **Skill**: $SKILL_ID
- **Session ID**: ${SESSION_ID}  
- **Duration**: $DURATION_MINUTES minutes
- **Result**: $(if [ "$SKILL_STATE" = "MASTERED" ]; then echo "✅ MASTERED"; else echo "🔄 NEEDS RETEACHING"; fi)

## 📊 Teaching Sequence Results
- **Explanation Phase**: ✅ Core concepts presented with CLT principles
- **Worked Examples**: ✅ 3 progressive examples (foundational → elaborated → transfer)
- **Practice Phases**:
  - Trivial (high guidance): $(get_trivial_accuracy)% accuracy
  - Easy (moderate guidance): $(get_easy_accuracy)% accuracy  
  - Realistic (minimal guidance): $(get_realistic_accuracy)% accuracy

## 🧪 Mastery Assessment
- **Quiz Performance**: $CORRECT_ITEMS/$TOTAL_ITEMS correct ($(printf "%.0f" $(echo "$ACCURACY * 100" | bc))%)
- **Mastery Threshold**: 83% (5/6 items)
- **Result**: $(if [ "$MASTERY_ACHIEVED" = "true" ]; then echo "MASTERY ACHIEVED 🎉"; else echo "BELOW THRESHOLD - MORE PRACTICE NEEDED 📚"; fi)

## 🔄 Learning State Changes
- **Skill State**: UNREADY → $SKILL_STATE
- **Stack Updates**: $(if [ "$SKILL_STATE" = "MASTERED" ]; then echo "Removed from stack, unlocked $NEWLY_READY_COUNT dependent skills"; else echo "Moved to bottom of stack for reteaching"; fi)
- **Mastery Boundary**: $(if [ "$SKILL_STATE" = "MASTERED" ]; then echo "Expanded by 1 skill"; else echo "No change"; fi)

## 📈 Analytics
- **Average Response Time**: $(jq -r '[.responses[].response_time] | add / length' "$RESPONSE_FILE") seconds
- **Confidence Calibration**: $(calculate_confidence_calibration)%
- **Teaching Effectiveness**: $(calculate_teaching_effectiveness) (0-1 scale)

## 🔮 Next Steps
$(if [ "$SKILL_STATE" = "MASTERED" ]; then
    echo "- ✅ Skill successfully mastered through teaching sequence"
    echo "- 🚀 Ready to teach newly unlocked skills: $NEWLY_READY"
    echo "- 📊 Continue with next skill in learning progression"
else
    echo "- 🔄 Reteaching needed with modified approach"  
    echo "- 📝 Analyze quiz errors to identify specific gaps"
    echo "- 🎯 Consider additional prerequisite skills or simplified examples"
    echo "- ⏰ Schedule spaced review session"
fi)

The teaching session $(if [ "$SKILL_STATE" = "MASTERED" ]; then echo "successfully delivered"; else echo "identified areas needing"; fi) research-based instruction with measured learning outcomes.
```

#### 8.3 Git Integration
```bash
git add .claude/learn/
git commit -m "teach: $(if [ "$SKILL_STATE" = "MASTERED" ]; then echo "✅ mastered"; else echo "🔄 reteaching"; fi) $SKILL_ID → $ACCURACY quiz accuracy (${SESSION_ID})

Teaching Session Results:
- Worked examples: 3 progressive demonstrations  
- Faded practice: trivial($(get_trivial_accuracy)%) → easy($(get_easy_accuracy)%) → realistic($(get_realistic_accuracy)%)
- Mastery quiz: $CORRECT_ITEMS/$TOTAL_ITEMS correct ($(printf "%.0f" $(echo "$ACCURACY * 100" | bc))% vs 83% threshold)

Learning State Changes:
- Skill state: UNREADY → $SKILL_STATE
- $(if [ "$SKILL_STATE" = "MASTERED" ]; then echo "Unlocked $NEWLY_READY_COUNT dependent skills"; else echo "Flagged for reteaching with gap analysis"; fi)
- Stack focus: $(jq -r '.current_focus // "COMPLETE"' .claude/learn/stack.json)

🎯 Next: $(if [ "$SKILL_STATE" = "MASTERED" ] && [ -n "$NEWLY_READY" ]; then echo "Teach $(echo "$NEWLY_READY" | head -1)"; elif [ "$SKILL_STATE" = "MASTERED" ]; then jq -r '.current_focus // "Learning pathway complete!"' .claude/learn/stack.json; else echo "Analyze $SKILL_ID teaching failure and retry"; fi)"
```

## Error Handling and Edge Cases

### Teaching Failures
- **Low Practice Performance**: Adjust guidance level, provide additional scaffolding
- **Mastery Quiz Failure**: Detailed error analysis, targeted remediation
- **Prerequisite Gaps**: Re-verify prerequisites, identify missing foundational skills
- **Cognitive Overload**: Simplify examples, increase scaffolding, chunk instruction

### Content Generation Issues
- **Missing Teaching Materials**: Trigger automatic content generation with fallbacks
- **Inappropriate Examples**: Validate examples match student ability and context
- **Poor Quiz Items**: Ensure distractors are plausible and based on actual misconceptions

### Session Management
- **Student Dropout**: Save partial progress, enable session resumption
- **Technical Issues**: Robust state persistence and recovery procedures
- **Time Constraints**: Adaptive pacing based on student progress and engagement

## Integration Points

This command integrates with:
- **`/learn/assess`**: Builds on prerequisite mastery verification
- **`/learn/expand`**: Teaches skills after successful decomposition
- **`/learn/session`**: Session scheduling and management
- **`/learn/review`**: Spaced review of mastered skills
- **`/learn/progress`**: Learning analytics and visualization

## File Outputs Created/Modified

- `.claude/learn/skills.json` - Updated skill states and teaching history
- `.claude/learn/student.json` - Updated mastery boundary and learning metrics
- `.claude/learn/stack.json` - Stack management based on teaching results  
- `.claude/learn/sessions/[session_id].json` - Complete teaching session log
- `.claude/learn/quizzes/[session_id]_mastery_quiz.json` - Generated assessment
- `.claude/learn/teaching/[skill_id]/` - Generated teaching materials
- Git commit documenting teaching outcomes and state changes

The research-based teaching system provides structured skill instruction with cognitive load management, faded guidance, and reliable mastery assessment, completing the core mastery learning cycle.