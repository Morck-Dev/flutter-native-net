#ifndef NATIVE_NET_FFI_H
#define NATIVE_NET_FFI_H

#include <stdint.h>
#include <stddef.h>

/* ── Export macro ───────────────────────────────────────────── */
#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

/* ── Response struct returned to Dart via FFI ──────────────── */
typedef struct {
    int32_t  status_code;       /* HTTP status code (200, 404, …)     */
    char*    headers;           /* Raw headers "Key: Val\r\n…"        */
    int64_t  headers_length;    /* Byte length of headers string      */
    uint8_t* body;              /* Response body bytes                 */
    int64_t  body_length;       /* Byte length of body                */
    char*    error_message;     /* Human-readable error (NULL if ok)  */
    char*    effective_url;     /* Final URL after redirects          */
    double   total_time_ms;     /* Total request time in milliseconds */
    int32_t  curl_code;         /* libcurl CURLcode (0 = CURLE_OK)    */
} NativeNetResponse;

#ifdef __cplusplus
extern "C" {
#endif

/* ── Global init / cleanup (call once per process) ─────────── */

/**
 * Initialises libcurl globally. Must be called from the main
 * thread before any other native_net function.
 * Returns 0 on success.
 */
FFI_PLUGIN_EXPORT int32_t native_net_init(void);

/**
 * Cleans up global libcurl state. Call when the client is disposed.
 */
FFI_PLUGIN_EXPORT void native_net_cleanup(void);

/* ── Perform a request (blocking – call from a worker thread) ─ */

/**
 * Performs an HTTP request using libcurl's easy API.
 *
 * @param url                 Request URL (UTF-8).
 * @param method              HTTP method: "GET", "POST", …
 * @param headers             Headers in "Key: Value\r\n" format, or NULL.
 * @param body                Request body bytes, or NULL.
 * @param body_length         Length of body in bytes.
 * @param connect_timeout_ms  Connection timeout (ms), 0 = no limit.
 * @param timeout_ms          Overall timeout (ms), 0 = no limit.
 * @param follow_redirects    1 = follow redirects, 0 = don't.
 * @param max_redirects       Maximum number of redirects to follow.
 * @param verbose             1 = enable curl verbose logging.
 *
 * @return Heap-allocated NativeNetResponse. Caller MUST free with
 *         native_net_free_response().
 */
FFI_PLUGIN_EXPORT NativeNetResponse* native_net_request(
    const char*    url,
    const char*    method,
    const char*    headers,
    const uint8_t* body,
    int64_t        body_length,
    int64_t        connect_timeout_ms,
    int64_t        timeout_ms,
    int32_t        follow_redirects,
    int64_t        max_redirects,
    int32_t        verbose
);

/* ── Free a response ───────────────────────────────────────── */

/**
 * Frees all memory associated with a NativeNetResponse.
 */
FFI_PLUGIN_EXPORT void native_net_free_response(NativeNetResponse* response);

#ifdef __cplusplus
}
#endif

#endif /* NATIVE_NET_FFI_H */
