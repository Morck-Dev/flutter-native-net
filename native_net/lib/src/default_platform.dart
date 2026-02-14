// Conditional export that selects the platform implementation at compile time.
//
// - Native platforms (Android, iOS, macOS, Linux, Windows):
//   Uses FfiNativeNetPlatform which wraps libcurl via dart:ffi.
//
// - Web:
//   Uses WebNativeNetPlatform which wraps the browser Fetch API.
export 'ffi/ffi_platform.dart'
    if (dart.library.js_interop) 'web/web_platform.dart';
