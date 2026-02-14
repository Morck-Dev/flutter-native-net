# =============================================================================
# native_net – CMake build
#
# ALWAYS builds libcurl from source via FetchContent so that the plugin
# works regardless of whether the host system has libcurl installed.
#
# TLS backend per platform (all use system-level TLS, no OpenSSL needed):
#   • Android  → mbedTLS      (built from source alongside curl)
#   • Linux    → mbedTLS      (built from source — zero system dependency)
#   • Windows  → Schannel     (provided by the OS)
#   • Apple    → SecureTransport (provided by the OS)
# =============================================================================

cmake_minimum_required(VERSION 3.14)

project(native_net VERSION 0.2.0 LANGUAGES C)

include(FetchContent)

# ─── mbedTLS (for Android & Linux which need a bundled TLS library) ──────────

if(ANDROID OR (UNIX AND NOT APPLE))
    message(STATUS "[native_net] Building mbedTLS from source for TLS …")
    set(ENABLE_TESTING  OFF CACHE BOOL "" FORCE)
    set(ENABLE_PROGRAMS OFF CACHE BOOL "" FORCE)

    FetchContent_Declare(
        mbedtls
        URL      https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.2/mbedtls-3.6.2.tar.bz2
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    )
    FetchContent_MakeAvailable(mbedtls)
endif()

# ─── libcurl (always built from source) ─────────────────────────────────────

message(STATUS "[native_net] Building libcurl from source …")

set(BUILD_CURL_EXE       OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS    OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING        OFF CACHE BOOL "" FORCE)
set(CURL_DISABLE_INSTALL  ON CACHE BOOL "" FORCE)
set(HTTP_ONLY             ON CACHE BOOL "" FORCE)   # only HTTP(S)
set(CURL_DISABLE_LDAP    ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_LDAPS   ON CACHE BOOL "" FORCE)

# TLS backend selection
if(ANDROID OR (UNIX AND NOT APPLE))
    # Android & Linux → mbedTLS (zero system dependency)
    set(CURL_USE_OPENSSL   OFF CACHE BOOL "" FORCE)
    set(CURL_USE_MBEDTLS    ON CACHE BOOL "" FORCE)
    set(MBEDTLS_INCLUDE_DIRS "${mbedtls_SOURCE_DIR}/include" CACHE STRING "" FORCE)
    set(MBEDTLS_LIBRARY      mbedtls      CACHE STRING "" FORCE)
    set(MBEDX509_LIBRARY     mbedx509     CACHE STRING "" FORCE)
    set(MBEDCRYPTO_LIBRARY   mbedcrypto   CACHE STRING "" FORCE)
elseif(WIN32)
    # Windows → Schannel (always available)
    set(CURL_USE_OPENSSL   OFF CACHE BOOL "" FORCE)
    set(CURL_USE_SCHANNEL   ON CACHE BOOL "" FORCE)
elseif(APPLE)
    # macOS / iOS → Secure Transport (always available)
    set(CURL_USE_OPENSSL   OFF CACHE BOOL "" FORCE)
    set(CURL_USE_SECTRANSP  ON CACHE BOOL "" FORCE)
endif()

FetchContent_Declare(
    curl
    URL      https://github.com/curl/curl/releases/download/curl-8_11_1/curl-8.11.1.tar.gz
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_MakeAvailable(curl)

set(CURL_TARGETS libcurl_static)
set(CURL_INCLUDE_DIRS
    ${curl_SOURCE_DIR}/include
    ${curl_BINARY_DIR}/include
)

# ─── Build our wrapper shared library ────────────────────────────────────────

add_library(native_net SHARED
    native_net_ffi.c
)

target_include_directories(native_net PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CURL_INCLUDE_DIRS}
)

target_link_libraries(native_net PRIVATE ${CURL_TARGETS})

set_target_properties(native_net PROPERTIES
    C_VISIBILITY_PRESET       default
    POSITION_INDEPENDENT_CODE ON
)

if(ANDROID)
    set_target_properties(native_net PROPERTIES
        OUTPUT_NAME "native_net"
    )
endif()

if(APPLE)
    set_target_properties(native_net PROPERTIES
        FRAMEWORK  FALSE
        LINK_FLAGS "-undefined dynamic_lookup"
    )
endif()
