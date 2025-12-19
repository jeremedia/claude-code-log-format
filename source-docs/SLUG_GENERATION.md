# Claude Code Slug Generation

**Status**: Validated against Claude Code v2.0.65 (Bun-compiled binary)  
**Last Updated**: 2025-12-12

> Auto-generated slugs like `elegant-whistling-dahl` and where they’re used.

## Source Pointers
- Wordlists + slug builder (`KpR`, `NpR`, `hJD`)
- Plan slug cache and file selection (`ZJD`, `LJD`, `VX`, `Mh`, `CRR`)

## Wordlists & Construction
- Wordlists live in three arrays (`X4B`, `h4B`, `Q4B`):
  - `X4B`: adjectives (e.g., `vectorized`, `resilient`, `cached`, `sparkling`, many new whimsical adjectives).
  - `h4B`: gerunds/verbs (`whistling`, `foraging`, `wobbling`, etc.).
  - `Q4B`: nouns drawn from nature, animals, objects, and computing pioneers (names like `dahl`, `hopper`, `lovelace`, plus new whimsical nouns).
- Random selection:
  - `hJD(len)` → `crypto.randomBytes(4).readUInt32BE(0) % len`
  - `NpR(list)` picks a random element.
  - `KpR()` returns `<adjective>-<verb>-<noun>`.
- Total combinations tracked as `cL8 = X4B.length * h4B.length * Q4B.length`.

## Usage in Plans
- `ZJD(sessionId?)`:
  - Returns a cached slug per session (cache held in `E6T()`).
  - On cache miss, attempts up to `EJD = 10` random slugs, checking for existing files under `~/.claude/plans/`.
  - Slugs are considered taken if a matching markdown file already exists.
- Plan file locations:
  - Base dir: `~/.claude/plans/` (`Mh()`), created on demand.
  - Primary plan path: `~/.claude/plans/<slug>.md` (`VX()` when caller session matches root).
  - Agent-specific variant: `~/.claude/plans/<slug>-agent-<agentSessionId>.md` when writing a plan for a non-root agent (reuses the root session’s slug).
- Helpers:
  - `LJD(sessionId, slug)` manually seeds the cache.
  - `CRR(messages)` detects an existing `slug` on a message chain, seeds the cache, and checks for the presence of `<slug>.md`.

## Validated vs. Speculative
- **Validated**: Wordlists, random selection, uniqueness check via filesystem, plan path construction, reuse of root slugs for agent plans.
- **Speculative**: How/when slugs get attached to assistant messages (only the detection hook `CRR` was traced here).

## Cross-References
- Session/log file placement for plan slugs: `SESSION_MANAGEMENT.md`
- Message logging (where slugs may be attached to messages): `JSONL_LOGGING.md`
