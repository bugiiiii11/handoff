#!/usr/bin/env bash
# polish inventory -- a bounded map of a code surface so the scan reads the right 8 files, not all 40.
#
# usage: inventory.sh [--domain web|unity|backend|auto] [--top N] [--exclude 'RegexA|RegexB'] <path> [<path>...]
#   --exclude adds directory names (ERE) to the default skip list (vendored / editor / demo folders).
#
# Prints (about 80-120 lines, never more than the file count allows):
#   1. files + LOC by extension            4. smell hits per pattern (top files)
#   2. biggest files                       5. tests / docs presence
#   3. entry-point guesses                 6. READ CANDIDATES (LOC x smell density)
# Uses ripgrep when it can find one (PATH, $RG, or Claude Code's bundled binary); otherwise
# falls back to find + grep, so it runs on any machine. Paths print with forward slashes.
set -u
DOMAIN=auto; TOP=12; PATHS=(); EXTRA_EXCL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --domain) DOMAIN=$2; shift 2;;
    --top) TOP=$2; shift 2;;
    --exclude) EXTRA_EXCL=$2; shift 2;;
    -h|--help) sed -n '2,12p' "$0"; exit 0;;
    *) PATHS+=("$1"); shift;;
  esac
done
[ ${#PATHS[@]} -eq 0 ] && { echo "usage: inventory.sh [--domain web|unity|backend|auto] [--top N] <path>..." >&2; exit 1; }

# --- search backend ----------------------------------------------------------
RG_CMD=()
if [ -n "${RG:-}" ] && [ -x "$RG" ]; then RG_CMD=("$RG")
elif command -v rg >/dev/null 2>&1; then RG_CMD=(rg)
elif [ -n "${CLAUDE_CODE_EXECPATH:-}" ] && [ -x "$CLAUDE_CODE_EXECPATH" ]; then RG_CMD=(env ARGV0=rg "$CLAUDE_CODE_EXECPATH")
elif [ -x "$HOME/.local/bin/claude.exe" ]; then RG_CMD=(env ARGV0=rg "$HOME/.local/bin/claude.exe")
elif [ -x "$HOME/.local/bin/claude" ]; then RG_CMD=(env ARGV0=rg "$HOME/.local/bin/claude")
fi
if [ ${#RG_CMD[@]} -gt 0 ] && ! "${RG_CMD[@]}" --version >/dev/null 2>&1; then RG_CMD=(); fi
BACKEND=$([ ${#RG_CMD[@]} -gt 0 ] && echo ripgrep || echo "find+grep")

list_files() {            # every file under the paths, forward slashes
  if [ ${#RG_CMD[@]} -gt 0 ]; then "${RG_CMD[@]}" --files --no-messages "${PATHS[@]}" 2>/dev/null
  else find "${PATHS[@]}" -type f 2>/dev/null; fi | tr '\\' '/'
}
count_hits() {            # $1 = ERE; prints path:count for files with >0 hits
  if [ ${#RG_CMD[@]} -gt 0 ]; then "${RG_CMD[@]}" -c --no-messages -e "$1" "${PATHS[@]}" 2>/dev/null
  else grep -rIEc -e "$1" "${PATHS[@]}" 2>/dev/null | grep -Ev ':0$'; fi | tr '\\' '/'
}

EXCL_DIRS='node_modules|dist|build|\.git|Library|Temp|obj|Logs|__pycache__|\.venv|venv|coverage|vendor|third_party|ThirdParty|Plugins|StreamingAssets|Packages|ProjectSettings|Editor|EXTERNAL|External|Demo|Demos|Examples|Samples|Gizmos|TextMesh Pro|Standard Assets'
[ -n "$EXTRA_EXCL" ] && EXCL_DIRS="$EXCL_DIRS|$EXTRA_EXCL"
SRC_EXT='js|jsx|ts|tsx|css|scss|cs|shader|jslib|py|sql|html|vue|svelte'
TMP=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/polish-inv-$$"); mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# --- file list -------------------------------------------------------------
list_files \
  | grep -Ev "(^|/)($EXCL_DIRS)/" \
  | grep -Ev '\.(min|bundle|test|spec|stories)\.[a-z]+$' \
  | grep -E "\.($SRC_EXT)$" > "$TMP/files"
NFILES=$(wc -l < "$TMP/files")
[ "$NFILES" -eq 0 ] && { echo "no source files under: ${PATHS[*]}"; exit 0; }

# LOC per file (path<TAB>loc)
while IFS= read -r f; do
  [ -f "$f" ] && printf '%s\t%s\n' "$f" "$(wc -l < "$f")"
done < "$TMP/files" > "$TMP/loc"
TOTAL=$(awk -F'\t' '{s+=$2} END{print s+0}' "$TMP/loc")

echo "== polish inventory ($BACKEND) =="
echo "paths: ${PATHS[*]}"
echo "files: $NFILES   total LOC: $TOTAL"
echo
echo "== 1. LOC by extension =="
awk -F'\t' '{n=split($1,a,"."); e=a[n]; c[e]++; l[e]+=$2} END{for(e in c) printf "  %-7s %5d files %8d LOC\n", e, c[e], l[e]}' "$TMP/loc" | sort -k4 -nr

# --- domain ---------------------------------------------------------------
if [ "$DOMAIN" = auto ]; then
  DOMAIN=$(awk -F'\t' '{n=split($1,a,"."); e=a[n]; l[e]+=$2} END{
    w=l["js"]+l["jsx"]+l["ts"]+l["tsx"]+l["css"]+l["scss"]+l["vue"]+l["svelte"]; u=l["cs"]+l["shader"]+l["jslib"]; b=l["py"]+l["sql"];
    d="web"; m=w; if(u>m){d="unity";m=u} if(b>m){d="backend";m=b} print d}' "$TMP/loc")
fi
echo
echo "domain: $DOMAIN (auto-detected unless --domain was given; mixed surfaces: run once per domain)"

# --- biggest files ----------------------------------------------------------
echo
echo "== 2. biggest files (top $TOP) =="
sort -t$'\t' -k2 -nr "$TMP/loc" | head -n "$TOP" | awk -F'\t' '{printf "  %6d  %s\n", $2, $1}'

# --- entry points -----------------------------------------------------------
echo
echo "== 3. entry-point guesses =="
case "$DOMAIN" in
  web)     EP='(^|/)(index|main|App|[A-Za-z]*Page|[A-Za-z]*Renderer|[A-Za-z]*Loop|[A-Za-z]*Engine|[A-Za-z]*Battlefield|[A-Za-z]*Scene)\.(jsx?|tsx?)$';;
  unity)   EP='(^|/)([A-Za-z]*(GameManager|Manager|Controller|Spawner|Player|Boss|Enemy|UI|HUD|Bridge|Loader|Level))\.cs$';;
  backend) EP='(^|/)(main|app|[a-z_]*routes?|[a-z_]*service|[a-z_]*handler)[a-z_]*\.py$';;
esac
{ grep -E '(^|/)[A-Za-z]*(GameManager|Bootstrap|GameLoop|Main)[A-Za-z]*\.(cs|jsx?|tsx?|py)$' "$TMP/files"; grep -E "$EP" "$TMP/files"; } \
  | awk '!seen[$0]++' | head -n 15 | sed 's/^/  /'
NEP=$(grep -Ec "$EP" "$TMP/files"); [ "$NEP" -gt 15 ] && echo "  ... $NEP matches, first 15 shown"

# --- smell patterns ---------------------------------------------------------
# label|regex  (ERE; works in ripgrep and GNU grep -E). Meanings + usual fixes: ../references/smells.md
case "$DOMAIN" in
web) SMELLS=(
  'rAF loop|requestAnimationFrame\('
  'setInterval|setInterval\('
  'useState|useState\('
  'useEffect|useEffect\('
  'setState-like calls|\bset[A-Z][A-Za-z]*\('
  'backdrop blur|backdrop-(blur|filter)'
  'keyframes anim|@keyframes'
  'antialias on|antialias:\s*true'
  'per-frame allocs|new (PIXI\.)?(Text|Graphics|Sprite|Container)\('
  'destroy calls|\.destroy\('
  'add listener|addEventListener\('
  'remove listener|removeEventListener\('
  'new Audio|new Audio\('
  'JSON.parse|JSON\.parse\('
  'localStorage|localStorage'
  'console.log|console\.(log|warn)\('
  'DPR / resolution|devicePixelRatio|resolution:'
  'three.js|from .(three|@react-three)'
  'lazy routes|lazy\('
  'TODO/FIXME|TODO|FIXME|HACK|XXX'
);;
unity) SMELLS=(
  'Update loops|void (Update|FixedUpdate|LateUpdate)\('
  'GetComponent|GetComponent(s)?(InChildren|InParent)?<'
  'Find calls|FindObjectOfType|FindObjectsOfType|GameObject\.Find|FindWithTag|FindGameObjectsWithTag'
  'Instantiate|Instantiate\('
  'Destroy|Destroy\('
  'Camera.main|Camera\.main'
  'Resources.Load|Resources\.Load'
  'OnGUI|OnGUI\('
  'Debug.Log|Debug\.Log'
  'WaitForSeconds alloc|new WaitForSeconds\('
  'coroutines|StartCoroutine\('
  'SendMessage|SendMessage\('
  'physics queries|Physics2?D?\.(Raycast|Overlap|Sphere|Box|Capsule)'
  'PlayerPrefs|PlayerPrefs\.'
  'WebGL bridge|DllImport|ExternalCall|ExternalEval|\.jslib'
  'string build|\$"|string\.Format|string\.Concat'
  'frame rate / vsync|targetFrameRate|vSyncCount'
  'TODO/FIXME|TODO|FIXME|HACK|XXX'
);;
backend) SMELLS=(
  'route decorators|@(router|app|[a-z_]+_router)\.(get|post|put|delete|patch)\('
  'sync defs|^\s*def '
  'async defs|^\s*async def '
  'blocking io|requests\.(get|post)|urllib|time\.sleep\('
  'blanket except|except( Exception)?( as \w+)?:'
  'SELECT *|SELECT \*'
  'db calls|await [a-z_.]*\.(fetch|fetchrow|fetchval|execute|executemany)\('
  'print|^\s*print\('
  'env reads|os\.getenv\(|os\.environ'
  'caches|TTLCache|lru_cache|_cache'
  'chain calls|Web3\(|_get_working_web3|\.functions\.'
  'json.loads|json\.loads\('
  'TODO/FIXME|TODO|FIXME|HACK|XXX'
);;
esac

echo
echo "== 4. smell hits (pattern | files | hits | top files) =="
ALLPAT=""
for s in "${SMELLS[@]}"; do
  label=${s%%|*}; pat=${s#*|}
  ALLPAT="${ALLPAT:+$ALLPAT|}($pat)"
  count_hits "$pat" | grep -Ev "(^|/)($EXCL_DIRS)/" | grep -E "\.($SRC_EXT):[0-9]+$" > "$TMP/hits" || true
  nf=$(wc -l < "$TMP/hits"); nh=$(awk -F: '{s+=$NF} END{print s+0}' "$TMP/hits")
  [ "$nf" -eq 0 ] && continue
  top=$(sed -E 's/^(.*):([0-9]+)$/\2\t\1/' "$TMP/hits" | sort -nr | head -n 4 \
        | awk -F'\t' '{n=split($2,a,"/"); printf "%s(%d) ", a[n], $1}')
  printf "  %-20s %4d f %6d hits  %s\n" "$label" "$nf" "$nh" "$top"
done

# --- tests / docs -----------------------------------------------------------
echo
echo "== 5. tests / docs near the surface =="
list_files | grep -Ev "(^|/)($EXCL_DIRS)/" | grep -E '(__tests__|/tests?/|/Tests?/|\.(test|spec)\.[a-z]+$|/__test)' > "$TMP/tests"
NT=$(wc -l < "$TMP/tests")
echo "  test files: $NT $(head -n 3 "$TMP/tests" | tr '\n' ' ')"
DOCS=$(list_files | grep -Ev "(^|/)($EXCL_DIRS)/" | grep -Ei '\.md$' | head -n 6 | tr '\n' ' ')
echo "  docs inside scope: ${DOCS:-none}"
for p in "${PATHS[@]}"; do
  base=$(basename "$p" | tr '[:upper:]' '[:lower:]')
  for d in "$p/../docs" "$p/../../docs" "$p/../../../docs"; do
    [ -d "$d" ] && ls "$d" 2>/dev/null | grep -i "${base:0:5}" | head -n 3 | sed "s#^#  sibling docs ($d): #" && break
  done
done

# --- read candidates ---------------------------------------------------------
echo
echo "== 6. READ CANDIDATES (LOC, smell hits, hits per 100 LOC) -- start here =="
count_hits "$ALLPAT" | grep -Ev "(^|/)($EXCL_DIRS)/" | grep -E "\.($SRC_EXT):[0-9]+$" \
  | sed -E 's/:([0-9]+)$/\t\1/' > "$TMP/allhits" || true
awk -F'\t' 'NR==FNR{h[$1]=$2; next} {hits=($1 in h)?h[$1]:0; d=($2>0)?hits*100/$2:0;
  score=$2*0.4 + hits*6 + d*20; printf "%.0f\t%d\t%d\t%.1f\t%s\n", score, $2, hits, d, $1}' "$TMP/allhits" "$TMP/loc" \
  | sort -nr | head -n "$TOP" | awk -F'\t' '{printf "  %6d LOC %5d hits %6.1f/100  %s\n", $2, $3, $4, $5}'
echo
echo "read the entry points + the top candidates fully; the rest by grep -n + sed -n ranges. Meanings: references/smells.md"
