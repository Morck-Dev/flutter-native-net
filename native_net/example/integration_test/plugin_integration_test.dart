// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:native_net/native_net.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NativeNetClient can make a GET request',
      (WidgetTester tester) async {
    final client = NativeNetClient(
      config: const NativeNetConfig(
        connectTimeout: Duration(seconds: 10),
        readTimeout: Duration(seconds: 10),
      ),
    );

    final response = await client.get('https://httpbin.org/get');
    expect(response.isSuccess, true);
    expect(response.statusCode, 200);

    await client.close();
  });
}
