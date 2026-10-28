package main

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import sdl "ext:odin-sdl3"

WindowAppName :: "vdbg"
WindowWidth :: 1280
WindowHeight :: 720

MainFontSize :: 38

Platform :: struct {
	clock_freq:     f64,
	gpu_renderer:   GPU_Renderer,
	basic_renderer: Basic_Renderer,
	app:            App_State,
	app_input:      App_Input,
	stats:          Run_Stats,

	// fonts - todo(hector) move to...?
	//	main_font:      ^ttf.Font,
}

platform: Platform

main :: proc() {
	platform_close_started_at: u64
	// First: names the main thread before any zone. The Tracy client itself starts at load.
	trace_init()
	platform_init_at := time_now()

	defer {
		// too lazy to come up with somehting better, but good enough for now.
		platform_close_ended_at := time_now()
		lifecycle_record(.Platform_Teardown, platform_close_started_at, platform_close_ended_at)
		print_run_report(&platform.stats)

		// meh, wont get counted, fix later
		log.destroy_console_logger(context.logger)
	}
	vd_hello()

	platform.clock_freq = f64(sdl.GetPerformanceFrequency())

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
	// Tracy Memory view: each arena is a named pool (unwrapped when Tracy is off).
	tracked_permanent, tracked_scratch: Tracked_Arena
	context.allocator = tracked_arena_allocator(&tracked_permanent, permanent_allocator, "permanent")
	context.temp_allocator = tracked_arena_allocator(&tracked_scratch, scratch_allocator, "scratch")

	context.logger = log.create_console_logger()

	// Track arena usage, and growth so we can tune initial sizes
	arena_stats_init(&platform.stats.permanent_arena, &permanent_arena)
	arena_stats_init(&platform.stats.scratch_arena, &scratch_arena)


	run_info_capture_backend(&platform.stats.info)
	log.infof("Permanent arena: %s reserved", format_bytes(permanent_arena.total_reserved))
	log.infof("Scratch arena: %s reserved", format_bytes(scratch_arena.total_reserved))

	// Init SDL
	_ctx := context
	sdl.SetLogPriorities(.VERBOSE when ODIN_DEBUG else .INFO)
	sdl.SetLogOutputFunction(sdl_log_output_proc, &_ctx)
	if !sdl.Init({.VIDEO, .AUDIO}) {
		log_sdl_fatal("failed to init SDL")
	}

	platform.stats.info.sdl_version = sdl.GetVersion()
	platform.stats.info.sdl_revision = string(sdl.GetRevision())

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

	// clear the temp arena so we can start the app loop fresh; sample its use first
	arena_stats_sample(&platform.stats.scratch_arena, &scratch_arena, 0)
	vmem.arena_temp_end(temp_scratch_arena)
	vmem.arena_check_temp(&scratch_arena)

	//	platform.main_font = ttf.OpenFont("fonts/JetBrainsMono-Medium.ttf", MainFontSize)
	//	if platform.main_font == nil {
	//		log_sdl_fatal("failed to open main font")
	//	}

	platform_init_ended_at := time_now()
	lifecycle_record(.Platform_Startup, platform_init_at, platform_init_ended_at)

	// Main loop and Frame timing
	// todo(hector) - make these timings be scope based as well, like niice
	app_init(&platform.app)

	// make dummy frame data to test the renderer
	pixels := make([]byte, WindowWidth * WindowHeight * 4)
	for row := 0; row < WindowHeight; row += 1 {
		for col := 0; col < WindowWidth; col += 1 {
			i := (row * WindowWidth + col) * 4
			pixels[i + 0] = 255
			pixels[i + 1] = 100
			pixels[i + 2] = 68
			pixels[i + 3] = 255
		}
	}
	platform.stats.info.workload = fmt.aprintf("synthetic solid-color frame, %d×%d RGBA", WindowWidth, WindowHeight)

	app_init_ended_at := time_now()
	lifecycle_record(.App_Setup, platform_init_ended_at, app_init_ended_at)
	platform.stats.loop_started_at = app_init_ended_at

	last_frame_counter := app_init_ended_at
	app_running, global_pause := true, false
	dt: f64
	for app_running {

		// Measure frame time. Stages (see trace.odin) feed the run report and Tracy.
		now := time_now()
		dt = elapsed_from(last_frame_counter, now)
		frame_num := frame_begin(now, last_frame_counter)
		last_frame_counter = now

		// Process input events
		input := stage_begin(.Input)
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
		stage_end(input)

		if button_is_pressed(platform.app_input.buttons[.GlobalGamePause]) {
			global_pause = !global_pause
		}

		// App update
		previous_debug_mode := platform.app.debug_mode
		previous_vsync_mode := platform.app.vsync
		if !global_pause {
			stage_scope(.App_Update)
			app_update_and_render(
				&platform.app,
				&platform.app_input,
				dt,
				platform.gpu_renderer.pixel_width,
				platform.gpu_renderer.pixel_height,
			)
		} else {
			platform.stats.paused_frames += 1
		}

		if global_pause && is_key_pressed(&platform.app_input, .Cancel) {
			app_running = false
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

		{
			stage_scope(.Texture_Upload)
			sdl.UpdateTexture(platform.basic_renderer.video_texture, nil, raw_data(pixels), WindowWidth * 4)
		}
		{
			stage_scope(.Render_Commands)
			sdl.SetRenderDrawColor(platform.basic_renderer.renderer, 0, 0, 0, 255)
			sdl.RenderClear(platform.basic_renderer.renderer)
			sdl.RenderTexture(platform.basic_renderer.renderer, platform.basic_renderer.video_texture, nil, nil)
		}
		{
			stage_scope(.Present)
			sdl.RenderPresent(platform.basic_renderer.renderer)
		}

		// Sample arenas before the scratch reset. Growth means our initial sizes were too small.
		permanent_reserved := platform.stats.permanent_arena.reserved
		if arena_stats_sample(&platform.stats.permanent_arena, &permanent_arena, frame_num) {
			log.warnf(
				"Permanent arena grew: %s -> %s",
				format_bytes(permanent_reserved),
				format_bytes(permanent_arena.total_reserved),
			)
		}

		scratch_reserved := platform.stats.scratch_arena.reserved
		if arena_stats_sample(&platform.stats.scratch_arena, &scratch_arena, frame_num) {
			log.warnf(
				"Scratch arena grew: %s -> %s",
				format_bytes(scratch_reserved),
				format_bytes(scratch_arena.total_reserved),
			)
		}

		trace_plot_bytes("permanent_used", permanent_arena.total_used)
		trace_plot_bytes("scratch_used", scratch_arena.total_used)

		// Wipe scratch — everything allocated this frame is gone
		free_all(context.temp_allocator)
	}
	platform.stats.loop_ended_at = time_now()
	run_info_capture_display(&platform.stats.info, platform.basic_renderer.window, platform.basic_renderer.renderer)
	platform_close_started_at = time_now()
}

time_now :: proc() -> u64 {
	return u64(sdl.GetPerformanceCounter())
}

elapsed_ms :: proc(start: u64) -> f64 {
	return elapsed(start) * 1000.0
}

elapsed_from_ms :: proc(start, end: u64) -> f64 {
	return elapsed_from(start, end) * 1000.0
}

elapsed :: proc(start: u64) -> f64 {
	return f64(sdl.GetPerformanceCounter() - start) / platform.clock_freq
}

elapsed_from :: proc(start, end: u64) -> f64 {
	return f64(end - start) / platform.clock_freq
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
