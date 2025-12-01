# Claude Code Terminal Integration

**Status**: Validated against source (cli.js v2.0.55)
**Last Updated**: 2025-11-29

> This document describes terminal integration behaviors validated against Claude Code's bundled source code (npm package).

## Tab/Window Titles

### Escape Sequence

Claude Code sets terminal tab titles using OSC 0:

**Unix/macOS:**
```javascript
process.stdout.write(`\x1B]0;${title}\x07`)
```

**Windows:**
```javascript
process.title = title
```

The title is prefixed with ✳ when set:
```javascript
A ? `✳ ${A}` : ""
```

### Title Generation Logic

Claude Code uses a **separate API call** to determine when to update the title:

```javascript
systemPrompt: [
  "Analyze if this message indicates a new conversation topic. " +
  "If it does, extract a 2-3 word title that captures the new topic. " +
  "Format your response as a JSON object with two fields: " +
  "'isNewTopic' (boolean) and 'title' (string, or null if isNewTopic is false). " +
  "Only include these fields, no other text. " +
  "ONLY generate the JSON object, no other text (eg. no markdown)."
]
```

**Query metadata:**
- `querySource: "terminal_update_title"`
- Triggered on user messages (excluding `<local-command-stdout>` prefixed content)

**Response format:**
```json
{
  "isNewTopic": true,
  "title": "Ghostty Tab Titles"
}
```

### Environment Variable

Title updates can be disabled:
```bash
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1
```

### JSONL Storage

Two event types store title-related data:

**Summary events** (`type: "summary"`):
```json
{
  "type": "summary",
  "summary": "Claude Code Integration: Custom Hooks...",
  "leafUuid": "57d54247-2e2b-4658-beaf-4e8f704569a7"
}
```

**Custom title events** (`type: "custom-title"`):
```json
{
  "type": "custom-title",
  "customTitle": "User Defined Title",
  "sessionId": "session-uuid"
}
```

### Terminal Compatibility

Supported by most modern terminals:
- Ghostty
- iTerm2
- Terminal.app
- Windows Terminal
- Alacritty
- Kitty
- Wezterm

**Ghostty config** (`~/.config/ghostty/config`):
```
# On by default
window-title-from-escape-sequence = true
```

---

## Desktop Notifications

Claude Code supports two notification protocols:

### OSC 99 (Kitty Protocol)

Used by Kitty, Ghostty, and other modern terminals:

```javascript
// Notification with ID for grouping
const id = Math.floor(Math.random() * 10000);

// Title
process.stdout.write(`\x1B]99;i=${id}:d=0:p=title;${title}\x1B\\`);

// Body
process.stdout.write(`\x1B]99;i=${id}:p=body;${message}\x1B\\`);

// Focus action (brings terminal to front)
process.stdout.write(`\x1B]99;i=${id}:d=1:a=focus;\x1B\\`);
```

**Parameters:**
- `i=ID` - Notification identifier (for grouping/updating)
- `d=0/1` - Start/end of notification
- `p=title/body` - Payload type
- `a=focus` - Action to perform

### OSC 777 (iTerm2/Legacy)

Fallback for terminals not supporting OSC 99:

```javascript
process.stdout.write(`\x1B]777;notify;${title};${message}\x07`);
```

### Terminal Bell

Simple audible alert:
```javascript
process.stdout.write("\x07");
```

---

## Screen Control

### Clear Screen

Full screen clear with cursor reset:
```javascript
process.stdout.write("\x1B[2J\x1B[3J\x1B[H");
```

**Sequence breakdown:**
- `\x1B[2J` - Clear entire screen
- `\x1B[3J` - Clear scrollback buffer
- `\x1B[H` - Move cursor to home position (0,0)

---

## Status Line

Claude Code can configure a custom status line in the terminal prompt.

### Setup Commands

```
/statusline
/terminal-setup
```

### Information Displayed

- Current working directory
- Git branch
- Agent state (active/idle)
- Token usage indicators

**Note**: Status line implementation details not yet extracted from source.

---

## Summary: Escape Sequences Reference

| Purpose | Sequence | Protocol |
|---------|----------|----------|
| Set title | `\x1B]0;title\x07` | OSC 0 |
| Notification (modern) | `\x1B]99;params\x1B\\` | OSC 99 (Kitty) |
| Notification (legacy) | `\x1B]777;notify;title;msg\x07` | OSC 777 (iTerm2) |
| Bell | `\x07` | BEL |
| Clear screen | `\x1B[2J\x1B[3J\x1B[H` | CSI |

---

## Source Reference

Analysis based on:
- **Package**: `@anthropic-ai/claude-code@2.0.55`
- **File**: `cli.js` (bundled/minified)
- **Functions identified**: `_o1` (setTitle), `CQ2` (title analysis), notification handlers

---

## Related Documentation

- [CLAUDE_CODE_LOG_FORMAT.md](CLAUDE_CODE_LOG_FORMAT.md) - Complete JSONL format spec
- [TOOL_RESULT_STRUCTURES.md](TOOL_RESULT_STRUCTURES.md) - Tool result details
