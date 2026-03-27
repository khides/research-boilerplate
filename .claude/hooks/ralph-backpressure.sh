#!/usr/bin/env bash
# Ralph Backpressure Hook (PostToolUse)
# Write/Edit 後にPython の構文チェック/lint を自動実行し、
# エラーを additionalContext として Claude に即時フィードバック。
# 依存: jq
set -euo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

# stdin から hook JSON を読み取る
input="$(cat)"

# tool_input.file_path を取得
file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty')"

if [[ -z "$file_path" ]]; then
  exit 0
fi

if [[ ! -f "$file_path" ]]; then
  exit 0
fi

# プロジェクトルート検出
project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$project_root" ]]; then
  exit 0
fi

ext="${file_path##*.}"

errors=""

# エラー収集ヘルパー
append_error() {
  local label="$1" output="$2"
  if [[ -n "$output" ]]; then
    errors="${errors}[${label}]\n${output}\n\n"
  fi
}

case "$ext" in
  py)
    # Python: py_compile + ruff
    python_bin=""
    if [[ -f "$project_root/.venv/bin/python" ]]; then
      python_bin="$project_root/.venv/bin/python"
    elif command -v python3 &>/dev/null; then
      python_bin="python3"
    elif command -v python &>/dev/null; then
      python_bin="python"
    fi

    if [[ -n "$python_bin" ]]; then
      py_output="$(timeout 10 "$python_bin" -m py_compile "$file_path" 2>&1)" || true
      append_error "py_compile" "$py_output"
    fi

    # ruff
    ruff_bin=""
    if [[ -f "$project_root/.venv/bin/ruff" ]]; then
      ruff_bin="$project_root/.venv/bin/ruff"
    elif command -v ruff &>/dev/null; then
      ruff_bin="ruff"
    fi

    if [[ -n "$ruff_bin" ]]; then
      timeout 5 "$ruff_bin" check --fix "$file_path" &>/dev/null || true
      ruff_output="$(timeout 5 "$ruff_bin" check "$file_path" 2>&1)" || true
      append_error "ruff" "$ruff_output"
    fi

    # pytest: 対応するテストファイルを実行
    dir="$(dirname "$file_path")"
    stem="$(basename "$file_path" ".py")"
    test_file=""
    for candidate in \
      "${dir}/test_${stem}.py" \
      "${dir}/tests/test_${stem}.py" \
      "${dir}/../tests/test_${stem}.py"; do
      if [[ -f "$candidate" ]]; then
        test_file="$candidate"
        break
      fi
    done
    if [[ -n "$test_file" ]] && [[ -n "$python_bin" ]]; then
      test_output="$(timeout 30 "$python_bin" -m pytest "$test_file" -x -q 2>&1)" || true
      if echo "$test_output" | grep -qE '(FAILED|ERROR)'; then
        append_error "pytest ($test_file)" "$test_output"
      fi
    fi
    ;;
  sh|bash)
    if command -v shellcheck &>/dev/null; then
      sc_output="$(timeout 10 shellcheck "$file_path" 2>&1)" || true
      append_error "shellcheck" "$sc_output"
    fi
    ;;
  json)
    json_output="$(jq empty "$file_path" 2>&1)" || true
    append_error "json syntax" "$json_output"
    ;;
  yaml|yml)
    if [[ -n "$(command -v python3 2>/dev/null || command -v python 2>/dev/null)" ]]; then
      yaml_output="$(python3 -c "import yaml; yaml.safe_load(open('$file_path'))" 2>&1)" || true
      append_error "yaml syntax" "$yaml_output"
    fi
    ;;
  *)
    exit 0
    ;;
esac

if [[ -z "$errors" ]]; then
  exit 0
fi

# 出力が長すぎる場合は切り詰める
max_lines=50
line_count="$(printf '%b' "$errors" | wc -l)"
if [[ "$line_count" -gt "$max_lines" ]]; then
  errors="$(printf '%b' "$errors" | head -n "$max_lines")"
  errors="${errors}\n... (truncated, ${line_count} total lines)"
fi

printf '{"additionalContext":"[Ralph Backpressure] Errors detected:\\n%s"}\n' \
  "$(printf '%b' "$errors" | jq -Rs . | sed 's/^"//;s/"$//')"
