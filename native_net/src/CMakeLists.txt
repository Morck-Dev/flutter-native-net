# =============================================================================
# native_net - CMake build
#
# Build strategy (in order):
#   1. Use prebuilt binary from prebuilt/ directory (fastest, no deps)
#   2. Fall back to building libcurl from source via FetchContent
#
# To force source build: cmake -DNATIVE_NET_FORCE_BUILD=ON ...
# =============================================================================

cmake_minimum_required(VERSION 3.14)

project(native_net VERSION 0.3.0 LANGUAGES C)

option(NATIVE_NET_FORCE_BUILD "Force building from source even if prebuilt exists" OFF)

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
    else()
        set(PREBUILT_LIB "${PREBUILT_DIR}/linux/x64/libnative_net.so")
    endif()

    if(EXISTS "${PREBUILT_LIB}")
        set(USE_PREBUILT ON)
        message(STATUS "[native_net] Using PREBUILT binary: ${PREBUILT_LIB}")
    endif()
endif()

# === Path A: Use prebuilt binary ==========================================

if(USE_PREBUILT)
    add_library(native_net SHARED IMPORTED GLOBAL)

    if(WIN32)
        set_target_properties(native_net PROPERTIES IMPORTED_LOCATION "${PREBUILT_LIB}")
        set_target_properties(native_net PROPERTIES IMPORTED_IMPLIB "${PREBUILT_LIB}")
    else()
        set_target_properties(native_net PROPERTIES IMPORTED_LOCATION "${PREBUILT_LIB}")
    endif()

    # Copy the prebuilt binary to the build output so Flutter can bundle it
    if(WIN32)
        set(OUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/native_net.dll")
        add_custom_command(OUTPUT "${OUT_FILE}"
            COMMAND ${CMAKE_COMMAND} -E copy "${PREBUILT_LIB}" "${OUT_FILE}"
            DEPENDS "${PREBUILT_LIB}")
        add_custom_target(native_net_copy ALL DEPENDS "${OUT_FILE}")
    endif()

    return()
endif()

# === Path B: Build from source ============================================

message(STATUS "[native_net] No prebuilt found, building from source ...")
message(STATUS "[native_net] (Run 'bash scripts/download_prebuilt.sh' to get prebuilt binaries)")

include(FetchContent)

# --- mbedTLS (for Android & Linux) ----------------------------------------

if(ANDROID OR (UNIX AND NOT APPLE))
    message(STATUS "[native_net] Building mbedTLS from source for TLS ...")
    set(ENABLE_TESTING  OFF CACHE BOOL "" FORCE)
    set(ENABLE_PROGRAMS OFF CACHE BOOL "" FORCE)

    FetchContent_Declare(
        mbedtls
        URL      https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.2/mbedtls-3.6.2.tar.bz2
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    )
    FetchContent_GetProperties(mbedtls)
    if(NOT mbedtls_POPULATED)
        FetchContent_Populate(mbedtls)
        add_subdirectory(${mbedtls_SOURCE_DIR} ${mbedtls_BINARY_DIR} EXCLUDE_FROM_ALL)
    endif()
endif()

# --- libcurl ---------------------------------------------------------------

message(STATUS "[native_net] Building libcurl from source ...")

set(BUILD_CURL_EXE       OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS    OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING        OFF CACHE BOOL "" FORCE)
set(HTTP_ONLY             ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_LDAP    ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_LDAPS   ON CACHE BOOL "" FORCE)
set(CURL_USE_LIBPSL      OFF CACHE BOOL "" FORCE)

# TLS backend selection
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

FetchContent_Declare(
    curl
    URL      https://github.com/curl/curl/releases/download/curl-8_11_1/curl-8.11.1.tar.gz
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)

# EXCLUDE_FROM_ALL prevents curl's install() targets from causing
# INSTALL.vcxproj build failures on Windows.
FetchContent_GetProperties(curl)
if(NOT curl_POPULATED)
    FetchContent_Populate(curl)
    add_subdirectory(${curl_SOURCE_DIR} ${curl_BINARY_DIR} EXCLUDE_FROM_ALL)
endif()

set(CURL_TARGETS libcurl_static)
set(CURL_INCLUDE_DIRS
    ${curl_SOURCE_DIR}/include
    ${curl_BINARY_DIR}/include
)

# --- Build native_net shared library ----------------------------------------

add_library(native_net SHARED
    native_net_ffi.c
)

target_include_directories(native_net PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CURL_INCLUDE_DIRS}
)

target_link_libraries(native_net PRIVATE ${CURL_TARGETS})

if(MSVC)
    target_compile_definitions(native_net PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

set_target_properties(native_net PROPERTIES
    C_VISIBILITY_PRESET       default
    POSITION_INDEPENDENT_CODE ON
)

if(ANDROID)
    set_target_properties(native_net PROPERTIES OUTPUT_NAME "native_net")
endif()

if(APPLE)
    set_target_properties(native_net PROPERTIES
        FRAMEWORK  FALSE
        LINK_FLAGS "-undefined dynamic_lookup"
    )
endif()
