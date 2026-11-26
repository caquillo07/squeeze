# Vendored SDL3

- Version: **3.4.18** (`release-3.4.18-0-g829a65d76`), from `REVISION.txt` and
  `include/SDL3/SDL_version.h`.
- Imported 2026-11-25 from `SDL3-3.4.18.tar.gz`, downloaded by the user from the GitHub
  release page. The detached `.sig` (DSA `1528635D8053A57F77D1E08630A59377A7763BE6`,
  RSA `0900104363B4C9D4223DE149D913FE7D4B61D39B`) was not checked: the signing keys
  could not be fetched. Upstream: https://github.com/libsdl-org/SDL
- Archive SHA-256: `9c75cf16330322c217dedd2e0609f1124f1b54b8633e763467b4684d0f4334a3`.
- Extracted under `ext/SDL3/` with the top-level archive directory stripped, after
  removing the previous tree so files dropped upstream do not linger.
- Extraction keeps the release's file mtimes, which can predate existing objects, so
  make skips the new sources. After replacing the source, delete `build/deps/sdl/`
  before `just build-sdl`; the C smoke test fails on a stale archive.
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

`just check-sdl-bindings` fails when `include/SDL3/SDL_version.h` and the Odin
bindings' `sdl3_version.odin` declare different versions; `prepare-sdl` runs it, so
every desktop build, check, and Odin smoke test does. Update both together.

C smoke tests check header/library version identity, a clock, a surface allocation,
and shadercross initialization/formats. Odin smoke tests check that the
linked library version equals the bindings' version, exercise the pinned bindings,
and inspect surface fields. Debug source lookup is verified in the linked
desktop binary; live GUI/Metal rendering and CLion stepping remain user checks.

See [Odin SDL bindings](odin-sdl3/README.md) and
[desktop debugging](../docs/references/desktop_debugging.md).
