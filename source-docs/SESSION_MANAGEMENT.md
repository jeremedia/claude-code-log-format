# Claude Code Session Management

**Status**: Validated against source (`cli-beautified.js` v2.0.55)  
**Last Updated**: 2025-02-14

> How sessions are created, named, located on disk, and rehydrated.

## Source Pointers
- Session ID + globals (`A0`, `mH0`, `XR`, cwd/originalCwd): `cli-beautified.js:2019-2040` and `30609+` for `K0`.
- Persistence class `_K9` (file naming, append, load): `cli-beautified.js:435046-435520`.
- Slug cache for plans (see `NB5`/`U_` helpers): `cli-beautified.js:262838-262920`.

## Session Identity
- `sessionId` lives in a process-global store (`IQ.sessionId`).
- Creation: `mH0()` assigns `crypto.randomUUID()` by default.
- Override: `XR(newId)` sets the ID and mirrors it to `process.env.CLAUDE_CODE_SESSION_ID` when defined.
- Other session metadata tracked globally: `cwd` (`K0`), `originalCwd`, cost/time/token counters, hook registrations, etc.

## File Naming & Location
- Project root for persistence: `~/.claude/projects/` (`uQ` + `AFA`).
- Per-project subfolder: sanitized current working directory (`aS3` replaces non-alphanumerics with `-`; `fH(Xa)`).
- Session log: `<sessionId>.jsonl` (`PJA` → `FjA`).
- Sidechain agent logs: `agent-<agentId>.jsonl` (`gXA`).
- Plan files share the same base config dir but live under `~/.claude/plans/` (see slug generation doc).

## Lifecycle & Persistence
- Writes occur via `_K9.appendEntry` (see `JSONL_LOGGING.md` for event types).
- Persistence is skipped when:
  - Running under `"test"` env and `TEST_ENABLE_SESSION_PERSISTENCE` is not `"true"`.
  - `cleanupPeriodDays` is `0` in settings.
- Files/directories are lazily created with `0o600` permissions and `flush: true`.
- Remote persistence is optional (`setRemoteIngressUrl` + `persistToRemote`); hydration from remote uses `yK9`.

## Loading & Reconstruction
- `loadAllSessions(limit?)` scans all `*.jsonl` under the project folder, building in-memory maps for:
  - `messages` (user/assistant/system/attachment)
  - `summaries` (by `leafUuid`)
  - `customTitles` (by `sessionId`)
  - `fileHistorySnapshots` (by `messageId`)
- `getAllTranscripts(limit?)` assembles root→leaf chains (non-sidechain roots) and decorates them with summaries/titles/snapshots.
- `getLastLog(sessionId)` selects the newest non-sidechain chain by `timestamp`.
- `flush()` blocks until tracked writes finish (`pendingWriteCount`/`trackWrite`).

## Queue & Snapshot Helpers
- `H0A(messages)` / `BZ9(messages, agentId?)` insert a chain (main vs. sidechain) and return the leaf UUID.
- `ORA(queueOp)` appends queue operations (`type: "queue-operation"`).
- `h21(messageId, snapshot, isSnapshotUpdate)` appends file-history snapshots.
- `Ax()` forces `sessionFile` to point at the current session path (used when priming logs).

## Cross-References
- Event logging and dedupe details: `JSONL_LOGGING.md`
- Tool outputs that generate log entries: `TOOL_EXECUTION_FLOW.md`
- Slug generation for plan files: `SLUG_GENERATION.md`

## Validated vs. Speculative
- **Validated**: Path derivation, sessionId creation/override, load/flush behavior, skip conditions, helper entrypoints above.
- **Speculative**: The long-term retention/cleanup policy hinted by `cleanupPeriodDays` is not enforced in the observed code path during this pass.
