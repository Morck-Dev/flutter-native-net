import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_net/native_net_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelNativeNet platform = MethodChannelNativeNet();
  const MethodChannel channel = MethodChannel('native_net');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getPlatformVersion':
          return 'Android 14 (OkHttp 4.12.0)';
        case 'initialize':
          return null;
        case 'request':
          return {
            'statusCode': 200,
            'headers': {'content-type': 'application/json'},
            'bodyBytes': '{"ok":true}'.codeUnits,
            'reasonPhrase': 'OK',
            'contentLength': 11,
            'duration': 100,
          };
        case 'cancelRequest':
          return null;
        case 'dispose':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), 'Android 14 (OkHttp 4.12.0)');
  });

  test('initialize', () async {
    await platform.initialize({'connectTimeout': 30000});
    // Should not throw
  });

  test('request returns response map', () async {
    final result = await platform.request({
      'url': 'https://example.com',
      'method': 'GET',
    });

    expect(result['statusCode'], 200);
    expect(result['headers'], isA<Map>());
  });

  test('dispose', () async {
    await platform.dispose();
    // Should not throw
  });
}
