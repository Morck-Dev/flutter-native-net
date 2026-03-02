import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../native_net_platform_interface.dart';
import 'models/config.dart';
import 'models/exceptions.dart';
import 'models/http_method.dart';
import 'models/progress.dart';
import 'models/request.dart';
import 'models/response.dart';

typedef RequestInterceptor = Future<NativeNetRequest> Function(
  NativeNetRequest request,
);

typedef ResponseInterceptor = Future<NativeNetResponse> Function(
  NativeNetResponse response,
);

/// The main HTTP client powered by libcurl on native platforms
/// and the Fetch API on web.
///
/// ```dart
/// final client = NativeNetClient();
///
/// // JSON
/// await client.post(url, jsonBody: {'key': 'value'});
///
/// // Form
/// await client.post(url, formData: {'username': 'admin', 'password': '123'});
///
/// // Raw body
/// await client.post(url, body: '<xml>data</xml>',
///     headers: {'Content-Type': 'application/xml'});
/// ```
class NativeNetClient {
  final NativeNetConfig _config;
  final List<RequestInterceptor> _requestInterceptors = [];
  final List<ResponseInterceptor> _responseInterceptors = [];
  bool _initialized = false;
  bool _closed = false;
  String? _caBundlePath;

  NativeNetClient({NativeNetConfig? config})
      : _config = config ?? const NativeNetConfig();

  void addRequestInterceptor(RequestInterceptor interceptor) {
    _requestInterceptors.add(interceptor);
  }

  void addResponseInterceptor(ResponseInterceptor interceptor) {
    _responseInterceptors.add(interceptor);
  }

  Future<void> _ensureInitialized() async {
    if (_closed) {
      throw const NativeNetException(
        message: 'Client has been closed',
        code: 'CLIENT_CLOSED',
      );
    }
    if (!_initialized) {
      await NativeNetPlatform.instance.initialize(_config.toMap());
      if (Platform.isAndroid || Platform.isLinux) {
        _caBundlePath = await _extractCaBundle();
      }
      _initialized = true;
    }
  }

  Future<String?> getPlatformVersion() {
    return NativeNetPlatform.instance.getPlatformVersion();
  }

  /// Sends an HTTP request and returns the response.
  Future<NativeNetResponse> request(NativeNetRequest request) async {
    await _ensureInitialized();

    var processedRequest = request;
    for (final interceptor in _requestInterceptors) {
      processedRequest = await interceptor(processedRequest);
    }

    final mergedHeaders = <String, String>{};
    if (_config.defaultHeaders != null) {
      mergedHeaders.addAll(_config.defaultHeaders!);
    }
    if (processedRequest.headers != null) {
      mergedHeaders.addAll(processedRequest.headers!);
    }

    final requestMap = processedRequest.toMap();
    if (mergedHeaders.isNotEmpty) {
      requestMap['headers'] = mergedHeaders;
    }

    _applyConfigToMap(requestMap);

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

  // ── Unified HTTP methods ─────────────────────────────────────────────────
  //
  // Each method accepts multiple body types. Only ONE should be provided:
  //   jsonBody  -> auto Content-Type: application/json
  //   formData  -> auto Content-Type: application/x-www-form-urlencoded
  //   body      -> raw string (set Content-Type yourself if needed)
  //   bodyBytes -> raw bytes
  //
  // If none is provided, no body is sent.

  /// Sends a GET request.
  Future<NativeNetResponse> get(
    String url, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    Duration? connectTimeout,
    Duration? readTimeout,
  }) {
    final finalUrl = queryParams != null && queryParams.isNotEmpty
        ? _appendQueryParams(url, queryParams)
        : url;
    return request(NativeNetRequest(
      url: finalUrl,
      method: HttpMethod.get,
      headers: headers,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
    ));
  }

