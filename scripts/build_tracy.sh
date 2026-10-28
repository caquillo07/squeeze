#!/usr/bin/env bash
set -euo pipefail

usage="Usage: scripts/build_tracy.sh [debug|release] [on|startup]"
root=$(cd "$(dirname "$0")/.." && pwd)
config="${1:-debug}"
mode="${2:-on}"
if [[ $# -gt 2 || ( "$config" != debug && "$config" != release ) || ( "$mode" != on && "$mode" != startup ) ]]; then
    echo "$usage" >&2
    exit 1
fi
if [[ $(uname -sm) != "Darwin arm64" ]]; then
    echo "Tracy client build supports macOS arm64 only." >&2
    exit 1
fi
source_file="$root/ext/tracy/public/TracyClient.cpp"
build_dir="$root/build/deps/tracy/$config/$mode"
archive="$build_dir/libtracy.a"

# The client is one translation unit. Both configurations are optimized: the
# profiler's job is low per-zone overhead, and we never step through its internals.
# Debug keeps symbols and frame pointers for symbolicated stacks.
# Upstream uses sprintf; silence only that deprecation for vendored code we do not edit.
# Always listen on localhost only: no network exposure, no firewall prompt.
flags=(-std=c++17 -arch arm64 -DTRACY_ENABLE -DTRACY_ONLY_LOCALHOST -fno-omit-frame-pointer
    -Wno-deprecated-declarations)
if [[ "$mode" == on ]]; then
    # Collect only while a viewer is connected: no memory growth otherwise, but startup
    # is missed unless the viewer is already waiting. "startup" buffers from launch.
    flags+=(-DTRACY_ON_DEMAND)
fi
if [[ "$config" == debug ]]; then
    flags+=(-O2 -g)
else
    flags+=(-O3 -g0 -DNDEBUG)
fi

mkdir -p "$build_dir"
printf '%s\n' "${flags[@]}" > "$build_dir/flags.next"
if [[ -f "$archive" && "$archive" -nt "$source_file" ]] && cmp -s "$build_dir/flags.next" "$build_dir/flags" \
    && [[ -z "$(find "$root/ext/tracy/public" -newer "$archive" -print -quit)" ]]; then
    rm "$build_dir/flags.next"
    printf 'Tracy %s/%s client unchanged: %s\n' "$config" "$mode" "$archive"
    exit 0
fi
printf 'Tracy %s/%s: compiling client...\n' "$config" "$mode"
/usr/bin/clang++ "${flags[@]}" -c "$source_file" -o "$build_dir/TracyClient.o"
rm -f "$archive"
libtool -static -o "$archive" "$build_dir/TracyClient.o"
mv "$build_dir/flags.next" "$build_dir/flags"
printf 'Tracy %s/%s client library: %s\n' "$config" "$mode" "$archive"
