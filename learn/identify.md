---
allowed-tools: Task, Write, Read, Edit, Bash(jq:*), Bash(python3:*), Bash([:*), Bash(echo:*)
argument-hint: [SKILL_DESCRIPTION]
description: Semantic skill identification and deduplication to maintain DAG coherence
---

# /learn/identify $ARGUMENTS

## Purpose
Perform semantic analysis of proposed skills to prevent DAG redundancy. This command implements research-grounded deduplication using embedding similarity, keyword analysis, and domain clustering to maintain a coherent, non-redundant skill graph.

## Initial Context
- Existing skills: !`[ -f .claude/learn/skills.json ] && jq "length" .claude/learn/skills.json || echo "0"`
- Semantic index exists: !`[ -f .claude/learn/semantic_index.json ] && echo "true" || echo "false"`
- Last skill ID: !`[ -f .claude/learn/skills.json ] && jq -r "keys | map(tonumber) | max" .claude/learn/skills.json || echo "0"`

## Semantic Identification Algorithm

### Phase 1: Skill Fingerprint Generation

#### 1.1 Extract Skill Components
Parse the skill description to extract:
- **Core Action Verbs**: What the student must DO (solve, compute, analyze, apply)
- **Domain Objects**: What concepts are involved (equations, functions, derivatives)
- **Context/Constraints**: Under what conditions (given data, with tools, time limits)
- **Performance Level**: Expected mastery depth (recognize, apply, synthesize, evaluate)

#### 1.2 Generate Semantic Fingerprint
Create multi-dimensional representation:

```python
# Use Task tool to run semantic analysis
skill_fingerprint = {
    "keywords": extract_keywords(skill_description),
    "action_verbs": extract_verbs(skill_description), 
    "domain_tags": classify_domain(skill_description),
    "cognitive_level": bloom_taxonomy_level(skill_description),
    "embedding": generate_embedding(skill_description),
    "prerequisite_hints": extract_prerequisite_indicators(skill_description)
}
```

### Phase 2: Similarity Search and Analysis

#### 2.1 Fast Candidate Filtering
Use semantic index for efficient search:

```bash
# Extract keywords from new skill
NEW_KEYWORDS=$(echo "$ARGUMENTS" | jq -r '.keywords[]' 2>/dev/null || echo "$ARGUMENTS" | tr ' ' '\n')

# Find skills with keyword overlap
jq --arg keywords "$NEW_KEYWORDS" '
  .keyword_index as $idx |
  ($keywords | split(" ")) as $new_kw |
  reduce $new_kw[] as $kw ({}; 
    if $idx[$kw] then . + {($kw): $idx[$kw]} else . end
  ) |
  [.[]] | flatten | unique
' .claude/learn/semantic_index.json > .claude/learn/cache/candidates.json
```

#### 2.2 Embedding Similarity Computation
For each candidate, compute cosine similarity:

```python
# Launch similarity computation task
similarity_results = []
for candidate_id in candidates:
    candidate_embedding = get_skill_embedding(candidate_id)
    similarity = cosine_similarity(new_embedding, candidate_embedding)
    similarity_results.append({
        "skill_id": candidate_id,
        "similarity": similarity,
        "title": get_skill_title(candidate_id)
    })

# Sort by similarity score
similarity_results.sort(key=lambda x: x['similarity'], reverse=True)
```

### Phase 3: Relationship Classification

#### 3.1 Similarity Thresholds
Apply research-calibrated thresholds:

- **>= 0.92**: DUPLICATE (essentially identical skills)
- **0.85-0.91**: HIGHLY_SIMILAR (likely merge candidates)
- **0.75-0.84**: RELATED (potential hierarchical relationship)  
- **0.60-0.74**: WEAKLY_RELATED (same domain, different skills)
- **< 0.60**: DISTINCT (genuinely different skills)

#### 3.2 Hierarchical Relationship Analysis
For RELATED skills, determine hierarchy using Task tool:

```markdown
**Agent Prompt:**
Analyze these two skills and determine their hierarchical relationship:

**Skill A**: [existing_skill_title]
Description: [existing_skill_description]

**Skill B**: [new_skill_description]  
Description: [new_skill_description]

Consider:
1. **Cognitive Complexity**: Which requires more advanced thinking?
2. **Prerequisite Dependencies**: Which must be learned first?
3. **Scope**: Which encompasses a broader range of problems?
4. **Abstraction Level**: Which operates at a higher level of abstraction?

Classify the relationship as one of:
- SUBSUMES: Skill A contains Skill B as a component
- SUBSUMED_BY: Skill B contains Skill A as a component  
- PREREQUISITE: Skill A must be mastered before Skill B
- COREQUISITE: Skills should be learned together
- PARALLEL: Skills are independent but related
- DISTINCT: Actually different skills despite similarity

Provide reasoning and confidence level (0.0-1.0).
```

### Phase 4: Conflict Resolution

#### 4.1 Automatic Resolution Rules

**DUPLICATE Skills (similarity >= 0.92):**
1. Merge into existing skill
2. Add new description as alias
3. Preserve all prerequisite relationships
4. Update semantic index

**HIGHLY_SIMILAR Skills (0.85-0.91):**
1. Present both to user for decision
2. Highlight key differences
3. Recommend merge or separate with clarification
4. Allow manual differentiation

**RELATED Skills (0.75-0.84):**
1. Establish hierarchical relationship
2. Update prerequisite graph
3. Ensure no circular dependencies
4. Add cross-references

#### 4.2 Skill Merging Process

When merging skills:

```bash
# Create skill merge record
jq --arg old_id "$OLD_SKILL_ID" --arg new_id "$NEW_SKILL_ID" '
  .skills[$new_id] = (.skills[$old_id] + .skills[$new_id]) |
  .skills[$new_id].canonical_id = $new_id |
  .skills[$new_id].merged_from += [$old_id] |
  .skills[$new_id].aliases += [.skills[$old_id].title] |
  del(.skills[$old_id])
' .claude/learn/skills.json > .claude/learn/skills_temp.json

mv .claude/learn/skills_temp.json .claude/learn/skills.json
```

Update all references throughout DAG:
```bash
# Update prerequisite references
jq --arg old_id "$OLD_SKILL_ID" --arg new_id "$NEW_SKILL_ID" '
  walk(
    if type == "array" then 
      map(if . == $old_id then $new_id else . end)
    else . end
  )
' .claude/learn/skills.json > .claude/learn/skills_temp.json

mv .claude/learn/skills_temp.json .claude/learn/skills.json
```

### Phase 5: Semantic Index Updates

#### 5.1 Embedding Index Maintenance
```python
# Update embeddings index
embeddings_index[new_skill_id] = new_skill_embedding

# Remove old embedding if merged
if merged_skill_id:
    del embeddings_index[merged_skill_id]

# Save updated index
with open('.claude/learn/semantic_index.json', 'w') as f:
    json.dump(semantic_index, f, indent=2)
```

#### 5.2 Keyword Index Updates
```bash
# Rebuild keyword index from updated skills
jq '
  reduce to_entries[] as {key: $id, value: $skill} ({};
    reduce ($skill.semantic_fingerprint.keywords // [])[] as $kw (.;
      .keyword_index[$kw] += [$id] | .keyword_index[$kw] |= unique
    )
  )
' .claude/learn/skills.json > .claude/learn/semantic_index_temp.json
```

### Phase 6: Validation and Output

#### 6.1 DAG Consistency Check
Verify no circular dependencies introduced:
```python
def detect_cycles(skills_graph):
    """Topological sort to detect cycles"""
    in_degree = {skill: 0 for skill in skills_graph}
    
    for skill in skills_graph:
        for prereq in skills_graph[skill].get('prerequisites', []):
            in_degree[skill] += 1
    
    queue = [skill for skill, degree in in_degree.items() if degree == 0]
    processed = 0
    
    while queue:
        current = queue.pop(0)
        processed += 1
        
        for dependent in get_dependents(current):
            in_degree[dependent] -= 1
            if in_degree[dependent] == 0:
                queue.append(dependent)
    
    return processed != len(skills_graph)  # True if cycle exists
```

#### 6.2 Generate Identification Report

```markdown
# Skill Identification Report

## Input Skill
**Description**: $ARGUMENTS
**Generated ID**: skill_[new_id]

## Semantic Analysis
- **Keywords**: [list of extracted keywords]
- **Domain**: [classified domain tags]
- **Cognitive Level**: [Bloom's taxonomy level]
- **Action Verbs**: [extracted verbs]

## Similarity Search Results
| Existing Skill | Similarity | Relationship | Action |
|---------------|------------|--------------|---------|
| skill_123: "Quadratic equations" | 0.94 | DUPLICATE | ✅ MERGED |
| skill_456: "Polynomial solving" | 0.78 | RELATED | ↗️ PREREQUISITE |
| skill_789: "Algebraic manipulation" | 0.62 | WEAKLY_RELATED | ➡️ CROSS-REFERENCE |

## Actions Taken
- ✅ Merged with existing skill_123 "Quadratic Formula Application"
- ✅ Added alias: "Solving quadratic equations using formula"  
- ✅ Updated 3 dependent skills to reference canonical ID
- ✅ Rebuilt semantic index with new keywords
- ✅ Verified DAG consistency (no cycles detected)

## Updated Skill Node
```json
{
  "skill_123": {
    "title": "Quadratic Formula Application",
    "canonical_id": "skill_123", 
    "aliases": ["Solving quadratic equations", "Using quadratic formula", "Quadratic equation solving"],
    "semantic_fingerprint": {
      "keywords": ["quadratic", "formula", "solving", "equation", "roots"],
      "domain_tags": ["algebra", "polynomials", "equations"],
      "cognitive_level": "apply"
    },
    "merged_from": ["skill_456"],
    "prerequisites": ["skill_045", "skill_067"],
    "state": "UNREADY",
    "last_updated": "2024-01-15T10:30:00Z"
  }
}
```

## Next Steps
- **If new skill**: Proceed with prerequisite analysis
- **If merged**: Update any external references
- **If hierarchical**: Establish prerequisite relationships
- **Always**: Commit changes to git with detailed merge log
```

### Phase 7: Git Integration

#### 7.1 Commit Skill Changes
```bash
# Create detailed commit message
if [[ "$ACTION" == "MERGED" ]]; then
    git add .claude/learn/
    git commit -m "semantic: merge duplicate skill '$ARGUMENTS' → skill_$CANONICAL_ID

- Identified semantic similarity: $SIMILARITY_SCORE
- Consolidated aliases: $(echo $ALIASES | jq -c)
- Updated $DEPENDENT_COUNT dependent skills
- Rebuilt semantic index with merged keywords
- Verified DAG consistency maintained

Skill graph now has $(jq 'length' .claude/learn/skills.json) unique skills"

elif [[ "$ACTION" == "NEW" ]]; then
    git add .claude/learn/
    git commit -m "semantic: add new skill '$ARGUMENTS' as skill_$NEW_ID

- Semantic analysis: no duplicates found (max similarity: $MAX_SIM)
- Domain classification: $(echo $DOMAIN_TAGS | jq -c)
- Keywords indexed: $(echo $KEYWORDS | jq -c)  
- Ready for prerequisite analysis and DAG integration"
fi
```

## Error Handling

### Common Issues and Resolutions

**Embedding Generation Failure:**
- Fall back to keyword-based similarity only
- Use simple term frequency analysis
- Request manual skill differentiation

**Circular Dependencies:**
- Flag cycles and present resolution options
- Suggest prerequisite relationship modifications
- Enable manual DAG editing

**Ambiguous Relationships:**
- Present multiple classification options to user
- Allow manual relationship specification
- Default to conservative DISTINCT classification

## Integration with Other Commands

This command integrates with:
- `/learn/start` - Initial skill extraction and deduplication
- `/learn/expand` - New prerequisite analysis and addition  
- `/learn/merge` - Manual skill node fusion
- `/learn/validate` - DAG consistency checking

## File Outputs Modified

- `.claude/learn/skills.json` - Updated with merged/new skills
- `.claude/learn/semantic_index.json` - Refreshed similarity indices  
- `.claude/learn/cache/` - Temporary similarity computation results
- Git commit documenting semantic analysis and actions taken

The semantic identification system ensures DAG coherence and prevents skill redundancy while maintaining rich relationship modeling for effective mastery learning.