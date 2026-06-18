# Sprint: Monorepo Bootstrap

**Started:** 2026-06-18
**Status:** Not Started

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
- [ ] Write justfile with placeholder recipes
- [ ] git init + initial commit

### Phase 2 — Core C Shim Migration
- [ ] Copy vdbg_player's vd.c/h into core/shim/ as ffmpeg_shim.c/h
- [ ] Clean up the shim: remove vdbg_player-specific code, keep the clean ffmpeg API surface
- [ ] Verify it compiles standalone: `cc -c core/shim/ffmpeg_shim.c`
- [ ] Write a minimal thumb_cache.c/h stub (API only, implementation later)

### Phase 3 — Desktop App Skeleton
- [ ] Copy vdbg_player's main.odin + essentials into desktop/
- [ ] Update import paths to reference core/ and ext/
- [ ] Copy SDL3 bindings into ext/sdl3/
- [ ] Get `just build-desktop` compiling and linking
- [ ] Verify it launches (window opens, nothing crashes)

### Phase 4 — iOS App Migration
- [ ] Create Squeeze.xcodeproj in ios/
- [ ] Migrate MediaToolKit's Swift files into ios/ (SqueezeApp.swift, PhotoLibrary.swift, GalleryViewController.swift)
- [ ] Rename bundle ID to com.caquilloapps.Squeeze
- [ ] Add core/shim/*.c and core/thumb_cache.c to Xcode project as sources
- [ ] Create Squeeze-Bridging-Header.h exposing core C API
- [ ] Verify the app builds for iOS device target
- [ ] Verify existing gallery functionality still works on physical iPhone

### Phase 5 — Proof of Life
- [ ] Desktop app calls a core function (even just a version string) and prints it
- [ ] iOS app calls the same core function through the bridging header and logs it
- [ ] Both consuming the same source file from core/ — confirmed shared code

---

## Current Status

**Completed:**
- Phase 1 docs (architecture, vision, style guide, CLAUDE.md)

**In Progress:**
- Phase 1 remaining (justfile, git init)

**Blocked:**
- (none)

---

## Learnings
- (captured as we go)

---

## Completion Checklist

Before archiving this sprint:
- [ ] All phases marked complete
- [ ] docs/references/ guides written for major features
- [ ] progress_tracker.md updated with summary + learnings
- [ ] Archive: `mv todo.md docs/sprints/completed/2026-06_monorepo_bootstrap.md`
