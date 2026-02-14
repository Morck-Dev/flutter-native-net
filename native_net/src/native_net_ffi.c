/*
 * native_net_ffi.c  –  libcurl wrapper for Flutter FFI
 *
 * All platforms share this single C file.
 * libcurl is always built from source (via CMake FetchContent) so the
 * plugin works even on systems without a pre-installed libcurl.
 */

#include "native_net_ffi.h"

#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ── Portable helpers ──────────────────────────────────────── */

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
    b->data = NULL; b->size = 0; b->capacity = 0;
}

static int buffer_append(Buffer* b, const uint8_t* src, size_t len) {
    if (b->size + len > b->capacity) {
        size_t cap = (b->capacity == 0) ? 4096 : b->capacity;
        while (cap < b->size + len) cap *= 2;
        uint8_t* p = (uint8_t*)realloc(b->data, cap);
        if (!p) return -1;
        b->data = p;
        b->capacity = cap;
    }
    memcpy(b->data + b->size, src, len);
    b->size += len;
    return 0;
}

static void buffer_free(Buffer* b) {
    free(b->data);
    b->data = NULL; b->size = 0; b->capacity = 0;
}

/* ── curl callbacks ────────────────────────────────────────── */

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

static size_t write_file_cb(void* ptr, size_t size, size_t nmemb, void* userdata) {
    FILE* fp = (FILE*)userdata;
    return fwrite(ptr, size, nmemb, fp);
}

/* Progress callback – updates the shared NativeNetProgress struct and
   checks whether Dart has requested cancellation. */
static int progress_cb(void* clientp,
                        curl_off_t dltotal, curl_off_t dlnow,
                        curl_off_t ultotal, curl_off_t ulnow) {
    NativeNetProgress* p = (NativeNetProgress*)clientp;
    if (!p) return 0;
    p->download_total = (int64_t)dltotal;
    p->download_now   = (int64_t)dlnow;
    p->upload_total   = (int64_t)ultotal;
    p->upload_now     = (int64_t)ulnow;
    return p->cancelled ? 1 : 0;   /* non-zero aborts the transfer */
}

/* ── Helpers ───────────────────────────────────────────────── */

static NativeNetResponse* make_error(int32_t code, const char* msg) {
    NativeNetResponse* r = (NativeNetResponse*)calloc(1, sizeof(*r));
    if (!r) return NULL;
    r->curl_code     = code;
    r->error_message = msg ? strdup(msg) : NULL;
    return r;
}

/* Parse "Key: Value\r\n…" header string into a curl_slist. */
static struct curl_slist* parse_headers(const char* headers) {
    struct curl_slist* slist = NULL;
    if (!headers || !*headers) return NULL;

    const char* p = headers;
    while (*p) {
        const char* eol = strstr(p, "\r\n");
        if (!eol) { eol = strchr(p, '\n'); if (!eol) eol = p + strlen(p); }
        if (eol > p) {
            char* line = nn_strndup(p, (size_t)(eol - p));
            if (line) { slist = curl_slist_append(slist, line); free(line); }
        }
        if (*eol == '\r' && *(eol+1) == '\n') p = eol + 2;
        else if (*eol == '\n')                 p = eol + 1;
        else                                   p = eol;
    }
    return slist;
}

/* Apply common curl options shared by all request types. */
static void apply_common_opts(CURL* curl,
                               struct curl_slist* slist,
                               int64_t connect_timeout_ms,
                               int64_t timeout_ms,
                               int32_t follow_redirects,
                               int64_t max_redirects,
                               int32_t verbose,
                               NativeNetProgress* progress,
                               Buffer* hdr_buf) {
    if (slist) curl_easy_setopt(curl, CURLOPT_HTTPHEADER, slist);

    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, header_cb);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, hdr_buf);

    if (connect_timeout_ms > 0)
        curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, (long)connect_timeout_ms);
    if (timeout_ms > 0)
        curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, (long)timeout_ms);

    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, (long)(follow_redirects ? 1 : 0));
    if (max_redirects > 0)
        curl_easy_setopt(curl, CURLOPT_MAXREDIRS, (long)max_redirects);

    if (verbose)
        curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);

    curl_easy_setopt(curl, CURLOPT_ACCEPT_ENCODING, "");
    curl_easy_setopt(curl, CURLOPT_TCP_KEEPALIVE, 1L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);

    if (progress) {
        curl_easy_setopt(curl, CURLOPT_XFERINFOFUNCTION, progress_cb);
        curl_easy_setopt(curl, CURLOPT_XFERINFODATA, progress);
        curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);
    }
}

