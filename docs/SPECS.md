# Technical specifications — v0

This document is the technical design for the v0 (MVP) engine and MCP server: the data model,
the exact request/response schema for each MCP tool defined in [AGENTS.md](../AGENTS.md), the
functional scope of v0, and what is explicitly excluded from it.

It complements, but does not replace:
- [PROJECT.md](../PROJECT.md) — the domain problem (index replication, tracking error), no
  implementation detail.
- [AGENTS.md](../AGENTS.md) — the tool *contract* (purpose, principles, determinism). This
  document fills in the exact types behind that contract's "conceptual" input/output descriptions.
- [ROADMAP.md](../ROADMAP.md) — when this spec is implemented (Phase 1).

> Status: design only, nothing below is implemented yet. Field names use `snake_case` because
> they're the wire format (MCP tool JSON / axum API JSON) as well as the natural `serde` mapping
> for the Rust structs — the two are meant to be the same shape, not translated.

## 1. Data model

These types are the shared vocabulary between `engine`, `mcp-server`, and (once generated via
`ts-rs`/`typeshare` in Phase 2) `web/`. Suggested location: `engine/src/model.rs`; not mandated,
but tool inputs/outputs in §2 are built directly out of these types, so keeping them in one place
in `engine` (rather than duplicated in `mcp-server`) matters more than the exact file name.

```rust
/// A single tradable security in the v0 universe.
pub struct Security {
    pub ticker: String,
    pub name: String,
    pub sector: String,
}

/// One constituent of a benchmark index, with its index weight.
pub struct IndexConstituent {
    pub ticker: String,
    /// Fraction of the index, in [0, 1]. Constituent weights sum to 1.0 across an Index.
    pub weight: f64,
}

/// A benchmark index: a fixed, named set of weighted constituents.
/// v0 ships exactly one static Index — see §3.
pub struct Index {
    pub id: String,
    pub name: String,
    pub constituents: Vec<IndexConstituent>,
}

/// One position in a basket.
pub struct BasketPosition {
    pub ticker: String,
    /// Fraction of the basket, in [0, 1].
    pub weight: f64,
}

/// A candidate or held basket: a set of weighted positions. Not required to reference every
/// Index constituent — that's the point of optimized/sampling replication (see PROJECT.md §1).
pub struct Basket {
    pub positions: Vec<BasketPosition>,
}

/// Constraints for `optimize_basket` and `simulate_rebalance`.
pub struct Constraints {
    /// Per-position lower bound, in [0, 1]. Applies to any security included in the basket
    /// (a security not included is implicitly at weight 0, regardless of this bound).
    pub min_weight: f64,
    /// Per-position upper bound, in [0, 1].
    pub max_weight: f64,
    /// Maximum number of non-zero positions in the resulting basket. `None` = unconstrained
    /// (every security in the candidate universe may be held). See §4 for why this turns the
    /// solve from an LP into a MIP.
    pub max_positions: Option<usize>,
    /// Flat transaction cost per unit of notional traded, in basis points (see §4 — v0 uses a
    /// single flat rate, not a per-security cost curve).
    pub transaction_cost_bps: f64,
}

/// A single trade in a `simulate_rebalance` result.
pub struct Trade {
    pub ticker: String,
    pub direction: TradeDirection,
    /// Absolute change in weight this trade represents, in [0, 1].
    pub delta_weight: f64,
}

pub enum TradeDirection {
    Buy,
    Sell,
}
```

**Units, consistently across every tool:** weights are fractions in `[0, 1]` (not percent);
tracking error, volatility, and cost figures are in basis points (`1 bps = 0.0001`), matching the
convention already used in PROJECT.md.

**Errors.** All three tools share one error shape rather than each inventing their own:

```rust
pub enum ToolError {
    /// The constraint set has no feasible solution. `reason` names the binding constraint(s)
    /// (e.g. "max_positions=5 cannot satisfy max_weight=0.10 with a fully-invested basket").
    Infeasible { reason: String },
    UnknownTicker { ticker: String },
    UnknownIndex { index_id: String },
    InvalidConstraints { reason: String },
}
```

