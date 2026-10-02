#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
config="${1:-debug}"
case "$config" in
    debug) build_type=Debug ;;
    release) build_type=Release ;;
    *) echo "Usage: scripts/build_sdl.sh [debug|release]" >&2; exit 1 ;;
esac
if [[ $# -gt 1 ]]; then
    echo "Usage: scripts/build_sdl.sh [debug|release]" >&2
    exit 1
fi
if [[ $(uname -sm) != "Darwin arm64" ]]; then
    echo "SDL dependency build supports macOS arm64 only." >&2
    exit 1
fi
if [[ ! -x "$HOME/.local/bin/make" ]]; then
    echo "Missing modern GNU Make: $HOME/.local/bin/make" >&2
    exit 1
fi
build_dir="$root/build/deps/sdl/$config"
# SPIRV-Cross embeds a configure timestamp; keep it stable across incremental builds.
export SOURCE_DATE_EPOCH=0
cmake -S "$root/scripts/sdl" -B "$build_dir" -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE="$build_type" \
    -DCMAKE_C_COMPILER=/usr/bin/clang \
    -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
    -DCMAKE_OBJC_COMPILER=/usr/bin/clang \
    -DCMAKE_MAKE_PROGRAM="$HOME/.local/bin/make" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_SYSROOT=macosx \
    -DCMAKE_INSTALL_PREFIX="$build_dir/install"
cmake --build "$build_dir" --target sdl-deps sdl-smoke -j"${SDL_JOBS:-8}"
ctest --test-dir "$build_dir" --output-on-failure --no-tests=error
# No --strip: Debug archive members must retain DWARF.
cmake --install "$build_dir"
printf 'SDL %s static libraries: %s/install/lib/\n' "$config" "$build_dir"
