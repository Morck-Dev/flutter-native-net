import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ─── NativeNetProgress struct ──────────────────────────────────────────────

/// Shared progress struct. Lives in Dart-allocated native memory so
/// both the main isolate (polling) and the worker isolate (C callback)
/// can access it.
final class NativeNetProgressStruct extends Struct {
  @Int64()
  external int downloadTotal;

  @Int64()
  external int downloadNow;

  @Int64()
  external int uploadTotal;

  @Int64()
  external int uploadNow;

  @Int32()
  external int cancelled;
}

// ─── NativeNetResponse struct ──────────────────────────────────────────────

final class NativeNetResponseStruct extends Struct {
  @Int32()
  external int statusCode;

  external Pointer<Utf8> headers;

  @Int64()
  external int headersLength;

  external Pointer<Uint8> body;

  @Int64()
  external int bodyLength;

  external Pointer<Utf8> errorMessage;

  external Pointer<Utf8> effectiveUrl;

  @Double()
  external double totalTimeMs;

  @Int32()
  external int curlCode;
}

// ─── C function type definitions ───────────────────────────────────────────

// int32_t native_net_init(void)
typedef NativeNetInitNative = Int32 Function();
typedef NativeNetInitDart = int Function();

// void native_net_cleanup(void)
typedef NativeNetCleanupNative = Void Function();
typedef NativeNetCleanupDart = void Function();

// NativeNetResponse* native_net_request(…, NativeNetProgress*)
typedef NativeNetRequestNative = Pointer<NativeNetResponseStruct> Function(
  Pointer<Utf8> url,
  Pointer<Utf8> method,
  Pointer<Utf8> headers,
  Pointer<Uint8> body,
  Int64 bodyLength,
  Int64 connectTimeoutMs,
  Int64 timeoutMs,
  Int32 followRedirects,
  Int64 maxRedirects,
  Int32 verbose,
  Pointer<NativeNetProgressStruct> progress,
);
typedef NativeNetRequestDart = Pointer<NativeNetResponseStruct> Function(
  Pointer<Utf8> url,
  Pointer<Utf8> method,
  Pointer<Utf8> headers,
  Pointer<Uint8> body,
  int bodyLength,
  int connectTimeoutMs,
  int timeoutMs,
  int followRedirects,
  int maxRedirects,
  int verbose,
  Pointer<NativeNetProgressStruct> progress,
);

// NativeNetResponse* native_net_download_file(…)
typedef NativeNetDownloadNative = Pointer<NativeNetResponseStruct> Function(
  Pointer<Utf8> url,
  Pointer<Utf8> headers,
  Pointer<Utf8> filePath,
  Int64 connectTimeoutMs,
  Int64 timeoutMs,
  Int32 followRedirects,
  Int64 maxRedirects,
  Int32 verbose,
  Pointer<NativeNetProgressStruct> progress,
);
typedef NativeNetDownloadDart = Pointer<NativeNetResponseStruct> Function(
  Pointer<Utf8> url,
  Pointer<Utf8> headers,
  Pointer<Utf8> filePath,
  int connectTimeoutMs,
  int timeoutMs,
  int followRedirects,
  int maxRedirects,
  int verbose,
  Pointer<NativeNetProgressStruct> progress,
);

// NativeNetResponse* native_net_upload_file(…)
typedef NativeNetUploadNative = Pointer<NativeNetResponseStruct> Function(
  Pointer<Utf8> url,
  Pointer<Utf8> method,
  Pointer<Utf8> headers,
  Pointer<Utf8> filePath,
  Pointer<Utf8> fileField,
  Pointer<Utf8> fileName,
  Pointer<Utf8> mimeType,
  Pointer<Utf8> extraFields,
  Int64 connectTimeoutMs,
  Int64 timeoutMs,
  Int32 followRedirects,
  Int64 maxRedirects,
  Int32 verbose,
  Pointer<NativeNetProgressStruct> progress,
);
typedef NativeNetUploadDart = Pointer<NativeNetResponseStruct> Function(
  Pointer<Utf8> url,
  Pointer<Utf8> method,
  Pointer<Utf8> headers,
  Pointer<Utf8> filePath,
  Pointer<Utf8> fileField,
  Pointer<Utf8> fileName,
  Pointer<Utf8> mimeType,
  Pointer<Utf8> extraFields,
  int connectTimeoutMs,
  int timeoutMs,
  int followRedirects,
  int maxRedirects,
  int verbose,
  Pointer<NativeNetProgressStruct> progress,
);

// void native_net_free_response(NativeNetResponse*)
typedef NativeNetFreeResponseNative = Void Function(
  Pointer<NativeNetResponseStruct>,
);
typedef NativeNetFreeResponseDart = void Function(
  Pointer<NativeNetResponseStruct>,
);

// ─── Bindings holder ───────────────────────────────────────────────────────

class NativeNetBindings {
  final NativeNetInitDart init;
  final NativeNetCleanupDart cleanup;
  final NativeNetRequestDart request;
  final NativeNetDownloadDart downloadFile;
  final NativeNetUploadDart uploadFile;
  final NativeNetFreeResponseDart freeResponse;

  NativeNetBindings(DynamicLibrary lib)
      : init = lib.lookupFunction<NativeNetInitNative, NativeNetInitDart>(
          'native_net_init',
        ),
        cleanup =
            lib.lookupFunction<NativeNetCleanupNative, NativeNetCleanupDart>(
          'native_net_cleanup',
        ),
        request =
            lib.lookupFunction<NativeNetRequestNative, NativeNetRequestDart>(
          'native_net_request',
        ),
        downloadFile =
            lib.lookupFunction<NativeNetDownloadNative, NativeNetDownloadDart>(
          'native_net_download_file',
        ),
        uploadFile =
            lib.lookupFunction<NativeNetUploadNative, NativeNetUploadDart>(
          'native_net_upload_file',
        ),
        freeResponse = lib.lookupFunction<NativeNetFreeResponseNative,
            NativeNetFreeResponseDart>(
          'native_net_free_response',
        );
}
