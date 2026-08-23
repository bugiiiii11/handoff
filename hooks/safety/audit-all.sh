#!/bin/bash
# PostToolUse: Log Bash commands, WebFetch URLs and WebSearch queries to a JSONL audit file
# Audit file: ~/.claude/safety-audit.jsonl (override with CLAUDE_SAFETY_AUDIT_FILE)
#
# Wire on PostToolUse with matcher "Bash|WebFetch|WebSearch".

# Resolve jq (often not on PATH in Git Bash on Windows)
JQ="jq"
if ! command -v jq &>/dev/null; then
  _U="${USER:-$USERNAME}"
  for p in "/c/Users/$_U/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe/jq.exe" \
           "/c/ProgramData/winget/Links/jq.exe" \
           "/c/Users/$_U/scoop/shims/jq.exe" \
           "/usr/bin/jq" "/usr/local/bin/jq"; do
    [ -x "$p" ] && { JQ="$p"; break; }
  done
fi
# Audit hooks degrade gracefully: if jq is unavailable, skip logging (don't block)
if [ "$JQ" = "jq" ] && ! command -v jq &>/dev/null; then exit 0; fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | "$JQ" -r '.tool_name')
SESSION_ID=$(echo "$INPUT" | "$JQ" -r '.session_id')
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
AUDIT_FILE="${CLAUDE_SAFETY_AUDIT_FILE:-$HOME/.claude/safety-audit.jsonl}"

# Ensure audit dir exists
mkdir -p "$(dirname "$AUDIT_FILE")"

case "$TOOL_NAME" in
  Bash|PowerShell)
    COMMAND=$(echo "$INPUT" | "$JQ" -r '.tool_input.command // "unknown"')
    echo "{\"ts\":\"$TIMESTAMP\",\"session\":\"$SESSION_ID\",\"tool\":\"$TOOL_NAME\",\"command\":$(echo "$COMMAND" | "$JQ" -Rs .)}" >> "$AUDIT_FILE"
    ;;
  WebFetch)
    URL=$(echo "$INPUT" | "$JQ" -r '.tool_input.url // "unknown"')
    echo "{\"ts\":\"$TIMESTAMP\",\"session\":\"$SESSION_ID\",\"tool\":\"WebFetch\",\"url\":$(echo "$URL" | "$JQ" -Rs .)}" >> "$AUDIT_FILE"
    ;;
  WebSearch)
    QUERY=$(echo "$INPUT" | "$JQ" -r '.tool_input.query // "unknown"')
    echo "{\"ts\":\"$TIMESTAMP\",\"session\":\"$SESSION_ID\",\"tool\":\"WebSearch\",\"query\":$(echo "$QUERY" | "$JQ" -Rs .)}" >> "$AUDIT_FILE"
    ;;
esac

exit 0
