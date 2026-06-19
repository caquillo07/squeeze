# Sprint: Monorepo Bootstrap

**Started:** 2026-06-18
**Status:** In Progress

## Goal
A working monorepo where `just build` compiles the desktop app (Odin + core C shim) and the iOS project builds in Xcode with core C files included. No features yet — just the skeleton that proves the build works end to end.

## Context
We're unifying four related projects (vdb, video_editor, vdbg_player, MediaToolKit) into a single monorepo called Squeeze. This sprint sets up the repo structure, migrates the proven code (vdbg_player's C shim, MediaToolKit's iOS shell), and gets both targets building from the same core source.

---

## Phases

### Phase 1 — Repo Skeleton & Docs
- [x] Create directory structure (core/, desktop/, ios/, ext/, docs/)
- [x] Write CLAUDE.md (project instructions)
- [x] Write docs/references/architecture.md
- [x] Write docs/references/project_vision.md
- [x] Write docs/references/coding_style.md (with No Magic section)
- [x] Write sprint template
- [x] Write justfile with iOS recipes (build, run, run-device, debug, test, release, screenshot, devices)
- [x] git init + initial commit

### Phase 2 — Core C Shim Migration
- [x] Copy vdbg_player's vd.c/h into core/shim/
- [x] Verify it compiles standalone: `clang -c core/shim/vd.c`
- [ ] Write a minimal thumb_cache.c/h stub (API only, implementation later)

### Phase 3 — Desktop App Skeleton
- [x] Copy vdbg_player's Odin source into desktop/
- [x] Update foreign import paths (vd.odin → build/desktop/libvd.a)
- [x] Copy SDL_gpu_shadercross into ext/
- [x] Add odinfmt.json, shaders, fonts
- [x] Get `just build-desktop` compiling and linking (C shim + shaders + Odin)
- [x] Verify it launches (window opens, red test frame renders)
- [x] Add `just build-deps` recipe for shadercross
- [x] Fix dummy frame pixel stride bug

### Phase 4 — iOS App Migration
- [x] Create Squeeze.xcodeproj in ios/
- [x] Migrate MediaToolKit's Swift files into ios/ (SqueezeApp.swift, RootView.swift, GalleryView.swift, PhotoLibrary.swift)
- [x] Rename bundle ID to com.caquilloapps.Squeeze
- [ ] Add core/shim/*.c to Xcode project as sources
- [ ] Create Squeeze-Bridging-Header.h exposing core C API
- [x] Verify the app builds for iOS simulator and device target
- [x] Verify existing gallery functionality still works on physical iPhone
- [x] Add justfile recipes for device deployment (run-device with wireless devicectl)

### Phase 4.5 — Post-Migration Cleanup
- [x] Add SwiftFormat (.swiftformat config with tabs, justfile recipe)
- [x] Add odinfmt to `just fmt` recipe
- [x] Gate swiftformat behind macOS check

### Phase 5 — Proof of Life
- [x] Desktop app calls a core function (vd_hello) and prints it
- [ ] iOS app calls the same core function through the bridging header and logs it
- [ ] Both consuming the same source file from core/ — confirmed shared code

---

## Current Status

**Completed:**
- Phase 1 (repo skeleton, docs, justfile, git init)
- Phase 2 (C shim migrated, compiles via `just build-shim`)
- Phase 3 (desktop app migrated, builds and runs via `just build-desktop` / `just run-desktop`)
- Phase 4 iOS migration (Swift files, Xcode project, build verified on simulator + device)
- Phase 4.5 (SwiftFormat + odinfmt, macOS-gated)

**Up Next:**
- Phase 4 remaining: bridging header + core C in Xcode project
- Phase 5: iOS calling core function to prove shared code

**Blocked:**
- (none)

---

## Learnings
- Xcode's `devicectl` supports wireless device deployment but spams provisioning warnings — filter stderr with grep
- `devicectl` JSON output (`--json-output <file>`) is the stable interface for scripting; table output is for humans
- Device state can be "connected" or "available (paired)" — match on `pairingState == "paired"` not `tunnelState == "connected"`
- No CLI for attaching Xcode's debugger — use Debug > Attach to Process manually
- Xcode's file sync (PBXFileSystemSynchronizedRootGroup) auto-discovers source files in subdirectories
- SDL3 `UpdateTexture` pitch param is bytes per row (width * 4 for RGBA), not bytes per pixel
- `glslc` requires `-fshader-stage` flag before the input file, not after
- Odin `foreign import` paths are relative to the source file, not the build directory

---

## Completion Checklist

Before archiving this sprint:
- [ ] All phases marked complete
- [ ] docs/references/ guides written for major features
- [ ] progress_tracker.md updated with summary + learnings
- [ ] Archive: `mv todo.md docs/sprints/completed/2026-06_monorepo_bootstrap.md`
