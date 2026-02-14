import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../native_net_platform_interface.dart';
import '../models/exceptions.dart';

/// Creates the default Web-based platform implementation.
NativeNetPlatform createDefaultPlatform() => WebNativeNetPlatform();

/// Platform implementation that uses the browser's Fetch API.
///
/// This is the automatic fallback for Flutter Web, since libcurl
/// cannot run inside a browser.
class WebNativeNetPlatform extends NativeNetPlatform {
  @override
  Future<String?> getPlatformVersion() async {
    return 'Web (Fetch API)';
  }

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // No-op for web – the browser manages connections.
  }

  @override
  Future<Map<dynamic, dynamic>> request(
    Map<String, dynamic> requestData,
  ) async {
    final url = requestData['url'] as String;
    final method = requestData['method'] as String;
    final headersMap = requestData['headers'] as Map<String, String>?;
    final bodyString = requestData['body'] as String?;
    final bodyBytes = requestData['bodyBytes'] as Uint8List?;
    final followRedirects = (requestData['followRedirects'] as bool?) ?? true;

    final startTime = DateTime.now();

    try {
      // Build Headers object
      final headers = web.Headers();
      headersMap?.forEach((key, value) {
        headers.append(key, value);
      });

      // Build RequestInit
      final init = web.RequestInit(
        method: method,
        headers: headers,
        redirect: followRedirects ? 'follow' : 'manual',
      );

      // Set body for non-GET/HEAD requests
      if (method != 'GET' && method != 'HEAD') {
        if (bodyBytes != null) {
          init.body = bodyBytes.toJS;
        } else if (bodyString != null) {
          init.body = bodyString.toJS;
        }
      }

      // Perform fetch
      final response = await web.window.fetch(url.toJS, init).toDart;
      final duration = DateTime.now().difference(startTime);

      // Read response body as ArrayBuffer → Uint8List
      final arrayBuffer = await response.arrayBuffer().toDart;
      final responseBodyBytes = arrayBuffer.toDart.asUint8List();

      // Read response headers
      final responseHeaders = <String, String>{};
      // Iterate over known headers – the Fetch API Headers object is
      // not directly iterable in all package:web versions, so we parse
      // common headers and any that were sent in the request.
      final knownHeaders = [
        'content-type',
        'content-length',
        'content-encoding',
        'cache-control',
        'etag',
        'last-modified',
        'location',
        'set-cookie',
        'date',
        'server',
        'vary',
        'x-request-id',
        'access-control-allow-origin',
        'access-control-allow-methods',
        'access-control-allow-headers',
      ];
      // Also include request headers to check for echoed ones
      if (headersMap != null) {
        knownHeaders.addAll(headersMap.keys.map((k) => k.toLowerCase()));
      }
      for (final name in knownHeaders) {
        final value = response.headers.get(name);
        if (value != null) {
          responseHeaders[name] = value;
        }
      }

      return {
        'statusCode': response.status,
        'headers': responseHeaders,
        'bodyBytes': responseBodyBytes,
        'reasonPhrase': response.statusText,
        'contentLength': responseBodyBytes.length,
        'duration': duration.inMilliseconds,
        'finalUrl': response.url,
      };
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      final msg = e.toString();

      if (msg.contains('TypeError') || msg.contains('NetworkError')) {
        throw ConnectionException(
          message: 'Network request failed: $msg',
        );
      }
      if (msg.contains('AbortError')) {
        throw CancelledException(message: msg);
      }

      throw NativeNetException(
        message: 'Fetch API error: $msg',
        code: 'REQUEST_ERROR',
        details: duration.inMilliseconds,
      );
    }
  }

  @override
  Future<Map<dynamic, dynamic>> downloadFile(Map<String, dynamic> data) async {
    // On web, downloading to a file path is not supported.
    // Perform a normal GET and return the body bytes so the caller
    // can handle saving (e.g. via a download link).
    final requestData = Map<String, dynamic>.from(data);
    requestData['method'] = 'GET';
    return request(requestData);
  }

  @override
  Future<Map<dynamic, dynamic>> uploadFile(Map<String, dynamic> data) async {
    // On web, file upload via local path is not supported.
    // Throw an informative error directing users to use multipart() instead.
    throw const NativeNetException(
      message:
          'uploadFile() with local file paths is not supported on web. '
          'Use client.multipart() with in-memory file bytes instead.',
      code: 'UNSUPPORTED_PLATFORM',
    );
  }

  @override
  Future<void> cancelRequest(String tag) async {
    // Could use AbortController in a future version.
  }

  @override
  Future<void> dispose() async {
    // No-op for web.
  }
}
