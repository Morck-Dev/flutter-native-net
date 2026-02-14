import 'dart:convert';
import 'dart:typed_data';

import '../native_net_platform_interface.dart';
import 'models/config.dart';
import 'models/exceptions.dart';
import 'models/http_method.dart';
import 'models/request.dart';
import 'models/response.dart';

/// A callback type for intercepting requests before they are sent.
typedef RequestInterceptor = Future<NativeNetRequest> Function(
  NativeNetRequest request,
);

/// A callback type for intercepting responses after they are received.
typedef ResponseInterceptor = Future<NativeNetResponse> Function(
  NativeNetResponse response,
);

/// The main HTTP client powered by libcurl on native platforms
/// and the Fetch API on web.
///
/// - **Android / iOS / macOS / Linux / Windows**: libcurl via dart:ffi
/// - **Web**: browser Fetch API
///
/// Usage:
/// ```dart
/// final client = NativeNetClient(
///   config: NativeNetConfig(
///     connectTimeout: Duration(seconds: 10),
///     defaultHeaders: {'Authorization': 'Bearer token'},
///   ),
/// );
///
/// final response = await client.get('https://api.example.com/data');
/// print(response.body);
///
/// client.close();
/// ```
class NativeNetClient {
  final NativeNetConfig _config;
  final List<RequestInterceptor> _requestInterceptors = [];
  final List<ResponseInterceptor> _responseInterceptors = [];
  bool _initialized = false;
  bool _closed = false;

  NativeNetClient({NativeNetConfig? config})
      : _config = config ?? const NativeNetConfig();

  /// Adds a request interceptor that modifies requests before they are sent.
  void addRequestInterceptor(RequestInterceptor interceptor) {
    _requestInterceptors.add(interceptor);
  }

  /// Adds a response interceptor that processes responses after they arrive.
  void addResponseInterceptor(ResponseInterceptor interceptor) {
    _responseInterceptors.add(interceptor);
  }

  /// Ensures the native client is initialised.
  Future<void> _ensureInitialized() async {
    if (_closed) {
      throw const NativeNetException(
        message: 'Client has been closed',
        code: 'CLIENT_CLOSED',
      );
    }
    if (!_initialized) {
      await NativeNetPlatform.instance.initialize(_config.toMap());
      _initialized = true;
    }
  }

  /// Returns a string describing the native backend (for debugging).
  Future<String?> getPlatformVersion() {
    return NativeNetPlatform.instance.getPlatformVersion();
  }

  /// Sends an HTTP request and returns the response.
  ///
  /// This is the core method that all convenience methods delegate to.
  /// It handles request/response interceptors, default headers, and
  /// error mapping.
  Future<NativeNetResponse> request(NativeNetRequest request) async {
    await _ensureInitialized();

    // Apply request interceptors
    var processedRequest = request;
    for (final interceptor in _requestInterceptors) {
      processedRequest = await interceptor(processedRequest);
    }

    // Merge default headers with request headers
    final mergedHeaders = <String, String>{};
    if (_config.defaultHeaders != null) {
      mergedHeaders.addAll(_config.defaultHeaders!);
    }
    if (processedRequest.headers != null) {
      mergedHeaders.addAll(processedRequest.headers!);
    }

    // Build the final request map
    final requestMap = processedRequest.toMap();
    if (mergedHeaders.isNotEmpty) {
      requestMap['headers'] = mergedHeaders;
    }
    // Pass verbose flag from config
    requestMap['verbose'] = _config.enableLogging;

    // Handle multipart body building in Dart
    // (The C layer receives the body as raw bytes; Dart does the encoding.)
    if (processedRequest.files != null &&
        processedRequest.files!.isNotEmpty) {
      final multipartResult = _buildMultipartBody(
        processedRequest.formFields,
        processedRequest.files!,
      );
      requestMap['body'] = null;
      requestMap['bodyBytes'] = multipartResult.bytes;
      final headers = (requestMap['headers'] as Map<String, String>?) ?? {};
      headers['Content-Type'] =
          'multipart/form-data; boundary=${multipartResult.boundary}';
      requestMap['headers'] = headers;
    }

    try {
      final resultMap = await NativeNetPlatform.instance.request(requestMap);
      var response = NativeNetResponse.fromMap(resultMap);

      // Apply response interceptors
      for (final interceptor in _responseInterceptors) {
        response = await interceptor(response);
      }

      return response;
    } on NativeNetException {
      rethrow;
    } catch (e) {
      throw NativeNetException(
        message: e.toString(),
        code: 'REQUEST_ERROR',
      );
    }
  }

  // ─── Convenience methods ──────────────────────────────────────────────────

  /// Sends a GET request.
  Future<NativeNetResponse> get(
    String url, {
    Map<String, String>? headers,
    Duration? connectTimeout,
    Duration? readTimeout,
  }) {
    return request(NativeNetRequest(
      url: url,
      method: HttpMethod.get,
      headers: headers,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
    ));
  }

