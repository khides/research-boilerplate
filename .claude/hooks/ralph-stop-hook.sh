#!/usr/bin/env bash
# Ralph Stop Hook
# stdin から JSON を受け取り、ループ継続/終了を判定する。
# 状態ファイルはセッション固有の active ファイル経由で発見する。
# 依存: jq, git
set -euo pipefail

# jq が使えない場合はフェイルオープン
if ! command -v jq &>/dev/null; then
  exit 0
fi

# stdin から hook JSON を読み取る
input="$(cat)"

# stop_hook_active チェック
stop_hook_active="$(echo "$input" | jq -r '.stop_hook_active // false')"

# セッション固有の active ファイルから状態ファイルのパスを取得
active_file=""
state_file=""

_raw_session_id="$(echo "$input" | jq -r '.session_id // ""')"
if [[ -z "$_raw_session_id" ]]; then
  _raw_session_id="${CLAUDE_SESSION_ID:-}"
fi

if [[ -n "$_raw_session_id" ]]; then
  _session_hash="$(echo "$_raw_session_id" | md5sum 2>/dev/null | cut -c1-12 || echo "$_raw_session_id" | md5 2>/dev/null | cut -c1-12)"
  active_file="/tmp/ralph_active_${_session_hash}"
  if [[ -f "$active_file" ]]; then
    state_file="$(cat "$active_file")"
  fi
fi

# 判定 1: stop_hook_active=true で状態ファイルなし -> 即 exit 0
if [[ "$stop_hook_active" == "true" ]] && { [[ -z "$state_file" ]] || [[ ! -f "$state_file" ]]; }; then
  exit 0
fi

# 判定 2: 状態ファイルなし -> exit 0 (Ralph 非稼働)
if [[ -z "$state_file" ]] || [[ ! -f "$state_file" ]]; then
  exit 0
fi

# 以降は状態ファイルが存在する場合のロジック
state="$(cat "$state_file")"
phase="$(echo "$state" | jq -r '.phase // "implementation"')"
completion_token="$(echo "$state" | jq -r '.completion_token // "RALPH_COMPLETE"')"
max_iterations="$(echo "$state" | jq -r '.max_iterations')"
iteration="$(echo "$state" | jq -r '.iteration')"

# phase チェック: implementation/verification 以外は pass through
if [[ "$phase" != "implementation" ]] && [[ "$phase" != "verification" ]]; then
  exit 0
fi

# archive: cleanup 前に状態ファイルを保存
archive() {
  local archive_file="/tmp/ralph_archive_$(date +%Y%m%d_%H%M%S).json"
  cp "$state_file" "$archive_file"
}

# cleanup: 状態ファイルと active ファイルを削除
cleanup() {
  rm -f "$state_file"
  rm -f "$active_file"
}

# atomic な状態ファイル更新
update_state() {
  local new_state="$1"
  local tmp_file="${state_file}.tmp.$$"
  echo "$new_state" > "$tmp_file" && mv "$tmp_file" "$state_file"
}

# 進捗情報を生成
progress_info() {
  local total_tasks done_tasks pending_ac
  total_tasks="$(echo "$state" | jq '.task_graph | length // 0')"
  done_tasks="$(echo "$state" | jq '[.task_graph[]? | select(.status == "done")] | length')"
  pending_ac="$(echo "$state" | jq '[.acceptance_criteria[]? | select(.verified == false)] | length')"
  printf "Tasks: %d/%d done, Pending ACs: %d" "$done_tasks" "$total_tasks" "$pending_ac"
}

# 判定 3: last_assistant_message に completion_token を含む
last_message="$(echo "$input" | jq -r '.last_assistant_message // ""')"
if [[ -n "$last_message" ]] && echo "$last_message" | grep -qF "$completion_token"; then
  total_ac="$(echo "$state" | jq '[.acceptance_criteria[]?] | length')"
  unverified_ac="$(echo "$state" | jq '[.acceptance_criteria[]? | select(.verified != true)] | length')"
  if [[ "$total_ac" -gt 0 ]] && [[ "$unverified_ac" -gt 0 ]]; then
    unverified_list="$(echo "$state" | jq -r '[.acceptance_criteria[]? | select(.verified != true) | .id] | join(", ")')"
    iteration=$((iteration + 1))
    state="$(echo "$state" | jq --argjson iter "$iteration" '.iteration = $iter')"
    update_state "$state"
    printf '{"decision":"block","reason":"RALPH_COMPLETE rejected: unverified ACs: %s. Verify all ACs before completing. Iteration %d/%d."}\n' \
      "$unverified_list" "$iteration" "$max_iterations"
    exit 0
  fi
  archive
  cleanup
  exit 0
fi

# 判定 4: iteration >= max_iterations -> エラー記録 -> cleanup -> exit 0
if [[ "$iteration" -ge "$max_iterations" ]]; then
  state="$(echo "$state" | jq --arg reason "Max iterations ($max_iterations) reached" \
    '.errors += [$reason]')"
  update_state "$state"
  archive
  cleanup
  exit 0
fi

# 判定 5: stall detection
compute_diff_hash() {
  local hash
  hash="$(git diff --stat 2>/dev/null | md5sum 2>/dev/null | cut -d' ' -f1 || true)"
  if [[ -z "$hash" ]]; then
    hash="$(git diff --stat 2>/dev/null | md5 2>/dev/null || echo "unknown")"
  fi
  echo "$hash"
}

current_diff_hash="$(compute_diff_hash)"
stall_hashes="$(echo "$state" | jq -r '.stall_hashes // []')"
stall_count="$(echo "$stall_hashes" | jq 'length')"
last_hash="$(echo "$stall_hashes" | jq -r '.[-1] // ""')"

if [[ "$current_diff_hash" == "$last_hash" ]]; then
  state="$(echo "$state" | jq --arg h "$current_diff_hash" '.stall_hashes += [$h]')"
  stall_count=$((stall_count + 1))
else
  state="$(echo "$state" | jq --arg h "$current_diff_hash" '.stall_hashes = [$h]')"
  stall_count=1
fi

if [[ "$stall_count" -ge 4 ]]; then
  state="$(echo "$state" | jq '.errors += ["No progress detected for 3 consecutive iterations"]')"
  update_state "$state"
  archive
  cleanup
  exit 0
fi

# 判定 6: 未完了 -> iteration++, 状態更新, block で継続
iteration=$((iteration + 1))
state="$(echo "$state" | jq --argjson iter "$iteration" '.iteration = $iter')"
update_state "$state"

progress="$(progress_info)"
printf '{"decision":"block","reason":"Ralph iteration %d/%d. %s. Continue working. When complete, output: %s"}\n' \
  "$iteration" "$max_iterations" "$progress" "$completion_token"
