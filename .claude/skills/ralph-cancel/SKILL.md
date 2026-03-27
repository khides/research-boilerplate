---
name: ralph-cancel
description: 実行中の Ralph ループを中断し、状態ファイルをアーカイブして cleanup する。
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash
---

# Ralph Cancel - ループ中断

実行中の Ralph ループを安全に中断する。

## 手順

1. セッション固有の active ファイルから状態ファイルを特定
2. 状態ファイルをアーカイブ
3. active ファイルと状態ファイルを削除
4. 中断完了を報告

```bash
if [[ -z "${CLAUDE_SESSION_ID:-}" ]]; then
  echo "CLAUDE_SESSION_ID is not set."
  exit 1
fi

SESSION_HASH="$(echo "${CLAUDE_SESSION_ID}" | md5sum 2>/dev/null | cut -c1-12 || echo "${CLAUDE_SESSION_ID}" | md5 2>/dev/null | cut -c1-12)"
ACTIVE_FILE="/tmp/ralph_active_${SESSION_HASH}"

if [[ ! -f "$ACTIVE_FILE" ]]; then
  echo "No active Ralph session found."
  exit 0
fi

STATE_FILE="$(cat "$ACTIVE_FILE")"

if [[ -f "$STATE_FILE" ]]; then
  ARCHIVE="/tmp/ralph_archive_$(date +%Y%m%d_%H%M%S).json"
  cp "$STATE_FILE" "$ARCHIVE"
  echo "Archived state to: $ARCHIVE"
  rm -f "$STATE_FILE"
fi

rm -f "$ACTIVE_FILE"
echo "Ralph session cancelled."
```
