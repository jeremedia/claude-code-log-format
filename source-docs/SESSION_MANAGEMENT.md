# Claude Code Session Management

**Status**: Validated against Claude Code v2.0.65 (Bun-compiled binary)  
**Last Updated**: 2025-12-12

> How sessions are created, named, located on disk, and rehydrated.

## Source Pointers
- Session ID + globals (`$A`, `XR`, cwd/originalCwd)
- Persistence class `yH_` (file naming, append, load)
- Slug cache for plans (`ZJD`, `LJD`, `CRR`)

## Session Identity
- `sessionId` lives in a process-global store (`IQ.sessionId`).
- Creation: defaults to `crypto.randomUUID()`.
- Override: `XR(newId)` sets the ID and mirrors it to `process.env.CLAUDE_CODE_SESSION_ID` when defined.
- Other session metadata tracked globally: `cwd` (`K0`), `originalCwd`, cost/time/token counters, hook registrations, etc.
- Message metadata now carries `slug`, `agentId`, `isTeammate`, and `logicalParentUuid` to preserve threading across compaction boundaries.

## File Naming & Location
- Project root for persistence: `~/.claude/projects/` (`Mx` + `tI`).
- Per-project subfolder: sanitized current working directory (`PH_` replaces non-alphanumerics with `-`).
- Session log: `<sessionId>.jsonl` (`aGT` → `KVT`).
- Sidechain agent logs: `agent-<agentId>.jsonl` (`B3T`).
- Plan files share the same base config dir but live under `~/.claude/plans/` (see slug generation doc).

## Lifecycle & Persistence
- Writes occur via `yH_.appendEntry` (see `JSONL_LOGGING.md` for event types).
- Persistence is skipped when:
  - Running under `"test"` env and `TEST_ENABLE_SESSION_PERSISTENCE` is not `"true"`.
  - `cleanupPeriodDays` is `0` in settings.
- Files/directories are lazily created with `0o600` permissions and `flush: true`.
- Remote persistence is optional (`setRemoteIngressUrl` + `persistToRemote`); hydration from remote uses `yK9`/`SH_`.

## Loading & Reconstruction
- `loadAllSessions(limit?)` scans all `*.jsonl` under the project folder, building in-memory maps for:
  - `messages` (user/assistant/system/attachment)
  - `summaries` (by `leafUuid`)
  - `customTitles` (by `sessionId`)
  - `tags` (by `sessionId`)
  - `fileHistorySnapshots` (by `messageId`)
- `getAllTranscripts(limit?)` assembles root→leaf chains (non-sidechain roots) and decorates them with summaries/titles/snapshots.
- `getLastLog(sessionId)` selects the newest non-sidechain chain by `timestamp`.
- `flush()` blocks until tracked writes finish (`pendingWriteCount`/`trackWrite`).

## Queue & Snapshot Helpers
- `ve(messages)` / `yDA(messages, agentId?, logicalParent?)` insert a chain (main vs. sidechain) and return the leaf UUID. Compact boundary system events reset `parentUuid` to null and stash `logicalParentUuid` to keep thread continuity.
- `y4B(queueOp)` appends queue operations (`type: "queue-operation"`).
- `l_R(messageId, snapshot, isSnapshotUpdate)` appends file-history snapshots (snapshot objects only).
- `lY()` forces `sessionFile` to point at the current session path (used when priming logs).

## Cross-References
- Event logging and dedupe details: `JSONL_LOGGING.md`
- Tool outputs that generate log entries: `TOOL_EXECUTION_FLOW.md`
- Slug generation for plan files: `SLUG_GENERATION.md`

## Validated vs. Speculative
- **Validated**: Path derivation, sessionId creation/override, load/flush behavior, skip conditions, helper entrypoints above.
- **Speculative**: The long-term retention/cleanup policy hinted by `cleanupPeriodDays` is not enforced in the observed code path during this pass.
