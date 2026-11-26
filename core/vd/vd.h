#pragma once

// Public header: keep it valid C11+ and C++, not only the C23 that builds VD.
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void vd_hello(void);

// Describes the linked decoding backend and its library versions, as queried at
// runtime. Writes a NUL-terminated string into caller-owned storage, truncating if
// needed. Returns the full description length excluding the NUL, like snprintf;
// a result >= capacity means it was truncated.
size_t vd_backend_describe(char *buffer, size_t capacity);

// Whole-run counters for the decoding backend's heap, safe to read at any time.
// Byte counts are allocator usable sizes (>= requested). Mirrored by Heap_Stats in
// desktop/trace.odin.
typedef struct vd_heap_stats {
	uint64_t allocations;
	uint64_t frees;
	uint64_t live_bytes;
	uint64_t peak_live_bytes;
	uint64_t total_bytes;
} vd_heap_stats;
// Odin's Heap_Stats mirrors this layout.
#ifdef __cplusplus
static_assert(sizeof(vd_heap_stats) == 40, "vd_heap_stats layout is shared with Odin");
#else
_Static_assert(sizeof(vd_heap_stats) == 40, "vd_heap_stats layout is shared with Odin");
#endif

// Fills *out and returns true when the backend measures its heap; returns false
// (and zeroes *out) for backends without one, such as the stub.
bool vd_heap_stats_get(vd_heap_stats *out);

#ifdef __cplusplus
}
#endif
