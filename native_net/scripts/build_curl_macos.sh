#!/usr/bin/env bash
# =============================================================================
# build_curl_macos.sh
#
# Downloads and builds libcurl as a static library for macOS.
# Uses Apple Secure Transport for TLS – zero external dependencies.
#
# Usage:
#   ./build_curl_macos.sh [output_dir]
# =============================================================================

set -euo pipefail

CURL_VERSION="8.11.1"
CURL_URL="https://github.com/curl/curl/releases/download/curl-8_11_1/curl-${CURL_VERSION}.tar.gz"
MIN_MACOS_VERSION="10.11"

OUTPUT_DIR="${1:-$(dirname "$0")/../macos/Frameworks/curl-macos}"
BUILD_DIR="/tmp/native_net_curl_macos_build_$$"

# Skip if already built
if [ -f "${OUTPUT_DIR}/lib/libcurl.a" ] && [ -d "${OUTPUT_DIR}/include/curl" ]; then
    echo "[native_net] libcurl already built at ${OUTPUT_DIR}, skipping."
    exit 0
fi

echo "[native_net] Building libcurl ${CURL_VERSION} for macOS …"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

# Download source
curl -sL "${CURL_URL}" | tar xz -C "${BUILD_DIR}"
CURL_SRC="${BUILD_DIR}/curl-${CURL_VERSION}"

# Build for the host architecture using CMake
cmake -S "${CURL_SRC}" -B "${BUILD_DIR}/build" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${MIN_MACOS_VERSION}" \
    -DCMAKE_INSTALL_PREFIX="${OUTPUT_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_CURL_EXE=OFF \
    -DBUILD_TESTING=OFF \
    -DHTTP_ONLY=ON \
    -DCURL_USE_SECTRANSP=ON \
    -DCURL_USE_OPENSSL=OFF \
    -DCURL_DISABLE_LDAP=ON \
    -DCURL_DISABLE_LDAPS=ON \
    > /dev/null 2>&1

cmake --build "${BUILD_DIR}/build" --config Release --parallel > /dev/null 2>&1
cmake --install "${BUILD_DIR}/build" --config Release > /dev/null 2>&1

echo "[native_net] libcurl ${CURL_VERSION} for macOS built successfully."

# Cleanup
rm -rf "${BUILD_DIR}"