  /// Sends a POST request.
  ///
  /// ```dart
  /// // JSON body
  /// await client.post(url, jsonBody: {'name': 'test'});
  ///
  /// // Form body
  /// await client.post(url, formData: {'user': 'admin', 'pass': '123'});
  ///
  /// // Raw body
  /// await client.post(url, body: 'raw text');
  /// ```
  Future<NativeNetResponse> post(
    String url, {
    Map<String, String>? headers,
    String? body,
    Uint8List? bodyBytes,
    dynamic jsonBody,
    Map<String, String>? formData,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    return _bodyRequest(HttpMethod.post, url,
        headers: headers, body: body, bodyBytes: bodyBytes,
        jsonBody: jsonBody, formData: formData,
        connectTimeout: connectTimeout, readTimeout: readTimeout,
        writeTimeout: writeTimeout);
  }

  /// Sends a PUT request.
  Future<NativeNetResponse> put(
    String url, {
    Map<String, String>? headers,
    String? body,
    Uint8List? bodyBytes,
    dynamic jsonBody,
    Map<String, String>? formData,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    return _bodyRequest(HttpMethod.put, url,
        headers: headers, body: body, bodyBytes: bodyBytes,
        jsonBody: jsonBody, formData: formData,
        connectTimeout: connectTimeout, readTimeout: readTimeout,
        writeTimeout: writeTimeout);
  }

  /// Sends a DELETE request.
  Future<NativeNetResponse> delete(
    String url, {
    Map<String, String>? headers,
    String? body,
    dynamic jsonBody,
    Map<String, String>? formData,
    Duration? connectTimeout,
    Duration? readTimeout,
  }) {
    return _bodyRequest(HttpMethod.delete, url,
        headers: headers, body: body,
        jsonBody: jsonBody, formData: formData,
        connectTimeout: connectTimeout, readTimeout: readTimeout);
  }

  /// Sends a PATCH request.
  Future<NativeNetResponse> patch(
    String url, {
    Map<String, String>? headers,
    String? body,
    Uint8List? bodyBytes,
    dynamic jsonBody,
    Map<String, String>? formData,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    return _bodyRequest(HttpMethod.patch, url,
        headers: headers, body: body, bodyBytes: bodyBytes,
        jsonBody: jsonBody, formData: formData,
        connectTimeout: connectTimeout, readTimeout: readTimeout,
        writeTimeout: writeTimeout);
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

  /// Sends a multipart/form-data request (file upload).
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

  // ── File download ────────────────────────────────────────────────────────

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

    final mergedHeaders = <String, String>{};
    if (_config.defaultHeaders != null) {
      mergedHeaders.addAll(_config.defaultHeaders!);
    }
    if (headers != null) mergedHeaders.addAll(headers);

    final data = <String, dynamic>{
      'url': url,
      'filePath': savePath,
      'headers': mergedHeaders.isNotEmpty ? mergedHeaders : null,
      if (connectTimeout != null)
        'connectTimeout': connectTimeout.inMilliseconds,
      if (readTimeout != null) 'readTimeout': readTimeout.inMilliseconds,
    };
    _applyConfigToMap(data);

    final resultMap = await NativeNetPlatform.instance.downloadFile(data);
    return NativeNetResponse.fromMap(resultMap);
  }

  // ── File upload ──────────────────────────────────────────────────────────

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

    final mergedHeaders = <String, String>{};
    if (_config.defaultHeaders != null) {
      mergedHeaders.addAll(_config.defaultHeaders!);
    }
    if (headers != null) mergedHeaders.addAll(headers);

    String? extraFieldsStr;
    if (formFields != null && formFields.isNotEmpty) {
      final buf = StringBuffer();
      formFields.forEach((k, v) => buf.write('$k=$v\n'));
      extraFieldsStr = buf.toString();
    }

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
      if (readTimeout != null) 'readTimeout': readTimeout.inMilliseconds,
    };
    _applyConfigToMap(data);

    final resultMap = await NativeNetPlatform.instance.uploadFile(data);
    return NativeNetResponse.fromMap(resultMap);
  }

  // ── Internals ────────────────────────────────────────────────────────────

  /// Shared logic for POST/PUT/PATCH/DELETE with auto body-type detection.
  Future<NativeNetResponse> _bodyRequest(
    HttpMethod method,
    String url, {
    Map<String, String>? headers,
    String? body,
    Uint8List? bodyBytes,
    dynamic jsonBody,
    Map<String, String>? formData,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    final mergedHeaders = <String, String>{...?headers};
    String? resolvedBody = body;
    Uint8List? resolvedBytes = bodyBytes;

    if (jsonBody != null) {
      resolvedBody = json.encode(jsonBody);
      mergedHeaders.putIfAbsent(
          'Content-Type', () => 'application/json; charset=utf-8');
    } else if (formData != null) {
      resolvedBody = _encodeFormData(formData);
      mergedHeaders.putIfAbsent(
          'Content-Type', () => 'application/x-www-form-urlencoded');
    }

    return request(NativeNetRequest(
      url: url,
      method: method,
      headers: mergedHeaders.isNotEmpty ? mergedHeaders : null,
      body: resolvedBody,
      bodyBytes: resolvedBytes,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
      writeTimeout: writeTimeout,
    ));
  }

  static String _encodeFormData(Map<String, String> data) {
    return data.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  static String _appendQueryParams(String url, Map<String, String> params) {
    final uri = Uri.parse(url);
    final merged = Map<String, String>.from(uri.queryParameters)
      ..addAll(params);
    return uri.replace(queryParameters: merged).toString();
  }

  void _applyConfigToMap(Map<String, dynamic> map) {
    map['verbose'] = _config.enableLogging;
    map['connectTimeout'] ??= _config.connectTimeout.inMilliseconds;
    map['readTimeout'] ??= _config.readTimeout.inMilliseconds;
    map['followRedirects'] ??= _config.followRedirects;
    map['maxRedirects'] ??= _config.maxRedirects;

    final tls = _config.tls;
    if (tls != null) {
      map['sslVerifyPeer'] = tls.verifyPeer ? 1 : -1;
      map['sslVerifyHost'] = tls.verifyHost ? 2 : -1;
      if (tls.caInfoPath != null) map['caInfo'] = tls.caInfoPath;
      if (tls.caDirectoryPath != null) map['caPath'] = tls.caDirectoryPath;
      if (tls.clientCertPath != null) map['clientCert'] = tls.clientCertPath;
      if (tls.clientKeyPath != null) map['clientKey'] = tls.clientKeyPath;
      if (tls.clientCertType != null) {
        map['clientCertType'] = tls.clientCertType;
      }
      if (tls.pinnedPublicKey != null) {
        map['pinnedPublicKey'] = tls.pinnedPublicKey;
      }
    }

    final proxy = _config.proxy;
    if (proxy != null) {
      map['proxy'] = proxy.url;
      map['proxyType'] = proxy.type.value;
      map['httpProxyTunnel'] = proxy.tunnel ? 1 : 0;
      if (proxy.username != null && proxy.password != null) {
        map['proxyUserpwd'] = '${proxy.username}:${proxy.password}';
      }
    }

    final cookies = _config.cookies;
    if (cookies != null) {
      if (cookies.cookies != null) map['cookie'] = cookies.cookies;
      if (cookies.cookieFile != null) map['cookieFile'] = cookies.cookieFile;
      if (cookies.cookieJar != null) map['cookieJar'] = cookies.cookieJar;
    }

    if (_config.httpVersion.value > 0) {
      map['httpVersion'] = _config.httpVersion.value;
    }
    if (_config.maxDownloadSpeed > 0) {
      map['maxRecvSpeed'] = _config.maxDownloadSpeed;
    }
    if (_config.maxUploadSpeed > 0) {
      map['maxSendSpeed'] = _config.maxUploadSpeed;
    }
    if (_config.userAgent != null) map['userAgent'] = _config.userAgent;
    if (_config.dnsServers != null) map['dnsServers'] = _config.dnsServers;

    if (_caBundlePath != null && map['caInfo'] == null) {
      map['caInfo'] = _caBundlePath;
    }
  }

  Future<String?> _extractCaBundle() async {
    try {
      final tempDir = Directory.systemTemp;
      final caFile = File('${tempDir.path}/native_net_cacert.pem');
      if (!caFile.existsSync()) {
        final data = await rootBundle.load(
          'packages/native_net/assets/cacert.pem',
        );
        await caFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      return caFile.path;
    } catch (e) {
      return null;
    }
  }

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      if (_initialized) {
        await NativeNetPlatform.instance.dispose();
      }
    }
  }

  _MultipartResult _buildMultipartBody(
    Map<String, String>? formFields,
    List<MultipartFile> files,
  ) {
    final boundary = 'NativeNet-${DateTime.now().millisecondsSinceEpoch}';
    final buffer = BytesBuilder();
    const crlf = '\r\n';

    formFields?.forEach((key, value) {
      buffer.add('--$boundary$crlf'.codeUnits);
      buffer.add(
        'Content-Disposition: form-data; name="$key"$crlf$crlf'.codeUnits,
      );
      buffer.add('$value$crlf'.codeUnits);
    });

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

    return _MultipartResult(bytes: buffer.toBytes(), boundary: boundary);
  }
}

class _MultipartResult {
  final Uint8List bytes;
  final String boundary;
  const _MultipartResult({required this.bytes, required this.boundary});
}
