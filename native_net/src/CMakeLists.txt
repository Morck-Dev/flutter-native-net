# =============================================================================
# native_net - CMake build
#
# Build strategy:
#   1. Check prebuilt/ for precompiled binaries (fastest)
#   2. Fall back to building libcurl from source via FetchContent
#
# TLS backends: mbedTLS (Android/Linux), Schannel (Win), SecureTransport (Apple)
# =============================================================================

cmake_minimum_required(VERSION 3.14)

# Allow FetchContent_Populate on CMake 3.30+ (avoids CMP0169 warning)
if(POLICY CMP0169)
    cmake_policy(SET CMP0169 OLD)
endif()

project(native_net VERSION 0.3.0 LANGUAGES C)

# All sub-builds (mbedtls, curl) must produce PIC code so they
# can be linked into our shared library (.so/.dylib/.dll).
set(CMAKE_POSITION_INDEPENDENT_CODE ON CACHE BOOL "" FORCE)

option(NATIVE_NET_FORCE_BUILD "Force building from source even if prebuilt exists" OFF)

# Disable install() AND export() from curl/mbedtls.
# curl calls both install(EXPORT CURLTargets ...) and export(TARGETS libcurl_static ...),
# and both fail when mbedtls targets aren't in the export set.
set(_NN_SKIP_EXPORT TRUE)
macro(install)
    if(NOT _NN_SKIP_EXPORT)
        _install(${ARGV})
    endif()
endmacro()
macro(export)
    if(NOT _NN_SKIP_EXPORT)
        _export(${ARGV})
    endif()
endmacro()

# === Check for prebuilt binary ============================================

