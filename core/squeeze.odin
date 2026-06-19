package squeeze_core

import "core:c"

@(export)
squeeze_version :: proc "c" () -> cstring {
	return "0.1.0"
}

@(export)
squeeze_add :: proc "c" (a: c.int, b: c.int) -> c.int {
	return a + b
}
