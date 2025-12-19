# Claude Code Log Format Versioning Process

This document establishes the process for tracking and updating the specification as Claude Code evolves.

## Version Tracking Strategy

### When to Check for Changes

1. **On Claude Code update** - Check `claude --version` after updates
2. **When parsing fails** - Unexpected fields/structures indicate format changes
3. **Monthly audit** - Compare current logs against spec baseline

### Automated Detection

Run the validation script after any Claude Code update:

```bash
./scripts/validate-format.sh
```

This will:
1. Extract schema from recent logs
2. Compare against documented fields
3. Report new/missing/changed fields
4. Flag breaking changes

## Version Naming Convention

```
Spec v{MAJOR}.{MINOR} for Claude Code v{CC_VERSION}
```

- **MAJOR**: Breaking changes (field removed, type changed, semantic change)
- **MINOR**: Additive changes (new fields, new event types, new subtypes)

### Examples
- `v1.1 for Claude Code v2.0.49` - Original spec
- `v1.2 for Claude Code v2.0.65` - Additive changes only
- `v2.0 for Claude Code v3.0.0` - Breaking changes

## Update Workflow

### 1. Detection Phase

```bash
# Check current Claude Code version
claude --version

# Run validation against recent logs
./scripts/validate-format.sh ~/.claude/projects/YOUR_PROJECT/*.jsonl
```

### 2. Analysis Phase

Create `VERSION_DRIFT.md` documenting:
- [ ] New fields discovered
- [ ] Removed fields
- [ ] Changed structures
- [ ] New event types/subtypes
- [ ] New tool types

### 3. Update Phase

1. **Update CLAUDE_CODE_LOG_FORMAT.md**
   - Add new fields to field inventory
   - Update JSON schema
   - Add examples for new structures

2. **Update TOOL_RESULT_STRUCTURES.md** (if tool changes)
   - Document new tool result formats
   - Update error patterns

3. **Update README.md**
   - Bump version badge
   - Add to versioning section
   - Note breaking changes

4. **Archive drift analysis**
   - Move `VERSION_DRIFT.md` to `archive/v{OLD}_to_v{NEW}_drift.md`

### 4. Validation Phase

```bash
# Validate updated spec against corpus
./scripts/validate-format.sh --strict

# Ensure examples still parse
./scripts/validate-examples.sh
```

## Field Stability Classification

| Classification | Definition | Example |
|----------------|------------|---------|
| **Stable** | Present in all versions, semantics unchanged | `uuid`, `timestamp`, `type` |
| **Extended** | Present in all versions, new values added | `type` enum (new event types) |
| **New** | Added in recent version | `isMeta`, `compactMetadata` |
| **Deprecated** | Still present but may be removed | (none currently) |
| **Removed** | No longer present in logs | (track if found) |

## Breaking Change Policy

Breaking changes require:
1. Major version bump (v1.x → v2.0)
2. Migration guide in `docs/migrations/`
3. Deprecation notice if possible

## Changelog Format

```markdown
## [v1.2] - 2025-12-12 - Claude Code v2.0.65

### Added
- `isMeta` field on user events
- `system` event subtypes: `stop_hook_summary`, `compact_boundary`
- `compactMetadata` for context compaction events

### Changed
- `file-history-snapshot` simplified structure
- `slug` field now documented in main spec

### Deprecated
- (none)

### Removed
- (none)
```

## Automation Opportunities

### GitHub Action (future)
```yaml
on:
  schedule:
    - cron: '0 0 1 * *'  # Monthly
  workflow_dispatch:

jobs:
  validate-spec:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Get Claude Code version
        run: claude --version
      - name: Validate format
        run: ./scripts/validate-format.sh
      - name: Create issue if drift detected
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Format drift detected',
              body: 'Validation failed - spec may need update'
            })
```

## Contact

When Anthropic releases Claude Code updates that change the log format:
1. Check their changelog (if available)
2. Run validation
3. Update spec
4. Consider contributing upstream if format is now documented
