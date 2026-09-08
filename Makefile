.DEFAULT_GOAL := help

.PHONY: help build test lint fmt run-engine run-mcp run-web run-agent

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

build: ## Build the Rust workspace
	cargo build --workspace

test: ## Run all tests (Rust workspace + Python)
	cargo test --workspace
	uv run pytest

lint: ## Lint everything (Rust, Python, web)
	cargo clippy --workspace --all-targets -- -D warnings
	cargo fmt --all -- --check
	uv run ruff check .
	cd web && npm run lint

fmt: ## Auto-format everything
	cargo fmt --all
	uv run ruff format .
	cd web && npx prettier --write .

run-engine: ## Run the engine crate directly (dev/debug entrypoint, once implemented)
	cargo run -p engine

run-mcp: ## Run the MCP server (+ axum API)
	cargo run -p mcp-server

run-web: ## Run the web dashboard (Vite dev server)
	cd web && npm run dev

run-agent: ## Run the LangChain agent
	uv run python -m agent
