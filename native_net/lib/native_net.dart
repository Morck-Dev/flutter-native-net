/// A Flutter plugin that leverages native platform HTTP networking frameworks.
///
/// - **Android**: Uses OkHttp (Square's industry-standard HTTP client)
/// - **iOS/macOS**: Uses URLSession (Apple's native networking framework)
///
/// This provides better performance, automatic system proxy support,
/// platform certificate management, and HTTP/2 support compared to
/// pure-Dart HTTP clients.
library;

// Client
export 'src/client.dart';

// Models
export 'src/models/config.dart';
export 'src/models/exceptions.dart';
export 'src/models/http_method.dart';
export 'src/models/request.dart';
export 'src/models/response.dart';
