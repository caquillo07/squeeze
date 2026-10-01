// Included by vd.c; do not compile separately.
#include <stdio.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>

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
