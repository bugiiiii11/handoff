---
name: save
description: Emergency context save -- dump session state to emergency-snapshot.md before compaction hits
---

Fast emergency save. Use when context is running low (80%+) and you need to preserve what happened this session. No ceremony -- just dump and stop.

## Step 1 -- Detect repo shape (one quick check)

- `git rev-parse --is-inside-work-tree` -- is the cwd itself a git repo?
  - **yes** -> run `git status -sb` in cwd.
  - **no** -> scan one level deep for `.git` subdirs. Run `git -C <subdir> status -sb` for each, in parallel.

If neither, skip git status and note it in the snapshot.

## Step 2 -- Write emergency-snapshot.md

Create `emergency-snapshot.md` in the cwd root with:

```markdown
# Emergency Snapshot -- Session <N>
Date: <today>

## What was done this session
<Bullet list of what was accomplished, decisions made, files changed>

## Uncommitted work
<Per-repo list of modified/new files from git status, or "all clean">

## Key context
<Anything important that would be lost -- root causes found, approaches decided, gotchas discovered>

## Decisions made
<Any key decisions and their reasoning -- these should also go to decisions.md on resume via /wrap>

## Next step when resuming
<What was in progress or about to start>
```

## Rules

- Minimize tool calls: one repo-shape check + git status (parallel) + write the file. That's it.
- Do NOT commit, push, or update handoff.md / decisions.md.
- Do NOT read handoff.md or other files -- use what you already know from the conversation.
- Write fast, move on. This is a fire exit, not a wrap-up.
- If an emergency snapshot already exists, overwrite it (the new one is more current).
- The `/start` skill consumes and deletes this file on next session.
