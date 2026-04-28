# Handoff

**Session-management skills for Claude Code.** Four slash commands that handle the session lifecycle so you don't lose context between runs.

`/start` &nbsp;·&nbsp; `/wrap` &nbsp;·&nbsp; `/save` &nbsp;·&nbsp; `/doc-update`

---

## The problem

Claude Code sessions are stateless. Every time you resume a project, the model starts cold. The usual symptoms:

- You re-explain what you were doing for the third time this week.
- Uncommitted work piles up across multiple repos because nobody's checking.
- `handoff.md` drifts out of sync with the actual state of the code.
- Context fills up mid-session and compaction wipes the thread you were holding.

Handoff is a small, opinionated workflow that fixes this. Two files (`handoff.md` + `decisions.md`) hold the project's state. Four skills keep them honest.

---

## The skills

| Skill | When to run | What it does |
|-------|-------------|--------------|
| **/start** | First message of a session | Reads `handoff.md`, checks repo status across all detected repos, surfaces any emergency snapshot from the previous session, presents a session briefing. |
| **/wrap** | Mid-session, after a chunk of work, or at session end | Detects dirty repos, asks before committing/pushing, prompts to update `handoff.md`, logs decisions to `decisions.md`. Idempotent — safe to call repeatedly. |
| **/save** | When context is running low (~80%) | Emergency dump to `emergency-snapshot.md` before compaction hits. Fast, no questions asked. `/start` consumes it on resume. |
| **/doc-update** | Called by `/wrap`, or manually | Updates `handoff.md` (new session section, "What To Do Next", session table) and `decisions.md`. Only touches files that actually changed. |

All four skills auto-detect your repo shape:

- **Single repo** — cwd is a git repo.
- **Monorepo** — same as single, with workspace-aware tooling layered on top.
- **Multi-repo** — cwd contains multiple repos one level deep (e.g., `frontend/`, `backend/`, `mobile/`).

Pushes go to the tracked upstream (`@{u}`). No hardcoded remote names. If a repo has no upstream, the skill asks — it never guesses.

---

## Required files

These two files live in your project root. Both are required defaults — the skills assume they exist and offer to create them from templates if missing.

- **`handoff.md`** — session memory: what was done, what to do next, key files. Templates: [examples/handoff-template.md](examples/handoff-template.md).
- **`decisions.md`** — append-only decision log with reasoning and alternatives. Template: [examples/decisions-template.md](examples/decisions-template.md).

---

## Install

Drop the four skills into your project's local Claude Code skill directory:

```bash
git clone https://github.com/bugiiiii11/handoff.git /tmp/handoff

# Per-project install (recommended)
mkdir -p .claude/skills
cp -r /tmp/handoff/skills/* .claude/skills/
```

Or install globally — `cp -r /tmp/handoff/skills/* ~/.claude/skills/` — to make them available across every project.

Then seed the required files:

```bash
cp /tmp/handoff/examples/handoff-template.md  ./handoff.md
cp /tmp/handoff/examples/decisions-template.md ./decisions.md
```

Restart Claude Code and the four skills will be available as slash commands.

---

## Quick start

A typical day:

```
/start                    # session briefing — what was last touched, what's next
... do work ...
/wrap                     # commit, push, update handoff
... more work, context filling up ...
/save                     # fire-exit snapshot before compaction
... compaction or new session ...
/start                    # picks up the snapshot, deletes it, briefs you
```

`/wrap` is the workhorse. Run it whenever you finish a chunk — it's idempotent, so there's no penalty for calling it often.

---

## Why these four?

Because a session has four moments where state can leak:

1. **Starting** — you don't know where you left off. → `/start`
2. **Stopping** — you know what changed but the docs/git don't. → `/wrap`
3. **Crashing** — context is full and compaction is about to nuke the thread. → `/save`
4. **Drifting** — docs are stale because nobody updated them. → `/doc-update`

That's it. No sprint planning, no time tracking, no integrations. Just the boring lifecycle plumbing that turns Claude Code from a session-by-session tool into something that remembers your project across weeks.

---

## What's next: PlanKit

Handoff is the free, open-source slice. The full version — **PlanKit** — adds the parts that need a real backend:

- `/sprint`, `/plan`, `/shutdown` — a Claude Code-native sprint loop.
- Telegram notifications + chat reflection during the day.
- End-of-day Claude summary (with persona system: `warm-coach`, `brutalist`, `playful`, `data-only`).
- WakaTime + token-spend integration for passive dev-time tracking.
- Health windows as scheduling constraints.

PlanKit ships as a module inside the M.D.N Tech client portal.

> **Get notified:** [Watch this repo](https://github.com/bugiiiii11/handoff/subscription) — releases will be announced here when PlanKit opens for early access.

---

## Contributing

- **Bugs / install issues:** open an [Issue](https://github.com/bugiiiii11/handoff/issues).
- **Feature requests / "can it also do X":** open a [Discussion](https://github.com/bugiiiii11/handoff/discussions). These shape the PlanKit roadmap.
- PRs welcome for the four core skills. Keep them generic — anything project-specific belongs in your own fork.

---

## License

MIT. See [LICENSE](LICENSE).
