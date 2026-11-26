// Included by vd.c (FFmpeg backend); do not compile separately.
#include <stdatomic.h>
#include <stdlib.h>
#include "vd_trace.h"

// FFmpeg's heap. FFmpeg is configured with --malloc-prefix=vd_ (scripts/build_ffmpeg.sh),
// so libavutil/mem.c calls these instead of libc. They forward to the system allocator,
// count for vd_heap_stats_get, and report to Tracy as pool "ffmpeg" when VD_TRACY.
// Called from FFmpeg's threads: atomics only.
//
// mem.c also declares vd_malloc and vd_memalign, but never calls them: av_malloc uses
// posix_memalign (configure requires aligned allocation with asm), av_realloc uses
// realloc, av_free uses free. If FFmpeg ever starts calling them, the final link fails
// with an undefined symbol instead of silently falling back.

// Usable size of a system-allocator block (>= requested); free() receives no size.
#if defined(__APPLE__)
#include <malloc/malloc.h>
#define vd_block_size(block) malloc_size(block)
#elif defined(__linux__)
#include <malloc.h>
#define vd_block_size(block) malloc_usable_size(block)
#else
#error "vd_block_size: unsupported platform"
#endif

#define VD_FFMPEG_POOL "ffmpeg"

static struct {
	_Atomic uint64_t allocations;
	_Atomic uint64_t frees;
	_Atomic uint64_t live_bytes;
	_Atomic uint64_t peak_live_bytes;
	_Atomic uint64_t total_bytes;
} vd_ffmpeg_heap;

static void vd_ffmpeg_heap_alloc(void *block, size_t requested) {
	uint64_t bytes = vd_block_size(block);
	atomic_fetch_add_explicit(&vd_ffmpeg_heap.allocations, 1, memory_order_relaxed);
	atomic_fetch_add_explicit(&vd_ffmpeg_heap.total_bytes, bytes, memory_order_relaxed);
	uint64_t live = atomic_fetch_add_explicit(&vd_ffmpeg_heap.live_bytes, bytes, memory_order_relaxed) + bytes;

	// peak = max(peak, live), safe against other threads updating it concurrently.
	uint64_t peak = atomic_load_explicit(&vd_ffmpeg_heap.peak_live_bytes, memory_order_relaxed);
	while (live > peak) {
		// On failure, peak is reloaded with the latest value; retry only while we're larger.
		if (atomic_compare_exchange_weak_explicit(
			&vd_ffmpeg_heap.peak_live_bytes, &peak, live, memory_order_relaxed, memory_order_relaxed
		)) {
			break;
		}
	}

	trace_alloc(block, requested, VD_FFMPEG_POOL);
	(void)requested; // only used by Tracy, which compiles out without VD_TRACY
}

static void vd_ffmpeg_heap_free(void *block) {
	trace_free(block, VD_FFMPEG_POOL);
	atomic_fetch_add_explicit(&vd_ffmpeg_heap.frees, 1, memory_order_relaxed);
	atomic_fetch_sub_explicit(&vd_ffmpeg_heap.live_bytes, vd_block_size(block), memory_order_relaxed);
}

// Signatures from libavutil/mem.c's MALLOC_PREFIX declarations.
int vd_posix_memalign(void **block, size_t alignment, size_t size);
void *vd_realloc(void *block, size_t size);
void vd_free(void *block);

int vd_posix_memalign(void **block, size_t alignment, size_t size) {
	int err = posix_memalign(block, alignment, size);
	if (err == 0 && *block != NULL) {
		vd_ffmpeg_heap_alloc(*block, size);
	}
	return err;
}

void *vd_realloc(void *block, size_t size) {
	// realloc frees the old block on success, so size it first. av_realloc never asks
	// for 0 bytes, and FFmpeg does not require realloc'd memory to stay aligned.
	size_t old_size = block != NULL ? vd_block_size(block) : 0;
	void *result = realloc(block, size);
	if (result == NULL) {
		return NULL; // The original block is untouched and still live.
	}
	if (block != NULL) {
		trace_free(block, VD_FFMPEG_POOL);
		atomic_fetch_add_explicit(&vd_ffmpeg_heap.frees, 1, memory_order_relaxed);
		atomic_fetch_sub_explicit(&vd_ffmpeg_heap.live_bytes, old_size, memory_order_relaxed);
	}
	vd_ffmpeg_heap_alloc(result, size);
	return result;
}

void vd_free(void *block) {
	if (block != NULL) {
		vd_ffmpeg_heap_free(block);
	}
	free(block);
}

bool vd_heap_stats_get(vd_heap_stats *out) {
	out->allocations = atomic_load_explicit(&vd_ffmpeg_heap.allocations, memory_order_relaxed);
	out->frees = atomic_load_explicit(&vd_ffmpeg_heap.frees, memory_order_relaxed);
	out->live_bytes = atomic_load_explicit(&vd_ffmpeg_heap.live_bytes, memory_order_relaxed);
	out->peak_live_bytes = atomic_load_explicit(&vd_ffmpeg_heap.peak_live_bytes, memory_order_relaxed);
	out->total_bytes = atomic_load_explicit(&vd_ffmpeg_heap.total_bytes, memory_order_relaxed);
	return true;
}
