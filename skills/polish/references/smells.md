# Smell catalogue -- what the inventory counts mean and the usual fix

Read only the section for the detected domain. A hit is a lead, not a finding: the finding is the
`file:line` + the reason it costs the player something. Value comes from breadth (every frame / every
player) times visibility; a hot smell inside a loop that runs once at load is Value 1.

## Web (React / Pixi / Three / plain DOM)

| Pattern | Why it matters | Usual fix | Typical value |
|---------|----------------|-----------|---------------|
| rAF loop | A `requestAnimationFrame` loop that is not gated on visibility keeps burning GPU behind an overlay or in a background tab; two loops on one page = two renderers. | Gate on `document.visibilityState` / route; unmount hidden renderers (the OD lag root cause: a 3D background rendering behind an opaque game). | 5 when it doubles a renderer |
| setState-like calls inside the frame loop | React re-renders every frame for a sim that ticks less often; each render rebuilds arrays, adapters and DOM with shadows/gradients. | Set state only when the tick advanced; move the entity path to a ref + the ticker; change-detect the HUD snapshot; interpolate visuals from the snapshot. | 5 |
| useEffect / useState density | A page with dozens is usually doing frame work in React. Not a finding by itself -- find the ones keyed on per-frame values. | Memoize handlers passed to the renderer (`useCallback`), split the HUD from the field. | 3 |
| backdrop blur | `backdrop-filter` over a repainting canvas forces a per-frame blur of the region beneath. | Opaque-ish fill instead of blur on always-visible controls. | 3 |
| keyframes anim | A permanent CSS animation on a full-width layer (box-shadow / inset shadow) repaints the strip every frame -- and often signals a design bug (alarm on from tick 0). | Fix the threshold; animate a small element, not the bar. | 4 when it runs the whole match |
| antialias on | MSAA buys nothing on textured meshes; `powerPreference` unset lets dual-GPU laptops pick the integrated GPU; no `maxFPS` doubles work on 120/144 Hz panels. | `antialias:false`, `powerPreference:'high-performance'`, `ticker.maxFPS = 60`; 1 px lines stay crisp. | 4 |
| per-frame allocs (`new Text/Graphics/Sprite`) | Text = canvas rasterize + GPU upload; rebuilt bars every change = GC hitches in dense waves. | Persistent objects, `clear()` + redraw, `visible` toggles, pooled sprites / `ParticleContainer`. | 3 |
| destroy calls | Paired with the above: destroy/recreate churn. Also check the page-leave path frees the renderer. | Pool; destroy once on unmount. | 2-3 |
| add vs remove listener | Unbalanced counts = leaks or rebinds every render (`pointertap` re-bound because the handler is a new function). | `useCallback`; bind once in an effect keyed on stable refs. | 3 |
| new Audio | One `Audio` per play = decode + alloc per shot; clipped or doubled cues. | Pooled / throttled player; one stinger per match end. | 2 |
| DPR / resolution | Caps keyed on `innerWidth < 640` never apply in landscape (phones are 640-930 wide there). | Key on viewport tier or `min(innerWidth, innerHeight)`. | 4 on mobile |
| JSON.parse / localStorage | Large parses on the main thread mid-play; stale snapshots after a deploy. | Preload during the loading screen with real progress; validate before use. | 3 |
| lazy routes | Every route lazy = one chunk stale while another is fresh (a deployed fix absent for days). | A build-id check; `no-cache` on mutable manifests. | 2 (ops) |
| three.js present | A second WebGL context on a game page. | Unmount it on game routes. | 5 if it is mounted during play |
| console.log | Noise in hot paths costs a little; more useful as a map of what the author was debugging. | Remove from per-frame paths. | 1 |

Also look for, without a pattern: a loading screen whose last step is hard-coded (`false` / 75%);
events the sim emits that the renderer never handles (`life_lost`, `wave_started` -- grep the emit
names against the render layer); the result screen offering only "Continue"; a restart / exit with no
confirmation on mobile; hotkeys shown only in one state; targets under 44 px on touch; the "hero
portrait" style decoration that covers play space.

## Unity (C#, WebGL target)

