#!/bin/bash
# PreToolUse: Block WebFetch to internal/suspicious URLs (SSRF protection)
# Exit 2 = block, Exit 0 = allow
#
# Wire on PreToolUse with matcher "WebFetch".

# Resolve jq (often not on PATH in Git Bash on Windows), then fail closed
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
# Fail closed: if jq still unavailable, block rather than silently allow
if [ "$JQ" = "jq" ] && ! command -v jq &>/dev/null; then
  echo "BLOCKED: jq not found -- hook cannot evaluate safety" >&2
  exit 2
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | "$JQ" -r '.tool_name')

if [ "$TOOL_NAME" != "WebFetch" ]; then
  exit 0
fi

URL=$(echo "$INPUT" | "$JQ" -r '.tool_input.url // ""')

BLOCKED_PATTERNS=(
  'localhost'
  '127\.0\.0\.1'
  '0\.0\.0\.0'
  '192\.168\.'
  '10\.[0-9]+\.[0-9]+\.[0-9]+'
  '172\.(1[6-9]|2[0-9]|3[01])\.'
  # Link-local, which covers the cloud instance-metadata endpoint (169.254.169.254)
  # used by AWS / GCP / Azure / DigitalOcean -- the canonical SSRF credential target.
  '169\.254\.'
  'metadata\.google\.internal'
  '\[::1\]'
  'bit\.ly/'
  'tinyurl\.com/'
  'file://'
  'ftp://'
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$URL" | grep -qE "$pattern"; then
    echo "BLOCKED by safety hook: internal/suspicious URL [$URL]" >&2
    exit 2
  fi
done

exit 0
