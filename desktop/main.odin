package main

import "base:intrinsics"
import "base:runtime"
import fmt "core:fmt"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import os "core:os"
import sdl "vendor:sdl3"
//import "vendor:sdl3/ttf"

WindowAppName :: "vdbg"
WindowWidth :: 1280
WindowHeight :: 720

MainFontSize :: 38

Debug_Timing :: struct {
	fps:                        f32,
	frame_ms:                   f32,
	platform_init_elapsed:      f32,
	current_frame_pts:          f64,
	current_frame_dts:          f64,
	current_frame_is_key_frame: bool,
}

Platform :: struct {
	gpu_renderer:   GPU_Renderer,
	basic_renderer: Basic_Renderer,
	app:            App_State,
	app_input:      App_Input,
	debug_timing:   Debug_Timing,

	// fonts - todo(hector) move to...?
	//	main_font:      ^ttf.Font,
}

platform: Platform

main :: proc() {
	vd_hello()

	// App memory — growable virtual memory arenas
	// Initial block sizes are our best guess. If they grow, we log it so we can tune.
	// todo - we need a permanet for the app memory and one for the platform,
	//  do this when we get to hot reloading
	//	main_started_at := time_now()
	permanent_arena: vmem.Arena
	if vmem.arena_init_growing(&permanent_arena, 64 * mem.Megabyte) != nil {
		panic("Failed to init permanent arena")
	}
	permanent_allocator := vmem.arena_allocator(&permanent_arena)

	scratch_arena: vmem.Arena
	if vmem.arena_init_growing(&scratch_arena, 16 * mem.Megabyte) != nil {
		panic("Failed to init scratch arena")
	}
	scratch_allocator := vmem.arena_allocator(&scratch_arena)

	// Own all temp memory — tprintf and friends go through our scratch arena
	context.allocator = permanent_allocator
	context.temp_allocator = scratch_allocator

	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	// Track arena sizes so we can warn on growth and tune initial sizes
	permanent_reserved := permanent_arena.total_reserved
	scratch_reserved := scratch_arena.total_reserved
	log.infof("Permanent arena: %s reserved", format_bytes(permanent_reserved))
	log.infof("Scratch arena: %s reserved", format_bytes(scratch_reserved))

	// Init SDL
	_ctx := context
	sdl.SetLogPriorities(.VERBOSE when ODIN_DEBUG else .INFO)
	sdl.SetLogOutputFunction(sdl_log_output_proc, &_ctx)
	if !sdl.Init({.VIDEO, .AUDIO}) {
		log_sdl_fatal("failed to init SDL")
	}
	defer sdl.Quit()

	//	if !ttf.Init() {
	//		log_sdl_fatal("failed to init SDL TTF")
	//	}

	// init renderer and all assets needed, then clear the temp allocator to
	// let the app start fresh.
	temp_scratch_arena := vmem.arena_temp_begin(&scratch_arena)

	// todo init GPU renderer
	basic_renderer_init()
	defer basic_renderer_deinit()

	// clear the temp arena so we can start the app loop fresh
	vmem.arena_temp_end(temp_scratch_arena)
	vmem.arena_check_temp(&scratch_arena)

	//	platform.main_font = ttf.OpenFont("fonts/JetBrainsMono-Medium.ttf", MainFontSize)
	//	if platform.main_font == nil {
	//		log_sdl_fatal("failed to open main font")
	//	}

	// Main loop and Frame timing
	app_init(&platform.app)
	last_frame_counter := time_now()
	app_running, global_pause := true, false
	dt: f32


	// make dummy frame data to test the renderer
	pixels := make([]byte, WindowWidth * WindowHeight * 4)
	for row := 0; row < WindowHeight; row += 1 {
		for col := 0; col < WindowWidth; col += 1 {
			i := (row * WindowWidth + col) * 4
			pixels[i + 0] = 255
			pixels[i + 1] = 0
			pixels[i + 2] = 0
			pixels[i + 3] = 255
		}
	}

	for app_running {

		// Measure frame time
		now := time_now()
		dt = elapsed(last_frame_counter)
		last_frame_counter = now

		platform.debug_timing.frame_ms = dt * 1000.0
		platform.debug_timing.fps = dt > 0 ? 1.0 / dt : 0


		// Process input events
		reset_app_input(&platform.app_input)
		event: sdl.Event
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				app_running = false
			case .WINDOW_FOCUS_LOST:
				// todo
				log.infof("window has lost focus")
			case .WINDOW_MINIMIZED:
				// todo
				log.infof("window has been minimized")
			case .WINDOW_OCCLUDED:
				// todo
				log.infof("window has been occluded")
			case .KEY_DOWN, .KEY_UP:
				// todo: contexts + raw key array (see input_system_spec.md)
				is_down := event.type == .KEY_DOWN
				if !is_down || (is_down && !event.key.repeat) { 	// kind of usesless... but just in case
					for btn in InputAction {
						if event.key.scancode == key_bindings[btn] {
							update_button(&platform.app_input.buttons[btn], is_down)
						}
					}
				}
			case .MOUSE_WHEEL:
				// if using natural scrolling, convert back to regular
				//  todo - not sure if i want this, maybe it can be a setting if
				//   someone else wants/needs it
				scroll := event.wheel.y
				if event.wheel.direction == .FLIPPED do scroll = -scroll
				platform.app_input.mouse_scroll_delta += scroll

			case .MOUSE_MOTION:
				platform.app_input.mouse_position_delta.x += event.motion.xrel
				platform.app_input.mouse_position_delta.y += event.motion.yrel
				platform.app_input.mouse_position = {event.motion.x, event.motion.y}

			case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
				is_down := event.type == .MOUSE_BUTTON_DOWN
				if event.button.button == sdl.BUTTON_LEFT do update_button(&platform.app_input.mouse_left, is_down)
				if event.button.button == sdl.BUTTON_RIGHT do update_button(&platform.app_input.mouse_right, is_down)

			case .WINDOW_PIXEL_SIZE_CHANGED:
				log.info("WINDOW_PIXEL_SIZE_CHANGED event fired")
				new_w := u32(event.window.data1)
				new_h := u32(event.window.data2)
				if new_w > 0 && new_h > 0 {
					//					renderer_resize_viewport(new_w, new_h)
				}
			}
		}

		if button_is_pressed(platform.app_input.buttons[.GlobalGamePause]) {
			global_pause = !global_pause
		}

		// App update
		previous_debug_mode := platform.app.debug_mode
		previous_vsync_mode := platform.app.vsync
		if !global_pause {
			app_update_and_render(
				&platform.app,
				&platform.app_input,
				dt,
				platform.gpu_renderer.pixel_width,
				platform.gpu_renderer.pixel_height,
			)
		} else {
			if is_key_pressed(&platform.app_input, .Cancel) {
				app_running = false
			}
		}

		if platform.app.debug_mode != previous_debug_mode {
			assert(
				sdl.SetWindowRelativeMouseMode(platform.gpu_renderer.window, platform.app.debug_mode),
				"failed to set relative mouse mode",
			)
			log.infof("Debug camera %s", platform.app.debug_mode ? "ON" : "OFF")
		}

		if platform.app.vsync != previous_vsync_mode {
			renderer_enable_vsync(platform.app.vsync)
			log.infof("VSync: %s", platform.app.vsync ? "ON" : "OFF")
		}
		if platform.app.quit_app {
			app_running = false
		}

		sdl.UpdateTexture(platform.basic_renderer.video_texture, nil, raw_data(pixels), WindowWidth * 4)

		sdl.SetRenderDrawColor(platform.basic_renderer.renderer, 0, 0, 0, 255)
		sdl.RenderClear(platform.basic_renderer.renderer)
		sdl.RenderTexture(platform.basic_renderer.renderer, platform.basic_renderer.video_texture, nil, nil)
		sdl.RenderPresent(platform.basic_renderer.renderer)

		// Check for arena growth — means our initial sizes were too small
		if permanent_arena.total_reserved != permanent_reserved {
			log.warnf(
				"Permanent arena grew: %s -> %s",
				format_bytes(permanent_reserved),
				format_bytes(permanent_arena.total_reserved),
			)
			permanent_reserved = permanent_arena.total_reserved
		}
		if scratch_arena.total_reserved != scratch_reserved {
			log.warnf(
				"Scratch arena grew: %s -> %s",
				format_bytes(scratch_reserved),
				format_bytes(scratch_arena.total_reserved),
			)
			scratch_reserved = scratch_arena.total_reserved
		}

		// Wipe scratch — everything allocated this frame is gone
		free_all(context.temp_allocator)
	}

}

