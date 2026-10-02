# Project-Local Odin SDL3 Bindings

Snapshot of the installed Odin `vendor/sdl3/*.odin` bindings from
`dev-2026-09-nightly:a2fb372`. These declare the **3.4.2** API; the vendored SDL3
**3.4.4** is a compatible patch update. Original Odin `LICENSE` is retained.
Upstream: https://github.com/odin-lang/Odin/tree/a2fb372/vendor/sdl3

Import this package as `import sdl "ext:odin-sdl3"`. The `ext` collection points
to the repository's `ext/` directory; `justfile` supplies it to Odin build/check/run
commands. In CLion, mark `ext/` as a Collection Source Root named `ext`.

Only `sdl3__foreign.odin` differs from the imported binding sources:
- Require macOS arm64, our current supported target.
- Import `../../build/desktop/libSDL3.a` explicitly, instead of `system:SDL3`.

The SDK's system import cannot be redirected with a binding configuration define.
Odin's macOS linker searches Homebrew before extra library paths, so merely adding
`-L` would not reliably select our archive. This small pinned snapshot avoids both
that fallback and modifications to the installed SDK. It is not a new hand-written
SDL API layer.

Update this snapshot deliberately when updating SDL APIs; preserve the local
foreign import, review upstream declaration changes, and run Debug/Release C and
Odin smoke tests plus a desktop build. The binding constants intentionally report
the snapshot's API version; `SDL_GetVersion()` reports the actual linked 3.4.4.

No SDL headers or prebuilt libraries from the Odin SDK are copied. The optional
Vulkan binding declarations still refer to Odin's `vendor:vulkan` types; the local
SDL build disables Vulkan and does not link any Vulkan implementation.

See [SDL build notes](../SDL3.README.md).
