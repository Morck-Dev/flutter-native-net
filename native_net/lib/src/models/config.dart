/// Configuration for [NativeNetClient].
///
/// Controls default timeouts, redirect behavior, logging, and other
/// client-level settings that apply to all requests made by the client.
class NativeNetConfig {
  /// Default connection timeout for all requests.
  final Duration connectTimeout;

  /// Default read timeout for all requests.
  final Duration readTimeout;

  /// Default write timeout for all requests.
  final Duration writeTimeout;

  /// Whether to follow redirects by default.
  final bool followRedirects;

  /// Maximum number of redirects to follow.
  final int maxRedirects;

  /// Default headers applied to all requests.
  final Map<String, String>? defaultHeaders;

  /// Whether to enable native-level logging.
  final bool enableLogging;

  /// Maximum number of idle connections in the connection pool (Android/OkHttp).
  final int maxIdleConnections;

  /// Keep-alive duration for idle connections.
  final Duration keepAliveDuration;

  const NativeNetConfig({
    this.connectTimeout = const Duration(seconds: 30),
    this.readTimeout = const Duration(seconds: 30),
    this.writeTimeout = const Duration(seconds: 30),
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.defaultHeaders,
    this.enableLogging = false,
    this.maxIdleConnections = 5,
    this.keepAliveDuration = const Duration(minutes: 5),
  });

  /// Converts this config to a map for platform channel serialization.
  Map<String, dynamic> toMap() {
    return {
      'connectTimeout': connectTimeout.inMilliseconds,
      'readTimeout': readTimeout.inMilliseconds,
      'writeTimeout': writeTimeout.inMilliseconds,
      'followRedirects': followRedirects,
      'maxRedirects': maxRedirects,
      if (defaultHeaders != null) 'defaultHeaders': defaultHeaders,
      'enableLogging': enableLogging,
      'maxIdleConnections': maxIdleConnections,
      'keepAliveDuration': keepAliveDuration.inMilliseconds,
    };
  }
}
