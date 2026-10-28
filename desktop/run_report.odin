package main

import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"
import "core:strings"
import sdl "ext:odin-sdl3"
import tracy "ext:odin-tracy"

// Build identity, passed by justfile. Values are quoted there because an all-digit
// commit hash would otherwise become an integer define.
BUILD_COMMIT :: #config(SQUEEZE_COMMIT, "unknown")
// Configuration of the C libraries and dependencies: VD, FFmpeg, SDL3, shadercross.
BUILD_DEPS_CONFIG :: #config(SQUEEZE_DEPS_CONFIG, "unknown")
// Tracy client mode selected by justfile: on, startup, or off.
BUILD_TRACY_MODE :: #config(SQUEEZE_TRACY_MODE, "unknown")

// Everything the shutdown report prints. Collected by the code doing the work; no
// report text is written by hand, so the report follows the code as it changes.
Run_Stats :: struct {
	info:            Run_Info,
	lifecycle:       [Lifecycle_Step]Lifecycle_Timing,
	frames:          Frame_Stages,
	// Loop iterations so far; the frame number used for "worst at frame".
	frame_index:     u64,
	paused_frames:   u64,
	loop_started_at: u64,
	loop_ended_at:   u64,
	permanent_arena: Arena_Stats,
	scratch_arena:   Arena_Stats,
}

// Queried at runtime where possible, so the report shows what actually ran.
Run_Info :: struct {
	// Set by the code that creates content; empty means nothing was loaded.
	workload:           string,
	backend_text:       [512]u8,
	backend_length:     int,
	sdl_version:        i32,
	sdl_revision:       string,
	// Renderer/display state is captured when the loop exits, before teardown.
	renderer_name:      string,
	vsync:              i32,
	vsync_known:        bool,
	display_refresh_hz: f32,
}

// Session aggregate for one timed stage. Ticks come from SDL's monotonic performance
// counter: wall-clock time, including any waiting inside the call, not CPU time.
// count == 0 means the stage never ran.
Stage_Stats :: struct {
	count:       u64,
	total_ticks: u64,
	max_ticks:   u64,
	// Frame number where max_ticks happened.
	worst_frame: u64,
}

// One-off timings, in report order. Parents are listed in lifecycle_parents.
Lifecycle_Step :: enum {
	Platform_Startup,
	Basic_Renderer_Setup,
	GPU_Device_Setup,
	GPU_Shader_Setup,
	GPU_Pipeline_Setup,
	App_Setup,
	Platform_Teardown,
}

// Nested steps are included in their parent's time; the report marks them so they
// are not added twice. Keep in sync with where each step is measured.
lifecycle_parents := [Lifecycle_Step]Maybe(Lifecycle_Step) {
	.Platform_Startup     = nil,
	.Basic_Renderer_Setup = .Platform_Startup,
	.GPU_Device_Setup     = .Platform_Startup,
	.GPU_Shader_Setup     = .Platform_Startup,
	.GPU_Pipeline_Setup   = .Platform_Startup,
	.App_Setup            = nil,
	.Platform_Teardown    = nil,
}

lifecycle_names := [Lifecycle_Step]string {
	.Platform_Startup     = "Platform startup",
	.Basic_Renderer_Setup = "Basic renderer setup",
	.GPU_Device_Setup     = "GPU device setup",
	.GPU_Shader_Setup     = "GPU shader setup",
	.GPU_Pipeline_Setup   = "GPU pipeline setup",
	.App_Setup            = "App setup",
	.Platform_Teardown    = "Platform teardown",
}

// Report section for each step, so the report reads in the order things happen.
Lifecycle_Phase :: enum {
	Startup,
	Shutdown,
}

lifecycle_phases := [Lifecycle_Step]Lifecycle_Phase {
	.Platform_Startup     = .Startup,
	.Basic_Renderer_Setup = .Startup,
	.GPU_Device_Setup     = .Startup,
	.GPU_Shader_Setup     = .Startup,
	.GPU_Pipeline_Setup   = .Startup,
	.App_Setup            = .Startup,
	.Platform_Teardown    = .Shutdown,
}

Lifecycle_Timing :: struct {
	ticks:    u64,
	executed: bool,
}

