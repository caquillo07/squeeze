#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
source_dir="$root/ext/ffmpeg"
config="${1:-debug}"
if [[ $# -gt 1 || ( "$config" != debug && "$config" != release ) ]]; then
    echo "Usage: scripts/build_ffmpeg.sh [debug|release]" >&2
    exit 1
fi
build_dir="$root/build/deps/ffmpeg/$config"
prefix="$build_dir/install"
make_program="$HOME/.local/bin/make"

if [[ $(uname -sm) != "Darwin arm64" ]]; then
    echo "FFmpeg build currently supports macOS arm64 only." >&2
    exit 1
fi
if [[ ! -f "$source_dir/configure" ]]; then
    echo "Missing vendored source: ext/ffmpeg/configure" >&2
    exit 1
fi
if [[ ! -x "$make_program" ]]; then
    echo "Missing modern GNU Make: $make_program" >&2
    exit 1
fi

mkdir -p "$build_dir"
cd "$build_dir"
flags=(
    --prefix="$prefix"
    --cc=/usr/bin/clang --arch=aarch64 --target-os=darwin
    --enable-static --disable-shared
    --disable-autodetect --disable-gpl --disable-nonfree --disable-version3
    --disable-programs --disable-doc --disable-network
    --disable-avdevice --disable-avfilter
    --disable-everything
    --enable-avformat --enable-avcodec --enable-avutil
    --enable-swscale --enable-swresample
    --enable-demuxer=mov --enable-decoder=h264 --enable-parser=h264
    --enable-protocol=file
)
if [[ "$config" == debug ]]; then
    flags+=(--enable-debug=3 --disable-optimizations --optflags=-O0
        --disable-stripping --extra-cflags=-fno-omit-frame-pointer)
else
    flags+=(--disable-debug --enable-optimizations --optflags=-O3)
fi
printf '%s\n' "${flags[@]}" > configure.flags.next
if [[ ! -f ffbuild/config.mak ]] || ! cmp -s configure.flags.next configure.flags; then
    printf 'FFmpeg %s: configuring (compiler probes may be quiet)…\n' "$config"
    printf 'Probe log: %s/ffbuild/config.log\n' "$build_dir"
    configure_start=$SECONDS
    "$source_dir/configure" "${flags[@]}"
    mv configure.flags.next configure.flags
    printf 'FFmpeg %s: configured in %ss\n' "$config" "$((SECONDS - configure_start))"
else
    rm configure.flags.next
    printf 'FFmpeg %s: configuration unchanged; skipping configure.\n' "$config"
fi
printf 'FFmpeg %s: compiling with %s jobs…\n' "$config" "${FFMPEG_JOBS:-8}"
"$make_program" -j"${FFMPEG_JOBS:-8}"
printf 'FFmpeg %s: installing…\n' "$config"
"$make_program" install
printf 'FFmpeg %s static libraries: %s/lib/\n' "$config" "$prefix"
