package main

import "base:intrinsics"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import sdl "ext:odin-sdl3"
import tracy "ext:odin-tracy"

// One instrumentation API for the app. A stage feeds both the shutdown report
// (always on) and a Tracy zone (opt-in, compiles to nothing otherwise), so their
// names and boundaries cannot drift. trace_* scopes are Tracy-only detail and can
// nest anywhere, including inside stages.

// Non-overlapping per-frame stages, in execution order. Reported every run.
Stage :: enum {
	// Reset input state and drain SDL events.
	Input,
	// app_update_and_render call only; not executed while paused.
	App_Update,
	// SDL_UpdateTexture call.
	Texture_Upload,
	// Clear and texture draw submission; not GPU execution.
	Render_Commands,
	// SDL_RenderPresent call; may include vsync/compositor waiting.
	Present,
}

// Shared by the report and Tracy zones.
stage_names := [Stage]string {
	.Input           = "input",
	.App_Update      = "app_update",
	.Texture_Upload  = "texture_upload",
	.Render_Commands = "render_commands",
	.Present         = "present",
}

// Session aggregates, summed over every frame.
Frame_Stages :: struct {
	// Loop start to next loop start: pacing, not cost. Skips the first interval,
	// which measures startup instead. Includes paused frames and debugger stops.
	// Attributed to the frame the interval ends at.
	frame_interval: Stage_Stats,
	stages:         [Stage]Stage_Stats,
}

// Names the main thread, configures plots, and hooks SDL's allocator. Call
// first in main, on the main thread, before any SDL call.
trace_init :: proc() {
	sdl_memory_hooks_install()
	tracy.SetThreadName("main")
	tracy.PlotConfig("permanent_used", .Memory, true, true, 0)
	tracy.PlotConfig("scratch_used", .Memory, true, true, 0)
}

Stage_Scope :: struct {
	stage:      Stage,
	started_at: u64,
	zone:       tracy.ZoneCtx,
}

// Starts the frame: counts it, records the previous frame's interval, and marks a
// Tracy frame at the same boundary. Returns the frame number.
frame_begin :: proc(frame_started_at: u64, previous_frame_started_at: u64) -> u64 {
	stats := &platform.stats
	stats.frame_index += 1
	if stats.frame_index > 1 {
		stage_record(&stats.frames.frame_interval, previous_frame_started_at, frame_started_at, stats.frame_index)
	}
	tracy.FrameMark()
	return stats.frame_index
}

// Our clock reads sit outside the zone, so the report includes Tracy's zone cost
// when Tracy is enabled; Tracy's own timing does not include ours.
stage_begin :: proc(stage: Stage, loc := #caller_location) -> Stage_Scope {
	scope := Stage_Scope {
		stage      = stage,
		started_at = time_now(),
	}
	scope.zone = tracy.ZoneBegin(true, tracy.TRACY_CALLSTACK, stage_names[stage], 0, loc)
	return scope
}

stage_end :: proc(scope: Stage_Scope) {
	tracy.ZoneEnd(scope.zone)
	stats := &platform.stats
	stage_record(&stats.frames.stages[scope.stage], scope.started_at, time_now(), stats.frame_index)
}

// Scoped form: ends when the enclosing scope exits.
@(deferred_out = stage_end)
stage_scope :: proc(stage: Stage, loc := #caller_location) -> Stage_Scope {
	return stage_begin(stage, loc)
}

// Tracy-only detail zones; not in the report.
trace_begin :: proc(name: string, loc := #caller_location) -> tracy.ZoneCtx {
	return tracy.ZoneBegin(true, tracy.TRACY_CALLSTACK, name, 0, loc)
}

trace_end :: proc(zone: tracy.ZoneCtx) {
	tracy.ZoneEnd(zone)
}

@(deferred_out = trace_end)
trace_scope :: proc(name: string, loc := #caller_location) -> tracy.ZoneCtx {
	return trace_begin(name, loc)
}

trace_plot_bytes :: proc(name: cstring, bytes: uint) {
	tracy.PlotI(name, i64(bytes))
}

// Stack frames captured per tracked allocation; separate from zones (TRACY_CALLSTACK)
// because allocations are rare and "who allocated this" needs a stack.
ALLOC_CALLSTACK :: #config(SQUEEZE_ALLOC_CALLSTACK, 16)
// Tracy asserts depth < 63 on Windows and libunwind; macOS does not check. Enforce
// the portable range here so a bad just variable fails the build, not a capture.
#assert(ALLOC_CALLSTACK >= 0 && ALLOC_CALLSTACK <= 62, "SQUEEZE_ALLOC_CALLSTACK must be 0..62")
#assert(tracy.TRACY_CALLSTACK >= 0 && tracy.TRACY_CALLSTACK <= 62, "TRACY_CALLSTACK must be 0..62")

