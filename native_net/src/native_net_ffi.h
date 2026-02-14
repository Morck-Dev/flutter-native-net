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

/* ── Progress struct (shared between Dart main isolate & C) ── */
typedef struct {
    int64_t download_total;   /* Total bytes to download (0 if unknown) */
    int64_t download_now;     /* Bytes downloaded so far                */
    int64_t upload_total;     /* Total bytes to upload   (0 if unknown) */
    int64_t upload_now;       /* Bytes uploaded so far                  */
    int32_t cancelled;        /* Set to 1 from Dart to abort transfer  */
} NativeNetProgress;

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

/* ── Global init / cleanup ─────────────────────────────────── */

FFI_PLUGIN_EXPORT int32_t native_net_init(void);
FFI_PLUGIN_EXPORT void    native_net_cleanup(void);

/* ── Perform a request (blocking – call from a worker isolate) */

/**
 * Performs a standard HTTP request using libcurl's easy API.
 * The response body is collected in memory.
 *
 * @param progress  Optional pointer to a progress struct. If non-NULL,
 *                  it is updated during transfer and checked for
 *                  cancellation. The struct lives in Dart-allocated
 *                  native memory shared across isolates.
 */
FFI_PLUGIN_EXPORT NativeNetResponse* native_net_request(
    const char*       url,
    const char*       method,
    const char*       headers,
    const uint8_t*    body,
    int64_t           body_length,
    int64_t           connect_timeout_ms,
    int64_t           timeout_ms,
    int32_t           follow_redirects,
    int64_t           max_redirects,
    int32_t           verbose,
    NativeNetProgress* progress
);

/* ── Download to file ──────────────────────────────────────── */

/**
 * Downloads a URL directly to a local file.
 * The response body is NOT stored in the returned struct (body will
 * be NULL and body_length will be 0). Headers, status code, timing
 * etc. are still populated.
 */
FFI_PLUGIN_EXPORT NativeNetResponse* native_net_download_file(
    const char*       url,
    const char*       headers,
    const char*       file_path,
    int64_t           connect_timeout_ms,
    int64_t           timeout_ms,
    int32_t           follow_redirects,
    int64_t           max_redirects,
    int32_t           verbose,
    NativeNetProgress* progress
);

/* ── Upload file (multipart/form-data) ─────────────────────── */

/**
 * Uploads a local file as a multipart/form-data POST request.
 * Uses curl_mime so the file is streamed from disk – never loaded
 * entirely into memory.
 *
 * @param file_path       Local path to the file to upload.
 * @param file_field      Form field name (e.g. "file").
 * @param file_name       Display name sent in Content-Disposition (or NULL
 *                        to use the file_path basename).
 * @param mime_type       MIME type (e.g. "image/jpeg"), or NULL for auto.
 * @param extra_fields    Additional form fields as "key=val\nkey=val\n",
 *                        or NULL.
 */
FFI_PLUGIN_EXPORT NativeNetResponse* native_net_upload_file(
    const char*       url,
    const char*       method,
    const char*       headers,
    const char*       file_path,
    const char*       file_field,
    const char*       file_name,
    const char*       mime_type,
    const char*       extra_fields,
    int64_t           connect_timeout_ms,
    int64_t           timeout_ms,
    int32_t           follow_redirects,
    int64_t           max_redirects,
    int32_t           verbose,
    NativeNetProgress* progress
);

/* ── Free a response ───────────────────────────────────────── */

FFI_PLUGIN_EXPORT void native_net_free_response(NativeNetResponse* response);

#ifdef __cplusplus
}
#endif

#endif /* NATIVE_NET_FFI_H */