time_now :: proc() -> u64 {
	return u64(sdl.GetPerformanceCounter())
}

elapsed_ms :: proc(start: u64) -> f32 {
	return elapsed(start) * 1000.0
}

elapsed :: proc(start: u64) -> f32 {
	return f32(sdl.GetPerformanceCounter() - start) / f32(sdl.GetPerformanceFrequency())
}

format_bytes :: proc(bytes: uint) -> string {
	GB :: 1024 * 1024 * 1024
	MB :: 1024 * 1024
	KB :: 1024
	if bytes >= GB {
		return fmt.tprintf("%.2f GB", f64(bytes) / f64(GB))
	} else if bytes >= MB {
		return fmt.tprintf("%.2f MB", f64(bytes) / f64(MB))
	} else if bytes >= KB {
		return fmt.tprintf("%.2f KB", f64(bytes) / f64(KB))
	}
	return fmt.tprintf("%v B", bytes)
}

log_sdl_warn :: proc(msg: string, location := #caller_location) {
	log.warnf("%s: %s", msg, sdl.GetError(), location = location)
}

log_sdl_error :: proc(msg: string, location := #caller_location) {
	log.errorf("%s: %s", msg, sdl.GetError(), location = location)
}

log_sdl_fatal :: proc(msg: string, location := #caller_location) -> ! {
	log.fatalf("%s: %s", msg, sdl.GetError(), location = location)
	when ODIN_DEBUG {
		intrinsics.debug_trap()
	}
	panic("fatal error encountered", loc = location)
}

sdl_log_output_proc :: proc "c" (
	userdata: rawptr,
	category: sdl.LogCategory,
	priority: sdl.LogPriority,
	message: cstring,
) {
	context = (cast(^runtime.Context)userdata)^
	log.debugf("SDL {} [{}]: {}", category, priority, message)
}
