# Claude Code JSONL Logging

**Status**: Validated against Claude Code v2.0.65 (Bun-compiled binary)  
**Last Updated**: 2025-12-12

> How Claude Code persists chat/timeline events into per-project JSONL files.

## Storage Layout
- Base directory: `~/.claude/projects/` (path helpers `Mx`, `tI`).
- The current working directory is sanitized (`PH_` strips non-alphanumerics to `-`) to form a per-project folder.
- Primary session file: `~/.claude/projects/<sanitized-cwd>/<sessionId>.jsonl` (`aGT` → `KVT`).
- Sidechain agents: `~/.claude/projects/<sanitized-cwd>/agent-<agentId>.jsonl` when `isSidechain && agentId` (`B3T`).
- Plan-related slugs are cached per session but do **not** affect log filenames.

## Source Pointers
- Path helpers (`Mx`, `PH_`, `tI`, `KVT`, `B3T`)
- Persistence class `yH_` (`insertMessageChain`, `appendEntry`, `loadAllSessions`, `persistToRemote`)
- Remote hydration helpers (`SH_`, `setRemoteIngressUrl`)

## Session Lifecycle
- Session IDs come from a process-global store (`A0`), defaulting to `crypto.randomUUID()` (`mH0`). `XR` can overwrite the session ID and mirrors it to `CLAUDE_CODE_SESSION_ID` if present.
- Logs are only written when:
  - `NODE_ENV` equivalent (`nS3()`) is not `"test"` **or** `TEST_ENABLE_SESSION_PERSISTENCE=true`.
  - `cleanupPeriodDays` setting is not zero (`k0()?.cleanupPeriodDays === 0` short-circuits writes).
- Directory/files are created lazily on the first `appendEntry`, with mode `0o600` and `flush: true` for durability.

## appendEntry Pipeline
Source: `appendEntry` in `yH_`.

- Synchronous, line-delimited appends using `fs.appendFileSync`.
- Special-cased event types (always written):
  - `summary`
  - `custom-title`
  - `tag`
  - `file-history-snapshot`
  - `queue-operation`
- All other entries:
  - Deduplicated per session via a cached `Set` (`kH_(sessionId)`); skips if `uuid` already logged.
  - If `isSidechain` and `agentId` present, the entry is written to `agent-<id>.jsonl`; otherwise to the main session file.
  - For `user`/`assistant`/`attachment`/`system` events, an optional remote ingress hook is invoked (`persistToRemote`).

### Remote Ingress
- `setRemoteIngressUrl(url)` enables remote mirroring; `persistToRemote(sessionId, entry)` posts via `BP2`. Failures emit `tengu_session_persistence_failed`.
- `yK9(sessionId, url)` can hydrate local logs from the remote endpoint before continuing.

## Message Insertion Helpers
- `insertMessageChain(messages, isSidechain=false, agentId?)`
  - Adds metadata to each message before appending:
    - `parentUuid`/`logicalParentUuid` threading (compact boundary events reset the chain to null).
    - `isSidechain`, `isTeammate` (when running teammate mode), `userType` (`"external"`), `cwd`, `sessionId`, `gitBranch` (from `XM()`), `agentId`, `slug` (plan slug cache), version info (`VERSION: 2.0.65`).
  - Updates an in-memory `messages` map for reconstruction.
- `insertQueueOperation(entry)` logs queue changes (`type: "queue-operation"` with enqueue/dequeue/remove metadata).
- `insertFileHistorySnapshot(messageId, snapshot, isSnapshotUpdate)` captures file diff snapshots alongside messages. Structure is now `{type, messageId, snapshot, isSnapshotUpdate}` (no `uuid`/`sessionId`/`cwd`).
- `xK9(leafUuid, summary)` writes `summary` events; `_I1(sessionId, title)` writes `custom-title` and caches it.

## Reading & Reconstruction
- `loadAllSessions(limit?)` scans `*.jsonl` under the project folder, parsing into in-memory maps for messages, summaries, custom titles, tags, and file-history snapshots. File names are sanitized with `nX(basename(...))`.
- `getAllTranscripts(limit?)` returns root-to-leaf chains (non-sidechain roots only), enriched with cached summaries/titles/snapshots via `uF0`.
- `getLastLog(sessionId)` returns the latest non-sidechain message chain (sorted by `timestamp`).
- `flush()` resolves once outstanding tracked writes complete (`trackWrite`/`pendingWriteCount`).

## Event Triggers (observed)
- **User/assistant/system/attachment** messages flow through `insertMessageChain`.
- **Summaries** are written when summarization completes (`xK9` callers).
- **Custom titles** are recorded when the UI/user renames a session (`_I1`).
- **Queue operations** originate from the command queue (`ORA` invocations).
- **File history snapshots** come from the file checkpointing subsystem (`wGT`/`UGT` → `l_R`), which records per-message snapshots of tracked files and rewinds; emits `file-history-snapshot` entries whenever a snapshot or backup update is taken.
- **Auto-summarization**: during startup initialization, a maintenance task (`r4_`) runs once (unless `ZD()` disables it). It scans `~/.claude/projects/*/*.jsonl` for conversations lacking a stored summary, builds a prompt via `_D1`/`RD1`, and writes a `summary` event with `MH_(leafUuid, summary)` when a model response is returned.
- **Compaction**: auto-compaction (`mZB` → `M_R`/`N_R`) emits a `system` `compact_boundary` marker (`K_R`) plus a compacted summary block when token thresholds are exceeded (defaults derived from context window; can be disabled via `DISABLE_COMPACT`). Manual compaction path also uses `K_R` with `trigger: "manual"` and attaches a compact summary text block marked `isCompactSummary`.

## Cross-References
- Session lifecycle, path derivation: `SESSION_MANAGEMENT.md`
- Tool outputs flowing into logs: `TOOL_EXECUTION_FLOW.md`
- Plan slug cache used by messages: `SLUG_GENERATION.md`

## Validated vs. Speculative
- **Validated**: Paths, file naming, append/dedupe logic, sidechain handling, remote ingress call sites (`appendEntry`, `persistToRemote`, `insert*` helpers), new metadata fields (`logicalParentUuid`, `isTeammate`, `slug`, `agentId`).
- **Validated**: `summary` events are produced by the auto-summarizer `r4_` (invoked once at startup) calling `MH_` after `_D1`/`RD1` construct a summary prompt/response; disabled via `ZD()`.
- **Validated**: `file-history-snapshot` events are produced by the file checkpointing subsystem during track/flush (`wGT`/`UGT`/`l_R`); rewinds/read paths also log snapshots when copying backups.
- **Validated**: `compact_boundary` events are emitted by the compaction pipeline (`mZB` → `M_R`/`N_R`) when token thresholds are exceeded or when a manual compact is triggered.
- **Speculative**: Token thresholds and override env vars for compaction are inferred from the compaction helpers; exact values may change by model/window.
