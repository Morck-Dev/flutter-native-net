/// A Flutter plugin for native HTTP networking powered by **libcurl**.
///
/// Uses libcurl (built from source) via dart:ffi on all native platforms
/// and falls back to the browser Fetch API on web.
library;

// Client
export 'src/client.dart';

// Models
export 'src/models/config.dart';
export 'src/models/cookie_config.dart';
export 'src/models/exceptions.dart';
export 'src/models/http_method.dart';
export 'src/models/progress.dart';
export 'src/models/proxy_config.dart';
export 'src/models/request.dart';
export 'src/models/response.dart';
export 'src/models/tls_config.dart';
