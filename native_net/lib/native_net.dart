/// A Flutter plugin for native HTTP networking powered by **libcurl**.
///
/// Uses libcurl via dart:ffi on all native platforms (Android, iOS, macOS,
/// Linux, Windows) and falls back to the browser Fetch API on web.
///
/// ```dart
/// import 'package:native_net/native_net.dart';
///
/// final client = NativeNetClient();
/// final response = await client.get('https://httpbin.org/get');
/// print(response.body);
/// client.close();
/// ```
library;

// Client
export 'src/client.dart';

// Models
export 'src/models/config.dart';
export 'src/models/exceptions.dart';
export 'src/models/http_method.dart';
export 'src/models/request.dart';
export 'src/models/response.dart';
