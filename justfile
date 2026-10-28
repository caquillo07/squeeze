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
# Tracy client mode. on: collect while a viewer is connected (default for debug).
# startup: buffer from launch so startup is captured. off: no Tracy code at all
# (default for release). Both enabled modes listen on localhost only.
tracy := if vd_config == "release" { "off" } else { "on" }
# Stack frames captured per Tracy zone/allocation; 0 is none. Costly: just tracy_callstack=8 run-desktop
tracy_callstack := "0"
odin_tracy_define := if tracy == "off" { "" } else if tracy == "on" { "-define:TRACY_ENABLE=true -define:TRACY_CALLSTACK=" + tracy_callstack } else if tracy == "startup" { "-define:TRACY_ENABLE=true -define:TRACY_CALLSTACK=" + tracy_callstack } else { error("tracy must be on, startup, or off") }

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

# Build both Tracy client modes explicitly (incremental; one translation unit each)
build-tracy:
    bash scripts/build_tracy.sh {{quote(vd_config)}} on
    bash scripts/build_tracy.sh {{quote(vd_config)}} startup

# Publish the matching prebuilt Tracy client unless tracy=off; never builds it here
prepare-tracy:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{tracy}}" == off ]]; then exit 0; fi
    archive="$PWD/build/deps/tracy/{{vd_config}}/{{tracy}}/libtracy.a"
    if [[ ! -f "$archive" ]]; then
        echo "Missing $archive. Run just vd_config={{vd_config}} build-tracy first." >&2
        exit 1
    fi
    cmake -E make_directory build/desktop
    cmake -E copy_if_different "$archive" build/desktop/libtracy.a

# Check the Odin Tracy bindings link and run against the matching prebuilt client
smoke-tracy:
    just tracy=on vd_config={{quote(vd_config)}} prepare-tracy
    odin run scripts/tracy/odin-smoke/ {{quote(odin_ext_collection)}} -out:build/desktop/tracy-odin-smoke -debug -define:TRACY_ENABLE=true -extra-linker-flags:-lc++

# Configure all C targets; building a subset does not shrink the IDE database
configure-vd:
    cmake --preset {{quote(vd_preset)}} {{if vd_backend == "" { "" } else { quote("-DVD_BACKEND=" + vd_backend) }}} \
        -DVD_TRACY={{if tracy == "off" { "OFF" } else { "ON" }}} -DVD_TRACY_CALLSTACK={{tracy_callstack}}

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
build-desktop: fmt build-shim prepare-sdl prepare-tracy build-shaders
    #!/usr/bin/env bash
    set -euo pipefail
    sdl_link_flags=$(< build/desktop/sdl-link-flags)
    # Build identity for the run report. Quoted: an all-digit hash would become an integer define.
    commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
    if [[ "$commit" != unknown && -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
        commit="$commit-dirty"
    fi
    odin build desktop/ {{quote(odin_ext_collection)}} -out:build/squeeze-desktop -debug {{odin_tracy_define}} \
        -define:SQUEEZE_COMMIT="\"$commit\"" -define:SQUEEZE_DEPS_CONFIG="\"{{vd_config}}\"" \
        -define:SQUEEZE_TRACY_MODE="\"{{tracy}}\"" \
        -extra-linker-flags:"$sdl_link_flags"
    echo "Desktop binary: $PWD/build/squeeze-desktop"

# Check desktop Odin code with the same collections and selected prebuilt libraries
check-desktop: build-shim prepare-sdl
    odin check desktop/ {{quote(odin_ext_collection)}} {{odin_tracy_define}}

# Build and run desktop app
run-desktop: build-desktop
    ./build/squeeze-desktop

# ── Dependencies ─────────────────────────────

# Build matching vendored dependencies explicitly (run once per configuration)
build-deps: build-ffmpeg build-sdl build-tracy

# Format Odin source
fmt:
    # Explicit absolute config: odinfmt's own search silently falls back to defaults
    # when resolving the path fails (seen in sandboxed shells).
    odinfmt -config:{{quote(justfile_directory() + "/odinfmt.json")}} -w core/
    odinfmt -config:{{quote(justfile_directory() + "/odinfmt.json")}} -w desktop/

# ── Utilities ────────────────────────────────

# Clean project outputs, retaining expensive dependency builds
clean:
    @if [ -d build ]; then find build -mindepth 1 -maxdepth 1 ! -name deps -exec rm -rf {} +; fi
    rm -rf cmake-build-*/
    @echo "Project artifacts removed; build/deps/ preserved."

# Clean everything, including FFmpeg, SDL3, shadercross, and the Tracy client
clean-all:
    rm -rf build/ cmake-build-*/
    @echo "All build artifacts removed; dependencies must be rebuilt."
