# <Target> -- polish sprint record (S<N>-, <YYYY-MM-DD>)

Audit: `<AUDIT_DIR>/<target>-polish-audit.md` (IDs below refer to its rows). One section per sprint,
appended in order, never rewritten. **Constraint:** <copied verbatim from the audit>.

## How to measure

<the instrument shipped in sprint 1 and how to read it: URL flag, what each number means, what
"good" looks like on the reported device, how to screenshot it for a remote triage.>

---

## Sprint 1 (S<N>, <date>) -- <theme>: SHIPPED on <repo> `<branch>` (`<hash>`)

### What changed
- **A1(a)** -- <what, in one line> (`file:line` now).
- **A3** -- ...

### Verified -- automated
- `<command>` -> <result> (tests N passed / build green / sim determinism unchanged).
- Headless smoke: <page loads, 0 console errors, the new thing present -- the concrete check>.

### Checks that need a real device (the owner runs these)
- [ ] <open X, do Y, expect Z> -- <device / viewport>
- [ ] <the measurable: the readout before vs after on the reported machine>

### Tooling gotchas (cheap wins for the next session)
- <port / timeout / flag / harness quirk hit this sprint, and the workaround>

### Not in this sprint (remaining picks)
- <IDs still open, and the design picks awaiting a tick>

---

## Do not (cumulative)

- <restated constraint>
- <anything a sprint proved must never come back -- e.g. "the chrome offsets must not return; the page owns its exits now">
