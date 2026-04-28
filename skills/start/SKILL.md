---
name: start
description: Session initialization -- read handoff, check repo state, surface emergency snapshot, present briefing
---

Initialize the session by reading project state and presenting a clear starting point.

## Step 1 -- Detect repo shape

- `git rev-parse --is-inside-work-tree` -- is the cwd itself a git repo?
  - **yes** -> single-repo or monorepo. Use `git <cmd>`.
  - **no** -> multi-repo. Scan one level deep for subdirectories containing a `.git` folder. Each match is a repo. Use `git -C <subdir> <cmd>` per repo.

If neither shape is found, note it in the briefing and skip git checks.

## Step 2 -- Read project context (do all in parallel)

Read these files (both are required defaults for any project using this skill suite):
- `handoff.md` (cwd root) -- session history + "What To Do Next"
- `decisions.md` (cwd root) -- decision log (read only the most recent 1-2 entries to keep context lean)

If `handoff.md` is missing, flag it in the briefing and offer to create it from the `/wrap` template before doing anything else.

Note: CLAUDE.md is auto-loaded every message -- do NOT read it again.

For each detected repo, run in parallel:
- `git [-C <repo>] status -sb` -- branch, tracking, uncommitted changes
- `git [-C <repo>] log --oneline -3` -- recent commits
- `git [-C <repo>] rev-list @{u}..HEAD --count 2>/dev/null` -- unpushed commits vs. tracked upstream

Check for emergency snapshot:
- `emergency-snapshot.md` (cwd root)
- If it exists, read it and include its contents in the briefing under "Emergency Recovery"
- After presenting the briefing, delete the snapshot file (it's been consumed)

## Step 3 -- Present session briefing

Show a concise briefing:

```
## Session Briefing

**Last session:** <N> -- <title from handoff> (<date>)
**Days since last session:** <N>

### Repo Status
| Repo | Branch | Status | Unpushed | Last commit |
|------|--------|--------|----------|-------------|
| <name or "."> | <branch> | <clean / N modified> | <count> | <hash + subject> |

### What To Do Next
<Copy the "What To Do Next" table from handoff.md>
<Flag any items that appear already done based on git log>

### Emergency Recovery (only if snapshot existed)
<Summary of what was in progress from the snapshot>

### Heads Up
<Any uncommitted work, unpushed commits, stale handoff items, or missing required files (handoff.md / decisions.md)>
<If nothing, say "All clear.">
```

## Rules

- Do NOT make any changes (except deleting a consumed emergency snapshot).
- Keep the briefing short and scannable.
- Flag stale or missing items honestly.
- Always include session date for tracking frequency.
