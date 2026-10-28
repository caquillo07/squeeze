# Sprint: Profiling and Measurement Foundations

**Started:** 2026-10-27
**Status:** In Progress

## Goal
Answer, for any run: **what happened, what did it cost, and how can we explain
that cost?** Build a lightweight, repeatable setup that becomes the blueprint for
future Odin/C desktop apps.

## Context
Cross-language source debugging and local Debug/Release dependency builds are done
(`docs/sprints/completed/2026-10_desktop_debugging.md`). `desktop/main.odin` already
prints a reflection-based `Runtime_Stats` dump at shutdown, but most of its numbers
lack defined meaning: frame timings are the last sample only, wall time is labeled
CPU time, `frame_draw_ms` mixes upload/render/present, arena values are reserved
capacity rather than usage, and unused fields print zeros.

## Three Views

| View              | Role                                                         | Mechanism                                                  |
|-------------------|--------------------------------------------------------------|------------------------------------------------------------|
| Shutdown report   | The receipt: what ran and what it cost                       | Small session aggregates, curated printer                  |
| Timeline trace    | The story: when work happened and overlapped                 | Tracy (cross-platform), on in Debug, off in Release       |
| External profiler | The evidence: where CPU/memory/GPU/system time actually went | macOS: Instruments. Linux (later): perf/Hotspot, heaptrack |

The report and traces use the same stage names and boundaries.

## Principles
- Every printed number has a contract: boundary, unit, population, aggregation, exclusions.
- Distinguish wall time from CPU time, work from waiting, CPU submission from GPU execution.
- Distinguish tracked app allocations from whole-process memory and GPU resources.
- A number needs a denominator; unavailable measurements print "not measured", never zero.
- Collection is bounded and allocation-free: no frame history, logging, or formatting in hot paths.
- Debug timings are labeled as such; performance baselines come from optimized builds.
- One explicitly owned stats context; no profiling singleton, framework, or custom trace viewer.
- Verify each tool against a known workload; enabling it is not proof it works.

---

## Phases

### Phase 1 — Meaningful Shutdown Report  ✓
- [x] Define measurement contracts for the initial stages (table below; also as comments on `Stage` in `desktop/trace.odin`)
- [x] Separate live state (last frame, playback position) from session aggregates
- [x] Per timed stage collect only count, total ticks, max ticks; derive total/mean/worst at shutdown
- [x] Split `frame_draw` into texture upload, render commands, and present call
- [x] Define the frame-interval population (first interval skipped; pauses and debugger stops included, documented)
- [x] Verify stage aggregates on a real run (temporary `print_frame_stages` table): stage means sum to ~99.9% of the frame interval; counts consistent (intervals = frames − 1)
- [x] Readable durations: largest unit ≥ 1, two decimals, aligned decimal points
- [x] Mark inclusive (nested) startup timings so they are not added to their children (`Lifecycle_Step` + `lifecycle_parents`)
- [x] Worst-case frame number per stage (`worst_frame`)
- [x] Arena capacity: initial, final, growth events
- [x] Arena usage/high-water after verifying `vmem.Arena` semantics: peak used (+frame), peak committed, reserved/peak reserved, growth events; scratch sampled before each reset and before startup's temp scope ends. Verified headlessly with forced block growth
- [x] Fix: growth check counted `free_all`'s release of extra blocks (a shrink) as growth
- [x] `release_events` counter: growth + releases rising together = cycling overflow block. Growth still warns every time, deliberately loud
- [x] Curated four-section report in `desktop/run_report.odin`: Run, Lifecycle, Frames, Memory. No hand-written state: values are recorded at runtime by the code doing the work
  - Run: commit (+dirty) and C/deps config via `-define`s from justfile; Odin version/optimization; SDL version/revision and FFmpeg versions queried at runtime; workload set by the content-creating code; renderer, vsync, display refresh captured at loop exit
  - Lifecycle: nested steps indented and marked "included in …"; unexecuted steps print "not executed"
  - Live last-frame `fps`/`prev_frame_ms` and unimplemented playback fields removed
  - Derived: share of loop time inside present; timer resolution
