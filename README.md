# Handoff

**Session management for Claude Code.** One skill, four subcommands that handle the session lifecycle so you don't lose context between runs.

`/handoff start` &nbsp;·&nbsp; `/handoff wrap` &nbsp;·&nbsp; `/handoff save` &nbsp;·&nbsp; `/handoff docs`

> **v3** — the four separate skills (`/start`, `/wrap`, `/save`, `/doc-update`) are now a single `/handoff` skill with subcommands, plus optional auto-wrap hooks that measure **real** context usage from the transcript. Upgrading from v2? See [Migrating from v2](#migrating-from-v2).

---

## The problem

Claude Code sessions are stateless. Every time you resume a project, the model starts cold. The usual symptoms:

- You re-explain what you were doing for the third time this week.
- Uncommitted work piles up because nobody's checking.
- `handoff.md` drifts out of sync with the actual state of the code.
- Context fills up mid-session and compaction wipes the thread you were holding.
- On long-context models, sessions silently cross into premium-priced territory before anyone notices.

Handoff is a small, opinionated workflow that fixes this. One file (`handoff.md`) holds the project's live state, hard-capped so it stays cheap to read. One skill keeps it honest. Two optional hooks tell you — with real numbers — when it's time to wrap.

---

## The four subcommands

| Command | When to run | What it does |
|---------|-------------|--------------|
| **/handoff start** | First message of a session | **Fetches origin first, then reconciles** (see below), surfaces any emergency snapshot from the previous session, presents a ~25-line briefing. Read-only apart from a lossless fast-forward pull. |
| **/handoff wrap** | After a chunk of work, or at session end | Fetches and reconciles, then updates `handoff.md` (docs before commit), rotates overflow to `handoff-archive.md`, commits locally. Never pushes without an explicit request. Idempotent — safe to call repeatedly. |
| **/handoff save** | Fire exit — context is nearly full | Minimal-tool-call dump to `emergency-snapshot.md`. No commit, no questions. `/handoff start` consumes and deletes it next session. |
| **/handoff docs** | Mid-session checkpoint — or when the 20% hook nudges | Runs the wrap's documentation update + rotation steps only. No commit, and the session continues. |

### Sharing a repo with a teammate

`handoff.md` is the tasklist, so a briefing built from a stale copy is worse than no briefing — it hands you a confident summary of work someone else already finished. Both `start` and `wrap` therefore establish repo state **before** they trust the file:

| Situation | What happens |
|---|---|
| Local is behind, nothing local to lose | `git pull --ff-only`, then brief from the pulled `handoff.md` |
| Diverged, or behind with a dirty tree | No pull. Brief from origin's copy (`git show @{u}:handoff.md`) and flag it — you reconcile, not the model |
| Up to date, or no remote at all | Read `handoff.md` normally |

The rule is detect-and-reconcile, never silently overwrite: the model will fast-forward when that is lossless and stop and tell you when it is not.

### The files

- **`handoff.md`** — live session state: current phase, what was done (last 2 sessions), what to do next, key files. **Hard-capped at ~120 lines** so `/handoff start` costs ~6k tokens, not 80k. Created from a built-in template on first wrap, or seed it from [examples/handoff-template.md](examples/handoff-template.md).
- **`handoff-archive.md`** — overflow, rotated automatically by wrap, newest first. Never read on start; consult it mid-session only when you actually need history.
- **`emergency-snapshot.md`** — transient; written by `/handoff save`, consumed by the next `/handoff start`.
- **`decisions.md`** — optional append-only decision log if you want one ([template](examples/decisions-template.md)).

### Token discipline (the point of this design)

- `start` reads ONLY `handoff.md` (plus a snapshot if one exists) — never the archive, never preemptive history.
- `handoff.md` records only what git CANNOT tell a future session: decisions, rejected approaches and why, gotchas, open questions. It never re-lists changed files or restates commit messages.
- The cap + rotation keep the standing per-session read small forever.

---

## Install

```bash
git clone https://github.com/bugiiiii11/handoff.git
mkdir -p ~/.claude/skills
cp -r handoff/skills/* ~/.claude/skills/
```

Windows (PowerShell):

```powershell
git clone https://github.com/bugiiiii11/handoff.git
New-Item -ItemType Directory -Force -Path "$HOME\.claude\skills" | Out-Null
Copy-Item -Recurse -Force handoff\skills\* "$HOME\.claude\skills\"
```

That installs globally (every project). For a per-project install, copy into the project's `.claude/skills/` instead. Restart Claude Code, then type `/handoff start` to verify.

Uninstall: `rm -rf ~/.claude/skills/handoff` (PowerShell: `Remove-Item -Recurse -Force "$HOME\.claude\skills\handoff"`).

---

## Optional: auto-wrap hooks

The skill tells Claude *how* to wrap; the hooks tell it *when*. Two small bash scripts read the **real context size** from the session transcript (the last assistant message's `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` — the exact prompt size of the latest API call) and nudge a wrap at two thresholds:

- **Soft (default 20%** of the window) — *checkpoint*: "run `/handoff docs` and keep working." State is persisted, the session does not end.
- **Hard (default 22%)** — *wrap*: "stop new work and wrap NOW."

The two rungs deliberately ask for different things. When soft also ended the session, every nudge that landed mid-task forced a choice between abandoning the work and ignoring the hook — and the hook lost. Splitting persistence (soft) from ending (hard) makes the soft rung cheap enough to always obey.

Why those numbers: not cost. Current 1M-context models (Opus 5 / 4.8 / 4.7, Sonnet 5) bill the full window at a flat rate, with no long-context premium — an earlier version of this file claimed otherwise, which was a leftover from the Sonnet 4.x 1M beta. The real constraint is **answer quality**, which degrades long before the window is full. Both thresholds are env-tunable (`AUTOWRAP_WINDOW`, `AUTOWRAP_SOFT_PCT`, `AUTOWRAP_HARD_PCT`).

- [`hooks/auto-wrap.sh`](hooks/auto-wrap.sh) — **Stop** event. Escalates once at soft and once at hard (per-session marker files), reports the real percentage, and never blocks twice.
- [`hooks/context-warn.sh`](hooks/context-warn.sh) — **UserPromptSubmit** event. Injects a one-line advisory *before* new work starts, catching the case where a single long turn crossed the threshold.

### Wiring

Requires `jq` and bash (Git Bash on Windows works). Copy the scripts into your project and register both hooks in `.claude/settings.json` (or `settings.local.json`):

```bash
mkdir -p .claude/hooks
cp handoff/hooks/*.sh .claude/hooks/
```

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/auto-wrap.sh\"",
            "timeout": 10
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/context-warn.sh\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Hooks load at session start — **restart Claude Code to activate**.

Tune via environment variables: `AUTOWRAP_WINDOW` (default `1000000`), `AUTOWRAP_SOFT_PCT` (default `20`), `AUTOWRAP_HARD_PCT` (default `22`). On a 200k-window model, set `AUTOWRAP_WINDOW=200000` and pick higher percentages (e.g. soft 60 / hard 75).

Verify the scripts on your machine with the bundled smoke tests (17 checks, synthetic transcripts):

```bash
bash handoff/hooks/test-hooks.sh
```

---

## Quick start

A typical day:

```
/handoff start            # briefing — what was last touched, what's next
... do work ...
/handoff wrap             # update handoff.md, rotate overflow, commit locally
... more work, context filling up, hook nudges a checkpoint at 20% ...
/handoff docs             # persist state, keep working — no commit, session continues
... hook nudges the full wrap at 22% ...
/handoff wrap             # wrap again — idempotent, updates the session section in place
... context critical ...
/handoff save             # fire-exit snapshot
... new session ...
/handoff start            # picks up the snapshot, deletes it, briefs you
```

`wrap` is the workhorse. It commits locally without asking and **never pushes** unless you explicitly say so.

---

## Migrating from v2

The old layout was four separate skills. Remove them, then install v3:

```bash
rm -rf ~/.claude/skills/{start,wrap,save,doc-update}
cp -r handoff/skills/* ~/.claude/skills/
```

Command mapping: `/start` → `/handoff start` · `/wrap` → `/handoff wrap` · `/save` → `/handoff save` · `/doc-update` → `/handoff docs`.

Your existing `handoff.md` keeps working. If it has grown large, the first `/handoff wrap` rotates history into `handoff-archive.md` and trims the live file to the cap. v3 drops the v2 multi-repo detection — the skill assumes the current project root is one git repo (run it per-repo otherwise).

---

## Bonus skill: build-kb

The install also ships [`skills/build-kb/`](skills/build-kb/SKILL.md) — a one-shot `/build-kb` command that scans your repo's user-facing content (README, marketing pages, docs, pricing) and generates a chatbot-ready `knowledge-base.md`, organized into fixed categories, never inventing content. Useful for seeding any website chatbot; built for [ChatKit](https://www.mdntech.org).

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
- PRs welcome for the skill and hooks. Keep them generic — anything project-specific belongs in your own fork (or your project's `CLAUDE.md` "Handoff extras").

---

## License

MIT. See [LICENSE](LICENSE).
