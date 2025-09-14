---
allowed-tools: Task, Write, Read, Edit, Bash(jq:*), Bash(python3:*), Bash(git:*), Bash(if:*), Bash([:*), Bash(echo:*), Bash(date:*), Bash(sed:*)
argument-hint: [SKILL_ID_OR_AUTO]
description: Adaptive skill assessment using CAT with IRT item selection and BKT mastery classification
---

# /learn/assess $ARGUMENTS

## Purpose
Conduct adaptive skill assessment using Computerized Adaptive Testing (CAT) with Item Response Theory (IRT) item selection and Bayesian Knowledge Tracing (BKT) for mastery classification. This command implements research-grounded assessment that drives the mastery learning stack algorithm.

## Initial Context
- Target skill: !`if [ "$ARGUMENTS" = "auto" ]; then jq -r ".current_focus // .stack[0] // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi`
- Current skill state: !`SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".current_focus // .stack[0] // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi); jq -r ".[$SKILL].state // \"NOT_FOUND\"" .claude/learn/skills.json`
- Student θ estimate: !`SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".current_focus // .stack[0] // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi); jq -r ".skill_estimates[$SKILL].theta // .global_metrics.global_theta // 0.0" .claude/learn/student.json`
- Available items: !`SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".current_focus // .stack[0] // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi); jq -r ".[$SKILL].item_bank | (.trivial // []) + (.easy // []) + (.realistic // []) | length" .claude/learn/skills.json`
- Mastery criteria: !`jq -r ".mastery_criteria | {threshold, successive_relearning_sessions}" .claude/learn/config.json`
- Generated session ID: !`date +"%Y%m%d_%H%M%S" | sed "s/^/session_/"`

## Assessment Algorithm Overview

### Research Foundation
- **CAT Implementation**: Maximum Fisher Information item selection with GMIR exposure control
- **IRT Model**: 3-Parameter Logistic (3PL) with difficulty, discrimination, and guessing parameters
- **BKT Updates**: Bayesian Knowledge Tracing with prior knowledge, learning rate, slip, and guess parameters
- **Mastery Threshold**: 85% with successive relearning requirement across sessions
- **Precision Target**: SE(θ) < 0.30 for reliable estimates

## Assessment Procedure

### Phase 1: Pre-Assessment Validation

#### 1.1 Skill and Context Validation
```bash
# Validate skill exists and get assessment readiness
SKILL_ID=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".current_focus // .stack[0] // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi)

if [ "$SKILL_ID" = "none" ]; then
    echo "ERROR: No skill to assess. Run /learn/start to initialize learning domain."
    exit 1
fi

SKILL_STATE=$(SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".current_focus // .stack[0] // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi); jq -r ".[$SKILL].state // \"NOT_FOUND\"" .claude/learn/skills.json)
if [ "$SKILL_STATE" = "NOT_FOUND" ]; then
    echo "ERROR: Skill $SKILL_ID not found in skills.json"
    exit 1
fi

AVAILABLE_ITEMS=$(SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".current_focus // .stack[0] // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi); jq -r ".[$SKILL].item_bank | (.trivial // []) + (.easy // []) + (.realistic // []) | length" .claude/learn/skills.json)
if [ "$AVAILABLE_ITEMS" = "0" ]; then
    echo "WARNING: No items available for $SKILL_ID. Generating item bank first."
    # Trigger item generation (simplified for now)
fi
```

#### 1.2 Assessment History Check
Check for recent assessments and successive relearning requirements:
```bash
jq --arg skill "$SKILL_ID" --arg threshold "$(jq -r '.mastery_criteria.successive_relearning_sessions' .claude/learn/config.json)" '
  .skill_estimates[$skill] as $est |
  if ($est.mastery_probability >= 0.85 and $est.successive_passes < ($threshold | tonumber)) then
    "SUCCESSIVE_RELEARNING_REQUIRED"
  elif ($est.mastery_probability >= 0.85) then  
    "ALREADY_MASTERED"
  else
    "READY_FOR_ASSESSMENT"
  end
' .claude/learn/student.json > .claude/learn/cache/assessment_status.txt
```

### Phase 2: CAT Assessment Engine

#### 2.1 Initialize Assessment Session
Create session tracking structure:
```python
# Use Task tool to initialize CAT assessment
session_data = {
    "session_id": "$(date +"%Y%m%d_%H%M%S" | sed "s/^/session_/")",
    "skill_id": skill_id,
    "assessment_type": "CAT_DIAGNOSTIC",
    "start_time": datetime.utcnow().isoformat(),
    "theta_estimates": [],
    "se_estimates": [],
    "items_administered": [],
    "responses": [],
    "stopping_criteria_met": False,
    "final_classification": None
}
```

#### 2.2 CAT Item Selection Algorithm
Implement Maximum Fisher Information (MFI) with exposure control:

```markdown
**Agent Prompt for CAT Implementation:**

You are implementing a CAT assessment engine. Follow this algorithm precisely:

**Input Parameters:**
- Current θ estimate: From student.json for this skill
- Available items with IRT parameters from skill item bank
- Max items: 12, Min items: 3
- Precision target: SE(θ) < 0.30
- Exposure limit: 30% per item

**Item Selection Algorithm (MFI with GMIR):**
1. For each unused item i, calculate Fisher Information: I(θ) = [P'i(θ)]² / [Pi(θ)(1-Pi(θ))]
2. Apply GMIR exposure control: penalize overexposed items  
3. Select item with highest adjusted information
4. Present item to student (simulated for now)
5. Collect response (correct/incorrect), response time, confidence
6. Update θ using Maximum Likelihood Estimation
7. Calculate SE(θ) using Fisher Information
8. Check stopping criteria

**Stopping Rules (OR condition):**
- SE(θ) < 0.30 (precision achieved)
- 12 items administered (item limit)
- No remaining items with sufficient information

**Output Required:**
- Final θ estimate with SE
- All item responses with parameters
- Mastery probability using BKT
- Assessment classification: MASTERED/UNREADY/DECOMPOSE_NEEDED

Implement this as a complete assessment simulation with realistic student response patterns.
```

#### 2.3 Response Collection and Processing
For each item administered:
```python
# Collect comprehensive response data
item_response = {
    "item_id": selected_item_id,
    "difficulty_parameter": item_a,
    "discrimination_parameter": item_b, 
    "guessing_parameter": item_c,
    "theta_at_administration": current_theta,
    "predicted_probability": calculate_3pl_probability(theta, a, b, c),
    "actual_response": student_response,  # 1 = correct, 0 = incorrect
    "response_time_seconds": response_time,
    "confidence_rating": confidence,
    "item_information": calculate_fisher_info(theta, a, b, c),
    "timestamp": datetime.utcnow().isoformat()
}

# Update θ estimate using MLE
new_theta, new_se = update_theta_mle(responses_so_far)
```

### Phase 3: Bayesian Knowledge Tracing Updates

#### 3.1 BKT Parameter Application
Apply research-calibrated BKT parameters:
```python
# BKT parameters from config
bkt_params = {
    "prior_knowledge": 0.1,    # P(Lo)
    "learning_rate": 0.3,      # P(T)  
    "slip_rate": 0.1,          # P(S)
    "guess_rate": 0.25         # P(G)
}

# Update knowledge state probability
def update_bkt(prior_p_mastery, response_correct, bkt_params):
    if response_correct:
        # Evidence of mastery
        numerator = prior_p_mastery * (1 - bkt_params["slip_rate"])
        denominator = (numerator + 
                      (1 - prior_p_mastery) * bkt_params["guess_rate"])
    else:
        # Evidence of non-mastery  
        numerator = prior_p_mastery * bkt_params["slip_rate"]
        denominator = (numerator + 
                      (1 - prior_p_mastery) * (1 - bkt_params["guess_rate"]))
    
    return numerator / denominator if denominator > 0 else prior_p_mastery
```

#### 3.2 Mastery Classification
Classify skill state based on multiple criteria:
```python
def classify_mastery(theta, se_theta, bkt_probability, config):
    mastery_threshold = config["mastery_criteria"]["threshold"]
    
    # Multi-criteria classification
    criteria = {
        "irt_mastery": theta > 0.5,  # Above average ability
        "precision_adequate": se_theta < 0.30,
        "bkt_probability": bkt_probability >= mastery_threshold,
        "confidence_calibrated": abs(confidence - accuracy) < 0.2
    }
    
    if all([criteria["bkt_probability"], criteria["precision_adequate"]]):
        return "MASTERED"
    elif theta < -1.0 and se_theta < 0.50:
        return "UNREADY"  # Clear evidence of lack of mastery
    else:
        return "DECOMPOSE_NEEDED"  # Ambiguous, need prerequisite analysis
```

### Phase 4: Stack Management and Updates

#### 4.1 Skill State Updates
Update skills.json with assessment results:
```bash
# Update skill mastery data
jq --arg skill "$SKILL_ID" --argjson theta "$FINAL_THETA" --argjson se "$FINAL_SE" --argjson prob "$MASTERY_PROB" '
  .[$skill].mastery_data.theta_estimate = $theta |
  .[$skill].mastery_data.theta_se = $se |
  .[$skill].mastery_data.mastery_probability = $prob |
  .[$skill].mastery_data.last_assessed = now | strftime("%Y-%m-%dT%H:%M:%SZ") |
  .[$skill].mastery_data.assessment_count += 1 |
  .[$skill].state = $classification
' .claude/learn/skills.json > .claude/learn/skills_temp.json

mv .claude/learn/skills_temp.json .claude/learn/skills.json
```

#### 4.2 Stack Algorithm Implementation
Update processing stack based on assessment results:

**MASTERED Skills:**
```bash
# Remove from stack, update mastery boundary
jq --arg skill "$SKILL_ID" '
  .stack = (.stack - [$skill]) |
  .processed += [$skill] |
  .current_focus = (.stack[0] // null) |
  .processing_history += [{
    "skill_id": $skill,
    "action": "ASSESSED", 
    "result": "MASTERED",
    "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    "session_id": "$(date +"%Y%m%d_%H%M%S" | sed "s/^/session_/")"
  }]
' .claude/learn/stack.json > .claude/learn/stack_temp.json
```

**UNREADY Skills (Need Decomposition):**
```bash
# Add back to top of stack, trigger decomposition
jq --arg skill "$SKILL_ID" '
  .failed_skills[$skill] = {
    "fail_count": ((.failed_skills[$skill].fail_count // 0) + 1),
    "last_failed": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    "prerequisite_gaps": [],
    "next_attempt_after": (now + 7*24*3600 | strftime("%Y-%m-%dT%H:%M:%SZ"))
  } |
  .stack = [$skill] + .stack |
  .current_focus = $skill
' .claude/learn/stack.json > .claude/learn/stack_temp.json
```

### Phase 5: Skill Decomposition (for UNREADY skills)

#### 5.1 Prerequisite Analysis
For skills classified as UNREADY, identify missing prerequisites:
```markdown
**Agent Prompt for Skill Decomposition:**

The student failed to demonstrate mastery of: "$SKILL_ID"

**Assessment Results:**
- Final θ: [calculated value]
- Mastery probability: [calculated value]
- Response accuracy: [calculated value]
- Items attempted: [calculated value]

**Task:** Identify 2-4 prerequisite skills that must be mastered before this skill can be learned.

**Requirements:**
1. Each prerequisite should address a specific knowledge/skill gap revealed by the assessment
2. Prerequisites should be MORE BASIC than the failed skill
3. Mastering the prerequisites should make the original skill learnable
4. Each prerequisite must be concretely assessable

**Before proposing prerequisites:**
1. Run semantic analysis on each proposed prerequisite using /learn/identify
2. Only add genuinely new skills to the DAG
3. Establish proper prerequisite relationships

**Output:** List of prerequisite skill descriptions ready for semantic deduplication.
```

#### 5.2 Prerequisite Integration
Add identified prerequisites to DAG:
```bash
# For each prerequisite identified
for PREREQ in $PREREQUISITES; do
    # Run through semantic identification
    echo "Processing prerequisite: $PREREQ"
    
    # This would call /learn/identify internally
    PREREQ_RESULT=$(./learn/identify.md "$PREREQ")
    
    # Extract canonical ID and add to stack
    PREREQ_ID=$(echo "$PREREQ_RESULT" | jq -r '.canonical_id')
    
    # Update stack with new prerequisite at top
    jq --arg prereq "$PREREQ_ID" --arg skill "$SKILL_ID" '
      .stack = [$prereq] + .stack |
      .current_focus = $prereq
    ' .claude/learn/stack.json > .claude/learn/stack_temp.json
    
    mv .claude/learn/stack_temp.json .claude/learn/stack.json
done
```

### Phase 6: Session Logging and Analytics

#### 6.1 Comprehensive Session Recording
Create detailed session log:
```bash
SESSION_ID=$(date +"%Y%m%d_%H%M%S" | sed "s/^/session_/")
cat > .claude/learn/sessions/${SESSION_ID}.json << EOF
{
  "session_id": "${SESSION_ID}",
  "skill_id": "$SKILL_ID",
  "session_type": "CAT_ASSESSMENT",
  "start_time": "$START_TIME", 
  "end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_minutes": $DURATION,
  "assessment_results": {
    "final_theta": $FINAL_THETA,
    "final_se": $FINAL_SE,
    "mastery_probability": $MASTERY_PROB,
    "classification": "$CLASSIFICATION",
    "items_administered": $ITEM_COUNT,
    "accuracy": $ACCURACY,
    "avg_response_time": $AVG_RT,
    "confidence_accuracy": $CONF_ACC
  },
  "item_responses": $ALL_RESPONSES,
  "stack_changes": {
    "before": $STACK_BEFORE,
    "after": $STACK_AFTER,
    "prerequisites_added": $NEW_PREREQS
  },
  "next_actions": $NEXT_ACTIONS
}
EOF
```

#### 6.2 Student Model Updates
Update comprehensive student profile:
```bash
jq --arg skill "$SKILL_ID" --argjson theta "$FINAL_THETA" --argjson se "$FINAL_SE" '
  .skill_estimates[$skill] = {
    "theta": $theta,
    "se": $se, 
    "mastery_probability": $MASTERY_PROB,
    "last_updated": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
  } |
  .learning_history.sessions_completed += 1 |
  .learning_history.total_learning_time_minutes += $DURATION |
  .learning_history.skills_attempted += 1 |
  (.learning_history.skills_mastered += (if $CLASSIFICATION == "MASTERED" then 1 else 0 end)) |
  .learning_history.total_items_attempted += $ITEM_COUNT |
  .learning_history.total_items_correct += $CORRECT_COUNT |
  .metadata.last_active = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
' .claude/learn/student.json > .claude/learn/student_temp.json

mv .claude/learn/student_temp.json .claude/learn/student.json
```

### Phase 7: Results and Next Steps

#### 7.1 Assessment Report Generation
```markdown
# Assessment Report: $SKILL_ID

## Results Summary  
- **Classification**: MASTERED | UNREADY | DECOMPOSE_NEEDED
- **Mastery Probability**: X.XX (BKT)
- **Ability Estimate**: θ = X.XX ± X.XX (IRT)
- **Items Administered**: X of 12 maximum
- **Response Accuracy**: XX% (X/X correct)
- **Average Response Time**: XX seconds
- **Confidence Calibration**: XX% accuracy

## Assessment Details
- **Session ID**: ${SESSION_ID}
- **Duration**: XX minutes
- **Stopping Criterion**: Precision target | Item limit | Information exhaustion
- **CAT Efficiency**: XX% reduction vs. fixed-length test

## Actions Taken
- ✅ Updated skill state in DAG
- ✅ Modified processing stack  
- ✅ Updated student model parameters
- ✅ Created detailed session log
- ✅ [If applicable] Added X prerequisites to assessment queue

## Next Steps
- **If MASTERED**: Skill removed from stack, dependents may be unlocked
- **If UNREADY**: Prerequisites identified and added to top of stack
- **If DECOMPOSE**: Run /learn/expand to identify missing prerequisites

## Stack Status
- **Current Focus**: Next skill to process
- **Remaining Stack**: X skills queued for assessment/teaching
- **Mastery Boundary**: X skills mastered so far

Ready for next assessment cycle or teaching phase.
```

#### 7.2 Git Integration
```bash
git add .claude/learn/
git commit -m "assess: evaluated $SKILL_ID → $CLASSIFICATION (${SESSION_ID})

Assessment Results:
- Mastery probability: $MASTERY_PROB (BKT)
- Ability estimate: θ=$FINAL_THETA ± $FINAL_SE (CAT/IRT)
- Items administered: $ITEM_COUNT with $ACCURACY accuracy
- Response time: ${AVG_RT}s avg, confidence calibration: $CONF_ACC

Stack Changes:
- $(if [ "$CLASSIFICATION" = "MASTERED" ]; then echo "Removed from stack, unlocked dependents"; elif [ "$CLASSIFICATION" = "UNREADY" ]; then echo "Added $PREREQ_COUNT prerequisites to top"; else echo "Flagged for decomposition"; fi)

🎯 Next: $(jq -r '.current_focus // "Stack empty - learning complete!"' .claude/learn/stack.json)"
```

## Error Handling and Edge Cases

### Assessment Failures
- **No Items Available**: Trigger item bank generation or use fallback assessment
- **CAT Convergence Issues**: Fall back to fixed-length assessment  
- **Student Dropout**: Save partial results, schedule continuation
- **Technical Issues**: Robust session recovery with state persistence

### Skill State Edge Cases
- **Already Mastered**: Confirm with abbreviated assessment or skip
- **Recent Assessment**: Respect spacing intervals, defer if too soon
- **Missing Prerequisites**: Validate DAG integrity, fix relationships

### Stack Management Issues  
- **Circular Dependencies**: Detect and resolve cycles in prerequisite graph
- **Empty Stack**: Learning complete, generate completion report
- **Deep Stack**: Implement stack depth limits, suggest learning path optimization

## Integration Points

This command integrates with:
- **`/learn/start`**: Processes initialized skill DAG and student model
- **`/learn/identify`**: Semantic deduplication of newly identified prerequisites  
- **`/learn/expand`**: Explicit prerequisite analysis for ambiguous cases
- **`/learn/teach`**: Teaching phase for skills with mastered prerequisites
- **`/learn/session`**: Session management and scheduling
- **`/learn/progress`**: Analytics and visualization of learning state

## File Outputs Created/Modified

- `.claude/learn/skills.json` - Updated skill states and mastery data
- `.claude/learn/student.json` - Updated student model and estimates  
- `.claude/learn/stack.json` - Modified processing queue based on results
- `.claude/learn/sessions/[session_id].json` - Detailed assessment log
- Git commit with comprehensive assessment documentation

The adaptive assessment system provides the foundation for data-driven mastery learning progression with research-grounded CAT, IRT, and BKT implementations.