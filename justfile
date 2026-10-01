# Squeeze — Build Commands
# Run `just` to see available recipes

# Empty uses the preset's backend. Override with: just vd_backend=stub build-desktop
vd_backend := ""
# C/FFmpeg configuration (not Odin): just vd_config=release smoke-vd
vd_config := "debug"
vd_preset := "vd-" + vd_config
vd_build_dir := "build/vd/" + vd_config

# ──────────────────────────────────────────────

# List available recipes
default:
    @just --list

# ── Desktop (Odin + SDL3) ───────────────────

# Build matching vendored FFmpeg (explicit, incremental; no downloads)
build-ffmpeg:
    bash scripts/build_ffmpeg.sh {{quote(vd_config)}}

# Configure all C targets; building a subset does not shrink the IDE database
configure-vd:
    cmake --preset {{quote(vd_preset)}} {{if vd_backend == "" { "" } else { quote("-DVD_BACKEND=" + vd_backend) }}}

# Unity build + archive merge. FFmpeg must already be built.
build-shim: configure-vd
    cmake --build --preset {{quote(vd_preset)}} --target vd
    cmake -E make_directory build/desktop
    cmake -E copy_if_different {{quote(vd_build_dir + "/libvd.a")}} build/desktop/libvd.a
    @echo "VD archive: $PWD/build/desktop/libvd.a"

# Build and run all applicable VD tests
smoke-vd: build-shim
    cmake --build --preset {{quote(vd_preset)}}
    ctest --preset {{quote(vd_preset)}}
    @echo "VD smoke binary: $PWD/{{vd_build_dir}}/vd-smoke"
    @if [ "{{vd_backend}}" != stub ]; then echo "FFmpeg smoke binary: $PWD/{{vd_build_dir}}/vd-ffmpeg-smoke"; fi

# Compile GLSL shaders to SPIR-V
build-shaders:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p build/shaders
    for f in desktop/shaders/*.glsl; do
        base=$(basename "$f" .glsl)
        short_stage="${base##*.}"
        case "$short_stage" in
            vert) stage=vertex ;;
            frag) stage=fragment ;;
            comp) stage=compute ;;
            *)    stage="$short_stage" ;;
        esac
        glslc -fshader-stage="$stage" "$f" -o "build/shaders/${base}.spv"
    done
    echo "Shaders: $PWD/build/shaders/"

# Build desktop app
build-desktop: build-shim build-shaders
    #!/usr/bin/env bash
    set -euo pipefail
    odinfmt -w desktop/
    odin build desktop/ -out:build/squeeze-desktop -debug
    echo "Desktop binary: $PWD/build/squeeze-desktop"

# Build and run desktop app
run-desktop: build-desktop
    ./build/squeeze-desktop

# ── Dependencies ─────────────────────────────

# Build vendored dependencies (run once per machine)
build-deps: build-ffmpeg
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building SDL_gpu_shadercross..."
    cmake -S ext/SDL_gpu_shadercross -B build/deps/shadercross \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DSDLSHADERCROSS_VENDORED=ON \
        -DSDLSHADERCROSS_DXC=OFF \
        -DSDLSHADERCROSS_SPIRVCROSS_SHARED=OFF \
        -DSDLSHADERCROSS_CLI=OFF \
        -DCMAKE_CXX_FLAGS="-Wno-invalid-specialization"
    cmake --build build/deps/shadercross --config Release -j8
    echo "Shadercross library: $PWD/build/deps/shadercross/libSDL3_shadercross.a"

# Format Odin source
fmt:
    odinfmt -w core/
    odinfmt -w desktop/

# ── Utilities ────────────────────────────────

# Clean project outputs, retaining expensive dependency builds
clean:
    @if [ -d build ]; then find build -mindepth 1 -maxdepth 1 ! -name deps -exec rm -rf {} +; fi
    rm -rf cmake-build-*/
    @echo "Project artifacts removed; build/deps/ preserved."

# Clean everything, including FFmpeg and shadercross
clean-all:
    rm -rf build/ cmake-build-*/
    @echo "All build artifacts removed; dependencies must be rebuilt."
