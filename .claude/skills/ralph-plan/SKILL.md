---
name: ralph-plan
description: タスクの要件定義・設計・タスク分解をインタラクティブに行い、Ralph実装ループ用の状態ファイルを生成します。
user-invocable: true
disable-model-invocation: true
arguments: "<task-description>"
allowed-tools: Bash, Read, Write, Glob, Grep, Task, WebFetch, WebSearch, AskUserQuestion
---

# Ralph Plan - インタラクティブ計画セッション

ユーザーとの対話を通じて要件定義・受入条件・設計・タスク分解を行い、`/ralph` で使用する状態ファイルを生成します。

## 絶対ルール

1. 各フェーズの末尾でユーザーの明示的な承認を得るまで次のフェーズに進んではならない。
2. Phase 2 の承認後は必ず Phase 3 を実行すること。実装に進むことは禁止。
3. Phase 3 で状態ファイルを生成したら、このスキルは終了する。実装作業は一切行わない。
4. Edit/MultiEdit ツールはこのスキルでは使用不可。Write ツールは Phase 3 の状態ファイル生成にのみ使用可。
5. task_graph にコミットタスクを含めない。ユーザーが明示的に要求した場合のみ含める。

## 引数

| 引数 | 説明 |
|------|------|
| `<task-description>` | 実装するタスクの説明 |

### 使用例

```
/ralph-plan "Add data preprocessing pipeline"
/ralph-plan "Implement new visualization module"
/ralph-plan docs/plan.md
```

## 手順

### Phase 0: Context Gathering

最初に CLAUDE.md を Read してプロジェクトの不変条件を把握する。

タスク説明を分析し、関連するドキュメントを発見する:
1. `docs/*.md` を Glob で列挙
2. タスク説明から関連ドキュメントを特定して読む

最大3つのサブエージェントを Task ツールで並列起動してコードベースを調査する:

1. パターン調査エージェント:
   - 既存のコード構造
   - 命名規則
   - ディレクトリ構造
   - 類似機能の実装方法

2. 依存関係調査エージェント:
   - 関連パッケージ・内部モジュール
   - 型定義
   - データフォーマット

3. テスト構造調査エージェント:
   - 既存テストのパターン
   - テストユーティリティ
   - テストランナー設定

全エージェントの結果を統合し、コンテキストレポートとしてユーザーに提示する。

--- GATE: Phase 0 完了 ---
コンテキストレポートを提示したら停止し、ユーザーの承認を待つ。

### Phase 1: Requirements & Acceptance Criteria

コンテキストレポートをもとに以下を生成し、ユーザーに提示する:

```markdown
## 機能要件
- FR-1: ...

## 非機能要件
- NFR-1: ...

## スコープ外
- ...

## 受入条件
- AC-1: ... (検証方法: ...)
- AC-L: ruff check 通過 (検証方法: ruff check src/)
- AC-F: black --check 通過 (検証方法: black --check src/)
- AC-T: pytest 通過 (検証方法: pytest -x -q)
```

--- GATE: Phase 1 完了 ---
ユーザーの承認を待つ。

### Phase 2: Design & Task Decomposition

```markdown
## アーキテクチャ方針
- 既存パターンとの整合性: ...
- 採用するパターン: ...

## 変更対象ファイル
- 新規: ...
- 変更: ...

## リスク・懸念事項
- ...
```

設計承認後、atomic なタスクに分解:

```markdown
## タスクグラフ
- T-1: ... [deps: none] [files: ...]
- T-2: ... [deps: T-1] [files: ...]
```

--- GATE: Phase 2 完了 ---
ユーザーの承認を待つ。

### Phase 3: 状態ファイル生成

```bash
if [[ -z "${CLAUDE_SESSION_ID:-}" ]]; then
  echo "ERROR: CLAUDE_SESSION_ID is not set."
  exit 1
fi
SESSION_HASH="$(echo "${CLAUDE_SESSION_ID}" | md5sum 2>/dev/null | cut -c1-12 || echo "${CLAUDE_SESSION_ID}" | md5 2>/dev/null | cut -c1-12)"
STATE_FILE="/tmp/ralph_${SESSION_HASH}.json"
echo "$STATE_FILE"
```

Write ツールで STATE_FILE パスに状態ファイル (JSON) を書き出す:

```jsonc
{
  "session_id": "<hash>",
  "phase": "implementation",
  "max_iterations": 25,
  "iteration": 0,
  "created_at": "<ISO8601>",
  "acceptance_criteria": [
    {"id": "AC-1", "description": "...", "verified": false, "verification_command": "..."}
  ],
  "task_graph": [
    {"id": "T-1", "name": "...", "deps": [], "status": "pending", "completion_condition": "...", "files": ["..."]}
  ],
  "context_report": "<Phase 0 の調査結果サマリー>",
  "stall_hashes": [],
  "completion_token": "RALPH_COMPLETE",
  "errors": []
}
```

--- GATE: Phase 3 完了 (最終) ---

```
[ralph-plan 完了] 状態ファイルを生成しました: <STATE_FILE>
`/ralph` で実装を開始できます。
```
