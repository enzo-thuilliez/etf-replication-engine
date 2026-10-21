# Roadmap

Phased plan for this project. Each phase has one objective, concrete deliverables, and a status.
For *what* each layer should do once built, see [AGENTS.md](AGENTS.md) (tool contract) and
[docs/SPECS.md](docs/SPECS.md) (v0 technical design, referenced explicitly in Phase 1).

**Status legend:** ✅ Done · 🚧 In progress · ⬜ To do

## Phase 0 — Environment & setup

**Objective:** set up the dev environment and repo structure so coding can start without
friction.

- [x] Rust toolchain (rustup, cargo, clippy, rustfmt) working under WSL
- [x] Python (`uv`) and Node toolchains installed
- [x] Cargo workspace (`engine` + `mcp-server`) that compiles (`cargo build --workspace`)
- [x] Full scaffold: directory tree, README.md, PROJECT.md, AGENTS.md, CLAUDE.md
- [x] GitHub Actions CI in place (Rust + Python + Node lint/build/test)
- [x] `.pre-commit-config.yaml` configured (cargo fmt/clippy, ruff, eslint/prettier)
- [x] MIT license (`LICENSE`)

**Status: ✅ Done**

## Phase 1 — Engine + MCP server MVP

**Objective:** a working optimization engine, exposed through the 3 MCP tools, testable from
MCP Inspector and Claude Desktop — within the v0 scope strictly defined in
[docs/SPECS.md](docs/SPECS.md). This is the phase most at risk of scope creep: the goal is an MVP
shippable in **a few days, no more**. Anything not listed below belongs to a later phase or to
`docs/SPECS.md` §5 (out of v0 scope) — not to Phase 1.

- [ ] Data model (`engine/src/model.rs`): `Security`, `Index`, `Basket`, `Constraints`,
      `Trade`, `ToolError`, matching docs/SPECS.md §1
- [ ] v0 dataset: 30 real tickers + sectors + illustrative index weights (CSV in `data/`),
      fixed-seed synthetic returns generator (docs/SPECS.md §3)
- [ ] `optimize_basket`: LP via `good_lp` + HiGHS (L1 proxy, see docs/SPECS.md §4), with MIP
      support for `max_positions` when cardinality is constrained
- [ ] `compute_tracking_error`: actual TE (annualized standard deviation) from the synthetic
      returns + sector decomposition
- [ ] `simulate_rebalance`: trade list, total cost, turnover, from a current basket and a target
      basket
- [ ] Unit tests (`engine/tests/`): at least one feasible case, one infeasible case
      (`optimize_basket`), a sanity-check TE computation, a cost/turnover computation
- [ ] `mcp-server`: the 3 tools exposed via `rmcp`, schemas matching docs/SPECS.md §2
- [ ] Minimal `axum` route(s) exposing the same 3 operations over HTTP (no authentication — just
      enough for Phase 2 to plug into, not a full API design)
- [ ] Manual validation: the 3 tools can be called and respond correctly via **MCP Inspector**,
      and via a **Claude Desktop** config pointing at `mcp-server`

Explicitly out of this phase: web dashboard, agent, persistence (`db/`), Docker — see
docs/SPECS.md §5 for the full list and the reasoning behind each exclusion.

**Status: ⬜ To do**

## Phase 2 — Frontend

**Objective:** React/TS dashboard connected to the `axum` API, visualizing basket composition
and tracking error.

- [ ] TS types generated from the Rust structs (`ts-rs`/`typeshare`) into `web/src/types`
- [ ] Basket composition view (table/chart, basket weights vs index weights)
- [ ] Tracking error display + sector decomposition
- [ ] UI to trigger `optimize_basket` / `simulate_rebalance` against the `mcp-server` API and
      display the results
- [ ] Chat panel shell in place (wired to the agent in Phase 3, not before)

**Status: ⬜ To do**

## Phase 3 — Agent

**Objective:** LangChain + Azure OpenAI agent consuming the MCP server, with first end-to-end
usage scenarios.

- [ ] `src/agent/` implementation: LangChain agent, MCP client, Azure OpenAI configuration
- [ ] The agent follows the behavior contract in AGENTS.md (grounding in tool calls,
      clarifying questions, faithful reporting of tool errors)
- [ ] `web/` chat panel wired to the agent
- [ ] A few end-to-end usage scenarios documented/tested manually (e.g. the
      `optimize_basket` → `simulate_rebalance` sequence described in AGENTS.md)

**Status: ⬜ To do**

## Phase 4 — Evaluation

**Objective:** automatically evaluate the correctness of the agent's tool calls and the quality
of its answers.

- [ ] Evaluation harness in `eval/` (`deepeval` and/or `ragas`)
- [ ] Test cases derived directly from the AGENTS.md contract (tool-calling correctness,
      faithfulness of the natural-language answer to the tool result)
- [ ] Eval scripts in `scripts/llm/`, called by the `eval/` harness
- [ ] First baseline report/metrics on the Phase 3 agent

**Status: ⬜ To do**

## Phase 5 — Productionization

**Objective:** make the project deployable and harden the pipeline; optional WASM bonus.

- [ ] Dockerfiles for `mcp-server`, `web`, `agent`; enable the commented-out services in
      `docker-compose.yml`
- [ ] CI hardening (committed lockfiles, caching, possibly image build/push)
- [ ] README updated with Docker launch instructions
- [ ] *(Bonus, optional)* compile part of `engine` to WASM for interactive in-browser
      recalculation

**Status: ⬜ To do**
