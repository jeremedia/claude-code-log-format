# Claude Code Agent Log Format - Master Reference

**Spec Version**: 1.1
**Claude Code Version**: 2.0.49
**Format**: JSONL (newline-delimited JSON)
**Last Updated**: 2025-11-23

> 📋 **Document Scope**: This document describes the **log file format** as produced by Claude Code, not the behavior of any specific parser implementation. Fields documented here appear in the logs regardless of whether current parsers utilize them. Parser implementations may use a subset of available fields.

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Complete Field Inventory](#complete-field-inventory)
3. [Event Lifecycle](#event-lifecycle)
4. [Message and Content Types](#message-and-content-types)
5. [Duration Measurement Rules](#duration-measurement-rules)
6. [JSON Schema](#json-schema)
7. [Semantic Model](#semantic-model)
8. [Dashboard-Oriented Guide](#dashboard-oriented-guide)
9. [Fully Annotated Examples](#fully-annotated-examples)

---

## Executive Summary

Claude Code agent logs capture the complete conversation between the user and the AI assistant, including:
- User messages and assistant responses
- Tool invocations and their results
- Token usage and caching statistics
- Execution context (git branch, working directory, session metadata)

**Key Characteristics**:
- **Format**: JSONL (one JSON object per line)
- **Ordering**: Chronological by timestamp
- **Linking**: Events linked via `uuid` → `parentUuid` chain AND `message.id` for grouping
- **Types**: Seven top-level types (`assistant`, `user`, `file-history-snapshot`, `queue-operation`, `system`, `summary`, `turn_end`)
- **Content**: Five content types (`text`, `thinking`, `tool_use`, `tool_result`, `image`)

### Validation Status

**Sample Data**: 1,001 log files, ~236,000+ events, 14 diverse projects (Oct-Nov 2025)
- ✅ **Core schema**: Verified across 236K+ events from production use
- ✅ **Enum values**: Comprehensive coverage validated
- ✅ **Error cases**: 100+ failed tool executions documented with patterns
- ✅ **Tool coverage**: 24 tools documented (including ExitPlanMode)
- ✅ **Tool result structures**: Complete documentation for all non-MCP tools
- ✅ **Multi-tool patterns**: 99.97% single tool per entry (2 multi-tool cases in 236K events)
- ✅ **Content types**: 5 types including thinking (3,225 occurrences) and image (24)
- ✅ **Event types**: 7 types including file-history-snapshot (615) and system events (74)

**Production Readiness**: VALIDATED - Battle-tested against 236K+ events from real-world Claude Code usage across diverse workloads.

---

## Complete Field Inventory

### Top-Level Fields (All Messages)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `uuid` | string (UUID) | Yes | Unique identifier for this log entry (e.g., `ee82aa02-d77a-4ffc-a0ff-ecac689bf59a`) |
| `parentUuid` | string (UUID) \| null | Yes | UUID of the parent event (null for conversation start) |
| `type` | enum: `"assistant"` \| `"user"` \| `"file-history-snapshot"` \| `"queue-operation"` \| `"system"` \| `"summary"` \| `"turn_end"` | Yes | Event type |
| `timestamp` | string (ISO 8601) | Yes | UTC timestamp with millisecond precision (e.g., `"2025-11-23T04:53:42.362Z"`). **Note**: Not unique - multiple events may share the same millisecond timestamp. Use `uuid` for unique identification. |
| `agentId` | string | Yes | Short agent identifier (e.g., `"6e067db7"`) |
| `sessionId` | string (UUID) | Yes | Session identifier (shared across conversation) |
| `version` | string | Yes | Claude Code version (e.g., `"2.0.49"`) |
| `cwd` | string | Yes | Working directory path |
| `gitBranch` | string | Yes | Current git branch name |
| `isSidechain` | boolean | Yes | Whether this is a sidechain agent (subagent) |
| `userType` | string | Yes | Type of user interaction (only `"external"` observed in 13K events; other values may exist) |
| `message` | object | Conditional | Message payload (required for `assistant`/`user` types; see Message Structure) |
| `requestId` | string | Conditional | API request ID (only on assistant messages) |
| `toolUseResult` | object | Conditional | Tool execution result metadata (only on user messages with tool results) |

### Message Structure

All messages contain a `message` object with the following structure:

#### For Assistant Messages

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model` | string | Yes | Model identifier (e.g., `"claude-sonnet-4-5-20250929"`) |
| `id` | string (pattern: `^msg_[A-Za-z0-9]{24}$`) | Yes | Anthropic message ID, shared across related streaming events (e.g., `"msg_01DLR6cAneJvrPvkp7xyLYJ6"`) |
| `type` | literal: `"message"` | Yes | Always `"message"` for Anthropic API format |
| `role` | literal: `"assistant"` | Yes | Always `"assistant"` |
| `content` | array | Yes | Array of content blocks (see Content Types) |
| `stop_reason` | enum: `"tool_use"` \| `"end_turn"` \| `"stop_sequence"` \| null | Yes | Why the message stopped (observed values in 13K events; Anthropic API may support additional values) |
| `stop_sequence` | string \| null | Yes | Stop sequence used (typically null) |
| `usage` | object | Yes | Token usage statistics (see Usage Structure) |
| `context_management` | object | Optional | Context management info (e.g., `{"applied_edits": []}`) |

#### For User Messages

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `role` | literal: `"user"` | Yes | Always `"user"` |
| `content` | array | Yes | Array of content blocks (always tool results) |

### Content Types

Content blocks appear in the `message.content` array. There are five types:

#### 1. Text Content (`type: "text"`)

```json
{
  "type": "text",
  "text": "The actual message text..."
}
```

**Appears in**: Assistant messages
**Purpose**: Natural language responses from the assistant

#### 2. Tool Use Content (`type: "tool_use"`)

```json
{
  "type": "tool_use",
  "id": "toolu_01BKdVgszQBNUd9fukSjjEtB",
  "name": "Glob",
  "input": {
    "pattern": "**/*.svelte",
    "path": "/Volumes/jer4TBv3/agent-dash/frontend"
  }
}
```

**Appears in**: Assistant messages with `stop_reason: "tool_use"`
**Purpose**: Assistant requests to execute a tool

**Tool Inventory from Sample Data** (23 tools observed across 13,261 events):

| Tool | Count | Category | Purpose |
|------|-------|----------|---------|
| Edit | 993 | File Operations | Modify existing files |
| Bash | 799 | Shell | Execute shell commands |
| Read | 599 | File Operations | Read file contents |
| TodoWrite | 238 | Workflow | Task management |
| Grep | 229 | Search | Content search |
| BashOutput | 132 | Shell | Monitor background shells |
| Write | 83 | File Operations | Create/overwrite files |
| KillShell | 60 | Shell | Terminate background shells |
| Glob | 53 | Search | File pattern matching |
| Task | 51 | Workflow | Subagent dispatch |
| ExitPlanMode | 20 | Workflow | Exit planning mode |
| Skill | 15 | Workflow | Invoke skills |
| AskUserQuestion | 13 | Interaction | User prompts |
| WebFetch | 11 | Network | Fetch URL content |
| WebSearch | 5 | Network | Web search |
| SlashCommand | 1 | Workflow | Execute slash commands |
| **MCP Tools** (chrome-devtools integration) |
| navigate_page | 8 | Browser | Navigate to URL |
| list_pages | 6 | Browser | List open pages |
| take_snapshot | 3 | Browser | Capture DOM snapshot |
| take_screenshot | 3 | Browser | Capture screenshot |
| list_console_messages | 4 | Browser | Get console logs |
| new_page | 2 | Browser | Open new tab |
| list_network_requests | 2 | Browser | Network activity |
| get_network_request | 2 | Browser | Request details |

> **Note**: This inventory represents tools observed in validation sample. Additional tools may exist in Claude Code (new MCP servers, future tool additions, etc.). Parsers should handle unknown tool types gracefully rather than failing on unrecognized names.

**MCP Tools**: Use `mcp__servername__toolname` naming convention (e.g., `mcp__chrome-devtools__navigate_page`). Only chrome-devtools MCP server observed in sample data; other MCP servers may exist following the same pattern.

> 📋 **Parser Note**: Parser implementations may not have built-in taxonomy entries for MCP tools. Parsers should gracefully handle unknown tool types rather than failing.

#### 3. Tool Result Content (`type: "tool_result"`)

```json
{
  "type": "tool_result",
  "tool_use_id": "toolu_01BKdVgszQBNUd9fukSjjEtB",
  "content": "Result content as string..."
  // is_error field may appear on errors (not observed in sample)
}
```

**Appears in**: User messages (system response to tool invocation)
**Purpose**: Returns the result of a tool execution
**Linking**: `tool_use_id` matches the `id` from the corresponding `tool_use`

> ⚠️ **CORRECTED (13K validation)**: `is_error` field appears in tool results with three behaviors:
> - `is_error: true` → Tool execution failed (230 cases)
> - `is_error: false` → Explicit success (754 cases)
> - Field absent (not present in JSON) → Implicit success (10,947 cases)
> - `is_error: null` → Treat as implicit success (if observed)
>
> **Semantic Distinction**: Both explicit `false` and field absence/null indicate successful tool execution. The field is **optional** - parsers should treat both absent fields and explicit `null` values identically to `false`. Error content may be wrapped in `<tool_use_error>` tags or plain text (e.g., Bash exit codes).

> 📋 **Parser Note**: Basic parsers may track tool completion without checking `is_error`. For error-aware dashboards, check this field to distinguish successful vs failed tool executions.

#### 4. Thinking Content (`type: "thinking"`)

```json
{
  "type": "thinking",
  "thinking": "The user is making a very valid point about the multi-tool invocation pattern...",
  "signature": "EosOCkYICRgCKkCp..."
}
```

**Appears in**: Assistant messages (extended thinking mode)
**Purpose**: Contains Claude's internal reasoning process before generating a response
**Frequency**: 3,225 occurrences (nearly as common as tool_use!)
**Note**: Signature field provides verification of thinking authenticity

#### 5. Image Content (`type: "image"`)

```json
{
  "type": "image",
  "source": {
    "type": "base64",
    "media_type": "image/png",
    "data": "iVBORw0KGgoAAAANS..."
  }
}
```

**Appears in**: User messages (user-uploaded screenshots/images)
**Purpose**: Provides visual input to Claude
**Pattern**: Usually appears with text in multi-item content arrays: `[image, text]`
**Frequency**: 24 occurrences (22 in image+text pairs)

### Usage Structure

Token usage statistics appear in `message.usage` for assistant messages:

```json
{
  "input_tokens": 5,
  "cache_creation_input_tokens": 6738,
  "cache_read_input_tokens": 60996,
  "cache_creation": {
    "ephemeral_5m_input_tokens": 6738,
    "ephemeral_1h_input_tokens": 0
  },
  "output_tokens": 2753,
  "service_tier": "standard"
}
```

| Field | Description |
|-------|-------------|
| `input_tokens` | New input tokens (not from cache) |
| `cache_creation_input_tokens` | Tokens used to create cache entries |
| `cache_read_input_tokens` | Tokens read from cache |
| `output_tokens` | Tokens generated in response |
| `service_tier` | Service tier used (e.g., `"standard"`) |
| `cache_creation.ephemeral_5m_input_tokens` | Tokens cached for 5 minutes |
| `cache_creation.ephemeral_1h_input_tokens` | Tokens cached for 1 hour |

### Tool Use Result Structure

The `toolUseResult` field appears on user messages and varies by tool type:

#### Glob Tool Result

```json
{
  "filenames": ["/path/to/file1.svelte", "/path/to/file2.svelte"],
  "durationMs": 353,
  "numFiles": 2,
  "truncated": false
}
```

#### Grep Tool Result

```json
{
  "mode": "files_with_matches",
  "filenames": ["file1.svelte", "file2.ts"],
  "numFiles": 2
}
```

#### Read Tool Result

```json
{
  "type": "text",
  "file": {
    "filePath": "/path/to/file.svelte",
    "content": "File content...",
    "numLines": 285,
    "startLine": 1,
    "totalLines": 285
  }
}
```

#### Bash Tool Result

```json
{
  "stdout": "Command output...",
  "stderr": "",
  "interrupted": false,
  "isImage": false
}
```

> **Note**: Unlike Glob and WebFetch, Bash results do NOT include `durationMs`. Calculate execution duration from timestamp deltas.

#### WebFetch Tool Result

```json
{
  "durationMs": 1243
}
```

> **Duration Field Availability**: Only **2 tools** provide `durationMs` in `toolUseResult`: **Glob** (53 occurrences) and **WebFetch** (11 occurrences) - confirmed across 236K events. All other tools (Read, Grep, Edit, Write, Bash, etc.) do not include execution duration in their result metadata. To measure duration for these tools, calculate from timestamp deltas between tool invocation and result.

#### Edit Tool Result

**No `toolUseResult` fields** - Edit tool does not populate the `toolUseResult` object. All information appears in the `content` field of the tool_result.

**Content format** (success): Plain text with file snippet showing modified lines
**Content format** (error): XML-wrapped error message `<tool_use_error>...</tool_use_error>`
**Error rate**: 4.9% (48 failures in 993 uses)
**Common errors**: "File has not been read yet. Read it first before writing to it."

#### Write Tool Result

**No `toolUseResult` fields** - Write tool does not populate the `toolUseResult` object.

**Content format** (success): Confirmation message with file path and snippet
**Error rate**: 3.2% (3 failures in 83 uses)

#### TodoWrite Tool Result

**No `toolUseResult` fields** - TodoWrite tool does not populate the `toolUseResult` object.

**Content format** (success): "Todos have been modified successfully. Ensure that you continue to use the todo list..."
**Error rate**: 0.8% (2 failures in 238 uses)

#### Task Tool Result

**⚠️ UNIQUE BEHAVIOR**: Task tool is the ONLY tool that returns content as an **array** instead of a string:

```json
{
  "content": [
    {
      "type": "text",
      "text": "Subagent response..."
    }
  ]
}
```

All other tools return `content` as a plain string. This is critical for parser implementations.

**Error rate**: 10% (5 failures in 51 uses)
**Common errors**: Subagent failures, invalid parameters

#### AskUserQuestion Tool Result

**No `toolUseResult` fields**

**Content format** (success): Comma-separated answers: `"{'question1': 'answer1', 'question2': 'answer2'}"`
**Error rate**: 11.1% (1 failure in 13 uses)

#### WebSearch Tool Result

**No `toolUseResult` fields**

**Content format** (success): JSON string with search results including titles, links, snippets
**Error rate**: 0% (5 uses, no failures observed)

#### ExitPlanMode Tool Result

**No `toolUseResult` fields**

**Content format** (success): Confirmation of plan approval/rejection
**Error rate**: 20% (4 failures in 20 uses)

#### Skill Tool Result

**No `toolUseResult` fields**

**Content format** (success): Skill execution confirmation
**Error rate**: 0% (15 uses, no failures observed)

#### BashOutput Tool Result

**No `toolUseResult` fields**

**Content format**: XML-structured shell output with stdout/stderr sections
**Error rate**: 1.9% (2 failures in 132 uses)

#### SlashCommand Tool Result

**No `toolUseResult` fields**

**Insufficient data**: Only 1 use observed, no errors

#### KillShell Tool Result

**⚠️ HIGH ERROR RATE**: 86.2% (52 failures in 60 uses)

**Why high errors are expected**: KillShell attempts to terminate background shells. If a shell completes before the kill command executes (race condition), it returns an error. This is normal behavior, not a bug.

**Content format** (success): JSON string with shell termination details
**Content format** (error): `"No shell found with id: <shell_id>"`

> **Note**: Most tools do not populate `toolUseResult` with metadata. Tool execution details appear in the `content` field of tool_result messages. Only Glob and WebFetch provide structured metadata in `toolUseResult`.

---

## Event Lifecycle

### 1. Message Flow

Every interaction follows a predictable pattern:

```
Assistant Message (text/tool_use)
    ↓ (parentUuid link)
User Message (tool_result) [if tool was used]
    ↓
Assistant Message (text/tool_use/both)
    ↓
...
```

### 2. UUID Linking

Events are linked via `uuid` → `parentUuid`:

```
Event A (uuid: "aaa", parentUuid: null)        # Conversation start
    ↓
Event B (uuid: "bbb", parentUuid: "aaa")       # Response to A
    ↓
Event C (uuid: "ccc", parentUuid: "bbb")       # Response to B
```

**First Message**: Always has `parentUuid: null`
**Subsequent Messages**: Reference the previous event's `uuid`

### 3. Tool Invocation Lifecycle

Tool calls create a two-event sequence:

```
1. Assistant emits tool_use
   - type: "assistant"
   - content: [{type: "tool_use", id: "toolu_XXX", name: "Read", input: {...}}]
   - stop_reason: "tool_use"
   - uuid: "assistant-uuid"

2. User emits tool_result
   - type: "user"
   - content: [{type: "tool_result", tool_use_id: "toolu_XXX", content: "..."}]
   - toolUseResult: {...} (metadata)
   - parentUuid: "assistant-uuid"
```

**Linking**: `tool_result.tool_use_id` == `tool_use.id`

### 4. Message ID vs UUID: Critical Distinction

> ⚠️ **CRITICAL**: Two different identifiers serve different purposes

**`uuid`** (Top-level field):
- Unique per **log entry** (one per event)
- Changes with every event
- Used for `parentUuid` linking (chronological chain)

**`message.id`** (Inside message object):
- Shared across **related API call events**
- Same value for all log entries from one API request
- Groups related tool invocations together

**Example Pattern**:
```
Event 1: uuid=A1, message.id=msg_X, content=[text]
Event 2: uuid=A2, message.id=msg_X, content=[tool_use: Glob]
Event 3: uuid=A3, message.id=msg_X, content=[tool_use: Read]
Event 4: uuid=U1, parentUuid=A3, content=[tool_result: Read]
Event 5: uuid=U2, parentUuid=A2, content=[tool_result: Glob]
```

**Usage**:
- **Chronological ordering**: Use `uuid` → `parentUuid` chain
- **Grouping related tools**: Use `message.id` to find all events from same API request (field exists in logs but not required for basic parsing - stateful parsing also works)
- **Matching results**: Use `tool_use_id` to link specific tool calls to results

> 📋 **Parser Note**: Current parser implementations use stateful tracking via timestamps rather than `message.id` grouping. The field is available for advanced use cases like correlating streaming chunks.

### 5. Tool Result Ordering

> ⚠️ **WARNING**: Tool results may arrive **out-of-order**

**Observed Pattern** (sample size: 15 tool results):
- Tool invocation order: Glob → Read → Grep
- Tool result order: **May be reversed or scrambled**
- Results link via `parentUuid`, not invocation sequence

**Implication**: Cannot assume `parentUuid` order matches semantic dependencies

**Correct Matching**: Always use `tool_use_id` to link results to invocations, never rely on timestamp or position ordering.

### 6. Timestamp Sequencing

- Timestamps are monotonically increasing (chronological order)
- Each log entry represents a discrete moment in the conversation
- Time deltas between entries = response latency (for assistant) or tool execution time (for user)

### 7. Multi-Tool Invocation Streaming

> ⚠️ **CRITICAL**: This pattern differs from standard Anthropic API behavior

When Claude invokes multiple tools, Claude Code streams them as **sequential log entries**:

**Pattern Observed** (sample size: 34 events):
- Multiple tool calls create **multiple sequential assistant log entries**
- Each entry shares the same `message.id` but has unique `uuid`
- Each entry contains **exactly one tool_use block** in `content`
- Tool results arrive as separate user messages (may be out-of-order)

**Example**: 3 tools invoked in sequence
```
Assistant (uuid: A1, message.id: msg_X): [tool_use: Glob]
Assistant (uuid: A2, message.id: msg_X): [tool_use: Read]
Assistant (uuid: A3, message.id: msg_X): [tool_use: Grep]
User (uuid: U1, parentUuid: A3): [tool_result: Grep]
User (uuid: U2, parentUuid: A2): [tool_result: Read]
User (uuid: U3, parentUuid: A1): [tool_result: Glob]
```

**Grouping Strategy**:
- Use `message.id` to identify related tool calls from same API request
- Use `parentUuid` for chronological event ordering
- Use `tool_use_id` to match results to invocations

**Statistics from 236K events**:
- **99.97% of assistant log entries** with tool_use contain exactly 1 tool in `content` array
- **2 multi-tool cases** observed (0.03%) - both appeared as multiple tool_use objects in same content array
- **Multiple tools from one API request** typically create multiple sequential log entries with shared `message.id`
- **Message grouping distribution**:
  - 76 message IDs → 1 log entry (single tool)
  - 1,771 message IDs → 2 log entries (common)
  - 1,351 message IDs → 3 log entries
  - 96 message IDs → 4 log entries
  - 64 message IDs → 5-17 log entries (rare)

**Conclusion**: The "multiple tool_use blocks in one content array" pattern is **extremely rare** (0.03%) in Claude Code logs. In typical usage, Claude Code streams each tool as a separate log entry, unlike the standard Anthropic Messages API. Parsers should handle both patterns.

---

## Message and Content Types

### Type: `assistant`

**Trigger**: Claude generates a response
**Contains**: Natural language text and/or tool invocations

#### Variants:

**1. Text-only response** (`stop_reason: "end_turn"`)
```json
{
  "type": "assistant",
  "message": {
    "role": "assistant",
    "content": [{"type": "text", "text": "Here's my response..."}],
    "stop_reason": "end_turn"
  }
}
```

**2. Tool invocation** (`stop_reason: "tool_use"`)
```json
{
  "type": "assistant",
  "message": {
    "role": "assistant",
    "content": [
      {"type": "text", "text": "Let me check that file..."},
      {"type": "tool_use", "id": "toolu_XXX", "name": "Read", "input": {...}}
    ],
    "stop_reason": "tool_use"
  }
}
```

**3. Tool-only invocation** (`stop_reason: "tool_use"`)
```json
{
  "type": "assistant",
  "message": {
    "role": "assistant",
    "content": [
      {"type": "tool_use", "id": "toolu_XXX", "name": "Bash", "input": {...}}
    ],
    "stop_reason": "tool_use"
  }
}
```

### Type: `user`

**Trigger**: User input OR system returns tool execution results
**Contains**: Tool result blocks (most common), OR user-provided text/images

```json
{
  "type": "user",
  "message": {
    "role": "user",
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": "toolu_XXX",
        "content": "Result data...",
        "is_error": false
      }
    ]
  },
  "toolUseResult": {...}
}
```

**Special Fields**:
- `toolUseResult`: Rich metadata about the tool execution (varies by tool)
- `content[].is_error`: Indicates tool execution result (true=failure, false=success, absent=success)

---

## Additional Event Types

Beyond `assistant` and `user`, Claude Code logs contain five additional event types for tracking conversation state and metadata:

### Type: `file-history-snapshot`

**Frequency**: 615 occurrences
**Purpose**: Tracks file state changes during conversation

```json
{
  "type": "file-history-snapshot",
  "messageId": "msg_01ABC...",
  "snapshot": {
    "messageId": "msg_01ABC...",
    "trackedFileBackups": {},
    "timestamp": "2025-11-22T01:54:28.173Z"
  },
  "isSnapshotUpdate": false
}
```

### Type: `queue-operation`

**Frequency**: 83 occurrences
**Purpose**: Output buffering and streaming control

```json
{
  "type": "queue-operation",
  "operation": "enqueue",
  "timestamp": "2025-11-22T04:05:25.111Z",
  "content": "... [content being queued] ..."
}
```

### Type: `system`

**Frequency**: 74 occurrences
**Purpose**: System notifications and conversation management

```json
{
  "type": "system",
  "subtype": "compact_boundary",
  "content": "Conversation compacted",
  "isMeta": false,
  "level": "info",
  "compactMetadata": {
    "trigger": "auto",
    "preTokens": 156910
  }
}
```

**Subtypes observed**: `compact_boundary` (conversation compression)

### Type: `summary`

**Frequency**: 20 occurrences
**Purpose**: Conversation summaries for context management

```json
{
  "type": "summary",
  "summary": "Claude Code Integration: Custom Hooks for Deterministic Event Visibility",
  "leafUuid": "57d54247-2e2b-4658-beaf-4e8f704569a7"
}
```

### Type: `turn_end`

**Frequency**: 12 occurrences
**Purpose**: Turn completion markers (primarily for subagents)

```json
{
  "timestamp": "2025-11-23T19:58:07.000Z",
  "type": "turn_end",
  "agentId": "3fbc2c5c"
}
```

---

## Duration Measurement Rules

### Where Duration Data Exists

1. **Tool-Level Duration** (millisecond precision):
   - **Location**: `toolUseResult.durationMs` (only on some tools)
   - **Availability (validated across 13K events)**:
     - ✅ **Glob** (53 occurrences) - File pattern matching
     - ✅ **WebFetch** (11 occurrences) - URL content retrieval
     - ❌ **NOT available**: Bash, Read, Grep, Edit, Write, TodoWrite, and most other tools
   - **Precision**: Milliseconds
   - **Example**: `"durationMs": 353`

2. **Message-Level Duration** (DOES NOT EXIST):
   - Assistant messages do NOT have a `duration` field
   - Must be derived from timestamp deltas

### Calculating Response Latency

**For Assistant Messages** (no built-in duration):

```javascript
// Find assistant message and next event in chronological order
const assistantMsg = logEntries.find(e => e.uuid === targetUuid);
const assistantIdx = logEntries.indexOf(assistantMsg);
const nextMsg = logEntries[assistantIdx + 1];

if (nextMsg) {
  const latencyMs = new Date(nextMsg.timestamp) - new Date(assistantMsg.timestamp);
  // This includes: LLM inference time + tool execution time (if tools were called)
}
```

> 📋 **Note**: For multi-tool scenarios, you may need to sum durations across multiple events with the same `message.id` to get total API request latency.

**For Tool Execution** (when `durationMs` available):

```javascript
const userMsg = logEntries.find(e => e.type === 'user' && e.uuid === targetUuid);
if (userMsg.toolUseResult?.durationMs) {
  const toolDurationMs = userMsg.toolUseResult.durationMs;
  // Pure tool execution time (excludes LLM time)
}
```

**For Total Turn Time**:

```javascript
// From user's question to assistant's final response
const userQuestionIdx = logEntries.findIndex(e => e.type === 'user' && e.message.content.some(c => c.type === 'text'));
const userQuestion = logEntries[userQuestionIdx];

// Find next assistant message with end_turn (not tool_use)
const assistantResponse = logEntries.slice(userQuestionIdx + 1).find(e =>
  e.type === 'assistant' && e.message?.stop_reason === 'end_turn'
);

if (assistantResponse) {
  const turnTimeMs = new Date(assistantResponse.timestamp) - new Date(userQuestion.timestamp);
  // Total time from question to response (includes all tool calls)
}
```

### Why Duration is Derived, Not Stored

- **Assistant messages**: Represent *initiation* of generation, not completion
- **Duration calculation**: Requires comparing timestamps with next event
- **State transitions**: Events are discrete points in time, not spans
- **Dashboard implication**: Must compute durations from timestamp deltas

---

## JSON Schema

> ⚠️ **CRITICAL SCHEMA SCOPE LIMITATION**: This schema validates **ONLY** `assistant` and `user` event types. Running this schema against other event types (`file-history-snapshot`, `queue-operation`, `system`, `summary`, `turn_end`) will produce validation errors. These 5 event types have different required fields documented in "Additional Event Types" section. For complete validation, implement discriminated union by `type` field.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "ClaudeCodeLogEntry (Assistant/User Events Only)",
  "description": "⚠️ SCOPE: Validates assistant and user events. This schema will FAIL validation for file-history-snapshot, queue-operation, system, summary, and turn_end types. See prose documentation for those structures.",
  "type": "object",
  "required": [
    "uuid",
    "parentUuid",
    "type",
    "timestamp",
    "agentId",
    "sessionId",
    "version",
    "cwd",
    "gitBranch",
    "isSidechain",
    "userType"
  ],
  "comment": "Note: 'message' field required for assistant/user types but not for other event types. See Additional Event Types section for their specific required fields.",
  "properties": {
    "uuid": {
      "type": "string",
      "format": "uuid",
      "description": "Unique identifier for this log entry"
    },
    "parentUuid": {
      "oneOf": [
        {"type": "string", "format": "uuid"},
        {"type": "null"}
      ],
      "description": "UUID of parent event (null for conversation start)"
    },
    "type": {
      "type": "string",
      "enum": [
        "assistant",
        "user",
        "file-history-snapshot",
        "queue-operation",
        "system",
        "summary",
        "turn_end"
      ],
      "description": "Event type"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp"
    },
    "agentId": {
      "type": "string",
      "description": "Short agent identifier"
    },
    "sessionId": {
      "type": "string",
      "format": "uuid",
      "description": "Session identifier"
    },
    "version": {
      "type": "string",
      "description": "Claude Code version"
    },
    "cwd": {
      "type": "string",
      "description": "Working directory path"
    },
    "gitBranch": {
      "type": "string",
      "description": "Current git branch"
    },
    "isSidechain": {
      "type": "boolean",
      "description": "Whether this is a subagent"
    },
    "userType": {
      "type": "string",
      "description": "User interaction type (only 'external' observed in 13K events; other values may exist)"
    },
    "requestId": {
      "type": "string",
      "description": "API request ID (assistant messages only)"
    },
    "message": {
      "type": "object",
      "oneOf": [
        {"$ref": "#/definitions/AssistantMessage"},
        {"$ref": "#/definitions/UserMessage"}
      ]
    },
    "toolUseResult": {
      "type": "object",
      "description": "Tool execution metadata (user messages only). Structure varies by tool. Only 4 common patterns shown in schema; see Tool Use Result Structure section for complete inventory. Edit, Write, TodoWrite, WebFetch, MCP tools, etc. may have different structures.",
      "oneOf": [
        {"$ref": "#/definitions/GlobResult"},
        {"$ref": "#/definitions/GrepResult"},
        {"$ref": "#/definitions/ReadResult"},
        {"$ref": "#/definitions/BashResult"}
      ]
    }
  },
  "definitions": {
    "AssistantMessage": {
      "type": "object",
      "required": ["model", "id", "type", "role", "content", "stop_reason", "stop_sequence", "usage"],
      "properties": {
        "model": {"type": "string"},
        "id": {
          "type": "string",
          "pattern": "^msg_[A-Za-z0-9]{24}$",
          "description": "Anthropic message ID (shared across related streaming events)"
        },
        "type": {"const": "message"},
        "role": {"const": "assistant"},
        "content": {
          "type": "array",
          "items": {
            "oneOf": [
              {"$ref": "#/definitions/TextContent"},
              {"$ref": "#/definitions/ToolUseContent"},
              {"$ref": "#/definitions/ThinkingContent"},
              {"$ref": "#/definitions/ImageContent"}
            ]
          }
        },
        "stop_reason": {
          "oneOf": [
            {"type": "string", "enum": ["tool_use", "end_turn", "stop_sequence"]},
            {"type": "null"}
          ]
        },
        "stop_sequence": {"type": ["string", "null"]},
        "usage": {"$ref": "#/definitions/Usage"},
        "context_management": {
          "type": "object",
          "properties": {
            "applied_edits": {"type": "array"}
          }
        }
      }
    },
    "UserMessage": {
      "type": "object",
      "required": ["role", "content"],
      "properties": {
        "role": {"const": "user"},
        "content": {
          "type": "array",
          "items": {
            "oneOf": [
              {"$ref": "#/definitions/ToolResultContent"},
              {"$ref": "#/definitions/ImageContent"},
              {"$ref": "#/definitions/TextContent"}
            ]
          }
        }
      }
    },
    "TextContent": {
      "type": "object",
      "required": ["type", "text"],
      "properties": {
        "type": {"const": "text"},
        "text": {"type": "string"}
      }
    },
    "ToolUseContent": {
      "type": "object",
      "required": ["type", "id", "name", "input"],
      "properties": {
        "type": {"const": "tool_use"},
        "id": {"type": "string", "pattern": "^toolu_[A-Za-z0-9]{24}$"},
        "name": {"type": "string"},
        "input": {"type": "object"}
      }
    },
    "ToolResultContent": {
      "type": "object",
      "required": ["type", "tool_use_id", "content"],
      "properties": {
        "type": {"const": "tool_result"},
        "tool_use_id": {"type": "string", "pattern": "^toolu_[A-Za-z0-9]{24}$"},
        "content": {"type": "string"},
        "is_error": {
          "type": "boolean",
          "description": "Tool execution result. OBSERVED in 13K events: true (230 failures), false (754 successes), absent/null (10,947 events). When present: true=error, false=success. When absent: treat as success."
        }
      }
    },
    "ThinkingContent": {
      "type": "object",
      "required": ["type", "thinking"],
      "properties": {
        "type": {"const": "thinking"},
        "thinking": {"type": "string", "description": "Extended thinking content"},
        "signature": {"type": "string", "description": "Verification signature"}
      }
    },
    "ImageContent": {
      "type": "object",
      "required": ["type", "source"],
      "properties": {
        "type": {"const": "image"},
        "source": {
          "type": "object",
          "required": ["type", "media_type", "data"],
          "properties": {
            "type": {"const": "base64"},
            "media_type": {"type": "string", "description": "MIME type (e.g., image/png)"},
            "data": {"type": "string", "description": "Base64-encoded image data"}
          }
        }
      }
    },
    "Usage": {
      "type": "object",
      "required": ["input_tokens", "output_tokens"],
      "properties": {
        "input_tokens": {"type": "integer"},
        "cache_creation_input_tokens": {"type": "integer"},
        "cache_read_input_tokens": {"type": "integer"},
        "output_tokens": {"type": "integer"},
        "service_tier": {"type": "string"},
        "cache_creation": {
          "type": "object",
          "properties": {
            "ephemeral_5m_input_tokens": {"type": "integer"},
            "ephemeral_1h_input_tokens": {"type": "integer"}
          }
        }
      }
    },
    "GlobResult": {
      "type": "object",
      "required": ["filenames", "numFiles"],
      "properties": {
        "filenames": {"type": "array", "items": {"type": "string"}},
        "durationMs": {"type": "integer"},
        "numFiles": {"type": "integer"},
        "truncated": {"type": "boolean"}
      }
    },
    "GrepResult": {
      "type": "object",
      "required": ["mode", "filenames", "numFiles"],
      "properties": {
        "mode": {"type": "string"},
        "filenames": {"type": "array", "items": {"type": "string"}},
        "numFiles": {"type": "integer"}
      }
    },
    "ReadResult": {
      "type": "object",
      "required": ["type", "file"],
      "properties": {
        "type": {"const": "text"},
        "file": {
          "type": "object",
          "properties": {
            "filePath": {"type": "string"},
            "content": {"type": "string"},
            "numLines": {"type": "integer"},
            "startLine": {"type": "integer"},
            "totalLines": {"type": "integer"}
          }
        }
      }
    },
    "BashResult": {
      "type": "object",
      "required": ["stdout", "stderr", "interrupted", "isImage"],
      "properties": {
        "stdout": {"type": "string"},
        "stderr": {"type": "string"},
        "interrupted": {"type": "boolean"},
        "isImage": {"type": "boolean"}
      }
    }
  }
}
```

---

## Semantic Model

### Ontology

The log system models conversations as a **directed acyclic graph (DAG)** of events:

```
┌─────────────────┐
│ Log Entry       │
├─────────────────┤
│ • uuid          │ → Unique identity
│ • parentUuid    │ → Links to parent (DAG structure)
│ • timestamp     │ → Temporal ordering
│ • type          │ → Role in conversation
│ • message       │ → Actual content
└─────────────────┘
```

### Roles

**1. Assistant Messages** (`type: "assistant"`)
- **Ontological Role**: Claude's internal decision points
- **Contains**: Reasoning (text) and actions (tool_use)
- **Triggers**: User input or tool results
- **State**: Represents *initiation* of generation (not completion)

**2. User Messages** (`type: "user"`)
- **Ontological Role**: System feedback to Claude
- **Contains**: Tool execution results
- **Triggers**: Assistant tool invocations
- **State**: Represents *completion* of tool execution

### State Machine

```
┌──────────────────────────────────────────────────────┐
│                  Conversation Loop                   │
└──────────────────────────────────────────────────────┘

[START] → Assistant Message
              │
              ├─ stop_reason: "end_turn" → [WAIT FOR USER]
              │
              └─ stop_reason: "tool_use" → User Message (tool_result)
                                                  │
                                                  └─→ Assistant Message
                                                           │
                                                          ...
```

**States**:
1. **Waiting**: Assistant awaits user input
2. **Generating**: Assistant produces response (text + optional tool_use)
3. **Executing**: System runs tools (user message with tool_result)
4. **Looping**: Assistant continues with tool results as input

### Reconstruction Rules

To reconstruct a conversation from logs:

1. **Find root**: Entry with `parentUuid: null`
2. **Build chain**: Follow `uuid` → `parentUuid` links
3. **Group turns**: Assistant message + any tool results = one "turn"
4. **Order by**: `timestamp` (chronological)
5. **Display**:
   - Assistant text → visible to user
   - Tool invocations → show as "actions taken"
   - Tool results → show as "outcomes"

### Relationships

```
Assistant Message ──(invokes)──> Tool Use
                                     │
                                     │ (executes)
                                     ↓
                                Tool Result ──(provides)──> User Message
                                                                  │
                                                                  │ (feeds into)
                                                                  ↓
                                                            Next Assistant Message
```

---

## Dashboard-Oriented Guide

### Fields for Visualization

#### Timeline View

| Field | Purpose |
|-------|---------|
| `timestamp` | X-axis positioning |
| `type` | Event type (assistant vs user/tool) |
| `message.content[].type` | Event category (text, tool_use, tool_result) |
| `message.content[].name` | Tool name (for glyphs/colors) |
| `uuid` / `parentUuid` | Event linking for dependency visualization |

#### Latency Tracking

| Metric | Calculation |
|--------|-------------|
| **Assistant Response Time** | `nextEvent.timestamp - currentEvent.timestamp` |
| **Tool Execution Time** | `toolUseResult.durationMs` (when available) |
| **Turn Time** | User question timestamp → final assistant response timestamp |

#### Token Usage Metrics

| Field | Visualization |
|-------|---------------|
| `message.usage.input_tokens` | Fresh input cost |
| `message.usage.cache_read_input_tokens` | Cached input savings |
| `message.usage.output_tokens` | Generation cost |
| `message.usage.cache_creation_input_tokens` | Cache building cost |

#### Event Segmentation

```javascript
// Segment assistant messages
const textBlocks = message.content.filter(c => c.type === 'text');
const toolCalls = message.content.filter(c => c.type === 'tool_use');

// Count tool invocations per turn
const toolsPerTurn = toolCalls.length;

// Identify thinking vs action
const hasThinking = textBlocks.length > 0;
const hasAction = toolCalls.length > 0;

// Classify turn type
if (hasThinking && hasAction) {
  turnType = 'reasoning-with-action';
} else if (hasThinking) {
  turnType = 'pure-reasoning';
} else if (hasAction) {
  turnType = 'pure-action';
}
```

#### Phase Duration Breakdown

For a complete assistant turn with tool usage:

```javascript
// Phase 1: Reasoning (assistant message creation)
const reasoningStart = assistantMsg.timestamp;
const reasoningEnd = firstToolResult.timestamp; // First user message
const reasoningDuration = reasoningEnd - reasoningStart;

// Phase 2: Tool Execution (all tool results)
const toolResults = userMessages.filter(m =>
  m.parentUuid === assistantMsg.uuid
);
const toolDuration = toolResults.reduce((sum, tr) =>
  sum + (tr.toolUseResult?.durationMs || 0), 0
);

// Phase 3: Next Response (if assistant continues)
const nextAssistant = log.find(e => e.parentUuid === lastToolResult.uuid);
const nextResponseStart = lastToolResult.timestamp;
const nextResponseEnd = nextAssistant?.timestamp;
const nextResponseDuration = nextResponseEnd - nextResponseStart;
```

### Ordering Events

**Primary Sort**: `timestamp` (chronological)
**Secondary Sort**: `uuid` lexicographic (for events at same millisecond)

```javascript
logEntries.sort((a, b) => {
  const timeDiff = new Date(a.timestamp) - new Date(b.timestamp);
  return timeDiff !== 0 ? timeDiff : a.uuid.localeCompare(b.uuid);
});
```

### Constructing Event Trees

```javascript
// Build parent → children map
const childrenMap = new Map();
logEntries.forEach(entry => {
  const parent = entry.parentUuid || 'root';
  if (!childrenMap.has(parent)) {
    childrenMap.set(parent, []);
  }
  childrenMap.get(parent).push(entry);
});

// Traverse tree
function buildTree(uuid = null) {
  const children = childrenMap.get(uuid) || [];
  return children.map(child => ({
    ...child,
    children: buildTree(child.uuid)
  }));
}

const tree = buildTree(null);
```

### Activity Heatmap Data

```javascript
// Events per minute
const eventsPerMinute = logEntries.reduce((acc, entry) => {
  const minute = Math.floor(new Date(entry.timestamp) / 60000) * 60000;
  acc[minute] = (acc[minute] || 0) + 1;
  return acc;
}, {});

// Tool usage frequency
const toolFrequency = logEntries
  .flatMap(e => e.message.content || [])
  .filter(c => c.type === 'tool_use')
  .reduce((acc, tool) => {
    acc[tool.name] = (acc[tool.name] || 0) + 1;
    return acc;
  }, {});
```

### Performance Metrics

```javascript
// Average response latency
const assistantMessages = logEntries.filter(e => e.type === 'assistant');
const latencies = assistantMessages.map((msg, i) => {
  const next = logEntries.find(e => e.parentUuid === msg.uuid);
  return next ? new Date(next.timestamp) - new Date(msg.timestamp) : null;
}).filter(l => l !== null);

const avgLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length;

// Token efficiency (cache hit rate)
const totalInput = assistantMessages.reduce((sum, msg) =>
  sum + (msg.message.usage?.input_tokens || 0), 0
);
const cachedInput = assistantMessages.reduce((sum, msg) =>
  sum + (msg.message.usage?.cache_read_input_tokens || 0), 0
);
const cacheHitRate = cachedInput / (totalInput + cachedInput);
```

---

## Fully Annotated Examples

### Example 1: Assistant Message with Tool Invocation

```json
{
  // ──────────────────────────────────────────────────────────
  // ENVELOPE: Metadata about this log entry
  // ──────────────────────────────────────────────────────────
  "parentUuid": "b5991f3b-30c2-4922-b304-53fcd26f029e",  // Links to previous message
  "uuid": "ee82aa02-d77a-4ffc-a0ff-ecac689bf59a",        // This event's unique ID
  "timestamp": "2025-11-23T04:53:43.058Z",              // When this occurred

  // ──────────────────────────────────────────────────────────
  // CONTEXT: Execution environment
  // ──────────────────────────────────────────────────────────
  "agentId": "6e067db7",                                // Short agent identifier
  "sessionId": "19f5b1dc-60b2-4190-9484-0327449d379d",  // Session ID (shared across conversation)
  "version": "2.0.49",                                  // Claude Code version
  "cwd": "/Volumes/jer4TBv3/agent-dash",                // Working directory
  "gitBranch": "001-timeline-monitor",                  // Current git branch
  "isSidechain": true,                                  // This is a subagent
  "userType": "external",                               // User interaction type

  // ──────────────────────────────────────────────────────────
  // API METADATA: Request tracking
  // ──────────────────────────────────────────────────────────
  "requestId": "req_011CVQDuEUy86c4t9S1dcwJi",          // Anthropic API request ID
  "type": "assistant",                                  // This is an assistant message

  // ──────────────────────────────────────────────────────────
  // MESSAGE: The actual conversation content
  // ──────────────────────────────────────────────────────────
  "message": {
    "model": "claude-sonnet-4-5-20250929",             // Model used
    "id": "msg_01DLR6cAneJvrPvkp7xyLYJ6",              // API message ID (same across related events)
    "type": "message",                                 // Anthropic message format
    "role": "assistant",                               // Speaker role

    // ──────────────────────────────────────────────────────────
    // CONTENT: What the assistant said/did
    // ──────────────────────────────────────────────────────────
    "content": [
      {
        "type": "tool_use",                            // This is a tool invocation
        "id": "toolu_01BKdVgszQBNUd9fukSjjEtB",       // Unique tool call ID
        "name": "Glob",                                // Tool name
        "input": {                                     // Tool parameters
          "pattern": "**/*.svelte",
          "path": "/Volumes/jer4TBv3/agent-dash/frontend"
        }
      }
    ],

    // ──────────────────────────────────────────────────────────
    // TERMINATION: Why generation stopped
    // ──────────────────────────────────────────────────────────
    "stop_reason": "tool_use",                         // Stopped to invoke a tool
    "stop_sequence": null,                             // No stop sequence triggered

    // ──────────────────────────────────────────────────────────
    // USAGE: Token consumption for this generation
    // ──────────────────────────────────────────────────────────
    "usage": {
      "input_tokens": 3,                               // New input tokens (not cached)
      "cache_creation_input_tokens": 21896,            // Tokens used to build cache
      "cache_read_input_tokens": 0,                    // Tokens read from cache
      "output_tokens": 271,                            // Tokens generated
      "cache_creation": {
        "ephemeral_5m_input_tokens": 21896,            // 5-minute cache tokens
        "ephemeral_1h_input_tokens": 0                 // 1-hour cache tokens
      },
      "service_tier": "standard"                       // Service tier
    }
  }
}
```

**Interpretation**:
- **Event Type**: Assistant invokes Glob tool
- **Parent Link**: This follows message `b5991f3b...`
- **Duration**: NOT PRESENT (must compute from next event's timestamp)
- **Next Event**: Will be a user message with `tool_result` for `toolu_01BKdVgszQBNUd9fukSjjEtB`

### Example 2: User Message with Tool Result

```json
{
  // ──────────────────────────────────────────────────────────
  // ENVELOPE: Links to the tool invocation
  // ──────────────────────────────────────────────────────────
  "parentUuid": "8d52f3cb-ba62-4f26-8f52-c11df4fcc85b",  // The assistant message that invoked this tool
  "uuid": "0896b404-b265-4a7e-bc8c-c7e20a0adf35",        // This result's unique ID
  "timestamp": "2025-11-23T04:53:45.482Z",              // When the result was received

  // ──────────────────────────────────────────────────────────
  // CONTEXT: Same as assistant message
  // ──────────────────────────────────────────────────────────
  "agentId": "6e067db7",
  "sessionId": "19f5b1dc-60b2-4190-9484-0327449d379d",
  "version": "2.0.49",
  "cwd": "/Volumes/jer4TBv3/agent-dash",
  "gitBranch": "001-timeline-monitor",
  "isSidechain": true,
  "userType": "external",
  "type": "user",                                       // This is a user message (system response)

  // ──────────────────────────────────────────────────────────
  // MESSAGE: Tool result content
  // ──────────────────────────────────────────────────────────
  "message": {
    "role": "user",                                    // Role is "user" (system)
    "content": [
      {
        "tool_use_id": "toolu_018MS6iynS2ga6zCxj7yvzX6",  // Links to tool_use.id
        "type": "tool_result",                         // This is a tool result
        "content": "/Volumes/jer4TBv3/agent-dash/frontend/src/lib/components/AgentRow.svelte",
        "is_error": false                              // Tool succeeded (not an error)
      }
    ]
  },

  // ──────────────────────────────────────────────────────────
  // TOOL USE RESULT: Rich metadata about the execution
  // ──────────────────────────────────────────────────────────
  "toolUseResult": {
    "filenames": [                                     // Files found (Glob-specific)
      "/Volumes/jer4TBv3/agent-dash/frontend/src/lib/components/AgentRow.svelte"
    ],
    "durationMs": 353,                                 // Tool execution time (milliseconds)
    "numFiles": 1,                                     // Number of matches
    "truncated": false                                 // Results not truncated
  }
}
```

**Interpretation**:
- **Event Type**: System returns Glob tool result
- **Parent Link**: Responds to assistant message `8d52f3cb...`
- **Duration**: Tool took 353ms to execute (from `toolUseResult.durationMs`)
- **Next Event**: Assistant will process this result and continue

### Example 3: Assistant Message with Text Response

```json
{
  "parentUuid": "1be97948-306f-42ac-ba3b-a6e67a675a90",
  "uuid": "412b6fd1-2dd2-4edd-8015-9173a9e2e5dc",
  "timestamp": "2025-11-23T04:55:16.213Z",
  "agentId": "6e067db7",
  "sessionId": "19f5b1dc-60b2-4190-9484-0327449d379d",
  "version": "2.0.49",
  "cwd": "/Volumes/jer4TBv3/agent-dash",
  "gitBranch": "001-timeline-monitor",
  "isSidechain": true,
  "userType": "external",
  "requestId": "req_011CVQDxBavL5Rtn8nq2e2fH",
  "type": "assistant",

  "message": {
    "model": "claude-sonnet-4-5-20250929",
    "id": "msg_01THMooD6dbed9HQg5ym62PE",
    "type": "message",
    "role": "assistant",

    // ──────────────────────────────────────────────────────────
    // CONTENT: Pure text response (no tools)
    // ──────────────────────────────────────────────────────────
    "content": [
      {
        "type": "text",                                // Natural language response
        "text": "Perfect! Now I have a complete understanding of the codebase. Let me create a comprehensive plan for implementing expanding event bars.\n\n# DETAILED IMPLEMENTATION PLAN: Expanding Event Bars\n\n..."
      }
    ],

    // ──────────────────────────────────────────────────────────
    // TERMINATION: End of turn (no more tools to invoke)
    // ──────────────────────────────────────────────────────────
    "stop_reason": "end_turn",                         // Turn is complete
    "stop_sequence": null,

    // ──────────────────────────────────────────────────────────
    // USAGE: Heavy token usage for long response
    // ──────────────────────────────────────────────────────────
    "usage": {
      "input_tokens": 5,                               // Minimal new input
      "cache_creation_input_tokens": 6738,             // Building cache
      "cache_read_input_tokens": 60996,                // Reading from cache (huge savings!)
      "output_tokens": 2753,                           // Long response
      "cache_creation": {
        "ephemeral_5m_input_tokens": 6738,
        "ephemeral_1h_input_tokens": 0
      },
      "service_tier": "standard"
    }
  }
}
```

**Interpretation**:
- **Event Type**: Assistant provides final text response
- **Parent Link**: Responds to previous event `1be97948...`
- **Duration**: NOT PRESENT (calculate from next event, or this is final turn)
- **Cache Efficiency**: 60996 cached tokens vs 5 new tokens = 99.99% cache hit rate!
- **Stop Reason**: `end_turn` means conversation is waiting for user input

---

## Appendix: Common Patterns

### Pattern 1: Multiple Tool Invocations (STREAMING)

> ⚠️ **WARNING**: Pattern NOT observed in 34-event sample

**Theoretical pattern** (standard Anthropic API):
Multiple tools in single `content` array - **NOT SEEN** in Claude Code logs

**Observed pattern** (Claude Code streaming):
Multiple tools as **sequential log entries** with shared `message.id`

```
Log Entry 1: {uuid: A1, message.id: msg_X, content: [{tool_use: Glob}]}
Log Entry 2: {uuid: A2, message.id: msg_X, content: [{tool_use: Read}]}
Log Entry 3: {uuid: A3, message.id: msg_X, content: [{tool_use: Grep}]}
```

Result messages:
```
Log Entry 4: {uuid: U1, parentUuid: A3, content: [{tool_result for Grep}]}
Log Entry 5: {uuid: U2, parentUuid: A2, content: [{tool_result for Read}]}
Log Entry 6: {uuid: U3, parentUuid: A1, content: [{tool_result for Glob}]}
```

**Grouping**: Use `message.id` to identify related tools from same API request.

### Pattern 2: Conversation Start

```json
{
  "uuid": "first-message-uuid",
  "parentUuid": null,  // ← NULL indicates conversation start
  "type": "assistant",
  "timestamp": "2025-11-23T04:53:42.362Z",
  "message": {
    "content": [
      {"type": "text", "text": "I'll analyze the AgentDash timeline..."}
    ],
    "stop_reason": "tool_use"
  }
}
```

The first message always has `parentUuid: null`.

---

## Summary

This document provides a **validated reference** for the Claude Code agent log format based on analysis of 13,261 events from 7 diverse conversations:

✅ **Complete field inventory** - Every field documented and validated
✅ **Event lifecycle** - Streaming patterns confirmed across 3,365 message groups
✅ **Event types** - 7 types documented (assistant, user, file-history-snapshot, queue-operation, system, summary, turn_end)
✅ **Content types** - 5 types including thinking (3,225 occurrences) and image (24)
✅ **Tool inventory** - 23 tools documented with usage counts
✅ **Error cases** - 230 failures analyzed with diverse error patterns
✅ **Duration rules** - How to measure time (derived from timestamps and `toolUseResult.durationMs`)
✅ **JSON Schema** - Canonical schema definition (battle-tested)
✅ **Semantic model** - Streaming behavior and message grouping via `message.id`
✅ **Dashboard guide** - Practical visualization patterns
✅ **Annotated examples** - Real-world samples with explanations

### Production Readiness: VALIDATED ✅

**Validation completed:**
1. ✅ Critical errors corrected (multi-tool pattern, is_error field, service_tier location)
2. ✅ Validated against 7 diverse log files (88M to 280K)
3. ✅ Collected 230 error case samples (failed tools)
4. ✅ Tested with 23 different tool types
5. ✅ Verified enum completeness (stop_reason, userType, service_tier, content types)
6. ✅ Discovered 5 additional event types beyond assistant/user
7. ✅ Documented thinking content type (3,225 occurrences)

**Current Status**: VALIDATED - Battle-tested against 13K+ events with comprehensive coverage of success/error cases, diverse tools, and all event types.

This document is **production-ready** for building parsers, dashboards, analytics, and monitoring tools for Claude Code agent conversations.
