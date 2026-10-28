// Included by vd.c; do not compile separately.
#include <stdio.h>

size_t vd_backend_describe(char *buffer, size_t capacity) {
	int length = snprintf(buffer, capacity, "stub (no decoding backend)");
	if (length < 0) {
		if (capacity > 0) {
			buffer[0] = '\0';
		}
		return 0;
	}
	return (size_t)length;
}

void vd_hello(void) {
	printf("[VD] backend unavailable (stub build)\n");
	return;
}
