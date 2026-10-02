# Sprint: Desktop Debugging

**Started:** 2026-09-30
**Status:** In Progress

## Goal
Source-level debugging from the Odin desktop app through VD into FFmpeg, and
through local SDL3, in CLion.

## Context
Desktop/core is the active scope. The C unity build, shared CLion/terminal presets,
Debug/Release outputs, and dependency builds are working. iOS source/tooling was
removed; its original plans are in `docs/sprints/deferred/`.

---

## Phases

### Phase 1 — Odin → VD
- [x] Check Odin plugin and LLDB integration in CLion
- [x] Build/run the desktop executable through the existing `just` command
- [x] Break in Odin and step across the C ABI into `vd_hello`
- [ ] Verify source locations, variables, and backtraces

### Phase 2 — Dependency Debugging
- [x] Separate FFmpeg Debug/Release builds and select the matching prebuilt artifacts
- [x] Retain debug symbols/source paths and disable stripping for dependency debugging
- [ ] Trace Odin → VD → FFmpeg with source breakpoints and backtraces

---

## Current Status

**Completed:**
- Prerequisite C build/preset integration; terminal and CLion reuse configuration outputs
- User verified Odin → C → Odin stepping through `vd_hello` in CLion
- Separate FFmpeg Debug/Release builds; smoke tests pass in both configurations
- LLDB resolves `avformat_version` to source in the desktop executable

**In Progress:**
- Verify live FFmpeg stepping, variable inspection, and backtraces in CLion

**Blocked:**
- Harness LLDB launch failed; live debugger checks remain in the user's CLion session

## Learnings
- macOS system Make 3.81 ignores subsecond timestamps; modern Make 4.4.1 fixes stale builds.
- Debug/Release C flags are explicit; tests retain assertions in both configurations.
- CLion custom targets use project-local build tools, not IDE-wide External Tools.
- Custom Build Application's executable field needs an absolute path; `$ProjectFileDir$` was treated literally.
- Setup is documented in `docs/references/desktop_debugging.md`.
- SDL uses dispatch wrappers; `SDL_Init_REAL` and `SDL_GetPerformanceFrequency_REAL` are useful implementation breakpoints.
- Vendored SPIRV-Cross embeds configure timestamps; `SOURCE_DATE_EPOCH=0` prevents needless rebuilds.

## SDL3 Debugging — In Progress

- [x] Vendor user-supplied SDL3 3.4.4 source and pin project-local Odin bindings with an explicit static-library import
- [x] Build SDL3 and shadercross explicitly into separate Debug/Release directories; never rebuild automatically during app builds
- [x] Debug: retain symbols/source paths and frame pointers, disable optimizations and stripping
- [x] Release: optimized artifacts without debug information
- [x] Select matching prebuilt artifacts through `vd_config`; CLion delegates to `just`, without separate flags
- [x] Headless C/SDL/shadercross and Odin binding smoke tests in both configurations
- [x] Confirm incremental reuse, missing-artifact failure, Debug/Release DWARF policy, desktop linking, and FFmpeg regression tests
- [ ] Verify live Odin → SDL3 → Odin stepping, variables, backtraces, and GUI/Metal behavior in CLion (setup documented in `docs/references/desktop_debugging.md`)

## Completion Checklist
- [ ] Both debugging phases verified
- [ ] Debugger setup documented and progress tracker updated
- [ ] Archive this sprint; next feature is decoding/rendering the first video frame
