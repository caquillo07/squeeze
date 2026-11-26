# Project-Local Odin SDL3 Bindings

Snapshot of the installed Odin `vendor/sdl3/*.odin` bindings from
`dev-2026-11-nightly:9a69916`. These declare the **3.4.18** API, matching the vendored
SDL3. Original Odin `LICENSE` is retained.
Upstream: https://github.com/odin-lang/Odin/tree/9a69916/vendor/sdl3

Import this package as `import sdl "ext:odin-sdl3"`. The `ext` collection points
to the repository's `ext/` directory; `justfile` supplies it to Odin build/check/run
commands. In CLion, right-click `ext/` → **Mark Directory as → Odin Collection** (named `ext`).

Only `sdl3__foreign.odin` differs from the imported binding sources:
- Require macOS arm64, our current supported target.
- Import `../../build/desktop/libSDL3.a` explicitly, instead of `system:SDL3`.

The SDK's system import cannot be redirected with a binding configuration define.
Odin's macOS linker searches Homebrew before extra library paths, so merely adding
`-L` would not reliably select our archive. This small pinned snapshot avoids both
that fallback and modifications to the installed SDK. It is not a new hand-written
SDL API layer.

The bindings must declare the same SDL version as `ext/SDL3`; `just check-sdl-bindings`
enforces it. An earlier snapshot declared 3.4.2 against SDL 3.4.4 as a "compatible
patch update", but nothing checked that claim, and SDL patch releases do change
declarations (3.4.16 and 3.4.18 added fields to the pen event structs). Update both
together: copy every `vendor/sdl3/*.odin` from the installed Odin except
`sdl3__foreign.odin`, review the upstream diff, and run Debug/Release C and Odin
smoke tests plus a desktop build.

No SDL headers or prebuilt libraries from the Odin SDK are copied. The optional
Vulkan binding declarations still refer to Odin's `vendor:vulkan` types; the local
SDL build disables Vulkan and does not link any Vulkan implementation.

See [SDL build notes](../SDL3.README.md).
