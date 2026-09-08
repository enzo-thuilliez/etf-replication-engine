# CLAUDE.md

Instructions for Claude Code (and other agents) working in this repository.

## What this repo is

A Rust optimization engine for ETF index replication / rebalancing, exposed as MCP tools to an
LLM agent, with a React dashboard. See [README.md](README.md) for the pitch and
[PROJECT.md](PROJECT.md) for the domain problem. See [AGENTS.md](AGENTS.md) for the MCP tool /
agent interface contract — treat it as the spec when implementing tools or agent logic.

**Current stage: scaffolding only.** There is no optimization logic, no MCP tools, and no agent
implementation yet. Do not assume any of the business logic described in PROJECT.md or AGENTS.md
already exists in code — check before referencing a function, tool, or type as if it's real.

## Repository layout

This is a polyglot monorepo, not a single-language project:

- `Cargo.toml` (root) — Rust workspace, members `engine` and `mcp-server`.
- `engine/` — Rust library crate. All optimization logic (basket optimization, tracking-error
  computation, rebalance simulation) lives here. No MCP or HTTP concerns in this crate.
- `mcp-server/` — Rust binary crate. Depends on `engine` via a path dependency. Exposes the
  engine as MCP tools (`rmcp`) and as an `axum` HTTP API for the web dashboard. Both interfaces
  should call the same `engine` functions — don't duplicate optimization logic here.
- `web/` — React + TypeScript (Vite) dashboard. Consumes the `mcp-server` axum API. Rust↔TS types
  are meant to be generated (`ts-rs`/`typeshare`), not hand-duplicated — if you add a
  request/response struct in `mcp-server`, prefer generating its TS counterpart over writing one
  by hand.
- `src/agent/` — Python package (src-layout, managed with `uv`, not pip/poetry). LangChain +
  Azure OpenAI agent that consumes `mcp-server` as an MCP client.
- `eval/` — agent evaluation (deepeval/ragas). Phase 2+, after the agent exists.
- `scripts/llm/` — utility scripts, including LLM-calling eval scripts.
- `notebook/` — exploratory Jupyter notebooks. Not production code; fine to be messy, but don't
  import from here into `src/agent/` or `engine/`.
- `data/`, `db/` — local dev data and SQLite files. Contents are gitignored; only `.gitkeep`
  placeholders are tracked.
- `docs/` — architecture notes and technical specs (`docs/SPECS.md`, forthcoming).
- `tests/` — cross-stack integration tests and Python tests. Rust unit/integration tests stay
  inside their own crate (`engine/tests/`, `mcp-server/tests/`), per Rust convention — don't put
  Rust tests here.

## Conventions

- **Rust**: workspace-level `cargo fmt` and `cargo clippy` must pass. Shared dependency versions
  go in `[workspace.dependencies]` in the root `Cargo.toml` as the workspace grows.
- **Python**: managed with `uv` (`uv sync`, `uv run ...`), never `pip install` directly. Linted/
  formatted with `ruff` (config in `pyproject.toml`). src-layout: importable code lives under
  `src/agent/`, not at the repo root.
- **TypeScript**: `web/` is a standalone Vite app with its own `package.json`. Lint/format with
  ESLint + Prettier.
- Don't add Docker/Compose service definitions beyond the commented skeleton in
  `docker-compose.yml` until the post-MVP phase — see the comments in that file for why.

## Running things locally

```bash
# Rust workspace
cargo build
cargo test
cargo clippy --workspace --all-targets

# Web
cd web && npm install && npm run dev

# Python agent
uv sync
uv run ruff check .

# Or via Makefile targets: build, test, run-engine, run-mcp, run-web, run-agent
make help
```

## Documentation

- **PROJECT.md** — domain problem (index replication, tracking error, cost-aware rebalancing).
  No implementation detail belongs here.
- **AGENTS.md** — MCP tool contract and agent behavior contract. Implementation should conform
  to this, not the other way around; if implementation needs to diverge from the contract,
  update AGENTS.md in the same change.
- **docs/** — technical architecture and specs, filled in as the corresponding phase is built.
