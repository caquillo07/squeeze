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

| View | Role | Mechanism |
|---|---|---|
| Shutdown report | The receipt: what ran and what it cost | Small session aggregates, curated printer |
| Timeline trace | The story: when work happened and overlapped | Tracy (cross-platform), opt-in builds |
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

### Phase 1 — Meaningful Shutdown Report  ← start here
- [x] Define measurement contracts for the initial stages (table below; also as comments on `Frame_Stages`)
- [x] Separate live state (last frame, playback position) from session aggregates
- [x] Per timed stage collect only count, total ticks, max ticks; derive total/mean/worst at shutdown
- [x] Split `frame_draw` into texture upload, render commands, and present call
- [x] Define the frame-interval population (first interval skipped; pauses and debugger stops included, documented)
- [x] Verify stage aggregates on a real run (temporary `print_frame_stages` table): stage means sum to ~99.9% of the frame interval; counts consistent (intervals = frames − 1)
- [x] Readable durations: largest unit ≥ 1, two decimals, aligned decimal points
- [ ] Mark inclusive (nested) startup timings so they are not added to their children
- [ ] Arena capacity: initial, final, max, growth events; usage/high-water only after verifying arena API semantics (scratch sampled before reset)
- [ ] Curated four-section report: Run context, Lifecycle, Frame/stage summary, Memory & coverage
  - Run context: build config (Debug/Release), renderer backend, actual vsync state, workload (dummy 1280×720 RGBA), loop duration, frames presented
  - Lifecycle: indent nested timings and mark them "included above"
  - Never-executed measurements print "not executed"/"not measured" instead of zeros (GPU init, shader, pipeline, pts/dts)
  - Drop or relabel live last-frame `fps`/`prev_frame_ms` (86 fps last frame vs ~129 session mean)
  - Note timer resolution (~41.7 ns ticks) next to sub-microsecond values
- [ ] Keep the reflection dump only as an optional raw diagnostic
- [ ] Measure instrumentation overhead

Initial stage contracts (wall-clock monotonic ticks, displayed in ms):

| Stage | Boundary | Notes |
|---|---|---|
| Frame interval | Between consecutive loop starts | Pacing, not cost |
| Input processing | Reset input state + drain SDL events | |
| App update | `app_update_and_render` call | Count excludes paused frames |
| Texture upload | `SDL_UpdateTexture` call | |
| Render commands | Clear + texture draw submission | Not GPU execution |
| Present call | `SDL_RenderPresent` call | May include vsync/compositor waiting |

### Phase 2 — Tracy Traces
Decided: Tracy **0.14.1**. Vendor and build the **client** only; the **viewer** is a
developer-installed tool (official prebuilt binaries exist for macOS, Linux, Windows),
not vendored or built here. Bindings: `oskarnp/odin-tracy` (linked from Tracy's README).
- [x] macOS viewer 0.14.1 runs: binaries are ad-hoc signed, not notarized; clear quarantine and re-sign the `.app` ad-hoc
- [ ] Document viewer setup: version, download source, install outside the repo, macOS quarantine/re-sign steps; viewer and client versions must match
- [ ] Vendor Tracy 0.14.1 client source (`public/`) under `ext/`; record version, checksum, license
- [ ] Vendor `odin-tracy` at a pinned commit; verify it targets the 0.14.1 C API, how it links, and how it compiles out
- [ ] Build the client explicitly into a static archive with matching Debug/Profile flags; foreign import points at our archive (as with `odin-sdl3`)
- [ ] Opt-in only: disabled builds have no Tracy code, no listening socket
- [ ] One frame mark plus zones for the six report stages, using the same names/boundaries as the shutdown report
- [ ] Verify capture in the viewer on macOS; cross-check zone totals against the shutdown report; measure overhead
- [ ] Evaluate plots (arena usage) and the profiled-allocator wrapper, if the bindings provide one
- [ ] Check macOS limits: sampling, context switches, Metal GPU zones
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
- [ ] Document entry points and CPU/memory/trace/benchmark workflows under `docs/references/`
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
- Approach agreed: three views, metric contracts, minimal aggregates
- Tracy decided: vendor 0.14.1 client + odin-tracy; viewer installed per machine (macOS viewer verified after quarantine removal + ad-hoc re-sign)
- `Stage_Stats`/`Frame_Stages` session aggregates and aligned stage table, verified on real runs

**In Progress:**
- Phase 1 — curated four-section report (next)

## Next Session
1. Curated shutdown report (see Phase 1 sub-items): run context, lifecycle, stages, memory & coverage.
2. Arena capacity aggregates; then verify `vmem.Arena` used/high-water semantics before reporting usage.
3. Measure instrumentation overhead (e.g. N back-to-back `time_now` calls), keep the reflection dump as raw/optional.
4. Then Phase 2: document viewer setup, vendor Tracy 0.14.1 client + odin-tracy, one frame mark and the six stage zones.

## First Findings (Debug build, dummy workload)
- ~82% of session time is inside `SDL_RenderPresent` — waiting, not work. We redraw a static image ~129×/s; battery fix later: skip presenting when nothing changed.
- Texture upload: ~0.65–0.85 ms per 3.7 MB frame, re-uploaded every frame; becomes the real per-frame cost with video.
- Worst frame (~100 ms) coincides with a ~100 ms input drain: SDL event pump blocked (likely window activation or macOS move/resize modal loop). A trace will show when.

**Blocked:**
- Decode benchmarks and pipeline metrics require the real media pipeline

## Learnings
- Last-frame values mislead: last frame showed 86 fps while the session mean was ~129 fps.
- This Odin nightly's `fmt` zero-pads right-aligned numbers by default; format numbers to strings first.
- Odin `%Ns` width counts bytes, not runes: `µ` (2 bytes) misaligns columns. Build fixed-width strings instead.
- Tracy's macOS binaries are ad-hoc signed and not notarized; Gatekeeper reports the quarantined `.app` as "damaged" until quarantine is cleared and it is re-signed ad-hoc.

## Completion Checklist
- [ ] Agreed scope verified with representative workloads
- [ ] Deferred items recorded rather than implemented prematurely
- [ ] Workflows documented under `docs/references/`
- [ ] `progress_tracker.md` updated
- [ ] Archive to `docs/sprints/completed/`