  /// Sends a POST request with an optional body.
  Future<NativeNetResponse> post(
    String url, {
    Map<String, String>? headers,
    String? body,
    Uint8List? bodyBytes,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    return request(NativeNetRequest(
      url: url,
      method: HttpMethod.post,
      headers: headers,
      body: body,
      bodyBytes: bodyBytes,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
      writeTimeout: writeTimeout,
    ));
  }

  /// Sends a POST request with a JSON body.
  Future<NativeNetResponse> postJson(
    String url, {
    Map<String, String>? headers,
    required dynamic jsonBody,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    final mergedHeaders = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      ...?headers,
    };
    return request(NativeNetRequest(
      url: url,
      method: HttpMethod.post,
      headers: mergedHeaders,
      body: json.encode(jsonBody),
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
      writeTimeout: writeTimeout,
    ));
  }

  /// Sends a PUT request with an optional body.
  Future<NativeNetResponse> put(
    String url, {
    Map<String, String>? headers,
    String? body,
    Uint8List? bodyBytes,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    return request(NativeNetRequest(
      url: url,
      method: HttpMethod.put,
      headers: headers,
      body: body,
      bodyBytes: bodyBytes,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
      writeTimeout: writeTimeout,
    ));
  }

  /// Sends a PUT request with a JSON body.
  Future<NativeNetResponse> putJson(
    String url, {
    Map<String, String>? headers,
    required dynamic jsonBody,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    final mergedHeaders = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      ...?headers,
    };
    return request(NativeNetRequest(
      url: url,
      method: HttpMethod.put,
      headers: mergedHeaders,
      body: json.encode(jsonBody),
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
      writeTimeout: writeTimeout,
    ));
  }

  /// Sends a DELETE request.
  Future<NativeNetResponse> delete(
    String url, {
    Map<String, String>? headers,
    String? body,
    Duration? connectTimeout,
    Duration? readTimeout,
  }) {
    return request(NativeNetRequest(
      url: url,
      method: HttpMethod.delete,
      headers: headers,
      body: body,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
    ));
  }

  /// Sends a PATCH request with an optional body.
  Future<NativeNetResponse> patch(
    String url, {
    Map<String, String>? headers,
    String? body,
    Uint8List? bodyBytes,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    return request(NativeNetRequest(
      url: url,
      method: HttpMethod.patch,
      headers: headers,
      body: body,
      bodyBytes: bodyBytes,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
      writeTimeout: writeTimeout,
    ));
  }

  /// Sends a PATCH request with a JSON body.
  Future<NativeNetResponse> patchJson(
    String url, {
    Map<String, String>? headers,
    required dynamic jsonBody,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    final mergedHeaders = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      ...?headers,
    };
    return request(NativeNetRequest(
      url: url,
      method: HttpMethod.patch,
      headers: mergedHeaders,
      body: json.encode(jsonBody),
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
      writeTimeout: writeTimeout,
    ));
  }

  /// Sends a HEAD request.
  Future<NativeNetResponse> head(
    String url, {
    Map<String, String>? headers,
    Duration? connectTimeout,
    Duration? readTimeout,
  }) {
    return request(NativeNetRequest(
      url: url,
      method: HttpMethod.head,
      headers: headers,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
    ));
  }

  /// Sends a multipart/form-data request (e.g. for file uploads).
  Future<NativeNetResponse> multipart(
    String url, {
    HttpMethod method = HttpMethod.post,
    Map<String, String>? headers,
    Map<String, String>? formFields,
    List<MultipartFile>? files,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    return request(NativeNetRequest(
      url: url,
      method: method,
      headers: headers,
      formFields: formFields,
      files: files,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
      writeTimeout: writeTimeout,
    ));
  }

  /// Closes the client and releases native resources.
  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      if (_initialized) {
        await NativeNetPlatform.instance.dispose();
      }
    }
  }

  // ─── Multipart body builder ────────────────────────────────────────────

  _MultipartResult _buildMultipartBody(
    Map<String, String>? formFields,
    List<MultipartFile> files,
  ) {
    final boundary = 'NativeNet-${DateTime.now().millisecondsSinceEpoch}';
    final buffer = BytesBuilder();
    const crlf = '\r\n';

    // Form fields
    formFields?.forEach((key, value) {
      buffer.add('--$boundary$crlf'.codeUnits);
      buffer.add(
        'Content-Disposition: form-data; name="$key"$crlf$crlf'.codeUnits,
      );
      buffer.add('$value$crlf'.codeUnits);
    });

    // Files
    for (final file in files) {
      buffer.add('--$boundary$crlf'.codeUnits);
      buffer.add(
        'Content-Disposition: form-data; name="${file.field}"; '
            'filename="${file.fileName}"$crlf'
            .codeUnits,
      );
      final ct = file.contentType ?? 'application/octet-stream';
      buffer.add('Content-Type: $ct$crlf$crlf'.codeUnits);
      buffer.add(file.bytes);
      buffer.add(crlf.codeUnits);
    }

    buffer.add('--$boundary--$crlf'.codeUnits);

    return _MultipartResult(
      bytes: buffer.toBytes(),
      boundary: boundary,
    );
  }
}

class _MultipartResult {
  final Uint8List bytes;
  final String boundary;
  const _MultipartResult({required this.bytes, required this.boundary});
}
