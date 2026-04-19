#!/usr/bin/env bash
#
# Builds PokemonKit as Android `.so` libraries via swift-android-bundler and
# splits the output across the gradle modules per the gradual-loading model:
#
#   - Core Swift runtime libs       → Android/swift-runtime/src/main/jniLibs + assets
#   - Product-specific libs (PokemonKitAndroid)
#                                   → Android/pokemon-swift/src/main/jniLibs + assets
#
# Each side gets its own manifest. SwiftRuntime loads the core list on app
# start; PokemonSwiftRuntime (Step 12) checks SwiftRuntime.isConfigured then
# loads its own list and calls nativeCreate.
#
# Requires: swift-android-bundler, patchelf, jq, swiftly (Swift 6.3 toolchain),
# Android SDK + NDK at ~/Library/Android/sdk, Swift for Android SDK installed.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT="PokemonKitAndroid"
PACKAGE_DIR="$ROOT/Modules/PokemonKit"
RUNTIME_MODULE="$ROOT/Android/swift-runtime"
POKEMON_MODULE="$ROOT/Android/pokemon-swift"
SWIFT_VERSION="6.3"

# Build swift-android-bundler if missing — pinned to v0.3.0, built with Swift 6.3.0 via swiftly.
"$ROOT/Scripts/bootstrap-tools.sh"
BUNDLER="$ROOT/.tools/swift-android-bundler/.build/release/swift-android-bundler"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/jniLibs" "$TMP/manifest"

echo "==> swift-android-bundler build (arm64, x86_64, arm7)"
"$BUNDLER" build \
    --product "$PRODUCT" \
    --swift-package "$PACKAGE_DIR" \
    --destination "$TMP/jniLibs" \
    --manifest-destination "$TMP/manifest" \
    --swift-version "$SWIFT_VERSION" \
    --arch arm64 --arch x86_64 --arch arm7 \
    --exclude foundation-networking \
    --strip all

ALL_MANIFEST="$TMP/manifest/swift-libs-manifest.json"

# Build two ordered manifests by splitting the bundler's topo-sorted list.
# Anything matching the product name → pokemon manifest; rest → runtime manifest.
RUNTIME_LIBS_JSON=$(jq -c "{libraries: [.libraries[] | select(. != \"$PRODUCT\")]}" "$ALL_MANIFEST")
POKEMON_LIBS_JSON=$(jq -c --arg product "$PRODUCT" \
    '{libraries: [.libraries[] | select(. == $product)], product: $product}' \
    "$ALL_MANIFEST")

echo "==> Splitting .so files per arch"
RUNTIME_DST="$RUNTIME_MODULE/src/main/jniLibs"
POKEMON_DST="$POKEMON_MODULE/src/main/jniLibs"
rm -rf "$RUNTIME_DST" "$POKEMON_DST"

for arch_dir in "$TMP/jniLibs"/*/; do
    arch="$(basename "$arch_dir")"
    mkdir -p "$RUNTIME_DST/$arch" "$POKEMON_DST/$arch"
    for so in "$arch_dir"*.so; do
        libname="$(basename "$so" .so | sed 's/^lib//')"
        if [[ "$libname" == "$PRODUCT" ]]; then
            cp "$so" "$POKEMON_DST/$arch/"
        else
            cp "$so" "$RUNTIME_DST/$arch/"
        fi
    done
done

echo "==> Writing manifests"
RUNTIME_MANIFEST="$RUNTIME_MODULE/src/main/assets/swift-libs-manifest.json"
POKEMON_MANIFEST="$POKEMON_MODULE/src/main/assets/pokemon-libs-manifest.json"
mkdir -p "$(dirname "$POKEMON_MANIFEST")"
echo "$RUNTIME_LIBS_JSON" | jq . > "$RUNTIME_MANIFEST"
echo "$POKEMON_LIBS_JSON" | jq . > "$POKEMON_MANIFEST"

echo
echo "swift-runtime libs:"
jq -r '.libraries[]' "$RUNTIME_MANIFEST" | sed 's/^/  - /'
echo
echo "pokemon-swift libs:"
jq -r '.libraries[]' "$POKEMON_MANIFEST" | sed 's/^/  - /'
echo
echo "Done."
