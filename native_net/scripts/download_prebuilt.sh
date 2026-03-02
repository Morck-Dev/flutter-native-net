#!/usr/bin/env bash
# =============================================================================
# download_prebuilt.sh
#
# Downloads prebuilt native_net binaries from GitHub Releases.
# Supports system proxy (HTTP_PROXY / HTTPS_PROXY / ALL_PROXY).
#
# Usage:
#   bash scripts/download_prebuilt.sh                    # latest release
#   bash scripts/download_prebuilt.sh v0.3.1             # specific tag
#   REPO=user/repo bash scripts/download_prebuilt.sh     # custom repo
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO="${REPO:-Morck-Dev/flutter-native-net}"
TAG="${1:-latest}"

# ── Proxy detection ────────────────────────────────────────────────────────
# curl automatically uses HTTP_PROXY/HTTPS_PROXY/ALL_PROXY env vars.
# We just detect and report for user visibility.

detect_proxy() {
    local proxy=""
    if [ -n "${HTTPS_PROXY:-}" ]; then
        proxy="$HTTPS_PROXY"
    elif [ -n "${https_proxy:-}" ]; then
        proxy="$https_proxy"
    elif [ -n "${HTTP_PROXY:-}" ]; then
        proxy="$HTTP_PROXY"
    elif [ -n "${http_proxy:-}" ]; then
        proxy="$http_proxy"
    elif [ -n "${ALL_PROXY:-}" ]; then
        proxy="$ALL_PROXY"
    elif [ -n "${all_proxy:-}" ]; then
        proxy="$all_proxy"
    fi

    if [ -n "$proxy" ]; then
        echo "[native_net] Proxy detected: $proxy"
    else
        echo "[native_net] No proxy detected."
        echo "[native_net] If you need a proxy, set HTTPS_PROXY before running:"
        echo "[native_net]   export HTTPS_PROXY=http://127.0.0.1:7890"
        echo "[native_net]   bash scripts/download_prebuilt.sh"
    fi
}

detect_proxy

# ── Resolve latest tag ─────────────────────────────────────────────────────

if [ "$TAG" = "latest" ]; then
    echo "[native_net] Resolving latest release tag ..."
    TAG=$(curl -sL --retry 3 --retry-delay 3 \
        "https://api.github.com/repos/$REPO/releases/latest" | \
        grep '"tag_name"' | head -1 | \
        sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [ -z "$TAG" ]; then
        echo "[native_net] ERROR: Could not resolve latest tag."
        echo "[native_net] Try: bash scripts/download_prebuilt.sh v0.3.1"
        exit 1
    fi
    echo "[native_net] Latest release: $TAG"
fi

BASE_URL="https://github.com/$REPO/releases/download/$TAG"

# ── Download helper (with proxy, retry, timeout) ───────────────────────────

download() {
    local file="$1"
    local dest="$2"
    local url="$BASE_URL/$file"

    echo "[native_net] Downloading $file ..."
    mkdir -p "$(dirname "$dest")"

    # curl automatically uses HTTPS_PROXY/HTTP_PROXY/ALL_PROXY
    if curl -fSL \
        --retry 3 \
        --retry-delay 5 \
        --connect-timeout 30 \
        --max-time 300 \
        -o "$dest" "$url"; then
        echo "[native_net]   OK -> $dest"
        return 0
    else
        echo "[native_net]   FAILED: $file"
        echo "[native_net]   URL: $url"
        echo "[native_net]   If behind a firewall, set proxy:"
        echo "[native_net]     export HTTPS_PROXY=http://127.0.0.1:7890"
        rm -f "$dest"
        return 1
    fi
}

echo ""
echo "[native_net] Downloading prebuilt binaries ($TAG) from $REPO ..."
echo ""

PREBUILT="$PLUGIN_DIR/prebuilt"
mkdir -p "$PREBUILT"

# ── Android ────────────────────────────────────────────────────────────────
# Also download AAR here for users who can't auto-download via Gradle
if download "native_net.aar" "$PLUGIN_DIR/android/native_net.aar"; then
    echo "[native_net]   Android AAR ready (Gradle will use local file)"
fi

# ── iOS XCFramework ───────────────────────────────────────────────────────
if download "native_net-xcframework.tar.gz" "/tmp/nn_xcfw_$$.tar.gz"; then
    rm -rf "$PLUGIN_DIR/ios/Frameworks/native_net.xcframework"
    mkdir -p "$PLUGIN_DIR/ios/Frameworks"
    tar xzf "/tmp/nn_xcfw_$$.tar.gz" -C "$PLUGIN_DIR/ios/Frameworks/"
    rm -f "/tmp/nn_xcfw_$$.tar.gz"
    echo "[native_net]   -> ios/Frameworks/native_net.xcframework/"
fi

# ── macOS XCFramework ────────────────────────────────────────────────────
if download "native_net-xcframework.tar.gz" "/tmp/nn_xcfw_mac_$$.tar.gz"; then
    rm -rf "$PLUGIN_DIR/macos/Frameworks/native_net.xcframework"
    mkdir -p "$PLUGIN_DIR/macos/Frameworks"
    tar xzf "/tmp/nn_xcfw_mac_$$.tar.gz" -C "$PLUGIN_DIR/macos/Frameworks/"
    rm -f "/tmp/nn_xcfw_mac_$$.tar.gz"
    echo "[native_net]   -> macos/Frameworks/native_net.xcframework/"
fi

# ── Windows DLL ──────────────────────────────────────────────────────────
if download "native_net-windows-x64.zip" "/tmp/nn_win_$$.zip"; then
    mkdir -p "$PREBUILT/windows/x64"
    unzip -qo "/tmp/nn_win_$$.zip" -d "$PREBUILT/windows/x64/"
    rm -f "/tmp/nn_win_$$.zip"
fi

# ── Linux SO ─────────────────────────────────────────────────────────────
if download "native_net-linux-x64.tar.gz" "/tmp/nn_linux_$$.tar.gz"; then
    mkdir -p "$PREBUILT/linux/x64"
    tar xzf "/tmp/nn_linux_$$.tar.gz" -C "$PREBUILT/linux/x64/"
    rm -f "/tmp/nn_linux_$$.tar.gz"
fi

echo ""
echo "[native_net] Done. Downloaded files:"
find "$PLUGIN_DIR/android" -name "native_net.aar" 2>/dev/null | sed "s|$PLUGIN_DIR/|  |"
find "$PLUGIN_DIR/ios/Frameworks" "$PLUGIN_DIR/macos/Frameworks" "$PREBUILT" \
     -type f 2>/dev/null | sort | sed "s|$PLUGIN_DIR/|  |"
echo ""
echo "[native_net] Run 'flutter clean && flutter run' to use them."