/* Fill response metadata after a successful perform. */
static void fill_response_meta(CURL* curl, NativeNetResponse* r, Buffer* hdr_buf) {
    long code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &code);
    r->status_code = (int32_t)code;

    char* eff = NULL;
    curl_easy_getinfo(curl, CURLINFO_EFFECTIVE_URL, &eff);
    if (eff) r->effective_url = strdup(eff);

    double tt = 0;
    curl_easy_getinfo(curl, CURLINFO_TOTAL_TIME, &tt);
    r->total_time_ms = tt * 1000.0;

    if (hdr_buf->size > 0) {
        buffer_append(hdr_buf, (const uint8_t*)"\0", 1);
        r->headers        = (char*)hdr_buf->data;
        r->headers_length = (int64_t)(hdr_buf->size - 1);
        hdr_buf->data     = NULL;   /* ownership transferred */
    }
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

/* ─── Standard request (body in memory) ─────────────────────── */

FFI_PLUGIN_EXPORT
NativeNetResponse* native_net_request(
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
    NativeNetProgress* progress)
{
    if (!url || !method) return make_error(-1, "url and method must not be NULL");

    CURL* curl = curl_easy_init();
    if (!curl) return make_error(-1, "curl_easy_init failed");

    NativeNetResponse* response = (NativeNetResponse*)calloc(1, sizeof(*response));
    if (!response) { curl_easy_cleanup(curl); return NULL; }

    Buffer body_buf, hdr_buf;
    buffer_init(&body_buf);
    buffer_init(&hdr_buf);

    curl_easy_setopt(curl, CURLOPT_URL, url);

    /* HTTP method */
    if      (strcmp(method, "GET")  == 0) curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);
    else if (strcmp(method, "POST") == 0) curl_easy_setopt(curl, CURLOPT_POST, 1L);
    else if (strcmp(method, "HEAD") == 0) curl_easy_setopt(curl, CURLOPT_NOBODY, 1L);
    else                                  curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);

    struct curl_slist* slist = parse_headers(headers);
    apply_common_opts(curl, slist, connect_timeout_ms, timeout_ms,
                      follow_redirects, max_redirects, verbose, progress, &hdr_buf);

    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &body_buf);

    /* Request body */
    if (body && body_length > 0) {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE_LARGE, (curl_off_t)body_length);
    } else if (strcmp(method, "POST") == 0 || strcmp(method, "PUT") == 0 ||
               strcmp(method, "PATCH") == 0) {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, "");
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, 0L);
    }

    CURLcode res = curl_easy_perform(curl);
    response->curl_code = (int32_t)res;

    if (res == CURLE_OK) {
        fill_response_meta(curl, response, &hdr_buf);
        response->body        = body_buf.data;
        response->body_length = (int64_t)body_buf.size;
        body_buf.data = NULL;
    } else {
        response->error_message = strdup(curl_easy_strerror(res));
    }

    if (slist) curl_slist_free_all(slist);
    buffer_free(&body_buf);
    buffer_free(&hdr_buf);
    curl_easy_cleanup(curl);
    return response;
}

/* ─── Download to file ──────────────────────────────────────── */

FFI_PLUGIN_EXPORT
NativeNetResponse* native_net_download_file(
    const char*       url,
    const char*       headers,
    const char*       file_path,
    int64_t           connect_timeout_ms,
    int64_t           timeout_ms,
    int32_t           follow_redirects,
    int64_t           max_redirects,
    int32_t           verbose,
    NativeNetProgress* progress)
{
    if (!url)       return make_error(-1, "url must not be NULL");
    if (!file_path) return make_error(-1, "file_path must not be NULL");

    FILE* fp = fopen(file_path, "wb");
    if (!fp) return make_error(-1, "Cannot open file for writing");

    CURL* curl = curl_easy_init();
    if (!curl) { fclose(fp); return make_error(-1, "curl_easy_init failed"); }

    NativeNetResponse* response = (NativeNetResponse*)calloc(1, sizeof(*response));
    if (!response) { curl_easy_cleanup(curl); fclose(fp); return NULL; }

    Buffer hdr_buf;
    buffer_init(&hdr_buf);

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);

    struct curl_slist* slist = parse_headers(headers);
    apply_common_opts(curl, slist, connect_timeout_ms, timeout_ms,
                      follow_redirects, max_redirects, verbose, progress, &hdr_buf);

    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_file_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);

    CURLcode res = curl_easy_perform(curl);
    fclose(fp);

    response->curl_code = (int32_t)res;

    if (res == CURLE_OK) {
        fill_response_meta(curl, response, &hdr_buf);
        /* body stays NULL – data was written to disk */
    } else {
        response->error_message = strdup(curl_easy_strerror(res));
        /* Remove the partial file on error */
        remove(file_path);
    }

    if (slist) curl_slist_free_all(slist);
    buffer_free(&hdr_buf);
    curl_easy_cleanup(curl);
    return response;
}