| Pattern | Why it matters | Usual fix | Typical value |
|---------|----------------|-----------|---------------|
| Update loops | Every `Update` on every object runs every frame; dozens of small ones cost more than one manager. | Manager-driven ticks; disable components that idle; `enabled = false` on off-screen objects. | 3 |
| GetComponent in Update | Lookup per frame; on WebGL the IL2CPP cost shows. | Cache in `Awake`/`Start`. | 3 |
| Find calls | `Find*` walks the scene; in a loop or a spawn it stutters. | Cache references; inject via inspector or a registry. | 3-4 |
| Instantiate / Destroy | Spawning projectiles / enemies without pooling = allocation + GC spikes; the classic WebGL hitch. | Object pool for anything spawned more than once a second. | 5 in a shooter |
| Camera.main | `FindGameObjectWithTag("MainCamera")` every call before 2020.2; still a lookup habit worth caching. | Cache once. | 2 |
| Resources.Load at runtime | Synchronous load mid-play; on WebGL the whole `Resources` folder ships in the build. | Preload / Addressables / direct references. | 3 |
| OnGUI | Immediate-mode GUI allocates every frame and repaints twice. | UGUI / TMP; remove debug OnGUI from builds. | 4 if present in gameplay |
| Debug.Log | Each call allocates a string and, on WebGL, writes to the browser console -- expensive in hot paths. | Strip from Update / hit / spawn paths; wrap in a `#if` define. | 2-3 |
| WaitForSeconds alloc | `new WaitForSeconds` inside a loop allocates every iteration. | Cache the instance. | 1-2 |
| coroutines | Many concurrent coroutines for timers = allocation + ordering bugs. | A timer manager or plain float countdowns. | 2 |
| SendMessage | Reflection call, string-based; slow and silent on typos. | Direct references / events / interfaces. | 2 |
| physics queries per frame | Raycast / Overlap every frame from many objects. | Layer masks, cadence (every N frames), non-alloc variants (`RaycastNonAlloc`). | 3 |
| PlayerPrefs | Fine for settings; a problem when it is the save system for progress or used in hot paths. | Batch writes; never in Update. | 1-2 |
| WebGL bridge (`DllImport` / `.jslib`) | The seam with the React wrapper: score submission, wallet, resize. Calls are synchronous and string-based. | Keep messages small; version the contract; never trust the JS side for scores. | 4 (contract) |
| string build in hot paths | `$"..."` / `Format` in Update or per-hit = garbage. | Cache, `StringBuilder`, update text only on change. | 2 |
| frame rate / vsync | `targetFrameRate` unset on WebGL = browser default; `-1` + heavy scene = uneven pacing. | Set explicitly; expose a low-graphics toggle. | 3 |

Also look for: `QualitySettings` never lowered for mobile browsers; particle systems with unbounded
max particles; audio sources with `PlayOneShot` spam and no limiter; the loading screen that reports
nothing during asset decompression (WebGL's longest wait); text updated every frame (`.text =` in
Update); the score / result screen that shows one number and a button. Remember the build constraint:
a C# change is a new build the assistant cannot make -- pair every C# item with the exact thing to
look at after the owner's build.

## Backend (FastAPI / asyncpg / web3)

| Pattern | Why it matters | Usual fix | Typical value |
|---------|----------------|-----------|---------------|
| sync defs under async routers | A sync `def` route runs in the threadpool (fine); a sync helper doing IO inside an `async def` blocks the loop for everyone (`/health` included). | `await` the IO; `run_in_executor` for the unavoidable; a timeout on every external call. | 5 when it can take the service down |
| blocking io (`requests`, `time.sleep`, `urllib`) | Same as above, the explicit form. | httpx async client with timeout. | 5 |
| blanket except | Silent failures: the endpoint returns 200 with nothing done (rollover STEP 7/8). | Narrow the except; return the error in the payload; log with context. | 4 |
| db calls inside loops | N+1: one query per item. | One query with `ANY($1)` / a join; batch writes. | 3 |
| SELECT * | Wide rows over the pooler; breaks on column changes. | Name the columns. | 1-2 |
| caches | Memory TTL caches survive reconnects and hide fresh chain state; no admin flush = stale for 5 min. | Event-driven invalidation; an admin-gated flush. | 3 |
| chain calls in handlers | Synchronous web3 inside async handlers with dead fallbacks = event-loop starvation. | Timeout per RPC, keyless fallbacks tested live, no chain call on hot read paths. | 5 |
| env reads scattered | Config resolved in many places = a staged variable nobody applied. | One settings object; log the resolved value at boot. | 2 |
| route decorators count | A map of the surface, not a smell. Use it to pick the hot endpoints (the ones the client polls). | -- | -- |
| print | Unstructured logs. | The logger with request context. | 1 |

Also look for: params that only appear inside `LEAST/GREATEST/CASE` (asyncpg resolves them as TEXT);
advisory locks taken on a pooled connection (unlocked on return); responses that return the same
`None` for "nothing to do" and "threw"; endpoints public that should be admin-gated.
