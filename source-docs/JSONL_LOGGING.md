# Claude Code JSONL Logging

**Status**: Validated against source (`cli-beautified.js` v2.0.55)  
**Last Updated**: 2025-02-14

> How Claude Code persists chat/timeline events into per-project JSONL files.

## Storage Layout
- Base directory: `~/.claude/projects/` (function `AFA`, `uQ`). The current working directory is sanitized (`aS3` strips non-alphanumerics to `-`) to form a per-project folder (`fH`, `Xa = K0()`).
- Primary session file: `~/.claude/projects/<sanitized-cwd>/<sessionId>.jsonl` (`PJA` → `FjA`).
- Sidechain agents: `~/.claude/projects/<sanitized-cwd>/agent-<agentId>.jsonl` when `isSidechain && agentId` (`gXA`).
- Plan-related slugs are cached per session but do **not** affect log filenames.

## Source Pointers
- Path helpers (`FjA`, `gXA`, `fH`, `AFA`): `cli-beautified.js:435000-435090`.
- `_K9.appendEntry` core logic: `cli-beautified.js:435046-435210`.
- `loadAllSessions` and transcript reconstruction helpers: `cli-beautified.js:435210-435520`.

## Session Lifecycle
- Session IDs come from a process-global store (`A0`), defaulting to `crypto.randomUUID()` (`mH0`). `XR` can overwrite the session ID and mirrors it to `CLAUDE_CODE_SESSION_ID` if present.
- Logs are only written when:
  - `NODE_ENV` equivalent (`nS3()`) is not `"test"` **or** `TEST_ENABLE_SESSION_PERSISTENCE=true`.
  - `cleanupPeriodDays` setting is not zero (`k0()?.cleanupPeriodDays === 0` short-circuits writes).
- Directory/files are created lazily on the first `appendEntry`, with mode `0o600` and `flush: true` for durability.

## appendEntry Pipeline
Source: `appendEntry` in `_K9` (`cli-beautified.js:435134`).

- Synchronous, line-delimited appends using `fs.appendFileSync`.
- Special-cased event types (always written):
  - `summary`
  - `custom-title`
  - `file-history-snapshot`
  - `queue-operation`
- All other entries:
  - Deduplicated per session via a cached `Set` (`vK9(sessionId)`); skips if `uuid` already logged.
  - If `isSidechain` and `agentId` present, the entry is written to `agent-<id>.jsonl`; otherwise to the main session file.
  - For user/assistant/attachment/system events (`K80`), an optional remote ingress hook is invoked (`persistToRemote`).

### Remote Ingress
- `setRemoteIngressUrl(url)` enables remote mirroring; `persistToRemote(sessionId, entry)` posts via `BP2`. Failures emit `tengu_session_persistence_failed`.
- `yK9(sessionId, url)` can hydrate local logs from the remote endpoint before continuing.

## Message Insertion Helpers
- `insertMessageChain(messages, isSidechain=false, agentId?)`
  - Adds metadata to each message before appending:
    - `parentUuid`/`logicalParentUuid` threading (null for root).
    - `isSidechain`, `userType` (`"external"`), `cwd` (`K0()`), `sessionId`, `gitBranch` (from `fb()`), `agentId`, `slug` (plan slug cache), version info (`VERSION: 2.0.55`).
  - Updates an in-memory `messages` map for reconstruction.
- `insertQueueOperation(entry)` logs queue changes (`type: "queue-operation"` with enqueue/dequeue/remove metadata).
- `insertFileHistorySnapshot(messageId, snapshot, isSnapshotUpdate)` captures file diff snapshots alongside messages.
- `xK9(leafUuid, summary)` writes `summary` events; `_I1(sessionId, title)` writes `custom-title` and caches it.

## Reading & Reconstruction
- `loadAllSessions(limit?)` scans `*.jsonl` under the project folder, parsing into in-memory maps for messages, summaries, custom titles, and file-history snapshots.
- `getAllTranscripts(limit?)` returns root-to-leaf chains (non-sidechain roots only), enriched with cached summaries/titles/snapshots via `uF0`.
- `getLastLog(sessionId)` returns the latest non-sidechain message chain (sorted by `timestamp`).
- `flush()` resolves once outstanding tracked writes complete (`trackWrite`/`pendingWriteCount`).

## Event Triggers (observed)
- **User/assistant/system/attachment** messages flow through `insertMessageChain`.
- **Summaries** are written when summarization completes (`xK9` callers).
- **Custom titles** are recorded when the UI/user renames a session (`_I1`).
- **Queue operations** originate from the command queue (`ORA` invocations).
- **File history snapshots** come from tooling that captures file states (`h21`).

## Cross-References
- Session lifecycle, path derivation: `SESSION_MANAGEMENT.md`
- Tool outputs flowing into logs: `TOOL_EXECUTION_FLOW.md`
- Plan slug cache used by messages: `SLUG_GENERATION.md`

## Validated vs. Speculative
- **Validated**: Paths, file naming, append/dedupe logic, sidechain handling, remote ingress call sites (`appendEntry`, `persistToRemote`, `insert*` helpers).
- **Speculative**: Upstream triggers for `summary` / `file-history-snapshot` are inferred from helper names; exact caller graph not fully traced in this pass.
