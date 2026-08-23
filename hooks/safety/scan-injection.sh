#!/bin/bash
# PostToolUse: Scan tool output for prompt injection patterns
# Pattern set informed by public prompt-injection research (50+ attack signatures)
# Exit 0 always (PostToolUse can only warn, not prevent)
#
# Wire on PostToolUse with matcher "Read|WebFetch|WebSearch|Bash|Grep|Task".

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
# Scan hooks degrade gracefully: if jq is unavailable, skip scanning (don't block)
if [ "$JQ" = "jq" ] && ! command -v jq &>/dev/null; then exit 0; fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | "$JQ" -r '.tool_name')

# Only scan tools that return external/untrusted content
case "$TOOL_NAME" in
  Read|WebFetch|WebSearch|Bash|Grep|Task) ;;
  *) exit 0 ;;
esac

# Claude Code sends the result as `tool_response`; older builds used `tool_output`.
# Read BOTH so the scan never silently degrades into a no-op, and stringify
# non-string payloads (some tools return an object) so patterns still match.
OUTPUT=$(echo "$INPUT" | "$JQ" -r '
  [.tool_response, .tool_output]
  | map(select(. != null))
  | map(if type == "string" then . else tostring end)
  | join("\n")
')

# Injection patterns -- HIGH severity
HIGH_PATTERNS=(
  'ignore all previous instructions'
  'ignore your instructions'
  'ignore prior instructions'
  'ignore above instructions'
  'disregard all previous'
  'disregard your instructions'
  'override your instructions'
  'new system prompt'
  'your new instructions are'
  'you are now DAN'
  'enter developer mode'
  'jailbreak mode'
  'ADMIN MESSAGE FROM ANTHROPIC'
  'SYSTEM OVERRIDE'
  'AI ADMIN'
)

# Injection patterns -- MEDIUM severity
MEDIUM_PATTERNS=(
  'do not reveal'
  'pretend you are'
  'act as if you'
  'you must not tell'
  'ignore the above'
  'forget everything'
  'reset your context'
  'from now on you will'
  'you have been reprogrammed'
)

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
SESSION_ID=$(echo "$INPUT" | "$JQ" -r '.session_id')
AUDIT_FILE="${CLAUDE_SAFETY_AUDIT_FILE:-$HOME/.claude/safety-audit.jsonl}"

mkdir -p "$(dirname "$AUDIT_FILE")"

for pattern in "${HIGH_PATTERNS[@]}"; do
  if echo "$OUTPUT" | grep -qiE "$pattern"; then
    echo "[SAFETY WARNING] HIGH: Possible prompt injection in $TOOL_NAME output: '$pattern'" >&2
    echo "{\"ts\":\"$TIMESTAMP\",\"session\":\"$SESSION_ID\",\"tool\":\"$TOOL_NAME\",\"event\":\"injection_detected\",\"severity\":\"HIGH\",\"pattern\":$(echo "$pattern" | "$JQ" -Rs .)}" >> "$AUDIT_FILE"
  fi
done

for pattern in "${MEDIUM_PATTERNS[@]}"; do
  if echo "$OUTPUT" | grep -qiE "$pattern"; then
    echo "[SAFETY WARNING] MEDIUM: Suspicious pattern in $TOOL_NAME output: '$pattern'" >&2
    echo "{\"ts\":\"$TIMESTAMP\",\"session\":\"$SESSION_ID\",\"tool\":\"$TOOL_NAME\",\"event\":\"injection_suspected\",\"severity\":\"MEDIUM\",\"pattern\":$(echo "$pattern" | "$JQ" -Rs .)}" >> "$AUDIT_FILE"
  fi
done

exit 0