// A growing virtual-memory arena, sampled at defined points: each frame before the
// scratch reset, and before startup's temporary scratch scope ends. Peaks are the
// highest values seen at those points, not necessarily between them.
//   used:      bytes handed out, including alignment padding; skips unused block tails
//   committed: pages made accessible; physical memory only once touched
//   reserved:  address space only. Shrinks again when free_all releases extra blocks
Arena_Stats :: struct {
	initial_reserved: uint,
	reserved:         uint,
	max_reserved:     uint,
	// Times reserved increased between samples: the initial size was too small.
	growth_events:    u64,
	// Times reserved decreased between samples: extra blocks released (e.g. by free_all).
	// Growth and releases rising together means the arena is cycling an overflow block.
	release_events:   u64,
	used:             uint,
	max_used:         uint,
	// Frame of the peak used sample; 0 is startup.
	max_used_frame:   u64,
	committed:        uint,
	max_committed:    uint,
	// Number of arena_stats_sample calls, for the instrumentation cost estimate.
	samples:          u64,
}

// Per-call cost of our own instrumentation, measured in tight loops at exit in the
// running build. Warm caches make these optimistic; scale is what matters.
Instrumentation_Cost :: struct {
	clock_read_ms:   f64,
	stage_record_ms: f64,
	arena_sample_ms: f64,
}

// Hot path: no allocation, formatting, or logging.
stage_record :: proc(stage: ^Stage_Stats, start, end: u64, frame: u64) {
	ticks := end - start
	stage.count += 1
	stage.total_ticks += ticks
	if ticks > stage.max_ticks {
		stage.max_ticks = ticks
		stage.worst_frame = frame
	}
	return
}

lifecycle_record :: proc(step: Lifecycle_Step, start, end: u64) {
	platform.stats.lifecycle[step] = {
		ticks    = end - start,
		executed = true,
	}
	return
}

arena_stats_init :: proc(stats: ^Arena_Stats, arena: ^vmem.Arena) {
	stats^ = {}
	stats.initial_reserved = arena.total_reserved
	stats.reserved = arena.total_reserved
	arena_stats_sample(stats, arena, 0)
	return
}

// Cheap: reads arena fields and walks its few blocks. Returns true when the arena
// reserved more address space since the last sample.
arena_stats_sample :: proc(stats: ^Arena_Stats, arena: ^vmem.Arena, frame: u64) -> (grew: bool) {
	committed: uint
	for block := arena.curr_block; block != nil; block = block.prev {
		committed += block.committed
	}

	grew = arena.total_reserved > stats.reserved
	if grew {
		stats.growth_events += 1
	} else if arena.total_reserved < stats.reserved {
		stats.release_events += 1
	}
	stats.reserved = arena.total_reserved
	stats.max_reserved = max(stats.max_reserved, arena.total_reserved)

	stats.used = arena.total_used
	if arena.total_used > stats.max_used {
		stats.max_used = arena.total_used
		stats.max_used_frame = frame
	}

	stats.committed = committed
	stats.max_committed = max(stats.max_committed, committed)
	stats.samples += 1
	return
}

// Unoptimized on purpose: an optimizing build otherwise folds or hoists the loops'
// redundant work and reports zero. The called procedures stay optimized; the loop
// bookkeeping adds a little, keeping the estimate an upper bound.
@(optimization_mode = "none")
measure_instrumentation_cost :: proc() -> Instrumentation_Cost {
	cost: Instrumentation_Cost

	CLOCK_READS :: 100_000
	sink: u64
	started_at := time_now()
	for _ in 0 ..< CLOCK_READS {
		sink += time_now()
	}
	cost.clock_read_ms = ticks_to_ms(time_now() - started_at) / CLOCK_READS

	STAGE_RECORDS :: 100_000
	stage: Stage_Stats
	started_at = time_now()
	for i in 0 ..< u64(STAGE_RECORDS) {
		stage_record(&stage, i, i + (i & 7), i)
	}
	cost.stage_record_ms = ticks_to_ms(time_now() - started_at) / STAGE_RECORDS

	ARENA_SAMPLES :: 10_000
	arena: vmem.Arena
	if vmem.arena_init_growing(&arena, 1024 * 1024) == nil {
		arena_stats: Arena_Stats
		arena_stats_init(&arena_stats, &arena)
		started_at = time_now()
		for i in 0 ..< u64(ARENA_SAMPLES) {
			arena_stats_sample(&arena_stats, &arena, i)
		}
		cost.arena_sample_ms = ticks_to_ms(time_now() - started_at) / ARENA_SAMPLES
		vmem.arena_destroy(&arena)
	}

	// Keep the loops' results observable so an optimizing build cannot drop them.
	if sink == 0 || stage.count != STAGE_RECORDS {
		fmt.println("(instrumentation measurement loop did not run as expected)")
	}
	return cost
}

