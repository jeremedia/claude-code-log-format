# Claude Code Log Format Version Drift Analysis

**Analysis Date**: 2025-12-12
**Spec Version**: 1.2 (updated for Claude Code v2.0.65)
**Current Version**: 2.0.65
**Version Gap**: 16 minor versions

## Summary

Significant format changes detected between v2.0.49 and v2.0.65. The spec remains mostly accurate for core event types but several new fields and subtypes have been added.

---

## File Naming Change

**Documented**: `agent-SESSION_ID.jsonl` (e.g., `agent-ace1187.jsonl`)
**Current**: Both old format AND new UUID format (e.g., `17f72126-4f27-44ad-86d7-861ce35265c0.jsonl`)

The session ID now appears to be a full UUID rather than a short hash, and file naming follows the UUID pattern.

---

## New Top-Level Fields

### Added to All/Most Events

| Field | Type | Description |
|-------|------|-------------|
| `slug` | string | Plan slug identifier (e.g., `"parsed-brewing-stearns"`) - was documented in source-docs but NOT in main spec |

### Added to `user` Events

| Field | Type | Description |
|-------|------|-------------|
| `isMeta` | boolean | Indicates meta-messages (system injected, not human typed) |

### Added to `assistant` Events (conditional)

| Field | Type | Description |
|-------|------|-------------|
| `thinkingMetadata` | object | Metadata about thinking blocks (when present) |
| `agentId` | string | Agent identifier (e.g., `"6e067db7"`) |

### Added to `summary` Events

| Field | Type | Description |
|-------|------|-------------|
| `leafUuid` | string (UUID) | UUID of the leaf event being summarized |
| `summary` | string | The actual summary content |
| `isCompactSummary` | boolean | Whether this is a compaction summary |

### Other New Fields (Various Events)

| Field | Type | Found On | Description |
|-------|------|----------|-------------|
| `isVisibleInTranscriptOnly` | boolean | Various | Visibility control |
| `todos` | array | Various | Todo state tracking |

---

## `system` Event Type Changes

The `system` event type has been significantly expanded with a subtype system:

### New Subtypes

| Subtype | Description |
|---------|-------------|
| `stop_hook_summary` | Summary of hooks executed at stop |
| `compact_boundary` | Context compaction marker |

### New Fields for `system` Events

| Field | Type | Description |
|-------|------|-------------|
| `subtype` | string | Event subtype discriminator |
| `level` | string | Severity level (e.g., `"info"`, `"suggestion"`) |
| `content` | string | Human-readable message |
| `hookCount` | number | Number of hooks executed |
| `hookInfos` | array | Hook execution details |
| `hookErrors` | array | Hook errors if any |
| `hasOutput` | boolean | Whether hooks produced output |
| `preventedContinuation` | boolean | Whether hooks prevented continuation |
| `stopReason` | string | Reason for stop |
| `toolUseID` | string (UUID) | Related tool use identifier |
| `logicalParentUuid` | string (UUID) | Logical parent (for compaction) |
| `compactMetadata` | object | Compaction metadata |

### `compactMetadata` Structure

```json
{
  "trigger": "auto",
  "preTokens": 155917
}
```

---

## `file-history-snapshot` Changes

**Documented structure** (v2.0.49): Had `uuid`, `parentUuid`, `sessionId`, etc.

**Current structure** (v2.0.65): Simplified

```json
{
  "type": "file-history-snapshot",
  "messageId": "aeca23ca-200a-4b5f-8729-53818f8b1e4c",
  "snapshot": {
    "messageId": "aeca23ca-200a-4b5f-8729-53818f8b1e4c",
    "trackedFileBackups": {},
    "timestamp": "2025-12-13T03:18:45.214Z"
  },
  "isSnapshotUpdate": false
}
```

**Missing from current**: `uuid`, `parentUuid`, `sessionId`, `version`, `cwd`, `gitBranch`, etc.
**Added**: `messageId`, `isSnapshotUpdate`, simplified `snapshot` object

---

## `toolUseResult` Structure Variations

The spec documented `toolUseResult` but these structures appear to have evolved:

### Bash Tool Result
```json
{
  "stdout": "",
  "stderr": "",
  "interrupted": false,
  "isImage": false
}
```

### Read Tool Result
```json
{
  "type": "text",
  "file": {
    "filePath": "/path/to/file.ts",
    "content": "...",
    "numLines": 69,
    "startLine": 1,
    "totalLines": 69
  }
}
```

---

## Fields Confirmed Unchanged

- `uuid`, `parentUuid`, `timestamp`, `sessionId`, `version`
- `type` (core values: `assistant`, `user`, `system`, `turn_end`, `file-history-snapshot`)
- `message` structure for assistant/user events
- `message.content` array with `text`, `thinking`, `tool_use`, `tool_result` types
- `thinking` content with `signature` field
- `cwd`, `gitBranch`, `isSidechain`, `userType`

---

## Recommendations

1. **Update main spec** to include `slug` field in field inventory
2. **Document `system` subtypes** as discriminated union
3. **Update `file-history-snapshot`** documentation to reflect simplified structure
4. **Add `isMeta` field** to user events documentation
5. **Document `compactMetadata`** for context compaction events
6. **Review `toolUseResult`** structures for all tools - may have evolved

---

## Validation Sample

Analyzed 5 log files (5.7MB total):

| Event Type | Count |
|------------|-------|
| assistant | 814 |
| user | 403 |
| file-history-snapshot | 59 |
| system | 34 |
| turn_end | 30 |
| summary | 25 |

### Complete New Field List (from automated scan)

```
compactMetadata, content, hasOutput, hookCount, hookErrors, hookInfos,
isCompactSummary, isMeta, isSnapshotUpdate, isVisibleInTranscriptOnly,
leafUuid, level, logicalParentUuid, messageId, preventedContinuation,
slug, snapshot, stopReason, subtype, summary, thinkingMetadata, todos, toolUseID
```

Total: **23 new fields** not documented in spec v1.1

---

## Next Steps

1. Run `./scripts/validate-format.sh` after each Claude Code update
2. Update main spec when drift exceeds threshold
3. Consider automating with GitHub Actions for upstream contributions
