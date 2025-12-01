# Claude Code Context Management (Partial)

**Status**: Partially validated; key mechanics still to be traced  
**Last Updated**: 2025-02-14

> Early notes on token budgeting, summarization, and context windows. More reverse-engineering needed.

## Source Pointers
- Context window heuristic `Su`: `cli-beautified.js:1950-1965`
- Pricing/guard `hE6` + token sum helper `fE6`: `cli-beautified.js:195920-195970`
- Bash output summarization prompt and handler: `cli-beautified.js:208289-208340`

## Known Constants
- `Su(modelName)` reports the assumed context window:
  - `1_000_000` tokens when the model string contains `"[1m]"`.
  - Otherwise `200_000` tokens.
- `hE6(model, usage)` enforces a pricing tier; when the “bt” pricing profile is selected and `input_tokens + cache_*` exceeds **200,000**, the fallback pricing profile `Ru1` is used. This implies an internal soft cap around 200k input tokens per request.
- `K21(messages)` inspects the latest assistant message usage and returns `true` if its token count exceeds 200k (likely to gate error handling when context windows are blown).

## Request Assembly (found, no pruning)
- Main request builder `IK9` (`cli-beautified.js:431400+`) normalizes messages (`ZZ`), applies system prompts, and sets thinking budgets:
  - Thinking is enabled when `maxThinkingTokens > 0` and sent as `thinking: {type: "enabled", budget_tokens: <cap>}` with a safeguard `ej3` to keep `budget_tokens < max_tokens`.
  - `context_management` payload is added when thinking is enabled and betas include `XvA`; no trimming behavior observed alongside it.
  - Messages are passed through `rj3` to attach prompt-caching hints near the tail but **not** to drop content.
- `ZZ` normalization removes progress/system/meta messages, merges consecutive user/assistant blocks, and rewrites tool inputs, but does **not** summarize or prune by length.
- No explicit rolling-summary or truncation logic surfaced in this path; conversation history appears to go through after light normalization only.

## Bash Output Summarization (observed)
- A dedicated prompt (`querySource: "bash_output_summarization"`) asks the model whether command output should be summarized and to return `<should_summarize>true/false</should_summarize>` plus `<summary>` when applicable (`cli-beautified.js:208289+`).
- Hooked into bash tool results to reduce noisy output before re-injection into context (inferred from prompt wiring).

## Unknown / To Map
- Message-level compaction or rolling summaries of long conversations.
- Exact trigger thresholds for pruning history vs. requesting summaries.
- How `budget_tokens` or `budget_usd` fields interact with context trimming.
- Whether sidechains share or isolate context budgets from the main session.

## Next Steps (reverse-engineering TODO)
1. Find any higher-level guard that calls `K21` (or similar) to short-circuit when the last assistant reply >200k tokens, and see if it triggers pruning.
2. Trace where bash summarization responses are consumed and how the condensed text is stored (tool_result vs. attachment).
3. Identify any rolling-summary or “summary” event creators that emit `type: "summary"` entries into the JSONL logs.

## Validated vs. Speculative
- **Validated**: Context window heuristic (`Su`), pricing guard (`hE6`), presence of bash output summarization prompt.
- **Speculative**: All other aspects above; no hard evidence yet on conversation history pruning.

## Cross-References
- Tool outputs and how they might be summarized: `TOOL_EXECUTION_FLOW.md`
- Log persistence for summaries/snapshots: `JSONL_LOGGING.md`
