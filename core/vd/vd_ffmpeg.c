// Included by vd.c; do not compile separately.
#include <stdio.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>

size_t vd_backend_describe(char *buffer, size_t capacity) {
	unsigned avformat = avformat_version();
	unsigned avcodec = avcodec_version();
	unsigned avutil = avutil_version();
	unsigned swscale = swscale_version();
	unsigned swresample = swresample_version();
	int length = snprintf(
		buffer,
		capacity,
		"FFmpeg %s (avformat %u.%u.%u, avcodec %u.%u.%u, avutil %u.%u.%u, "
		"swscale %u.%u.%u, swresample %u.%u.%u)",
		av_version_info(),
		AV_VERSION_MAJOR(avformat), AV_VERSION_MINOR(avformat), AV_VERSION_MICRO(avformat),
		AV_VERSION_MAJOR(avcodec), AV_VERSION_MINOR(avcodec), AV_VERSION_MICRO(avcodec),
		AV_VERSION_MAJOR(avutil), AV_VERSION_MINOR(avutil), AV_VERSION_MICRO(avutil),
		AV_VERSION_MAJOR(swscale), AV_VERSION_MINOR(swscale), AV_VERSION_MICRO(swscale),
		AV_VERSION_MAJOR(swresample), AV_VERSION_MINOR(swresample), AV_VERSION_MICRO(swresample)
	);
	// snprintf only fails on encoding errors; report an empty description rather than a negative size.
	if (length < 0) {
		if (capacity > 0) {
			buffer[0] = '\0';
		}
		return 0;
	}
	return (size_t)length;
}

void vd_hello() {
	printf("[VD] FFmpeg %s (%s)\n", av_version_info(), avutil_license());
	printf(
		"[VD] avformat=%u avcodec=%u avutil=%u swscale=%u swresample=%u\n",
		avformat_version(),
		avcodec_version(),
		avutil_version(),
		swscale_version(),
		swresample_version()
	);
}
