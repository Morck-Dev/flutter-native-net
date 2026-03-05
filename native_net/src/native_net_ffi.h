#ifndef NATIVE_NET_FFI_H
#define NATIVE_NET_FFI_H

#include <stdint.h>
#include <stddef.h>

/* Export macro */
#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

/* Progress / cancellation struct */
typedef struct {
    int64_t download_total;
    int64_t download_now;
    int64_t upload_total;
    int64_t upload_now;
    int32_t cancelled;        /* set to 1 from Dart to abort */
    int32_t _pad0;
} NativeNetProgress;

/* Request options (comprehensive) */
/*
 * A single struct that carries ALL request parameters.
 * Zeroed memory gives safe defaults for every field.
 *
 * FIELD DEFAULTS (when memory is zeroed / 0):
 *   ssl_verify_peer = 0  -> we treat 0 as "use default (verify)"
 *   ssl_verify_host = 0  -> we treat 0 as "use default (verify)"
 *   To explicitly disable, set ssl_verify_peer = -1 or ssl_verify_host = -1.
 *
 * NOTE: The field order MUST match the Dart FFI struct exactly.
 */
typedef struct {
    /* Required */
    const char*    url;
    const char*    method;            /* "GET","POST",...            */
    const char*    headers;           /* "K: V\r\n..." or NULL      */
    const uint8_t* body;
    int64_t        body_length;

    /* Timeouts (ms, 0 = no limit) */
    int64_t        connect_timeout_ms;
    int64_t        timeout_ms;

    /* Redirects */
    int64_t        max_redirects;     /* 0 = default (50)           */
    int32_t        follow_redirects;  /* 1=follow, 0=don't, -1=default */

    /* TLS / SSL */
    int32_t        ssl_verify_peer;   /*  1=verify, -1=skip, 0=default(verify)  */
    int32_t        ssl_verify_host;   /*  2=verify, -1=skip, 0=default(verify)  */
    int32_t        _pad1;
    const char*    ca_info;           /* path to CA bundle file     */
    const char*    ca_path;           /* path to CA directory        */
    const char*    client_cert;       /* path to client cert         */
    const char*    client_key;        /* path to client priv key     */
    const char*    client_cert_type;  /* "PEM" (default) or "DER"    */
    const char*    pinned_public_key; /* "sha256//base64..."         */

    /* Proxy */
    const char*    proxy;             /* "http://host:port"          */
    const char*    proxy_userpwd;     /* "user:pass"                 */
    int32_t        proxy_type;        /* 0=HTTP,4=SOCKS4,5=SOCKS5   */
    int32_t        http_proxy_tunnel; /* 1=tunnel through proxy      */

    /* HTTP Auth */
    const char*    userpwd;           /* "user:pass"                 */
    int64_t        http_auth;         /* CURLAUTH bitmask            */

    /* Cookies */
    const char*    cookie;            /* "name=val; name2=val2"      */
    const char*    cookie_file;       /* read cookies from file      */
    const char*    cookie_jar;        /* write cookies to file       */

    /* HTTP version */
    int32_t        http_version;      /* 0=auto,1=1.0,2=1.1,3=H2,4=H3 */

    /* Speed limits (bytes/sec, 0 = unlimited) */
    int32_t        _pad2;
    int64_t        max_recv_speed;
    int64_t        max_send_speed;

    /* Resume / Range */
    int64_t        resume_from;       /* byte offset to resume       */
    const char*    range;             /* "0-499" or NULL             */

    /* User-Agent */
    const char*    user_agent;

    /* DNS */
    const char*    dns_servers;       /* "1.1.1.1,8.8.8.8"          */
    const char*    resolve;           /* "host:port:addr,..."        */

    /* File ops (download / upload) */
    const char*    file_path;         /* download dest / upload src  */
    const char*    file_field;        /* upload: form field name     */
    const char*    file_name;         /* upload: display filename    */
    const char*    mime_type;         /* upload: MIME type            */
    const char*    extra_fields;      /* upload: "k=v\nk=v\n"       */

    /* Misc */
    int32_t        verbose;
    int32_t        _pad3;
    NativeNetProgress* progress;
} NativeNetRequestOptions;

/* Response struct */
typedef struct {
    int32_t  status_code;
    int32_t  _pad0;
    char*    headers;
    int64_t  headers_length;
    uint8_t* body;
    int64_t  body_length;
    char*    error_message;
    char*    effective_url;
    double   total_time_ms;
    int32_t  curl_code;
    int32_t  _pad1;
} NativeNetResponse;

#ifdef __cplusplus
extern "C" {
#endif

/* Global init / cleanup */
FFI_PLUGIN_EXPORT int32_t native_net_init(void);
FFI_PLUGIN_EXPORT void    native_net_cleanup(void);

/* Request (body in memory) */
FFI_PLUGIN_EXPORT NativeNetResponse* native_net_request(
    const NativeNetRequestOptions* opts);

/* Download to file */
FFI_PLUGIN_EXPORT NativeNetResponse* native_net_download_file(
    const NativeNetRequestOptions* opts);

/* Upload file (multipart) */
FFI_PLUGIN_EXPORT NativeNetResponse* native_net_upload_file(
    const NativeNetRequestOptions* opts);

/* Free response */
FFI_PLUGIN_EXPORT void native_net_free_response(NativeNetResponse* r);

#ifdef __cplusplus
}
#endif

#endif /* NATIVE_NET_FFI_H */
