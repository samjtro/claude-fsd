# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claude-fsd is an automated development system that runs continuous AI agent-driven development cycles. It operates like "Tesla FSD for code" - multiple specialized AI agents (Developer, Planner, Reviewer, Tester) work together autonomously to build projects while allowing human oversight and intervention.

## Core Commands

```bash
# Main entry points (wrapper commands)
claude-fsd              # Interactive mode with guided setup
claude-fsd dev          # Jump directly to development mode
claude-fsd plan         # Jump directly to planning mode
claude-fsd plan-gen     # Generate new project plan
claudefsd               # Alias for claude-fsd

# Direct agent execution (for advanced users)
claudefsd-dev [--verbose]   # Direct development agent execution (continuous loop)
                            # --verbose: Show full Claude Code logs instead of status bar
claudefsd-analyze-brief     # Generate questions from BRIEF.md (uses opus model)
claudefsd-create-plan       # Create development plan from answered questions (uses opus model)
claudefsd-check-dependencies # Verify required tools are available

# Project monitoring and control
claudefsd-status        # Show project status, progress, and health
claudefsd-pause         # Gracefully pause development and save state
claudefsd-resume        # Resume paused development with context restoration
claudefsd-logs          # Advanced log analysis and monitoring

# Testing and validation
./test-failure-detection.sh  # Test failure detection mechanisms
./bootstrap.sh          # Bootstrap entire system from source including Codex

# Automatic commit management
claudefsd-auto-commit --enable [timeout]  # Enable auto-commits with timeout
claudefsd-auto-commit --monitor           # Start background monitoring
claudefsd-auto-commit --status            # Check auto-commit status
```

## Build and Development Commands

This is a Node.js CLI package with executable scripts:
- **No build step required** - Shell scripts in `bin/` directory are the executables
- **No testing framework** - Uses manual testing with `test-manual.md` instructions
- **No linting setup** - Code quality maintained through AI review process

## Model Selection Strategy

The system automatically selects Claude models based on the complexity and nature of each task:

- **Opus Model**: Used for complex architectural work requiring deep thinking
  - Upfront planning (`claudefsd-analyze-brief`)
  - Architecture planning (`claudefsd-create-plan`)
  - Megathinking mode (every 4th iteration in development cycle)
  
- **Sonnet Model**: Used for regular development iterations
  - Standard development tasks (iterations 1, 2, 3, 5, 6, 7, etc.)
  - All three agents (Planner, Developer, Reviewer) use the same model per iteration

## Architecture

### Agent System Design
The system uses multiple AI agents working in cycles:
- **Planner Agent**: Analyzes docs/PLAN.md and selects next task with megathinking mode every 4th iteration
- **Developer Agent**: Implements tasks using Claude Code with `--dangerously-skip-permissions`
- **Reviewer Agent**: Uses Codex (if available) for static code review in background
- **Tester Agent**: Reviews, validates, and can commit changes

### Key Files Structure
```
docs/
├── PLAN.md          # Development roadmap (primary task list)
├── CLAUDE-NOTES.md  # AI architect analysis
├── QUESTIONS.md     # Clarification questions
└── IDEAS.md         # Future improvements
BRIEF.md             # Project description
logs/                # AI session logs with timestamps
```

### Failure Detection System
- Monitors iteration timing (minimum 5 minutes expected)
- Tracks consecutive fast iterations (< 5 minutes)
- Exits after 3 consecutive fast iterations (indicates API throttling)
- Implements exponential backoff delays

## Development Workflow

### Loop Mechanics in claudefsd-dev
1. **Task Selection**: Planner reads docs/PLAN.md and selects next open task
2. **Implementation**: Developer implements with extensive error checking
3. **Review**: Parallel static review with Codex + comprehensive Claude review
4. **Testing/Commit**: Validates changes and handles git operations
5. **Repeat**: Continues until all tasks marked complete

### Megathinking Mode
Every 4th development cycle activates architectural planning mode for high-level system design considerations.

## Error Handling Philosophy
- **No cheating patterns**: Never disable tests, exclude files from compilation, or use silent fallbacks
- **Fail fast**: Integration failures should throw exceptions, not return mock data
- **No production fallbacks**: Avoid try/catch blocks that hide errors with default values
- **Defensive programming**: All edge cases must throw proper exceptions

## Dependencies
- **Required**: `claude` command (Claude CLI) - Install from https://docs.anthropic.com/en/docs/claude-code
- **Optional**: `codex` command for enhanced code review - Set up from source via bootstrap script
- **Optional**: OPENAI_API_KEY environment variable for Codex features
- **Optional**: Node.js 22+ (only required if you want Codex CLI features - claude-fsd itself is pure bash)

## Source Installation
Claude-fsd is designed to run entirely from source without npm dependencies:
```bash
git clone <repository-url>
cd claude-fsd
./bootstrap.sh  # Automated installation with prompts
```

The bootstrap script will:
- Install Claude CLI (with manual prompts)
- Optionally set up OpenAI Codex CLI from source (includes Node.js v22+ if needed)
- Set up PATH and zsh aliases
- Verify all dependencies

**Note**: claude-fsd core functionality is pure bash and requires no Node.js installation.

### Manual Installation
```bash
# 1. Clone repository
git clone <repository-url>
cd claude-fsd

# 2. Make scripts executable
chmod +x bin/*

# 3. Add to PATH (choose your shell config file)
echo 'export PATH="'$(pwd)'/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 4. Install Claude CLI manually
# Follow: https://docs.anthropic.com/en/docs/claude-code

# 5. (Optional) Set up Codex CLI from source
# This requires Node.js 22+ and is completely optional
# See bootstrap.sh for detailed steps
```

## Git Branch Strategy
- Stays on current branch if it's a proper feature branch
- Avoids branch switching during automated cycles
- Uses git for version control (no backup copies needed)

## Testing Strategy
- Emphasizes integration tests over unit tests
- Tests should exercise real systems (databases, APIs) non-destructively  
- No mocking without explicit permission
- Lint and architecture tests run frequently during development

## Enhanced Functionality

### Project Monitoring Commands
- **claudefsd-status**: Comprehensive project dashboard showing task progress, git status, recent activity, and system health
- **claudefsd-pause**: Gracefully pause development sessions with state preservation
- **claudefsd-resume**: Resume paused sessions with full context restoration and conflict detection
- **claudefsd-logs**: Advanced log analysis with session grouping, error detection, and real-time monitoring

### Development Workflow Enhancements
- **State preservation**: Automatic saving of development context when pausing
- **Progress tracking**: Visual progress bars and completion percentages for tasks
- **Error monitoring**: Proactive detection of failures and performance issues  
- **Session analysis**: Complete breakdown of agent activities and outputs
- **Log management**: Intelligent log rotation, search, and analysis capabilities

### Automatic Commit Management
- **claudefsd-auto-commit**: Provides automatic patch/commit notes after configurable timeout periods
- **Background monitoring**: Integrates seamlessly with development cycles to track activity
- **Context-aware commits**: Includes progress summaries, next tasks, and development state
- **Configurable timeouts**: Default 30-minute timeout, customizable per project
- **Activity detection**: Monitors log files and git changes to detect ongoing work
- **Clean integration**: Automatically starts/stops with development sessions

### Zsh Integration
The bootstrap script creates convenient aliases:
```bash
# Quick commands
cfsd='claude-fsd'
cfsd-dev='claudefsd-dev'
cfsd-status='claudefsd-status'

# Development helpers
cfsd-new PROJECT_NAME    # Create new project structure
cfsd-logs tail developer # Tail latest developer logs
cfsd-last-error         # Show recent errors
```