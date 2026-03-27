# Research Boilerplate

tmux + Claude Code + Ralph による自律的研究ループの boilerplate リポジトリ。

## 設計思想

### なぜ tmux か

このボイラープレートでは、研究セッションの実行基盤として tmux を採用している。理由は以下の通り:

- **セッション永続化**: SSH 切断やターミナルを閉じても、Claude Code の自律ループ (Ralph) が中断されない。長時間の研究タスクを安全に実行できる
- **ウィンドウ分離**: Claude Code 専用ウィンドウ (claude) と手動コマンド用ウィンドウ (shell) を分離し、AI の自律作業と人間の手動操作を並行して行える
- **環境統一**: ローカル環境でも Docker 環境でも同一の `setup-tmux.sh` スクリプトでセッションを構築する。開発体験が環境に依存しない
- **VSCode 統合**: VSCode Tasks からワンクリックでセッションの起動・接続・停止が可能

### Ralph の仕組み

Ralph は Claude Code の Hook 機構を活用した自律的反復ループシステム。3つの Hook で構成される:

1. **Session Start Hook** (`ralph-session-start.sh`): セッション ID を環境変数に注入し、状態ファイルとセッションを紐付ける
2. **Stop Hook** (`ralph-stop-hook.sh`): Claude が応答を終了しようとするたびに実行される。状態ファイルを参照し、未完了のタスクや受入条件があれば `decision: "block"` を返して Claude を続行させる。完了トークン (`RALPH_COMPLETE`) の検出、最大反復回数到達、または 3回連続の stall で終了する
3. **Backpressure Hook** (`ralph-backpressure.sh`): Write/Edit 後に自動実行される PostToolUse Hook。Python ファイルなら `py_compile` + `ruff check` + 対応テスト、Shell なら `shellcheck`、JSON/YAML なら構文チェックを行い、エラーがあれば即座に Claude へフィードバックする

ワークフローは 2パターン:

- **Plan モード**: `/ralph-plan` で対話的に要件定義・タスク分解を行い、`/ralph` で自律実行
- **Skip-plan モード**: `/ralph "タスク説明"` で計画なしに直接自律実行

## Prerequisites

- [make](https://www.gnu.org/software/make/)
- [Docker](https://docs.docker.com/get-docker/)

## Quick Start

### Local 環境

```bash
make setup                    # mise install + Python venv + Node.js deps
make tmux                     # tmux + Claude Code セッション開始
```

### Docker 環境

```bash
make docker-up                # コンテナ起動 (セットアップ自動実行)
make tmux-docker              # tmux + Claude Code セッション開始 (Docker内)
```

### VSCode Task

`Ctrl+Shift+P` -> `Tasks: Run Task` から:

- **Start Research Session (Local)** - ローカル環境で tmux + Claude Code 起動
- **Start Research Session (Docker)** - Docker 環境で tmux + Claude Code 起動
- **Attach to Research Session** - 既存セッションに再接続
- **Stop Research Session** - セッション停止

## Ralph (自律的研究ループ)

### Plan-driven ワークフロー

```bash
# 1. 計画フェーズ (インタラクティブ)
/ralph-plan "データ前処理パイプラインの実装"

# 2. 実装フェーズ (自律実行)
/ralph
```

### Skip-plan ワークフロー

```bash
# 計画なしで直接自律実行
/ralph "結果の可視化モジュールを追加"
/ralph "テストカバレッジを改善" --max-iterations 10
```

### ループ制御

```bash
/ralph-cancel                 # 実行中のループを中断
```

## Project Structure

```
.claude/
  hooks/                      # Ralph hooks (session-start, stop, backpressure)
  skills/                     # Ralph skills (ralph, ralph-plan, ralph-cancel)
  settings.json               # Claude Code permissions and hooks
.devcontainer/                # Docker development environment
  Dockerfile                  # Python 3.11 + uv + Node.js + tmux
  docker-compose.yml          # Container configuration
  setup.sh                    # Container initialization
.vscode/
  tasks.json                  # VSCode task definitions
  settings.json               # VSCode settings
scripts/
  setup-tmux.sh               # tmux session setup (local / Docker)
src/                          # Main source code
tests/                        # Test files
docs/                         # Documentation
config.yaml                   # Experiment configuration
Makefile                      # Development commands
CLAUDE.md                     # Claude Code project guidance
```

## Make Targets

```bash
make help                     # 全ターゲット一覧

# Setup
make setup                    # ローカル環境セットアップ (Python + Node.js)

# Code Quality
make check                    # 全チェック実行 (format + lint + typecheck + test)
make format                   # black でフォーマット
make lint                     # ruff でリント
make lint-fix                 # ruff で自動修正
make typecheck                # mypy で型チェック
make test                     # pytest でテスト

# Research
make run                      # メイン実験実行

# Docker
make docker-up                # コンテナ起動 (セットアップ自動実行)
make docker-down              # コンテナ停止
make docker-shell             # コンテナ内シェル
make docker-build             # コンテナ再ビルド

# tmux + Claude Code
make tmux                     # ローカル環境でセッション開始
make tmux-docker              # Docker 環境でセッション開始
make tmux-attach              # 既存セッションに接続
make tmux-stop                # セッション停止

# Utilities
make clean                    # 一時ファイル削除
make clean-tmp                # tmp/ 削除
make clean-out                # out/ 削除 (確認あり)
```

## 使い方

1. このリポジトリをテンプレートとして新しい研究プロジェクトを作成
2. `pyproject.toml` の依存関係をプロジェクトに合わせて更新
3. `config.yaml` に実験パラメータを定義
4. `src/main.py` に研究パイプラインを実装
5. ローカル: `make setup && make tmux` / Docker: `make docker-up && make tmux-docker`
