import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'native_net_method_channel.dart';

/// The interface that implementations of native_net must implement.
///
/// Platform implementations should extend this class rather than implement
/// it as `NativeNetPlatform`. Extending this class (using `extends`) ensures
/// that the subclass will get the default implementation, while platform
/// implementations that `implements` this interface will be broken by newly
/// added [NativeNetPlatform] methods.
abstract class NativeNetPlatform extends PlatformInterface {
  NativeNetPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeNetPlatform _instance = MethodChannelNativeNet();

  /// The default instance of [NativeNetPlatform] to use.
  static NativeNetPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NativeNetPlatform] when
  /// they register themselves.
  static set instance(NativeNetPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Gets the platform version string.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// Initializes the native HTTP client with the given configuration.
  Future<void> initialize(Map<String, dynamic> config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Sends an HTTP request and returns the response.
  Future<Map<dynamic, dynamic>> request(Map<String, dynamic> requestData) {
    throw UnimplementedError('request() has not been implemented.');
  }

  /// Cancels a request by its tag/identifier.
  Future<void> cancelRequest(String tag) {
    throw UnimplementedError('cancelRequest() has not been implemented.');
  }

  /// Shuts down the native HTTP client and releases resources.
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}
