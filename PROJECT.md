# The domain problem: index replication and cost-aware rebalancing

This document explains the business/domain problem this project is about — not the technical
implementation (see [docs/](docs/) for that once it exists). It assumes no prior knowledge of
ETF indexing.

## 1. What an index-replicating ETF actually does

An index fund (or ETF) promises investors the return of a benchmark index — e.g. the S&P 500 or
the Euro Stoxx 50 — minus fees. To deliver that promise, the fund manager has to hold a basket of
securities whose combined return tracks the index's return over time. There are three broad
approaches:

- **Full physical replication** — buy every constituent of the index, at its exact index weight.
  This is the most faithful approach but becomes expensive or impractical for indices with
  thousands of constituents (small illiquid stocks, high rebalancing turnover) or in markets
  with high transaction costs or access restrictions.
- **Optimized / sampling replication** — hold a *subset* of the index constituents (and/or
  slightly different weights), chosen so the basket's expected behavior stays as close as
  possible to the full index, while reducing the number of positions and the amount of trading
  required. This is where the optimization problem in this project lives.
- **Synthetic replication** — use a swap with a counterparty to receive the index return directly,
  without holding the underlying securities. Different risk profile (counterparty risk), out of
  scope for this project.

This project focuses on **optimized physical replication**: given an index and a candidate
universe of securities, construct (and later rebalance) a basket that minimizes tracking error
under real-world constraints.

## 2. Tracking error

**Tracking error (TE)** is the standard measure of how closely a basket follows its benchmark.
Informally: look at the *difference* between the basket's daily (or periodic) return and the
index's daily return, over some history — that difference is the "active return." Tracking error
is the volatility (standard deviation) of that active return series, usually annualized:

```
active_return(t) = basket_return(t) - index_return(t)
TE = annualized_stdev( active_return )
```

A TE of 20 basis points (0.20%) means the basket's return typically deviates from the index's by
about that much per year, in either direction. Fund managers are usually evaluated — and
sometimes contractually bound — on keeping TE below a target threshold.

**Where tracking error comes from**, even for a well-run fund:

- **Sampling** — holding fewer names or different weights than the index, by construction, so the
  basket's factor/sector/single-name exposures aren't identical to the index's.
- **Fees and costs** — management fees, transaction costs from trading, and taxes (e.g. a
  financial transaction tax on certain trades) are a drag on the fund's return that the index
  itself doesn't bear.
- **Cash drag** — a fund typically holds a small cash buffer (for redemptions, dividend timing),
  which doesn't participate in the index's return.
- **Corporate actions and dividend timing** — the index's calculation methodology for handling
  dividends, buybacks, spin-offs, and rebalancing events may not exactly match how the fund
  realizes and reinvests them.
- **Rebalancing lag** — indices are reconstituted periodically (e.g. quarterly); if the fund
  can't trade instantly at the index's effective date, it briefly holds "stale" weights.
- **FX and market access** — for international indices, currency conversion mechanics and access
  restrictions in certain markets can introduce further deviation.

Minimizing tracking error is therefore not just "buy the index" — it's an ongoing optimization
problem, especially when the fund can't (or chooses not to) hold every constituent at its exact
weight.

## 3. Basket optimization under transaction-cost constraints

This is the central computational problem this project models.

### The setup

Periodically (e.g. at each index reconstitution, or when net flows require trading), the fund
manager must decide **what to buy and sell** to keep the basket close to the (possibly changed)
index, while minimizing:

1. **Expected future tracking error** — how well the resulting basket will track the index going
   forward, given each security's risk characteristics (volatility, correlation/beta to the
   index, sector and factor exposure).
2. **Transaction costs incurred to get there** — every trade has a cost: bid-ask spread, market
   impact (larger trades move the price against you), brokerage fees, and in some markets a
   transaction tax. Trading a lot to perfectly match new index weights might minimize *future*
   tracking error but be expensive *today* — and that cost itself hurts the fund's realized
   return relative to the index.

This is fundamentally a **tradeoff between two costs that live on different time horizons**:
the one-time cost of trading now, versus the ongoing cost of tracking error if you under-trade.

### The constraints

A realistic basket optimization isn't unconstrained — it typically has to respect:

- **Full investment**: basket weights sum to 1 (fully invested, ignoring a small cash buffer).
- **Position bounds**: no single position above (or below) some percentage of the fund, often
  tied to regulatory diversification rules (e.g. UCITS 5/10/40 concentration limits).
- **Cardinality**: an optional cap on the *number* of distinct positions, since every extra line
  held has custody, operational, and monitoring cost — the "sampling" aspect of optimized
  replication.
- **Turnover budget**: a limit on how much of the basket can be traded during a given
  rebalancing, since turnover directly drives transaction costs.
- **Long-only / no-shorting** (typically, for a physical ETF), and sometimes sector- or
  factor-neutrality constraints relative to the index.

### The shape of the optimization

Put together, the problem looks like: *choose basket weights that minimize a combination of
(expected tracking error) and (transaction costs to reach those weights from the current basket),
subject to the constraints above.* Depending on how tracking error and costs are modeled, this
can be formulated as a linear program (LP) or a quadratic program (QP) — which is why this
project uses [`good_lp`](https://crates.io/crates/good_lp) with the HiGHS solver as the
optimization backend: a fast, well-tested LP/QP solver that can be called repeatedly as
scenarios change.

Three related computations fall out of this framing, which is why they're the three tools this
project's engine exposes:

- **`optimize_basket`** — given an index, a candidate universe, and constraints, produce basket
  weights that minimize expected tracking error.
- **`compute_tracking_error`** — given a basket and an index (or their historical return series),
  compute the resulting tracking error, to evaluate a candidate basket or an existing one.
- **`simulate_rebalance`** — given a *current* basket and a *target* basket (or new constraints),
  compute the trades required and their estimated transaction cost, so the cost/tracking-error
  tradeoff can be inspected before committing to a rebalance.

## 4. Why this is interesting to build (and to expose to an LLM agent)

The optimization itself is a well-studied quantitative finance problem, but it's also naturally
interactive: a portfolio manager rarely runs it once and stops. They ask "what if I cap turnover
at 5% instead of 10%?", "what if I exclude these three illiquid names?", "how much would relaxing
the position bound to 8% save in tracking error?". That back-and-forth — re-running a constrained
optimization with slightly different parameters and explaining the result in plain language — is
exactly the kind of workflow that benefits from being exposed as **tool calls an LLM agent can
invoke**, rather than a one-shot batch script or a form-based UI. It's also why the tools are
specified as a strict contract (see [AGENTS.md](AGENTS.md)): the agent should call real,
deterministic optimization code and report its actual output, not approximate or hallucinate
what the numbers would be.
