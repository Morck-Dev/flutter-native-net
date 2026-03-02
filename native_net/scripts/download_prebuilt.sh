#!/usr/bin/env bash
# =============================================================================
# download_prebuilt.sh
#
# Downloads prebuilt native_net binaries from GitHub Releases and places
# them where the Flutter plugin expects them:
#   android/libs/native_net.aar          (all ABIs in one file)
#   ios/Frameworks/native_net.xcframework.tar.gz -> extracted
#   macos/Frameworks/  (included in xcframework)
#   prebuilt/windows/x64/native_net.dll
#   prebuilt/linux/x64/libnative_net.so
#
# Usage:
#   bash scripts/download_prebuilt.sh                    # latest release
#   bash scripts/download_prebuilt.sh v0.3.1             # specific tag
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO="${REPO:-Morck-Dev/flutter-native-net}"
TAG="${1:-latest}"

# Resolve "latest" to actual tag name
if [ "$TAG" = "latest" ]; then
    echo "[native_net] Resolving latest release tag ..."
    TAG=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" | \
        grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [ -z "$TAG" ]; then
        echo "[native_net] ERROR: Could not resolve latest release tag."
        echo "[native_net] Try specifying a tag: bash scripts/download_prebuilt.sh v0.3.0"
        exit 1
    fi
    echo "[native_net] Latest release: $TAG"
fi

# GitHub release download URL pattern (no API/JSON parsing needed)
BASE_URL="https://github.com/$REPO/releases/download/$TAG"

download() {
    local file="$1"
    local dest="$2"
    local url="$BASE_URL/$file"

    echo "[native_net] Downloading $file ..."
    mkdir -p "$(dirname "$dest")"

    if curl -fSL --retry 3 --retry-delay 5 -o "$dest" "$url"; then
        echo "[native_net]   -> $dest"
        return 0
    else
        echo "[native_net]   WARNING: Failed to download $file (HTTP error)"
        rm -f "$dest"
        return 1
    fi
}

echo "[native_net] Downloading prebuilt binaries ($TAG) from $REPO ..."
echo ""

PREBUILT="$PLUGIN_DIR/prebuilt"
mkdir -p "$PREBUILT"

# Android: AAR is downloaded automatically by Gradle on first build.
# No manual download needed. (See android/build.gradle.kts)
echo "[native_net] Android: AAR is auto-downloaded by Gradle on first build."

# iOS XCFramework
if download "native_net-xcframework.tar.gz" "/tmp/nn_xcfw_$$.tar.gz"; then
    rm -rf "$PLUGIN_DIR/ios/Frameworks/native_net.xcframework"
    mkdir -p "$PLUGIN_DIR/ios/Frameworks"
    tar xzf "/tmp/nn_xcfw_$$.tar.gz" -C "$PLUGIN_DIR/ios/Frameworks/"
    rm -f "/tmp/nn_xcfw_$$.tar.gz"
    echo "[native_net]   -> ios/Frameworks/native_net.xcframework/"
fi

# macOS XCFramework (same archive, extract for macOS too)
if download "native_net-xcframework.tar.gz" "/tmp/nn_xcfw_mac_$$.tar.gz"; then
    rm -rf "$PLUGIN_DIR/macos/Frameworks/native_net.xcframework"
    mkdir -p "$PLUGIN_DIR/macos/Frameworks"
    tar xzf "/tmp/nn_xcfw_mac_$$.tar.gz" -C "$PLUGIN_DIR/macos/Frameworks/"
    rm -f "/tmp/nn_xcfw_mac_$$.tar.gz"
    echo "[native_net]   -> macos/Frameworks/native_net.xcframework/"
fi

# Windows DLL
download "native_net-windows-x64.zip" "/tmp/nn_win_$$.zip" && {
    mkdir -p "$PREBUILT/windows/x64"
    unzip -qo "/tmp/nn_win_$$.zip" -d "$PREBUILT/windows/x64/"
    rm -f "/tmp/nn_win_$$.zip"
} || true

# Linux SO
download "native_net-linux-x64.tar.gz" "/tmp/nn_linux_$$.tar.gz" && {
    mkdir -p "$PREBUILT/linux/x64"
    tar xzf "/tmp/nn_linux_$$.tar.gz" -C "$PREBUILT/linux/x64/"
    rm -f "/tmp/nn_linux_$$.tar.gz"
} || true

echo ""
echo "[native_net] Done. Files:"
find "$PLUGIN_DIR/ios/Frameworks" \
     "$PLUGIN_DIR/macos/Frameworks" "$PREBUILT" \
     -type f 2>/dev/null | sort | sed "s|$PLUGIN_DIR/|  |"
echo ""
echo "[native_net] Run 'flutter clean && flutter run' to use them."
