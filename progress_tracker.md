# Squeeze — Progress Tracker

## Current Sprint: Monorepo Bootstrap (2026-06-18)

### Phase 1 — Repo Skeleton & Docs (Complete)
- Directory structure, CLAUDE.md, architecture.md, project_vision.md, coding_style.md
- justfile with full iOS recipe set (build, run, run-device, debug, test, release, screenshot, devices)
- Sprint system with template and upcoming sprints planned

### Phase 2 — Core C Shim Migration (Complete)
- Migrated vd.c/h from vdbg_player to core/shim/
- Compiles via `just build-shim` (clang → ar → libvd.a)

### Phase 3 — Desktop App Skeleton (Complete)
- Migrated 7 Odin files from vdbg_player (main, app, input, vd, basic_renderer, gpu_renderer, shadercross)
- Migrated shaders (GLSL), fonts, SDL_gpu_shadercross dependency
- Updated foreign import paths for monorepo layout
- `just build-desktop` compiles C shim + GLSL shaders + Odin app
- `just run-desktop` launches window with Metal renderer, red test frame
- `just build-deps` builds vendored shadercross from source
- Fixed dummy frame pixel stride bug (row * Width not Height, * 4 for RGBA)

### Phase 4 — iOS App Migration (Complete)
- Migrated MediaToolKit → Squeeze (4 Swift files: SqueezeApp, RootView, GalleryView, PhotoLibrary)
- New Xcode project with file sync, bundle ID com.caquilloapps.Squeeze
- Build settings: photo library usage description, app category, status bar style
- Verified on simulator (iPhone 17 Pro Max) and physical device (wireless via devicectl)
- Gallery with thumbnails, file size badges, duration badges, prefetch pre-warming all working

### Phase 4.5 — Post-Migration Cleanup (Complete)
- SwiftFormat with tabs, explicit returns, no conditional assignment rewrite
- odinfmt integrated into `just fmt`
- swiftformat gated behind macOS check for Linux compatibility

### Phase 5 — Proof of Life (Complete)
- Odin core (`core/squeeze.odin`) compiles to iOS static lib via `just build-core-ios`
- Xcode Run Script phase calls `scripts/build_odin_core.sh` → `just build-core-ios`
- Bridging header exposes both Odin (`squeeze_version`, `squeeze_add`) and C shim (`vd_hello`) functions
- Swift successfully calls Odin and C: `[Squeeze] Odin core v0.1.0, 40 + 2 = 42` + `hello from C shim!`
- `build-deps` updated: shadercross builds out-of-tree to `build/deps/shadercross/`, DXC disabled, `-j4`
- `.gitignore` expanded to cover `.build/`, `*.xcuserstate`, `DerivedData/`, `.DS_Store`

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
