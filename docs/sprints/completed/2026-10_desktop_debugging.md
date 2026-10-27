# Sprint: Desktop Debugging

**Started:** 2026-09-30
**Completed:** 2026-10-27
**Status:** Complete

## Goal
Source-level debugging from the Odin desktop app through VD into FFmpeg, and
through local SDL3, in CLion.

## Context
Desktop/core is the active scope. The C unity build, shared CLion/terminal presets,
Debug/Release outputs, and dependency builds were in place at the start. iOS
source/tooling was removed; its original plans are in `docs/sprints/deferred/`.

---

## Phases

### Phase 1 — Odin → VD
- [x] Check Odin plugin and LLDB integration in CLion
- [x] Build/run the desktop executable through the existing `just` command
- [x] Break in Odin and step across the C ABI into `vd_hello`
- [x] Verify source locations, variables, and backtraces

### Phase 2 — FFmpeg Debugging
- [x] Separate FFmpeg Debug/Release builds and select the matching prebuilt artifacts
- [x] Retain debug symbols/source paths and disable stripping for dependency debugging
- [x] Trace Odin → VD → FFmpeg with source breakpoints and backtraces

### Phase 3 — Vendored SDL3
- [x] Vendor user-supplied SDL3 3.4.4 source and pin project-local Odin bindings with an explicit static-library import
- [x] Build SDL3 and shadercross explicitly into separate Debug/Release directories; never rebuild automatically during app builds
- [x] Debug: retain symbols/source paths and frame pointers, disable optimizations and stripping
- [x] Release: optimized artifacts without debug information
- [x] Select matching prebuilt artifacts through `vd_config`; CLion delegates to `just`, without separate flags
- [x] Headless C/SDL/shadercross and Odin binding smoke tests in both configurations
- [x] Confirm incremental reuse, missing-artifact failure, Debug/Release DWARF policy, desktop linking, and FFmpeg regression tests
- [x] Verify live Odin → SDL3 → Odin stepping in CLion

### Follow-ups Done During the Sprint
- [x] `ext` registered as an Odin collection (`import sdl "ext:odin-sdl3"`) for build/check/smoke commands
- [x] FFmpeg dependency build reports configure/compile/install phases and configure duration
- [x] Fresh clone built successfully on the first attempt via `just build-deps`

---

## Outcome

- User confirmed live CLion stepping across Odin, VD, FFmpeg, and SDL3.
- LLDB resolves FFmpeg (`avformat_version`) and SDL3 (`SDL_Init_REAL`) to vendored
  source in the desktop binary; the binary has no SDL3 dylib or Homebrew dependencies.
- Setup documented in `docs/references/desktop_debugging.md`, `ext/ffmpeg.README.md`,
  `ext/SDL3.README.md`, and `ext/odin-sdl3/README.md`.

## Learnings
- macOS system Make 3.81 ignores subsecond timestamps; modern Make 4.4.1 fixes stale builds.
- Debug/Release C flags are explicit; tests retain assertions in both configurations.
- CLion custom targets use project-local build tools (the **…** button beside Build), not IDE-wide External Tools.
- Custom Build Application's executable field needs an absolute path; `$ProjectFileDir$` was treated literally.
- Odin Support's collection marking is labeled **Mark Directory as → Odin Collection**; its README's older wording is outdated.
- Odin's SDL3 bindings hard-code `system:SDL3` and its macOS linker searches Homebrew first; a pinned local binding snapshot with an explicit archive import avoids silent fallback.
- SDL uses dispatch wrappers; `SDL_Init_REAL` and `SDL_GetPerformanceFrequency_REAL` are useful implementation breakpoints.
- Vendored SPIRV-Cross embeds configure timestamps; `SOURCE_DATE_EPOCH=0` prevents needless rebuilds.
- FFmpeg's configure is quiet for ~20 s while probes write to `ffbuild/config.log`; its summary prints at the end.
