#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void vd_hello();

// Describes the linked decoding backend and its library versions, as queried at
// runtime. Writes a NUL-terminated string into caller-owned storage, truncating if
// needed. Returns the full description length excluding the NUL, like snprintf;
// a result >= capacity means it was truncated.
size_t vd_backend_describe(char *buffer, size_t capacity);

#ifdef __cplusplus
}
#endif
