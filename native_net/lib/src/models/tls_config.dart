/// TLS/SSL configuration for controlling certificate verification,
/// custom CA bundles, client certificates, and certificate pinning.
///
/// ## Self-signed certificates
/// ```dart
/// const tls = TlsConfig(verifyPeer: false, verifyHost: false);
/// ```
///
/// ## Custom CA bundle (enterprise / internal CA)
/// ```dart
/// const tls = TlsConfig(caInfoPath: '/path/to/ca-bundle.crt');
/// ```
///
/// ## Client certificate (mTLS / mutual TLS)
/// ```dart
/// const tls = TlsConfig(
///   clientCertPath: '/path/to/client.pem',
///   clientKeyPath: '/path/to/client-key.pem',
/// );
/// ```
///
/// ## Certificate pinning
/// ```dart
/// const tls = TlsConfig(
///   pinnedPublicKey: 'sha256//YhKJG3J9...=',
/// );
/// ```
class TlsConfig {
  /// Whether to verify the server's SSL certificate.
  /// Set to `false` to accept self-signed certificates.
  /// Default: `true`.
  final bool verifyPeer;

  /// Whether to verify the hostname in the certificate.
  /// Set to `false` to accept certificates for IP addresses or
  /// mismatched hostnames.
  /// Default: `true`.
  final bool verifyHost;

  /// Path to a CA bundle file (PEM format) for verifying the server.
  /// If not set, the system/mbedTLS default bundle is used.
  final String? caInfoPath;

  /// Path to a directory containing CA certificate files.
  final String? caDirectoryPath;

  /// Path to a client certificate file for mutual TLS (mTLS).
  final String? clientCertPath;

  /// Path to the client's private key file.
  final String? clientKeyPath;

  /// Type of the client certificate. Default: `"PEM"`.
  /// Can also be `"DER"`.
  final String? clientCertType;

  /// Public key hash(es) for certificate pinning.
  ///
  /// Format: `"sha256//base64hash"` (multiple separated by `;`).
  ///
  /// When set, the connection will fail unless the server's certificate
  /// matches one of the pinned hashes.
  final String? pinnedPublicKey;

  const TlsConfig({
    this.verifyPeer = true,
    this.verifyHost = true,
    this.caInfoPath,
    this.caDirectoryPath,
    this.clientCertPath,
    this.clientKeyPath,
    this.clientCertType,
    this.pinnedPublicKey,
  });

  /// Convenience: accept all certificates (useful for development only).
  static const TlsConfig insecure = TlsConfig(
    verifyPeer: false,
    verifyHost: false,
  );
}
