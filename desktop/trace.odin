package main

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

// Names the main thread and configures plots. Call once at startup on the main thread.
trace_init :: proc() {
	tracy.SetThreadName("main")
	tracy.PlotConfig("permanent_used", .Memory, true, true, 0)
	tracy.PlotConfig("scratch_used", .Memory, true, true, 0)
	return
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
	return
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
	return
}

@(deferred_out = trace_end)
trace_scope :: proc(name: string, loc := #caller_location) -> tracy.ZoneCtx {
	return trace_begin(name, loc)
}

trace_plot_bytes :: proc(name: cstring, bytes: uint) {
	tracy.PlotI(name, i64(bytes))
	return
}
