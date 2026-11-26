#pragma once

// Tracy zones for VD, named like the app's Odin trace API (desktop/trace.odin), so C
// and Odin read alike. Zones go to the app's single Tracy client and nest under its
// stages on the same thread. VD-internal: never include from the public vd.h.
//
// Compiles to nothing unless built with VD_TRACY (defines TRACY_ENABLE). Macros, not
// functions: Tracy's cheap path needs a static source location at the call site.
//
//     trace_begin(zone, "send_packet");
//     int err = avcodec_send_packet(decoder, packet);
//     trace_end(zone);
#include <tracy/TracyC.h>

// Only defined when Tracy is enabled.
#if defined(TRACY_CALLSTACK) && (TRACY_CALLSTACK < 0 || TRACY_CALLSTACK > 62)
#error "TRACY_CALLSTACK must be 0..62 (Tracy's portable limit)"
#endif

#ifndef VD_TRACY_ALLOC_CALLSTACK
#define VD_TRACY_ALLOC_CALLSTACK 0
#endif
#if VD_TRACY_ALLOC_CALLSTACK < 0 || VD_TRACY_ALLOC_CALLSTACK > 62
#error "VD_TRACY_ALLOC_CALLSTACK must be 0..62 (Tracy's portable limit)"
#endif

#define trace_begin(zone, name) TracyCZoneN(zone, name, 1)
#define trace_end(zone) TracyCZoneEnd(zone)

// Allocation events for Tracy's Memory view, in a named pool (use a string literal:
// Tracy identifies pools by pointer). Depth matches the app's tracy_alloc_callstack.
#define trace_alloc(ptr, size, pool) TracyCAllocNS(ptr, size, VD_TRACY_ALLOC_CALLSTACK, pool)
#define trace_free(ptr, pool) TracyCFreeNS(ptr, VD_TRACY_ALLOC_CALLSTACK, pool)
