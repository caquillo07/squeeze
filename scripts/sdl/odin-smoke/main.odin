package main

import "core:fmt"
import sdl "ext:odin-sdl3"

main :: proc() {
	assert(sdl.GetVersion() >= sdl.VERSION, "SDL library is older than the pinned bindings")
	assert(sdl.Init({}), "SDL_Init failed")
	defer sdl.Quit()
	assert(sdl.GetPerformanceFrequency() > 0, "SDL clock frequency unavailable")
	assert(sdl.GetPerformanceCounter() > 0, "SDL clock counter unavailable")

	surface := sdl.CreateSurface(2, 2, .RGBA32)
	assert(surface != nil, "SDL_CreateSurface failed")
	defer sdl.DestroySurface(surface)
	assert(surface.w == 2 && surface.h == 2, "SDL surface layout mismatch")
	assert(surface.format == .RGBA32 && surface.pitch >= 8, "SDL pixel layout mismatch")
	assert(surface.pixels != nil, "SDL surface has no pixel storage")
	fmt.printf("Odin → local SDL %d: clock and surface bindings OK\n", sdl.GetVersion())
	return
}
