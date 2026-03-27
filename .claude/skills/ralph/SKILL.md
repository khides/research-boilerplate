---
name: ralph
description: 自律的反復研究ループ。タスクグラフに基づいて自律実行。
user-invocable: true
disable-model-invocation: true
arguments: "<prompt>"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - MultiEdit
  - Glob
  - Grep
  - Task
  - WebFetch
  - WebSearch
hooks:
  PreToolUse:
    - matcher: "AskUserQuestion|EnterPlanMode"
      hooks:
        - type: command
          command: "echo '{\"decision\":\"block\",\"reason\":\"Ralph autonomous mode. Do not ask questions - make your own judgment and proceed.\"}' && exit 2"
  Stop:
    - hooks:
        - type: command
          command: "bash -c '\"$(git rev-parse --show-toplevel)/.claude/hooks/ralph-stop-hook.sh\"'"
          timeout: 15
  PostToolUse:
    - matcher: "Write|Edit|MultiEdit"
      hooks:
        - type: command
          command: "bash -c '\"$(git rev-parse --show-toplevel)/.claude/hooks/ralph-backpressure.sh\"'"
          timeout: 30
---

# Ralph - 自律的反復研究ループ

状態ファイルに基づいてタスクグラフを順に実装し、全受入条件を検証して完了する自律ループ。
ユーザーに対して一切質問しない。判断は全て自律で行う。

## ルールオーバーライド

Ralph ループ内では以下のグローバルルールを上書きする:

- テスト・ビルドはユーザー確認なしで実行する。AC 検証に必要なコマンドは全て自律実行すること。
- git push は実行しない。
- git commit は task_graph にコミットタスクが明示的に含まれている場合のみ実行する。

## 引数

| 引数 | デフォルト | 説明 |
|------|-----------|------|
| `<prompt>` | (任意) | タスクの説明 (skip-plan モード用) |
| `--max-iterations N` | 25 | 最大反復回数 |

### 使用例

```
/ralph                                              # ralph-plan で生成済みの状態ファイルを使用
/ralph "Implement data preprocessing pipeline"      # skip-plan モード
/ralph "Add visualization for results" --max-iterations 10
```

## 手順

### 0. プロジェクトコンテキストの読み込み

最初に CLAUDE.md を Read して、プロジェクト全体の不変条件として適用する。
次に、変更対象のディレクトリに応じて docs/ 配下の関連ドキュメントを読む。

### 1. 状態ファイルの読み込み

セッション固有の active ファイル、または cross-session discovery ファイルから状態ファイルを特定する:

```bash
if [[ -z "${CLAUDE_SESSION_ID:-}" ]]; then
  echo "ERROR: CLAUDE_SESSION_ID is not set. SessionStart hook may not be configured."
  exit 1
fi
SESSION_HASH="$(echo "${CLAUDE_SESSION_ID}" | md5sum 2>/dev/null | cut -c1-12 || echo "${CLAUDE_SESSION_ID}" | md5 2>/dev/null | cut -c1-12)"
ACTIVE_FILE="/tmp/ralph_active_${SESSION_HASH}"
STATE_FILE=""

if [ -f "$ACTIVE_FILE" ]; then
  STATE_FILE="$(cat "$ACTIVE_FILE")"
else
  CANDIDATE="/tmp/ralph_${SESSION_HASH}.json"
  if [ -f "$CANDIDATE" ]; then
    STATE_FILE="$CANDIDATE"
    echo "$STATE_FILE" > "$ACTIVE_FILE"
  fi
fi

if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ]; then
  cat "$STATE_FILE"
fi
```

### 2a. 状態ファイルが存在する場合 (Plan モード)

状態ファイルの内容を読み込み、`task_graph` と `acceptance_criteria` を把握する。
ユーザーに以下を報告してから作業を開始:

```
Ralph loop started (plan mode).
- Tasks: <total_tasks> tasks
- ACs: <total_acs> acceptance criteria
- Max iterations: <max_iterations>
- State file: <STATE_FILE>
```

### 2b. 状態ファイルが存在しない場合 (Skip-plan モード)

引数からタスク説明と `--max-iterations` をパースし、最小限の状態ファイルを生成:

```bash
SESSION_HASH="$(echo "${CLAUDE_SESSION_ID}" | md5sum 2>/dev/null | cut -c1-12 || echo "${CLAUDE_SESSION_ID}" | md5 2>/dev/null | cut -c1-12)"
STATE_FILE="/tmp/ralph_${SESSION_HASH}.json"
ACTIVE_FILE="/tmp/ralph_active_${SESSION_HASH}"

jq -n \
  --arg sid "$SESSION_HASH" \
  --arg prompt "<parsed prompt>" \
  --argjson max_iterations <parsed max_iterations> \
  --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    session_id: $sid,
    phase: "implementation",
    max_iterations: $max_iterations,
    iteration: 0,
    created_at: $created_at,
    acceptance_criteria: [],
    task_graph: [],
    context_report: $prompt,
    stall_hashes: [],
    completion_token: "RALPH_COMPLETE",
    errors: []
  }' > "$STATE_FILE"

echo "$STATE_FILE" > "$ACTIVE_FILE"
```

### 3. タスク実行

以下のガイドラインに従って実装する:

- task_graph が存在する場合: 依存関係 (`deps`) に従い、`status: "pending"` のタスクから順に実装
- task_graph が空の場合 (skip-plan): prompt に基づいて自律的にタスクを分解し実装
- テスト駆動: 可能な限りテストを先に書き、テストが通ることを確認してから次に進む
- 自己検証: 各ステップで型チェック、lint、テスト実行を活用
- 段階的実装: 小さなステップに分割し、各ステップで動作確認
- エラー対応: PostToolUse hook からのバックプレッシャーに即座に対応する
- 3回連続で同じエラーに遭遇した場合はアプローチを変更する

### 4. 検証コマンド

| Tool | Command |
|------|---------|
| Lint | `ruff check src/` |
| Format | `black --check src/` |
| Type check | `mypy src/` |
| Test | `pytest -x -q` |

### 5. タスク完了時の処理

各タスク完了時に状態ファイルの該当タスクの status を `"done"` に更新:

```bash
SESSION_HASH="$(echo "${CLAUDE_SESSION_ID}" | md5sum 2>/dev/null | cut -c1-12 || echo "${CLAUDE_SESSION_ID}" | md5 2>/dev/null | cut -c1-12)"
STATE_FILE="$(cat "/tmp/ralph_active_${SESSION_HASH}")"
jq '.task_graph |= map(if .id == "T-N" then .status = "done" else . end)' \
  "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
```

### 6. 検証フェーズ

全タスク完了後:

1. 状態ファイルの phase を `"verification"` に更新
2. acceptance_criteria の各 AC を検証
3. 未達成の AC があれば修正作業を行い、再検証
4. 全 AC 通過で次のステップへ

### 7. 品質ゲート (RALPH_COMPLETE 前に全通過必須)

1. ruff check 通過
2. black --check 通過
3. pytest 通過
4. 全 acceptance criteria verified

### 8. 完了

全品質ゲート通過後:

1. 変更のサマリーを出力
2. 完了トークンを出力:

```
RALPH_COMPLETE
```

## ループの仕組み

1. Claude が停止しようとするたびに Stop hook が実行される
2. Stop hook はセッション固有の active ファイル経由で状態ファイルを確認
3. phase が implementation/verification で未完了なら `decision: "block"` を返す
4. Claude は停止せずに作業を継続する
5. 完了トークン検出、max_iterations 到達、stall 3回連続で終了

## 中断

ループを中断するには `/ralph-cancel` を実行する。
