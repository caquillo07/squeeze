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
