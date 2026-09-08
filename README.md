# ETF Index Replication & Rebalancing Engine

A Rust engine that solves the core computational problem behind ETF indexing: building and
rebalancing a security basket that tracks a benchmark index as closely as possible while
minimizing transaction costs. The engine is exposed as [MCP](https://modelcontextprotocol.io)
tools that an LLM agent can call, with a React dashboard for visualizing the basket, tracking
error, and simulated rebalancing costs.

> **Status: early stage.** This repository currently contains the project scaffolding
> (workspace layout, tooling, CI, documentation) and no business logic yet. See
> [Status & roadmap](#status--roadmap) below.

## Why this project

I'm an AI Engineering intern on the ETF, Indexing & Smart Beta team at Amundi, where I build
LLM tool-calling agents over market data and production RAG pipelines. This project is an
independent, from-scratch exploration of the same kind of problem — index replication and
rebalancing under real-world constraints — built with my own data, algorithms, and code (no
proprietary information, data, or logic from my employer).

The angle is deliberate: **Rust (performance, memory safety) + agentic AI (MCP tool-calling) +
quantitative finance (ETF/indexing)**. It's a combination that mirrors the kind of system I work
on daily, aimed at AI Engineer roles in asset management and quant finance.

For the domain background — what index replication and tracking error actually mean, and why
basket optimization under transaction costs is a non-trivial problem — see [PROJECT.md](PROJECT.md).

## Architecture

```
etf-replication-engine/
├── engine/            # Rust crate — optimization engine (good_lp / HiGHS solver)
├── mcp-server/        # Rust crate — MCP server (rmcp) + axum web API over the engine
├── web/                # React + TypeScript (Vite) dashboard and agent chat panel
├── src/agent/          # Python package — LangChain + Azure OpenAI agent, consumes the MCP server
├── eval/               # Agent evaluation (deepeval / ragas) — phase 2+
├── scripts/llm/        # Utility scripts, incl. LLM-calling eval scripts
├── notebook/           # Jupyter notebooks for exploration and prototyping
├── data/               # Local test/dev datasets (gitignored contents)
├── db/                 # Local SQLite dev databases (gitignored contents)
├── docs/               # Architecture notes and technical specs
├── tests/              # Cross-stack integration tests + Python tests
├── .github/workflows/   # CI: Rust / Python / Node lint, build, test
└── Cargo.toml          # Rust workspace root (members: engine, mcp-server)
```

**Data flow (target architecture):**

```
┌─────────────┐        MCP (tool calls)        ┌────────────────┐
│  LLM Agent   │ ─────────────────────────────▶ │   mcp-server    │
│ (src/agent,  │ ◀───────────────────────────── │  (rmcp + axum)  │
│  LangChain)  │                                 └────────┬────────┘
└─────────────┘                                            │ in-process
       ▲                                                    ▼
       │ HTTP                                        ┌────────────┐
       │                                              │   engine    │
┌─────────────┐        HTTP (axum API)                │ (good_lp /  │
│  web (React) │ ─────────────────────────────────────▶│   HiGHS)    │
│  dashboard   │                                        └────────────┘
└─────────────┘
```

The `engine` crate is the single source of truth for optimization logic. Both the MCP server and
the axum web API call into it directly — no duplicated logic between the agent-facing and
UI-facing paths.

## Tech stack

| Layer | Technology |
|---|---|
| Optimization engine | Rust, [`good_lp`](https://crates.io/crates/good_lp) with the HiGHS solver |
| MCP tool server | Rust, [`rmcp`](https://github.com/modelcontextprotocol/rust-sdk) (official MCP Rust SDK) |
| Web API | Rust, [`axum`](https://github.com/tokio-rs/axum), sharing the engine in-process |
| Frontend | React + TypeScript, [Vite](https://vitejs.dev) |
| Rust ↔ TS type sharing | [`ts-rs`](https://crates.io/crates/ts-rs) / [`typeshare`](https://github.com/1Password/typeshare) |
| Agent orchestration | Python (src-layout), [LangChain](https://www.langchain.com) + Azure OpenAI, managed with [`uv`](https://docs.astral.sh/uv/) |
| Agent evaluation | [`deepeval`](https://github.com/confident-ai/deepeval) / [`ragas`](https://github.com/explodinggradients/ragas) |
| CI | GitHub Actions (Rust, Python, Node lint/build/test) |

Docker/Compose orchestration is intentionally deferred to a post-MVP productionization phase —
see [docker-compose.yml](docker-compose.yml) for the (inactive) skeleton and rationale.

## Running locally

> These commands describe the intended workflow. Since the engine and agent contain no logic
> yet, `run-engine` / `run-mcp` / `run-agent` are placeholders until the corresponding phases
> land.

**Prerequisites:** Rust (stable, via `rustup`), Node.js 20+, Python 3.11+ with
[`uv`](https://docs.astral.sh/uv/) installed.

```bash
# Rust workspace (engine + mcp-server)
cargo build
cargo test

# Web dashboard
cd web
npm install
npm run dev

# Python agent
uv sync
uv run python -m agent   # placeholder entrypoint

# Or via the Makefile
make build
make test
make run-web
```

See [Makefile](Makefile) for the full list of targets.

## Status & roadmap

This repository is at the **scaffolding stage**: workspace layout, CI, tooling, and domain
documentation are in place; no optimization logic, MCP tools, or agent behavior are implemented
yet. See [AGENTS.md](AGENTS.md) for the interface contract the engine/MCP/agent layers are being
built towards.

A detailed, phased roadmap will live in `ROADMAP.md` (coming soon). At a high level, the plan is:

1. Core engine: basket optimization + tracking-error computation (no MCP/UI yet)
2. MCP server exposing the engine as tools, with a minimal axum API
3. Web dashboard consuming the API
4. LangChain agent consuming the MCP server, with evaluation harness
5. Post-MVP: Dockerized deployment, WASM build of the engine for in-browser recalculation

## License

MIT — see [LICENSE](LICENSE) (to be added).
