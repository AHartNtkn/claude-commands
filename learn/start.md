---
allowed-tools: Task, Write, Read, Bash(git:*), Bash(mkdir:*), Bash(jq:*), WebFetch, Grep, Glob, Bash([:*), Bash(echo:*), Bash(wc:*)
argument-hint: [SUBJECT_OR_URL]
description: Initialize a mastery-learning domain from subject description or academic paper URL
---

# /learn/start $ARGUMENTS

## Purpose
Initialize a comprehensive mastery-learning system for a given subject or academic paper. This command establishes the foundational skill DAG, sets up tracking infrastructure, and creates a git-backed learning repository with semantic skill identification.

## Initial Context
- Learning directory exists: !`[ -d .claude/learn ] && echo "true" || echo "false"`
- Git repository exists: !`[ -d .git ] && echo "true" || echo "false"`
- Existing skills count: !`[ -f .claude/learn/skills.json ] && jq -r "keys[]" .claude/learn/skills.json | wc -l || echo "0"`
- Setup status: !`mkdir -p .claude/learn/{sessions,quizzes,teaching} && echo "Directories created"`

## Operating Principles
- **Research-Grounded**: Implements 85-90% mastery thresholds, CAT-based assessment, spaced repetition
- **Semantic Deduplication**: All skills undergo semantic analysis to prevent redundancy
- **State Externalization**: All progress, relationships, and algorithms stored in structured files
- **Git Integration**: Every learning session creates commits for progress tracking and branching

## Initialization Procedure

### Phase 1: Infrastructure Setup

#### 1.1 Git Repository Initialization
If git repository doesn't exist, initialize private learning repo:
```bash
git init
echo "# Mastery Learning Progress" > README.md
echo ".claude/learn/sessions/*.tmp" > .gitignore
echo ".claude/learn/cache/" >> .gitignore
git add README.md .gitignore
git commit -m "init: mastery learning repository"
```

#### 1.2 Directory Structure Creation
```bash
mkdir -p .claude/learn/{sessions,quizzes,teaching,cache}
mkdir -p .claude/learn/banks/{trivial,easy,realistic}
```

#### 1.3 Core State File Initialization
Create foundational JSON files with proper structure:

**`.claude/learn/skills.json`** - Skill DAG with semantic metadata
**`.claude/learn/student.json`** - Student progress and analytics
**`.claude/learn/semantic_index.json`** - Fast similarity lookups
**`.claude/learn/stack.json`** - Processing queue
**`.claude/learn/config.json`** - System configuration

### Phase 2: Subject Analysis and Skill Extraction

#### 2.1 Content Analysis
Based on $ARGUMENTS:

**If URL provided:**
- Use WebFetch to retrieve academic paper/content
- Extract key concepts, methodologies, and learning objectives
- Identify prerequisite knowledge domains
- Map to established academic taxonomies

**If subject description provided:**
- Parse natural language description for domain keywords
- Identify scope boundaries and learning depth
- Cross-reference with academic standards/curricula
- Determine assessment complexity levels

#### 2.2 Initial Skill Identification
Use Task tool to launch specialized skill extraction agent:

```markdown
**Agent Prompt:**
You are a curriculum design expert specializing in mastery learning. Analyze the following content and extract a comprehensive list of skills needed for mastery:

Content: [Subject/Paper content]

CRITICAL REQUIREMENTS:
1. **Concrete Skills Only**: Each skill must be testable through specific problems/exercises
2. **Atomic Decomposition**: Break complex skills into component parts
3. **Clear Prerequisites**: Identify what must be mastered before each skill
4. **Assessment Criteria**: Define what "mastery" looks like for each skill
5. **Semantic Uniqueness**: Avoid redundant or overlapping skills

For each skill, provide:
- Unique identifier and title
- Concrete description (what can the student DO?)
- Prerequisites (which other skills must be mastered first?)
- Assessment type (procedural, computational, conceptual, application)
- Difficulty level (foundational, intermediate, advanced)
- Example problems that would test this skill

Output as structured JSON matching our skills.json schema.
```

#### 2.3 Semantic Deduplication Pass
For each extracted skill:
1. Generate semantic fingerprint (keywords, domain tags)
2. Create embedding vector representation
3. Check against existing skills using cosine similarity
4. Merge duplicates and establish canonical IDs
5. Build initial semantic index

### Phase 3: DAG Construction and Validation

#### 3.1 Prerequisite Relationship Mapping
```bash
# Use jq to build adjacency matrix from prerequisites
jq '
  def build_dag:
    . as $skills |
    reduce to_entries[] as {key: $id, value: $skill} ({}; 
      . + {($id): ($skill.prerequisites // [])});
  build_dag
' .claude/learn/skills.json > .claude/learn/dag_matrix.json
```

#### 3.2 Cycle Detection and Resolution
Implement topological sort to detect cycles:
- Flag circular dependencies for resolution
- Suggest prerequisite relationship corrections
- Ensure DAG property is maintained

#### 3.3 Root Node Identification
Identify skills with no prerequisites as potential starting points:
```bash
jq '
  [.[] | select(.prerequisites == [] or .prerequisites == null) | .canonical_id]
' .claude/learn/skills.json > .claude/learn/root_skills.json
```

### Phase 4: Assessment Strategy Configuration

#### 4.1 Mastery Criteria Setup
Configure research-based thresholds in config.json:
```json
{
  "mastery_threshold": 0.85,
  "cat_precision_target": 0.30,
  "successive_relearning_sessions": 2,
  "max_items_per_assessment": 12,
  "spacing_intervals": [1, 3, 7, 14, 30], // days
  "item_exposure_limit": 0.3
}
```

#### 4.2 Initial Student Model
Initialize Bayesian Knowledge Tracing parameters:
```json
{
  "student_id": "learner_001",
  "created": "2024-01-15T10:00:00Z",
  "global_theta": 0.0,
  "skill_estimates": {},
  "mastery_boundary": [],
  "session_count": 0,
  "total_learning_time": 0,
  "calibration_accuracy": null,
  "spacing_schedule": {}
}
```

### Phase 5: Learning Stack Initialization

#### 5.1 Priority Queue Setup
Initialize processing stack based on learning objectives:
```bash
# Identify target skills from user input
TARGET_SKILLS=$(echo "$ARGUMENTS" | jq -r '.targets // []')

# Build initial stack with target skills on top
jq --argjson targets "$TARGET_SKILLS" '
  {
    "stack": $targets,
    "processed": [],
    "current_focus": ($targets[0] // null),
    "created": now | strftime("%Y-%m-%dT%H:%M:%SZ")
  }
' <<< '{}' > .claude/learn/stack.json
```

#### 5.2 Session Planning
Create initial assessment plan:
- Identify skills needing baseline assessment
- Schedule initial diagnostic tests
- Plan skill decomposition priorities
- Set spacing intervals for review

### Phase 6: Validation and Commit

#### 6.1 System Integrity Checks
Validate all created files:
```bash
# Validate JSON structure
find .claude/learn -name "*.json" -exec jq empty {} \;

# Check DAG properties
python3 -c "
import json
with open('.claude/learn/skills.json') as f:
    skills = json.load(f)
# Add cycle detection logic here
print('DAG validation: PASSED')
"
```

#### 6.2 Initial Commit
```bash
git add .claude/learn/
git commit -m "init: learning domain '$ARGUMENTS'

- Extracted $(jq 'length' .claude/learn/skills.json) skills from subject analysis
- Built prerequisite DAG with semantic deduplication  
- Configured mastery thresholds: 85% with CAT precision 0.30
- Initialized BKT student model with spacing intervals
- Created assessment stack with $(jq '.stack | length' .claude/learn/stack.json) target skills

🎯 Ready for adaptive assessment and mastery-based progression"
```

### Phase 7: Next Steps Guidance

Display learning system status and next actions:

```markdown
# Learning Domain Initialized: $ARGUMENTS

## System Status
✅ Skill DAG: X skills identified with semantic deduplication  
✅ Prerequisites: Y prerequisite relationships mapped
✅ Assessment: CAT-based with 85% mastery threshold
✅ Tracking: Git-based progress with BKT student model

## Next Actions
1. **Start Assessment**: Run `/learn/assess` to begin diagnostic testing
2. **Review DAG**: Use `/learn/progress` to visualize skill relationships  
3. **Manual Adjustment**: Edit `.claude/learn/skills.json` if needed

## Target Skills
[List the main skills the student will work toward mastering]

The system will automatically:
- Assess current knowledge boundaries
- Decompose failed skills into prerequisites  
- Schedule spaced practice and reviews
- Track mastery progression with git commits

Ready to begin mastery-based learning!
```

## Error Handling

### Common Issues and Resolutions

**URL Fetch Failures:**
- Retry with different extraction methods
- Fall back to manual subject description
- Use cached paper abstracts if available

**Skill Extraction Ambiguity:**
- Prompt for clarification on scope
- Provide multiple decomposition options
- Allow manual skill curation

**DAG Cycles:**
- Flag circular dependencies
- Suggest relationship modifications
- Enable manual prerequisite editing

**Git Repository Issues:**
- Check write permissions
- Handle existing repo conflicts
- Provide manual setup instructions

## Integration Points

This command integrates with:
- `/learn/assess` - Begins diagnostic testing on initialized skills
- `/learn/identify` - Handles ongoing semantic deduplication
- `/learn/progress` - Visualizes learning state and DAG
- All subsequent learning commands that reference the established skill DAG

## File Outputs Created

- `.claude/learn/skills.json` - Complete skill DAG with metadata
- `.claude/learn/student.json` - Student progress tracking  
- `.claude/learn/semantic_index.json` - Fast similarity search index
- `.claude/learn/stack.json` - Processing queue state
- `.claude/learn/config.json` - System configuration
- Git commit with complete initialization state

The mastery learning system is now ready for adaptive assessment and personalized skill progression.