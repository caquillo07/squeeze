# Vendored Tracy (client) and Odin Bindings

- Tracy **0.14.1**: https://github.com/wolfpld/tracy/releases/tag/v0.14.1
- Source archive SHA-256: `bf4af567e9c7524d07f3caa745fad02fb33bd5694f11910750382d1efbb251c1`
  (user-supplied `tracy-0.14.1.tar.gz`; `common/TracyVersion.hpp` reports 0.14.1).
- `ext/tracy/`: only the client sources (`public/`, minus the Fortran wrapper) and
  `LICENSE` (3-clause BSD). Unmodified.
- `ext/odin-tracy/`: `oskarnp/odin-tracy` bindings (linked from Tracy's README),
  targeting Tracy 0.14.1. 3-clause BSD. Local changes:
  - `bindings.odin`: imports `../../build/desktop/libtracy.a` instead of a
    dynamic library, with a macOS arm64 `#assert` when Tracy is enabled.
  - Removed the submodule declaration, empty `tracy/` submodule directory, and the
    upstream dylib build scripts; `scripts/build_tracy.sh` owns the build.

## Usage

```sh
just build-tracy                  # both Debug client modes (-O2 -g); part of build-deps
just vd_config=release build-tracy
just smoke-tracy                  # Odin bindings link + run against the client
just run-desktop                  # Debug: Tracy on, collects while a viewer is connected
just tracy=startup run-desktop    # buffer from launch, to capture startup
just tracy=off run-desktop        # no Tracy code at all
just tracy_callstack=8 run-desktop  # also capture 8 stack frames per zone (costly)
```

Modes (`tracy` just variable; the run report prints the active one):

- **on** (default unless `vd_config=release`): `TRACY_ON_DEMAND`. Collects only while
  a viewer is connected, so no memory grows otherwise; startup is missed unless the
  viewer is already waiting.
- **startup**: buffers from launch until a viewer connects. Memory grows meanwhile.
- **off** (default for `vd_config=release`): `TRACY_ENABLE` is false, the wrappers
  compile to nothing, the client is not linked, no thread starts, no socket opens.

Both enabled modes are built with `TRACY_ONLY_LOCALHOST`: the client listens on
localhost only. The two modes are separate prebuilt archives under
`build/deps/tracy/<config>/<mode>/`; `prepare-tracy` publishes the selected one and
never compiles. Never ship Tracy-enabled builds.

The client is one translation unit compiled with Apple Clang into a static archive
under `build/deps/tracy/{debug,release}/`. Both configurations are optimized (Debug
`-O2 -g`, Release `-O3 -g0`): the profiler should add little per-zone overhead, and
we do not step through its internals. Frame pointers are kept. Only upstream's
`sprintf` deprecation warnings are silenced.

`ZoneBegin` in the bindings allocates a source location per zone. Fine at our zone
counts; revisit for very hot zones.

## App instrumentation

App code never calls Tracy directly; it uses `desktop/trace.odin`:

- `stage_begin(.Input)` / `stage_end(scope)`, or scoped `stage_scope(.Present)`:
  report stages. One call feeds the always-on shutdown report and a Tracy zone with
  the same name and boundaries. Stages are non-overlapping and listed in `Stage`.
- `trace_begin("name")` / `trace_end(zone)`, or scoped `trace_scope("name")`:
  Tracy-only detail zones; nest anywhere, including inside stages.
- `frame_begin` marks the Tracy frame at the report's frame-interval boundary.
- `trace_plot_bytes`: arena used bytes plotted as `permanent_used`, `scratch_used`.

Compare Tracy's zone statistics against the shutdown report; both should agree.

VD's C code uses `core/vd/vd_trace.h`: `trace_begin(zone, "name")` / `trace_end(zone)`,
the same names as the Odin API, as macros over Tracy's C API (static source
locations). Stages stay app-only; VD only adds detail zones, which nest under the
app's stages. CMake option `VD_TRACY` (presets: ON for vd-debug, OFF for vd-release;
`just` passes it from `tracy`) defines `TRACY_ENABLE`; off, the macros vanish.
`libvd.a` only references the client; the app links the single client, and VD tests
link it when `VD_TRACY` is on. Switching Tracy on/off rebuilds the VD unity object.

## Viewer (developer-installed, not vendored)

The viewer must be the **same version (0.14.1)** as the client. Official prebuilt
binaries exist for macOS, Linux, and Windows on the release page; install outside
the repository. On macOS the release binaries are ad-hoc signed and not notarized,
so Gatekeeper reports the quarantined app as "damaged":

```sh
xattr -dr com.apple.quarantine tracy-profiler.app
codesign --force --deep --sign - tracy-profiler.app
```

Homebrew also packages Tracy (`brew install tracy`), but its version may not match
the vendored client. Open the viewer, run `just run-desktop`, and connect.
