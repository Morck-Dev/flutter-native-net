import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_net_platform_interface.dart';

/// An implementation of [NativeNetPlatform] that uses method channels.
class MethodChannelNativeNet extends NativeNetPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('native_net');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    await methodChannel.invokeMethod<void>('initialize', config);
  }

  @override
  Future<Map<dynamic, dynamic>> request(
    Map<String, dynamic> requestData,
  ) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'request',
      requestData,
    );
    return result ?? {};
  }

  @override
  Future<void> cancelRequest(String tag) async {
    await methodChannel.invokeMethod<void>('cancelRequest', {'tag': tag});
  }

  @override
  Future<void> dispose() async {
    await methodChannel.invokeMethod<void>('dispose');
  }
}
