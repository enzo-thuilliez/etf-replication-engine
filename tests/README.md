# Tests

Cross-stack integration tests (e.g. agent → MCP server → engine, end-to-end) and Python unit
tests. Rust unit/integration tests stay inside their own crate (`engine/tests/`,
`mcp-server/tests/`), per standard Rust convention — don't put Rust tests here.

No tests yet — engine/mcp-server/agent have no implementation to test.
