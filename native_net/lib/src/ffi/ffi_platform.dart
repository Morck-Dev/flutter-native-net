import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../native_net_platform_interface.dart';
import '../models/exceptions.dart';
import 'bindings.dart';
import 'native_library.dart';

/// Creates the default FFI-based platform implementation.
NativeNetPlatform createDefaultPlatform() => FfiNativeNetPlatform();

/// Platform implementation that uses libcurl via dart:ffi.
///
/// Each HTTP request is executed in a worker [Isolate] so the
/// blocking `curl_easy_perform` call never blocks the UI thread.
class FfiNativeNetPlatform extends NativeNetPlatform {
  bool _globalInitDone = false;
  late final NativeNetBindings _bindings;

  @override
  Future<String?> getPlatformVersion() async {
    // Return a descriptive string about the native backend.
    return 'libcurl (native FFI)';
  }

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    if (!_globalInitDone) {
      final lib = openNativeLibrary();
      _bindings = NativeNetBindings(lib);
      final code = _bindings.init();
      if (code != 0) {
        throw NativeNetException(
          message: 'curl_global_init failed with code $code',
          code: 'INIT_ERROR',
        );
      }
      _globalInitDone = true;
    }
  }

  @override
  Future<Map<dynamic, dynamic>> request(
    Map<String, dynamic> requestData,
  ) async {
    // Run the blocking libcurl call inside a worker isolate.
    return Isolate.run(() => _executeRequest(requestData));
  }

  @override
  Future<void> cancelRequest(String tag) async {
    // libcurl easy API does not support async cancellation from another
    // thread. In a future version we can use the multi API or abort flags.
  }

  @override
  Future<void> dispose() async {
    if (_globalInitDone) {
      _bindings.cleanup();
      _globalInitDone = false;
    }
  }
}

/// Performs the actual libcurl request inside a worker isolate.
///
/// This function is self-contained: it opens the native library and looks up
/// the functions each time. This is safe because [DynamicLibrary.open] is
/// cached at the OS level (the shared library is loaded once per process).
Map<dynamic, dynamic> _executeRequest(Map<String, dynamic> data) {
  final lib = openNativeLibrary();
  final bindings = NativeNetBindings(lib);

  final url = data['url'] as String;
  final method = data['method'] as String;
  final headersMap = data['headers'] as Map<String, String>?;
  final bodyString = data['body'] as String?;
  final bodyBytes = data['bodyBytes'] as Uint8List?;
  final connectTimeout = (data['connectTimeout'] as num?)?.toInt() ?? 0;
  final readTimeout = (data['readTimeout'] as num?)?.toInt() ?? 0;
  final followRedirects = (data['followRedirects'] as bool?) ?? true;
  final maxRedirects = (data['maxRedirects'] as num?)?.toInt() ?? 5;
  final verbose = (data['verbose'] as bool?) ?? false;

  // Build headers string: "Key: Value\r\nKey: Value\r\n"
  final headersBuf = StringBuffer();
  headersMap?.forEach((key, value) {
    headersBuf.write('$key: $value\r\n');
  });
  final headersStr = headersBuf.toString();

  // Resolve request body
  Uint8List? resolvedBody;
  if (bodyBytes != null) {
    resolvedBody = bodyBytes;
  } else if (bodyString != null) {
    resolvedBody = Uint8List.fromList(bodyString.codeUnits);
  }

  // Allocate native memory for parameters
  final urlPtr = url.toNativeUtf8();
  final methodPtr = method.toNativeUtf8();
  final headersPtr = headersStr.isNotEmpty
      ? headersStr.toNativeUtf8()
      : nullptr.cast<Utf8>();

  Pointer<Uint8> bodyPtr = nullptr;
  int bodyLength = 0;
  if (resolvedBody != null && resolvedBody.isNotEmpty) {
    bodyLength = resolvedBody.length;
    bodyPtr = calloc<Uint8>(bodyLength);
    bodyPtr.asTypedList(bodyLength).setAll(0, resolvedBody);
  }

  // Call libcurl (blocking)
  final responsePtr = bindings.request(
    urlPtr,
    methodPtr,
    headersPtr,
    bodyPtr,
    bodyLength,
    connectTimeout,
    readTimeout,
    followRedirects ? 1 : 0,
    maxRedirects,
    verbose ? 1 : 0,
  );

  // Free input buffers
  calloc.free(urlPtr);
  calloc.free(methodPtr);
  if (headersStr.isNotEmpty) calloc.free(headersPtr);
  if (bodyPtr != nullptr) calloc.free(bodyPtr);

  // Parse response
  if (responsePtr == nullptr) {
    throw const NativeNetException(
      message: 'native_net_request returned NULL',
      code: 'INTERNAL_ERROR',
    );
  }

  final ref = responsePtr.ref;
  final curlCode = ref.curlCode;

  if (curlCode != 0) {
    // Request failed at the libcurl level
    final errorMsg = ref.errorMessage != nullptr
        ? ref.errorMessage.toDartString()
        : 'Unknown curl error (code $curlCode)';
    bindings.freeResponse(responsePtr);

    // Map curl error codes to our error types
    final errorCode = _mapCurlError(curlCode);
    throw createExceptionFromPlatformError(errorCode, errorMsg, null);
  }

  // Read response data
  final statusCode = ref.statusCode;
  final totalTimeMs = ref.totalTimeMs;

  // Read body bytes
  Uint8List responseBodyBytes;
  if (ref.body != nullptr && ref.bodyLength > 0) {
    responseBodyBytes = Uint8List.fromList(
      ref.body.asTypedList(ref.bodyLength),
    );
  } else {
    responseBodyBytes = Uint8List(0);
  }

  // Read headers
  final responseHeaders = <String, String>{};
  if (ref.headers != nullptr && ref.headersLength > 0) {
    final rawHeaders = ref.headers.toDartString();
    for (final line in rawHeaders.split('\r\n')) {
      final colonIdx = line.indexOf(':');
      if (colonIdx > 0) {
        final key = line.substring(0, colonIdx).trim();
        final value = line.substring(colonIdx + 1).trim();
        responseHeaders[key.toLowerCase()] = value;
      }
    }
  }

  // Read effective URL
  String? effectiveUrl;
  if (ref.effectiveUrl != nullptr) {
    effectiveUrl = ref.effectiveUrl.toDartString();
  }

  // Free native response
  bindings.freeResponse(responsePtr);

  // Return as a map (same format as the old MethodChannel approach)
  return {
    'statusCode': statusCode,
    'headers': responseHeaders,
    'bodyBytes': responseBodyBytes,
    'reasonPhrase': _httpReasonPhrase(statusCode),
    'contentLength': responseBodyBytes.length,
    'duration': totalTimeMs.toInt(),
    'finalUrl': effectiveUrl,
  };
}

