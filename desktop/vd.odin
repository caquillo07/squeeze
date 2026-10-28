package main

import "core:c"

foreign import vd "../build/desktop/libvd.a"

@(default_calling_convention = "c")
foreign vd {
	vd_hello :: proc() ---

	// Writes a NUL-terminated description into caller-owned storage; returns the full
	// length excluding the NUL (>= capacity means truncated).
	vd_backend_describe :: proc(buffer: [^]u8, capacity: c.size_t) -> c.size_t ---
}