/* ─── Upload file (multipart) ───────────────────────────────── */

FFI_PLUGIN_EXPORT
NativeNetResponse* native_net_upload_file(
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
    NativeNetProgress* progress)
{
    if (!url)       return make_error(-1, "url must not be NULL");
    if (!file_path) return make_error(-1, "file_path must not be NULL");

    CURL* curl = curl_easy_init();
    if (!curl) return make_error(-1, "curl_easy_init failed");

    NativeNetResponse* response = (NativeNetResponse*)calloc(1, sizeof(*response));
    if (!response) { curl_easy_cleanup(curl); return NULL; }

    Buffer body_buf, hdr_buf;
    buffer_init(&body_buf);
    buffer_init(&hdr_buf);

    curl_easy_setopt(curl, CURLOPT_URL, url);

    const char* m = (method && *method) ? method : "POST";
    if (strcmp(m, "POST") == 0) curl_easy_setopt(curl, CURLOPT_POST, 1L);
    else                        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, m);

    struct curl_slist* slist = parse_headers(headers);
    apply_common_opts(curl, slist, connect_timeout_ms, timeout_ms,
                      follow_redirects, max_redirects, verbose, progress, &hdr_buf);

    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &body_buf);

    /* Build multipart form using curl_mime */
    curl_mime* mime = curl_mime_init(curl);
    curl_mimepart* part;

    /* File part – streamed from disk, not loaded into memory */
    part = curl_mime_addpart(mime);
    curl_mime_name(part, file_field ? file_field : "file");
    curl_mime_filedata(part, file_path);
    if (file_name && *file_name)
        curl_mime_filename(part, file_name);
    if (mime_type && *mime_type)
        curl_mime_type(part, mime_type);

    /* Extra form fields: "key=value\nkey=value\n" */
    if (extra_fields && *extra_fields) {
        const char* p = extra_fields;
        while (*p) {
            const char* eol = strchr(p, '\n');
            if (!eol) eol = p + strlen(p);
            const char* eq = memchr(p, '=', (size_t)(eol - p));
            if (eq && eq > p) {
                char* key = nn_strndup(p, (size_t)(eq - p));
                char* val = nn_strndup(eq + 1, (size_t)(eol - eq - 1));
                if (key && val) {
                    part = curl_mime_addpart(mime);
                    curl_mime_name(part, key);
                    curl_mime_data(part, val, CURL_ZERO_TERMINATED);
                }
                free(key);
                free(val);
            }
            p = (*eol == '\n') ? eol + 1 : eol;
        }
    }

    curl_easy_setopt(curl, CURLOPT_MIMEPOST, mime);

    CURLcode res = curl_easy_perform(curl);
    response->curl_code = (int32_t)res;

    if (res == CURLE_OK) {
        fill_response_meta(curl, response, &hdr_buf);
        response->body        = body_buf.data;
        response->body_length = (int64_t)body_buf.size;
        body_buf.data = NULL;
    } else {
        response->error_message = strdup(curl_easy_strerror(res));
    }

    curl_mime_free(mime);
    if (slist) curl_slist_free_all(slist);
    buffer_free(&body_buf);
    buffer_free(&hdr_buf);
    curl_easy_cleanup(curl);
    return response;
}

/* ── Free ──────────────────────────────────────────────────── */

FFI_PLUGIN_EXPORT
void native_net_free_response(NativeNetResponse* r) {
    if (!r) return;
    free(r->headers);
    free(r->body);
    free(r->error_message);
    free(r->effective_url);
    free(r);
}
