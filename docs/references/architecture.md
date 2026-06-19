# Architecture — Squeeze

## Monorepo Layout

One repo, one commit touches everything. No git submodules.

```
squeeze/
├── core/           shared C + Odin library
├── desktop/        Odin + SDL3 desktop app
├── ios/            Swift UIKit iOS app (thin shell)
├── ext/            shared vendored dependencies
├── docs/
├── justfile
└── todo.md
```

## Core — The Portable Heart

`core/` is pure C + Odin. Zero platform imports, zero framework dependencies. This is the code that runs everywhere.

```
core/
├── shim/
│   ├── ffmpeg_shim.c/h     clean API over libav* (decode, probe, mux/demux)
│   └── vt_shim.c/h         VideoToolbox wrapper (if Odin foreign isn't clean enough)
├── thumb_cache.c/h          LRU, fixed capacity, explicit memory budget
├── compress.odin            dispatch interface (function pointers)
├── compress_ffmpeg.odin     desktop backend (links libav*)
├── compress_vt.odin         iOS/macOS backend (VideoToolbox)
└── probe.odin               metadata extraction
```

### Rules

- No Swift, no ObjC, no platform frameworks in core.
- C shim wraps gnarly APIs (ffmpeg structs, etc.) so Odin sees a clean interface.
- VideoToolbox is a pure C API — try Odin `foreign` bindings first. Fall back to a C shim only if the bindings get ugly.
- Memory: arenas in C, context allocators in Odin. No scattered malloc/free.

### The C Shim Pattern

Complex C libraries (ffmpeg especially) have deeply nested structs, macros, and initialization rituals. Instead of mirroring all of that in Odin bindings, we write a thin C file that:

1. Includes the library headers
2. Exposes a flat, clean API of plain functions
3. Hides the internal structs behind opaque pointers or copies data into simple output structs

This is proven in `vdbg_player`'s `vd.c/h`. The shim is ~200-400 lines of C. The Odin side sees ~20 function signatures.

## Desktop — Odin + SDL3

`desktop/` is a pure Odin application using SDL3 for windowing, input, and GPU rendering. It links `core/` as a static library.

- Custom UI built with SDL3 (scroll views, clip rects, etc.)
- GPU-accelerated rendering with compiled shaders
- ffmpeg backend at compile time
- Imports from `ext/` for SDL3 bindings and other shared deps

## iOS — Thin Swift Shell

`ios/` is a UIKit app written in Swift. It exists because Apple's platform APIs (PhotoKit, StoreKit, app lifecycle) require it. Everything else goes through core.

```
ios/
├── SqueezeApp.swift              @main entry point (~20 lines)
├── PhotoLibrary.swift            PhotoKit: permissions, asset enumeration, change observers
├── GalleryViewController.swift   UIKit collection view, feeds thumbs from core's cache
├── Squeeze-Bridging-Header.h     exposes core's C API to Swift
├── Assets.xcassets
└── Squeeze.xcodeproj
```

### What stays in Swift

- PhotoKit access (PHAsset enumeration, permissions, change observers)
- App lifecycle (UIApplicationDelegate)
- UIKit views (UICollectionView, UIViewController)
- StoreKit (monetization)
- System share sheets

### What goes to core

- Thumbnail caching (own LRU in C, not NSCache)
- Image decoding/encoding
- Video processing (VideoToolbox, compression)
- Metadata extraction and probing
- Any business logic

### Bridge pattern

Swift calls into core through the bridging header. Core's C shim exposes functions like:

```c
ThumbCache* thumb_cache_create(int capacity, size_t memory_budget);
void thumb_cache_insert(ThumbCache* cache, const char* key, const uint8_t* pixels, int w, int h);
const uint8_t* thumb_cache_get(ThumbCache* cache, const char* key, int* w, int* h);
```

Swift sees these as global C functions. No wrappers needed.

### Why UIKit, not SwiftUI

- UIKit is closer to the metal — `UICollectionView` has prefetch APIs, fine-grained cell control, and proven performance for media grids.
- SwiftUI's reactive model (body recomputation, diffing) adds overhead and unpredictability we don't want.
- UIKit view controllers can call C functions directly through the bridging header.

## Shared Dependencies — ext/

`ext/` holds vendored dependencies that may be used by multiple targets:

```
ext/
├── sdl3/           SDL3 Odin bindings
├── ffmpeg/         ffmpeg headers + platform libs
└── ...
```

Desktop and core import from `ext/` via relative paths. iOS ignores `ext/` — it uses system frameworks.

## Build

### Desktop + Core

Justfile wrapping `odin build` and `cc`/`clang`:

- `just build` — build desktop app (compiles core C shim + Odin, links SDL3 + ffmpeg)
- `just run` — build and run
- `just build-ios-shim` — compile core C files for arm64-iphoneos (if ever needed separately)

### iOS

Xcode project in `ios/`. Core's C files (`core/shim/*.c`, `core/thumb_cache.c`) are added directly to the Xcode project as source files. Xcode compiles them with the correct target triple, SDK, and flags for iOS.

