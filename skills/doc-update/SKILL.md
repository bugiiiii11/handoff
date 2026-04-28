---
name: doc-update
description: Update project documentation (handoff.md, decisions.md, other docs) based on this session's work
---

Check whether documentation needs updating based on this session's work, then update only what's actually missing or stale.

## Step 1 -- Smart assessment (minimize reads)

Before reading any files, think about what actually changed this session:
- Did we do ANY work? -> always check `handoff.md`
- Did we make strategic decisions? -> check if `decisions.md` needs an entry
- Did we create new files or features? -> check relevant project-specific docs
- Otherwise -> skip ("no changes in that area")

Only read files that might need updating. Skip the rest.

`handoff.md` and `decisions.md` are required defaults. If either is missing, flag it and offer to create it from the templates in `/wrap` before continuing.

Then report a brief assessment:

```
Documentation check:
- handoff.md: <needs update / up to date / missing>
- decisions.md: <N decisions to log / up to date / missing>
- Other docs: <status or "skipped -- no relevant changes">

Proceed with updates? (N files need changes)
```

If everything is already up to date, say so clearly and stop.

## Step 2 -- Update only what needs it

### handoff.md (always check)

Add a new session section BEFORE "What To Do Next":

```markdown
## What Was Done (Session N) -- <short title>
Date: YYYY-MM-DD

1. **<What was built or changed>** -- <concise description>. Files: <list>. Committed: <hash if applicable>.
```

Then update:
- "What To Do Next" table to reflect current priorities
- "Key Files" table if new files were added
- Session Summary table (add row for this session with date)

**Trimming:** If handoff has more than ~3 detailed session sections, condense the oldest into a single line in the Session Summary table or move it to `handoff-archive.md`.

### decisions.md (if decisions were flagged)

Append decision entries at the top (newest first):

```markdown
### YYYY-MM-DD -- Session N
**Decision:** What was decided
**Why:** Brief reasoning
**Alternatives:** What else was considered
```

### Project-specific docs

- Only update docs that were affected by this session's work.
- Create new docs only if a significant new feature was added.

## Style rules

- No emojis in docs.
- Tables for structured data.
- Concise summaries in handoff -- don't paste code.
- Always include date on session entries.
- If nothing needs updating, say so and stop.
