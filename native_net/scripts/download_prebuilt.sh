#!/usr/bin/env bash
# =============================================================================
# download_prebuilt.sh
#
# Downloads prebuilt native_net binaries from GitHub Releases.
# Supports system proxy (HTTPS_PROXY / HTTP_PROXY / ALL_PROXY).
#
# Usage:
#   bash scripts/download_prebuilt.sh                    # latest release
#   bash scripts/download_prebuilt.sh v0.3.1             # specific tag
#   HTTPS_PROXY=http://127.0.0.1:7890 bash scripts/download_prebuilt.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO="${REPO:-Morck-Dev/flutter-native-net}"
TAG="${1:-latest}"

# ── Proxy detection ────────────────────────────────────────────────────────

PROXY=""
for var in HTTPS_PROXY https_proxy HTTP_PROXY http_proxy ALL_PROXY all_proxy; do
    val="${!var:-}"
    if [ -n "$val" ]; then
        PROXY="$val"
        break
    fi
done

CURL_PROXY_ARGS=""
if [ -n "$PROXY" ]; then
    CURL_PROXY_ARGS="--proxy $PROXY"
    echo "[native_net] Using proxy: $PROXY"
else
    echo "[native_net] No proxy detected."
    echo "[native_net]   Tip: export HTTPS_PROXY=http://127.0.0.1:7890"
fi

# ── Resolve latest tag ─────────────────────────────────────────────────────

if [ "$TAG" = "latest" ]; then
    echo "[native_net] Resolving latest release tag ..."
    TAG=$(curl -sL --retry 3 --retry-delay 3 $CURL_PROXY_ARGS \
        "https://api.github.com/repos/$REPO/releases/latest" | \
        grep '"tag_name"' | head -1 | \
        sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [ -z "$TAG" ]; then
        echo "[native_net] ERROR: Could not resolve latest tag."
        echo "[native_net] Try: bash scripts/download_prebuilt.sh v0.3.1"
        exit 1
    fi
fi

echo "[native_net] Release: $TAG"
BASE_URL="https://github.com/$REPO/releases/download/$TAG"

# ── Download helper ────────────────────────────────────────────────────────

download() {
    local file="$1"
    local dest="$2"
    local url="$BASE_URL/$file"

    echo "[native_net] Downloading $file ..."
    mkdir -p "$(dirname "$dest")"

    if curl -fSL \
        $CURL_PROXY_ARGS \
        --retry 3 \
        --retry-delay 5 \
        --connect-timeout 30 \
        --max-time 300 \
        -o "$dest" "$url"; then
        local size=$(wc -c < "$dest" 2>/dev/null || echo "?")
        echo "[native_net]   OK ($size bytes)"
        return 0
    else
        echo "[native_net]   FAILED: $url"
        rm -f "$dest"
        return 1
    fi
}

# ── Clean old prebuilt files first ─────────────────────────────────────────

echo ""
echo "[native_net] Cleaning old prebuilt files ..."
rm -f  "$PLUGIN_DIR/android/native_net.aar"
rm -rf "$PLUGIN_DIR/ios/Frameworks/native_net.xcframework"
rm -rf "$PLUGIN_DIR/macos/Frameworks/native_net.xcframework"
rm -rf "$PLUGIN_DIR/prebuilt"
echo "[native_net] Clean."
echo ""

PREBUILT="$PLUGIN_DIR/prebuilt"
mkdir -p "$PREBUILT"

# ── Android AAR ────────────────────────────────────────────────────────────

download "native_net.aar" "$PLUGIN_DIR/android/native_net.aar" || true

# ── iOS XCFramework ───────────────────────────────────────────────────────

TMP_XCFW="/tmp/nn_xcfw_$$.tar.gz"
if download "native_net-xcframework.tar.gz" "$TMP_XCFW"; then
    mkdir -p "$PLUGIN_DIR/ios/Frameworks"
    tar xzf "$TMP_XCFW" -C "$PLUGIN_DIR/ios/Frameworks/"
    rm -f "$TMP_XCFW"
    echo "[native_net]   -> ios/Frameworks/native_net.xcframework/"
fi

# ── macOS XCFramework ────────────────────────────────────────────────────

TMP_XCFW_MAC="/tmp/nn_xcfw_mac_$$.tar.gz"
if download "native_net-xcframework.tar.gz" "$TMP_XCFW_MAC"; then
    mkdir -p "$PLUGIN_DIR/macos/Frameworks"
    tar xzf "$TMP_XCFW_MAC" -C "$PLUGIN_DIR/macos/Frameworks/"
    rm -f "$TMP_XCFW_MAC"
    echo "[native_net]   -> macos/Frameworks/native_net.xcframework/"
fi

# ── Windows DLL ──────────────────────────────────────────────────────────

TMP_WIN="/tmp/nn_win_$$.zip"
if download "native_net-windows-x64.zip" "$TMP_WIN"; then
    mkdir -p "$PREBUILT/windows/x64"
    unzip -qo "$TMP_WIN" -d "$PREBUILT/windows/x64/"
    rm -f "$TMP_WIN"
fi

# ── Linux SO ─────────────────────────────────────────────────────────────

TMP_LINUX="/tmp/nn_linux_$$.tar.gz"
if download "native_net-linux-x64.tar.gz" "$TMP_LINUX"; then
    mkdir -p "$PREBUILT/linux/x64"
    tar xzf "$TMP_LINUX" -C "$PREBUILT/linux/x64/"
    rm -f "$TMP_LINUX"
fi

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
echo "[native_net] ========== Download complete =========="
echo ""
echo "Files:"
find "$PLUGIN_DIR/android" -name "native_net.aar" 2>/dev/null | sed "s|$PLUGIN_DIR/|  |"
find "$PLUGIN_DIR/ios/Frameworks" "$PLUGIN_DIR/macos/Frameworks" "$PREBUILT" \
     -type f 2>/dev/null | sort | sed "s|$PLUGIN_DIR/|  |"
echo ""
echo "Run: flutter clean && flutter run"
