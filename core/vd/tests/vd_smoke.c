#include "vd.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

// Set by CMake from VD_BACKEND, so a stale archive for the other backend fails here.
#ifndef VD_SMOKE_EXPECTED_PREFIX
#error "Define VD_SMOKE_EXPECTED_PREFIX"
#endif

int main(void) {
	vd_hello();

	char description[512];
	size_t length = vd_backend_describe(description, sizeof(description));
	assert(length > 0 && length < sizeof(description));
	assert(strlen(description) == length);
	assert(strncmp(description, VD_SMOKE_EXPECTED_PREFIX, strlen(VD_SMOKE_EXPECTED_PREFIX)) == 0);

	// Truncation: still NUL-terminated, and reports the full length.
	char small[8];
	size_t full_length = vd_backend_describe(small, sizeof(small));
	assert(full_length == length);
	assert(strlen(small) == sizeof(small) - 1);

	printf("[VD] backend: %s\n", description);
	return 0;
}
