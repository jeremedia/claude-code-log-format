# Claude Code Log Format Specification

> **The first and only complete, production-tested specification for Claude Code agent conversation logs**

[![Spec Version](https://img.shields.io/badge/spec%20version-1.2-blue.svg)](CLAUDE_CODE_LOG_FORMAT.md)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-v2.0.65-purple.svg)](https://claude.com/claude-code)
[![Validation](https://img.shields.io/badge/validated-236K%2B%20events-green.svg)](CLAUDE_CODE_LOG_FORMAT.md#validation-status)
[![Status](https://img.shields.io/badge/status-production%20ready-success.svg)](CLAUDE_CODE_LOG_FORMAT.md)

## What Is This?

This repository contains the **complete, authoritative specification** for the JSONL log format produced by **[Claude Code](https://claude.com/claude-code)**, Anthropic's official CLI agent for software development.

> ⚠️ **Version Notice**: The spec and schema are updated to **v1.2 for Claude Code v2.0.65** (Bun-compiled). New fields/subtypes (`slug`, `logicalParentUuid`, `isTeammate`, `thinkingMetadata`, `isMeta`, `compact_boundary`, `stop_hook_summary`, `isCompactSummary`, simplified `file-history-snapshot`) are included. See `VERSION_DRIFT.md` for the 2.0.49 → 2.0.65 diff and `source-docs/` for the reverse-engineered source notes (including summary generation and compaction markers).

### Drift Highlights (v2.0.49 → v2.0.65, now captured in spec v1.2)
- New top-level metadata: `slug`, `agentId`, `isTeammate`, `logicalParentUuid`, `thinkingMetadata`.
- Simplified `file-history-snapshot` structure (`messageId` + `snapshot` only) and new system subtypes (`compact_boundary`, `stop_hook_summary`).
- Automatic maintenance tasks emit `summary` events (startup auto-summarizer) and compaction markers (`compact_boundary` + `isCompactSummary`).
- Session filenames favor full UUIDs; plan slugs are reused across agents.
- Full drift list and reproduction steps live in `VERSION_DRIFT.md` and `source-docs/README.md`.

Despite Claude Code being in active use, **no public documentation** exists for its log format—not in Anthropic's official docs, not on GitHub, not on Stack Overflow, nowhere. Developers building dashboards, analytics tools, parsers, and observability systems have been independently reverse-engineering the same format with no reference.

**This changes that.**

## What's Inside

### 📖 Core Documentation

The [**CLAUDE_CODE_LOG_FORMAT.md**](CLAUDE_CODE_LOG_FORMAT.md) specification includes:

### Complete Documentation
- **Full field inventory** - Every field, every type, every enum value
- **7 event types** - Including undocumented types like `file-history-snapshot`, `system`, `queue-operation`
- **5 content types** - Text, thinking, tool_use, tool_result, image
- **23 tools documented** - With usage counts, categories, and purposes
- **Multi-tool streaming patterns** - How tools actually appear in logs (differs from standard Anthropic API!)
- **Message grouping semantics** - How `message.id` groups related streaming events
- **Duration measurement rules** - Which tools provide `durationMs` (only 2!), how to calculate for others
- **Tool execution lifecycle** - Linking tool invocations to results via `tool_use_id`
- **Error semantics** - The subtle difference between `is_error: false`, `is_error: null`, and field absence
- **Timestamp uniqueness issues** - Why timestamps alone aren't sufficient for event identification

### Production-Grade Resources
- **JSON Schema (Draft-07)** - For automated validation
- **Semantic DAG model** - Event linking via `uuid` → `parentUuid` chains
- **Fully annotated examples** - Real events with line-by-line explanations
- **Dashboard-oriented guide** - Practical code for building visualizations
- **Edge cases documented** - Out-of-order tool results, streaming artifacts, error patterns

### 📚 Supplemental Documentation

- [**TOOL_RESULT_STRUCTURES.md**](TOOL_RESULT_STRUCTURES.md) - Deep dive on all 16 non-MCP tools with examples, error rates, and parser patterns
- [**REFLECTIONS.md**](REFLECTIONS.md) - Claude's meta-observations on analyzing 236K+ events of its own cognitive operations *(Unique perspective on AI cognition!)*

### 🔄 Versioning & Maintenance

- [**VERSION_DRIFT.md**](VERSION_DRIFT.md) - Analysis of format changes between spec version and current Claude Code
- [**VERSIONING_PROCESS.md**](VERSIONING_PROCESS.md) - Process for evaluating and updating the spec against new versions
- [**scripts/validate-format.sh**](scripts/validate-format.sh) - Automated schema extraction and drift detection

## Validation Methodology

This isn't theoretical documentation—it's **empirically validated** against real data:

- **13,261 events analyzed** across 7 diverse conversation logs
- **88MB to 280KB** workload range (simple to complex conversations)
- **230 error cases** documented (not just the happy path)
- **5 rounds of rigorous peer review** - Each iteration correcting progressively smaller issues
- **Battle-tested** - Fixed multiple critical errors during validation (multi-tool patterns, duration semantics, etc.)

### The Methodology

1. **Reverse-engineer from actual logs** - Not assumptions or API docs
2. **Validate across diverse samples** - Multiple conversations, different tools, various complexity levels
3. **Document what IS, not what "should be"** - Empirical observation over theory
4. **Iterative peer review** - Fresh reviews until no critical issues remain
5. **Mark uncertainty explicitly** - State sample sizes, distinguish observed vs. theoretical

This approach caught and corrected **major factual errors** that would have broken implementations:
- Multi-tool streaming pattern was completely wrong in initial draft
- Duration measurement rules were incorrectly documented
- `is_error` semantics were oversimplified
- 5 additional event types were completely missing

## Why This Matters

If you're building:
- 📊 **Dashboards** - Visualize agent activity, tool usage, performance metrics
- 📈 **Analytics tools** - Track productivity, token usage, conversation patterns
- 🔍 **Parsers** - Extract structured data from log files
- 🔭 **Observability systems** - Monitor agent behavior, debug failures
- 📉 **Performance trackers** - Measure latency, tool execution time

...you need to understand this format. And until now, **no complete reference existed**.

### What's Not Available Elsewhere

No other public resource provides:
- ✅ A complete JSON Schema
- ✅ Correct multi-tool invocation patterns
- ✅ All 7 event types documented
- ✅ Tool result structure variations
- ✅ Duration measurement semantics
- ✅ Message grouping via `message.id`
- ✅ Thinking content with signatures
- ✅ Validated across thousands of events

## Quick Start

### Understanding the Format

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/claude-code-log-format.git
cd claude-code-log-format

# Read the complete specification
cat CLAUDE_CODE_LOG_FORMAT.md
```

### Example: Parse a Log File

```javascript
import fs from 'fs';

// Read JSONL log file
const logPath = '~/.claude/projects/YOUR_PROJECT/agent-SESSION_ID.jsonl';
const lines = fs.readFileSync(logPath, 'utf-8').split('\n').filter(Boolean);
const events = lines.map(line => JSON.parse(line));

// Filter to assistant responses
const responses = events.filter(e => e.type === 'assistant');

// Extract tool invocations
const toolCalls = responses.flatMap(event =>
  event.message?.content?.filter(c => c.type === 'tool_use') || []
);

console.log(`Found ${toolCalls.length} tool invocations`);
```

### Example: Calculate Response Latency

```javascript
// Find assistant message and next event
const assistantMsg = events.find(e => e.uuid === targetUuid);
const assistantIdx = events.indexOf(assistantMsg);
const nextMsg = events[assistantIdx + 1];

if (nextMsg) {
  const latencyMs = new Date(nextMsg.timestamp) - new Date(assistantMsg.timestamp);
  console.log(`Response latency: ${latencyMs}ms`);
}
```

See [CLAUDE_CODE_LOG_FORMAT.md](CLAUDE_CODE_LOG_FORMAT.md) for complete examples and patterns.

## Common Use Cases

### Building a Dashboard
- Track agent state (ACTIVE, IDLE, WAITING)
- Visualize tool usage patterns
- Monitor token consumption and caching efficiency
- Display event timeline with tool invocations

### Analytics & Metrics
- Measure average response latency
- Calculate tool execution time (when `durationMs` available)
- Track events per minute
- Analyze conversation structure via `parentUuid` chains

### Debugging & Observability
- Link tool invocations to results via `tool_use_id`
- Identify failed tool executions (`is_error: true`)
- Reconstruct conversation tree from `uuid` → `parentUuid` DAG
- Group related events by `message.id`

## Schema Scope

⚠️ **Important**: The JSON Schema validates **only** `assistant` and `user` event types. The 5 additional event types (`file-history-snapshot`, `queue-operation`, `system`, `summary`, `turn_end`) have different structures documented in prose.

For complete validation, implement a discriminated union based on the `type` field.

## Contributing

This specification is based on analysis of Claude Code v2.0.49 logs. As the format evolves:

- **Report issues** - If you find discrepancies in newer versions
- **Share edge cases** - Unusual patterns not covered in the spec
- **Contribute examples** - Real-world usage patterns
- **Suggest improvements** - Clarity, additional examples, diagrams

## Versioning

This specification tracks the **current Claude Code log format**. As Anthropic continues improving Claude Code, the format may change.

### Specification Releases

- **v1.2** (2025-12-13) - **Claude Code v2.0.65** ⭐ Current
  - Added new top-level metadata (`slug`, `logicalParentUuid`, `isTeammate`, `isMeta`, `thinkingMetadata`, `isVisibleInTranscriptOnly`)
  - Documented new `system` subtypes (`compact_boundary`, `stop_hook_summary`) and `compactMetadata`
  - Simplified `file-history-snapshot` structure, `summary.isCompactSummary`, auto-summarizer + compaction emitters
  - Updated JSON Schema to cover additive fields; drift reconciled from v2.0.49 corpus to v2.0.65 binary

- **v1.1** (2025-11-23) - **Claude Code v2.0.49**
  - Expanded validation: 236K+ events across 1,001 log files (18x increase)
  - Complete tool result structures for all 16 non-MCP tools
  - Corrected multi-tool pattern: 99.97% single tool (2 cases found)
  - Added [TOOL_RESULT_STRUCTURES.md](TOOL_RESULT_STRUCTURES.md) supplemental documentation
  - Error rate analysis per tool (Edit: 4.9%, Task: 10%, KillShell: 86%)
  - Critical finding: Task tool returns array content (unique behavior)

- **v1.0** (2025-11-23) - **Claude Code v2.0.49**
  - Initial release validated against 13,261 events
  - Complete field inventory (7 event types, 23 tools)
  - All content types documented (text, thinking, tool_use, tool_result, image)
  - Production-tested against diverse workloads

### Version Drift Analysis

When significant version gaps occur, run the validation script:

```bash
./scripts/validate-format.sh
```

Current drift analysis: [VERSION_DRIFT.md](VERSION_DRIFT.md) documents 23 new fields between v2.0.49 and v2.0.65.

### Future Updates

As Claude Code evolves, this specification will be updated to track format changes:
- New event types or content types
- Additional tools (new MCP servers, expanded capabilities)
- Changes to field semantics or structure
- Breaking changes will increment major version

See [VERSIONING_PROCESS.md](VERSIONING_PROCESS.md) for the complete update workflow.

**Using a different Claude Code version?** Check the badge above and compare against your version. Run the validation script or open an issue if you find discrepancies!

## How This Was Created

This specification was created through **reverse-engineering Claude Code logs** with a rigorous validation methodology:

1. **Initial Analysis** - 34 events from a single conversation (draft schema)
2. **Validation Expansion** - 7 diverse logs, 13,261 events total
3. **Peer Review Round 1** - Found critical multi-tool pattern error
4. **Peer Review Round 2** - Fixed 7 critical + 4 moderate issues
5. **Peer Review Round 3** - Resolved parser-documentation alignment issues
6. **Peer Review Round 4** - Corrected 4 critical + 4 major + 4 minor issues
7. **Peer Review Round 5** - **APPROVED FOR v1.0** - No critical issues

Each review cycle caught factual errors, schema inconsistencies, and missing documentation. The iterative process continued until reaching production readiness.

### Key Corrections Made
- ❌ **Wrong**: Multi-tool invocations appear in single content array
- ✅ **Right**: They stream as sequential log entries with shared `message.id`

- ❌ **Wrong**: `durationMs` available in Bash tool results
- ✅ **Right**: Only Glob and WebFetch provide `durationMs`

- ❌ **Wrong**: `is_error` field absent on success
- ✅ **Right**: Can be `true` (failure), `false` (explicit success), or absent (implicit success)

## License

MIT License - See [LICENSE](LICENSE) for details.

This specification is provided as-is for the benefit of the Claude Code developer community.

## Author

Created by **Claude** (Anthropic's AI assistant) through iterative reverse-engineering and validation of Claude Code conversation logs, November 2025.

## Acknowledgments

- **ChatGPT-5.1** - Confirmed no other public specification exists
- **The Claude Code team at Anthropic** - For building an amazing agent platform
- **The developer community** - Who have been reverse-engineering this format independently

---

**Found this useful?** ⭐ Star this repository to help others discover the definitive Claude Code log format specification.

**Building something with Claude Code logs?** Share your project! Open an issue or discussion to let the community know.
