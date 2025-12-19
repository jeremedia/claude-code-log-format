#!/bin/bash
# validate-format.sh - Analyze Claude Code JSONL logs and detect format drift
#
# Usage:
#   ./scripts/validate-format.sh                    # Analyze default project
#   ./scripts/validate-format.sh /path/to/*.jsonl   # Analyze specific logs
#   ./scripts/validate-format.sh --extract-schema   # Output discovered schema
#
# Requires: jq

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPEC_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Documented fields from spec v1.1 (Claude Code v2.0.49)
DOCUMENTED_TOP_LEVEL="uuid parentUuid type timestamp sessionId version cwd gitBranch isSidechain userType message requestId toolUseResult agentId"
DOCUMENTED_EVENT_TYPES="assistant user file-history-snapshot queue-operation system summary turn_end"

echo -e "${BLUE}Claude Code Log Format Validator${NC}"
echo "=================================="
echo ""

# Get Claude Code version
CC_VERSION=$(claude --version 2>/dev/null || echo "unknown")
echo -e "Claude Code Version: ${GREEN}${CC_VERSION}${NC}"
echo -e "Spec Version: ${YELLOW}1.1 (for v2.0.49)${NC}"
echo ""

# Find log files
if [ $# -gt 0 ] && [ "$1" != "--extract-schema" ]; then
    LOG_FILES="$@"
else
    # Default to most recent kyomei-nada logs
    LOG_DIR="$HOME/.claude/projects/-Volumes-jer4TBv3-kyomei-nada"
    if [ -d "$LOG_DIR" ]; then
        LOG_FILES=$(ls -t "$LOG_DIR"/*.jsonl 2>/dev/null | head -5)
    else
        echo -e "${RED}No log files found. Specify path or ensure default project exists.${NC}"
        exit 1
    fi
fi

echo "Analyzing log files:"
for f in $LOG_FILES; do
    size=$(du -h "$f" 2>/dev/null | cut -f1)
    echo "  - $(basename "$f") ($size)"
done
echo ""

# Extract all unique top-level fields across all event types
echo -e "${BLUE}Extracting schema from logs...${NC}"

ALL_FIELDS=$(cat $LOG_FILES | jq -r 'keys[]' 2>/dev/null | sort | uniq)
ALL_TYPES=$(cat $LOG_FILES | jq -r '.type // "null"' 2>/dev/null | sort | uniq)

echo ""
echo -e "${BLUE}Event Types Found:${NC}"
for t in $ALL_TYPES; do
    count=$(cat $LOG_FILES | jq -r "select(.type == \"$t\") | .type" 2>/dev/null | wc -l | tr -d ' ')
    if echo "$DOCUMENTED_EVENT_TYPES" | grep -qw "$t"; then
        echo -e "  ${GREEN}✓${NC} $t ($count events)"
    else
        echo -e "  ${YELLOW}NEW${NC} $t ($count events)"
    fi
done

echo ""
echo -e "${BLUE}Top-Level Fields Analysis:${NC}"
echo ""

# Check documented fields
echo "Documented fields status:"
for field in $DOCUMENTED_TOP_LEVEL; do
    if echo "$ALL_FIELDS" | grep -qw "$field"; then
        echo -e "  ${GREEN}✓${NC} $field"
    else
        echo -e "  ${YELLOW}?${NC} $field (not found in sample - may be conditional)"
    fi
done

echo ""
echo "New fields (not in spec v1.1):"
NEW_FIELDS=""
for field in $ALL_FIELDS; do
    if ! echo "$DOCUMENTED_TOP_LEVEL" | grep -qw "$field"; then
        NEW_FIELDS="$NEW_FIELDS $field"
        echo -e "  ${YELLOW}+${NC} $field"
    fi
done

if [ -z "$NEW_FIELDS" ]; then
    echo "  (none)"
fi

# Per-type field analysis
echo ""
echo -e "${BLUE}Fields by Event Type:${NC}"
for t in $ALL_TYPES; do
    echo ""
    echo -e "  ${BLUE}$t${NC}:"
    fields=$(cat $LOG_FILES | jq -r "select(.type == \"$t\") | keys[]" 2>/dev/null | sort | uniq | tr '\n' ' ')
    echo "    $fields"
done

# Check for system subtypes
echo ""
echo -e "${BLUE}System Event Subtypes:${NC}"
subtypes=$(cat $LOG_FILES | jq -r 'select(.type == "system") | .subtype // "none"' 2>/dev/null | sort | uniq)
for st in $subtypes; do
    echo "  - $st"
done

# toolUseResult structure analysis
echo ""
echo -e "${BLUE}toolUseResult Structures:${NC}"
cat $LOG_FILES | jq -c 'select(.toolUseResult != null and .toolUseResult != {}) | .toolUseResult | keys' 2>/dev/null | sort | uniq -c | sort -rn | head -10

# Summary
echo ""
echo "=================================="
echo -e "${BLUE}Summary${NC}"
echo "=================================="

if [ -n "$NEW_FIELDS" ]; then
    echo -e "${YELLOW}⚠ Format drift detected${NC}"
    echo "New fields found:$NEW_FIELDS"
    echo ""
    echo "Action: Update CLAUDE_CODE_LOG_FORMAT.md"
    exit 1
else
    echo -e "${GREEN}✓ No new top-level fields detected${NC}"
    echo "Spec appears current for basic structure."
fi

if [ "$1" == "--extract-schema" ]; then
    echo ""
    echo -e "${BLUE}Full Schema Export:${NC}"
    echo "{"
    for t in $ALL_TYPES; do
        echo "  \"$t\": {"
        fields=$(cat $LOG_FILES | jq -r "select(.type == \"$t\") | keys[]" 2>/dev/null | sort | uniq)
        first=true
        for f in $fields; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            # Get sample value type
            sample_type=$(cat $LOG_FILES | jq -r "select(.type == \"$t\") | .$f | type" 2>/dev/null | head -1)
            echo -n "    \"$f\": \"$sample_type\""
        done
        echo ""
        echo "  },"
    done
    echo "}"
fi
