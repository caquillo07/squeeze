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
| Timeline trace | The story: when work happened and overlapped | Opt-in named scopes (Instruments signposts first) |
| External profiler | The evidence: where CPU/memory/GPU actually went | Instruments on a Profile build |

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
- [ ] Define measurement contracts for the initial stages (table below)
- [ ] Separate live state (last frame, playback position) from session aggregates
- [ ] Per timed stage collect only count, total ticks, max ticks; derive total/mean/worst at shutdown
- [ ] Split `frame_draw` into texture upload, render commands, and present call
- [ ] Define the frame-interval population (exclude/flag first interval; note pauses and debugger stops)
- [ ] Mark inclusive (nested) startup timings so they are not added to their children
- [ ] Arena capacity: initial, final, max, growth events; usage/high-water only after verifying arena API semantics (scratch sampled before reset)
- [ ] Curated four-section report: Run context, Lifecycle, Frame/stage summary, Memory & coverage
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

### Phase 2 — Profile Build and Instruments
- [ ] Optimized, symbol-enabled Profile configuration across Odin, VD, FFmpeg, SDL3, shadercross; separate outputs, explicit dependency builds, shared terminal/CLion ownership
- [ ] Verify symbol/source attribution in Instruments
- [ ] Repeatable Time Profiler capture; cross-check against the shutdown report
- [ ] Allocations / VM Tracker workflow; note visibility limits for arenas and foreign libraries
- [ ] System Trace starting workflow for waits, scheduling, I/O, wakeups

### Phase 3 — Correlated Traces
- [ ] One signposted stage visible in Instruments alongside system activity
- [ ] Same names/boundaries as report stages; opt-in, bounded, negligible disabled cost
- [ ] Extend across the media pipeline as it appears

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
- Whole-process memory polling in-app: Instruments first
- PGO: experiment only after Release decode, reliable benchmarks, and profiler evidence of CPU time in compiler-optimizable C

## Current Status

**Completed:**
- Approach agreed: three views, metric contracts, minimal aggregates

**In Progress:**
- Phase 1 — shutdown report

**Blocked:**
- Decode benchmarks and pipeline metrics require the real media pipeline

## Learnings
- (capture measurement semantics, tool limitations, and surprises as we go)

## Completion Checklist
- [ ] Agreed scope verified with representative workloads
- [ ] Deferred items recorded rather than implemented prematurely
- [ ] Workflows documented under `docs/references/`
- [ ] `progress_tracker.md` updated
- [ ] Archive to `docs/sprints/completed/`
