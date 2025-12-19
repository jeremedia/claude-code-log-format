# Claude Code Source Documentation

This folder houses reverse-engineered notes from the bundled Claude Code runtime. Claude Code ships as a Bun-compiled binary (~158MB) containing minified JavaScript. We extract readable strings and document internal behaviors to understand features not covered by official documentation.

**Current baseline:** v2.0.69 (December 2025)

## Document Index

| File | Topic |
|------|-------|
| `JSONL_LOGGING.md` | How session logs are written, deduped, sidechained, and mirrored remotely |
| `SESSION_MANAGEMENT.md` | Session IDs, path layout, load/flush helpers, persistence skip conditions |
| `TOOL_EXECUTION_FLOW.md` | Tool queue/dispatch, pre/post hooks, permission gating, telemetry/error surfaces |
| `SLUG_GENERATION.md` | Wordlists and slug assignment for plan files |
| `CONTEXT_MANAGEMENT.md` | Context window heuristics, thinking budgets, pruning/summarization |
| `PROMPT_SUGGESTIONS.md` | "Tab to accept" suggestions - fork queries, filtering, telemetry |

## Why This Exists

Claude Code evolves rapidly. Anthropic ships updates frequently, and not all behaviors are documented. For Kyomei Nada to accurately observe and display Claude's internal states, we need to understand:

- What data Claude Code logs (and doesn't log)
- How features like suggestions, thinking, and context management work internally
- What API patterns Claude Code uses (fork queries, telemetry events)
- How to identify new features before official documentation catches up

## How to Investigate New Features

### 1. Extract Strings from the Binary

```bash
# Find installed version
ls ~/.local/share/claude/versions

# Extract searchable text (takes a few seconds)
strings ~/.local/share/claude/versions/2.0.69 > /tmp/claude-2.0.69.strings
wc -l /tmp/claude-2.0.69.strings  # Typically 300k+ lines
```

### 2. Search for Feature Keywords

```bash
# Generic feature search
grep -i "featurename" /tmp/claude-2.0.69.strings | head -50

# Look for telemetry events (usually prefixed with "tengu_")
grep -E "tengu_[a-z_]+" /tmp/claude-2.0.69.strings | sort -u

# Find feature flags
grep -E "CLAUDE_CODE_[A-Z_]+" /tmp/claude-2.0.69.strings | sort -u

# Search for UI text you've seen
grep -i "tab to accept" /tmp/claude-2.0.69.strings
```

### 3. Trace Function Relationships

The Bun bundle preserves function names. When you find relevant code:

```bash
# Find a function definition and its callers
grep -B5 -A20 "function.*suggestionHandler" /tmp/claude-2.0.69.strings

# Look for related state management
grep -E "setState.*suggestion|suggestion.*state" /tmp/claude-2.0.69.strings
```

### 4. Monitor API Traffic

The proxy captures all API requests. Compare:
- Normal conversation requests
- Fork queries (shorter context, specific prompts)
- Telemetry/analytics calls

### 5. Observe JSONL Logs

```bash
# Watch live logs during Claude Code usage
tail -f ~/.claude/projects/-Volumes-*/*.jsonl | jq '.'

# Find new event types
cat ~/.claude/projects/*/*.jsonl | jq -r '.type' | sort -u
```

### 6. Document Findings

Create a new `.md` file in this directory with:
- Feature overview
- How it works (flow diagram if complex)
- Key functions (minified names change between versions)
- Telemetry events
- Implications for Kyomei Nada
- Search patterns for future updates

## Version Drift Notes

### v2.0.65 → v2.0.69
- Prompt suggestions feature added (fork query pattern)
- New telemetry: `tengu_prompt_suggestion`
- Feature flag: `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION`

### v2.0.55 → v2.0.65
- Message metadata now includes `slug`, `agentId`, `isTeammate`, `logicalParentUuid`, `thinkingMetadata`
- `file-history-snapshot` events pared down to `{messageId, snapshot, isSnapshotUpdate}`
- New system subtypes: `compact_boundary`, `stop_hook_summary`
- Slugs reused across agents: `<slug>-agent-<session>.md`

## Useful Search Patterns

### By Feature Area

| Area | Search Pattern |
|------|----------------|
| Logging | `insertMessageChain`, `appendEntry`, `writeJsonl` |
| Tools | `H50`, `k61`, `Cm5`, `Em5`, `stop_hook_summary` |
| Slugs | `KpR`, `X4B`, `h4B`, `Q4B`, `ZJD` |
| Context | `r4_`, `_D1`, `RD1`, `MH_`, `xK9`, `compact_boundary` |
| Suggestions | `prompt_suggestion`, `Gi1`, `FyB`, `Wi1` |
| Fork queries | `SDR`, `forkLabel`, `cacheSafeParams` |

### Telemetry Events

```bash
# List all telemetry event names
grep -oE 'tengu_[a-z_]+' /tmp/claude-2.0.69.strings | sort -u
```

Common events:
- `tengu_api_query` - API request started
- `tengu_api_success` - API request completed
- `tengu_api_error` - API request failed
- `tengu_prompt_suggestion` - Suggestion shown/accepted/ignored
- `tengu_context_size` - Context window metrics
- `tengu_bash_tool_*` - Bash tool usage patterns

## Validation

After documenting a feature:

1. **Behavioral test**: Does the documented behavior match what you observe?
2. **Log check**: Do JSONL logs contain expected fields?
3. **Proxy check**: Does API traffic match expected patterns?
4. **Cross-reference**: Does official docs contradict findings?

## Contributing

When you discover something new about Claude Code internals:

1. Check if it's already documented here
2. Create/update the relevant `.md` file
3. Add version drift notes if behavior changed
4. Update search patterns if you found useful grep commands
5. Consider whether Kyomei Nada should surface this data
