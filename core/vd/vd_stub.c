// Included by vd.c; do not compile separately.
#include <stdio.h>
#include "vd_trace.h"

size_t vd_backend_describe(char *buffer, size_t capacity) {
	trace_begin(zone, "vd_backend_describe");
	int length = snprintf(buffer, capacity, "stub (no decoding backend)");
	trace_end(zone);
	if (length < 0) {
		if (capacity > 0) {
			buffer[0] = '\0';
		}
		return 0;
	}
	return (size_t)length;
}

void vd_hello(void) {
	trace_begin(zone, "vd_hello");
	printf("[VD] backend unavailable (stub build)\n");
	trace_end(zone);
}
