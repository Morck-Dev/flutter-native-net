# native_net

A Flutter plugin that leverages **native platform HTTP networking frameworks** for superior performance and platform integration.

| Platform | Native Framework | Key Features |
|----------|-----------------|--------------|
| **Android** | [OkHttp 4.12](https://square.github.io/okhttp/) | HTTP/2, connection pooling, transparent GZIP, interceptors |
| **iOS** | [URLSession](https://developer.apple.com/documentation/foundation/urlsession) | HTTP/2 & HTTP/3, system certificate management, ATS compliance |
| **macOS** | [URLSession](https://developer.apple.com/documentation/foundation/urlsession) | HTTP/2 & HTTP/3, system proxy support, Keychain integration |

## Why native_net?

Most Dart HTTP libraries (`http`, `dio`, etc.) use `dart:io`'s `HttpClient`, which is a standalone TLS/HTTP implementation that doesn't benefit from:

- **System proxy settings** - native frameworks automatically respect system-configured proxies
- **Platform certificate stores** - automatic trust of enterprise/system certificates
- **OS-level optimizations** - HTTP/2 multiplexing, connection coalescing, QUIC/HTTP/3
- **Connection pooling** - OkHttp's aggressive connection reuse saves significant latency
- **Network condition awareness** - iOS/macOS can intelligently manage requests based on network state

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  native_net:
    git:
      url: https://github.com/example/flutter-native-net.git
      path: native_net
```

## Quick Start

```dart
import 'package:native_net/native_net.dart';

// Create a client with configuration
final client = NativeNetClient(
  config: NativeNetConfig(
    connectTimeout: Duration(seconds: 10),
    readTimeout: Duration(seconds: 30),
    enableLogging: true,
    defaultHeaders: {
      'Authorization': 'Bearer your-token',
      'Accept': 'application/json',
    },
  ),
);

// GET request
final response = await client.get('https://api.example.com/users');
print(response.body);         // Response as string
print(response.jsonBody);     // Parsed JSON
print(response.statusCode);   // 200
print(response.isSuccess);    // true

// POST with JSON body
final createResponse = await client.postJson(
  'https://api.example.com/users',
  jsonBody: {
    'name': 'John Doe',
    'email': 'john@example.com',
  },
);

// Don't forget to close when done
client.close();
```

## API Reference

### NativeNetClient

The main HTTP client. Create one instance and reuse it across your app.

```dart
final client = NativeNetClient(config: NativeNetConfig(...));
```

#### HTTP Methods

| Method | Description |
|--------|-------------|
| `client.get(url)` | GET request |
| `client.post(url, body: ...)` | POST with string body |
| `client.postJson(url, jsonBody: ...)` | POST with auto-encoded JSON |
| `client.put(url, body: ...)` | PUT with string body |
| `client.putJson(url, jsonBody: ...)` | PUT with auto-encoded JSON |
| `client.patch(url, body: ...)` | PATCH with string body |
| `client.patchJson(url, jsonBody: ...)` | PATCH with auto-encoded JSON |
| `client.delete(url)` | DELETE request |
| `client.head(url)` | HEAD request |
| `client.multipart(url, files: ..., formFields: ...)` | Multipart form upload |

All methods accept optional `headers`, `connectTimeout`, and `readTimeout` parameters.

### NativeNetConfig

```dart
const config = NativeNetConfig(
  connectTimeout: Duration(seconds: 30),    // Connection timeout
  readTimeout: Duration(seconds: 30),       // Read timeout
  writeTimeout: Duration(seconds: 30),      // Write timeout
  followRedirects: true,                     // Auto-follow redirects
  maxRedirects: 5,                           // Max redirect hops
  enableLogging: false,                      // Native-level logging
  maxIdleConnections: 5,                     // Connection pool size (Android)
  keepAliveDuration: Duration(minutes: 5),   // Idle connection TTL
  defaultHeaders: {                          // Applied to all requests
    'Authorization': 'Bearer token',
  },
);
```

### NativeNetResponse

```dart
final response = await client.get('https://api.example.com/data');

response.statusCode;    // int: 200, 404, 500, etc.
response.body;          // String: UTF-8 decoded body
response.jsonBody;      // dynamic: Parsed JSON
response.bodyBytes;     // Uint8List: Raw bytes
response.headers;       // Map<String, String>
response.duration;      // Duration: Request time
response.isSuccess;     // bool: 2xx status
response.isClientError; // bool: 4xx status
response.isServerError; // bool: 5xx status
response.finalUrl;      // String?: After redirects
```

### Interceptors

```dart
// Request interceptor - modify requests before sending
client.addRequestInterceptor((request) async {
  // Add auth token to every request
  return NativeNetRequest(
    url: request.url,
    method: request.method,
    headers: {
      ...?request.headers,
      'Authorization': 'Bearer ${await getToken()}',
    },
    body: request.body,
  );
});

// Response interceptor - process responses
client.addResponseInterceptor((response) async {
  if (response.statusCode == 401) {
    // Handle token refresh
  }
  return response;
});
```

### File Upload (Multipart)

```dart
import 'dart:typed_data';

final response = await client.multipart(
  'https://api.example.com/upload',
  formFields: {
    'description': 'My photo',
  },
  files: [
    MultipartFile(
      field: 'photo',
      fileName: 'image.jpg',
      bytes: imageBytes,  // Uint8List
      contentType: 'image/jpeg',
    ),
  ],
);
```

### Error Handling

```dart
try {
  final response = await client.get('https://api.example.com/data');
} on TimeoutException catch (e) {
  print('Request timed out: ${e.message}');
} on ConnectionException catch (e) {
  print('Connection failed: ${e.message}');
} on CertificateException catch (e) {
  print('SSL error: ${e.message}');
} on CancelledException catch (e) {
  print('Request cancelled: ${e.message}');
} on NativeNetException catch (e) {
  print('Error (${e.code}): ${e.message}');
}
```

## Architecture

```
┌─────────────────────────────────────────┐
│           Dart API (NativeNetClient)     │
│  Unified interface, interceptors, models│
├─────────────────────────────────────────┤
│         Platform Interface              │
│     MethodChannel communication         │
├──────────┬──────────┬───────────────────┤
│ Android  │   iOS    │      macOS        │
│ (Kotlin) │ (Swift)  │     (Swift)       │
│          │          │                   │
│ OkHttp   │URLSession│   URLSession      │
│ 4.12.0   │          │                   │
└──────────┴──────────┴───────────────────┘
```

## Platform Requirements

| Platform | Minimum Version |
|----------|----------------|
| Android | API 24 (Android 7.0) |
| iOS | 12.0 |
| macOS | 10.14 |

## License

MIT License
