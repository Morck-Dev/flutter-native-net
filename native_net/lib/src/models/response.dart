import 'dart:convert';
import 'dart:typed_data';

/// Represents an HTTP response received from native networking.
class NativeNetResponse {
  /// The HTTP status code (e.g. 200, 404, 500).
  final int statusCode;

  /// The response headers.
  final Map<String, String> headers;

  /// The raw response body bytes.
  final Uint8List bodyBytes;

  /// The reason phrase (e.g. "OK", "Not Found").
  final String? reasonPhrase;

  /// The content length, or -1 if unknown.
  final int contentLength;

  /// The time taken to complete the request.
  final Duration duration;

  /// The final URL after any redirects.
  final String? finalUrl;

  const NativeNetResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
    this.reasonPhrase,
    this.contentLength = -1,
    this.duration = Duration.zero,
    this.finalUrl,
  });

  /// The response body decoded as a UTF-8 string.
  String get body => utf8.decode(bodyBytes, allowMalformed: true);

  /// Parses the response body as JSON.
  dynamic get jsonBody => json.decode(body);

  /// Whether the status code indicates success (2xx).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the status code indicates a redirect (3xx).
  bool get isRedirect => statusCode >= 300 && statusCode < 400;

  /// Whether the status code indicates a client error (4xx).
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Whether the status code indicates a server error (5xx).
  bool get isServerError => statusCode >= 500 && statusCode < 600;

  /// Creates a NativeNetResponse from a platform channel map.
  factory NativeNetResponse.fromMap(Map<dynamic, dynamic> map) {
    final headersRaw = map['headers'];
    final headers = <String, String>{};
    if (headersRaw is Map) {
      headersRaw.forEach((key, value) {
        headers[key.toString()] = value.toString();
      });
    }

    final bodyBytesRaw = map['bodyBytes'];
    Uint8List bodyBytes;
    if (bodyBytesRaw is Uint8List) {
      bodyBytes = bodyBytesRaw;
    } else if (bodyBytesRaw is List) {
      bodyBytes = Uint8List.fromList(bodyBytesRaw.cast<int>());
    } else if (bodyBytesRaw is String) {
      bodyBytes = utf8.encode(bodyBytesRaw);
    } else {
      bodyBytes = Uint8List(0);
    }

    return NativeNetResponse(
      statusCode: (map['statusCode'] as num?)?.toInt() ?? 0,
      headers: headers,
      bodyBytes: bodyBytes,
      reasonPhrase: map['reasonPhrase'] as String?,
      contentLength: (map['contentLength'] as num?)?.toInt() ?? -1,
      duration: Duration(
        milliseconds: (map['duration'] as num?)?.toInt() ?? 0,
      ),
      finalUrl: map['finalUrl'] as String?,
    );
  }

  @override
  String toString() {
    return 'NativeNetResponse(statusCode: $statusCode, '
        'contentLength: $contentLength, '
        'duration: ${duration.inMilliseconds}ms)';
  }
}