run_info_capture_backend :: proc(info: ^Run_Info) {
	length := int(vd_backend_describe(raw_data(info.backend_text[:]), len(info.backend_text)))
	info.backend_length = min(length, len(info.backend_text) - 1)
	return
}

// Call when the loop exits, while the window and renderer still exist.
run_info_capture_display :: proc(info: ^Run_Info, window: ^sdl.Window, renderer: ^sdl.Renderer) {
	info.renderer_name = strings.clone_from_cstring(sdl.GetRendererName(renderer))
	vsync: i32
	info.vsync_known = sdl.GetRenderVSync(renderer, &vsync)
	info.vsync = vsync
	mode := sdl.GetCurrentDisplayMode(sdl.GetDisplayForWindow(window))
	if mode != nil {
		info.display_refresh_hz = mode.refresh_rate
	}
	return
}

ticks_to_ms :: proc(ticks: u64) -> f64 {
	return f64(ticks) / platform.clock_freq * 1000.0
}

print_run_report :: proc(stats: ^Run_Stats) {
	info := &stats.info
	fmt.println("\nSqueeze run report")
	fmt.println(
		"──────────────────────────────────────────────────────────────────────",
	)

	// Run
	fmt.println("Run")
	commit := strings.trim(BUILD_COMMIT, "\"")
	deps_config := strings.trim(BUILD_DEPS_CONFIG, "\"")
	odin_config := "debug" if ODIN_DEBUG else "release"
	optimization := strings.to_lower(fmt.tprintf("%v", ODIN_OPTIMIZATION_MODE), context.temp_allocator)
	fmt.printf("  %-14s %s\n", "Commit", commit)
	fmt.printf(
		"  %-14s Odin %s (%s, -o:%v), C/deps %s\n",
		"Build",
		odin_config,
		ODIN_VERSION_HASH,
		optimization,
		deps_config,
	)
	if ODIN_DEBUG || deps_config != "release" {
		fmt.printf("  %-14s %s\n", "", "Debug code present: timings are not a performance baseline")
	}
	fmt.printf("  %-14s Odin %s, SDL %s", "Toolchain", ODIN_VERSION, format_sdl_version(info.sdl_version))
	if info.sdl_revision != "" {
		fmt.printf(" (%s)", info.sdl_revision)
	}
	fmt.println()
	fmt.printf("  %-14s %s\n", "Decoder", string(info.backend_text[:info.backend_length]))
	when tracy.TRACY_ENABLE {
		tracy_mode := strings.trim(BUILD_TRACY_MODE, "\"")
		collects := "while a viewer is connected" if tracy_mode == "on" else "from launch"
		fmt.printf(
			"  %-14s %s: collects %s, localhost only, callstack depth %d\n",
			"Tracy",
			tracy_mode,
			collects,
			tracy.TRACY_CALLSTACK,
		)
	} else {
		fmt.printf("  %-14s %s\n", "Tracy", "off (not compiled in)")
	}
	workload := info.workload if info.workload != "" else "none loaded"
	fmt.printf("  %-14s %s\n", "Workload", workload)
	renderer := info.renderer_name if info.renderer_name != "" else "not measured"
	fmt.printf("  %-14s %s, vsync %s\n", "Renderer", renderer, format_vsync(info^))
	if info.display_refresh_hz > 0 {
		period_ms := 1000.0 / f64(info.display_refresh_hz)
		fmt.printf(
			"  %-14s %.2f Hz (%s period)\n",
			"Display",
			info.display_refresh_hz,
			strings.trim_space(format_duration_ms(period_ms)),
		)
	} else {
		fmt.printf("  %-14s %s\n", "Display", "refresh rate not measured")
	}
	loop_ms: f64
	if stats.loop_ended_at > stats.loop_started_at {
		loop_ms = ticks_to_ms(stats.loop_ended_at - stats.loop_started_at)
	}
	fmt.printf(
		"  %-14s %s loop, %d frames presented, %d paused\n",
		"Session",
		strings.trim_space(format_duration_ms(loop_ms)),
		stats.frames.stages[.Present].count,
		stats.paused_frames,
	)

	fmt.println("\nStartup")
	print_lifecycle_phase(stats, .Startup)

	// Frames, in the order each stage runs within a frame; the whole frame last.
	frames := &stats.frames
	fmt.println("\nFrames (whole session; wall-clock, includes waiting inside calls)")
	fmt.printf("  %-16s %8s %11s %11s %11s %9s\n", "stage", "count", "total", "mean", "worst", "at frame")
	for stage in Stage {
		print_stage_row(stage_names[stage], frames.stages[stage])
	}
	// Frame mean minus stage means: loop bookkeeping between timed stages. Mean-based
	// because the frame interval has one fewer sample than the stages.
	if frames.frame_interval.count > 0 {
		stages_mean_ms: f64
		for stage in Stage {
			stages_mean_ms += stage_mean_ms(frames.stages[stage])
		}
		untimed_ms := max(stage_mean_ms(frames.frame_interval) - stages_mean_ms, 0)
		fmt.printf("  %-16s %8s  %10s  %s\n", "untimed", "", "", format_duration_ms(untimed_ms))
	}
	fmt.printf(
		"  %s\n",
		"───────────────────────────────────────────────────────────────────────",
	)
	print_stage_row("frame (total)", frames.frame_interval)
	if loop_ms > 0 && frames.stages[.Present].count > 0 {
		present_share := ticks_to_ms(frames.stages[.Present].total_ticks) / loop_ms * 100.0
		fmt.printf("  Inside present: %.0f%% of loop time (includes waiting)\n", present_share)
	}
	fmt.printf("  Timer resolution: %s\n", strings.trim_space(format_duration_ms(1000.0 / platform.clock_freq)))
	print_instrumentation_cost(stats)

	fmt.println("\nShutdown")
	print_lifecycle_phase(stats, .Shutdown)

	// Memory
	fmt.println("\nMemory (arenas sampled each frame, before the scratch reset)")
	fmt.printf(
		"  %-10s %11s %9s %15s %11s %14s %7s %9s\n",
		"arena",
		"peak used",
		"at frame",
		"peak committed",
		"reserved",
		"peak reserved",
		"growth",
		"released",
	)
	print_arena_row("permanent", stats.permanent_arena)
	print_arena_row("scratch", stats.scratch_arena)
	fmt.println("  Committed pages cost physical memory only once touched; reserved is address space.")
	fmt.printf("  %-32s %s\n", "Process footprint", "not measured (use Instruments)")
	fmt.printf("  %-32s %s\n", "GPU memory", "not measured")

	fmt.println("\nNot measured: CPU time (all timings are wall-clock), GPU execution time")

	if os.get_env("SQUEEZE_RAW_STATS", context.temp_allocator) == "1" {
		fmt.println("\nRaw stats (SQUEEZE_RAW_STATS=1; ticks are SDL performance-counter units)")
		fmt.printf("clock_freq = %v\n", platform.clock_freq)
		fmt.printf("lifecycle = %#v\n", stats.lifecycle)
		fmt.printf("frames = %#v\n", stats.frames)
		fmt.printf("permanent_arena = %#v\n", stats.permanent_arena)
		fmt.printf("scratch_arena = %#v\n", stats.scratch_arena)
	}
	return
}

