import 'src/default_platform.dart';

/// The interface that platform implementations of native_net must implement.
///
/// There are two implementations:
///   - [FfiNativeNetPlatform] – uses libcurl via dart:ffi (native platforms)
///   - [WebNativeNetPlatform] – uses the Fetch API (web)
///
/// The correct implementation is chosen at compile time via conditional
/// imports in [default_platform.dart].
///
/// For testing, you can replace the instance with a mock:
/// ```dart
/// NativeNetPlatform.instance = MockPlatform();
/// ```
abstract class NativeNetPlatform {
  NativeNetPlatform();

  static NativeNetPlatform? _instance;

  /// The current platform implementation.
  ///
  /// Defaults to the compile-time-selected implementation (FFI or Web).
  static NativeNetPlatform get instance {
    _instance ??= createDefaultPlatform();
    return _instance!;
  }

  /// Replace the platform implementation (useful for testing).
  static set instance(NativeNetPlatform platform) {
    _instance = platform;
  }

  /// Returns a string describing the native backend.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// Initialises the native HTTP client with the given configuration.
  Future<void> initialize(Map<String, dynamic> config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Sends an HTTP request and returns the response as a map.
  Future<Map<dynamic, dynamic>> request(Map<String, dynamic> requestData) {
    throw UnimplementedError('request() has not been implemented.');
  }

  /// Cancels a request identified by [tag].
  Future<void> cancelRequest(String tag) {
    throw UnimplementedError('cancelRequest() has not been implemented.');
  }

  /// Shuts down the native HTTP client and releases resources.
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}
