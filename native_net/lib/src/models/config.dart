import 'cookie_config.dart';
import 'proxy_config.dart';
import 'tls_config.dart';

/// HTTP version preference.
enum HttpVersion {
  /// Let libcurl decide (default).
  auto_(0),

  /// Force HTTP/1.0.
  http10(1),

  /// Force HTTP/1.1.
  http11(2),

  /// Prefer HTTP/2 (with HTTP/1.1 fallback).
  http2(3),

  /// Prefer HTTP/3 (with fallback, requires QUIC support in the build).
  http3(4);

  final int value;
  const HttpVersion(this.value);
}

/// Configuration for [NativeNetClient].
///
/// Controls defaults for timeouts, TLS, proxy, cookies, HTTP version,
/// speed limits, and other client-level settings that apply to all requests.
class NativeNetConfig {
  // ── Timeouts ──
  final Duration connectTimeout;
  final Duration readTimeout;
  final Duration writeTimeout;

  // ── Redirects ──
  final bool followRedirects;
  final int maxRedirects;

  // ── Headers ──
  final Map<String, String>? defaultHeaders;

  // ── TLS / SSL ──
  /// TLS configuration (self-signed certs, CA bundles, client certs, pinning).
  final TlsConfig? tls;

  // ── Proxy ──
  /// Proxy configuration (HTTP, SOCKS4, SOCKS5).
  final ProxyConfig? proxy;

  // ── Cookies ──
  /// Cookie configuration (in-memory or file-based cookie jar).
  final CookieConfig? cookies;

  // ── HTTP version ──
  /// Preferred HTTP version. Default: [HttpVersion.auto_].
  final HttpVersion httpVersion;

  // ── Speed limits ──
  /// Maximum download speed in bytes per second. 0 = unlimited.
  final int maxDownloadSpeed;

  /// Maximum upload speed in bytes per second. 0 = unlimited.
  final int maxUploadSpeed;

  // ── User-Agent ──
  /// Default User-Agent header. Set to `null` to use libcurl's default.
  final String? userAgent;

  // ── DNS ──
  /// Custom DNS servers (e.g. `"1.1.1.1,8.8.8.8"`).
  final String? dnsServers;

  // ── Logging ──
  final bool enableLogging;

  const NativeNetConfig({
    this.connectTimeout = const Duration(seconds: 30),
    this.readTimeout = const Duration(seconds: 30),
    this.writeTimeout = const Duration(seconds: 30),
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.defaultHeaders,
    this.tls,
    this.proxy,
    this.cookies,
    this.httpVersion = HttpVersion.auto_,
    this.maxDownloadSpeed = 0,
    this.maxUploadSpeed = 0,
    this.userAgent,
    this.dnsServers,
    this.enableLogging = false,
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
    };
  }
}
