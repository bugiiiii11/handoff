#!/bin/bash
# PreToolUse: Block dangerous Bash / PowerShell command patterns
# Exit 2 = block, Exit 0 = allow
#
# Wire on PreToolUse with matcher "Bash|PowerShell".

# Resolve jq (not on PATH in Git Bash on Windows)
JQ="jq"
if ! command -v jq &>/dev/null; then
  _U="${USER:-$USERNAME}"
  for p in "/c/Users/$_U/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe/jq.exe" \
           "/c/ProgramData/winget/Links/jq.exe" \
           "/c/Users/$_U/scoop/shims/jq.exe" \
           "/usr/bin/jq" "/usr/local/bin/jq"; do
    [ -x "$p" ] && { JQ="$p"; break; }
  done
  # Fail closed: if jq is still not found after the resolver, block rather than silently allow
  if ! command -v "$JQ" &>/dev/null && [ ! -x "$JQ" ]; then
    echo "BLOCKED: jq not found -- hook cannot evaluate safety" >&2
    exit 2
  fi
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | "$JQ" -r '.tool_name')

if [ "$TOOL_NAME" != "Bash" ] && [ "$TOOL_NAME" != "PowerShell" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | "$JQ" -r '.tool_input.command // ""')

# === Dangerous patterns ===
BLOCKED_PATTERNS=(
  'rm -rf /'
  'rm -rf ~'
  'rm -rf \.'
  # flag-reorder / wildcard-root variants of the same catastrophe
  'rm -fr /'
  'rm -fr ~'
  'rm -rf /\*'
  'rm -fr /\*'
  'rm -r -f /'
  'curl.*\|.*bash'
  'curl.*\|.*sh'
  'wget.*\|.*bash'
  'wget.*\|.*sh'
  ':\(\)\{.*\|.*&.*\};'
  'dd if=/dev'
  'mkfs\.'
  '> /dev/sd'
  'chmod -R 777 /'
  'eval.*\$\(curl'
  'git push.*--force.*main'
  'git push.*--force.*master'
  'git push.*-f.*main'
  'git push.*-f.*master'

  # === Sensitive file access via bash (closes the Edit/Write/Read tool bypass) ===
  # protect-files.sh guards the Edit/Write/Read TOOLS; these close the bash-tool
  # bypass (`cat .env`, `echo >> .env`). The `($|[^.a-zA-Z])` suffix guard keeps
  # .env.example/.sample/.template writable -- the unguarded forms false-positive
  # on ordinary commands like `cp x .env.example`.
  '(>|>>)[[:space:]]*[^|]*\.env($|[^.a-zA-Z])'
  '(tee|cp|mv)[^|]*\.env($|[^.a-zA-Z])'
  'sed[^|]*-i[^|]*\.env($|[^.a-zA-Z])'
  '(cat|head|tail|less|more)[^|]*\.env($|[^.a-zA-Z])'
  # SSH / cloud / credential file reads via bash
  '(cat|head|tail|less|more)[^|]*(\.ssh/|id_rsa|id_ed25519|id_ecdsa|\.aws/credentials|\.aws/config|\.git-credentials|\.netrc|\.npmrc|\.pypirc|\.kube/config|\.gnupg/|\.ethereum/|\.bitcoin/)'

  # === Data-exfiltration uploads -- GET fetches stay allowed ===
  # Blocks curl/wget UPLOADS (POST/PUT/data/form/upload), not GETs. Verb, not host.
  'curl[^|]*-X[[:space:]]*(POST|PUT|PATCH|DELETE)'
  'curl[^|]*(--data|-d[[:space:]]|--data-binary|--data-raw|--form|-F[[:space:]]|--upload-file|-T[[:space:]])'
  'wget[^|]*(--post-data|--post-file|--method[[:space:]]*(POST|PUT))'
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED by safety hook: dangerous pattern [$pattern]" >&2
    exit 2
  fi
done

# === PowerShell-specific catastrophe patterns (case-insensitive) ===
# PowerShell sidesteps bash syntax, so the bash patterns above never bite a PS command
# (except the shell-agnostic git ones). Mirror the catastrophe set in PS terms.
# Scoped to genuine catastrophes only -- an ordinary subdir delete is intentionally NOT blocked.
if [ "$TOOL_NAME" = "PowerShell" ]; then
  if echo "$COMMAND" | grep -qiE 'remove-item|\bri\b|\brmdir\b|\brd\b|\bdel\b|\berase\b' \
     && echo "$COMMAND" | grep -qiE '\-recurse\b|/s\b' \
     && echo "$COMMAND" | grep -qiE '\-force\b|/q\b' \
     && echo "$COMMAND" | grep -qiE '([A-Za-z]:\\([[:space:]]|$|["'"'"']|\*)|[A-Za-z]:\\Windows|\$HOME\b|\$env:windir|\$env:SystemRoot|\$env:USERPROFILE|[[:space:]]/[[:space:]]|~[\\/])'; then
    echo "BLOCKED by safety hook: recursive force-delete of a root/system/home path (PowerShell)" >&2
    exit 2
  fi

  PS_BLOCKED_PATTERNS=(
    'Format-Volume'
    'Clear-Disk'
    'Initialize-Disk'
    'Format-.*-FileSystem'
    '(iwr|irm|Invoke-WebRequest|Invoke-RestMethod|DownloadString|DownloadFile)[^|]*\|[^|]*(iex|Invoke-Expression)'
    '(iex|Invoke-Expression)[^;]*(DownloadString|DownloadFile|Invoke-WebRequest|Invoke-RestMethod|\biwr\b|\birm\b)'
  )
  for pattern in "${PS_BLOCKED_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
      echo "BLOCKED by safety hook: dangerous PowerShell pattern [$pattern]" >&2
      exit 2
    fi
  done
fi

exit 0
