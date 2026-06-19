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

### Monorepo Bootstrap (2026-06-18 → 2026-06-19) — Archived
- Repo skeleton, docs, justfile, git init
- Core C shim + Odin core (`core/squeeze.odin`) migrated
- Desktop app (Odin + SDL3) migrated, builds and runs
- iOS app (Swift/UIKit) migrated, builds on simulator + device
- Proof of life: iOS calls both Odin core and C shim through the bridging header
- Odin cross-compiles to iOS static lib via Xcode Run Script → `just build-core-ios`
- Full archive: `docs/sprints/completed/2026-06_monorepo_bootstrap.md`

## Current Sprint: Media Detail View (2026-06-19)
Photos-style detail view as a dedicated `DetailViewController` — custom transition, pinch-zoom, AVPlayer video, tap-toggle tool chrome (all v1 tools stubbed), pan-driven metadata panel. Stubs the core job API to prove the one-way poll wiring. See `todo.md`.

### v1 Roadmap
- **Alpha** (shareable): gallery + detail view + image compress/convert + video playback/compress/convert + save/share. iOS = all platform APIs, no ffmpeg.
- **Beta** (competitive): trim + crop/rotate + metadata view + strip location/EXIF. Editing stop line: crop, rotate, trim.
- **Release**: onboarding, edge cases (Live Photos/HDR), perf/battery, store assets.
- Bulk editing deferred to fast-follow (job system built addressable for it).

### Settled Architecture (docs/references/architecture.md)
- Core is the platform layer, UI is the game: UI relays intent, core owns all logic + calls platform codecs (VideoToolbox/ImageIO on Apple, ffmpeg elsewhere).
- Async job system: addressable jobs + queue + one worker (N later for bulk). One-way calls — UI polls per frame (`CADisplayLink` on iOS), core never calls up.

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