This directly implements AGENTS.md's principle #3 ("tools fail loudly and specifically") — an
`Infeasible` error must always carry a human-readable `reason`, never just a boolean failure.

## 2. MCP tool schemas

### `optimize_basket`

**Input**

| Field | Type | Required | Notes |
|---|---|---|---|
| `index_id` | `string` | yes | Must match a known `Index.id` (v0: one supported value, see §3). |
| `universe` | `string[]` (tickers) | no | Candidate securities the basket may hold. Defaults to all constituents of `index_id`. |
| `constraints` | `Constraints` | no | Defaults: `min_weight=0.0`, `max_weight=1.0`, `max_positions=None`, `transaction_cost_bps=0.0`. |
| `current_basket` | `Basket` | no | If provided, `constraints.transaction_cost_bps` is applied against the distance from this basket to the proposal (see §4). If omitted, the objective is pure active-weight minimization with no cost term. |

**Output**

| Field | Type | Notes |
|---|---|---|
| `feasible` | `boolean` | If `false`, `basket` is absent and `infeasible_reason` is set. |
| `basket` | `Basket \| null` | The proposed weights. |
| `expected_tracking_error_bps` | `number \| null` | TE of `basket` against `index_id`, computed the same way as `compute_tracking_error` would (§2.2) — not the solver's internal objective value, which uses a different (L1) proxy, see §4. |
| `infeasible_reason` | `string \| null` | Set iff `feasible=false`. |

### `compute_tracking_error`

**Input**

| Field | Type | Required | Notes |
|---|---|---|---|
| `index_id` | `string` | yes | |
| `basket` | `Basket` | yes | |
| `lookback_days` | `integer` | no | Defaults to the full synthetic history available (v0: 252 trading days, see §3). |

**Output**

| Field | Type | Notes |
|---|---|---|
| `tracking_error_bps` | `number` | Annualized stdev of (basket return − index return) over the lookback window. |
| `basket_volatility_bps` | `number` | Annualized stdev of the basket's own return. |
| `index_volatility_bps` | `number` | Annualized stdev of the index's own return. |
| `active_weight_by_sector` | `Record<string, number>` | `basket sector weight − index sector weight`, per sector — the decomposition AGENTS.md asks for so the agent can explain *why* TE is what it is, not just report a number. |

### `simulate_rebalance`

**Input**

| Field | Type | Required | Notes |
|---|---|---|---|
| `current_basket` | `Basket` | yes | |
| `target_basket` | `Basket` | yes | Typically the `basket` from a prior `optimize_basket` call, but any basket is accepted. |
| `constraints` | `Constraints` | no | Only `transaction_cost_bps` is used by this tool; other fields are ignored (no re-optimization happens here — see §4). Defaults to `transaction_cost_bps=0.0`. |

**Output**

| Field | Type | Notes |
|---|---|---|
| `trades` | `Trade[]` | One entry per ticker whose weight changes between `current_basket` and `target_basket`. |
| `total_cost_bps` | `number` | `transaction_cost_bps × turnover`. |
| `turnover` | `number` | `Σ \|target_weight − current_weight\| / 2`, in `[0, 1]`. |

## 3. Functional scope of v0

- **Universe:** a fixed, static set of **30 real, well-known large-cap US equities** across
  roughly 8–10 GICS-style sectors (Technology, Health Care, Financials, Consumer Discretionary,
  Consumer Staples, Industrials, Energy, Communication Services, Utilities, Materials) — the kind
  of names a S&P 500 subset would include (e.g. `AAPL`, `MSFT`, `JPM`, `JNJ`, `XOM`, ...). The
  exact 30-ticker list is finalized during Phase 1 implementation and bundled as a static CSV
  under `data/`.
