#!/usr/bin/env bash
#
# Clones and builds swift-android-bundler at a pinned tag into .tools/.
# Idempotent — if the marker file + binary are present, exits immediately.
#
# Requires:
#   - swiftly (https://www.swift.org/install/)
#   - Swift 6.3.0 installed via swiftly (`swiftly install 6.3.0`)
#
# Build dependencies for the bundler at runtime (not enforced here):
#   - Android SDK + NDK at ~/Library/Android/sdk
#   - Swift for Android SDK installed via `swift sdk install`
#   - patchelf (`brew install patchelf`)
#   - jq (`brew install jq`)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$ROOT/.tools"
BUNDLER_DIR="$TOOLS_DIR/swift-android-bundler"
BUNDLER_REPO="https://github.com/NikolayJuly/swift-android-bundler.git"
# Version pins — bump these two together.
BUNDLER_TAG="v0.3.1"
SWIFT_VERSION="6.3.0"
MARKER="$TOOLS_DIR/.bootstrapped-swift-android-bundler-$BUNDLER_TAG"
BINARY="$BUNDLER_DIR/.build/release/swift-android-bundler"

if [[ -f "$MARKER" && -x "$BINARY" ]]; then
    exit 0
fi

if ! command -v swiftly >/dev/null 2>&1; then
    cat >&2 <<EOF
ERROR: swiftly not found on PATH.
Install it from https://www.swift.org/install/ and re-run.
EOF
    exit 1
fi

if ! swiftly list 2>/dev/null | grep -q "Swift $SWIFT_VERSION"; then
    cat >&2 <<EOF
ERROR: Swift $SWIFT_VERSION is not installed via swiftly.
Run: swiftly install $SWIFT_VERSION
EOF
    exit 1
fi

mkdir -p "$TOOLS_DIR"

if [[ ! -d "$BUNDLER_DIR/.git" ]]; then
    rm -rf "$BUNDLER_DIR"
    echo "==> Cloning swift-android-bundler $BUNDLER_TAG"
    git clone --depth 1 --branch "$BUNDLER_TAG" "$BUNDLER_REPO" "$BUNDLER_DIR"
else
    echo "==> Updating swift-android-bundler to $BUNDLER_TAG"
    git -C "$BUNDLER_DIR" fetch --depth 1 origin "refs/tags/$BUNDLER_TAG:refs/tags/$BUNDLER_TAG" 2>/dev/null || true
    git -C "$BUNDLER_DIR" -c advice.detachedHead=false checkout "$BUNDLER_TAG"
fi

echo "==> Building swift-android-bundler with Swift $SWIFT_VERSION"
( cd "$BUNDLER_DIR" && swiftly run swift build -c release "+$SWIFT_VERSION" )

if [[ ! -x "$BINARY" ]]; then
    echo "ERROR: build finished but binary not found at $BINARY" >&2
    exit 1
fi

touch "$MARKER"
echo "==> swift-android-bundler ready: $BINARY"
