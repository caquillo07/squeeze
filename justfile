# Squeeze — Build Commands
# Run `just` to see available recipes

default:
    @just --list

# --- Desktop (Odin + SDL3) ---

build-desktop:
    @echo "TODO: odin build desktop/ ..."

run-desktop: build-desktop
    @echo "TODO: run desktop binary"

# --- Core (C shim) ---

build-shim:
    @echo "TODO: cc -c core/shim/ffmpeg_shim.c ..."

# --- iOS ---
# iOS builds through Xcode. These are convenience wrappers.

build-ios:
    @echo "TODO: xcodebuild -project ios/Squeeze.xcodeproj ..."

# --- Utilities ---

clean:
    @echo "TODO: clean build artifacts"