# Agent & MCP tool contract

This document specifies the expected behavior of the MCP tools exposed by `mcp-server` and of
the LangChain agent in `src/agent/`. It is an **interface contract**, written before any
implementation exists, so that the engine, the MCP layer, and the agent are all built towards the
same expectations. See [PROJECT.md](PROJECT.md) for the domain background behind each tool.

> Status: contract only. No tool below is implemented yet.

**Language:** everything in this repository is written in English — docs, code, comments,
docstrings, commit messages, tool descriptions, and error messages. This holds even when the
person asking for the change writes in another language.

## Workflow for coding agents

Humans: the same rules are in [CONTRIBUTING.md](CONTRIBUTING.md).

- **Never commit or push to `master`.** One issue → one branch (`feat/`, `fix/`, `chore/` or
  `docs/` plus a short slug) → one PR. CI green, then squash merge by the product owner.
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
- **Conflicts**: merge `master` into the branch. Never rebase, never force push (denied by
  `.claude/settings.json`).
- **GitHub**: use `gh api` (REST) for issues and PRs.
- **Before pushing**: `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets --
  -D warnings`, `cargo test --workspace`, plus `uv run ruff check . && uv run pytest` if Python
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
