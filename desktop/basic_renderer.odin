package main

import log "core:log"
import strings "core:strings"
import sdl "vendor:sdl3"

Basic_Renderer :: struct {
	window:        ^sdl.Window,
	renderer:      ^sdl.Renderer,
	video_texture: ^sdl.Texture,
}

basic_renderer_init :: proc() {
	basic_renderer := &platform.basic_renderer
	app_name := strings.unsafe_string_to_cstring(WindowAppName)
	sdl.CreateWindowAndRenderer(
		app_name,
		WindowWidth,
		WindowHeight,
		{.HIGH_PIXEL_DENSITY, .RESIZABLE},
		&basic_renderer.window,
		&basic_renderer.renderer,
	)

	log.infof("created window and basic renderer")
	log.infof("\tusing renderer backend: %s", sdl.GetRendererName(basic_renderer.renderer))
	log.infof("\twindow size: %v", basic_renderer_window_size())

	textureFormat := sdl.PixelFormat.RGBA32
	basic_renderer.video_texture = sdl.CreateTexture(
		basic_renderer.renderer,
		textureFormat,
		.STREAMING,
		WindowWidth,
		WindowHeight,
	)
	if basic_renderer.video_texture == nil {
		log_sdl_fatal("failed to create video texture")
	}
}

basic_renderer_deinit :: proc() {
	r := &platform.basic_renderer
	sdl.DestroyTexture(r.video_texture)
	sdl.DestroyRenderer(r.renderer)
	sdl.DestroyWindow(r.window)
	sdl.Quit()
}

basic_renderer_window_size :: proc() -> Vec2i {
	v: Vec2i
	if !sdl.GetWindowSize(platform.basic_renderer.window, &v.x, &v.y) {
		log_sdl_fatal("failed to get window size in pixels")
	}
	return v
}
