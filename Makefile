# Makefile for research project

.PHONY: help
.DEFAULT_GOAL := help

BOLD := \033[1m
RESET := \033[0m
GREEN := \033[32m
BLUE := \033[34m
YELLOW := \033[33m

##@ General

help: ## Display this help message
	@echo "$(BOLD)Research Project$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make $(BLUE)<target>$(RESET)\n\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(BLUE)%-25s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BOLD)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

setup: ## Setup local environment (mise + Python + Node.js)
	@echo "$(GREEN)Installing runtimes via mise...$(RESET)"
	@mise install
	@echo "$(GREEN)Setting up Python environment...$(RESET)"
	@uv venv --python 3.11
	@echo "$(GREEN)Installing Python dependencies...$(RESET)"
	@uv pip install -e ".[dev]"
	@echo "$(GREEN)Installing Node.js dependencies...$(RESET)"
	@npm install
	@echo "$(GREEN)Setup complete! Activate with: source .venv/bin/activate$(RESET)"

##@ Code Quality

format: ## Format code with black
	@uv run black src/ scripts/ tests/

lint: ## Lint code with ruff
	@uv run ruff check src/ scripts/ tests/

lint-fix: ## Lint and auto-fix with ruff
	@uv run ruff check --fix src/ scripts/ tests/

typecheck: ## Type check with mypy
	@uv run mypy src/

test: ## Run pytest
	@uv run pytest -x -q

check: format lint typecheck test ## Run all code quality checks

##@ Research

run: ## Run main experiment (usage: make run [ARGS="--config custom.yaml"])
	@echo "$(GREEN)Running experiment...$(RESET)"
	@uv run python src/main.py $(ARGS)

##@ Docker

docker-up: ## Start Docker container (runs setup, then detaches)
	@docker compose -f .devcontainer/docker-compose.yml up --detach --wait

docker-down: ## Stop Docker container
	@docker compose -f .devcontainer/docker-compose.yml down

docker-shell: ## Open shell in Docker container
	@docker exec -it research-dev fish

docker-build: ## Rebuild Docker container
	@docker compose -f .devcontainer/docker-compose.yml build --no-cache

##@ tmux + Claude Code

tmux: ## Start tmux session with Claude Code (local)
	@./scripts/setup-tmux.sh

tmux-docker: ## Start tmux session with Claude Code (Docker)
	@./scripts/setup-tmux.sh --docker

tmux-attach: ## Attach to existing tmux session
	@tmux attach-session -t research 2>/dev/null || echo "No session found. Run: make tmux"

tmux-stop: ## Stop tmux session
	@tmux kill-session -t research 2>/dev/null && echo "Session stopped." || echo "No session running."

##@ Utilities

clean-tmp: ## Clean temporary files
	@echo "$(YELLOW)Cleaning tmp/ directory...$(RESET)"
	@rm -rf tmp/*
	@echo "$(GREEN)Done!$(RESET)"

clean-out: ## Clean output files (WARNING: deletes all generated data!)
	@echo "$(YELLOW)WARNING: This will delete ALL generated data in out/$(RESET)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		rm -rf out/*; \
		echo "$(GREEN)Cleaned out/ directory$(RESET)"; \
	else \
		echo "Cancelled"; \
	fi

clean: clean-tmp ## Clean temporary files only
