---
name: polish
description: Best-wins polish plan for any game, feature or whole project -- "/polish scan <target> [lenses]" (token-budgeted audit: every finding ID'd, code-cited, sized, ranked, pickable; nothing shipped), "/polish plan <picks>" (apply the human's picks/unpicks, pack 3-5 sprints), "/polish run <sprint|IDs>" (ship ONE sprint on dev + record + a human verification checklist), "/polish page" (pick sheet artifact), "/polish status"
---

# Polish -- best-wins improvement plan for any surface (v1)

One skill, five subcommands. Detect the mode from the first argument: `scan`, `plan`, `run`, `page`,
`status`; the rest of the line is the target / lenses / picks. No argument -> one usage line listing
the five modes and stop.

Distilled from a real polish run on a live game: one audit of 31 items, then seven sprints,
each verified by the owner on a real device before the next one started. The method in one line:
**audit first and ship nothing; every finding gets an ID, a code citation, a size, a risk, a token cost
and a value; the human picks; one sprint per session with a way to MEASURE the result; the verdict is
the human's, never ours.**

## CONFIG (all modes)

- Output language English. No emojis in docs. Effort is relative size (XS/S/M/L), never hours.
- Files: audit `<AUDIT_DIR>/<target>-polish-audit.md`, record `<RECORD_DIR>/<target>-polish.md`,
  optional pick sheet `<AUDIT_DIR>/<target>-pick-sheet.html`. Default for both dirs = `docs/polish/`
  inside the repo that owns the surface. A project overlay (bottom of this file) may move them.
- `scan` and `plan` never change product code. `run` ships to the dev/working branch only; promotion
  to production is a human decision made outside this skill.
- 3-5 sprints total, each sized for ONE session (points rule below). Overflow goes to a "Later" pool,
  never to a sprint 6.
- Token spend is a first-class output: the audit records what was read and what was NOT, so a later
  session extends the scan instead of repeating it.
- The human verifies between sprints. Never start sprint N+1 in the session that shipped sprint N
  unless told to.

## Scoring (every finding carries all six)

| Column | Scale | Meaning |
|--------|-------|---------|
| Value | 1-5 | Player-visible impact x breadth. 5 = every player, every session (a lag root cause, an unreadable HUD); 3 = one mode / stage / screen; 1 = cosmetic or rare. Code health alone is 1 unless it was asked for. |
| Effort | XS / S / M / L | XS = one edit (0.5 pt), S = one sitting (1 pt), M = a few sittings (3 pt), L = a sprint on its own (6 pt). |
| Risk | L / M / H | L = render / DOM / copy / config in one file. M = shared component, state, or anything mobile-visible (needs the device matrix). H = touches determinism, anti-cheat, a byte-compared payload, a contract, a migration, shared balance data -- or needs a build the assistant cannot run (Unity, native). |
| Cost | L / M / H | Tokens for the executing session. L = at most 2 files, no harness. M = several files or a headless verification. H = large files (over 800 LOC) edited in many places, a new harness, or expected visual iteration. |
| Visible | desktop / mobile / both / invisible | Where the change shows. "mobile" and "both" pull the device test matrix in. |
| Deps | IDs | Must land first (e.g. "A2-3 needs A2-1"). |

- **Win score = Value / Effort points**; ties break toward lower Risk. Rows are listed by area, the
  suggested order is by win score.
- **Recommended set** = Value >= 3 AND Risk not H AND Cost not H, plus any Value-5 item that is H
  (flagged `H -- owner decides`). Everything else stays listed and pickable; nothing is hidden.
- **Design picks** = anything that changes look, layout or flow in a way the owner would want to see
  first (full-bleed layout, a new HUD arrangement, new art). Listed in their own block and never
  slipped into the recommended set.
- **Unpick by default**: a Risk-H or Cost-H item is only in a sprint if the human ticked it.

## Sprint packing (the points rule)

