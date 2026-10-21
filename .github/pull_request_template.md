## What

<!-- First line: "Closes #N", or "Part of #N" when this PR is one step of the issue. -->

## How

## Tests

<!-- What you ran and what it covers. -->

## Left for later

<!-- Anything out of the issue's Acceptance or in docs/SPECS.md §5. "Nothing" is fine. -->

## Checklist

- [ ] Conventional commit title (`feat(engine): …`, `fix(mcp): …`)
- [ ] `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`,
      `cargo test --workspace` pass
- [ ] `uv run ruff check . && uv run pytest` pass (if Python touched)
- [ ] `pnpm -C web run lint && pnpm -C web run build` pass (if web touched)
- [ ] Within docs/SPECS.md v0 scope (§5 items are out)
- [ ] AGENTS.md / docs/SPECS.md updated in the same PR if the contract changed
- [ ] One bullet under Unreleased in CHANGELOG.md
