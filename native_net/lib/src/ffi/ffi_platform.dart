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
class FfiNativeNetPlatform extends NativeNetPlatform {
  bool _globalInitDone = false;
  late final NativeNetBindings _bindings;

  @override
  Future<String?> getPlatformVersion() async => 'libcurl (native FFI)';

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
  Future<Map<dynamic, dynamic>> request(Map<String, dynamic> requestData) async {
    return Isolate.run(() => _executeRequest(requestData));
  }

  @override
  Future<Map<dynamic, dynamic>> downloadFile(
    Map<String, dynamic> data,
  ) async {
    final progressAddr = data['_progressAddr'] as int? ?? 0;
    return Isolate.run(() => _executeDownload(data, progressAddr));
  }

  @override
  Future<Map<dynamic, dynamic>> uploadFile(
    Map<String, dynamic> data,
  ) async {
    final progressAddr = data['_progressAddr'] as int? ?? 0;
    return Isolate.run(() => _executeUpload(data, progressAddr));
  }

  @override
  Future<void> cancelRequest(String tag) async {}

  @override
  Future<void> dispose() async {
    if (_globalInitDone) {
      _bindings.cleanup();
      _globalInitDone = false;
    }
  }
}

// ─── Isolate entry points ─────────────────────────────────────────────────

/// Standard request (body in memory).
Map<dynamic, dynamic> _executeRequest(Map<String, dynamic> data) {
  final lib = openNativeLibrary();
  final b = NativeNetBindings(lib);

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
  final progressAddr = data['_progressAddr'] as int? ?? 0;

  final headersStr = _buildHeadersString(headersMap);

  Uint8List? resolvedBody;
  if (bodyBytes != null) {
    resolvedBody = bodyBytes;
  } else if (bodyString != null) {
    resolvedBody = Uint8List.fromList(bodyString.codeUnits);
  }

  final urlPtr = url.toNativeUtf8();
  final methodPtr = method.toNativeUtf8();
  final headersPtr =
      headersStr.isNotEmpty ? headersStr.toNativeUtf8() : nullptr.cast<Utf8>();

  Pointer<Uint8> bodyPtr = nullptr;
  int bodyLength = 0;
  if (resolvedBody != null && resolvedBody.isNotEmpty) {
    bodyLength = resolvedBody.length;
    bodyPtr = calloc<Uint8>(bodyLength);
    bodyPtr.asTypedList(bodyLength).setAll(0, resolvedBody);
  }

  final progressPtr = progressAddr != 0
      ? Pointer<NativeNetProgressStruct>.fromAddress(progressAddr)
      : nullptr.cast<NativeNetProgressStruct>();

  final responsePtr = b.request(
    urlPtr, methodPtr, headersPtr, bodyPtr, bodyLength,
    connectTimeout, readTimeout,
    followRedirects ? 1 : 0, maxRedirects,
    verbose ? 1 : 0, progressPtr,
  );

  calloc.free(urlPtr);
  calloc.free(methodPtr);
  if (headersStr.isNotEmpty) calloc.free(headersPtr);
  if (bodyPtr != nullptr) calloc.free(bodyPtr);

  return _parseResponse(responsePtr, b);
}

/// Download to file.
Map<dynamic, dynamic> _executeDownload(
  Map<String, dynamic> data,
  int progressAddr,
) {
  final lib = openNativeLibrary();
  final b = NativeNetBindings(lib);

  final url = data['url'] as String;
  final filePath = data['filePath'] as String;
  final headersMap = data['headers'] as Map<String, String>?;
  final connectTimeout = (data['connectTimeout'] as num?)?.toInt() ?? 0;
  final readTimeout = (data['readTimeout'] as num?)?.toInt() ?? 0;
  final followRedirects = (data['followRedirects'] as bool?) ?? true;
  final maxRedirects = (data['maxRedirects'] as num?)?.toInt() ?? 5;
  final verbose = (data['verbose'] as bool?) ?? false;

  final headersStr = _buildHeadersString(headersMap);

  final urlPtr = url.toNativeUtf8();
  final headersPtr =
      headersStr.isNotEmpty ? headersStr.toNativeUtf8() : nullptr.cast<Utf8>();
  final filePathPtr = filePath.toNativeUtf8();
  final progressPtr = progressAddr != 0
      ? Pointer<NativeNetProgressStruct>.fromAddress(progressAddr)
      : nullptr.cast<NativeNetProgressStruct>();

  final responsePtr = b.downloadFile(
    urlPtr, headersPtr, filePathPtr,
    connectTimeout, readTimeout,
    followRedirects ? 1 : 0, maxRedirects,
    verbose ? 1 : 0, progressPtr,
  );

  calloc.free(urlPtr);
  if (headersStr.isNotEmpty) calloc.free(headersPtr);
  calloc.free(filePathPtr);

  return _parseResponse(responsePtr, b);
}

