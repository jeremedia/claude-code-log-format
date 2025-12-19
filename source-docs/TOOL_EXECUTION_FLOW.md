# Claude Code Tool Execution Flow

**Status**: Validated against Claude Code v2.0.65 (Bun-compiled binary) with noted speculative points  
**Last Updated**: 2025-12-12

> How tool calls are queued, validated, executed, and surfaced back to Claude Code.

## Source Pointers
- Orchestrator `class H50`
- Dispatcher `k61` (core generator)
- Post-hook/Pre-hook runners `Cm5` / `Em5`
- Hook-system message factories (`iF`, `y9_`, `K_R`)

## Core Orchestrator
- Class `H50`:
  - Holds `toolDefinitions` (each exposes `name`, `inputSchema`, `isConcurrencySafe`, optional `validateInput`, `call`, optional `contextModifier`).
  - Accepts a `canUseTool` permission function and a `toolUseContext` object (holds abort controller, query tracking, `setInProgressToolUseIDs`, tool decisions, etc.).
  - Maintains an internal queue of `{id, block, assistantMessage, status, isConcurrencySafe, results?, contextModifiers?}`.

### Queueing & Concurrency
- `addTool(toolBlock, assistantMessage)`:
  - Looks up the tool definition by `name`.
  - Parses the block input via `inputSchema.safeParse` to mark `isConcurrencySafe`.
  - Pushes into the queue and calls `processQueue()`.
- `canExecuteTool(isConcurrencySafe)`:
  - Allows multiple concurrent executions **only** if all running tools are marked concurrency-safe.
- `processQueue()`:
  - Iterates queued items; starts execution when safe; non-concurrency-safe items block behind any in-flight work.

### Execution Pipeline (`executeTool`)
- Marks status `executing`, adds `id` to `in-progress` set (`toolUseContext.setInProgressToolUseIDs`).
- Spawns an async task that:
  - Runs generator `k61(toolBlock, assistantMessage, canUseTool, toolUseContext)`.
  - Collects yielded `message` objects (tool_result/tool_output/etc.) and `contextModifier` functions.
  - On completion: status -> `completed`, stores results + modifiers; applies modifiers if non-concurrency-safe.
- Completion yields back through `getCompletedResults()`; also removes `id` from the in-progress set (`Qm5`).
- `getRemainingResults()` drains the queue, waiting on any executing tools (race over per-tool promises).

## Tool Dispatch (`k61`)
- Validates presence of the tool definition; if missing, emits telemetry (`tengu_tool_use_error`) and yields a `tool_result` with `<tool_use_error>No such tool available</tool_use_error>`.
- Rejects early if the request has been aborted (`abortController.signal.aborted`) with a canned cancellation tool_result.
- Input handling:
  - Zod `inputSchema.safeParse` ⇒ on failure, emits `InputValidationError` tool_result + telemetry.
  - Optional `validateInput` hook may veto with a message/errorCode.
- Pre-tool hooks: `Em5` iterates `PreToolUse:<toolName>` hooks; can:
  - Return `hookPermissionResult` (allow/deny/ask), `preventContinuation`, or `stopReason`.
  - Inject `updatedInput` used for the final call.
- Permission gating:
  - Calls `canUseTool` (provided by host) unless a hook already decided.
  - Denials yield error `tool_result` and emit `tengu_tool_use_can_use_tool_rejected`.
- Execution:
  - Records start time; invokes `tool.call(validatedInput, context, canUseTool, assistantMessage, progressCb)`.
  - Progress events feed `Dm5/Hm5` which enqueue streaming updates via `ry2`.
  - On success:
    - Emits telemetry (`tengu_tool_use_success`, `tool_result` metric payload via `IO`), duration, decision source, parameter snapshot for certain tools (bash/file ops).
    - Emits structured outputs as `structured_output` messages when provided.
    - Wraps raw/updated outputs via `ky2` into `tool_result` messages; captures optional `contextModifier` returned by the tool for later application.
  - On failure:
    - Catches domain errors (`HX`, `rj`) and generic errors; emits `tengu_tool_use_error`, `tool_result` with `<tool_use_error>...</tool_use_error>`, and metrics (`tool_result` success=false).

## Hooks & Post-Processing
- **PreToolUse hooks** (`j50` via `Em5`):
  - Can cancel, deny, or mutate inputs; can stop continuation entirely.
  - Emit `hook_cancelled`, `hook_error_during_execution`, or `hook_stopped_continuation` messages.
- **PostToolUse hooks** (`S50` via `Cm5`):
  - Run after the call; can emit additional messages, additional context, updated MCP outputs, or stop continuation.
  - Summaries of stop hooks surface as `system` messages with subtype `stop_hook_summary` (`y9_`), carrying `hookCount`, `hookInfos`, `hookErrors`, `preventedContinuation`, and `stopReason`.
  - Cancellation/errors are surfaced as hook_* messages and telemetry (`tengu_post_tool_hook_error`).
- **Progress streaming**: `Dm5/Hm5` add streaming progress (progress messages) while executing.

## Surfaces & Message Types
- Tool outputs surface as message payloads:
  - `tool_result` (standard)
  - `structured_output` (if tool returns `structured_output`)
  - Hook-related system messages (`hook_permission_decision`, `hook_cancelled`, `hook_stopped_continuation`, `hook_error_during_execution`, `hook_additional_context`, `stop_hook_summary`).
- Context modifiers returned alongside results can mutate the conversation context/state (e.g., add MCP tool output); applied after non-concurrency-safe runs, or individually when yielded.

## Error Paths (Observed)
- Missing tool definition.
- Aborted run (abortController).
- Schema validation failures.
- Pre-hook denial/stop.
- Permission denial from `canUseTool`.
- Tool thrown errors (domain vs. unknown).
- Post-hook cancellation/stop.

## Cross-References
- JSONL event logging (where tool results land): `JSONL_LOGGING.md`
- Session/layout details for tool logs: `SESSION_MANAGEMENT.md`
- Context budget heuristics related to tool outputs: `CONTEXT_MANAGEMENT.md`

## Validated vs. Speculative
- **Validated**: Queue/concurrency rules in `H50`, dispatch flow in `k61`/`Dm5`/`Hm5`/`Cm5`/`Em5`, telemetry + message construction for success/error/progress.
- **Speculative**: Exact shapes of `toolUseContext` and telemetry consumers (`IA`, `IO`, `kM2`, etc.) are inferred from call sites; upstream creation of `toolDefinitions` not traced in this pass.
