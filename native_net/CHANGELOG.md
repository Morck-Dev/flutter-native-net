## 0.1.0

* Initial release
* Android: OkHttp 4.12.0 integration
  * HTTP/2 support, connection pooling, transparent GZIP
  * Configurable timeouts, redirect handling
  * Multipart file upload support
  * Request logging via OkHttp's logging interceptor
* iOS/macOS: URLSession integration
  * HTTP/2 & HTTP/3 support
  * System certificate management
  * Automatic proxy configuration
  * Multipart file upload support
* Dart API:
  * Unified `NativeNetClient` with convenience methods (get, post, put, delete, patch, head)
  * JSON helper methods (postJson, putJson, patchJson)
  * Request/Response interceptors
  * Typed exceptions (TimeoutException, ConnectionException, CertificateException)
  * Configurable defaults (timeouts, headers, logging)
