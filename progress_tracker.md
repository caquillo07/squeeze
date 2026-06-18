# Squeeze — Progress Tracker

## Current Sprint: Monorepo Bootstrap (2026-06-18)

### Phase 1 — Repo Skeleton & Docs (Complete)
- Directory structure, CLAUDE.md, architecture.md, project_vision.md, coding_style.md
- justfile with full iOS recipe set (build, run, run-device, debug, test, release, screenshot, devices)
- Sprint system with template and upcoming sprints planned

### Phase 4 — iOS App Migration (Complete)
- Migrated MediaToolKit → Squeeze (4 Swift files: SqueezeApp, RootView, GalleryView, PhotoLibrary)
- New Xcode project with file sync, bundle ID com.caquilloapps.Squeeze
- Build settings: photo library usage description, app category, status bar style
- Verified on simulator (iPhone 17 Pro Max) and physical device (wireless via devicectl)
- Gallery with thumbnails, file size badges, duration badges, prefetch pre-warming all working

## Completed Sprints

(none yet — first sprint in progress)

## Prior Art (from predecessor projects)

### MediaToolKit (iOS app)
- Gallery with smooth scrolling, prefetch pre-warming, PHCachingImageManager
- File size + duration badges on thumbnails
- Photos-style ordering (oldest top, newest bottom, launch at bottom)
- UICollectionView via UIViewControllerRepresentable (SwiftUI LazyVGrid has no prefetch API)
- Key learnings captured in MediaToolKit's sprint 1

### vdbg_player (Odin desktop app)
- Working C shim (vd.c/h) wrapping ffmpeg decode/format detection
- SDL3 GPU-accelerated rendering with compiled shaders
- Incremental migration pattern from C shim to native Odin

### vdb (Odin prototype)
- Proof of concept for Odin + ffmpeg + SDL3 stack
- Validated the C shim approach