The same C source compiles twice — once by the justfile for desktop (arm64-macos, linking vendored ffmpeg) and once by Xcode for iOS (arm64-iphoneos, linking system frameworks). Same source, different targets. This is correct.

## Compile-Time Backend Selection

Compression has two backends, selected at compile time:

- `compress_ffmpeg.odin` — desktop. Links libavcodec/libavformat/etc.
- `compress_vt.odin` — iOS/macOS. Calls VideoToolbox directly (pure C API).

Both implement the same interface (function pointer table in `compress.odin`). The consumer doesn't know which backend is active.

## Core Is The Platform Layer (UI Is The Game)

Handmade Hero split: the **UI is the game**, the **core is the platform layer**. The UI expresses *intent* ("convert this HEIC to JPEG", "compress to ~10 MB") and knows nothing about *how*. Core owns every decision — target-size→bitrate math, format selection, preset definitions, quality fallbacks, validation — and calls whatever's best on the current OS:

```
core: convert(asset, .heic, .jpeg)        ← one call site, ALL logic here
  when Darwin    → ImageIO / VideoToolbox  (C/CoreFoundation, via shim)
  when Linux/Win → ffmpeg / imagemagick / whatever is fastest
```

Why: **if Swift decides anything, that decision is stranded on iOS and desktop has to reimplement it.** Push it all into core and both frontends stay dumb — they render and relay intent, nothing more.

This works because the Apple codec APIs are **C-callable**: VideoToolbox is pure C, ImageIO is C/CF. So the shim is real C that core dispatches into — not Swift. (AVFoundation — `AVPlayer`, `AVAssetExportSession` — is Obj-C, so it stays in the UI layer for *playback only*, which is presentation anyway. Video *compression* uses VideoToolbox to keep the logic in core.)

### The one unavoidable platform glue

Data *access* is Apple-specific — PhotoKit/`PHAsset` is an Apple concept. So Swift always does a thin bit: fetch the asset's bytes/URL, hand them to core, write the result back to the library. That's *plumbing, not logic* — no decisions, just "here are the bytes" / "save these bytes." The line: **data access & permissions = thin platform glue; everything else = core.**

## Async — The Job System

Long-running work (compression, conversion) is async. Core owns the **job lifecycle** — start, progress, cancel, done — same as it owns the logic.

```c
typedef uint64_t Job_Id;
typedef enum { JOB_QUEUED, JOB_RUNNING, JOB_DONE, JOB_FAILED, JOB_CANCELLED } Job_State;
typedef struct { Job_State state; float progress; int error_code; /* result */ } Job_Status;

Job_Id     squeeze_submit_convert(const char* src, int from_fmt, int to_fmt);
Job_Status squeeze_poll(Job_Id id);   // pure read, cheap, called every frame
void       squeeze_cancel(Job_Id id);
```

A **job is a value with an id**, and status is **per-job** (never global). Jobs go into a queue; **one worker thread drains it today.** Bulk editing later = bump the worker count from 1 to N — nothing else changes, because status was never global and callers already poll by id. The corner that traps you is a single-job mental model (global status vars, no job identity), *not* the worker count. Addressable jobs + a queue is the cheap prep that leaves the door open with zero speculative machinery.

Concurrency primitives available from C on Apple platforms: pthreads (portable), C11 atomics (`<stdatomic.h>`), GCD/libdispatch (C API), `os_unfair_lock`. Swift's `async/await`/actors are **not** C-callable, so they never appear in core. Core owns a portable thread/job model (Odin `core:thread` + `core:sync`); GCD only shows up at the Apple codec boundary and is absorbed by the shim.

## One-Way Calls (UI Polls, Core Never Calls Up)

**The UI polls core once per frame. Core never calls back into the UI.** Callbacks from platform codecs (e.g. VideoToolbox firing on a GCD queue) land in the *shim* — below the UI boundary — write into the job's status, and stop there. The game is only ever *pulled from*, never *called into*.

Why: a one-way data flow makes the business logic a pure function of state you can test by calling it and reading the result — no mock army reconstructing the logic, no callback spaghetti.

- **Desktop** polls in its existing frame loop for free.
- **iOS** drives polling with a `CADisplayLink` (the frame tick), alive *only while a job runs* — spin up on submit, invalidate on terminal state. Idle = no polling = battery stays sacred.

```odin
// desktop — same poll(), driven by the native loop
for app_running {
    status := squeeze_poll(job_id)
    draw_progress(status.progress)
}
```

The poll fields live directly on the owning view controller (no monitor class — see the flatten-ownership rule in coding_style). The controller's deterministic lifecycle (`viewWillDisappear`) tears down the `CADisplayLink`, which is exactly why no weak-proxy ceremony is needed.

## Data Flow

```
[PhotoKit / filesystem]
        │
        ▼
  [Swift shell / Odin app]   ← platform-specific asset access
        │
        ▼
    [core C API]              ← bridging header / foreign import
        │
        ├── thumb_cache       ← LRU cache, pixel buffers
        ├── probe             ← metadata extraction
        └── compress          ← encode pipeline (ffmpeg or VT backend)
        │
        ▼
  [output file / pixel data]
        │
        ▼
  [UI renders result]         ← SDL3 texture / UIKit image view
```
