# Architecture — Squeeze

## Current Scope

Desktop/core only, currently built and verified on macOS arm64. The inactive iOS
app and tooling were removed to avoid maintenance rot; Git history preserves the
source. Its plans are deferred under `docs/sprints/deferred/`, not active targets.
Linux support is planned but not implemented or verified.

## Layout

```text
squeeze/
├── core/
│   ├── squeeze.odin        portable exported proof-of-life functions
│   └── vd/
│       ├── vd.h            backend-neutral public C API
│       ├── vd.c            unity compilation entry point
│       ├── vd_ffmpeg.c     private FFmpeg backend
│       ├── vd_stub.c       backend-unavailable implementation
│       └── tests/          VD-owned smoke tests
├── desktop/                Odin + SDL3 application
├── ext/                    vendored dependency source
├── scripts/                explicit dependency-build helpers
├── CMakeLists.txt          C build, flags, archive merge, tests
├── CMakePresets.json       shared terminal / CLion configurations
├── justfile                commands
└── todo.md                 current work
```

## VD Boundary

Application code depends on `vd.h` and one `libvd.a`, not FFmpeg headers, enums,
or library lists. Backend selection is compile-time. `vd.c` includes the selected
implementation; backend files are not independently compiled. Odin only sees the
public C signatures.

FFmpeg objects are merged with the VD unity object into the app-facing static
archive. Backend-specific system requirements stay in the build integration.
Portable policy remains separate from private platform/library calls.

See [VD backend specification](vd_backend.md) for the API boundary, ownership,
vendoring, license policy, and build details. The current API is proof of life;
opening media and decoding frames are not implemented yet.

## Desktop

The desktop app is Odin + SDL3. SDL owns windowing, input, and presentation.
The current loop displays a dummy pixel buffer through SDL's basic renderer;
the GPU-renderer implementation is present but not the active rendering path.
Playback, gallery, processing, and custom UI remain future work.

Odin uses context allocators; our C code uses arenas/caller-owned storage. Resource
allocations performed by backend libraries must use their matching cleanup APIs.

## Dependencies and Build

Vendored FFmpeg source lives in `ext/ffmpeg/`. Its configure/make build is explicit,
out-of-tree, and independent of ordinary VD or Odin builds. The initial configuration
has no external codec libraries, GPL/nonfree options, encoders, or network support.
SDL_gpu_shadercross is also vendored. SDL3 itself is still a system dependency;
its vendoring is future work, not an already satisfied requirement.

```sh
just build-deps                       # explicit dependency builds
just build-shim                       # Debug VD archive, published for Odin
just smoke-vd                         # Debug C tests
just vd_config=release smoke-vd       # Release C tests
just build-desktop                    # C archive + shaders + Odin app
just run-desktop
just clean                            # project outputs; dependencies preserved
just clean-all                        # all build outputs, including dependencies
```

CMake owns only the C island; Odin compilation stays in `justfile`. CLion and the
terminal consume the same presets and tools. Debug/Release each have their own
cache under `build/vd/`; the IDE and terminal share the directory for each configuration.
Only one build/configure process should use a given directory at a time.

## Future Processing Architecture

UI relays intent and presents results; core owns processing policy and backend work.
The planned job API uses addressable jobs with submit/poll/cancel. Desktop polls
from its frame loop; core never calls up into the UI. Jobs, queues, workers,
thumbnail caching, compression, and probing are design plans, not current code.

## Data Flow

```text
filesystem → Odin application → VD C API → private backend
                                  │
                                  └→ pixels/status → SDL presentation
```
