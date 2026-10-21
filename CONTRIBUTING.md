# Contributing to ETF Replication Engine

Coding agents: the same rules, written for you, are in
[AGENTS.md](AGENTS.md#workflow-for-coding-agents).

## Setup (WSL / Linux)

You need Rust stable, a C/C++ toolchain for HiGHS, Python 3.11+ with `uv`, and Node 22 with
pnpm.

```sh
# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add clippy rustfmt

# HiGHS is built from source by good_lp's `highs` feature
sudo apt install cmake g++

# Python
curl -LsSf https://astral.sh/uv/install.sh | sh

# Node 22 + pnpm (via nvm and corepack)
nvm install 22
corepack enable pnpm
```

Then:

```sh
git clone git@github.com:enzo-thuilliez/etf-replication-engine.git
cd etf-replication-engine
cargo build --workspace
uv sync --extra dev
pnpm -C web install
```

## Scripts

| Command           | What it does                                              |
| ----------------- | --------------------------------------------------------- |
| `make build`      | `cargo build --workspace`                                 |
| `make test`       | `cargo test --workspace` and `uv run pytest`              |
| `make lint`       | clippy `-D warnings`, `cargo fmt --check`, ruff, ESLint   |
| `make fmt`        | `cargo fmt`, `ruff format`, Prettier (writes changes)     |
| `make run-engine` | Run the engine crate directly (dev entrypoint)            |
| `make run-mcp`    | MCP server + axum API                                     |
| `make run-web`    | Vite dev server for the dashboard                         |
| `make run-agent`  | LangChain agent                                           |
| `make help`       | List every target                                         |

CI runs the Rust job (fmt, clippy, build, test), the Python job (ruff, pytest) and the web job
(lint, build) on every push to `master` and every PR.

## Workflow

1. Pick an issue, or open one with the Feature or Bug template. Read the issues listed under
   its Dependencies; if one is still open, the issue isn't ready.
2. Branch from `master`: `feat/<short-slug>`, `fix/…`, `chore/…` or `docs/…`. One issue, one
   branch, one PR.
3. Stay inside [docs/SPECS.md](docs/SPECS.md). It is the v0 boundary: anything in its §5, or
   not in the issue's Acceptance, goes under "Left for later" in the PR body, not in the code.
4. Commit with [Conventional Commits](https://www.conventionalcommits.org/):
   `type(scope): lowercase summary`, e.g. `feat(engine): add simulate_rebalance`.
   Scopes: `engine`, `mcp`, `web`, `agent`, `eval`, `data`, `docs`, `ci`, `deps`, `repo`.
5. Add one bullet under `Unreleased` in [CHANGELOG.md](CHANGELOG.md), in its own last commit.
   Never edit existing bullets.
6. Before pushing: `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets --
   -D warnings`, `cargo test --workspace`, plus the Python or web checks if you touched them.
7. Open a PR against `master` using the template. Its first line is `Closes #N` (or
   `Part of #N` when the PR is one step of the issue).
8. If `master` moved, merge it into your branch. Never rebase, never force push.
9. Once CI is green, the product owner squash-merges. Nobody pushes to `master` directly.

## Using Claude Code

The repo ships project permissions in `.claude/settings.json`. Claude Code ignores their
allow rules until you trust the workspace: run `claude` once in the repo and accept the
trust dialog. Deny rules (no `rm -rf`, no force pushes, no pushes to `master`) apply either
way.

## Docs to keep in sync

- [docs/SPECS.md](docs/SPECS.md) when a data type, tool schema or v0 scope changes.
- [AGENTS.md](AGENTS.md) when the MCP tool or agent behaviour contract changes, in the same PR.
- [DECISIONS.md](DECISIONS.md) for decisions with trade-offs (add an ADR).
- [CHANGELOG.md](CHANGELOG.md) under `Unreleased` for every PR.
- [ROADMAP.md](ROADMAP.md) checkboxes when a PR completes a roadmap item.
