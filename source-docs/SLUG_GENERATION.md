# Claude Code Slug Generation

**Status**: Validated against source (`cli-beautified.js` v2.0.55)  
**Last Updated**: 2025-02-14

> Auto-generated slugs like `elegant-whistling-dahl` and where they’re used.

## Source Pointers
- Wordlists + slug builder (`NQ2`, `LQ2`, `wB5`, `xo1`): `cli-beautified.js:262838-262910`.
- Plan slug cache and file selection (`NB5`, `U_`, `TU`): `cli-beautified.js:262880-262940`.

## Wordlists & Construction
- Defined in `LQ2` (arrays `$Q2`, `wQ2`, `qQ2`):
  - `$Q2`: adjectives (e.g., `elegant`, `sparkling`, `resilient`, `vectorized`).
  - `wQ2`: nouns drawn from nature, animals, objects, and computing pioneers (includes names like `dahl`, `hopper`, `lovelace`).
  - `qQ2`: gerunds/verbs (`whistling`, `crafting`, `tinkering`, etc.).
- Random selection:
  - `wB5(len)` → `crypto.randomBytes(4).readUInt32BE(0) % len`
  - `xo1(list)` picks a random element.
  - `NQ2()` returns `<adjective>-<verb>-<noun>`.
- Total combinations tracked as `SzG = $Q2.length * qQ2.length * wQ2.length`.

## Usage in Plans
- `NB5(sessionId?)`:
  - Returns a cached slug per session (cache: `planSlugCache`, via `nFA()`).
  - On cache miss, attempts up to `qB5 = 10` random slugs, checking for existing files.
  - Slugs are considered taken if a matching markdown file exists under the plans directory.
- Plan file locations:
  - Base dir: `~/.claude/plans/` (`TU()`), created on demand.
  - Primary plan path: `~/.claude/plans/<slug>.md` (`U_()`).
  - Agent-specific variant: `~/.claude/plans/<slug>-agent-<agentSessionId>.md` when writing a plan for a non-root agent.
- Helpers:
  - `LB5(sessionId, slug)` manually seeds the cache.
  - `J01(messages)` detects an existing `slug` field on a message chain, seeds the cache, and checks for the presence of `<slug>.md`.

## Validated vs. Speculative
- **Validated**: Wordlists, random selection, uniqueness check via filesystem, plan path construction.
- **Speculative**: How/when slugs get attached to assistant messages (only the detection hook `J01` was traced here).

## Cross-References
- Session/log file placement for plan slugs: `SESSION_MANAGEMENT.md`
- Message logging (where slugs may be attached to messages): `JSONL_LOGGING.md`
