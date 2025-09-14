---
allowed-tools: Task, Write, Read, Edit, Bash(jq:*), Bash(git:*), Bash(python3:*), Bash(date:*), Bash(head:*), Bash(wc:*), Bash(tr:*), Bash(if:*), Bash([:*), Bash(sed:*)
argument-hint: [AUTO|SKILL_ID|DUE]
description: Spaced repetition review with adaptive scheduling, interleaving, and forgetting curve modeling
---

# /learn/review $ARGUMENTS

## Purpose
Implement research-based spaced repetition with adaptive scheduling, strategic interleaving, and forgetting curve modeling to maintain long-term retention of mastered skills. This command handles the critical maintenance phase of mastery learning to prevent skill decay.

## Initial Context
- Due reviews: !`jq -r --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" ".spacing_schedule | to_entries[] | select(.value.next_review <= $now) | .key" .claude/learn/student.json | head -10`
- Total mastered skills: !`jq -r ".mastery_boundary[]?" .claude/learn/student.json | wc -l | tr -d " "`
- Review statistics: !`jq -r "{total_mastered: (.mastery_boundary | length), overdue_reviews: ([.spacing_schedule | to_entries[] | select(.value.next_review <= \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\")] | length), avg_interval: ([.spacing_schedule | to_entries[].value.interval_days] | add / length)}" .claude/learn/student.json`
- Similar skills (for interleaving): !`if [ "$ARGUMENTS" != "AUTO" ] && [ "$ARGUMENTS" != "DUE" ]; then jq -r --arg skill "$ARGUMENTS" ".domain_clusters[] | select(.skills | contains([\$skill])) | .skills[] | select(. != \$skill)" .claude/learn/semantic_index.json | head -3; fi`
- Review session ID: !`date +"%Y%m%d_%H%M%S" | sed "s/^/review_/"`

## Spaced Review Framework

### Research Foundation
- **Distributed Practice**: Spacing intervals based on SuperMemo SM-2+ algorithm
- **Forgetting Curve**: Ebbinghaus exponential decay with individual adjustment
- **Testing Effect**: Retrieval practice strengthens memory better than re-study
- **Interleaving Effect**: Mixed practice of similar skills improves discrimination
- **Desirable Difficulties**: Strategic challenges that enhance long-term retention

## Review Procedure

### Phase 1: Review Selection and Scheduling

#### 1.1 Review Target Identification
```bash
if [ "$ARGUMENTS" = "AUTO" ] || [ "$ARGUMENTS" = "DUE" ]; then
    # Select skills due for review
    REVIEW_TARGETS=$(jq -r --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" ".spacing_schedule | to_entries[] | select(.value.next_review <= $now) | .key" .claude/learn/student.json | head -10)
    REVIEW_MODE="SCHEDULED"
elif [ -n "$ARGUMENTS" ]; then
    # Specific skill review requested
    REVIEW_TARGETS="$ARGUMENTS"
    REVIEW_MODE="MANUAL"
else
    echo "ERROR: No review target specified. Use AUTO, DUE, or specific SKILL_ID"
    exit 1
fi

if [ -z "$REVIEW_TARGETS" ]; then
    echo "✅ No reviews currently due. Next review: $(get_next_review_date)"
    exit 0
fi

echo "📅 Review session starting for: $REVIEW_TARGETS"
```

#### 1.2 Forgetting Curve Analysis
Calculate current retention probability for each skill:
```python
# Use Task tool for retention modeling
def calculate_retention_probability(skill_data, current_time):
    """
    Model retention using modified Ebbinghaus forgetting curve
    R(t) = e^(-t/S) where S is memory strength
    """
    last_review = skill_data['last_review']
    interval_days = skill_data['interval_days'] 
    review_count = skill_data['review_count']
    last_performance = skill_data.get('last_performance', 0.85)
    
    # Time elapsed since last review
    time_elapsed = (current_time - last_review).total_days()
    
    # Memory strength (increases with successful reviews)
    memory_strength = interval_days * (1 + 0.1 * review_count) * last_performance
    
    # Retention probability
    retention_prob = math.exp(-time_elapsed / memory_strength)
    
    return retention_prob

# Calculate for all review targets
retention_analysis = {}
for skill_id in review_targets:
    skill_data = get_spacing_data(skill_id)
    retention_prob = calculate_retention_probability(skill_data, datetime.now())
    retention_analysis[skill_id] = {
        'retention_probability': retention_prob,
        'urgency_score': 1.0 - retention_prob,
        'days_overdue': max(0, days_since_due_date(skill_id))
    }
```

#### 1.3 Interleaving Strategy Selection
Determine optimal skill mixing for the review session:
```markdown
**Agent Prompt for Interleaving Design:**

Design an interleaving strategy for review session with skills: $REVIEW_TARGETS

**Research Guidance:**
- **Benefits**: Improved discrimination between similar concepts, enhanced transfer
- **Optimal Conditions**: Skills should be similar enough to be confusable but distinct
- **Timing**: Interleave during practice problems, not during initial instruction review

**Available Similar Skills:**
$(for skill in $REVIEW_TARGETS; do
    echo "- $skill: Similar to $(get_similar_skills $skill)"
done)

**Interleaving Strategies:**
1. **Random Interleaving**: Completely mixed order (best for retention)
2. **Blocked Interleaving**: Mini-blocks of 2-3 items per skill (easier, still beneficial)
3. **Strategic Interleaving**: Alternate most confusable skills
4. **No Interleaving**: Block each skill separately (use when skills are very dissimilar)

**Selection Criteria:**
- High similarity → Strategic or Random interleaving
- Moderate similarity → Blocked interleaving  
- Low similarity → No interleaving needed
- Student preference/difficulty tolerance

**Output Required:**
- Recommended interleaving strategy
- Practice problem ordering
- Justification based on skill similarity and research
```

### Phase 2: Adaptive Review Assessment

#### 2.1 Retention Probe Generation
Create brief retention checks tailored to review context:
```bash
# Generate review items for each skill
for SKILL_ID in $REVIEW_TARGETS; do
    RETENTION_PROB=$(jq -r --arg skill "$SKILL_ID" '.retention_analysis[$skill].retention_probability' .claude/learn/cache/retention_analysis.json)
    
    # Adaptive item selection based on predicted retention
    if (( $(echo "$RETENTION_PROB > 0.8" | bc -l) )); then
        ITEM_DIFFICULTY="realistic"  # High retention → challenging items
        ITEM_COUNT=2
    elif (( $(echo "$RETENTION_PROB > 0.5" | bc -l) )); then
        ITEM_DIFFICULTY="easy"      # Moderate retention → moderate items
        ITEM_COUNT=3
    else
        ITEM_DIFFICULTY="trivial"   # Low retention → easier items
        ITEM_COUNT=4
    fi
    
    # Generate review items
    SESSION_ID=$(date +"%Y%m%d_%H%M%S" | sed "s/^/review_/")
    cat >> .claude/learn/cache/review_items_${SESSION_ID}.json << EOF
{
    "skill_id": "$SKILL_ID",
    "predicted_retention": $RETENTION_PROB,
    "item_difficulty": "$ITEM_DIFFICULTY", 
    "item_count": $ITEM_COUNT,
    "items": $(generate_review_items "$SKILL_ID" "$ITEM_DIFFICULTY" "$ITEM_COUNT")
}
EOF
done
```

#### 2.2 Review Item Administration
Implement adaptive review with immediate feedback:
```markdown
**Agent Prompt for Review Item Generation:**

Generate $ITEM_COUNT review items for skill: "$SKILL_ID"

**Review Context:**
- Skill last reviewed: $(get_last_review_date "$SKILL_ID")
- Predicted retention: $(printf "%.0f" $(echo "$RETENTION_PROB * 100" | bc))%
- Target difficulty: $ITEM_DIFFICULTY
- Review type: SPACED_REPETITION

**Item Requirements:**
- **Format**: 3-option multiple choice (consistent with teaching phase)
- **Difficulty**: $ITEM_DIFFICULTY level problems
- **Focus**: Test retention and application, not re-learning
- **Efficiency**: Quick assessment, not extensive practice
- **Discrimination**: Can distinguish retained vs. forgotten knowledge

**Review-Specific Adaptations:**
- **High Retention (>80%)**: Challenging transfer problems, different contexts
- **Moderate Retention (50-80%)**: Standard application problems
- **Low Retention (<50%)**: Foundational problems, key concepts

**Cognitive Considerations:**
- Test automaticity and fluency, not effortful problem-solving
- Include recognition of common patterns/procedures  
- Focus on critical discriminations between similar concepts
- Quick response time expectations (30-60 seconds per item)

Generate items optimized for retention assessment and spacing algorithm updates.
```

### Phase 3: Interleaved Practice Implementation

#### 3.1 Optimal Practice Ordering
Implement research-based interleaving strategy:
```python
def create_interleaved_sequence(skills_items, strategy):
    """
    Create optimal practice sequence based on interleaving research
    """
    if strategy == "RANDOM_INTERLEAVING":
        # Completely randomized order (best for retention)
        all_items = []
        for skill, items in skills_items.items():
            all_items.extend([(skill, item) for item in items])
        random.shuffle(all_items)
        return all_items
        
    elif strategy == "BLOCKED_INTERLEAVING":
        # Mini-blocks of 2-3 items per skill
        sequence = []
        max_items = max(len(items) for items in skills_items.values())
        
        for block in range(0, max_items, 2):  # Blocks of 2
            skills = list(skills_items.keys())
            random.shuffle(skills)  # Random skill order each block
            
            for skill in skills:
                items = skills_items[skill][block:block+2]
                sequence.extend([(skill, item) for item in items])
                
        return sequence
        
    elif strategy == "STRATEGIC_INTERLEAVING":
        # Alternate most similar/confusable skills
        similar_pairs = identify_confusable_pairs(skills_items.keys())
        return create_strategic_alternation(skills_items, similar_pairs)
        
    else:  # NO_INTERLEAVING
        # Block each skill separately
        sequence = []
        for skill, items in skills_items.items():
            sequence.extend([(skill, item) for item in items])
        return sequence
```

#### 3.2 Review Session Execution
```bash
# Execute interleaved review sequence
SESSION_ID=$(date +"%Y%m%d_%H%M%S" | sed "s/^/review_/")
SEQUENCE_FILE=".claude/learn/cache/review_sequence_${SESSION_ID}.json"
RESPONSES_FILE=".claude/learn/sessions/${SESSION_ID}_responses.json"

# Initialize response tracking
echo '{
    "session_id": "${SESSION_ID}",
    "session_type": "SPACED_REVIEW",
    "interleaving_strategy": "'$INTERLEAVING_STRATEGY'",
    "start_time": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "responses": []
}' > "$RESPONSES_FILE"

# Present items in interleaved sequence
jq -c '.sequence[]' "$SEQUENCE_FILE" | while read -r sequence_item; do
    SKILL_ID=$(echo "$sequence_item" | jq -r '.skill_id')
    ITEM_DATA=$(echo "$sequence_item" | jq -r '.item')
    
    echo "Presenting $SKILL_ID review item..."
    
    # Collect response (simplified - would be interactive)
    START_TIME=$(date +%s)
    # STUDENT_RESPONSE collected here
    END_TIME=$(date +%s)
    RESPONSE_TIME=$((END_TIME - START_TIME))
    
    # Record response
    RESPONSE_RECORD='{
        "skill_id": "'$SKILL_ID'",
        "item_id": "'$(echo "$ITEM_DATA" | jq -r '.item_id')'",
        "response": "'$STUDENT_RESPONSE'",
        "correct": '$(validate_response "$ITEM_DATA" "$STUDENT_RESPONSE")',
        "response_time": '$RESPONSE_TIME',
        "confidence": '$STUDENT_CONFIDENCE',
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }'
    
    jq --argjson resp "$RESPONSE_RECORD" '.responses += [$resp]' "$RESPONSES_FILE" > tmp.json
    mv tmp.json "$RESPONSES_FILE"
    
    # Immediate feedback for incorrect responses
    if [ "$(validate_response "$ITEM_DATA" "$STUDENT_RESPONSE")" = "false" ]; then
        echo "❌ Incorrect. The correct answer is: $(get_correct_answer "$ITEM_DATA")"
        echo "💡 Quick reminder: $(get_concept_reminder "$SKILL_ID")"
    else
        echo "✅ Correct!"
    fi
done
```

### Phase 4: Performance Analysis and Scheduling Updates

#### 4.1 Review Performance Calculation
```bash
# Calculate performance metrics for each reviewed skill
for SKILL_ID in $REVIEW_TARGETS; do
    SKILL_RESPONSES=$(jq --arg skill "$SKILL_ID" '[.responses[] | select(.skill_id == $skill)]' "$RESPONSES_FILE")
    
    TOTAL_ITEMS=$(echo "$SKILL_RESPONSES" | jq 'length')
    CORRECT_ITEMS=$(echo "$SKILL_RESPONSES" | jq '[.[] | select(.correct == true)] | length') 
    ACCURACY=$(jq -n "$CORRECT_ITEMS / $TOTAL_ITEMS")
    AVG_RT=$(echo "$SKILL_RESPONSES" | jq '[.[].response_time] | add / length')
    AVG_CONFIDENCE=$(echo "$SKILL_RESPONSES" | jq '[.[].confidence] | add / length')
    
    # Performance classification
    if (( $(echo "$ACCURACY >= 0.85 && $AVG_RT <= 45" | bc -l) )); then
        PERFORMANCE="STRONG_RETENTION"
        INTERVAL_MULTIPLIER=2.5  # Increase interval significantly
    elif (( $(echo "$ACCURACY >= 0.70" | bc -l) )); then
        PERFORMANCE="ADEQUATE_RETENTION"  
        INTERVAL_MULTIPLIER=1.3  # Modest interval increase
    elif (( $(echo "$ACCURACY >= 0.50" | bc -l) )); then
        PERFORMANCE="WEAK_RETENTION"
        INTERVAL_MULTIPLIER=0.8  # Slightly shorter interval
    else
        PERFORMANCE="FAILED_RETENTION"
        INTERVAL_MULTIPLIER=0.5  # Much shorter interval, needs re-teaching
    fi
    
    echo "$SKILL_ID: $PERFORMANCE ($ACCURACY accuracy, ${AVG_RT}s avg)"
done
```

#### 4.2 Adaptive Spacing Algorithm (SM-2+ Enhanced)
```python
def update_spacing_schedule(skill_id, performance_data):
    """
    Enhanced SM-2 algorithm with individual adjustment
    """
    current_schedule = get_current_schedule(skill_id)
    
    accuracy = performance_data['accuracy']
    response_time = performance_data['avg_response_time']
    confidence = performance_data['avg_confidence']
    
    # Calculate composite performance score
    performance_score = (
        accuracy * 0.6 +                    # Primary factor
        (1.0 - min(response_time/60, 1.0)) * 0.2 +  # Speed bonus
        confidence * 0.2                     # Confidence factor
    )
    
    # Update ease factor (SM-2 enhancement)
    if performance_score >= 0.85:
        ease_adjustment = 0.1
    elif performance_score >= 0.70:
        ease_adjustment = 0.0
    else:
        ease_adjustment = -0.2
        
    new_ease = max(1.3, current_schedule['ease_factor'] + ease_adjustment)
    
    # Calculate next interval
    if performance_score >= 0.60:  # Successful review
        if current_schedule['review_count'] == 0:
            next_interval = 1
        elif current_schedule['review_count'] == 1:
            next_interval = 6
        else:
            next_interval = int(current_schedule['interval_days'] * new_ease)
    else:  # Failed review - reset to beginning
        next_interval = 1
        new_ease = max(1.3, new_ease - 0.2)  # Penalize ease factor
        
    # Individual adjustment based on historical performance
    personal_multiplier = calculate_personal_multiplier(skill_id)
    next_interval = int(next_interval * personal_multiplier)
    
    return {
        'next_review': (datetime.now() + timedelta(days=next_interval)).isoformat(),
        'interval_days': next_interval,
        'ease_factor': new_ease,
        'review_count': current_schedule['review_count'] + 1,
        'last_performance': performance_score,
        'performance_history': current_schedule.get('performance_history', []) + [performance_score]
    }
```

#### 4.3 Schedule Updates and Persistence
```bash
# Update spacing schedules for all reviewed skills
for SKILL_ID in $REVIEW_TARGETS; do
    PERFORMANCE_DATA=$(get_skill_performance "$SKILL_ID" "$RESPONSES_FILE")
    NEW_SCHEDULE=$(calculate_new_schedule "$SKILL_ID" "$PERFORMANCE_DATA")
    
    # Update student.json with new scheduling
    jq --arg skill "$SKILL_ID" --argjson schedule "$NEW_SCHEDULE" '
        .spacing_schedule[$skill] = $schedule |
        .metadata.last_active = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    ' .claude/learn/student.json > .claude/learn/student_temp.json
    mv .claude/learn/student_temp.json .claude/learn/student.json
    
    echo "📅 $SKILL_ID: Next review in $(echo "$NEW_SCHEDULE" | jq -r '.interval_days') days"
done
```

### Phase 5: Retention Failure Handling

#### 5.1 Failed Retention Analysis
```bash
# Identify skills with retention failure
FAILED_SKILLS=$(jq -r '.responses | group_by(.skill_id) | map(select(([.[] | .correct] | add / length) < 0.5)) | .[].skill_id' "$RESPONSES_FILE")

if [ -n "$FAILED_SKILLS" ]; then
    echo "⚠️ Retention failure detected for: $FAILED_SKILLS"
    
    for FAILED_SKILL in $FAILED_SKILLS; do
        # Mark skill as needing re-teaching
        jq --arg skill "$FAILED_SKILL" '
            .[$skill].state = "RETENTION_FAILED" |
            .[$skill].retention_failure = {
                "failed_review_session": env.SESSION_ID,
                "failure_date": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
                "last_accuracy": ('$(get_skill_accuracy "$FAILED_SKILL" "$RESPONSES_FILE")')
            }
        ' .claude/learn/skills.json > .claude/learn/skills_temp.json
        mv .claude/learn/skills_temp.json .claude/learn/skills.json
        
        # Add back to teaching stack
        jq --arg skill "$FAILED_SKILL" '
            .stack = [$skill] + .stack |
            .current_focus = .stack[0] |
            .failed_skills[$skill] = {
                "fail_count": ((.failed_skills[$skill].fail_count // 0) + 1),
                "last_failed": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
                "failure_type": "RETENTION_DECAY"
            }
        ' .claude/learn/stack.json > .claude/learn/stack_temp.json
        mv .claude/learn/stack_temp.json .claude/learn/stack.json
    done
fi
```

#### 5.2 Prerequisite Decay Check
```bash
# Check if retention failures affect dependent skills
for FAILED_SKILL in $FAILED_SKILLS; do
    DEPENDENT_SKILLS=$(jq -r --arg failed "$FAILED_SKILL" '
        to_entries[] | 
        select(.value.prerequisites[]? == $failed) |
        .key
    ' .claude/learn/skills.json)
    
    if [ -n "$DEPENDENT_SKILLS" ]; then
        echo "🔗 Prerequisite failure may affect: $DEPENDENT_SKILLS"
        
        # Schedule dependent skills for assessment
        for DEPENDENT in $DEPENDENT_SKILLS; do
            jq --arg skill "$DEPENDENT" '
                .spacing_schedule[$skill].next_review = (now | strftime("%Y-%m-%dT%H:%M:%SZ")) |
                .spacing_schedule[$skill].review_reason = "PREREQUISITE_DECAY_CHECK"
            ' .claude/learn/student.json > .claude/learn/student_temp.json
            mv .claude/learn/student_temp.json .claude/learn/student.json
        done
    fi
done
```

### Phase 6: Session Documentation and Analytics

#### 6.1 Comprehensive Review Session Log
```bash
cat > .claude/learn/sessions/${SESSION_ID}.json << EOF
{
    "session_id": "${SESSION_ID}",
    "session_type": "SPACED_REVIEW",
    "start_time": "$START_TIME",
    "end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_minutes": $((($(date +%s) - $(date -d "$START_TIME" +%s)) / 60)),
    "review_strategy": {
        "interleaving_strategy": "$INTERLEAVING_STRATEGY",
        "skills_reviewed": $(echo "$REVIEW_TARGETS" | jq -R 'split(" ")'),
        "total_items_administered": $(jq '.responses | length' "$RESPONSES_FILE"),
        "adaptive_scheduling": true
    },
    "performance_summary": {
        "overall_accuracy": $(jq '[.responses[].correct] | add / length' "$RESPONSES_FILE"),
        "avg_response_time": $(jq '[.responses[].response_time] | add / length' "$RESPONSES_FILE"),
        "avg_confidence": $(jq '[.responses[].confidence] | add / length' "$RESPONSES_FILE"),
        "skills_with_strong_retention": $(count_strong_retention_skills),
        "skills_with_failed_retention": $(count_failed_retention_skills)
    },
    "scheduling_updates": {
        "intervals_increased": $(count_interval_increases),
        "intervals_decreased": $(count_interval_decreases),
        "skills_returned_to_teaching": $(echo "$FAILED_SKILLS" | wc -w | tr -d ' '),
        "next_review_dates": $(generate_next_review_summary)
    },
    "interleaving_effects": {
        "discrimination_accuracy": $(calculate_discrimination_accuracy),
        "context_switching_cost": $(calculate_switching_cost),
        "interleaving_benefit_estimate": $(estimate_interleaving_benefit)
    },
    "retention_modeling": {
        "forgetting_curve_updates": $(count_forgetting_curve_updates),
        "personal_multiplier_adjustments": $(count_personal_adjustments),
        "predicted_vs_actual_retention": $(calculate_prediction_accuracy)
    }
}
EOF
```

#### 6.2 Review Analytics and Reporting
```markdown
# Spaced Review Report: ${SESSION_ID}

## 📊 Session Overview
- **Skills Reviewed**: $(echo "$REVIEW_TARGETS" | wc -w) skills
- **Duration**: $((($(date +%s) - $(date -d "$START_TIME" +%s)) / 60)) minutes
- **Strategy**: $INTERLEAVING_STRATEGY interleaving
- **Items**: $(jq '.responses | length' "$RESPONSES_FILE") total review items

## 🎯 Performance Results
- **Overall Accuracy**: $(printf "%.0f" $(echo "$(jq '[.responses[].correct] | add / length' "$RESPONSES_FILE") * 100" | bc))%
- **Average Response Time**: $(jq '[.responses[].response_time] | add / length' "$RESPONSES_FILE") seconds
- **Confidence Calibration**: $(calculate_confidence_calibration)%

### Individual Skill Performance
$(for skill in $REVIEW_TARGETS; do
    SKILL_ACCURACY=$(get_skill_accuracy "$skill" "$RESPONSES_FILE")
    SKILL_RT=$(get_skill_response_time "$skill" "$RESPONSES_FILE")
    PERFORMANCE=$(classify_skill_performance "$skill")
    echo "- **$skill**: $(printf "%.0f" $(echo "$SKILL_ACCURACY * 100" | bc))% accuracy, ${SKILL_RT}s avg → $PERFORMANCE"
done)

## 📅 Spacing Schedule Updates
$(for skill in $REVIEW_TARGETS; do
    NEXT_INTERVAL=$(jq -r --arg skill "$skill" '.spacing_schedule[$skill].interval_days' .claude/learn/student.json)
    NEXT_DATE=$(jq -r --arg skill "$skill" '.spacing_schedule[$skill].next_review' .claude/learn/student.json)
    echo "- **$skill**: Next review in $NEXT_INTERVAL days ($NEXT_DATE)"
done)

## 🔄 Retention Management
- **Strong Retention**: $(count_strong_retention_skills) skills (intervals increased)
- **Adequate Retention**: $(count_adequate_retention_skills) skills (intervals maintained)  
- **Weak Retention**: $(count_weak_retention_skills) skills (intervals decreased)
- **Failed Retention**: $(count_failed_retention_skills) skills (returned to teaching)

$(if [ -n "$FAILED_SKILLS" ]; then
echo "### ⚠️ Retention Failures Requiring Re-teaching"
for skill in $FAILED_SKILLS; do
    echo "- **$skill**: $(get_skill_accuracy "$skill" "$RESPONSES_FILE")% accuracy - added back to teaching stack"
done
fi)

## 🧠 Interleaving Analysis  
- **Strategy Used**: $INTERLEAVING_STRATEGY
- **Discrimination Benefit**: $(estimate_discrimination_benefit)% improvement in similar skill distinction
- **Context Switching**: $(calculate_switching_cost)ms average cost per skill change
- **Overall Benefit**: $(estimate_overall_interleaving_benefit) for long-term retention

## 🔮 Predictive Accuracy
- **Retention Predictions**: $(calculate_prediction_accuracy)% accurate
- **Forgetting Curve Model**: Updated with $(count_forgetting_curve_updates) new data points
- **Personal Patterns**: $(count_personal_adjustments) individual adjustment factors updated

## 📈 Next Actions
$(if [ -n "$FAILED_SKILLS" ]; then
    echo "1. **Re-teach Failed Skills**: $(echo "$FAILED_SKILLS" | tr ' ' ', ') need instruction before dependent skills decay"
else
    echo "1. **Continue Spaced Practice**: All skills showing adequate retention"
fi)
2. **Next Review Session**: $(get_next_review_date) ($(get_next_review_count) skills due)
3. **Optimize Intervals**: $(get_optimization_recommendations)

The spaced review system successfully maintained skill retention through research-based scheduling and strategic interleaving.
```

#### 6.3 Git Integration
```bash
git add .claude/learn/
git commit -m "review: spaced practice → $(printf "%.0f" $(echo "$(jq '[.responses[].correct] | add / length' "$RESPONSES_FILE") * 100" | bc))% retention (${SESSION_ID})

Review Session Results:
- Skills: $(echo "$REVIEW_TARGETS" | wc -w) reviewed with $INTERLEAVING_STRATEGY interleaving
- Performance: $(jq '[.responses[].correct] | add / length' "$RESPONSES_FILE" | xargs printf "%.0f%%") accuracy, $(jq '[.responses[].response_time] | add / length' "$RESPONSES_FILE")s avg RT
- Scheduling: $(count_interval_increases) intervals increased, $(count_interval_decreases) decreased

Retention Management:
$(if [ -n "$FAILED_SKILLS" ]; then
    echo "- ⚠️ $(echo "$FAILED_SKILLS" | wc -w | tr -d ' ') skills failed retention → returned to teaching stack"
else  
    echo "- ✅ All skills showing adequate retention"
fi)
- Forgetting curves updated with $(jq '.responses | length' "$RESPONSES_FILE") new data points
- Next reviews: $(get_next_review_count) skills due $(get_next_review_date)

🧠 Interleaving effects: $(estimate_interleaving_benefit)% discrimination improvement, $(calculate_switching_cost)ms switching cost"
```

## Error Handling and Edge Cases

### Scheduling Failures
- **No Due Reviews**: Graceful exit with next review information
- **Retention Prediction Errors**: Fallback to standard spacing intervals
- **Schedule Conflicts**: Priority-based review ordering
- **Overdue Accumulation**: Batch processing with load balancing

### Performance Assessment Issues
- **Inconsistent Responses**: Flag for manual review, adjust confidence in predictions
- **Technical Interruptions**: Robust session recovery with partial credit
- **Motivation/Fatigue Effects**: Adaptive session length and difficulty

### Interleaving Complications
- **Skill Similarity Miscalculation**: Fallback to blocked practice
- **Confusion from Interleaving**: Dynamic adjustment to reduce mixing
- **Performance Degradation**: Switch to blocked practice mid-session

## Integration Points

This command integrates with:
- **`/learn/teach`**: Handles retention failures by returning skills to teaching
- **`/learn/assess`**: May trigger assessment of dependent skills  
- **`/learn/session`**: Session scheduling and management coordination
- **`/learn/progress`**: Long-term retention analytics and visualization
- **All learning commands**: Maintains the mastery boundary through active maintenance

## File Outputs Created/Modified

- `.claude/learn/student.json` - Updated spacing schedules and retention data
- `.claude/learn/skills.json` - Retention failure states and scheduling metadata  
- `.claude/learn/sessions/[session_id].json` - Complete review session log
- `.claude/learn/cache/retention_analysis.json` - Forgetting curve modeling results
- Git commit documenting review performance and scheduling updates

The spaced review system implements research-grounded retention maintenance with adaptive scheduling, strategic interleaving, and comprehensive analytics to ensure long-term skill preservation.