# Squeeze — Build Commands
# Run `just` to see available recipes

ios_project  := "ios/Squeeze/Squeeze.xcodeproj"
ios_scheme   := "Squeeze"
ios_bundle   := "com.caquilloapps.Squeeze"

# Default simulators — override with just run-ios ios_device="iPhone 17e"
ios_device   := "iPhone 17 Pro Max"
ipad_device  := "iPad Pro 13-inch (M5)"

# ──────────────────────────────────────────────

# List available recipes
default:
    @just --list

# ── iOS ─────────────────────────────────────

# Build iOS: just build-ios [ios|ipad|macos]
build-ios platform="ios":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{platform}}" in
        ios)
            xcodebuild build -quiet \
                -project {{ios_project}} \
                -scheme {{ios_scheme}} \
                -destination "platform=iOS Simulator,name={{ios_device}}" \
                -configuration Debug
            ;;
        ipad)
            xcodebuild build -quiet \
                -project {{ios_project}} \
                -scheme {{ios_scheme}} \
                -destination "platform=iOS Simulator,name={{ipad_device}}" \
                -configuration Debug
            ;;
        macos)
            xcodebuild build -quiet \
                -project {{ios_project}} \
                -scheme {{ios_scheme}} \
                -destination "platform=macOS,arch=arm64" \
                -configuration Debug
            ;;
        *)
            echo "Unknown platform: {{platform}}. Use ios, ipad, or macos."
            exit 1
            ;;
    esac
    echo "Build succeeded."

# Build and run on simulator: just run-ios [ios|ipad|macos]
run-ios platform="ios":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{platform}}" in
        ios)
            xcodebuild build -quiet \
                -project {{ios_project}} \
                -scheme {{ios_scheme}} \
                -destination "platform=iOS Simulator,name={{ios_device}}" \
                -configuration Debug
            xcrun simctl boot "{{ios_device}}" 2>/dev/null || true
            open -a Simulator
            app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "{{ios_scheme}}.app" -path "*/Debug-iphonesimulator/*" -maxdepth 5 2>/dev/null | head -1)
            if [ -z "$app_path" ]; then
                echo "Error: Could not find built app."
                exit 1
            fi
            xcrun simctl install "{{ios_device}}" "$app_path"
            xcrun simctl launch --console-pty "{{ios_device}}" "{{ios_bundle}}"
            ;;
        ipad)
            xcodebuild build -quiet \
                -project {{ios_project}} \
                -scheme {{ios_scheme}} \
                -destination "platform=iOS Simulator,name={{ipad_device}}" \
                -configuration Debug
            xcrun simctl boot "{{ipad_device}}" 2>/dev/null || true
            open -a Simulator
            app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "{{ios_scheme}}.app" -path "*/Debug-iphonesimulator/*" -maxdepth 5 2>/dev/null | head -1)
            if [ -z "$app_path" ]; then
                echo "Error: Could not find built app."
                exit 1
            fi
            xcrun simctl install "{{ipad_device}}" "$app_path"
            xcrun simctl launch --console-pty "{{ipad_device}}" "{{ios_bundle}}"
            ;;
        macos)
            xcodebuild build -quiet \
                -project {{ios_project}} \
                -scheme {{ios_scheme}} \
                -destination "platform=macOS,arch=arm64" \
                -configuration Debug
            app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "{{ios_scheme}}.app" -path "*/Debug/*" -not -path "*-iphonesimulator*" -maxdepth 5 2>/dev/null | head -1)
            if [ -z "$app_path" ]; then
                echo "Error: Could not find built app."
                exit 1
            fi
            open "$app_path"
            ;;
        *)
            echo "Unknown platform: {{platform}}. Use ios, ipad, or macos."
            exit 1
            ;;
    esac

# Build, install, and launch on a connected physical device
run-device:
    #!/usr/bin/env bash
    set -euo pipefail

    # Suppress devicectl's provisioning spam
    dctl() { xcrun devicectl "$@" 2> >(grep -v "provisioning\|manage create" >&2); }

    # Find the first available physical device (wired or wireless)
    json=$(mktemp)
    dctl list devices --json-output "$json" >/dev/null
    device_id=$(jq -r '.result.devices[] | select(.hardwareProperties.reality == "physical") | select(.connectionProperties.pairingState == "paired") | .identifier' "$json" | head -1)
    rm -f "$json"
    if [ -z "$device_id" ]; then
        echo "Error: No paired iOS device found."
        echo "Run 'xcrun devicectl list devices' to check."
        exit 1
    fi
    echo "Found device: $device_id"

    xcodebuild build -quiet \
        -project {{ios_project}} \
        -scheme {{ios_scheme}} \
        -destination "generic/platform=iOS" \
        -configuration Debug \
        -allowProvisioningUpdates

    app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "{{ios_scheme}}.app" -path "*/Debug-iphoneos/*" -maxdepth 5 2>/dev/null | head -1)
    if [ -z "$app_path" ]; then
        echo "Error: Could not find built app."
        exit 1
    fi

    echo "Installing..."
    dctl device install app --quiet --device "$device_id" "$app_path" >/dev/null

    echo "Launching (Ctrl+C to stop)..."
    dctl device process launch --console --device "$device_id" "{{ios_bundle}}"


