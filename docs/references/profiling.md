# Profiling and Measurement

Answer, for any run: what happened, what did it cost, and how can we explain that
cost. Three views, each with a different job:

| View | Question | Where |
|---|---|---|
| Shutdown report | What ran and what did it cost? | Printed at exit, every build |
| Tracy timeline | When did work happen and overlap? | `just run-desktop` + viewer |
| Platform profiler | Where did CPU/memory/system time actually go? | Instruments (macOS) |

## Shutdown report

`desktop/run_report.odin`. No hand-written state: every value is recorded at runtime
by the code doing the work or queried from linked libraries.

- **Run:** commit (`-dirty`), Odin/C configuration, Odin and SDL versions, linked
  FFmpeg versions (`vd_backend_describe`), Tracy mode, workload, renderer/vsync and
  display refresh at loop exit, session length and frames.
- **Startup / Shutdown:** one-off `Lifecycle_Step` timings. Nested steps are indented
  and marked "included in …"; steps that never ran print "not executed".
- **Frames:** per `Stage`, whole-session count, total, mean, worst, and the frame the
  worst happened on. Stages are non-overlapping and in execution order; `untimed` is
  the frame mean minus stage means; the frame total is last. All timings are
  wall-clock and include waiting inside calls. Also: share of loop time inside
  present, timer resolution, and instrumentation overhead measured at exit.
- **Memory:** arenas sampled each frame before the scratch reset (and before startup's
  temp scope ends): peak used (+frame), peak committed, reserved, peak reserved, growth
  and release counts. Growth with zero releases means undersized; growth and releases
  rising together means an overflow block is cycling. Growth logs a warning every time.

`SQUEEZE_RAW_STATS=1` appends the raw tick values. "not measured" means we have no
instrumentation for it; "not executed" means it ran zero times.

## Instrumentation API

`desktop/trace.odin`; app code never calls Tracy directly.

- `stage_begin(.Input)` / `stage_end(scope)` or scoped `stage_scope(.Present)`:
  report stage + Tracy zone, same name and boundaries by construction.
- `trace_begin("name")` / `trace_end(zone)` or `trace_scope("name")`: Tracy-only
  detail; nests anywhere.
- `frame_begin`: frame counter, frame interval, Tracy frame mark.
- C (VD): `core/vd/vd_trace.h` `trace_begin(zone, "name")` / `trace_end(zone)`; same
  timeline, single client. Stages stay app-only.

Collection costs ≤ ~150 ns per frame (~9.5 ns per clock read dominates); it is
always on.

## Tracy

See `ext/tracy.README.md` for vendoring, modes, and viewer setup.

```sh
just run-desktop                         # Debug: Tracy on, collects while connected
TRACY_NO_EXIT=1 just tracy=startup run-desktop  # capture startup; wait for viewer at exit
just tracy=off run-desktop               # no Tracy code
just tracy_callstack=8 run-desktop       # stack per zone (costly)
```

Tracy sees only instrumented code. On macOS it has no sampling or context-switch
capture, so SDL, Metal, and system threads are invisible to it; its CPU usage track is
coarse. Use Instruments for those. Library internals (SDL, FFmpeg) appear as the time
inside our zones around calls into them.

## Platform tools

- **Instruments:** Time Profiler (all threads, symbolicated in Debug), Allocations /
  VM Tracker, System Trace. Profile-build workflows are pending (todo Phase 3).
- **Activity Monitor:** % CPU is per core. btop's process Cpu% is of the whole machine
  (divide by core count to compare).

## Pitfalls we hit

- Last-frame values mislead; report session aggregates.
- Microbenchmarks in optimized builds can fold to zero; keep the measuring loop
  unoptimized and the measured procedures optimized.
- Odin `fmt` zero-pads right-aligned numbers and `%Ns` counts bytes; build
  fixed-width strings before padding.
- Arenas: committed is page-granular (16 KB on Apple Silicon); `free_all` releases
  extra blocks, keeps and zeroes the first.