- [x] `vd_backend_describe` (caller-owned buffer); smoke test asserts the linked backend matches `VD_BACKEND`, and truncation
- [x] Raw dump behind `SQUEEZE_RAW_STATS=1` (no rebuild)
- [x] Verify the report on a real run
- [x] Report reads in order: Run, Startup, Frames (stages in execution order, untimed remainder, frame total last), Shutdown, Memory
- [x] `just fmt` passes an absolute `-config:`; odinfmt silently ignored `odinfmt.json` when its path lookup failed (sandbox `filepath.abs` permission error)
- [x] Release behavior: collection always on (negligible); report printed in every build for now, hide later if it gets annoying
- [x] Measure instrumentation overhead: measured at exit in the running build and printed per frame. ~140–160 ns/frame upper bound (~0.002% of a frame) in both `-debug` and `-o:speed`; clock read ~9.5 ns dominates. The measurement procedure is `optimization_mode="none"` because `-o:speed` folded the loops and reported 0 ns

Initial stage contracts (wall-clock monotonic ticks, displayed in ms):

| Stage            | Boundary                             | Notes                                |
|------------------|--------------------------------------|--------------------------------------|
| Frame interval   | Between consecutive loop starts      | Pacing, not cost                     |
| Input processing | Reset input state + drain SDL events |                                      |
| App update       | `app_update_and_render` call         | Count excludes paused frames         |
| Texture upload   | `SDL_UpdateTexture` call             |                                      |
| Render commands  | Clear + texture draw submission      | Not GPU execution                    |
| Present call     | `SDL_RenderPresent` call             | May include vsync/compositor waiting |