# Build, launch paused, attach debugger: just debug-ios [ios|ipad]
debug-ios platform="ios":
    #!/usr/bin/env bash
    set -euo pipefail
    device="{{ios_device}}"
    [[ "{{platform}}" == "ipad" ]] && device="{{ipad_device}}"

    xcodebuild build -quiet \
        -project {{ios_project}} \
        -scheme {{ios_scheme}} \
        -destination "platform=iOS Simulator,name=$device" \
        -configuration Debug

    xcrun simctl boot "$device" 2>/dev/null || true
    open -a Simulator

    app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "{{ios_scheme}}.app" -path "*/Debug-iphonesimulator/*" -maxdepth 5 2>/dev/null | head -1)
    if [ -z "$app_path" ]; then
        echo "Error: Could not find built app."
        exit 1
    fi
    xcrun simctl install "$device" "$app_path"

    xcrun simctl launch --wait-for-debugger --console-pty "$device" "{{ios_bundle}}"
    echo ""
    echo "App waiting for debugger. In Xcode: Debug > Attach to Process > {{ios_scheme}}"

# Run iOS tests
test-ios:
    xcodebuild test -quiet \
        -project {{ios_project}} \
        -scheme {{ios_scheme}} \
        -destination "platform=iOS Simulator,name={{ios_device}}"

# Archive for release
release-ios:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Archiving {{ios_scheme}}..."
    xcodebuild archive -quiet \
        -project {{ios_project}} \
        -scheme {{ios_scheme}} \
        -archivePath build/{{ios_scheme}}.xcarchive \
        -configuration Release
    echo "Archive created at build/{{ios_scheme}}.xcarchive"

# Open Xcode
dev-ios:
    open {{ios_project}}

# Take a screenshot: just screenshot-ios [ios|ipad|macos]
screenshot-ios platform="ios":
    #!/usr/bin/env bash
    set -euo pipefail
    out="/tmp/squeeze_screenshot.png"
    case "{{platform}}" in
        ios)
            xcrun simctl io "{{ios_device}}" screenshot "$out" >/dev/null 2>&1
            ;;
        ipad)
            xcrun simctl io "{{ipad_device}}" screenshot "$out" >/dev/null 2>&1
            ;;
        macos)
            screencapture -l $(osascript -e 'tell app "{{ios_scheme}}" to id of window 1') "$out" 2>/dev/null
            ;;
        *)
            echo "Unknown platform: {{platform}}. Use ios, ipad, or macos."
            exit 1
            ;;
    esac
    echo "$out"

# ── Desktop (Odin + SDL3) ───────────────────

# Build core C shim (vd.c → libvd.a)
build-shim:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p build/desktop
    clang -c core/shim/vd.c -o build/desktop/vd.o
    ar rcs build/desktop/libvd.a build/desktop/vd.o

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
    echo "Shaders compiled."

# Build desktop app
build-desktop: build-shim build-shaders
    #!/usr/bin/env bash
    set -euo pipefail
    odinfmt -w desktop/
    odin build desktop/ -out:build/squeeze-desktop -debug

# Build and run desktop app
run-desktop: build-desktop
    ./build/squeeze-desktop

# ── Format & Lint ────────────────────────────

# ── Dependencies ─────────────────────────────

# Build vendored dependencies (run once per machine)
build-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building SDL_gpu_shadercross..."
    cd ext/SDL_gpu_shadercross
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DSDLSHADERCROSS_VENDORED=ON -DSDLSHADERCROSS_CLI=OFF
    cmake --build build --config Release
    echo "Dependencies built."

# Format all code
fmt:
    #!/usr/bin/env bash
    odinfmt -w desktop/
    if [[ "$(uname)" == "Darwin" ]]; then
        swiftformat ios/
    else
        echo "Skipping swiftformat (macOS only)"
    fi

# Lint all code (no changes, exits 1 on violations)
lint:
    #!/usr/bin/env bash
    if [[ "$(uname)" == "Darwin" ]]; then
        swiftformat --lint ios/
    else
        echo "Skipping swiftformat lint (macOS only)"
    fi

# ── Utilities ────────────────────────────────

# List available simulators and physical devices
devices:
    #!/usr/bin/env bash
    echo "=== Physical Devices ==="
    xcrun devicectl list devices 2>&1 | grep -v "provisioning\|manage create"
    echo ""
    echo "=== Simulators ==="
    xcrun simctl list devices available | grep -E "^-- iOS|    iPhone|    iPad"

# Clean all build artifacts
clean:
    xcodebuild clean -project {{ios_project}} -scheme {{ios_scheme}} 2>/dev/null || true
    rm -rf build/
