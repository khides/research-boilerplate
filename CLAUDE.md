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
.claude/
  hooks/                      # Ralph hooks (session-start, stop, backpressure)
  skills/                     # Ralph skills (ralph, ralph-plan, ralph-cancel)
  settings.json               # Claude Code permissions and hooks
.devcontainer/                # Docker development environment
  Dockerfile                  # Python 3.11 + uv + Node.js + tmux
  devcontainer.json           # Dev container metadata
  docker-compose.yml          # Container configuration
  setup.sh                    # Container initialization (dependency caching)
.vscode/
  tasks.json                  # VSCode task definitions
  settings.json               # VSCode settings
scripts/
  setup-tmux.sh               # tmux session setup (local / Docker)
src/                          # Main source code
tests/                        # Test files
docs/                         # Documentation
config.yaml                   # Experiment configuration
pyproject.toml                # Python project metadata and dependencies
package.json                  # Node.js dependencies (Claude Code)
Makefile                      # Development commands
.editorconfig                 # Editor formatting rules
.mise.toml                    # Runtime versions (Python 3.11, Node 20)
```

## Development Commands

```bash
# Code quality
make check              # Run all checks (format + lint + typecheck + test)
make format             # Format with black
make lint               # Lint with ruff
make lint-fix           # Lint and auto-fix with ruff
make typecheck          # Type check with mypy
make test               # Run pytest

# Research workflow
make run                # Run main experiment (ARGS="--config custom.yaml")

# Utilities
make help               # Display all make targets
make clean              # Clean temporary files (tmp/)
make clean-tmp          # Clean tmp/ directory
make clean-out          # Clean out/ directory (with confirmation)
```

## Environment

Prerequisites: make, Docker

Two execution patterns are available. Each environment is independent with separate setup.

### Local environment
```bash
make setup              # mise install + Python venv + Node.js deps
source .venv/bin/activate
make tmux               # Start tmux + Claude Code session
```

### Docker environment
```bash
make docker-up          # Start container (setup runs automatically)
make docker-build       # Rebuild container (no cache)
make tmux-docker        # Start tmux + Claude Code session (in Docker)
make docker-shell       # Enter container shell (fish)
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
make tmux-attach        # Attach to existing session
make tmux-stop          # Stop session
# Or use VSCode Task: "Start Research Session"
```

## Implementation Principles

- Deliver simple, focused solutions
- No over-engineering or speculative abstractions
- Solve only the current problem
- Use absolute paths, avoid `cd`
