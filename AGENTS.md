# AGENTS.md

The single source of instructions for coding agents (Claude Code, Codex, Cursor...) on this
repo; `CLAUDE.md` only imports it. Three parts: how to work in the repo, the issue → branch → PR
workflow, then the MCP tool and agent contracts.

## Purpose

This document specifies the expected behavior of the MCP tools exposed by `mcp-server` and of
the LangChain agent in `src/agent/`. It is an **interface contract**, written before any
implementation exists, so that the engine, the MCP layer, and the agent are all built towards the
same expectations. See [PROJECT.md](PROJECT.md) for the domain background behind each tool.

> **Current stage: Phase 1 (engine + MCP tools MVP), see [ROADMAP.md](ROADMAP.md).** Do not
> assume any of the business logic described in PROJECT.md or AGENTS.md already exists in code —
> check before referencing a function, tool, or type as if it's real.
>
> Contract only: no tool below is implemented yet.

**Language:** everything in this repository is written in English — docs, code, comments,
docstrings, commit messages, tool descriptions, and error messages. This holds even when the
person asking for the change writes in another language.

## Working in this repo

### Repository layout

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
- `eval/` — agent evaluation (deepeval/ragas). Phase 4, after the agent exists.
- `scripts/llm/` — utility scripts, including LLM-calling eval scripts.
- `notebook/` — exploratory Jupyter notebooks. Not production code; fine to be messy, but don't
  import from here into `src/agent/` or `engine/`.
- `data/`, `db/` — local dev data and SQLite files. Contents are gitignored; only `.gitkeep`
  placeholders are tracked.
- `docs/` — architecture notes and technical specs (`docs/SPECS.md`).
- `tests/` — cross-stack integration tests and Python tests. Rust unit/integration tests stay
  inside their own crate (`engine/tests/`, `mcp-server/tests/`), per Rust convention — don't put
  Rust tests here.

### Conventions

- **Rust**: workspace-level `cargo fmt` and `cargo clippy` (pedantic, shared `[workspace.lints]`)
  must pass, and `cargo deny check` (licences, advisories). No `unsafe`; no `unwrap`/`expect`
  outside tests. Shared dependency versions
  go in `[workspace.dependencies]` in the root `Cargo.toml` as the workspace grows.
- **Python**: managed with `uv` (`uv sync`, `uv run ...`), never `pip install` directly. Linted/
  formatted with `ruff` (config in `pyproject.toml`). src-layout: importable code lives under
  `src/agent/`, not at the repo root.
- **TypeScript**: `web/` is a standalone Vite app with its own `package.json`. Lint/format with
  ESLint + Prettier.
- Don't add Docker/Compose service definitions beyond the commented skeleton in
  `docker-compose.yml` until the post-MVP phase — see the comments in that file for why.

### Commands

```bash
# Rust workspace
cargo build
cargo test
cargo clippy --workspace --all-targets

# Web
pnpm -C web install
pnpm -C web run dev

# Python agent
uv sync
uv run ruff check .

# Or via Makefile targets: build, test, run-engine, run-mcp, run-web, run-agent
make help
```

### Docs to keep in sync

- **PROJECT.md** — domain problem (index replication, tracking error, cost-aware rebalancing).
  No implementation detail belongs here.
- **AGENTS.md** — MCP tool contract and agent behavior contract. Implementation should conform
  to this, not the other way around; if implementation needs to diverge from the contract,
  update AGENTS.md in the same change.
