/// Proxy type constants matching libcurl's CURLPROXY_* values.
enum ProxyType {
  /// HTTP proxy (default).
  http(0),

  /// SOCKS4 proxy.
  socks4(4),

  /// SOCKS5 proxy.
  socks5(5);

  final int value;
  const ProxyType(this.value);
}

/// Proxy configuration for routing requests through a proxy server.
///
/// ## HTTP proxy
/// ```dart
/// const proxy = ProxyConfig(url: 'http://proxy.example.com:8080');
/// ```
///
/// ## SOCKS5 proxy with auth
/// ```dart
/// const proxy = ProxyConfig(
///   url: 'socks5://proxy.example.com:1080',
///   type: ProxyType.socks5,
///   username: 'user',
///   password: 'pass',
/// );
/// ```
class ProxyConfig {
  /// Proxy server URL (e.g. `"http://proxy:8080"`).
  final String url;

  /// Proxy type. Defaults to [ProxyType.http].
  final ProxyType type;

  /// Proxy username (optional).
  final String? username;

  /// Proxy password (optional).
  final String? password;

  /// Whether to tunnel through the proxy via HTTP CONNECT.
  /// Required for HTTPS through an HTTP proxy.
  final bool tunnel;

  const ProxyConfig({
    required this.url,
    this.type = ProxyType.http,
    this.username,
    this.password,
    this.tunnel = false,
  });
}
