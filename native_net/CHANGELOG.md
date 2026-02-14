## 0.2.0

* **BREAKING**: Migrated from OkHttp/URLSession to unified libcurl backend
* All native platforms now use the same C code wrapping libcurl via dart:ffi
* Platform-specific TLS backends:
  * Android: mbedTLS (auto-built via CMake FetchContent)
  * iOS/macOS: Apple Secure Transport
  * Windows: Schannel
  * Linux: OpenSSL (system)
* Web platform support via browser Fetch API fallback
* Added Linux and Windows platform support
* Multipart body building moved to Dart layer for consistency
* Requests execute in worker Isolates (non-blocking UI thread)

## 0.1.0

* Initial release with OkHttp (Android) and URLSession (iOS/macOS)
