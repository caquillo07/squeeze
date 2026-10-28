package main

// Repro: on macOS arm64, Odin procedures do not maintain the frame-pointer chain.
// backtrace() (frame pointers) sees only the innermost frame; libunwind (unwind
// tables) sees all of them. Build: odin build . -debug -out:repro && ./repro

import "core:c"
import "core:fmt"

foreign import libc "system:System"

@(default_calling_convention = "c")
foreign libc {
	backtrace            :: proc(buffer: [^]rawptr, size: c.int) -> c.int ---
	backtrace_symbols_fd :: proc(buffer: [^]rawptr, size: c.int, fd: c.int) ---
	unw_getcontext       :: proc(ctx: rawptr) -> c.int ---
	unw_init_local       :: proc(cursor: rawptr, ctx: rawptr) -> c.int ---
	unw_step             :: proc(cursor: rawptr) -> c.int ---
	unw_get_reg          :: proc(cursor: rawptr, reg: c.int, value: ^u64) -> c.int ---
}

UNW_REG_IP :: -1

@(optimization_mode = "none")
level_3 :: proc() {
	frames: [32]rawptr

	// Frame-pointer walk (what backtrace(), Tracy on macOS, and FP-based samplers use).
	count := backtrace(&frames[0], len(frames))
	fmt.printf("backtrace() returned %d frames (expected: level_3, level_2, level_1, main::main, main, start):\n", count)
	backtrace_symbols_fd(&frames[0], count, 1)

	// Unwind-table walk via Apple libunwind, for comparison. Opaque context/cursor
	// buffers are oversized on purpose.
	ctx: [128]u64
	cursor: [256]u64
	unwound: c.int
	if unw_getcontext(&ctx) == 0 && unw_init_local(&cursor, &ctx) == 0 {
		for unwound < len(frames) && unw_step(&cursor) > 0 {
			ip: u64
			unw_get_reg(&cursor, UNW_REG_IP, &ip)
			frames[unwound] = rawptr(uintptr(ip))
			unwound += 1
		}
	}
	fmt.printf("libunwind (unw_step, starts at the caller) returned %d frames:\n", unwound)
	backtrace_symbols_fd(&frames[0], unwound, 1)
}

@(optimization_mode = "none")
level_2 :: proc() {
	level_3()
}

@(optimization_mode = "none")
level_1 :: proc() {
	level_2()
}

main :: proc() {
	level_1()
}
