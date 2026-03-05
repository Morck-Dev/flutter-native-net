import 'dart:typed_data';

import 'http_method.dart';

/// Represents a multipart file to be uploaded.
class MultipartFile {
  /// The field name for this file in the multipart form.
  final String field;

  /// The file name.
  final String fileName;

  /// The file content as bytes.
  final Uint8List bytes;

  /// The MIME content type of the file (e.g. "image/jpeg").
  final String? contentType;

  const MultipartFile({
    required this.field,
    required this.fileName,
    required this.bytes,
    this.contentType,
  });

  Map<String, dynamic> toMap() {
    return {
      'field': field,
      'fileName': fileName,
      'bytes': bytes,
      if (contentType != null) 'contentType': contentType,
    };
  }
}

/// Represents an HTTP request to be sent via native networking.
class NativeNetRequest {
  /// The URL to send the request to.
  final String url;

  /// The HTTP method (GET, POST, PUT, DELETE, etc.).
  final HttpMethod method;

  /// Optional request headers.
  final Map<String, String>? headers;

  /// Optional request body as a string (for JSON, form data, etc.).
  final String? body;

  /// Optional request body as raw bytes.
  final Uint8List? bodyBytes;

  /// Optional multipart files for upload.
  final List<MultipartFile>? files;

  /// Optional form fields for multipart requests.
  final Map<String, String>? formFields;

  /// Connection timeout. Overrides the client-level setting.
  final Duration? connectTimeout;

  /// Read timeout. Overrides the client-level setting.
  final Duration? readTimeout;

  /// Write timeout. Overrides the client-level setting.
  final Duration? writeTimeout;

  /// Whether to follow redirects automatically. Defaults to true.
  final bool followRedirects;

  /// Maximum number of redirects to follow.
  final int maxRedirects;

  const NativeNetRequest({
    required this.url,
    required this.method,
    this.headers,
    this.body,
    this.bodyBytes,
    this.files,
    this.formFields,
    this.connectTimeout,
    this.readTimeout,
    this.writeTimeout,
    this.followRedirects = true,
    this.maxRedirects = 5,
  }) : assert(
         body == null || bodyBytes == null,
         'Cannot specify both body and bodyBytes',
       );

  /// Converts this request to a map for platform channel serialization.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'url': url,
      'method': method.value,
      'followRedirects': followRedirects,
      'maxRedirects': maxRedirects,
    };

    if (headers != null && headers!.isNotEmpty) {
      map['headers'] = headers;
    }

    if (body != null) {
      map['body'] = body;
    }

    if (bodyBytes != null) {
      map['bodyBytes'] = bodyBytes;
    }

    if (files != null && files!.isNotEmpty) {
      map['files'] = files!.map((f) => f.toMap()).toList();
    }

    if (formFields != null && formFields!.isNotEmpty) {
      map['formFields'] = formFields;
    }

    if (connectTimeout != null) {
      map['connectTimeout'] = connectTimeout!.inMilliseconds;
    }

    if (readTimeout != null) {
      map['readTimeout'] = readTimeout!.inMilliseconds;
    }

    if (writeTimeout != null) {
      map['writeTimeout'] = writeTimeout!.inMilliseconds;
    }

    return map;
  }
}
