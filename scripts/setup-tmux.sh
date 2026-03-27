#!/bin/bash
set -euo pipefail

SESSION_NAME="research"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Options
USE_DOCKER=0
CLAUDE_ARGS=""

print_usage() {
  cat <<'USAGE'
Usage:
  setup-tmux.sh [--docker] [--claude-args "..."]

Options:
  --docker              Run inside Docker container instead of local environment.
  --claude-args "..."   Extra args passed to claude command.

Examples:
  ./scripts/setup-tmux.sh                        # Local environment
  ./scripts/setup-tmux.sh --docker               # Docker environment
  ./scripts/setup-tmux.sh --claude-args "--model opus"
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker)     USE_DOCKER=1; shift ;;
    --claude-args) shift; CLAUDE_ARGS="${1:-}"; shift ;;
    -h|--help)    print_usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; print_usage; exit 1 ;;
  esac
done

# If session exists, attach
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Session '$SESSION_NAME' already exists. Attaching..."
  tmux attach-session -t "$SESSION_NAME"
  exit 0
fi

echo "Creating tmux session '$SESSION_NAME'..."

# Docker mode: ensure container is running
if [[ "$USE_DOCKER" -eq 1 ]]; then
  echo "Starting Docker container..."
  cd "$PROJECT_ROOT"
  docker compose -f .devcontainer/docker-compose.yml up -d
  echo "Waiting for container to be ready..."
  for i in $(seq 1 30); do
    if docker exec research-dev true 2>/dev/null; then
      break
    fi
    sleep 1
  done
fi

# Wait for a tmux pane's shell to be ready (prompt appeared)
wait_for_pane() {
  local pane_id="$1"
  local max_wait=10
  for i in $(seq 1 "$max_wait"); do
    # Check if the pane has content (shell prompt has appeared)
    local content
    content=$(tmux capture-pane -t "$pane_id" -p 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$content" ]]; then
      return 0
    fi
    sleep 0.5
  done
}

# Load project tmux config
TMUX_CONF="$PROJECT_ROOT/.tmux.conf"
if [[ -f "$TMUX_CONF" ]]; then
  tmux source-file "$TMUX_CONF" 2>/dev/null || true
fi

# Create session with 2 windows: claude + shell
# Window 0: Claude Code (persistent research loop)
tmux new-session -d -s "$SESSION_NAME" -n "claude" -c "$PROJECT_ROOT"
CLAUDE_PANE=$(tmux display-message -p -t "$SESSION_NAME:claude" '#{pane_id}')

# Window 1: Shell (for manual commands)
tmux new-window -t "$SESSION_NAME" -n "shell" -c "$PROJECT_ROOT"
SHELL_PANE=$(tmux display-message -p -t "$SESSION_NAME:shell" '#{pane_id}')

# Wait for shell prompts before sending commands
wait_for_pane "$CLAUDE_PANE"
wait_for_pane "$SHELL_PANE"

if [[ "$USE_DOCKER" -eq 1 ]]; then
  # Docker mode: run claude inside container
  tmux send-keys -t "$CLAUDE_PANE" \
    "docker exec -it research-dev claude $CLAUDE_ARGS" C-m

  # Shell pane: enter container
  tmux send-keys -t "$SHELL_PANE" \
    "docker exec -it research-dev fish" C-m
else
  # Local mode: activate venv and run claude
  if [[ -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then
    tmux send-keys -t "$CLAUDE_PANE" \
      "source $PROJECT_ROOT/.venv/bin/activate && claude $CLAUDE_ARGS" C-m
    tmux send-keys -t "$SHELL_PANE" \
      "source $PROJECT_ROOT/.venv/bin/activate" C-m
  else
    tmux send-keys -t "$CLAUDE_PANE" \
      "claude $CLAUDE_ARGS" C-m
  fi
fi

# Focus claude window
tmux select-window -t "$SESSION_NAME:claude"
tmux select-pane -t "$CLAUDE_PANE"

echo "Tmux session '$SESSION_NAME' is ready!"
echo "  Window 'claude': Claude Code (research loop)"
echo "  Window 'shell':  Manual commands"
tmux attach-session -t "$SESSION_NAME"
