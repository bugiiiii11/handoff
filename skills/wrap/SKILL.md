---
name: wrap
description: Check session state -- auto-detect dirty repos, commit & push if needed, update docs if stale
---

Check the current state of work and wrap up anything that needs it. Safe to call anytime -- mid-session, after a chunk of work, or at session end. If nothing needs doing, say so and stop.

## Step 1 -- Detect repo shape

Run once to figure out what kind of project this is:

- `git rev-parse --is-inside-work-tree` -- is the cwd itself a git repo?
  - **yes** -> single-repo or monorepo. Use `git <cmd>` (no `-C`).
  - **no** -> multi-repo. Scan one level deep for any subdirectory containing a `.git` folder. Each match is a repo. Use `git -C <subdir> <cmd>` per repo.

If neither shape is found, this is a **docs-only project** (planning, research, notes -- no code yet). Continue in docs-only mode: skip the git steps below, but still run handoff/decisions updates and the "What To Do Next" check. Don't stop.

## Step 2 -- Assess current state (do all in parallel)

If git repos were detected, for each one run in parallel (skip in docs-only mode):

- `git [-C <repo>] status -sb` -- uncommitted changes + branch + tracking info
- `git [-C <repo>] diff --stat` -- what changed
- `git [-C <repo>] rev-list @{u}..HEAD --count 2>/dev/null` -- unpushed commits vs. tracked upstream (returns nothing if no upstream is set)
- `git [-C <repo>] rev-parse --abbrev-ref @{u} 2>/dev/null` -- upstream name (e.g., `origin/main`), empty if none

Read in parallel:
- `handoff.md` (cwd root) -- is the current session documented? Is "What To Do Next" accurate?
- `decisions.md` (cwd root) -- exists for later use in Step 4

Both `handoff.md` and `decisions.md` are required defaults for any project using this skill suite. If either is missing, flag it in the Wrap Check report and offer to create it from the templates in Step 5.

## Step 3 -- Report

Present a brief status check:

```
## Wrap Check

### Repo Status
| Repo | Branch | Upstream | Uncommitted | Unpushed | Action needed |
|------|--------|----------|-------------|----------|---------------|
| <name or "."> | <branch> | <upstream or "none"> | <files or "clean"> | <count or 0> | <yes/no> |

**Handoff status:** <up to date / needs session N section / stale / not present>
```

In single-repo mode, the `Repo` column shows `.` (or the cwd folder name). In multi-repo mode, it shows each subdir name. In docs-only mode, replace the Repo Status table with `**Mode:** docs-only (no git repo)` and show only the Handoff status line.

If everything is clean, handoff is current, and there's nothing to push, say "All wrapped. Nothing to do." and stop. In docs-only mode, the bar is just: handoff is current and no decisions to log.

## Step 4 -- Act on each issue

### Code changes (commit & push per repo)

Skip this subsection entirely in docs-only mode (no repos to commit).

- For each repo with uncommitted changes:
  - Show the changed files
  - Ask: "Want me to commit & push <repo>?"
  - If yes, follow standard git commit protocol using `git [-C <repo>]`, then push to the tracked upstream (`git [-C <repo>] push` with no args -- pushes to `@{u}`).
  - Treat commit & push as one action unless the user says otherwise.
- If a repo has no upstream set, ask the user where to push before pushing (don't guess).
- Do NOT auto-commit -- always ask first.
- Handle repos one at a time, or in the order the user prefers.

### Documentation updates
- If `handoff.md` needs updating, invoke `/doc-update`.
- If this was a discussion/analysis session (no code), still update "What To Do Next" if priorities changed.
- If `handoff.md` is missing, offer to create it from the template in Step 5 before continuing.

### Decision check
Ask once at end of wrap:

> Any key decisions this session worth logging? (skip if none)

If yes, append to `decisions.md` in the project root. Keep entries concise:

```markdown
### YYYY-MM-DD -- Session N
**Decision:** What was decided
**Why:** Brief reasoning
**Alternatives:** What else was considered
```

If `decisions.md` is missing, create it from the template in Step 5 first.

### "What To Do Next" check
- Compare "What To Do Next" against what was done this session
- Flag completed items and suggest new ones
- Ask the user before making changes

## Step 5 -- Templates (used when handoff.md or decisions.md is missing)

### handoff.md template

```markdown
# <Project Name> -- Handoff

**Project:** <name>
**Started:** YYYY-MM-DD
**Stage:** <one-line current state>

---

## Current State

<one paragraph: what exists, what doesn't>

---

## What To Do Next

| # | Task | Notes | Status |
|---|------|-------|--------|
| 1 |      |       | Pending |

---

## Key Files

| File | Purpose |
|------|---------|
| handoff.md | This file -- session memory |
| decisions.md | Decision log |

---

## Session Summary

| Session | Date | Focus | Output |
|---------|------|-------|--------|
| 1 | YYYY-MM-DD |  |  |
```

### decisions.md template

```markdown
# <Project Name> -- Decision Log

Append entries below. Newest at top.

---
```

## Rules

- Always ask before committing, pushing, or modifying docs.
- If everything is clean and up to date, just say "All wrapped. Nothing to do." and stop.
- Keep it brief.
- This skill can be called multiple times safely (idempotent).
- Push to the tracked upstream -- never guess a remote/branch combination. If no upstream, ask.
- All git commands run in parallel where possible.
