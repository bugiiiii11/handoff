#!/bin/bash
# PreToolUse: Block Write/Edit on sensitive files
# Exit 2 = block, Exit 0 = allow
#
# Wire on PreToolUse with matcher "Edit|Write".

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

if [[ ! "$TOOL_NAME" =~ ^(Edit|Write)$ ]]; then
  exit 0
fi

FILE=$(echo "$INPUT" | "$JQ" -r '.tool_input.file_path // ""')

# Allow env *templates* (no real secrets) before the .env block below catches them.
case "$FILE" in
  *.env.example|*.env.sample|*.env.template) exit 0 ;;
esac

# Sensitive file patterns -- block Write/Edit
BLOCKED=(
  '\.env$'
  '\.env\.'
  '\.pem$'
  '\.key$'
  '\.p12$'
  '\.pfx$'
  '\.keystore$'
  'id_rsa'
  'id_ed25519'
  'id_ecdsa'
  '\.ssh/config'
  'credentials\.json'
  'service.account\.json'
  'secret'
  '\.aws/credentials'
  '\.aws/config'
  'kubeconfig'
  '\.kube/config'
  '\.npmrc$'
  '\.pypirc$'
  'token\.json$'
  '\.netrc$'
  '\.docker/config\.json'
  '\.git-credentials'
)

for pattern in "${BLOCKED[@]}"; do
  if echo "$FILE" | grep -qiE "$pattern"; then
    echo "BLOCKED by safety hook: sensitive file [$FILE]" >&2
    exit 2
  fi
done

exit 0