/// Upload file (multipart).
Map<dynamic, dynamic> _executeUpload(
  Map<String, dynamic> data,
  int progressAddr,
) {
  final lib = openNativeLibrary();
  final b = NativeNetBindings(lib);

  final url = data['url'] as String;
  final method = (data['method'] as String?) ?? 'POST';
  final headersMap = data['headers'] as Map<String, String>?;
  final filePath = data['filePath'] as String;
  final fileField = (data['fileField'] as String?) ?? 'file';
  final fileName = data['fileName'] as String?;
  final mimeType = data['mimeType'] as String?;
  final extraFields = data['extraFields'] as String?;
  final connectTimeout = (data['connectTimeout'] as num?)?.toInt() ?? 0;
  final readTimeout = (data['readTimeout'] as num?)?.toInt() ?? 0;
  final followRedirects = (data['followRedirects'] as bool?) ?? true;
  final maxRedirects = (data['maxRedirects'] as num?)?.toInt() ?? 5;
  final verbose = (data['verbose'] as bool?) ?? false;

  final headersStr = _buildHeadersString(headersMap);

  final urlPtr = url.toNativeUtf8();
  final methodPtr = method.toNativeUtf8();
  final headersPtr =
      headersStr.isNotEmpty ? headersStr.toNativeUtf8() : nullptr.cast<Utf8>();
  final filePathPtr = filePath.toNativeUtf8();
  final fileFieldPtr = fileField.toNativeUtf8();
  final fileNamePtr =
      fileName != null ? fileName.toNativeUtf8() : nullptr.cast<Utf8>();
  final mimeTypePtr =
      mimeType != null ? mimeType.toNativeUtf8() : nullptr.cast<Utf8>();
  final extraFieldsPtr =
      extraFields != null ? extraFields.toNativeUtf8() : nullptr.cast<Utf8>();
  final progressPtr = progressAddr != 0
      ? Pointer<NativeNetProgressStruct>.fromAddress(progressAddr)
      : nullptr.cast<NativeNetProgressStruct>();

  final responsePtr = b.uploadFile(
    urlPtr, methodPtr, headersPtr,
    filePathPtr, fileFieldPtr, fileNamePtr, mimeTypePtr, extraFieldsPtr,
    connectTimeout, readTimeout,
    followRedirects ? 1 : 0, maxRedirects,
    verbose ? 1 : 0, progressPtr,
  );

  calloc.free(urlPtr);
  calloc.free(methodPtr);
  if (headersStr.isNotEmpty) calloc.free(headersPtr);
  calloc.free(filePathPtr);
  calloc.free(fileFieldPtr);
  if (fileName != null) calloc.free(fileNamePtr);
  if (mimeType != null) calloc.free(mimeTypePtr);
  if (extraFields != null) calloc.free(extraFieldsPtr);

  return _parseResponse(responsePtr, b);
}

// ─── Shared helpers ───────────────────────────────────────────────────────

String _buildHeadersString(Map<String, String>? headersMap) {
  if (headersMap == null || headersMap.isEmpty) return '';
  final buf = StringBuffer();
  headersMap.forEach((k, v) => buf.write('$k: $v\r\n'));
  return buf.toString();
}

Map<dynamic, dynamic> _parseResponse(
  Pointer<NativeNetResponseStruct> responsePtr,
  NativeNetBindings b,
) {
  if (responsePtr == nullptr) {
    throw const NativeNetException(
      message: 'native_net returned NULL',
      code: 'INTERNAL_ERROR',
    );
  }

  final ref = responsePtr.ref;

  if (ref.curlCode != 0) {
    final msg = ref.errorMessage != nullptr
        ? ref.errorMessage.toDartString()
        : 'curl error (code ${ref.curlCode})';
    b.freeResponse(responsePtr);
    throw createExceptionFromPlatformError(
      _mapCurlError(ref.curlCode), msg, null,
    );
  }

  final statusCode = ref.statusCode;
  final totalTimeMs = ref.totalTimeMs;

  Uint8List responseBodyBytes;
  if (ref.body != nullptr && ref.bodyLength > 0) {
    responseBodyBytes =
        Uint8List.fromList(ref.body.asTypedList(ref.bodyLength));
  } else {
    responseBodyBytes = Uint8List(0);
  }

  final responseHeaders = <String, String>{};
  if (ref.headers != nullptr && ref.headersLength > 0) {
    final raw = ref.headers.toDartString();
    for (final line in raw.split('\r\n')) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        responseHeaders[line.substring(0, idx).trim().toLowerCase()] =
            line.substring(idx + 1).trim();
      }
    }
  }

  String? effectiveUrl;
  if (ref.effectiveUrl != nullptr) {
    effectiveUrl = ref.effectiveUrl.toDartString();
  }

  b.freeResponse(responsePtr);

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

String _mapCurlError(int curlCode) {
  switch (curlCode) {
    case 6: case 7: case 9: case 45: case 55: case 56:
      return 'CONNECTION_ERROR';
    case 28:
      return 'TIMEOUT';
    case 35: case 51: case 53: case 54: case 58: case 59:
    case 60: case 64: case 66: case 77: case 82: case 83:
    case 90: case 91:
      return 'CERTIFICATE_ERROR';
    case 42:
      return 'CANCELLED';
    default:
      return 'REQUEST_ERROR';
  }
}

String _httpReasonPhrase(int code) {
  const phrases = {
    200: 'OK', 201: 'Created', 204: 'No Content',
    301: 'Moved Permanently', 302: 'Found', 304: 'Not Modified',
    400: 'Bad Request', 401: 'Unauthorized', 403: 'Forbidden',
    404: 'Not Found', 405: 'Method Not Allowed', 409: 'Conflict',
    422: 'Unprocessable Entity', 429: 'Too Many Requests',
    500: 'Internal Server Error', 502: 'Bad Gateway',
    503: 'Service Unavailable', 504: 'Gateway Timeout',
  };
  return phrases[code] ?? '';
}