- At most 6 points per sprint (e.g. 4 XS + 4 S, or 1 M + 3 S). Sum the picked items, split in order.
- **Sprint 1 = the measuring instrument + the zero-design-risk wins** (XS/S, Risk L, Value >= 3). If
  nothing measures the surface yet, the instrument IS item 1 (a `?perf=1` readout, a counter, a log
  line) -- without it the verdict is an opinion.
- Sprint 2 = feel / smoothness / the M items with the best win score.
- Sprint 3+ = UX / HUD / screens and the ticked design picks, mobile-visible items last (matrix).
- Every sprint ends with a human checklist: what to open, what to look for, on which device.

## Mode: scan

Token-budgeted. The goal is the right 8 files, not all 40.

0. **Asks first.** If the request names lenses, proceed. Lenses: performance, graphics / feel, HUD /
   UX, screens / flow (loading, result, empty states, exits), mobile, audio, backend / API contract,
   content / balance (needs a spec to compare against). If no lens is named, ask ONCE with a
   multi-select -- a scan with no lens spends tokens on what nobody asked for. Capture any evidence
   given (screenshot, device, "it lags on X") verbatim in the audit header. Identify the **hard
   constraint** (byte-compared state, anti-cheat payload, signed scores, a build the assistant cannot
   run, a contract). If none is stated, one grep: `serialize|hmac|signature|replay|checksum|encrypt`.
1. **Inventory (one call, bounded output):**
   `bash ~/.claude/skills/polish/scripts/inventory.sh [--domain web|unity|backend] [--exclude 'Vendor|Store'] <path>... > <scratchpad>/inventory.txt`
   then read it. It prints LOC by extension, the biggest files, entry-point guesses, smell hits per
   pattern with the top files, tests / docs presence, and a READ CANDIDATES list. This replaces
   opening files to find the hot ones. Vendored / editor / demo folders are skipped by default; if
   a store asset still shows up in the candidates, re-run once with `--exclude` rather than reading
   it. A mixed surface (Unity game + React wrapper + backend route) = one run per domain, three
   short outputs. Pattern meanings and usual fixes: `references/smells.md` (read the section for
   the detected domain only).
2. **Budget tier from total LOC:** up to 5k -> read the entry points + top 6 candidates fully.
   5-20k -> entry points + the hot loop(s) fully, the other candidates by `sed -n` ranges around the
   smell hits (grep -n first, then read about 40 lines either side). Over 20k -> one Explore agent
   (medium) for the map, then at most 12 targeted reads. Never read assets, generated data,
   vendored / plugin code, `.meta`, tests (grep them only). Read at most ONE project doc for the
   surface -- CLAUDE.md is already loaded.
3. **Hot paths first, in this order:** the frame / tick loop, the state -> UI sync, the loading path,
   the input path, the result / exit path. Note `file:line` for every finding AS YOU READ; never
   re-open a file to cite it.
4. **Cross-check against a sibling that does it right** (the OD audit cited the MW renderer's
   `antialias:false` + `powerPreference`). One grep across the repo, not a second scan.
5. **Rule things out on paper.** Write the "Not the cause / checked and fine" paragraph -- what was
   examined and found OK, with the number that proves it. It stops the next session re-checking.
6. **Baseline** (perf lens only): one headless run if a harness already exists; otherwise the
   instrument is item 1 and the baseline is measured in sprint 1.
7. **Write the audit** from `templates/audit.md` in ONE write. Then report at most 15 lines: the root
   causes (if any), item counts per area, the recommended sprint 1, and the pick question. **STOP** --
   no code, no plan file, no "I went ahead and".

**Budget guard:** past ~15 full-file reads, or three consecutive reads with no new finding, stop
reading and write with what is there; list the rest under "Not examined". Pointing at what is unread
beats a thinner audit that pretends to be complete.

## Mode: plan

