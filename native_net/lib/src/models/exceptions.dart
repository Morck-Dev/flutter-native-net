/// Base exception for all native_net errors.
class NativeNetException implements Exception {
  /// A human-readable error message.
  final String message;

  /// The underlying error code from the native layer, if available.
  final String? code;

  /// Additional details about the error.
  final dynamic details;

  const NativeNetException({
    required this.message,
    this.code,
    this.details,
  });

  @override
  String toString() => 'NativeNetException($code): $message';
}

/// Thrown when a connection cannot be established.
class ConnectionException extends NativeNetException {
  const ConnectionException({
    required super.message,
    super.code = 'CONNECTION_ERROR',
    super.details,
  });
}

/// Thrown when a request times out.
class TimeoutException extends NativeNetException {
  const TimeoutException({
    required super.message,
    super.code = 'TIMEOUT',
    super.details,
  });
}

/// Thrown when SSL/TLS certificate validation fails.
class CertificateException extends NativeNetException {
  const CertificateException({
    required super.message,
    super.code = 'CERTIFICATE_ERROR',
    super.details,
  });
}

/// Thrown when the request is cancelled.
class CancelledException extends NativeNetException {
  const CancelledException({
    super.message = 'Request was cancelled',
    super.code = 'CANCELLED',
    super.details,
  });
}

/// Creates a NativeNetException from a platform error map.
NativeNetException createExceptionFromPlatformError(
  String code,
  String? message,
  dynamic details,
) {
  final msg = message ?? 'Unknown error';
  switch (code) {
    case 'CONNECTION_ERROR':
      return ConnectionException(message: msg, details: details);
    case 'TIMEOUT':
      return TimeoutException(message: msg, details: details);
    case 'CERTIFICATE_ERROR':
      return CertificateException(message: msg, details: details);
    case 'CANCELLED':
      return CancelledException(message: msg, details: details);
    default:
      return NativeNetException(message: msg, code: code, details: details);
  }
}
