#include "vd.h"

#if defined(VD_BACKEND_FFMPEG) && defined(VD_BACKEND_STUB)
#error "Select exactly one VD backend"
#elif defined(VD_BACKEND_FFMPEG)
#include "vd_ffmpeg.c"
#elif defined(VD_BACKEND_STUB)
#include "vd_stub.c"
#else
#error "Select a VD backend"
#endif