print_lifecycle_phase :: proc(stats: ^Run_Stats, phase: Lifecycle_Phase) {
	for step in Lifecycle_Step {
		if lifecycle_phases[step] != phase {
			continue
		}
		timing := stats.lifecycle[step]
		parent, is_nested := lifecycle_parents[step].?
		indent := "    " if is_nested else "  "
		label := fmt.tprintf("%s%s", indent, lifecycle_names[step])
		if !timing.executed {
			fmt.printf("%-28s %s\n", label, "not executed")
			continue
		}
		duration := format_duration_ms(ticks_to_ms(timing.ticks))
		if is_nested {
			parent_name := strings.to_lower(lifecycle_names[parent], context.temp_allocator)
			fmt.printf("%-28s %s  included in %s\n", label, duration, parent_name)
		} else {
			fmt.printf("%-28s %s\n", label, duration)
		}
	}
	return
}

// Upper-bound estimate: assumes two clock reads per stage record, though consecutive
// stages share boundary timestamps. Counts come from the session, costs from exit.
print_instrumentation_cost :: proc(stats: ^Run_Stats) {
	if stats.frame_index == 0 {
		return
	}
	frames := &stats.frames
	records := frames.frame_interval.count
	for stage in Stage {
		records += frames.stages[stage].count
	}
	samples := stats.permanent_arena.samples + stats.scratch_arena.samples

	cost := measure_instrumentation_cost()
	total_ms := f64(2 * records) * cost.clock_read_ms
	total_ms += f64(records) * cost.stage_record_ms
	total_ms += f64(samples) * cost.arena_sample_ms
	per_frame_ms := total_ms / f64(stats.frame_index)

	fmt.printf("  Instrumentation: ≤ %s per frame", strings.trim_space(format_duration_ms(per_frame_ms)))
	frame_mean_ms := stage_mean_ms(frames.frame_interval)
	if frame_mean_ms > 0 {
		fmt.printf(" (%.3f%% of mean frame)", per_frame_ms / frame_mean_ms * 100.0)
	}
	fmt.println()
	fmt.printf(
		"    per call: clock read %s, stage record %s, arena sample %s\n",
		strings.trim_space(format_duration_ms(cost.clock_read_ms)),
		strings.trim_space(format_duration_ms(cost.stage_record_ms)),
		strings.trim_space(format_duration_ms(cost.arena_sample_ms)),
	)
	return
}

