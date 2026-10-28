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

#define trace_begin(zone, name) TracyCZoneN(zone, name, 1)
#define trace_end(zone) TracyCZoneEnd(zone)
