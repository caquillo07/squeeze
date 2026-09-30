# Sprint: Desktop Debugging

**Started:** Not started
**Status:** Not Started

## Goal
Source-level debugging from the Odin desktop app through VD into FFmpeg in CLion.

## Context
Desktop/core is the active scope. The C unity build, shared CLion/terminal presets,
Debug/Release outputs, and dependency builds are working. iOS source/tooling was
removed; its original plans are in `docs/sprints/deferred/`.

---

## Phases

### Phase 1 — Odin → VD
- [ ] Check Odin plugin and LLDB integration in CLion
- [ ] Build/run the desktop executable through the existing `just` command
- [ ] Break in Odin and step across the C ABI into `vd_hello`
- [ ] Verify source locations, variables, and backtraces

### Phase 2 — Dependency Debugging
- [ ] Separate FFmpeg Debug/Release builds and select the matching prebuilt artifacts
- [ ] Retain debug symbols/source paths and disable stripping for dependency debugging
- [ ] Trace Odin → VD → FFmpeg with source breakpoints and backtraces

---

## Current Status

**Completed:**
- Prerequisite C build/preset integration; terminal and CLion reuse configuration outputs

**In Progress:**
- Nothing yet; debugger setup is next

**Blocked:**
- None known

## Learnings
- macOS system Make 3.81 ignores subsecond timestamps; modern Make 4.4.1 fixes stale builds.
- Debug/Release C flags are explicit; tests retain assertions in both configurations.

## Completion Checklist
- [ ] Both debugging phases verified
- [ ] Debugger setup documented and progress tracker updated
- [ ] Archive this sprint; next feature is decoding/rendering the first video frame
