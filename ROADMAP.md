# Roadmap

Phased plan for this project. Each phase has one objective, concrete deliverables, and a status.
For *what* each layer should do once built, see [AGENTS.md](AGENTS.md) (tool contract) and
[docs/SPECS.md](docs/SPECS.md) (v0 technical design, referenced explicitly in Phase 1).

**Status legend:** ✅ Terminé · 🚧 En cours · ⬜ À faire

## Phase 0 — Environnement & setup

**Objectif :** mettre en place l'environnement de dev et la structure du repo pour pouvoir
commencer à coder sans friction.

- [x] Toolchain Rust (rustup, cargo, clippy, rustfmt) fonctionnelle sous WSL
- [x] Toolchain Python (`uv`) et Node installées
- [x] Cargo workspace (`engine` + `mcp-server`) qui compile (`cargo build --workspace`)
- [x] Scaffold complet : arborescence des dossiers, README.md, PROJECT.md, AGENTS.md, CLAUDE.md
- [x] CI GitHub Actions en place (lint/build/test Rust + Python + Node)
- [x] `.pre-commit-config.yaml` configuré (cargo fmt/clippy, ruff, eslint/prettier)
- [x] Licence MIT (`LICENSE`)

**Statut : ✅ Terminé**

## Phase 1 — MVP moteur + MCP server

**Objectif :** un moteur d'optimisation fonctionnel, exposé via les 3 tools MCP, testable depuis
MCP Inspector et Claude Desktop — sur le périmètre v0 strictement défini dans
[docs/SPECS.md](docs/SPECS.md). C'est la phase la plus à risque de dérive de scope : le but est
un MVP livrable en **quelques jours, pas plus**. Tout ce qui n'est pas listé ci-dessous appartient
à une phase suivante ou à `docs/SPECS.md` §5 (hors scope v0) — pas à Phase 1.

- [ ] Modèle de données (`engine/src/model.rs`) : `Security`, `Index`, `Basket`, `Constraints`,
      `Trade`, `ToolError`, conformes à docs/SPECS.md §1
- [ ] Jeu de données v0 : 30 tickers réels + secteurs + poids d'indice illustratifs (CSV dans
      `data/`), générateur de rendements synthétiques à seed fixe (docs/SPECS.md §3)
- [ ] `optimize_basket` : LP via `good_lp` + HiGHS (proxy L1, cf. docs/SPECS.md §4), avec support
      MIP pour `max_positions` quand la cardinalité est contrainte
- [ ] `compute_tracking_error` : calcul de la TE réelle (écart-type annualisé) depuis les
      rendements synthétiques + décomposition par secteur
- [ ] `simulate_rebalance` : liste de trades, coût total, turnover, depuis un panier courant et
      un panier cible
- [ ] Tests unitaires (`engine/tests/`) : au moins un cas faisable, un cas infaisable
      (`optimize_basket`), un calcul de TE de sanity check, un calcul de coût/turnover
- [ ] `mcp-server` : les 3 tools exposés via `rmcp`, schémas conformes à docs/SPECS.md §2
- [ ] Route(s) `axum` minimales exposant les mêmes 3 opérations en HTTP (sans authentification —
      juste assez pour que la Phase 2 puisse s'y brancher, pas une conception d'API complète)
- [ ] Validation manuelle : les 3 tools s'appellent et répondent correctement via **MCP
      Inspector**, et via une config **Claude Desktop** pointant sur `mcp-server`

Explicitement hors de cette phase : dashboard web, agent, persistance (`db/`), Docker — voir
docs/SPECS.md §5 pour la liste complète et le pourquoi de chaque exclusion.

**Statut : ⬜ À faire**

## Phase 2 — Frontend

**Objectif :** dashboard React/TS connecté à l'API `axum`, visualisant la composition du panier
et la tracking error.

- [ ] Génération des types TS depuis les structs Rust (`ts-rs`/`typeshare`) dans `web/src/types`
- [ ] Vue composition du panier (table/chart, poids panier vs poids indice)
- [ ] Affichage de la tracking error + décomposition sectorielle
- [ ] UI pour déclencher `optimize_basket` / `simulate_rebalance` contre l'API `mcp-server` et
      afficher les résultats
- [ ] Coquille du panneau de chat en place (branché à l'agent en Phase 3, pas avant)

**Statut : ⬜ À faire**

## Phase 3 — Agent

**Objectif :** agent LangChain + Azure OpenAI consommant le serveur MCP, avec des premiers
scénarios d'usage end-to-end.

- [ ] Implémentation `src/agent/` : agent LangChain, client MCP, configuration Azure OpenAI
- [ ] L'agent respecte le contrat de comportement d'AGENTS.md (ancrage sur les tool calls,
      questions de clarification, remontée fidèle des erreurs de tool)
- [ ] Panneau de chat de `web/` branché à l'agent
- [ ] Quelques scénarios d'usage end-to-end documentés/testés manuellement (ex. l'enchaînement
      `optimize_basket` → `simulate_rebalance` décrit dans AGENTS.md)

**Statut : ⬜ À faire**

## Phase 4 — Évaluation

**Objectif :** évaluer automatiquement la justesse des appels d'outils et la qualité des
réponses de l'agent, en écho à l'usage de `ragas` en production chez Amundi.

- [ ] Harnais d'évaluation dans `eval/` (`deepeval` et/ou `ragas`)
- [ ] Cas de test dérivés directement du contrat d'AGENTS.md (tool-calling correctness,
      fidélité de la réponse en langage naturel au résultat du tool)
- [ ] Scripts d'éval dans `scripts/llm/`, appelés par le harnais `eval/`
- [ ] Premier rapport/metrics baseline sur l'agent de la Phase 3

**Statut : ⬜ À faire**

## Phase 5 — Productionisation

**Objectif :** rendre le projet déployable et durcir le pipeline ; bonus WASM optionnel.

- [ ] Dockerfiles pour `mcp-server`, `web`, `agent` ; activation des services commentés dans
      `docker-compose.yml`
- [ ] Durcissement CI (lockfiles committés, caching, éventuellement build/push d'image)
- [ ] README mis à jour avec des instructions de lancement via Docker
- [ ] *(Bonus, optionnel)* compilation d'une partie de `engine` en WASM pour du recalcul
      interactif côté navigateur, per la section "bonus futur" du README

**Statut : ⬜ À faire**