Input = the human's picks: `sprint 1`, `all recommended`, a list of IDs, `+ID` / `-ID` deltas, or the
pick sheet's `PICKS: ... | UNPICK: ...` line. Rewrite ONLY the audit's "Plan (picked)" section:
sprints repacked under the points rule with Deps respected, unpicked IDs under "Unpicked (owner)"
with the reason if one was given, Risk-H / Cost-H items included only if explicitly ticked (say so
per item). No code. Report the sprint table (at most 10 lines) and stop.

## Mode: run

`/polish run <sprint number | IDs>` -- ship one sprint, on the dev / working branch.

1. Read ONLY: the audit's constraint line + status table + "Plan (picked)" section, the rows being
   executed (grep by ID), and the record doc's last sprint section if the file exists. Not the whole
   audit -- the citations are in the rows.
2. Implement in the order given. Re-derive nothing: the row says where and what; if the code moved,
   fix the citation in the row. One commit per sprint (one per item when an item is Risk M or H),
   message `feat(<target>): polish sprint N -- <IDs>` in the project's commit style.
3. **Respect the constraint line literally** (e.g. render-only: nothing in `sim/*`, no new field in
   the byte-compared state). If an item cannot be done without crossing it, stop that item, mark it
   `blocked: <why>` in the record, continue with the rest.
4. Verify: the project's tests / lint / build; for a web surface a headless smoke (page loads, zero
   console errors, the new thing is present -- use the webapp-testing skill); for a build the
   assistant cannot run (Unity, native) the item ends as `code done, unverified` with the exact build
   step and what to look for after it. Record tooling gotchas hit (ports, timeouts, flags) -- they
   are the next session's cheapest win.
5. Record: append the sprint section from `templates/record.md` (What changed by ID / Verified,
   automated / Checks that need a real device -- the human checklist / Tooling gotchas / Not in this
   sprint). Add ONE row to the audit's status table. Never rewrite earlier sections.
6. Push per project policy. Report at most 12 lines ending with the human checklist. Stop.

## Mode: page

Copy `templates/pick-sheet.html` to `<AUDIT_DIR>/<target>-pick-sheet.html`, fill `META`, `SPRINTS`
and `ITEMS` from the audit tables (data only -- do not restyle), publish it as an Artifact when the
tool is available. Recommended items arrive pre-ticked; the sheet's "Copy picks" box yields the
`PICKS: ... | UNPICK: ...` line that `plan` consumes.

## Mode: status

Read the audit's status table + "Plan (picked)" section only. Print: sprints shipped / human-verified
/ next / blocked items, at most 10 lines.

## Audit doc rules (what the OD audit taught)

- Header: target, scope paths, the lenses asked, the evidence given, **the constraint line**, the
  status table (`Sprint | Session | Items | Automated | Human verdict`), and the token note ("read
  fully: ..., by range: ..., not examined: ...").
- **Root causes first** when there is a complaint (lag, "feels bad"): each with the evidence chain,
  code-cited, and the fix. Then one paragraph "Not the cause / checked and fine".
- Per-area tables, columns `ID | Finding | Where | Fix | Value | Effort | Risk | Cost | Visible | Deps`.
  IDs: letter per area (A performance, B HUD / UX, C screens / flow, D feel / graphics, E audio,
  F backend / API, G content / balance, H code health) + number; sub-variants `A1(a)` / `A1(b)`.
  Every Where is `file:line` (or `file:line-line`). No finding without a fix.
- "Suggested order" = the sprints with their points; "Design picks"; "Test matrix" (devices, tiers,
  wrappers the surface must be checked on); "Do not" (the traps found while reading, with the reason);
  "Later" (listed, unranked).
- Keep it one file, about 150 lines at most. Depth goes into the rows, not into prose.

## Record doc rules

One file per target, sprint sections appended in order, each: What changed (by ID, with the new
file:line), Verified -- automated (commands + results), Checks that need a real device (the human
checklist), Tooling gotchas, Not in this sprint (remaining picks). A cumulative "Do not" section at
the bottom. Keep the measuring guide (how to read the instrument) in its own section near the top.
