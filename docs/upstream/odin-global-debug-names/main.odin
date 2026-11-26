package main

// Repro: LLDB cannot find Odin globals or types by name, because Odin's DWARF names
// them `main::counter` / `main::Point` flat instead of nesting them in a namespace.
// Build: odin build . -debug -out:repro, then see ISSUE.md for the LLDB commands.

import "core:fmt"

Point :: struct {
	x, y: i32,
}

counter: int
origin: Point

main :: proc() {
	counter = 42
	origin = {3, 4}
	local := origin
	fmt.println(counter, origin, local) // break here
}
