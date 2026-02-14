import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ─── NativeNetProgress struct ──────────────────────────────────────────────

final class NativeNetProgressStruct extends Struct {
  @Int64()  external int downloadTotal;
  @Int64()  external int downloadNow;
  @Int64()  external int uploadTotal;
  @Int64()  external int uploadNow;
  @Int32()  external int cancelled;
  @Int32()  external int pad0;
}

// ─── NativeNetRequestOptions struct ────────────────────────────────────────
// MUST match the C struct field order exactly.

final class NativeNetRequestOptionsStruct extends Struct {
  /* Required */
  external Pointer<Utf8>  url;
  external Pointer<Utf8>  method;
  external Pointer<Utf8>  headers;
  external Pointer<Uint8> body;
  @Int64() external int   bodyLength;

  /* Timeouts */
  @Int64() external int connectTimeoutMs;
  @Int64() external int timeoutMs;

  /* Redirects */
  @Int64() external int maxRedirects;
  @Int32() external int followRedirects;

  /* TLS / SSL */
  @Int32() external int sslVerifyPeer;
  @Int32() external int sslVerifyHost;
  @Int32() external int pad1;
  external Pointer<Utf8> caInfo;
  external Pointer<Utf8> caPath;
  external Pointer<Utf8> clientCert;
  external Pointer<Utf8> clientKey;
  external Pointer<Utf8> clientCertType;
  external Pointer<Utf8> pinnedPublicKey;

  /* Proxy */
  external Pointer<Utf8> proxy;
  external Pointer<Utf8> proxyUserpwd;
  @Int32() external int proxyType;
  @Int32() external int httpProxyTunnel;

  /* HTTP Auth */
  external Pointer<Utf8> userpwd;
  @Int64() external int httpAuth;

  /* Cookies */
  external Pointer<Utf8> cookie;
  external Pointer<Utf8> cookieFile;
  external Pointer<Utf8> cookieJar;

  /* HTTP version */
  @Int32() external int httpVersion;

  /* Speed limits */
  @Int32() external int pad2;
  @Int64() external int maxRecvSpeed;
  @Int64() external int maxSendSpeed;

  /* Resume / Range */
  @Int64() external int resumeFrom;
  external Pointer<Utf8> range;

  /* User-Agent */
  external Pointer<Utf8> userAgent;

  /* DNS */
  external Pointer<Utf8> dnsServers;
  external Pointer<Utf8> resolve;

  /* File ops */
  external Pointer<Utf8> filePath;
  external Pointer<Utf8> fileField;
  external Pointer<Utf8> fileName;
  external Pointer<Utf8> mimeType;
  external Pointer<Utf8> extraFields;

  /* Misc */
  @Int32() external int verbose;
  @Int32() external int pad3;
  external Pointer<NativeNetProgressStruct> progress;
}

// ─── NativeNetResponse struct ──────────────────────────────────────────────

final class NativeNetResponseStruct extends Struct {
  @Int32()  external int statusCode;
  @Int32()  external int pad0;
  external Pointer<Utf8>  headers;
  @Int64()  external int  headersLength;
  external Pointer<Uint8> body;
  @Int64()  external int  bodyLength;
  external Pointer<Utf8>  errorMessage;
  external Pointer<Utf8>  effectiveUrl;
  @Double() external double totalTimeMs;
  @Int32()  external int curlCode;
  @Int32()  external int pad1;
}

// ─── C function types ──────────────────────────────────────────────────────

// ignore_for_file: library_private_types_in_public_api
typedef _InitN = Int32 Function();
typedef _InitD = int Function();

typedef _CleanupN = Void Function();
typedef _CleanupD = void Function();

typedef _RequestN = Pointer<NativeNetResponseStruct> Function(
    Pointer<NativeNetRequestOptionsStruct>);
typedef _RequestD = Pointer<NativeNetResponseStruct> Function(
    Pointer<NativeNetRequestOptionsStruct>);

typedef _FreeN = Void Function(Pointer<NativeNetResponseStruct>);
typedef _FreeD = void Function(Pointer<NativeNetResponseStruct>);

// ─── Bindings holder ───────────────────────────────────────────────────────

class NativeNetBindings {
  final _InitD init;
  final _CleanupD cleanup;
  final _RequestD request;
  final _RequestD downloadFile;
  final _RequestD uploadFile;
  final _FreeD freeResponse;

  NativeNetBindings(DynamicLibrary lib)
      : init         = lib.lookupFunction<_InitN, _InitD>('native_net_init'),
        cleanup      = lib.lookupFunction<_CleanupN, _CleanupD>('native_net_cleanup'),
        request      = lib.lookupFunction<_RequestN, _RequestD>('native_net_request'),
        downloadFile = lib.lookupFunction<_RequestN, _RequestD>('native_net_download_file'),
        uploadFile   = lib.lookupFunction<_RequestN, _RequestD>('native_net_upload_file'),
        freeResponse = lib.lookupFunction<_FreeN, _FreeD>('native_net_free_response');
}
