# ETF Replication Engine

**Track an index with fewer trades. A Rust optimizer, driven by an LLM agent over MCP.**

[![CI](https://github.com/enzo-thuilliez/etf-replication-engine/actions/workflows/ci.yml/badge.svg)](https://github.com/enzo-thuilliez/etf-replication-engine/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

An ETF has to hold a basket that behaves like its benchmark index. Holding every constituent
at exact weight is expensive, and every rebalance costs money in spreads and commissions. The
engine finds the basket that tracks the index as closely as possible for the least trading,
and an agent lets you ask for it in plain language: *"rebalance against the new weights, keep
turnover under 5%, what does it cost me in tracking error?"*

> **Status:** scaffolding. Workspace, CI and specs are in place; the optimizer, MCP tools and
> agent are not built yet. See [ROADMAP.md](ROADMAP.md).

## What it does

- **Basket optimization.** Pick holdings and weights that minimize tracking error under
  constraints: max positions, turnover budget, weight bounds.
- **Tracking error.** Measure how far a basket drifts from its benchmark.
- **Rebalance simulation.** Compare the trades, cost and tracking error of a rebalance before
  making it.
- **Agent interface.** The same functions are exposed as MCP tools, so an LLM agent can call,
  combine and explain them.
- **Dashboard.** A React UI for the basket, tracking error and rebalance costs.

The domain problem is laid out in [PROJECT.md](PROJECT.md). The tool contract is in
[AGENTS.md](AGENTS.md).

## How it works

```text
  LLM agent ──── MCP ────┐
  (Python)               ▼
                     mcp-server ───► engine
                    (rmcp + axum)    (Rust, good_lp / HiGHS)
                         ▲
  Web dashboard ─ HTTP ──┘
  (React)
```

1. `engine` is a pure Rust library holding all the optimization logic, solved as an LP/MIP
   with HiGHS.
2. `mcp-server` exposes the engine twice, as MCP tools for the agent and as an HTTP API for
   the dashboard. Both paths call the same functions.
3. The agent (LangChain + Azure OpenAI) and the dashboard are thin clients on top.

More in [docs/architecture.md](docs/architecture.md) and [docs/SPECS.md](docs/SPECS.md).

## Stack

| Layer | Tech |
| --- | --- |
| Optimizer | Rust, [`good_lp`](https://crates.io/crates/good_lp) + HiGHS |
| Tool server | Rust, [`rmcp`](https://github.com/modelcontextprotocol/rust-sdk), [`axum`](https://github.com/tokio-rs/axum) |
| Dashboard | React, TypeScript, Vite; types generated from Rust |
| Agent | Python, LangChain, Azure OpenAI, [`uv`](https://docs.astral.sh/uv/) |
| Evaluation | [`deepeval`](https://github.com/confident-ai/deepeval), [`ragas`](https://github.com/explodinggradients/ragas) |

## Development

Requires Rust stable, Node 22 with pnpm, and Python 3.11+ with `uv`.

```sh
make build      # cargo build --workspace
make test       # Rust + Python tests
make lint       # clippy, rustfmt, ruff, eslint
make run-mcp    # MCP server + HTTP API
make run-web    # dashboard dev server
make run-agent  # agent
```

`make help` lists every target.

## Repository layout

```text
engine/        Rust: optimization library
mcp-server/    Rust: MCP tools + HTTP API over the engine
web/           React dashboard
src/agent/     Python agent (MCP client)
eval/          agent evaluation
docs/          architecture and specs
```

## License

[MIT](LICENSE)