stage_mean_ms :: proc(stage: Stage_Stats) -> f64 {
	if stage.count == 0 {
		return 0
	}
	return ticks_to_ms(stage.total_ticks) / f64(stage.count)
}

print_stage_row :: proc(name: string, stage: Stage_Stats) {
	if stage.count == 0 {
		fmt.printf("  %-16s %s\n", name, "not executed")
		return
	}
	total_ms := ticks_to_ms(stage.total_ticks)
	mean_ms := total_ms / f64(stage.count)
	worst_ms := ticks_to_ms(stage.max_ticks)
	// Pad formatted strings, not numbers: this Odin's fmt zero-pads right-aligned numbers.
	// Durations are already fixed-width; %s width counts bytes, which misaligns "µ".
	count := fmt.tprintf("%d", stage.count)
	worst_frame := fmt.tprintf("%d", stage.worst_frame)
	fmt.printf(
		"  %-16s %8s  %s  %s  %s %9s\n",
		name,
		count,
		format_duration_ms(total_ms),
		format_duration_ms(mean_ms),
		format_duration_ms(worst_ms),
		worst_frame,
	)
	return
}

print_arena_row :: proc(name: string, arena: Arena_Stats) {
	fmt.printf(
		"  %-10s %11s %9s %15s %11s %14s %7s %9s\n",
		name,
		format_bytes(arena.max_used),
		fmt.tprintf("%d", arena.max_used_frame),
		format_bytes(arena.max_committed),
		format_bytes(arena.initial_reserved),
		format_bytes(arena.max_reserved),
		fmt.tprintf("%d", arena.growth_events),
		fmt.tprintf("%d", arena.release_events),
	)
	return
}

format_sdl_version :: proc(version: i32) -> string {
	if version == 0 {
		return "not measured"
	}
	return fmt.tprintf(
		"%d.%d.%d",
		sdl.VERSIONNUM_MAJOR(version),
		sdl.VERSIONNUM_MINOR(version),
		sdl.VERSIONNUM_MICRO(version),
	)
}

// SDL_GetRenderVSync: 0 off, 1 every refresh, N every Nth refresh, -1 adaptive.
format_vsync :: proc(info: Run_Info) -> string {
	if !info.vsync_known {
		return "not measured"
	}
	switch info.vsync {
	case 0:
		return "off"
	case 1:
		return "on"
	case -1:
		return "adaptive"
	}
	return fmt.tprintf("every %d refreshes", info.vsync)
}

// Largest unit whose value is at least 1, always two decimals so decimal points align.
// Fixed width: 10 characters (7-wide number, space, 2-character unit).
format_duration_ms :: proc(ms: f64) -> string {
	value := ms
	unit := "ms"
	if ms >= 1000.0 {
		value = ms / 1000.0
		unit = "s "
	} else if ms < 0.001 {
		value = ms * 1_000_000.0
		unit = "ns"
	} else if ms < 1.0 {
		value = ms * 1000.0
		unit = "µs"
	}
	number := fmt.tprintf("%.2f", value)
	return fmt.tprintf("%7s %s", number, unit)
}