// Reports an arena's allocations to Tracy's Memory view as a named pool. Arenas never
// free individually: free_all discards the whole pool. A resize that moves leaves the
// old block live, as the arena does, until the next free_all. Temp-scope rewinds
// (arena_temp_end) bypass the allocator, so their allocations stay listed until then.
Tracked_Arena :: struct {
	backing: mem.Allocator,
	// Tracy identifies pools by this pointer; use a string literal.
	pool:    cstring,
}

// Installed in Debug builds (free guard) and Tracy builds (Memory view). Otherwise
// returns the backing allocator unchanged: no wrapper, no cost.
tracked_arena_allocator :: proc(tracked: ^Tracked_Arena, backing: mem.Allocator, pool: cstring) -> mem.Allocator {
	when !ODIN_DEBUG && !tracy.TRACY_ENABLE {
		return backing
	}
	tracked^ = {
		backing = backing,
		pool    = pool,
	}
	return mem.Allocator{procedure = tracked_arena_allocator_proc, data = tracked}
}

tracked_arena_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	[]byte,
	mem.Allocator_Error,
) {
	tracked := (^Tracked_Arena)(allocator_data)
	// Arenas cannot free individually, so any free is a bug: that memory stays live
	// until free_all. panicf, not assertf: stays on even with -disable-assert.
	if mode == .Free && old_memory != nil {
		fmt.panicf(
			"free() on arena '%s' (%p): arenas only free_all; use free_all or a dedicated allocator",
			tracked.pool,
			old_memory,
			loc = location,
		)
	}
	data, err := tracked.backing.procedure(tracked.backing.data, mode, size, alignment, old_memory, old_size, location)
	if err != nil {
		return data, err
	}
	switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		if data != nil {
			tracy.AllocN(raw_data(data), c.size_t(size), tracked.pool, ALLOC_CALLSTACK)
		}
	case .Resize, .Resize_Non_Zeroed:
		if old_memory != nil && raw_data(data) == old_memory {
			// Grew or shrank in place: same address, new size.
			tracy.FreeN(old_memory, tracked.pool, ALLOC_CALLSTACK)
		}
		if data != nil {
			tracy.AllocN(raw_data(data), c.size_t(size), tracked.pool, ALLOC_CALLSTACK)
		}
	case .Free:
		// Unreachable for arenas: they reject frees, so err above already returned.
		tracy.FreeN(old_memory, tracked.pool, ALLOC_CALLSTACK)
	case .Free_All:
		tracy.MemoryDiscard(tracked.pool)
	case .Query_Features, .Query_Info:
	}
	return data, err
}

// SDL heap: hooks via SDL_SetMemoryFunctions count every SDL allocation for the run
// report (always) and report them to Tracy's Memory view as pool "sdl" (Tracy builds).
// Memory stays in SDL's own allocator; the hooks forward and observe.
// Must run before SDL allocates anything, or a block could be freed through the wrong
// allocator. SDL_GetNumAllocations cannot check this: SDL builds without
// SDL_TRACK_ALLOCATION_COUNT (returns -1), so trace_init must stay first in main.
// Does not see memory Metal/AppKit/CoreAudio allocate internally.
SDL_POOL :: cstring("sdl")

SDL_Memory_Functions :: struct {
	malloc:  sdl.malloc_func,
	calloc:  sdl.calloc_func,
	realloc: sdl.realloc_func,
	free:    sdl.free_func,
}

// Written once before SDL starts any thread; read-only afterwards.
sdl_original_memory: SDL_Memory_Functions
// Updated atomically from any SDL thread.
sdl_heap: Heap_Stats

// Usable size of a system-allocator block (>= requested); free() receives no size.
when ODIN_OS == .Darwin {
	foreign import libsystem "system:System"
	@(default_calling_convention = "c")
	foreign libsystem {
		@(link_name = "malloc_size")
		block_size :: proc(block: rawptr) -> c.size_t ---
	}
} else when ODIN_OS == .Linux {
	foreign import libc_system "system:c"
	@(default_calling_convention = "c")
	foreign libc_system {
		@(link_name = "malloc_usable_size")
		block_size :: proc(block: rawptr) -> c.size_t ---
	}
} else {
	#panic("block_size: unsupported platform")
}

