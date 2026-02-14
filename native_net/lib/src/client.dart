import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../native_net_platform_interface.dart';
import 'ffi/bindings.dart' show NativeNetProgressStruct;
import 'models/config.dart';
import 'models/exceptions.dart';
import 'models/http_method.dart';
import 'models/progress.dart';
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

    // Inject all client-level config options
    _applyConfigToMap(requestMap);

    // Handle multipart body building in Dart
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

  // ─── File download ──────────────────────────────────────────────────────

  /// Downloads a URL directly to a local file.
  ///
  /// The file is written to [savePath]. The download is streamed directly
  /// to disk so arbitrarily large files can be downloaded without using
  /// excessive memory.
  ///
  /// [onProgress] is called periodically with the number of bytes received
  /// and the total expected size (0 if the server doesn't send
  /// Content-Length).
  ///
  /// Pass a [CancelToken] to cancel the download mid-flight.
  ///
  /// Returns a [NativeNetResponse] with headers, status code, and timing
  /// information. The response body will be empty (the data is on disk).
  ///
  /// ```dart
  /// final token = CancelToken();
  /// final response = await client.downloadFile(
  ///   'https://example.com/large.zip',
  ///   '/tmp/large.zip',
  ///   onProgress: (received, total) {
  ///     print('${(received / total * 100).toStringAsFixed(1)}%');
  ///   },
  ///   cancelToken: token,
  /// );
  /// ```
  Future<NativeNetResponse> downloadFile(
    String url,
    String savePath, {
    Map<String, String>? headers,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
    Duration? connectTimeout,
    Duration? readTimeout,
  }) async {
    await _ensureInitialized();

    // Merge headers
    final mergedHeaders = <String, String>{};
    if (_config.defaultHeaders != null) {
      mergedHeaders.addAll(_config.defaultHeaders!);
    }
    if (headers != null) mergedHeaders.addAll(headers);

    // Allocate progress struct in shared native memory
    final progressPtr = calloc<NativeNetProgressStruct>();
    final progressAddr = progressPtr.address;

    // Wire up cancel token
    cancelToken?.progressAddress = progressAddr;

    // Start a timer that polls the progress struct and calls the callback
    Timer? progressTimer;
    if (onProgress != null) {
      progressTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) {
          final dl = progressPtr.ref.downloadNow;
          final total = progressPtr.ref.downloadTotal;
          onProgress(dl, total);
        },
      );
    }

    // Check cancel token periodically
    Timer? cancelTimer;
    if (cancelToken != null) {
      cancelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (cancelToken.isCancelled) {
          progressPtr.ref.cancelled = 1;
        }
      });
    }

    try {
      final data = <String, dynamic>{
        'url': url,
        'filePath': savePath,
        'headers': mergedHeaders.isNotEmpty ? mergedHeaders : null,
        if (connectTimeout != null)
          'connectTimeout': connectTimeout.inMilliseconds,
        if (readTimeout != null)
          'readTimeout': readTimeout.inMilliseconds,
        '_progressAddr': progressAddr,
      };
      _applyConfigToMap(data);

      final resultMap = await NativeNetPlatform.instance.downloadFile(data);

      if (onProgress != null) {
        onProgress(progressPtr.ref.downloadNow, progressPtr.ref.downloadTotal);
      }

      return NativeNetResponse.fromMap(resultMap);
    } finally {
      progressTimer?.cancel();
      cancelTimer?.cancel();
      calloc.free(progressPtr);
    }
  }

  // ─── File upload ───────────────────────────────────────────────────────

  /// Uploads a local file to a URL as multipart/form-data.
  ///
  /// The file is streamed directly from disk using libcurl's mime API,
  /// so arbitrarily large files can be uploaded without loading them
  /// entirely into memory.
  ///
  /// [filePath] is the local path to the file to upload.
  /// [fieldName] is the form field name (default "file").
  /// [fileName] is the filename sent in the Content-Disposition header.
  /// [contentType] is the MIME type (e.g. "image/jpeg").
  /// [formFields] are additional form data key-value pairs.
  ///
  /// ```dart
  /// final response = await client.uploadFile(
  ///   'https://example.com/upload',
  ///   '/tmp/photo.jpg',
  ///   fieldName: 'photo',
  ///   contentType: 'image/jpeg',
  ///   formFields: {'album': 'vacation'},
  ///   onProgress: (sent, total) {
  ///     print('${(sent / total * 100).toStringAsFixed(1)}%');
  ///   },
  /// );
  /// ```
  Future<NativeNetResponse> uploadFile(
    String url,
    String filePath, {
    String fieldName = 'file',
    String? fileName,
    String? contentType,
    Map<String, String>? headers,
    Map<String, String>? formFields,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
    Duration? connectTimeout,
    Duration? readTimeout,
  }) async {
    await _ensureInitialized();

    // Merge headers
    final mergedHeaders = <String, String>{};
    if (_config.defaultHeaders != null) {
      mergedHeaders.addAll(_config.defaultHeaders!);
    }
    if (headers != null) mergedHeaders.addAll(headers);

    // Allocate progress struct
    final progressPtr = calloc<NativeNetProgressStruct>();
    final progressAddr = progressPtr.address;
    cancelToken?.progressAddress = progressAddr;

    Timer? progressTimer;
    if (onProgress != null) {
      progressTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) {
          final ul = progressPtr.ref.uploadNow;
          final total = progressPtr.ref.uploadTotal;
          onProgress(ul, total);
        },
      );
    }

    Timer? cancelTimer;
    if (cancelToken != null) {
      cancelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (cancelToken.isCancelled) {
          progressPtr.ref.cancelled = 1;
        }
      });
    }

    // Encode extra form fields as "key=value\nkey=value\n"
    String? extraFieldsStr;
    if (formFields != null && formFields.isNotEmpty) {
      final buf = StringBuffer();
      formFields.forEach((k, v) => buf.write('$k=$v\n'));
      extraFieldsStr = buf.toString();
    }

    try {
      final data = <String, dynamic>{
        'url': url,
        'method': 'POST',
        'headers': mergedHeaders.isNotEmpty ? mergedHeaders : null,
        'filePath': filePath,
        'fileField': fieldName,
        'fileName': fileName,
        'mimeType': contentType,
        'extraFields': extraFieldsStr,
        if (connectTimeout != null)
          'connectTimeout': connectTimeout.inMilliseconds,
        if (readTimeout != null)
          'readTimeout': readTimeout.inMilliseconds,
        '_progressAddr': progressAddr,
      };
      _applyConfigToMap(data);

      final resultMap = await NativeNetPlatform.instance.uploadFile(data);

      if (onProgress != null) {
        onProgress(progressPtr.ref.uploadNow, progressPtr.ref.uploadTotal);
      }

      return NativeNetResponse.fromMap(resultMap);
    } finally {
      progressTimer?.cancel();
      cancelTimer?.cancel();
      calloc.free(progressPtr);
    }
  }

  // ─── Config injection ────────────────────────────────────────────────────

  /// Injects all client-level config options into a request data map.
  void _applyConfigToMap(Map<String, dynamic> map) {
    // Verbose
    map['verbose'] = _config.enableLogging;

    // Timeouts (only if not already set per-request)
    map['connectTimeout'] ??= _config.connectTimeout.inMilliseconds;
    map['readTimeout'] ??= _config.readTimeout.inMilliseconds;
    map['followRedirects'] ??= _config.followRedirects;
    map['maxRedirects'] ??= _config.maxRedirects;

    // TLS
    final tls = _config.tls;
    if (tls != null) {
      map['sslVerifyPeer'] = tls.verifyPeer ? 1 : -1;
      map['sslVerifyHost'] = tls.verifyHost ? 2 : -1;
      if (tls.caInfoPath != null) map['caInfo'] = tls.caInfoPath;
      if (tls.caDirectoryPath != null) map['caPath'] = tls.caDirectoryPath;
      if (tls.clientCertPath != null) map['clientCert'] = tls.clientCertPath;
      if (tls.clientKeyPath != null) map['clientKey'] = tls.clientKeyPath;
      if (tls.clientCertType != null) map['clientCertType'] = tls.clientCertType;
      if (tls.pinnedPublicKey != null) {
        map['pinnedPublicKey'] = tls.pinnedPublicKey;
      }
    }

    // Proxy
    final proxy = _config.proxy;
    if (proxy != null) {
      map['proxy'] = proxy.url;
      map['proxyType'] = proxy.type.value;
      map['httpProxyTunnel'] = proxy.tunnel ? 1 : 0;
      if (proxy.username != null && proxy.password != null) {
        map['proxyUserpwd'] = '${proxy.username}:${proxy.password}';
      }
    }

    // Cookies
    final cookies = _config.cookies;
    if (cookies != null) {
      if (cookies.cookies != null) map['cookie'] = cookies.cookies;
      if (cookies.cookieFile != null) map['cookieFile'] = cookies.cookieFile;
      if (cookies.cookieJar != null) map['cookieJar'] = cookies.cookieJar;
    }

    // HTTP version
    if (_config.httpVersion.value > 0) {
      map['httpVersion'] = _config.httpVersion.value;
    }

    // Speed limits
    if (_config.maxDownloadSpeed > 0) {
      map['maxRecvSpeed'] = _config.maxDownloadSpeed;
    }
    if (_config.maxUploadSpeed > 0) {
      map['maxSendSpeed'] = _config.maxUploadSpeed;
    }

    // User-Agent
    if (_config.userAgent != null) {
      map['userAgent'] = _config.userAgent;
    }

    // DNS
    if (_config.dnsServers != null) {
      map['dnsServers'] = _config.dnsServers;
    }
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
