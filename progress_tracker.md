# Squeeze — Progress Tracker

## Current Work: Profiling and Measurement — In Progress

- Started 2026-10-27. See `todo.md` and `docs/references/profiling.md`.
- Phase 1 done: curated shutdown report (`desktop/run_report.odin`) with build/dependency identity queried at runtime, startup/shutdown lifecycle, per-stage frame aggregates with worst frame, arena used/committed/reserved peaks with growth/release counts, and self-measured instrumentation overhead (≤ ~150 ns/frame).
- Phase 2 core done: Tracy 0.14.1 client + odin-tracy vendored and built from source; modes `on` (Debug default, on-demand), `startup`, `off` (Release default), localhost-only. One trace API (`desktop/trace.odin`) feeds both the report and Tracy; VD C zones via `core/vd/vd_trace.h`. Verified in the viewer; zone stats agree with the report.
- Findings: ~82% of loop time waiting in present while redrawing a static image; ~30% of one core at idle across threads; startup stall is the window appearing, not our code.
- Arena allocations tracked in Tracy's Memory view as named pools (identity when Tracy is off). Callstack depths enforced at compile time.
- Found: Odin omits frame pointers on macOS arm64, so frame-pointer stack walks (backtrace, Tracy callstacks) skip Odin frames; unwind tables are fine. Draft upstream issue + repro in `docs/upstream/odin-frame-pointers/`.
- Next: file/decide on the frame-pointer issue, loud arena free guard, SDL and FFmpeg allocation tracking, then the event-driven loop.

## Completed: Desktop Debugging (2026-09-30 → 2026-10-27)

Archived in `docs/sprints/completed/2026-10_desktop_debugging.md`.

- Desktop/core only. iOS source and tooling removed on 2026-09-30 to avoid maintaining an inactive target.
- VD moved to `core/vd/`, with owned tests and a single unity compilation entry point.
- Vendored FFmpeg 9.0.2 builds statically; applications link only `libvd.a` for decoding dependencies.
- CMake presets shared by terminal/CLion; Debug/Release outputs are separate, C flags explicit.
- Modern Make 4.4.1 verified; both configurations' smoke tests pass.
- User verified Odin → VD → Odin stepping in CLion using a custom target delegating to `just`.
- Separate FFmpeg Debug/Release builds; both configurations' smoke tests pass. LLDB resolves `avformat_version` to source in the desktop binary.
- SDL3 3.4.4 source-vendored with pinned Odin bindings; SDL3/shadercross build explicitly into separate Debug/Release directories. Local static imports remove the system SDL dependency.
- C/SDL/shadercross and Odin binding smoke tests pass in both configurations. LLDB resolves SDL implementation source in the desktop binary.
- SDL incremental reuse, missing-artifact failure, DWARF policy, desktop linking, and FFmpeg regression checks pass. Desktop restored to Debug artifacts.
- User confirmed live CLion stepping across Odin, VD, FFmpeg, and SDL3. `ext` is an Odin collection; FFmpeg build reports phases and configure duration.
- iOS plans are preserved under `docs/sprints/deferred/`; completed sprint history below remains historical.

## Completed: Monorepo Bootstrap (2026-06-18 → 2026-06-19)

Archived in `docs/sprints/completed/2026-06_monorepo_bootstrap.md`.

- Repo skeleton, docs, justfile, sprint system
- VD C shim and desktop app (Odin + SDL3) migrated from vdbg_player; builds and runs
- The iOS app built in this sprint was removed on 2026-09-30; its plans are in `docs/sprints/deferred/`

## Prior Art (from predecessor projects)

### vdbg_player (Odin desktop app)
- Working C shim (vd.c/h) wrapping ffmpeg decode/format detection
- SDL3 GPU-accelerated rendering with compiled shaders
- Incremental migration pattern from C shim to native Odin

### vdb (Odin prototype)
- Proof of concept for Odin + ffmpeg + SDL3 stack
- Validated the C shim approach
