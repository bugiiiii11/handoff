# <Target> -- polish audit (S<N>, <YYYY-MM-DD>)

Scope: <paths read, one line>. Lenses asked: <performance / graphics / HUD / screens / mobile / ...>.
Evidence given: <"lags on a member's notebook", screenshots 1-3, device>. Everything here is a
RECOMMENDATION with an ID; the owner picks, then one sprint per session.

**Constraint (copied into every sprint):** <e.g. the sim is byte-replayed on the backend and the final
state compared as a STRING (`file:line`); nothing below touches `sim/*` or `serialize()`; all work is
render-only.>

| Sprint | Session | Items | Automated | Human verdict |
|--------|---------|-------|-----------|---------------|
| -- | S<N> | audit written, nothing shipped | -- | picks pending |

Token note -- read fully: <files>. By range: <files>. Not examined: <files / areas> (extend, do not re-scan).

Effort is relative size, not hours: XS = one edit, S = one sitting, M = a few sittings, L = a sprint.
Risk L/M/H = regression surface (H touches the constraint, a contract, a migration, or needs a build the
assistant cannot run). Cost L/M/H = tokens for the executing session. Win = Value / effort points
(XS 0.5, S 1, M 3, L 6).

---

## 1. Root causes (code-cited) -- <only when there is a complaint; else delete the section>

| ID | Finding | Where | Fix | Value | Effort | Risk | Cost | Visible | Deps |
|----|---------|-------|-----|-------|--------|------|------|---------|------|
| **A1** | **<the finding in one bold sentence>.** <evidence chain: what runs, how often, what it costs, why it is the likely cause>. | `file:line`, `file:line-line` | (a) <smallest fix>. (b) <larger option, if any>. | 5 | XS (a) / S (b) | L | L | desktop | -- |

Not the cause / checked and fine: <what was examined and found OK, with the number that proves it --
e.g. "the sim (integer math, 30 Hz), audio (throttled + pooled), texture memory (~70 MB decoded)".>

---

## 2. <Area B -- HUD / UX>

| ID | Finding | Where | Fix | Value | Effort | Risk | Cost | Visible | Deps |
|----|---------|-------|-----|-------|--------|------|------|---------|------|
| **B1** | ... | `file:line` | ... | 4 | S | M | M | both | -- |

## 3. <Area C -- screens / flow>

| ID | Finding | Where | Fix | Value | Effort | Risk | Cost | Visible | Deps |
|----|---------|-------|-----|-------|--------|------|------|---------|------|

## 4. <Area D -- feel / graphics>

| ID | Finding | Where | Fix | Value | Effort | Risk | Cost | Visible | Deps |
|----|---------|-------|-----|-------|--------|------|------|---------|------|

<add E audio / F backend / G content / H code health only if the lens was asked>

---

## 5. Suggested order (recommended set; the owner picks)

- **Sprint 1 -- measure + zero-design-risk wins (<pts> pt):** <instrument ID> first (baseline), then <IDs>. All XS/S, Risk L. Re-measure on the reported device.
- **Sprint 2 -- <theme> (<pts> pt):** <IDs>.
- **Sprint 3 -- <theme> (<pts> pt):** <IDs>; mobile-visible items last, with the test matrix.
- **Sprint 4/5 (only if needed):** <IDs>.
- **Later (listed, unranked):** <IDs> -- <why they wait>.

**Design picks for the owner (never assumed):** <ID -- one line each: what changes visibly and the trade-off>.
**Risk-H / Cost-H (unpicked by default):** <ID -- why it is H; what would make it safe>.

## Plan (picked)

<empty until `/polish plan`; then: Sprint N -> IDs (pts), Unpicked (owner) -> IDs + reason.>

---

## 6. Test matrix

<devices, wrappers, viewport tiers, orientation, fullscreen states the surface must be checked on for
any mobile-visible item; the components that encode device quirks and must not be touched.>

## 7. Do not

- <trap found while reading, with the reason -- e.g. "do not add the route to the mobile list, it is already there; the desktop list is the gap">
- <the constraint restated as a do-not>
