package sdl3

// Project-local static archive, published from the selected dependency configuration.
#assert(ODIN_OS == .Darwin && ODIN_ARCH == .arm64, "SDL3 build supports macOS arm64 only")
@(export) foreign import lib { "../../build/desktop/libSDL3.a" }