/*
 * native_net_ffi.c
 *
 * Thin C wrapper around libcurl's easy API.
 * This is compiled into a shared/static library for each platform and
 * called from Dart via dart:ffi.
 *
 * libcurl handles:
 *   - HTTP/1.1, HTTP/2, HTTP/3 (depending on build)
 *   - TLS via the platform backend (Secure Transport, Schannel, mbedTLS, …)
 *   - Connection pooling, transparent gzip, cookie jar, redirects
 */

#include "native_net_ffi.h"

#include <curl/curl.h>
#include <stdlib.h>
#include <string.h>

/* ── Portable strndup (MSVC does not have it) ──────────────── */
#if defined(_MSC_VER)
static char* nn_strndup(const char* s, size_t n) {
    size_t len = 0;
    while (len < n && s[len]) ++len;
    char* p = (char*)malloc(len + 1);
    if (p) { memcpy(p, s, len); p[len] = '\0'; }
    return p;
}
#else
#define nn_strndup strndup
#endif

/* ── Dynamic byte buffer ───────────────────────────────────── */

typedef struct {
    uint8_t* data;
    size_t   size;
    size_t   capacity;
} Buffer;

static void buffer_init(Buffer* b) {
    b->data     = NULL;
    b->size     = 0;
    b->capacity = 0;
}

static int buffer_append(Buffer* b, const uint8_t* src, size_t len) {
    if (b->size + len > b->capacity) {
        size_t cap = (b->capacity == 0) ? 4096 : b->capacity;
        while (cap < b->size + len) cap *= 2;
        uint8_t* p = (uint8_t*)realloc(b->data, cap);
        if (!p) return -1;
        b->data     = p;
        b->capacity = cap;
    }
    memcpy(b->data + b->size, src, len);
    b->size += len;
    return 0;
}

static void buffer_free(Buffer* b) {
    free(b->data);
    b->data     = NULL;
    b->size     = 0;
    b->capacity = 0;
}

/* ── libcurl callbacks ─────────────────────────────────────── */

static size_t write_cb(void* ptr, size_t size, size_t nmemb, void* userdata) {
    Buffer* buf = (Buffer*)userdata;
    size_t total = size * nmemb;
    return buffer_append(buf, (uint8_t*)ptr, total) == 0 ? total : 0;
}

static size_t header_cb(char* ptr, size_t size, size_t nitems, void* userdata) {
    Buffer* buf = (Buffer*)userdata;
    size_t total = size * nitems;
    return buffer_append(buf, (uint8_t*)ptr, total) == 0 ? total : 0;
}

/* ── Helper: create a failed response ──────────────────────── */

static NativeNetResponse* make_error(int32_t code, const char* msg) {
    NativeNetResponse* r = (NativeNetResponse*)calloc(1, sizeof(*r));
    if (!r) return NULL;
    r->curl_code     = code;
    r->error_message = msg ? strdup(msg) : NULL;
    return r;
}

/* ── Public API ────────────────────────────────────────────── */

FFI_PLUGIN_EXPORT
int32_t native_net_init(void) {
    return (int32_t)curl_global_init(CURL_GLOBAL_ALL);
}

FFI_PLUGIN_EXPORT
void native_net_cleanup(void) {
    curl_global_cleanup();
}

