// Backend-private smoke test. Apps never include these headers.
#include <assert.h>
#include <stdio.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/frame.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>

int main(void) {
	assert(av_find_input_format("mov") != NULL);
	const AVCodec *codec = avcodec_find_decoder(AV_CODEC_ID_H264);
	assert(codec != NULL);
	AVCodecContext *decoder = avcodec_alloc_context3(codec);
	assert(decoder != NULL);
	assert(avcodec_open2(decoder, codec, NULL) == 0);
	avcodec_free_context(&decoder);

	AVFormatContext *format = avformat_alloc_context();
	assert(format != NULL);
	avformat_free_context(format);
	AVFrame *frame = av_frame_alloc();
	assert(frame != NULL);
	av_frame_free(&frame);

	// Convert one RGB pixel to RGBA; no video decode implementation here.
	struct SwsContext *scale = sws_getContext(
		1,
		1,
		AV_PIX_FMT_RGB24,
		1,
		1,
		AV_PIX_FMT_RGBA,
		SWS_POINT,
		NULL,
		NULL,
		NULL
	);
	assert(scale != NULL);
	uint8_t rgb[64] = {17, 34, 51};
	uint8_t rgba[64] = {0};
	const uint8_t *src[4] = {rgb};
	uint8_t *dst[4] = {rgba};
	int src_stride[4] = {3};
	int dst_stride[4] = {4};
	assert(sws_scale(scale, src, src_stride, 0, 1, dst, dst_stride) == 1);
	assert(rgba[0] == 17 && rgba[1] == 34 && rgba[2] == 51 && rgba[3] == 255);
	sws_freeContext(scale);

	// Convert mono signed-16 PCM to float at the same sample rate.
	AVChannelLayout mono = AV_CHANNEL_LAYOUT_MONO;
	SwrContext *resample = NULL;
	assert(
		swr_alloc_set_opts2(
			&resample,
			&mono,
			AV_SAMPLE_FMT_FLT,
			48000,
			&mono,
			AV_SAMPLE_FMT_S16,
			48000,
			0,
			NULL
		) == 0
	);
	assert(resample != NULL);
	assert(swr_init(resample) == 0);
	int16_t pcm[1] = {16384};
	float samples[1] = {0};
	const uint8_t *audio_src[1] = {(const uint8_t *) pcm};
	uint8_t *audio_dst[1] = {(uint8_t *) samples};
	assert(swr_convert(resample, audio_dst, 1, audio_src, 1) == 1);
	assert(samples[0] == 0.5f);
	swr_free(&resample);

	puts("[VD] all five libraries: allocation/codec/scaling/resampling smoke passed");
	return 0;
}