- **docs/** — technical architecture and specs, filled in as the corresponding phase is built.

### Code intelligence

This repo is indexed with **GitNexus** (code-first workspace; the specs are short Markdown).

- Refresh: `gitnexus analyze` at the repo root (the hooks also reindex after commits).
- Before changing an `engine` public function, an MCP tool's input/output struct or an axum
  route, run GitNexus impact analysis and list the affected callers in the PR.

## Workflow for coding agents

Humans: the same rules are in [CONTRIBUTING.md](CONTRIBUTING.md).

- **Never commit or push to `main`.** One issue → one branch (`<type>/<issue>-<short-slug>`,
  e.g. `feat/5-optimize-basket-lp`; `<type>` one of `feat`, `fix`, `chore`, `docs`, `refactor`,
  `test`, `perf`, `ci`) → one PR with `Closes #N` → CI green (`ci-pass`, PR title, gitleaks) →
  squash merge by the product owner. Once CI is green, stop: never merge.
- **Issues**: every issue has one `type:*` label, one or more `area:*` labels, one
  `priority:p0|p1|p2` label and the milestone of its roadmap phase. A PR with no issue gets one
  first.
- **Docs-only changes** go in their own small PR, never mixed into a code PR.
- **Start**: read the issue, every issue in its Dependencies, and the
  [docs/SPECS.md](docs/SPECS.md) / AGENTS.md sections it cites. If a dependency is still open,
  stop and say so.
- **Scope**: docs/SPECS.md is the v0 boundary. Anything in its §5, or not in the issue's
  Acceptance, goes under "Left for later" in the PR body, not in the code.
- **PR body**: first line `Closes #N`, or `Part of #N` when the PR is one step. Then What, How,
  Tests, Left for later.
- **Commits**: conventional, `type(scope): lowercase summary`. Scopes: `engine`, `mcp`, `web`,
  `agent`, `eval`, `data`, `docs`, `ci`, `deps`, `repo`.
- **CHANGELOG**: one bullet under `Unreleased` in [CHANGELOG.md](CHANGELOG.md), added in its
  own last commit. Never edit existing bullets.
- **Conflicts**: merge `main` into the branch. Never rebase, never force push (denied by
  `.claude/settings.json`).
- **GitHub**: use `gh api` (REST) for issues and PRs.
- **Before pushing**: `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets --
  -D warnings`, `cargo test --workspace`, `cargo deny check`, plus `uv run ruff check . && uv run pytest` if Python
  changed and `pnpm -C web run lint && pnpm -C web run build` if `web/` changed.
- **Decisions and contracts**: a decision with trade-offs gets an ADR in
  [DECISIONS.md](DECISIONS.md). A contract change updates AGENTS.md and/or docs/SPECS.md in the
  same PR.

## Design principles

1. **Tools are the only source of numbers.** The agent must never compute, estimate, or restate
   a tracking error, a cost, or a weight itself — every quantitative claim in an agent response
   must trace back to a tool call result. If a needed computation has no corresponding tool, the
   agent should say so rather than approximate it.
2. **Tools are deterministic.** Given the same inputs (universe, index data, constraints), a tool
   call must return the same output. No randomness, no hidden state, no reliance on wall-clock
   time inside the optimization itself.
3. **Tools fail loudly and specifically.** An infeasible constraint set (e.g. a turnover budget
   too tight to satisfy position bounds) must return a structured error explaining *which*
   constraint made the problem infeasible — not a generic failure, and not a silently relaxed
   solution.
4. **Tools are side-effect-free by default.** `optimize_basket`, `compute_tracking_error`, and
   `simulate_rebalance` are all read/compute-only: they return a proposal or a measurement, they
   do not persist trades or mutate any stored portfolio state, unless a future tool explicitly
   says otherwise.

## Tool contracts

### `optimize_basket`

**Purpose:** given an index and a candidate security universe, propose basket weights that
minimize expected tracking error subject to constraints.

- **Inputs (conceptual):** target index identifier or its constituent weights; candidate universe
  of securities with risk characteristics; constraint set (position bounds, cardinality cap,
  turnover budget relative to a current basket if provided, long-only).
- **Output (conceptual):** proposed basket weights; the resulting expected tracking error;
  whether the constraint set was feasible; if infeasible, which constraint(s) were binding.
- **Determinism:** identical inputs must produce identical weights (same solver, same tolerance).
- **Performance expectation:** interactive — a single call should be fast enough to support a
  back-and-forth "what if I change X" conversation with the agent, not a batch/offline job.

### `compute_tracking_error`

**Purpose:** given a basket (weights) and a benchmark index, compute the resulting tracking
error, so a candidate or existing basket can be evaluated independently of `optimize_basket`.

- **Inputs (conceptual):** basket weights; index identifier or constituent weights; historical
  return window to use for the estimate.
- **Output (conceptual):** the tracking error figure (annualized), plus enough decomposition
  (e.g. contribution by sector or by name) that the agent can explain *why* TE is what it is, not
  just report a single number.
- **Determinism:** identical inputs (including the return window) must produce an identical
  figure.

### `simulate_rebalance`

**Purpose:** given a current basket and a target (from `optimize_basket` or supplied directly),
compute the trades required and their estimated transaction cost, to make the cost/tracking-error
tradeoff inspectable before any real rebalance decision.

- **Inputs (conceptual):** current basket weights; target basket weights; a transaction cost
  model (spread, market impact, fees — parameters, not hardcoded).
- **Output (conceptual):** the trade list (security, direction, size), total estimated cost, and
  the resulting turnover, so it can be compared against the tracking-error improvement from
  `optimize_basket`'s proposal.
- **Determinism:** identical inputs and cost model must produce an identical trade list and cost.

## Agent behavior contract

- The agent must ground every numeric answer in a tool call made *in that conversation* — it
  must not reuse a number from an earlier turn without re-verifying it still applies (e.g. after
  the user changes a constraint).
- When a request is ambiguous (e.g. "rebalance the fund" without specifying constraints or a
  target index), the agent should ask a clarifying question rather than guessing constraint
  values.
- When a tool call fails (infeasible constraints, unknown security, missing data), the agent must
  surface the actual failure reason returned by the tool, not a generic apology.
- The agent should be able to chain tool calls within one turn when the user's question requires
  it (e.g. "optimize the basket, then tell me what it would cost to get there from what we hold
  now" → `optimize_basket` then `simulate_rebalance`).

## Evaluation

Agent tool-calling correctness and response quality are evaluated with `deepeval` / `ragas`
(see [eval/](eval/), phase 2+ of the roadmap). Evaluation criteria will be derived directly from
this contract: did the agent call the right tool, with the right arguments, and did its natural-
language answer accurately reflect the tool's output.
