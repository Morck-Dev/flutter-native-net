## 0.2.1

* **Always build libcurl from source** – no longer depends on system-installed
  libcurl. Works reliably on minimal Docker containers, CI servers, etc.
* TLS backend per platform (zero external dependency):
  * Android & Linux → mbedTLS (built from source)
  * Windows → Schannel
  * iOS / macOS → Apple Secure Transport
* **New: `downloadFile()`** – download large files directly to disk
  with progress callback and cancellation support
* **New: `uploadFile()`** – upload files via multipart/form-data streamed
  from disk (never loaded entirely into memory) with progress callback
* **New: `CancelToken`** – cancel in-progress file transfers
* **New: `ProgressCallback`** – receive periodic progress updates
* macOS now also builds libcurl from source (was using system curl)

## 0.2.0

* Migrated from OkHttp/URLSession to unified libcurl backend
* All native platforms use the same C code wrapping libcurl via dart:ffi
* Web platform support via browser Fetch API fallback
* Added Linux and Windows platform support

## 0.1.0

* Initial release with OkHttp (Android) and URLSession (iOS/macOS)