### Phase 2 — Tracy Traces
Decided: Tracy **0.14.1**. Vendor and build the **client** only; the **viewer** is a
developer-installed tool (official prebuilt binaries exist for macOS, Linux, Windows),
not vendored or built here. Bindings: `oskarnp/odin-tracy` (linked from Tracy's README).
- [x] macOS viewer 0.14.1 runs: binaries are ad-hoc signed, not notarized; clear quarantine and re-sign the `.app` ad-hoc
- [x] Document viewer setup (`ext/tracy.README.md`): version, download, install outside the repo, macOS quarantine/re-sign; viewer and client versions must match
- [ ] Later: consider the Homebrew `tracy` formula vs. release binaries for the viewer (version must match the vendored client)
- [x] Vendor Tracy 0.14.1 client source (`ext/tracy/public`); version, checksum, license recorded
- [x] Vendor `odin-tracy` (targets 0.14.1); foreign import points at our static archive; unreferenced and unlinked when disabled
- [x] `scripts/build_tracy.sh`: one-TU client into `build/deps/tracy/{debug,release}/{on,startup}/libtracy.a` (Debug -O2 -g, Release -O3), incremental; `just build-tracy` builds both modes, included in `build-deps`
- [x] Off builds (`tracy=off`) verified to contain no Tracy C symbols
- [x] `just smoke-tracy`: bindings link and run (zones, frame marks, plots)
- [x] Frame mark at loop start plus zones for the five report stages, same names/boundaries; arena used plotted
- [x] Verify capture in the viewer on macOS; zone stats agree with the shutdown report
- [x] One instrumentation API (`desktop/trace.odin`): `stage_begin/end/scope` feed report + Tracy; `trace_begin/end/scope` for Tracy-only nested detail; `frame_begin`; app code no longer calls Tracy directly
- [x] `tracy_callstack` just variable (`-define:TRACY_CALLSTACK=N`)
- [x] Tracy modes: `on` (default unless release; `TRACY_ON_DEMAND`), `startup` (buffer from launch), `off` (default for release); all localhost-only; mode printed in the run report
- [x] `trace_init()` is the first line of `main` (names the thread before any zone; the client itself starts at load). `TRACY_NO_EXIT=1` only for short `startup` captures: it can hang exit with no viewer
- [x] Trace into VD: `core/vd/vd_trace.h` (`trace_begin/trace_end`, same names as Odin) over `TracyC.h`; `VD_TRACY` CMake option in presets + from `just`; libvd.a only references the single client; tests link it when on. Zones in `vd_hello`/`vd_backend_describe`
- [x] VD zones (`vd_hello`, `vd_backend_describe`) visible on the main thread with `tracy=startup`; nesting under a stage verified once VD runs inside one (decoder)
- [ ] Zones around FFmpeg calls when the decoder exists
- [x] Odin arenas tracked: `tracked_arena_allocator` (desktop/trace.odin), named pools `permanent`/`scratch`, `free_all` → pool discard, moved resizes keep the old block live, allocation callstacks (`tracy_alloc_callstack`, default 16); identity when Tracy is off. Verified headlessly (alloc, in-place/moved resize, rejected free, free_all)
- [x] Verified in Tracy's Memory view: `permanent`/`scratch` pools, 3.5 MB frame buffer, scratch emptying each frame; C (SDL) frames symbolicate
- [ ] **Odin frames missing from callstacks**: Odin omits frame pointers on macOS arm64 (no `"frame-pointer"` IR attribute; `x29` never set), and Tracy's macOS client walks frame pointers via `backtrace()`. Unwind tables are fine (libunwind walks Odin frames). Still present in `dev-2026-10-nightly:84bc3fc`. Draft issue + repro: `docs/upstream/odin-frame-pointers/`
- [ ] Loud arena free guard: install the arena wrapper in all Debug builds (not only Tracy), log an error with the call site on every `free`; fix our own hits (e.g. `log.destroy_console_logger` at shutdown); switch to an assert once runs are clean
- [x] Callstack depths enforced 0..62 at compile time (Odin `#assert`s, C `#error` in `vd_trace.h`)
- [ ] SDL allocations: `SDL_SetMemoryFunctions`
- [ ] FFmpeg allocations: configure `--malloc-prefix` hooks implemented in VD (option confirmed in vendored configure)
- [x] macOS limits: Tracy shows only threads that emit zones (no sampling/context switches on macOS); SDL/Metal/system threads → Instruments. Our future threads: name + zones
- [ ] Metal GPU zones: when the GPU renderer is active
- [ ] Extend zones across the media pipeline and threads as they appear

### Phase 3 — Profile Build and Platform Profilers
- [ ] Optimized, symbol-enabled Profile configuration across Odin, VD, FFmpeg, SDL3, shadercross (and Tracy client); separate outputs, explicit dependency builds, shared terminal/CLion ownership
- [ ] macOS: verify symbol attribution and a repeatable Time Profiler capture in Instruments; cross-check against the report and Tracy
- [ ] macOS: Allocations / VM Tracker and System Trace starting workflows; note visibility limits for arenas and foreign libraries
- [ ] Linux (when supported): perf/Hotspot and heaptrack equivalents

### Phase 4 — Distributions and Benchmarks
- [ ] Fixed whole-session frame-interval histogram; approximate median/p95/p99, labeled as such
- [ ] Headless decode → convert benchmark with fixed fixtures once decoding exists
- [ ] Record build/config/input identity; report distributions, throughput, memory; understand variation before thresholds

### Phase 5 — Reusable Blueprint
- [x] Started `docs/references/profiling.md`: report, trace API, Tracy, platform tools, pitfalls
- [ ] Extend with Instruments, allocation, and benchmark workflows as they land
- [ ] Record what each tool measures, what it cannot see, and how integration was verified
- [ ] Capture and explain a representative baseline

---

## Deferred
- Pipeline, queue, audio, A/V-drift, and dropped-frame metrics: when those systems exist
- Metal validation/capture and GPU timings: when the GPU renderer is active
- Whole-process memory polling in-app: platform profilers first
- Linux profiling workflows: when Linux becomes a supported target
- PGO: experiment only after Release decode, reliable benchmarks, and profiler evidence of CPU time in compiler-optimizable C

## Current Status

**Completed:**
- Phase 1: curated shutdown report (run context, startup, frames, shutdown, memory), arena usage, instrumentation overhead
- Phase 2 core: Tracy 0.14.1 client + odin-tracy vendored; modes on/startup/off; one trace API for report + Tracy; VD C zones via `vd_trace.h`; verified in the viewer

**In Progress:**
- Phase 2: allocation tracking. Odin arenas done and verified; Odin callstack frames blocked on frame pointers (see Next Session)

## Known Issue — Continuous Redraw Loop
Window moves are jerky. The loop redraws a static image every frame and spends ~85% of
its time blocked in `SDL_RenderPresent`, so the main thread rarely sits in the event loop.
One run also showed a ~1 s `present` stall (likely Metal's drawable timeout while the
window was occluded/changing displays) and a 139 ms event-pump block during a move.
- [ ] Experiment: present only on first frame and resize/expose; otherwise wait for events. Confirm jerks disappear
- [ ] Event-driven loop: redraw only when something changed; block in `SDL_WaitEventTimeout` until the next event or deadline (animation frame, video frame, timer)
- [ ] Keep running continuously (display-paced, vsync on) while anything animates or plays
- [ ] Redraw during live resize via an event watch on expose events, if needed
- [ ] Report: presented vs skipped frames, time spent waiting for events
- [ ] Re-check idle CPU after the change: Activity Monitor shows ~30% of one core for a static image (all threads; main thread works ~15%). Investigate (Tracy off vs on, Time Profiler by thread) only if it does not drop substantially

## Next Session
1. **Odin frame pointers:** re-run `docs/upstream/odin-frame-pointers/` repro on the latest nightly and re-search upstream; if still present, file `ISSUE.md` (user files it). Then decide a local stopgap for Odin callstacks: (a) patch our Odin build to emit `"frame-pointer"="non-leaf"` on Darwin, or (b) a small patch to the vendored Tracy client to walk with Apple libunwind (`unw_step`) instead of `backtrace()`
2. Loud arena free guard (all Debug builds), fix our own hits.
3. SDL allocations (`SDL_SetMemoryFunctions`), then FFmpeg (`--malloc-prefix`).
4. Then: event-driven loop (known issue), with Tracy before/after; then Phase 3 Profile build + Instruments.

## First Findings (Debug build, dummy workload)
- ~82% of session time is inside `SDL_RenderPresent` — waiting, not work. We redraw a static image ~129×/s; battery fix later: skip presenting when nothing changed.
- Texture upload: ~0.65–0.85 ms per 3.7 MB frame, re-uploaded every frame; becomes the real per-frame cost with video.
- The ~90–100 ms worst frame is at startup (frame 2), alongside `WINDOW_PIXEL_SIZE_CHANGED`: window appearing/scaling, not our code.
- Instrumentation costs ≤ ~150 ns/frame (~0.002%).
- Idle CPU is ~30% of one core across all threads (Activity Monitor) while showing a static image.

**Blocked:**
- Decode benchmarks and pipeline metrics require the real media pipeline

## Learnings
- Last-frame values mislead: last frame showed 86 fps while the session mean was ~129 fps.
- This Odin nightly's `fmt` zero-pads right-aligned numbers by default; format numbers to strings first.
- Odin `%Ns` width counts bytes, not runes: `µ` (2 bytes) misaligns columns. Build fixed-width strings instead.
- `vmem` growing arena: `free_all` releases extra blocks (reserved shrinks), keeps the first block's committed pages, and zeroes its used bytes — a per-frame memset proportional to scratch use.
- Tracy's macOS binaries are ad-hoc signed and not notarized; Gatekeeper reports the quarantined `.app` as "damaged" until quarantine is cleared and it is re-signed ad-hoc.
- Microbenchmarks: `-o:speed` folded redundant loops to 0 ns; measure with the loop procedure unoptimized and the measured procedures optimized.
- Odin omits unreferenced foreign imports at link time: with `TRACY_ENABLE` false the client archive is not needed or linked.
- `-define` values that look like integers become integers; quote string defines (e.g. all-digit commit hashes).
- The Tracy client starts at program load; `on` (`TRACY_ON_DEMAND`) discards everything before the viewer connects, so startup needs `tracy=startup`.
- Odin on macOS arm64 omits frame pointers: `backtrace()` and Tracy callstacks skip Odin frames; libunwind still walks them (unwind tables are correct).
- Activity Monitor's % CPU is per core; btop's process Cpu% is of the whole machine (×10 cores on M1 Max). Tracy's CPU usage track is coarse (~200 ms samples).

## Completion Checklist
- [ ] Agreed scope verified with representative workloads
- [ ] Deferred items recorded rather than implemented prematurely
- [ ] Workflows documented under `docs/references/`
- [ ] `progress_tracker.md` updated
- [ ] Archive to `docs/sprints/completed/`
