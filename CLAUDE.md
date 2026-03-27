# CLAUDE.md

This file provides guidance to Claude Code when working with this research project.

## EditorConfig Compliance

- Line endings: LF (Unix-style)
- Final newline: Always include a newline at the end of files
- Character encoding: UTF-8
- Indentation: 4 spaces for Python, 2 spaces for YAML/JSON

## Communication Style

- Respond in Japanese for brief answers and status updates
- No emoji in code, comments, or documentation
- Clear, concise technical writing

## Project Structure

```
src/           - Main source code
scripts/       - Standalone utility scripts
docs/          - Documentation
config.yaml    - Experiment configuration
out/           - Generated output (gitignored)
tmp/           - Temporary files (gitignored)
```

## Development Commands

```bash
# Code quality
make check              # Run all checks (format + lint + typecheck)
make format             # Format with black
make lint               # Lint with ruff
make typecheck          # Type check with mypy
make test               # Run pytest

# Research workflow
make run                # Run main experiment
```

## Environment

Prerequisites: make, Docker

Two execution patterns are available. Each環境は独立しており、セットアップも別々。

### Local environment
```bash
make setup              # mise install + Python venv + Node.js deps
source .venv/bin/activate
make tmux               # Start tmux + Claude Code session
```

### Docker environment
```bash
make docker-up          # Start container (setup runs automatically)
make tmux-docker        # Start tmux + Claude Code session (in Docker)
make docker-shell       # Enter container shell
make docker-down        # Stop container
```

## Ralph (Autonomous Loop)

This project supports Ralph for autonomous iterative development:

```bash
/ralph-plan "task description"   # Interactive planning
/ralph                           # Execute planned tasks autonomously
/ralph "quick task"              # Skip-plan mode
/ralph-cancel                    # Cancel running loop
```

## tmux Session

```bash
make tmux               # Local: tmux + Claude Code
make tmux-docker        # Docker: tmux + Claude Code
# Or use VSCode Task: "Start Research Session"
```

## Implementation Principles

- Deliver simple, focused solutions
- No over-engineering or speculative abstractions
- Solve only the current problem
- Use absolute paths, avoid `cd`