/// Maps libcurl CURLcode values to our error code strings.
String _mapCurlError(int curlCode) {
  // See https://curl.se/libcurl/c/libcurl-errors.html
  switch (curlCode) {
    case 6:  // CURLE_COULDNT_RESOLVE_HOST
    case 7:  // CURLE_COULDNT_CONNECT
    case 9:  // CURLE_REMOTE_ACCESS_DENIED
    case 45: // CURLE_INTERFACE_FAILED
    case 55: // CURLE_SEND_ERROR
    case 56: // CURLE_RECV_ERROR
      return 'CONNECTION_ERROR';
    case 28: // CURLE_OPERATION_TIMEDOUT
      return 'TIMEOUT';
    case 35: // CURLE_SSL_CONNECT_ERROR
    case 51: // CURLE_PEER_FAILED_VERIFICATION
    case 53: // CURLE_SSL_ENGINE_NOTFOUND
    case 54: // CURLE_SSL_ENGINE_SETFAILED
    case 58: // CURLE_SSL_CERTPROBLEM
    case 59: // CURLE_SSL_CIPHER
    case 60: // CURLE_SSL_CACERT
    case 64: // CURLE_USE_SSL_FAILED
    case 66: // CURLE_SSL_ENGINE_INITFAILED
    case 77: // CURLE_SSL_CACERT_BADFILE
    case 82: // CURLE_SSL_CRL_BADFILE
    case 83: // CURLE_SSL_ISSUER_ERROR
    case 90: // CURLE_SSL_PINNEDPUBKEYNOTMATCH
    case 91: // CURLE_SSL_INVALIDCERTSTATUS
      return 'CERTIFICATE_ERROR';
    case 42: // CURLE_ABORTED_BY_CALLBACK
      return 'CANCELLED';
    default:
      return 'REQUEST_ERROR';
  }
}

/// Returns a standard HTTP reason phrase for common status codes.
String _httpReasonPhrase(int statusCode) {
  switch (statusCode) {
    case 200: return 'OK';
    case 201: return 'Created';
    case 202: return 'Accepted';
    case 204: return 'No Content';
    case 301: return 'Moved Permanently';
    case 302: return 'Found';
    case 304: return 'Not Modified';
    case 400: return 'Bad Request';
    case 401: return 'Unauthorized';
    case 403: return 'Forbidden';
    case 404: return 'Not Found';
    case 405: return 'Method Not Allowed';
    case 408: return 'Request Timeout';
    case 409: return 'Conflict';
    case 422: return 'Unprocessable Entity';
    case 429: return 'Too Many Requests';
    case 500: return 'Internal Server Error';
    case 502: return 'Bad Gateway';
    case 503: return 'Service Unavailable';
    case 504: return 'Gateway Timeout';
    default:  return '';
  }
}