- **Index weights are illustrative, not licensed data.** Sector and approximate relative-size
  weights are hand-curated to *look like* a plausible large-cap benchmark subset; they are not
  sourced from, or claimed to be, an official S&P/MSCI index file. This project does not
  reproduce or redistribute any licensed index provider data.
- **One static index, one currency.** v0 ships exactly one `Index` (`id = "us_large_cap_30"`),
  denominated in USD. No multi-index, no multi-currency.
- **Returns are synthetic, not real historical prices.** A daily return series per security
  (v0: 252 trading days) is generated once from a **fixed random seed**, using a simple one-factor
  model (a sector factor + idiosyncratic noise per security) so that same-sector names are
  correlated the way real equities roughly are, without fetching or redistributing any real price
  history. Generated once and cached as a CSV under `data/` for reproducibility — not
  regenerated on every run.
- **Tools are stateless.** No basket, trade, or optimization result is persisted anywhere (per
  AGENTS.md principle #4). `db/` is not used in v0.

## 4. Deliberate simplifications (v0 vs. a real production engine)

These are explicit, not accidental — each is a scope cut made to keep Phase 1 shippable in a few
days (see ROADMAP.md), not a claim that this is how a real replication engine would work.

- **The solver minimizes an L1 proxy, not the real (co)variance-based tracking error.**
  `optimize_basket` solves a **linear program**: minimize `Σ |basket_weight_i − index_weight_i|`
  (plus, if `current_basket` is given, `transaction_cost_bps × Σ |basket_weight_i −
  current_weight_i|`), subject to `min_weight`/`max_weight`/full-investment. This keeps v0
  solvable with `good_lp` + HiGHS as a pure LP. The *real* tracking-error metric — variance of
  the basket-vs-index return difference — is only computed for **reporting**, via
  `compute_tracking_error`, directly from the synthetic return series; it does not feed back into
  the solver's objective in v0. A covariance-aware (quadratic) objective is a natural Phase 1+
  follow-up, not part of v0.
- **Cardinality makes the problem a MIP, not an LP, when set.** `max_positions` is implemented
  with a binary indicator variable per candidate security (HiGHS supports MIP); when
  `max_positions` is `None`, the solve stays a pure LP. This is called out because it's a real
  complexity jump, not a free constraint to add.
- **Transaction cost is a single flat rate**, not a per-security bid-ask spread, market-impact
  curve, or tax. `transaction_cost_bps` applies uniformly to every unit of weight traded.
- **No turnover budget or sector-neutrality constraint in the solver.** Both are described as
  real-world constraints in PROJECT.md §3, but v0's `Constraints` struct deliberately only
  implements the three the roadmap needs for a working end-to-end MVP: weight bounds,
  transaction cost, cardinality.
- **No index reconstitution events, dividends, or corporate actions.** The index composition is
  a fixed snapshot for the lifetime of v0.

## 5. Explicitly out of scope for v0

- Multi-currency / FX handling of any kind.
- Real, licensed, or real-time market data (no Bloomberg/FactSet connector, no live price feed —
  static synthetic dataset only, per §3).
- Authentication or authorization on the MCP server or the axum API.
- Persistence of baskets, trades, or optimization runs (no real use of `db/` yet — tools are
  stateless per AGENTS.md).
- Realistic transaction cost modeling: no market-impact curve, no per-security bid-ask spread, no
  transaction taxes.
- Turnover budget and sector/factor-neutrality constraints in the optimizer (domain concepts
  described in PROJECT.md, not modeled in v0's solver — see §4).
- Multiple simultaneous indices/benchmarks.
- Periodic/automatic index reconstitution, dividends, corporate actions.
- Automatic Rust↔TS type generation (`ts-rs`/`typeshare` wiring) — arrives with the frontend
  (Phase 2); v0's types exist only in Rust.
- The web dashboard, the LangChain agent, and the evaluation harness — separate phases (see
  [ROADMAP.md](../ROADMAP.md)).
- Docker/Compose deployment, load/perf testing.
