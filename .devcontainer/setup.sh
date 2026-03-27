#!/bin/bash
set -euo pipefail

echo "=== Research Project Setup ==="

WORKSPACE="/workspace"
VENV_PATH="$WORKSPACE/.venv"
PY_HASH_FILE="$VENV_PATH/.deps_hash"
NODE_HASH_FILE="$WORKSPACE/node_modules/.deps_hash"

# --- Python dependencies ---
py_current_hash="$(md5sum "$WORKSPACE/pyproject.toml" 2>/dev/null | cut -d' ' -f1 || echo "none")"
py_cached_hash=""
if [ -f "$PY_HASH_FILE" ]; then
    py_cached_hash="$(cat "$PY_HASH_FILE")"
fi

if [ ! -d "$VENV_PATH/bin" ] || [ "$py_current_hash" != "$py_cached_hash" ]; then
    echo "Creating Python venv..."
    uv venv "$VENV_PATH" --python 3.11 --allow-existing
    echo "Installing Python dependencies..."
    uv pip install -e ".[dev]" --python "$VENV_PATH/bin/python"
    echo "$py_current_hash" > "$PY_HASH_FILE"
else
    echo "Python dependencies up to date (cached)."
fi

# --- Node.js dependencies ---
node_current_hash="$(md5sum "$WORKSPACE/package.json" 2>/dev/null | cut -d' ' -f1 || echo "none")"
node_cached_hash=""
if [ -f "$NODE_HASH_FILE" ]; then
    node_cached_hash="$(cat "$NODE_HASH_FILE")"
fi

if [ ! -d "$WORKSPACE/node_modules/.bin" ] || [ "$node_current_hash" != "$node_cached_hash" ]; then
    echo "Installing Node.js dependencies..."
    cd "$WORKSPACE" && npm install
    echo "$node_current_hash" > "$NODE_HASH_FILE"
else
    echo "Node.js dependencies up to date (cached)."
fi

# --- Fish shell venv activation ---
mkdir -p /root/.config/fish/conf.d
cat > /root/.config/fish/conf.d/venv.fish <<'FISH'
if test -f /workspace/.venv/bin/activate.fish
    source /workspace/.venv/bin/activate.fish
end
FISH

touch /tmp/.setup_done
echo "=== Setup complete ==="
