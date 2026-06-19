#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
cd "$SRCROOT/../.."

case "$PLATFORM_NAME" in
	iphoneos)        SUBTARGET=iphone ;;
	iphonesimulator) SUBTARGET=iphonesimulator ;;
	*) echo "error: Unsupported platform: $PLATFORM_NAME" && exit 1 ;;
esac

just build-core-ios "$SUBTARGET" "$BUILT_PRODUCTS_DIR"

