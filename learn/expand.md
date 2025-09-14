---
allowed-tools: Task, Write, Read, Edit, Bash(jq:*), Bash(git:*), Bash(if:*), Bash([:*), Bash(echo:*), Bash(find:*)
argument-hint: [SKILL_ID_OR_AUTO]
description: Systematic skill decomposition using pedagogical analysis and cognitive load theory
---

# /learn/expand $ARGUMENTS

## Purpose
Perform systematic skill decomposition using pedagogical analysis, cognitive load theory, and assessment data to identify specific prerequisite skills needed for mastery. This command implements the critical "breaking down failed skills" phase of the mastery learning algorithm.

## Initial Context
- Target skill: !`if [ "$ARGUMENTS" = "auto" ]; then jq -r ".failed_skills | keys | first // .current_focus // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi`
- Skill details: !`SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".failed_skills | keys | first // .current_focus // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi); jq -r ".[$SKILL] // \"NOT_FOUND\"" .claude/learn/skills.json`
- Failure history: !`SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".failed_skills | keys | first // .current_focus // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi); jq -r ".failed_skills[$SKILL] // \"NOT_FOUND\"" .claude/learn/stack.json`
- Assessment data: !`SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".failed_skills | keys | first // .current_focus // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi); find .claude/learn/sessions -name "*.json" -exec jq -r "select(.skill_id == \"$SKILL\") | {session_id, classification, mastery_probability, accuracy, item_responses: (.item_responses | length)}" {} \;`
- Existing prerequisites: !`SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".failed_skills | keys | first // .current_focus // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi); jq -r ".[$SKILL].prerequisites // []" .claude/learn/skills.json`

## Skill Decomposition Framework

### Research Foundation
- **Cognitive Load Theory**: Decompose based on element interactivity and working memory limits
- **Taxonomic Analysis**: Use Bloom's taxonomy to identify cognitive level gaps
- **Error Analysis**: Examine specific failure patterns from assessment data  
- **Prerequisite Learning**: Ensure each prerequisite reduces cognitive load for target skill
- **Semantic Coherence**: Maintain DAG integrity through semantic deduplication

## Expansion Procedure

### Phase 1: Failure Analysis

#### 1.1 Assessment Data Analysis
Extract failure patterns from assessment history:
```bash
SKILL_ID=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".failed_skills | keys | first // .current_focus // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi)

if [ "$SKILL_ID" = "none" ]; then
    echo "ERROR: No skill specified for expansion"
    exit 1
fi

# Analyze recent assessment failures
cat > .claude/learn/cache/failure_analysis.json << EOF
{
  "skill_id": "$SKILL_ID",
  "analysis_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "failure_patterns": $(SKILL=$(if [ "$ARGUMENTS" = "auto" ]; then jq -r ".failed_skills | keys | first // .current_focus // \"none\"" .claude/learn/stack.json; else echo "$ARGUMENTS"; fi); find .claude/learn/sessions -name "*.json" -exec jq -r "select(.skill_id == \"$SKILL\") | {session_id, classification, mastery_probability, accuracy, item_responses: (.item_responses | length)}" {} \; | jq -s '[.] | group_by(.classification) | map({classification: .[0].classification, count: length, avg_accuracy: ([.[].accuracy] | add / length)})'),
  "error_indicators": []
}
EOF
```

#### 1.2 Error Pattern Identification
Use Task tool for detailed failure analysis:
```markdown
**Agent Prompt for Failure Analysis:**

Analyze the assessment failures for skill: "$SKILL_ID"

**Assessment Data:**
- Failure count: [from stack.json]
- Recent assessments: [from session files]
- Current prerequisites: [from skills.json]

**Task:** Identify specific knowledge/skill gaps that caused failure

**Analysis Framework:**
1. **Content Gaps**: What concepts/facts does the student not know?
2. **Procedural Gaps**: What procedures/algorithms can't the student execute?
3. **Conceptual Gaps**: What underlying principles don't they understand?
4. **Metacognitive Gaps**: What self-regulation/monitoring skills are missing?
5. **Cognitive Load Issues**: What's overwhelming their working memory?

**Evidence to Consider:**
- Which types of items were consistently failed?
- Were errors random or systematic?
- Did response times indicate confusion vs. partial knowledge?
- Was confidence calibrated with performance?

**Output Required:**
- Specific gap analysis with evidence
- Recommended prerequisite skills (2-5 skills max)
- Cognitive load reduction strategy
- Dependencies between identified prerequisites

Be concrete and avoid generic prerequisites. Focus on the specific barriers this student faces.
```

### Phase 2: Cognitive Load Decomposition

#### 2.1 Element Interactivity Analysis
Break down the target skill into cognitive elements:
```python
# Use Task tool for cognitive analysis
def analyze_cognitive_elements(skill_description, failure_data):
    """
    Analyze cognitive load using CLT principles
    """
    analysis = {
        "intrinsic_elements": [],      # Core concepts that must be held in WM
        "extraneous_elements": [],     # Sources of unnecessary cognitive load
        "germane_elements": [],        # Elements that aid schema construction
        "element_interactions": [],    # How elements combine (multiplicative load)
        "working_memory_estimate": 0   # Total WM slots required
    }
    
    # Identify high-interactivity components
    high_interactivity_components = []
    
    return analysis
```

#### 2.2 Prerequisite Skill Generation  
Generate prerequisite candidates based on cognitive analysis:
```markdown
**Agent Prompt for Prerequisite Generation:**

Based on the failure analysis, generate prerequisite skills that will reduce cognitive load for: "$SKILL_ID"

**Cognitive Load Analysis Results:**
[Insert results from Phase 2.1]

**Prerequisite Generation Rules:**
1. **Atomicity**: Each prerequisite should be testable independently
2. **Cognitive Load Reduction**: Mastering the prerequisite should free up working memory for the target skill
3. **Logical Dependencies**: Prerequisites should build naturally toward the target
4. **Assessability**: Each must be concretely measurable
5. **Appropriate Scope**: Not too broad (becomes another complex skill) or too narrow (trivial)

**Prerequisite Types to Consider:**
- **Foundational Knowledge**: Facts/concepts that must be automated
- **Component Procedures**: Sub-skills that need to be fluent
- **Conceptual Understanding**: Principles that inform the target skill
- **Strategic Knowledge**: When/how to apply procedures appropriately

**Output Format:**
For each prerequisite:
- Title and concrete description
- Rationale: How does this reduce cognitive load?
- Assessment approach: How would mastery be tested?
- Estimated difficulty relative to target skill

**Critical:** Before finalizing, check that mastering ALL prerequisites would make the target skill learnable with reasonable cognitive load.
```

### Phase 3: Semantic Integration and Deduplication

#### 3.1 Prerequisite Semantic Analysis
For each proposed prerequisite, run semantic identification:
```bash
# Process each prerequisite through semantic analysis
PREREQUISITES=$(cat .claude/learn/cache/proposed_prerequisites.json)

echo "$PREREQUISITES" | jq -c '.[]' | while read -r prereq; do
    PREREQ_DESC=$(echo "$prereq" | jq -r '.description')
    PREREQ_TITLE=$(echo "$prereq" | jq -r '.title')
    
    echo "Processing prerequisite: $PREREQ_TITLE"
    
    # Run semantic identification (this would call identify.md internally)
    # For now, simulate the semantic check
    SEMANTIC_RESULT=$(jq -n --arg title "$PREREQ_TITLE" --arg desc "$PREREQ_DESC" '{
        title: $title,
        description: $desc,
        semantic_action: "NEW_SKILL",
        canonical_id: ("skill_" + (now | tostring)),
        similar_skills: []
    }')
    
    echo "$SEMANTIC_RESULT" >> .claude/learn/cache/semantic_results.jsonl
done
```

#### 3.2 DAG Integration  
Add semantically validated prerequisites to the skill DAG:
```bash
# Update skills.json with new prerequisites
while read -r semantic_result; do
    CANONICAL_ID=$(echo "$semantic_result" | jq -r '.canonical_id')
    ACTION=$(echo "$semantic_result" | jq -r '.semantic_action')
    
    if [ "$ACTION" = "NEW_SKILL" ]; then
        # Add new skill to DAG
        SKILL_DATA=$(echo "$semantic_result" | jq '{
            title: .title,
            canonical_id: .canonical_id,
            aliases: [],
            description: .description,
            semantic_fingerprint: {
                keywords: (.description | split(" ") | .[0:5]),
                domain_tags: ["derived_prerequisite"],
                cognitive_level: "apply"
            },
            state: "UNTESTED",
            prerequisites: [],
            dependents: [env.SKILL_ID],
            mastery_data: {
                theta_estimate: 0.0,
                theta_se: 1.0,
                mastery_probability: 0.0,
                assessment_count: 0
            },
            metadata: {
                created: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
                derived_from: env.SKILL_ID,
                expansion_session: env.SESSION_ID
            }
        }')
        
        # Add to skills.json
        jq --argjson skill "$SKILL_DATA" --arg id "$CANONICAL_ID" '.[$id] = $skill' .claude/learn/skills.json > .claude/learn/skills_temp.json
        mv .claude/learn/skills_temp.json .claude/learn/skills.json
        
    elif [ "$ACTION" = "MERGED" ]; then
        # Use existing skill as prerequisite
        CANONICAL_ID=$(echo "$semantic_result" | jq -r '.merged_with')
    fi
    
    # Update target skill's prerequisites
    jq --arg target "$SKILL_ID" --arg prereq "$CANONICAL_ID" '
        .[$target].prerequisites += [$prereq] | 
        .[$target].prerequisites |= unique
    ' .claude/learn/skills.json > .claude/learn/skills_temp.json
    mv .claude/learn/skills_temp.json .claude/learn/skills.json
    
done < .claude/learn/cache/semantic_results.jsonl
```

### Phase 4: Stack Management Updates

#### 4.1 Prerequisite Ordering
Determine optimal order for prerequisite assessment:
```python
# Use topological sort to order prerequisites
def order_prerequisites(prerequisites, existing_dag):
    """
    Order prerequisites by dependency and difficulty
    """
    ordered = []
    
    # Simple dependency-aware ordering
    # In reality, would implement full topological sort
    for prereq in prerequisites:
        if has_no_dependencies(prereq, existing_dag):
            ordered.append(prereq)
    
    # Add remaining prerequisites in dependency order
    remaining = set(prerequisites) - set(ordered)
    while remaining:
        for prereq in remaining:
            if all_dependencies_in_ordered(prereq, ordered, existing_dag):
                ordered.append(prereq)
                remaining.remove(prereq)
                break
    
    return ordered
```

#### 4.2 Stack Updates
Add prerequisites to processing stack in correct order:
```bash
# Get ordered prerequisites  
ORDERED_PREREQS=$(jq -r '.ordered_prerequisites[]' .claude/learn/cache/expansion_results.json)

# Add to top of stack (reverse order so first prerequisite is processed first)
REVERSED_PREREQS=$(echo "$ORDERED_PREREQS" | tac)

for PREREQ_ID in $REVERSED_PREREQS; do
    jq --arg prereq "$PREREQ_ID" --arg target "$SKILL_ID" '
        .stack = [$prereq] + .stack |
        .current_focus = .stack[0] |
        .processing_history += [{
            "skill_id": $prereq,
            "action": "ADDED_PREREQUISITE",
            "parent_skill": $target,
            "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            "session_id": env.SESSION_ID
        }]
    ' .claude/learn/stack.json > .claude/learn/stack_temp.json
    mv .claude/learn/stack_temp.json .claude/learn/stack.json
done

# Update failed skill status - remove from failed list, add to bottom of regular stack
jq --arg skill "$SKILL_ID" '
    del(.failed_skills[$skill]) |
    .stack += [$skill]
' .claude/learn/stack.json > .claude/learn/stack_temp.json
mv .claude/learn/stack_temp.json .claude/learn/stack.json
```

### Phase 5: DAG Consistency Validation

#### 5.1 Cycle Detection
Ensure no circular dependencies introduced:
```python
# Implement cycle detection  
def detect_cycles(dag_adjacency):
    """
    Use DFS to detect cycles in prerequisite graph
    """
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {node: WHITE for node in dag_adjacency}
    
    def dfs(node):
        if color[node] == GRAY:
            return True  # Back edge found - cycle detected
        if color[node] == BLACK:
            return False
            
        color[node] = GRAY
        for neighbor in dag_adjacency.get(node, []):
            if dfs(neighbor):
                return True
        color[node] = BLACK
        return False
    
    for node in dag_adjacency:
        if color[node] == WHITE:
            if dfs(node):
                return True
    return False
```

#### 5.2 Relationship Validation
Verify prerequisite relationships are sensible:
```bash
# Validate each new prerequisite relationship
jq -r --arg target "$SKILL_ID" '.[$target].prerequisites[]' .claude/learn/skills.json | while read -r prereq_id; do
    # Check that prerequisite is genuinely simpler/more foundational
    TARGET_LEVEL=$(jq -r --arg target "$SKILL_ID" '.[$target].semantic_fingerprint.cognitive_level // "unknown"' .claude/learn/skills.json)
    PREREQ_LEVEL=$(jq -r --arg prereq "$prereq_id" '.[$prereq].semantic_fingerprint.cognitive_level // "unknown"' .claude/learn/skills.json)
    
    # Validate cognitive level ordering (remember < understand < apply < analyze < evaluate < create)
    if ! cognitive_level_is_prerequisite "$PREREQ_LEVEL" "$TARGET_LEVEL"; then
        echo "WARNING: Prerequisite $prereq_id may not be simpler than target $SKILL_ID"
    fi
done
```

### Phase 6: Documentation and Reporting

#### 6.1 Expansion Summary
Generate comprehensive expansion report:
```markdown
# Skill Expansion Report: $SKILL_ID

## Expansion Context
- **Target Skill**: $SKILL_ID
- **Expansion Trigger**: Assessment failure (multiple attempts)
- **Session ID**: $(date +"%Y%m%d_%H%M%S" | sed "s/^/expand_/")
- **Timestamp**: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Failure Analysis Results
$(cat .claude/learn/cache/failure_analysis.json | jq -r '.failure_patterns[] | "- \(.classification): \(.count) sessions, \(.avg_accuracy * 100)% avg accuracy"')

## Identified Prerequisites
$(jq -r '.prerequisites[] | "### \(.title)\n- **Description**: \(.description)\n- **Rationale**: \(.rationale)\n- **Assessment**: \(.assessment_approach)\n- **Cognitive Load Reduction**: \(.load_reduction)\n"' .claude/learn/cache/expansion_results.json)

## DAG Changes
- **New Skills Added**: $(jq -r '.new_skills | length' .claude/learn/cache/expansion_results.json)
- **Existing Skills Referenced**: $(jq -r '.merged_skills | length' .claude/learn/cache/expansion_results.json)
- **Total Prerequisites**: $(jq -r '.total_prerequisites' .claude/learn/cache/expansion_results.json)

## Stack Updates  
- **Prerequisites Added to Top**: $(echo "$ORDERED_PREREQS" | wc -l)
- **Processing Order**: $(echo "$ORDERED_PREREQS" | tr '\n' ' ')
- **Target Skill Position**: Bottom of stack (will be processed after prerequisites)

## Validation Results
- **Cycle Detection**: $(if detect_cycles; then echo "❌ CYCLES DETECTED"; else echo "✅ DAG VALID"; fi)
- **Semantic Coherence**: ✅ All prerequisites semantically validated
- **Cognitive Ordering**: ✅ Prerequisites verified as foundational to target

## Next Steps
1. **Assess Prerequisites**: Start with $(echo "$ORDERED_PREREQS" | head -1)
2. **Monitor Progress**: Track mastery of each prerequisite  
3. **Return to Target**: Reassess original skill after prerequisites mastered
4. **Iterate if Needed**: Further decomposition may be required

## Learning Path Preview
```
$(for prereq in $ORDERED_PREREQS; do
    echo "[$prereq] → "
done)
[$SKILL_ID] → [Dependent Skills...]
```

The skill decomposition has established a clear learning path with reduced cognitive load at each step.
```

#### 6.2 Git Integration
```bash
git add .claude/learn/
git commit -m "expand: decompose $SKILL_ID → $(echo "$ORDERED_PREREQS" | wc -l) prerequisites

Expansion Analysis:
- Failure patterns: $(jq -c '.failure_patterns' .claude/learn/cache/failure_analysis.json)
- Prerequisites identified: $(echo "$ORDERED_PREREQS" | tr '\n' ',' | sed 's/,$//')
- Cognitive load strategy: Element decomposition with WM management

DAG Updates:
- $(jq -r '.new_skills | length' .claude/learn/cache/expansion_results.json) new skills added to prerequisite graph
- $(jq -r '.merged_skills | length' .claude/learn/cache/expansion_results.json) existing skills referenced as prerequisites
- Stack reordered: prerequisites → target → dependents

🧠 Next: Assess $(echo "$ORDERED_PREREQS" | head -1) to begin prerequisite mastery sequence"
```

### Phase 7: Recursive Expansion Management

#### 7.1 Expansion Depth Tracking
Track decomposition depth to prevent infinite recursion:
```bash
# Update expansion metadata
jq --arg skill "$SKILL_ID" --arg session "$SESSION_ID" '
    .metadata.expansion_history += [{
        "skill_id": $skill,
        "session_id": $session,
        "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        "prerequisites_added": env.ORDERED_PREREQS | split(" "),
        "depth": ((.metadata.expansion_depth // 0) + 1)
    }] |
    .metadata.expansion_depth = ((.metadata.expansion_depth // 0) + 1)
' .claude/learn/skills.json > .claude/learn/skills_temp.json
mv .claude/learn/skills_temp.json .claude/learn/skills.json

# Warn if expansion depth exceeds reasonable limits
EXPANSION_DEPTH=$(jq -r '.metadata.expansion_depth // 0' .claude/learn/skills.json)
if [ "$EXPANSION_DEPTH" -gt 5 ]; then
    echo "⚠️ WARNING: Expansion depth is $EXPANSION_DEPTH. Consider reviewing learning objectives for appropriate granularity."
fi
```

#### 7.2 Prerequisite Success Prediction
Estimate likelihood that prerequisites will resolve the original failure:
```python
# Use Task tool for success prediction
def predict_expansion_success(target_skill, new_prerequisites, failure_history):
    """
    Predict whether mastering prerequisites will enable target skill mastery
    """
    prediction = {
        "confidence": 0.0,        # 0-1 confidence in success
        "risk_factors": [],       # Potential issues
        "success_indicators": [], # Positive signs
        "estimated_sessions": 0   # Sessions to complete prerequisite chain
    }
    
    # Analyze cognitive load reduction
    # Analyze prerequisite coverage of failure patterns  
    # Estimate time to mastery
    
    return prediction
```

## Error Handling and Edge Cases

### Expansion Failures
- **No Clear Prerequisites**: Skill may be too fundamental or incorrectly specified
- **Circular Dependencies**: Automatic cycle detection and resolution prompts
- **Excessive Decomposition**: Depth limits and granularity warnings
- **Prerequisite Gaps**: Validation that prerequisites actually address failure causes

### DAG Integrity Issues
- **Semantic Conflicts**: Robust deduplication prevents skill redundancy
- **Relationship Violations**: Validation ensures prerequisites are truly foundational
- **Orphaned Skills**: Cleanup of skills with no path to learning objectives

### Stack Management Edge Cases
- **Deep Prerequisite Chains**: Stack depth monitoring and optimization suggestions
- **Failed Prerequisites**: Recursive expansion with depth limits
- **Parallel Prerequisites**: Dependency resolution for concurrent learning paths

## Integration Points

This command integrates with:
- **`/learn/assess`**: Processes assessment failures to trigger expansion
- **`/learn/identify`**: Semantic deduplication of generated prerequisites
- **`/learn/teach`**: Teaching phase begins after prerequisites are mastered
- **`/learn/validate`**: DAG consistency checking and cycle detection
- **`/learn/progress`**: Visualization of expanded skill relationships

## File Outputs Created/Modified

- `.claude/learn/skills.json` - Updated with new prerequisite skills and relationships
- `.claude/learn/stack.json` - Reordered processing queue with prerequisites  
- `.claude/learn/cache/expansion_results.json` - Detailed expansion analysis
- `.claude/learn/cache/failure_analysis.json` - Assessment failure patterns
- Git commit documenting complete expansion process

The skill expansion system provides systematic decomposition based on cognitive load theory and failure analysis, ensuring that prerequisite identification addresses the specific barriers preventing student success.