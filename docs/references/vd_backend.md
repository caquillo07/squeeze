# VD — Backend Boundary and Vendored Build

**Status:** FFmpeg/stub selection, vendored static build, archive composition, and
smoke tests implemented on macOS arm64. Decoder API/playback remain unimplemented.
See [vendored source/build notes](../../ext/ffmpeg.README.md).

## Contract

Apps depend on `core/vd/vd.h` and link one artifact: `libvd.a`.
FFmpeg and platform codec APIs are private implementation details. Keep complexity
at the lowest scope that needs it; neither Odin nor Swift knows which decoder is active.

The public C API will expose:
- An opaque decoder handle; explicit open/close and ownership.
- Decode-next-frame with distinct frame-ready, end-of-stream, and error statuses.
- Dimensions, pixel layout, row pitch, and timestamps with explicit units.
- Useful errors for unavailable backends and unsupported media.

No FFmpeg structs, enums, headers, or platform types cross this boundary. Our own
buffers use arenas or caller-owned storage; backend-owned resources are released
through the backend's matching APIs. Document pixel-buffer lifetime and capacity.
Exact signatures are deferred until the first-frame implementation.

## Compile-Time Selection

Layout:

```text
core/vd/
    vd.h              backend-neutral public API
    vd.c              backend selection; only compilation entry point
    vd_ffmpeg.c       private FFmpeg implementation
    vd_stub.c         backend-unavailable implementation
    tests/            public and backend-private smoke tests
```

```c
#if defined(VD_BACKEND_FFMPEG) && defined(VD_BACKEND_STUB)
#error "Select exactly one VD backend"
#elif defined(VD_BACKEND_FFMPEG)
#include "vd_ffmpeg.c"
#elif defined(VD_BACKEND_STUB)
#include "vd_stub.c"
#else
#error "Select a VD backend"
#endif
```

Implementation files are included by `vd.c`, **not compiled independently**.
Build systems, including Xcode, must not glob them as separate source files.
Both builds export the same public symbols and use the same library name.
The stub builds without FFmpeg and returns backend-unavailable, never fake success.

A future native backend uses the same boundary. VideoToolbox alone does not replace
file demuxing; the Apple backend also needs container/sample access. Runtime backend
selection is deferred: no registry or function-pointer dispatch until needed.
Backend-neutral does not guarantee identical codec support. Capability queries are
added only when a real consumer needs them.

## One Library Upwards

FFmpeg headers are visible only while compiling the C implementation. Odin foreign
imports and the Swift bridging header expose only VD's API.

For the FFmpeg build, combine the shim object and required FFmpeg archive members
into a self-contained `libvd.a`. On macOS use `libtool -static`; do not put nested
`.a` files inside another archive. Use the appropriate archive tool on other targets.

The final linker must resolve backend symbols, but apps do not manage a list of
FFmpeg libraries. Platform SDK frameworks/system libraries remain explicit target
build requirements; a static archive does not bundle the OS. Future backend-specific
link requirements stay in the VD build integration, not application source.

## Vendoring Policy

- Commit actual source under `ext/ffmpeg/`; no submodule or build-time downloads.
- Start with the latest stable release **at import time**, then pin it. Record
  version, upstream URL, source checksum, and license; retain upstream license files.
- No package-manager libraries or implicit system-installed codec dependencies.
  Compiler, build tools, and platform SDKs remain prerequisites.
- Disable external-library autodetection. Any future external dependency must be
  explicitly selected, source-vendored, and license-reviewed.
- Start with GPL and nonfree options disabled. Enabling either later requires an
  explicit license/distribution decision. Static linking still has LGPL obligations.

Initial FFmpeg libraries:
`libavformat`, `libavcodec`, `libavutil`, `libswscale`, `libswresample`.
Disable command-line programs, documentation, unused libraries, and network protocols.
Use built-in demuxers/decoders; no x264/x265 dependency is needed for initial decoding.
Retain only what the first-frame milestone needs, expanding deliberately thereafter.
Platform SDK facilities are allowed explicitly.

Build out-of-tree:

```text
ext/ffmpeg/                    committed source
build/deps/ffmpeg/             configure/build output
build/deps/ffmpeg/install/     generated headers and static libraries
build/desktop/libvd.a          app-facing artifact
```

`just build-ffmpeg` builds the dependency explicitly and incrementally. Normal VD,
test, and desktop builds never build FFmpeg; missing prebuilt artifacts produce an
error telling the user to build it. Stub builds need no FFmpeg artifacts.

The root `CMakeLists.txt` owns the C23 unity build, strict C flags, archive merging,
and all applicable tests. `just build-shim` publishes the archive to
`build/desktop/libvd.a`; `just smoke-vd` builds/runs tests under `build/vd/debug/`
or `build/vd/release/`.

For CLion, open the root CMake project. Backend implementation files are listed as
header-only sources for IDE visibility, but compiled only through `vd.c`. The
compilation database includes all applicable tests even when building only the
archive. Each configuration has its database in its build directory; CLion uses
the CMake project directly.
Building different targets does not change its contents; selecting a different
backend does. Generated databases contain machine-local paths and are ignored.

`CMakePresets.json` is the shared configuration. A hidden base selects Makefiles,
`/usr/bin/clang`, `~/.local/bin/make`, the macOS SDK, arm64, and FFmpeg. `vd-debug`
and `vd-release` select Debug and Release in `build/vd/debug/` and
`build/vd/release/`. Each has named configure/build/test presets with descriptions.
`just` uses them. Both configurations keep their binaries and caches.

`CMakeLists.txt` explicitly owns the configuration flags: Debug `-g -O0`, Release
`-O3 -g0 -DNDEBUG`, replacing CMake's compiler-module defaults. Tests keep
assertions enabled in both configurations. Use `just vd_config=release smoke-vd`
or `just vd_config=release build-shim`; the default is Debug. This selector controls
C only, not Odin compilation. Switching configurations reuses that configuration's
existing outputs rather than overwriting the other configuration.

In CLion, select keg's CMake executable and the imported Debug or Release preset.
Both configurations can be enabled, but select only one pairing per configuration.
Disable old independently configured profiles; do not override the preset's toolchain,
generator, or output directory. Terminal and IDE share each configuration's cache;
never run their builds/configures concurrently in the same directory. Use modern GNU Make (verified with
4.4.1); macOS's `/usr/bin/make` 3.81 ignores subsecond dependency timestamps and
can silently reuse stale objects during rapid changes.

`just vd_backend=stub smoke-vd` explicitly overrides the backend in the same cache.
Keep CLion idle during that experiment. The next default configure restores FFmpeg;
reload the IDE project afterwards. No second backend profile/cache is created.
Only `just build-shim` publishes a copy to `build/desktop/libvd.a` for Odin; that
path holds the last requested configuration. Do not publish both concurrently.
SDL is still an existing system dependency until separately vendored; this design
covers the VD boundary, not a claim that the whole application is self-contained yet.

## First Milestone

1. Vendor and build the pinned FFmpeg source.
2. Build the FFmpeg and stub variants of `libvd.a`.
3. Verify desktop links only VD for decoding and the existing test frame still runs.
4. Open a CLI filename, decode one frame, convert to RGBA, and render it.

No audio playback, threading, runtime dispatch, or pacing work in this milestone.
