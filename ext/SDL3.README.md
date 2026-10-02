# Vendored SDL3

- Version: **3.4.4**, from `CMakeLists.txt` and `include/SDL3/SDL_version.h`.
- Imported from user-supplied `SDL3-3.4.4.tar.gz`; upstream authenticity was not
  independently verified. Upstream: https://github.com/libsdl-org/SDL
- Archive SHA-256: `ee712dbe6a89bb140bbfc2ce72358fb5ee5cc2240abeabd54855012db30b3864`.
- Extracted under `ext/SDL3/` with the top-level archive directory stripped.
- Upstream source is unmodified. Keep `LICENSE.txt` (zlib license), `REVISION.txt`,
  and bundled third-party notices. The original tarball is ignored, not deleted;
  commit extracted source, not a second binary copy.

## Explicit Builds

```sh
just build-sdl                    # Debug SDL3 + shadercross + C smoke test
just vd_config=release build-sdl  # Release SDL3 + shadercross + C smoke test
just smoke-sdl                    # Odin bindings smoke test against Debug artifacts
just vd_config=release smoke-sdl  # Odin bindings against Release artifacts
just build-deps                   # matching FFmpeg and SDL dependencies
just build-desktop                # consumes prebuilt dependencies only
```

macOS arm64 only. Requires CMake/CTest, `/usr/bin/clang`, `/usr/bin/clang++`,
Apple's SDK, and modern GNU Make at `~/.local/bin/make`. No build-time downloads,
external-library discovery, or fallback to a system SDL3. `SDL_JOBS` overrides the
default eight parallel jobs.

The owned CMake project in `scripts/sdl/` builds unmodified SDL3 and the existing
vendored SDL_gpu_shadercross/SPIRV-Cross sources. Shadercross consumes local SDL
headers. Its static archive is merged with the required SPIRV-Cross archive members,
so Odin does not maintain a separate dependency list. DXC and shared libraries are
disabled. Native macOS/Metal/audio/input backends remain enabled; OpenGL, OpenGL ES,
Vulkan, cameras, and optional libusb support are disabled. No Vulkan/MoltenVK or
libusb packages are required.

Debug uses `-g -O0 -fno-omit-frame-pointer` for C, C++, and Objective-C; installation
never strips symbols. Release uses `-O3 -g0 -DNDEBUG`. Outputs/installations are
separate under `build/deps/sdl/{debug,release}/`. The vendored SPIRV-Cross configure
timestamp is stabilized with `SOURCE_DATE_EPOCH=0`; Git discovery is disabled so
vendored sources do not report the enclosing monorepo's revision.

SDL generates its platform link requirements in `sdl3.pc`. Our CMake project extracts
those SDK flags into `install/share/squeeze/odin-link-flags`, adds the platform C++
runtime for shadercross, and rejects unresolved/external package requirements. No
second hand-maintained framework list or pkg-config executable is needed.

`just prepare-sdl` publishes the selected prebuilt SDL3 and shadercross archives
and link flags into `build/desktop/`. It fails on missing artifacts without compiling
anything. Desktop bindings import that SDL3 archive explicitly; no `-lSDL3` search.
Do not publish different configurations concurrently. `vd_config` controls the C
and dependency configurations; Odin desktop compilation currently always uses
`-debug`, even when C/SDL/FFmpeg Release is selected.

C smoke tests check header/library version identity, a clock, a surface allocation,
and shadercross initialization/formats. Odin smoke tests exercise the pinned
bindings and inspect surface fields. Debug source lookup is verified in the linked
desktop binary; live GUI/Metal rendering and CLion stepping remain user checks.

See [Odin SDL bindings](odin-sdl3/README.md) and
[desktop debugging](../docs/references/desktop_debugging.md).