set(PREBUILT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../prebuilt")
set(USE_PREBUILT OFF)

if(NOT NATIVE_NET_FORCE_BUILD)
    if(WIN32)
        set(PREBUILT_LIB "${PREBUILT_DIR}/windows/x64/native_net.dll")
    elseif(ANDROID)
        set(PREBUILT_LIB "${PREBUILT_DIR}/android/${ANDROID_ABI}/libnative_net.so")
    elseif(APPLE AND CMAKE_SYSTEM_NAME STREQUAL "iOS")
        set(PREBUILT_LIB "${PREBUILT_DIR}/ios/libnative_net.a")
    elseif(APPLE)
        set(PREBUILT_LIB "${PREBUILT_DIR}/macos/libnative_net.dylib")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64|ARM64")
        set(PREBUILT_LIB "${PREBUILT_DIR}/linux/arm64/libnative_net.so")
    else()
        set(PREBUILT_LIB "${PREBUILT_DIR}/linux/x64/libnative_net.so")
    endif()

    if(EXISTS "${PREBUILT_LIB}")
        set(USE_PREBUILT ON)
        message(STATUS "[native_net] Using PREBUILT binary: ${PREBUILT_LIB}")
    endif()
endif()

if(USE_PREBUILT)
    add_library(native_net SHARED IMPORTED GLOBAL)
    set_target_properties(native_net PROPERTIES IMPORTED_LOCATION "${PREBUILT_LIB}")
    if(WIN32)
        set_target_properties(native_net PROPERTIES IMPORTED_IMPLIB "${PREBUILT_LIB}")
    endif()
    return()
endif()

# === Build from source ====================================================

message(STATUS "[native_net] Building from source (run 'bash scripts/download_prebuilt.sh' for prebuilt)")

include(FetchContent)

# --- mbedTLS (Android & Linux) --------------------------------------------

if(ANDROID OR (UNIX AND NOT APPLE))
    message(STATUS "[native_net] Building mbedTLS ...")
    set(ENABLE_TESTING  OFF CACHE BOOL "" FORCE)
    set(ENABLE_PROGRAMS OFF CACHE BOOL "" FORCE)
    # mbedTLS static libs must be PIC to link into our shared library
    set(CMAKE_POSITION_INDEPENDENT_CODE ON CACHE BOOL "" FORCE)

    FetchContent_Declare(mbedtls
        URL      https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.2/mbedtls-3.6.2.tar.bz2
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    )
    FetchContent_GetProperties(mbedtls)
    if(NOT mbedtls_POPULATED)
        FetchContent_Populate(mbedtls)
        add_subdirectory(${mbedtls_SOURCE_DIR} ${mbedtls_BINARY_DIR})
    endif()
endif()

# --- libcurl ---------------------------------------------------------------

message(STATUS "[native_net] Building libcurl ...")

set(BUILD_CURL_EXE       OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS    OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING        OFF CACHE BOOL "" FORCE)
set(BUILD_LIBCURL_DOCS   OFF CACHE BOOL "" FORCE)
set(ENABLE_CURL_MANUAL   OFF CACHE BOOL "" FORCE)
set(HTTP_ONLY             ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_LDAP    ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_LDAPS   ON CACHE BOOL "" FORCE)
set(CURL_USE_LIBPSL      OFF CACHE BOOL "" FORCE)
set(CURL_USE_LIBSSH2     OFF CACHE BOOL "" FORCE)
set(USE_LIBIDN2          OFF CACHE BOOL "" FORCE)
set(CURL_USE_LIBIDN2     OFF CACHE BOOL "" FORCE)
set(USE_NGHTTP2          OFF CACHE BOOL "" FORCE)
set(CURL_DISABLE_ALTSVC  ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_DOH     ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_NETRC   ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_NTLM    ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_VERBOSE_STRINGS ON CACHE BOOL "" FORCE)

if(ANDROID OR (UNIX AND NOT APPLE))
    set(CURL_USE_OPENSSL   OFF CACHE BOOL "" FORCE)
    set(CURL_USE_MBEDTLS    ON CACHE BOOL "" FORCE)
    set(MBEDTLS_INCLUDE_DIRS "${mbedtls_SOURCE_DIR}/include" CACHE STRING "" FORCE)
    set(MBEDTLS_LIBRARY      mbedtls      CACHE STRING "" FORCE)
    set(MBEDX509_LIBRARY     mbedx509     CACHE STRING "" FORCE)
    set(MBEDCRYPTO_LIBRARY   mbedcrypto   CACHE STRING "" FORCE)
elseif(WIN32)
    set(CURL_USE_OPENSSL   OFF CACHE BOOL "" FORCE)
    set(CURL_USE_SCHANNEL   ON CACHE BOOL "" FORCE)
elseif(APPLE)
    set(CURL_USE_OPENSSL   OFF CACHE BOOL "" FORCE)
    set(CURL_USE_SECTRANSP  ON CACHE BOOL "" FORCE)
endif()

FetchContent_Declare(curl
    URL      https://github.com/curl/curl/releases/download/curl-8_11_1/curl-8.11.1.tar.gz
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_GetProperties(curl)
if(NOT curl_POPULATED)
    FetchContent_Populate(curl)
    add_subdirectory(${curl_SOURCE_DIR} ${curl_BINARY_DIR})
endif()

set(CURL_TARGETS libcurl_static)
set(CURL_INCLUDE_DIRS
    ${curl_SOURCE_DIR}/include
    ${curl_BINARY_DIR}/include
)

# Re-enable install() and export() for our own targets
set(_NN_SKIP_EXPORT FALSE)

# --- native_net library ----------------------------------------------------

# Apple platforms: build STATIC (.a) — CocoaPods links it into the app.
# Other platforms: build SHARED (.so/.dll) — loaded via DynamicLibrary.open().
if(APPLE)
    add_library(native_net STATIC native_net_ffi.c)
else()
    add_library(native_net SHARED native_net_ffi.c)
endif()

target_include_directories(native_net PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CURL_INCLUDE_DIRS}
)

target_link_libraries(native_net PRIVATE ${CURL_TARGETS})

# Apple: link system frameworks for Secure Transport
if(APPLE)
    target_link_libraries(native_net PRIVATE
        "-framework Security"
        "-framework CoreFoundation"
        "-framework SystemConfiguration"
    )
endif()

if(MSVC)
    target_compile_definitions(native_net PRIVATE _CRT_SECURE_NO_WARNINGS)
else()
    # Optimize for size on non-MSVC compilers (GCC/Clang)
    target_compile_options(native_net PRIVATE -Os)
endif()

set_target_properties(native_net PROPERTIES
    C_VISIBILITY_PRESET       hidden
    POSITION_INDEPENDENT_CODE ON
)

# Only export our FFI functions, hide everything else
set_target_properties(native_net PROPERTIES
    C_VISIBILITY_PRESET hidden
)

if(ANDROID)
    set_target_properties(native_net PROPERTIES OUTPUT_NAME "native_net")
    # Strip debug symbols from the final .so (huge size reduction)
    add_custom_command(TARGET native_net POST_BUILD
        COMMAND ${CMAKE_STRIP} --strip-unneeded $<TARGET_FILE:native_net>
        COMMENT "[native_net] Stripping debug symbols from libnative_net.so"
    )
endif()

# Strip on Linux too
if(UNIX AND NOT APPLE AND NOT ANDROID)
    add_custom_command(TARGET native_net POST_BUILD
        COMMAND strip --strip-unneeded $<TARGET_FILE:native_net> || true
        COMMENT "[native_net] Stripping debug symbols"
    )
endif()
