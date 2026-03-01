#!/usr/bin/env bash
# =============================================================================
# download_prebuilt.sh
#
# Downloads prebuilt native_net binaries from the latest GitHub Release
# and extracts them into native_net/prebuilt/.
#
# Usage:
#   bash scripts/download_prebuilt.sh                    # latest release
#   bash scripts/download_prebuilt.sh v0.3.0             # specific tag
#   REPO=user/repo bash scripts/download_prebuilt.sh     # custom repo
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PREBUILT_DIR="$PLUGIN_DIR/prebuilt"
REPO="${REPO:-Morck-Dev/flutter-native-net}"
TAG="${1:-latest}"

echo "[native_net] Downloading prebuilt binaries from $REPO ($TAG) ..."

# Determine the download URL prefix
if [ "$TAG" = "latest" ]; then
    API_URL="https://api.github.com/repos/$REPO/releases/latest"
else
    API_URL="https://api.github.com/repos/$REPO/releases/tags/$TAG"
fi

# Get release asset URLs
echo "[native_net] Fetching release info ..."
RELEASE_JSON=$(curl -sL "$API_URL")

download_asset() {
    local name="$1"
    local dest_dir="$2"
    local url

    url=$(echo "$RELEASE_JSON" | grep -o "\"browser_download_url\"[[:space:]]*:[[:space:]]*\"[^\"]*${name}[^\"]*\"" | head -1 | sed 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')

    if [ -z "$url" ]; then
        echo "[native_net] WARNING: $name not found in release, skipping."
        return 1
    fi

    echo "[native_net] Downloading $name ..."
    mkdir -p "$dest_dir"

    local tmp_file="/tmp/native_net_$$_$(basename "$name")"
    if ! curl -sL --retry 3 --retry-delay 5 -o "$tmp_file" "$url"; then
        echo "[native_net] ERROR: Failed to download $name"
        rm -f "$tmp_file"
        return 1
    fi

    echo "[native_net] Extracting to $dest_dir ..."
    case "$name" in
        *.zip)    unzip -qo "$tmp_file" -d "$dest_dir" ;;
        *.tar.gz) tar xzf "$tmp_file" -C "$dest_dir" ;;
    esac
    rm -f "$tmp_file"
    echo "[native_net] OK: $name -> $dest_dir"
}

# Clean old prebuilt
rm -rf "$PREBUILT_DIR"
mkdir -p "$PREBUILT_DIR"

# Download each platform
download_asset "native_net-windows-x64.zip"       "$PREBUILT_DIR/windows/x64"   || true
download_asset "native_net-linux-x64.tar.gz"       "$PREBUILT_DIR/linux/x64"     || true
download_asset "native_net-macos-universal.tar.gz"  "$PREBUILT_DIR/macos"         || true
download_asset "native_net-ios-arm64.tar.gz"        "$PREBUILT_DIR/ios"           || true
download_asset "native_net-android-all.tar.gz"      "$PREBUILT_DIR/android"       || true

echo ""
echo "[native_net] Prebuilt binaries downloaded to: $PREBUILT_DIR"
echo "[native_net] Directory structure:"
find "$PREBUILT_DIR" -type f 2>/dev/null | sort | sed 's|^|  |'
echo ""
echo "[native_net] Run 'flutter clean && flutter run' to use them."
