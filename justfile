# Squeeze — Build Commands
# Run `just` to see available recipes

# Empty uses the preset's backend. Override with: just vd_backend=stub build-desktop
vd_backend := ""
# C/dependency configuration (not Odin): just vd_config=release smoke-vd
vd_config := "debug"
vd_preset := "vd-" + vd_config
vd_build_dir := "build/vd/" + vd_config
# Named imports for vendored Odin packages, shared by build/check/smoke commands.
odin_ext_collection := "-collection:ext=" + justfile_directory() + "/ext"

# ──────────────────────────────────────────────

# List available recipes
default:
    @just --list

# ── Desktop (Odin + SDL3) ───────────────────

# Build matching vendored FFmpeg (explicit, incremental; no downloads)
build-ffmpeg:
    bash scripts/build_ffmpeg.sh {{quote(vd_config)}}

# Build local SDL3 + shadercross explicitly (incremental; includes headless smoke test)
build-sdl:
    bash scripts/build_sdl.sh {{quote(vd_config)}}

# Publish matching prebuilt SDL artifacts; never configure/build the dependency here
prepare-sdl:
    #!/usr/bin/env bash
    set -euo pipefail
    prefix="$PWD/build/deps/sdl/{{vd_config}}/install"
    for file in lib/libSDL3.a lib/libSDL3_shadercross.a share/squeeze/odin-link-flags; do
        if [[ ! -f "$prefix/$file" ]]; then
            echo "Missing $prefix/$file. Run just vd_config={{vd_config}} build-sdl first." >&2
            exit 1
        fi
    done
    cmake -E make_directory build/desktop
    cmake -E copy_if_different "$prefix/lib/libSDL3.a" build/desktop/libSDL3.a
    cmake -E copy_if_different "$prefix/lib/libSDL3_shadercross.a" build/desktop/libSDL3_shadercross.a
    cmake -E copy_if_different "$prefix/share/squeeze/odin-link-flags" build/desktop/sdl-link-flags

# Check Odin's pinned SDL bindings against matching prebuilt artifacts
smoke-sdl: prepare-sdl
    #!/usr/bin/env bash
    set -euo pipefail
    sdl_link_flags=$(< build/desktop/sdl-link-flags)
    odin run scripts/sdl/odin-smoke/ {{quote(odin_ext_collection)}} -out:build/desktop/sdl-odin-smoke -debug -extra-linker-flags:"$sdl_link_flags"

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
build-desktop: build-shim prepare-sdl build-shaders
    #!/usr/bin/env bash
    set -euo pipefail
    odinfmt -w desktop/
    sdl_link_flags=$(< build/desktop/sdl-link-flags)
    odin build desktop/ {{quote(odin_ext_collection)}} -out:build/squeeze-desktop -debug -extra-linker-flags:"$sdl_link_flags"
    echo "Desktop binary: $PWD/build/squeeze-desktop"

# Check desktop Odin code with the same collections and selected prebuilt libraries
check-desktop: build-shim prepare-sdl
    odin check desktop/ {{quote(odin_ext_collection)}}

# Build and run desktop app
run-desktop: build-desktop
    ./build/squeeze-desktop

# ── Dependencies ─────────────────────────────

# Build matching vendored dependencies explicitly (run once per configuration)
build-deps: build-ffmpeg build-sdl

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

# Clean everything, including FFmpeg, SDL3, and shadercross
clean-all:
    rm -rf build/ cmake-build-*/
    @echo "All build artifacts removed; dependencies must be rebuilt."
