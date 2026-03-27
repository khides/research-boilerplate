# Research Boilerplate

tmux + Claude Code + Ralph による自律的研究ループの boilerplate リポジトリ。

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
make typecheck                # mypy で型チェック
make test                     # pytest でテスト

# Research
make run                      # メイン実験実行

# Docker
make docker-up                # コンテナ起動 (セットアップ自動実行)
make docker-down              # コンテナ停止
make docker-shell             # コンテナ内シェル

# tmux + Claude Code
make tmux                     # ローカル環境でセッション開始
make tmux-docker              # Docker 環境でセッション開始
make tmux-attach              # 既存セッションに接続
make tmux-stop                # セッション停止
```

## 使い方

1. このリポジトリをテンプレートとして新しい研究プロジェクトを作成
2. `pyproject.toml` の依存関係をプロジェクトに合わせて更新
3. `config.yaml` に実験パラメータを定義
4. `src/main.py` に研究パイプラインを実装
5. ローカル: `make setup && make tmux` / Docker: `make docker-up && make tmux-docker`
