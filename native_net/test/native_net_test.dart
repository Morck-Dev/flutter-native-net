import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_net/native_net.dart';
import 'package:native_net/native_net_platform_interface.dart';
import 'package:native_net/native_net_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNativeNetPlatform
    with MockPlatformInterfaceMixin
    implements NativeNetPlatform {

  bool initialized = false;
  bool disposed = false;
  Map<String, dynamic>? lastConfig;
  Map<String, dynamic>? lastRequest;

  @override
  Future<String?> getPlatformVersion() async => 'Test Platform 1.0 (Mock)';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    initialized = true;
    lastConfig = config;
  }

  @override
  Future<Map<dynamic, dynamic>> request(Map<String, dynamic> requestData) async {
    lastRequest = requestData;
    return {
      'statusCode': 200,
      'headers': {'content-type': 'application/json'},
      'bodyBytes': Uint8List.fromList('{"message":"ok"}'.codeUnits),
      'reasonPhrase': 'OK',
      'contentLength': 16,
      'duration': 100,
      'finalUrl': requestData['url'],
    };
  }

  @override
  Future<void> cancelRequest(String tag) async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  final NativeNetPlatform initialPlatform = NativeNetPlatform.instance;

  test('$MethodChannelNativeNet is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNativeNet>());
  });

  group('NativeNetClient', () {
    late MockNativeNetPlatform mockPlatform;
    late NativeNetClient client;

    setUp(() {
      mockPlatform = MockNativeNetPlatform();
      NativeNetPlatform.instance = mockPlatform;
      client = NativeNetClient(
        config: const NativeNetConfig(
          connectTimeout: Duration(seconds: 10),
          defaultHeaders: {'X-Custom': 'test'},
        ),
      );
    });

    test('getPlatformVersion returns mock platform version', () async {
      expect(await client.getPlatformVersion(), 'Test Platform 1.0 (Mock)');
    });

    test('GET request initializes client and sends correct data', () async {
      final response = await client.get('https://api.example.com/data');

      expect(mockPlatform.initialized, isTrue);
      expect(mockPlatform.lastRequest?['url'], 'https://api.example.com/data');
      expect(mockPlatform.lastRequest?['method'], 'GET');
      expect(response.statusCode, 200);
      expect(response.body, '{"message":"ok"}');
      expect(response.isSuccess, isTrue);
    });

    test('POST request sends body correctly', () async {
      final response = await client.post(
        'https://api.example.com/data',
        body: '{"key":"value"}',
        headers: {'Content-Type': 'application/json'},
      );

      expect(mockPlatform.lastRequest?['method'], 'POST');
      expect(mockPlatform.lastRequest?['body'], '{"key":"value"}');
      expect(response.statusCode, 200);
    });

    test('postJson encodes body and sets content type', () async {
      await client.postJson(
        'https://api.example.com/data',
        jsonBody: {'key': 'value'},
      );

      expect(mockPlatform.lastRequest?['method'], 'POST');
      expect(mockPlatform.lastRequest?['body'], '{"key":"value"}');
      expect(
        mockPlatform.lastRequest?['headers']?['Content-Type'],
        'application/json; charset=utf-8',
      );
    });

    test('PUT request works correctly', () async {
      await client.put(
        'https://api.example.com/data/1',
        body: '{"updated":true}',
      );

      expect(mockPlatform.lastRequest?['method'], 'PUT');
      expect(mockPlatform.lastRequest?['body'], '{"updated":true}');
    });

    test('DELETE request works correctly', () async {
      await client.delete('https://api.example.com/data/1');

      expect(mockPlatform.lastRequest?['method'], 'DELETE');
    });

    test('PATCH request works correctly', () async {
      await client.patchJson(
        'https://api.example.com/data/1',
        jsonBody: {'field': 'patched'},
      );

      expect(mockPlatform.lastRequest?['method'], 'PATCH');
    });

    test('HEAD request works correctly', () async {
      await client.head('https://api.example.com/data');

      expect(mockPlatform.lastRequest?['method'], 'HEAD');
    });

    test('default headers are merged with request headers', () async {
      await client.get(
        'https://api.example.com/data',
        headers: {'Accept': 'application/json'},
      );

      final headers = mockPlatform.lastRequest?['headers'] as Map?;
      expect(headers?['X-Custom'], 'test');
      expect(headers?['Accept'], 'application/json');
    });

    test('request headers override default headers', () async {
      await client.get(
        'https://api.example.com/data',
        headers: {'X-Custom': 'overridden'},
      );

      final headers = mockPlatform.lastRequest?['headers'] as Map?;
      expect(headers?['X-Custom'], 'overridden');
    });

    test('close disposes platform resources', () async {
      // Trigger initialization
      await client.get('https://api.example.com/data');
      await client.close();

      expect(mockPlatform.disposed, isTrue);
    });

    test('request after close throws exception', () async {
      await client.close();

      expect(
        () => client.get('https://api.example.com/data'),
        throwsA(isA<NativeNetException>()),
      );
    });

    test('request interceptors are applied', () async {
      client.addRequestInterceptor((request) async {
        return NativeNetRequest(
          url: request.url,
          method: request.method,
          headers: {
            ...?request.headers,
            'X-Intercepted': 'true',
          },
        );
      });

      await client.get('https://api.example.com/data');

      final headers = mockPlatform.lastRequest?['headers'] as Map?;
      expect(headers?['X-Intercepted'], 'true');
    });

    test('response interceptors are applied', () async {
      NativeNetResponse? interceptedResponse;
      client.addResponseInterceptor((response) async {
        interceptedResponse = response;
        return response;
      });

      await client.get('https://api.example.com/data');

      expect(interceptedResponse, isNotNull);
      expect(interceptedResponse?.statusCode, 200);
    });

    test('custom timeouts are sent to platform', () async {
      await client.get(
        'https://api.example.com/data',
        connectTimeout: const Duration(seconds: 5),
        readTimeout: const Duration(seconds: 10),
      );

      expect(mockPlatform.lastRequest?['connectTimeout'], 5000);
      expect(mockPlatform.lastRequest?['readTimeout'], 10000);
    });
  });

  group('NativeNetResponse', () {
    test('fromMap correctly parses response data', () {
      final response = NativeNetResponse.fromMap({
        'statusCode': 200,
        'headers': {'content-type': 'application/json'},
        'bodyBytes': Uint8List.fromList('{"ok":true}'.codeUnits),
        'reasonPhrase': 'OK',
        'contentLength': 11,
        'duration': 150,
        'finalUrl': 'https://api.example.com/data',
      });

      expect(response.statusCode, 200);
      expect(response.body, '{"ok":true}');
      expect(response.jsonBody, {'ok': true});
      expect(response.isSuccess, isTrue);
      expect(response.duration.inMilliseconds, 150);
      expect(response.headers['content-type'], 'application/json');
    });

    test('status code ranges are detected correctly', () {
      expect(
        NativeNetResponse(statusCode: 200, headers: const {}, bodyBytes: Uint8List(0)).isSuccess,
        isTrue,
      );
      expect(
        NativeNetResponse(statusCode: 301, headers: const {}, bodyBytes: Uint8List(0)).isRedirect,
        isTrue,
      );
      expect(
        NativeNetResponse(statusCode: 404, headers: const {}, bodyBytes: Uint8List(0)).isClientError,
        isTrue,
      );
      expect(
        NativeNetResponse(statusCode: 500, headers: const {}, bodyBytes: Uint8List(0)).isServerError,
        isTrue,
      );
    });
  });

  group('NativeNetConfig', () {
    test('toMap correctly serializes config', () {
      const config = NativeNetConfig(
        connectTimeout: Duration(seconds: 10),
        readTimeout: Duration(seconds: 20),
        writeTimeout: Duration(seconds: 15),
        enableLogging: true,
        defaultHeaders: {'X-Api-Key': 'abc123'},
      );

      final map = config.toMap();
      expect(map['connectTimeout'], 10000);
      expect(map['readTimeout'], 20000);
      expect(map['writeTimeout'], 15000);
      expect(map['enableLogging'], true);
      expect(map['defaultHeaders'], {'X-Api-Key': 'abc123'});
    });
  });

  group('NativeNetRequest', () {
    test('toMap correctly serializes request', () {
      final request = NativeNetRequest(
        url: 'https://api.example.com/data',
        method: HttpMethod.post,
        headers: {'Content-Type': 'application/json'},
        body: '{"key":"value"}',
        connectTimeout: const Duration(seconds: 5),
      );

      final map = request.toMap();
      expect(map['url'], 'https://api.example.com/data');
      expect(map['method'], 'POST');
      expect(map['headers'], {'Content-Type': 'application/json'});
      expect(map['body'], '{"key":"value"}');
      expect(map['connectTimeout'], 5000);
    });

    test('cannot specify both body and bodyBytes', () {
      expect(
        () => NativeNetRequest(
          url: 'https://api.example.com/data',
          method: HttpMethod.post,
          body: 'text',
          bodyBytes: Uint8List(0),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Exceptions', () {
    test('createExceptionFromPlatformError creates correct types', () {
      expect(
        createExceptionFromPlatformError('CONNECTION_ERROR', 'msg', null),
        isA<ConnectionException>(),
      );
      expect(
        createExceptionFromPlatformError('TIMEOUT', 'msg', null),
        isA<TimeoutException>(),
      );
      expect(
        createExceptionFromPlatformError('CERTIFICATE_ERROR', 'msg', null),
        isA<CertificateException>(),
      );
      expect(
        createExceptionFromPlatformError('CANCELLED', 'msg', null),
        isA<CancelledException>(),
      );
      expect(
        createExceptionFromPlatformError('UNKNOWN', 'msg', null),
        isA<NativeNetException>(),
      );
    });
  });
}