sdl_memory_hooks_install :: proc() {
	o := &sdl_original_memory
	sdl.GetOriginalMemoryFunctions(&o.malloc, &o.calloc, &o.realloc, &o.free)
	// The pinned binding drops SDL_SetMemoryFunctions' bool result (ABI-safe), so
	// confirm by reading the active functions back.
	sdl.SetMemoryFunctions(sdl_traced_malloc, sdl_traced_calloc, sdl_traced_realloc, sdl_traced_free)
	active: SDL_Memory_Functions
	sdl.GetMemoryFunctions(&active.malloc, &active.calloc, &active.realloc, &active.free)
	if active.malloc != sdl_traced_malloc || active.free != sdl_traced_free {
		log.errorf("SDL memory hooks not installed: %s", sdl.GetError())
	}
}

// Hooks run on any SDL thread: atomics only, read-only originals. Tracy's memory
// calls are thread-safe. default_context only satisfies Odin's calling convention:
// nothing here allocates or logs.
sdl_traced_malloc :: proc "c" (size: uint) -> rawptr {
	context = runtime.default_context()
	result := sdl_original_memory.malloc(size)
	if result != nil {
		heap_stats_alloc(&sdl_heap, u64(block_size(result)))
		tracy.AllocN(result, c.size_t(size), SDL_POOL, ALLOC_CALLSTACK)
	}
	return result
}

sdl_traced_calloc :: proc "c" (count: uint, size: uint) -> rawptr {
	context = runtime.default_context()
	result := sdl_original_memory.calloc(count, size)
	if result != nil {
		heap_stats_alloc(&sdl_heap, u64(block_size(result)))
		tracy.AllocN(result, c.size_t(count * size), SDL_POOL, ALLOC_CALLSTACK)
	}
	return result
}

sdl_traced_realloc :: proc "c" (block: rawptr, size: uint) -> rawptr {
	context = runtime.default_context()
	// realloc frees the old block on success, so size it first.
	old_size := u64(block_size(block)) if block != nil else 0
	result := sdl_original_memory.realloc(block, size)
	// On failure the original block is untouched and still live.
	if result != nil {
		if block != nil {
			heap_stats_free(&sdl_heap, old_size)
			tracy.FreeN(block, SDL_POOL, ALLOC_CALLSTACK)
		}
		heap_stats_alloc(&sdl_heap, u64(block_size(result)))
		tracy.AllocN(result, c.size_t(size), SDL_POOL, ALLOC_CALLSTACK)
	}
	return result
}

sdl_traced_free :: proc "c" (block: rawptr) {
	context = runtime.default_context()
	if block != nil {
		heap_stats_free(&sdl_heap, u64(block_size(block)))
		tracy.FreeN(block, SDL_POOL, ALLOC_CALLSTACK)
	}
	sdl_original_memory.free(block)
}

// Whole-run counters for a foreign heap, safe to update from any thread. Byte
// counts are allocator usable sizes (>= requested). Mirrors VD's vd_heap_stats
// exactly (passed to vd_heap_stats_get), so keep the field order and types.
Heap_Stats :: struct {
	allocations:     u64,
	frees:           u64,
	live_bytes:      u64,
	peak_live_bytes: u64,
	total_bytes:     u64,
}

// Same size as C's vd_heap_stats (static_assert in vd.h).
#assert(size_of(Heap_Stats) == 40)

heap_stats_alloc :: proc "contextless" (stats: ^Heap_Stats, bytes: u64) {
	intrinsics.atomic_add_explicit(&stats.allocations, 1, .Relaxed)
	intrinsics.atomic_add_explicit(&stats.total_bytes, bytes, .Relaxed)
	live := intrinsics.atomic_add_explicit(&stats.live_bytes, bytes, .Relaxed) + bytes
	// peak = max(peak, live), safe against other threads updating it concurrently.
	peak := intrinsics.atomic_load_explicit(&stats.peak_live_bytes, .Relaxed)
	for live > peak {
		// On failure, peak is reloaded with the latest value; retry only while we're larger.
		swapped: bool
		peak, swapped = intrinsics.atomic_compare_exchange_weak_explicit(
			&stats.peak_live_bytes,
			peak,
			live,
			.Relaxed,
			.Relaxed,
		)
		if swapped {
			break
		}
	}
}

heap_stats_free :: proc "contextless" (stats: ^Heap_Stats, bytes: u64) {
	intrinsics.atomic_add_explicit(&stats.frees, 1, .Relaxed)
	intrinsics.atomic_sub_explicit(&stats.live_bytes, bytes, .Relaxed)
}
