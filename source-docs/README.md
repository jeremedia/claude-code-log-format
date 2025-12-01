# Claude Code Source Documentation (from cli-beautified.js v2.0.55)

This folder houses reverse-engineered notes from the bundled `cli-beautified.js`. Each file is scoped and cross-linked:

- `JSONL_LOGGING.md` — How session logs are written, deduped, sidechained, and mirrored remotely.
- `SESSION_MANAGEMENT.md` — Session IDs, path layout, load/flush helpers, persistence skip conditions.
- `TOOL_EXECUTION_FLOW.md` — Tool queue/dispatch, pre/post hooks, permission gating, telemetry/error surfaces.
- `SLUG_GENERATION.md` — Wordlists and slug assignment for plan files.
- `CONTEXT_MANAGEMENT.md` — Context window heuristics, thinking budgets, and current gaps around pruning/summarization.

All line references point into `cli-beautified.js` (from `/tmp/package/cli-beautified.js`). If updating to a new version, re-run the searches and refresh anchors.