FFI_PLUGIN_EXPORT
NativeNetResponse* native_net_request(
    const char*    url,
    const char*    method,
    const char*    headers,
    const uint8_t* body,
    int64_t        body_length,
    int64_t        connect_timeout_ms,
    int64_t        timeout_ms,
    int32_t        follow_redirects,
    int64_t        max_redirects,
    int32_t        verbose)
{
    if (!url || !method) {
        return make_error(-1, "url and method must not be NULL");
    }

    CURL* curl = curl_easy_init();
    if (!curl) {
        return make_error(-1, "curl_easy_init failed");
    }

    NativeNetResponse* response = (NativeNetResponse*)calloc(1, sizeof(*response));
    if (!response) {
        curl_easy_cleanup(curl);
        return NULL;
    }

    Buffer body_buf, hdr_buf;
    buffer_init(&body_buf);
    buffer_init(&hdr_buf);

    /* ---- URL ---- */
    curl_easy_setopt(curl, CURLOPT_URL, url);

    /* ---- HTTP method ---- */
    if (strcmp(method, "GET") == 0) {
        curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);
    } else if (strcmp(method, "POST") == 0) {
        curl_easy_setopt(curl, CURLOPT_POST, 1L);
    } else if (strcmp(method, "HEAD") == 0) {
        curl_easy_setopt(curl, CURLOPT_NOBODY, 1L);
    } else {
        /* PUT, DELETE, PATCH, OPTIONS, etc. */
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);
    }

    /* ---- Request headers ---- */
    struct curl_slist* slist = NULL;
    if (headers && *headers) {
        const char* p = headers;
        while (*p) {
            /* Find the next \r\n or \n or end-of-string */
            const char* eol = strstr(p, "\r\n");
            if (!eol) {
                eol = strchr(p, '\n');
                if (!eol) eol = p + strlen(p);
            }
            if (eol > p) {
                char* line = nn_strndup(p, (size_t)(eol - p));
                if (line) {
                    slist = curl_slist_append(slist, line);
                    free(line);
                }
            }
            /* Advance past the delimiter */
            if (*eol == '\r' && *(eol+1) == '\n') p = eol + 2;
            else if (*eol == '\n')                 p = eol + 1;
            else                                   p = eol;
        }
        if (slist) {
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, slist);
        }
    }

    /* ---- Request body ---- */
    if (body && body_length > 0) {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE_LARGE, (curl_off_t)body_length);
    } else if (strcmp(method, "POST") == 0 || strcmp(method, "PUT") == 0 || strcmp(method, "PATCH") == 0) {
        /* Ensure an empty body is sent for methods that typically have one */
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, "");
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, 0L);
    }

    /* ---- Write / header callbacks ---- */
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION,  write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA,      &body_buf);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION,  header_cb);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA,      &hdr_buf);

    /* ---- Timeouts ---- */
    if (connect_timeout_ms > 0) {
        curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, (long)connect_timeout_ms);
    }
    if (timeout_ms > 0) {
        curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, (long)timeout_ms);
    }

    /* ---- Redirects ---- */
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, (long)(follow_redirects ? 1 : 0));
    if (max_redirects > 0) {
        curl_easy_setopt(curl, CURLOPT_MAXREDIRS, (long)max_redirects);
    }

    /* ---- Verbose ---- */
    if (verbose) {
        curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
    }

    /* ---- Misc performance options ---- */
    curl_easy_setopt(curl, CURLOPT_ACCEPT_ENCODING, "");    /* auto decompress  */
    curl_easy_setopt(curl, CURLOPT_TCP_KEEPALIVE,    1L);   /* TCP keep-alive   */
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL,         1L);   /* thread-safe      */

    /* ---- Execute ---- */
    CURLcode res = curl_easy_perform(curl);
    response->curl_code = (int32_t)res;

    if (res == CURLE_OK) {
        /* Status code */
        long code = 0;
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &code);
        response->status_code = (int32_t)code;

        /* Effective URL */
        char* eff = NULL;
        curl_easy_getinfo(curl, CURLINFO_EFFECTIVE_URL, &eff);
        if (eff) response->effective_url = strdup(eff);

        /* Total time */
        double tt = 0;
        curl_easy_getinfo(curl, CURLINFO_TOTAL_TIME, &tt);
        response->total_time_ms = tt * 1000.0;

        /* Body – transfer ownership */
        response->body        = body_buf.data;
        response->body_length = (int64_t)body_buf.size;
        body_buf.data = NULL;

        /* Headers – null-terminate and transfer ownership */
        if (hdr_buf.size > 0) {
            buffer_append(&hdr_buf, (const uint8_t*)"\0", 1);
            response->headers        = (char*)hdr_buf.data;
            response->headers_length = (int64_t)(hdr_buf.size - 1);
            hdr_buf.data = NULL;
        }
    } else {
        response->error_message = strdup(curl_easy_strerror(res));
    }

    /* ---- Cleanup ---- */
    if (slist) curl_slist_free_all(slist);
    buffer_free(&body_buf);
    buffer_free(&hdr_buf);
    curl_easy_cleanup(curl);

    return response;
}

FFI_PLUGIN_EXPORT
void native_net_free_response(NativeNetResponse* r) {
    if (!r) return;
    free(r->headers);
    free(r->body);
    free(r->error_message);
    free(r->effective_url);
    free(r);
}
