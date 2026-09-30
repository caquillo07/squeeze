#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
source_dir="$root/ext/ffmpeg"
build_dir="$root/build/deps/ffmpeg"
prefix="$build_dir/install"

if [[ $(uname -sm) != "Darwin arm64" ]]; then
    echo "FFmpeg build currently supports macOS arm64 only." >&2
    exit 1
fi
if [[ ! -f "$source_dir/configure" ]]; then
    echo "Missing vendored source: ext/ffmpeg/configure" >&2
    exit 1
fi

mkdir -p "$build_dir"
cd "$build_dir"
flags=(
    --prefix="$prefix"
    --cc=clang --arch=aarch64 --target-os=darwin
    --enable-static --disable-shared
    --disable-autodetect --disable-gpl --disable-nonfree --disable-version3
    --disable-programs --disable-doc --disable-debug --disable-network
    --disable-avdevice --disable-avfilter
    --disable-everything
    --enable-avformat --enable-avcodec --enable-avutil
    --enable-swscale --enable-swresample
    --enable-demuxer=mov --enable-decoder=h264 --enable-parser=h264
    --enable-protocol=file
)
printf '%s\n' "${flags[@]}" > configure.flags.next
if [[ ! -f ffbuild/config.mak ]] || ! cmp -s configure.flags.next configure.flags; then
    "$source_dir/configure" "${flags[@]}"
    mv configure.flags.next configure.flags
else
    rm configure.flags.next
fi
make -j"${FFMPEG_JOBS:-8}"
make install
