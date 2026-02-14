# =============================================================================
# native_net – CMake build
#
# Builds the native_net_ffi shared library which wraps libcurl.
#
# Strategy for finding libcurl:
#   1. Try system-installed libcurl  (macOS, Linux typically have it)
#   2. If not found, download & build libcurl from source via FetchContent
#      with a platform-appropriate TLS backend:
#        • Android  → mbedTLS  (built from source)
#        • Windows  → Schannel (system)
#        • Apple    → Secure Transport (system)
#        • Linux    → OpenSSL  (system, should already be present)
# =============================================================================

cmake_minimum_required(VERSION 3.14)

project(native_net VERSION 0.1.0 LANGUAGES C)

# ─── Try to find system libcurl ──────────────────────────────────────────────

find_package(CURL QUIET)

if(CURL_FOUND)
    message(STATUS "[native_net] Using system libcurl: ${CURL_VERSION_STRING}")
    set(CURL_TARGETS CURL::libcurl)
else()
    message(STATUS "[native_net] System libcurl not found – building from source …")
    include(FetchContent)

    # ── mbedTLS (needed for Android which lacks a system TLS library) ────────
    if(ANDROID)
        message(STATUS "[native_net] Building mbedTLS for Android TLS …")
        set(ENABLE_TESTING  OFF CACHE BOOL "" FORCE)
        set(ENABLE_PROGRAMS OFF CACHE BOOL "" FORCE)

        FetchContent_Declare(
            mbedtls
            URL      https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.2/mbedtls-3.6.2.tar.bz2
            DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        )
        FetchContent_MakeAvailable(mbedtls)
    endif()

    # ── libcurl itself ───────────────────────────────────────────────────────
    set(BUILD_CURL_EXE      OFF CACHE BOOL "" FORCE)
    set(BUILD_SHARED_LIBS   OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTING       OFF CACHE BOOL "" FORCE)
    set(CURL_DISABLE_INSTALL ON CACHE BOOL "" FORCE)
    set(HTTP_ONLY            ON CACHE BOOL "" FORCE)   # we only need HTTP(S)
    set(CURL_DISABLE_LDAP   ON CACHE BOOL "" FORCE)
    set(CURL_DISABLE_LDAPS  ON CACHE BOOL "" FORCE)

    # TLS backend per platform
    if(ANDROID)
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
    else()
        # Linux fallback – try OpenSSL
        set(CURL_USE_OPENSSL    ON CACHE BOOL "" FORCE)
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
endif()

# ─── Build our wrapper shared library ────────────────────────────────────────

add_library(native_net SHARED
    native_net_ffi.c
)

target_include_directories(native_net PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CURL_INCLUDE_DIRS}
)

target_link_libraries(native_net PRIVATE ${CURL_TARGETS})

# Ensure symbols are visible for FFI
set_target_properties(native_net PROPERTIES
    C_VISIBILITY_PRESET     default
    POSITION_INDEPENDENT_CODE ON
)

# On Android, strip and set SONAME
if(ANDROID)
    set_target_properties(native_net PROPERTIES
        OUTPUT_NAME "native_net"
    )
endif()

# On Apple, allow undefined symbols (Flutter host provides them at load time)
if(APPLE)
    set_target_properties(native_net PROPERTIES
        FRAMEWORK FALSE
        LINK_FLAGS "-undefined dynamic_lookup"
    )
endif()
