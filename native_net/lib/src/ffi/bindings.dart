import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ─── NativeNetResponse struct (mirrors the C struct) ───────────────────────

/// Dart FFI representation of the C `NativeNetResponse` struct.
///
/// Layout must match the C definition exactly.
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

// NativeNetResponse* native_net_request(...)
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
);

// void native_net_free_response(NativeNetResponse*)
typedef NativeNetFreeResponseNative = Void Function(
  Pointer<NativeNetResponseStruct>,
);
typedef NativeNetFreeResponseDart = void Function(
  Pointer<NativeNetResponseStruct>,
);

// ─── Bindings holder ───────────────────────────────────────────────────────

/// Resolved FFI function pointers for the native_net C library.
class NativeNetBindings {
  final NativeNetInitDart init;
  final NativeNetCleanupDart cleanup;
  final NativeNetRequestDart request;
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
        freeResponse = lib.lookupFunction<NativeNetFreeResponseNative,
            NativeNetFreeResponseDart>(
          'native_net_free_response',
        );
}
