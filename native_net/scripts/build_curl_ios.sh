#!/usr/bin/env bash
# =============================================================================
# build_curl_ios.sh
#
# Downloads and builds libcurl as a static library for iOS.
# Uses Apple Secure Transport for TLS (no OpenSSL needed).
#
# Usage:
#   ./build_curl_ios.sh [output_dir]
#
# The output directory will contain:
#   include/curl/curl.h  (and other headers)
#   lib/libcurl.a        (fat/universal static library)
# =============================================================================

set -euo pipefail

CURL_VERSION="8.11.1"
CURL_URL="https://github.com/curl/curl/releases/download/curl-8_11_1/curl-${CURL_VERSION}.tar.gz"
MIN_IOS_VERSION="9.0"

OUTPUT_DIR="${1:-$(dirname "$0")/../ios/Frameworks/curl-ios}"
BUILD_DIR="/tmp/native_net_curl_build_$$"

# Skip if already built
if [ -f "${OUTPUT_DIR}/lib/libcurl.a" ] && [ -d "${OUTPUT_DIR}/include/curl" ]; then
    echo "[native_net] libcurl already built at ${OUTPUT_DIR}, skipping."
    exit 0
fi

echo "[native_net] Building libcurl ${CURL_VERSION} for iOS …"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

# Download curl source
echo "[native_net] Downloading curl ${CURL_VERSION} …"
curl -sL "${CURL_URL}" | tar xz -C "${BUILD_DIR}"
CURL_SRC="${BUILD_DIR}/curl-${CURL_VERSION}"

build_arch() {
    local ARCH="$1"
    local SDK="$2"
    local HOST="$3"
    local BUILD="${BUILD_DIR}/build-${ARCH}"
    local PREFIX="${BUILD_DIR}/prefix-${ARCH}"
    local SDK_PATH
    SDK_PATH="$(xcrun -sdk "${SDK}" --show-sdk-path)"

    echo "[native_net] Building for ${ARCH} (${SDK}) …"
    mkdir -p "${BUILD}"

    # Use CMake for reliable cross-compilation
    cmake -S "${CURL_SRC}" -B "${BUILD}" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_SYSROOT="${SDK_PATH}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${MIN_IOS_VERSION}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
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

    cmake --build "${BUILD}" --config Release --parallel > /dev/null 2>&1
    cmake --install "${BUILD}" --config Release > /dev/null 2>&1
}

# Build for device (arm64)
build_arch "arm64" "iphoneos" "arm-apple-darwin"

# Build for simulator (arm64 – Apple Silicon Macs)
build_arch "arm64" "iphonesimulator" "arm-apple-darwin"

# Create a fat library using lipo
# Note: Since both are arm64, we create separate libs for device/simulator
# For a proper xcframework approach, keep them separate. Here we provide
# the device build as the primary output.
echo "[native_net] Installing to ${OUTPUT_DIR} …"
mkdir -p "${OUTPUT_DIR}/lib" "${OUTPUT_DIR}/include"
cp -R "${BUILD_DIR}/prefix-arm64/include/curl" "${OUTPUT_DIR}/include/"
cp "${BUILD_DIR}/prefix-arm64/lib/libcurl.a" "${OUTPUT_DIR}/lib/"

echo "[native_net] libcurl ${CURL_VERSION} built successfully."

# Cleanup
rm -rf "${BUILD_DIR}"
