# Claude Code Context Management (Partial)

**Status**: Partially validated; key mechanics still to be traced (Claude Code v2.0.65)  
**Last Updated**: 2025-12-12

> Early notes on token budgeting, summarization, and context windows. More reverse-engineering needed.

## Source Pointers
- Context window heuristic `Su` (model window sizing)
- Pricing/guard `hE6` + token sum helper `fE6`
- Bash output summarization prompt and handler
- Compaction helpers: `K_R` (compact boundary system message), `Vj`/`Q_1`/`mF` (find/slice at last compact boundary), `HaB` (visibility filter), `h_1` (trim trailing thinking blocks)

## Known Constants
- `Su(modelName)` reports the assumed context window:
  - `1_000_000` tokens when the model string contains `"[1m]"`.
  - Otherwise `200_000` tokens.
- `hE6(model, usage)` enforces a pricing tier; when the “bt” pricing profile is selected and `input_tokens + cache_*` exceeds **200,000**, the fallback pricing profile `Ru1` is used. This implies an internal soft cap around 200k input tokens per request.
- `K21(messages)` inspects the latest assistant message usage and returns `true` if its token count exceeds 200k (likely to gate error handling when context windows are blown).
- Assistant messages may carry `thinkingMetadata` (attached to `message.thinkingMetadata`) alongside `thinking` content; downstream usage is still unclear.
- Compaction thresholds: defaults around `SoR=13000`, `BPD=20000`, `_PD=20000` tokens; a window-derived cap is applied, overridable via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (percentage of the context window). `DISABLE_COMPACT` bypasses the pipeline entirely.

## Request Assembly (found, minimal pruning)
- Main request builder `IK9` (`cli-beautified.js:431400+`) normalizes messages (`ZZ`), applies system prompts, and sets thinking budgets:
  - Thinking is enabled when `maxThinkingTokens > 0` and sent as `thinking: {type: "enabled", budget_tokens: <cap>}` with a safeguard `ej3` to keep `budget_tokens < max_tokens`.
  - `context_management` payload is added when thinking is enabled and betas include `XvA`; no trimming behavior observed alongside it.
  - Messages are passed through `rj3` to attach prompt-caching hints near the tail but **not** to drop content.
- `ZZ` normalization removes progress/system/meta messages, merges consecutive user/assistant blocks, and rewrites tool inputs, but does **not** summarize or prune by length.
- `mF`/`Q_1` provide a “slice from last compaction” helper by scanning for `system` subtype `compact_boundary`; callers can drop earlier history when a compaction marker is present (used by compaction pipeline to rebuild prompts).
- `HaB` filters user messages when building transcripts, skipping meta lines and hiding `isVisibleInTranscriptOnly` unless explicitly requested.
- `h_1` trims trailing `thinking`/`redacted_thinking` blocks from the latest assistant message before sending to the model (logs a telemetry counter).
- Compaction is driven by the compaction pipeline (`mZB` → `M_R`/`N_R`), which emits `compact_boundary` markers and compact summaries when token thresholds are exceeded (thresholds derived from context window; `DISABLE_COMPACT` turns it off). Auto-compaction uses defaults around `SoR=13000`, `BPD=20000`, `_PD=20000` tokens; `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` can shrink the threshold as a percentage of the context window.
- No explicit rolling-summary or truncation logic surfaced beyond the compaction markers; conversation history appears to go through after light normalization only.

## Summary Generation (validated)
- A startup maintenance task (`r4_`) runs once (unless disabled by `ZD()`), scanning `~/.claude/projects/*/*.jsonl` for conversation chains without `summary` entries.
- For each uncovered leaf, it builds a summarization prompt via `_D1`/`RD1` (pulls the transcript plus settings) and sends it to the model; on success it writes `type: "summary"` via `MH_(leafUuid, summary)`/`xK9`.
- Compaction also produces compact summaries when thresholds are exceeded; these are marked `isCompactSummary` and paired with a `system` `compact_boundary` marker (`K_R(trigger, preTokens)`).

## Bash Output Summarization (observed)
- A dedicated prompt (`querySource: "bash_output_summarization"`) asks the model whether command output should be summarized and to return `<should_summarize>true/false</should_summarize>` plus `<summary>` when applicable (`cli-beautified.js:208289+`).
- Hooked into bash tool results to reduce noisy output before re-injection into context (inferred from prompt wiring).

## Thinking Metadata
- Assistant/user messages can carry `thinkingMetadata` with `{level, disabled}`; when present and not disabled, it sets the thinking token budget (`high` level → ~32k tokens via `HbR.ULTRATHINK`). If absent, the budget is inferred from content length or the `MAX_THINKING_TOKENS` env override. “ultrathink” triggers in user text also bump the budget to `high`.
- `ipT()` toggles thinking globally based on model defaults, user settings, and `MAX_THINKING_TOKENS`.

## Unknown / To Map
- Exact trigger thresholds that emit `compact_boundary` (`K_R(trigger, preTokens)`) system events and how they are used to drop history. Auto-compaction currently fires when token thresholds are breached (defaults derived from context window) unless `DISABLE_COMPACT` is set; manual compaction always emits a marker. Env `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` can override the percentage of the context window used for auto-compaction.
- Where `thinkingMetadata` is consumed downstream beyond token budgeting (e.g., UI rendering).
- How `budget_tokens` or `budget_usd` fields interact with context trimming.
- Whether sidechains share or isolate context budgets from the main session; `isTeammate` flag is set via `NGT()` but the enabling path (teammate/lead mode) is not yet mapped.
- Whether bash-output summarization feeds into compaction/summaries or is only used for transient display; consumption path not yet traced.

## Next Steps (reverse-engineering TODO)
1. Find any higher-level guard that calls `K21` (or similar) to short-circuit when the last assistant reply >200k tokens, and see if it triggers pruning.
2. Trace where bash summarization responses are consumed and how the condensed text is stored (tool_result vs. attachment).
3. Map any downstream consumers of `thinkingMetadata` and teammate mode (`isTeammate`/`NGT()`), plus whether sidechains inherit budgets.

## Validated vs. Speculative
- **Validated**: Context window heuristic (`Su`), pricing guard (`hE6`), presence of bash output summarization prompt, auto-summarizer task (`r4_` → `_D1`/`RD1` → `MH_`/`xK9`), compaction emissions of compact summaries + `compact_boundary`.
- **Speculative**: All other aspects above; no hard evidence yet on conversation history pruning beyond compaction markers, or on downstream usage of `thinkingMetadata`.

## Cross-References
- Tool outputs and how they might be summarized: `TOOL_EXECUTION_FLOW.md`
- Log persistence for summaries/snapshots: `JSONL_LOGGING.md`
