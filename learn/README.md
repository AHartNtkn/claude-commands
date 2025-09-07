# Mastery Learning Commands

A research-based learning system that adapts to your knowledge and guides you through skill acquisition using proven educational methods.

## Quick Start

1. **Initialize your learning domain**:
   ```
   /learn/start "Linear Algebra"
   ```

2. **Begin learning**:
   ```
   /learn/assess auto
   ```

3. **Continue the learning cycle** - the system will guide you through assessment, skill breakdown, teaching, and spaced review automatically.

## How It Works

This system implements **mastery learning** - you must truly understand each skill before moving to the next. It uses:

- **Adaptive assessment** that finds your knowledge boundary
- **Intelligent skill breakdown** when you need prerequisites  
- **Research-based teaching** with worked examples and practice
- **Spaced repetition** to maintain long-term retention

## Core Learning Cycle

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   ASSESS    │───▶│   EXPAND     │───▶│    TEACH    │
│ Your Skills │    │ Prerequisites│    │ New Skills  │
└─────────────┘    └──────────────┘    └─────────────┘
       ▲                                      │
       │           ┌──────────────┐           │
       └───────────│    REVIEW    │◀──────────┘
                   │ Spaced Practice│
                   └──────────────┘
```

## Commands Overview

### 🎯 `/learn/start [subject]`
**Initialize a learning domain**
- Analyzes your subject and breaks it into learnable skills
- Creates a skill graph showing what depends on what
- Sets up progress tracking and git repository

**Example**: `/learn/start "Calculus"` or `/learn/start https://arxiv.org/paper-url`

### 📊 `/learn/assess [skill]`  
**Test your current knowledge**
- Uses adaptive testing to efficiently find what you know/don't know
- Automatically adjusts question difficulty based on your responses
- Updates your learning path based on results

**Use**: `/learn/assess auto` (tests the next skill in your queue)

### 🧩 `/learn/expand [skill]`
**Break down complex skills**  
- When you fail a skill assessment, this identifies what you need to learn first
- Uses cognitive science to find the right prerequisites
- Prevents skills from being too cognitively demanding

**Use**: Usually triggered automatically, but can run manually if needed

### 📚 `/learn/teach [skill]`
**Learn new skills through guided instruction**
- Only runs when you've mastered all prerequisites
- Uses worked examples, then faded practice, then assessment
- Based on cognitive load theory for effective learning

**Use**: `/learn/teach auto` (teaches the next ready skill)

### 🔄 `/learn/review [mode]`
**Maintain skills with spaced practice**
- Prevents forgetting through timed review sessions
- Mixes similar skills to improve discrimination
- Adapts spacing based on your retention performance

**Use**: 
- `/learn/review auto` - reviews whatever is due
- `/learn/review specific-skill` - reviews one skill

## Understanding Your Progress

### Skill States
- **UNTESTED** - Not yet assessed
- **UNREADY** - Assessed but missing prerequisites  
- **MASTERED** - You've demonstrated solid understanding
- **NEEDS_REVIEW** - Due for spaced practice

### Files Created
The system tracks everything in `.claude/learn/`:
- `skills.json` - Your skill graph and progress
- `student.json` - Your learning analytics and scheduling
- `sessions/` - Detailed logs of each learning session
- Git commits track your entire learning journey

## Learning Strategies

### 1. Trust the Process
The system is designed based on learning research. If it says you need a prerequisite, you probably do.

### 2. Focus on Mastery
Don't rush through skills. The 85% mastery threshold ensures you really understand before moving on.

### 3. Do Your Reviews
Spaced repetition maintains what you've learned. Skip reviews and you'll forget.

### 4. Use Auto Mode
`/learn/assess auto` and `/learn/teach auto` let the system guide you optimally.

## Example Learning Session

```bash
# Start learning calculus
/learn/start "Differential Calculus"

# Begin assessment
/learn/assess auto
# → Tests "Taking derivatives" - you get 40% correct
# → System identifies you need "Limits" and "Function notation" first

# System automatically adds prerequisites to your learning queue
/learn/assess auto  
# → Now tests "Limits" - you get 90% correct - MASTERED!

/learn/assess auto
# → Tests "Function notation" - you get 85% correct - MASTERED!

# Now you're ready to learn the original skill
/learn/teach auto
# → Teaches "Taking derivatives" with examples and practice
# → You pass the mastery quiz - MASTERED!

# A week later...
/learn/review auto
# → Quick review of "Taking derivatives" to maintain retention
```

## Tips for Success

### Getting Started
- **Be specific** with your learning goals in `/learn/start`
- **Start small** - better to master a narrow topic than struggle with something too broad

### During Learning
- **Read carefully** - the teaching materials are designed to prepare you for the assessments
- **Take your time** - rushing through examples won't help retention
- **Ask questions** - if something isn't clear, the system can usually explain differently

### Assessment
- **Don't guess** - the system learns from your response patterns
- **Use confidence ratings** - they help the system adapt to you
- **Don't worry about failure** - failing an assessment just identifies what to learn next

### Long-term Success  
- **Do your reviews** - even 5 minutes of spaced practice prevents forgetting
- **Trust the scheduling** - the system knows when you need to review
- **Track your progress** - git logs show your entire learning journey

## Advanced Usage

### Manual Control
While auto-mode is recommended, you can manually control the process:
- `/learn/assess specific-skill-id` - test a specific skill
- `/learn/expand failed-skill` - manually break down a skill
- `/learn/teach ready-skill` - teach a specific skill

### Monitoring Progress
- Check `.claude/learn/stack.json` to see your learning queue
- Look at `.claude/learn/student.json` for your analytics
- Use `git log` to see your learning history

### Customization
Edit `.claude/learn/config.json` to adjust:
- Mastery thresholds (default 85%)
- Spacing intervals for reviews
- Assessment precision targets
- Teaching strategies

## Troubleshooting

### "No skill ready for teaching"
- You need to assess and master prerequisites first
- Run `/learn/assess auto` until you have mastered skills

### "Assessment failed to converge"  
- The system couldn't get a precise measurement
- Usually means you need more practice - the skill will be broken down

### "Nothing due for review"
- All your mastered skills are still well-retained
- The system will tell you when the next review is scheduled

### Skills seem too easy/hard
- The system adapts to your performance automatically
- If consistently too easy, it will increase difficulty
- If too hard, it will identify missing prerequisites

## Research Foundation

This system implements findings from:
- **Mastery Learning** (Bloom, 1984): Don't advance until you've truly mastered prerequisites
- **Cognitive Load Theory** (Sweller): Manage working memory demands during instruction  
- **Testing Effect** (Roediger): Retrieval practice strengthens memory better than re-reading
- **Spaced Repetition** (Ebbinghaus): Reviews timed based on forgetting curves prevent decay
- **Worked Examples** (Renkl): Show complete solutions before independent practice
- **Interleaving** (Rohrer): Mix similar skills to improve discrimination and transfer

The system combines these proven methods into a coherent, personalized learning experience that adapts to your individual progress and retention patterns.

## Getting Help

- Each command has built-in help and error messages
- Progress reports explain what's happening and why
- Git commits provide detailed logs of all learning activities
- The system is designed to be self-explanatory - trust the guidance it provides

Happy learning! 🎓