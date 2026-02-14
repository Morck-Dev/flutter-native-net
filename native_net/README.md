# native_net

A Flutter plugin for **native HTTP networking** powered by [libcurl](https://curl.se/libcurl/) — the most widely deployed HTTP library in the world.

## Architecture

A single C codebase wraps libcurl and is compiled for every platform. Only one
native dependency to maintain.

```
┌──────────────────────────────────────────────────────┐
│              Dart API  (NativeNetClient)              │
│   Unified interface · interceptors · models          │
├──────────────────────────────────────────────────────┤
│                    dart:ffi bridge                    │
├─────────┬─────────┬───────┬───────┬──────┬───────────┤
│ Android │   iOS   │ macOS │ Linux │ Win  │    Web    │
│(mbedTLS)│(SecTrsp)│(SecTr)│(mbdTL)│(Sch) │(Fetch API)│
│         │         │       │       │      │           │
│         libcurl (always built from source)           │
└─────────┴─────────┴───────┴───────┴──────┴───────────┘
```

libcurl is **always built from source** — zero dependency on the host system.

| Platform | TLS Backend | libcurl Source |
|----------|-------------|----------------|
| **Android** | mbedTLS (auto-built) | CMake FetchContent |
| **iOS** | Secure Transport | Build script |
| **macOS** | Secure Transport | Build script |
| **Linux** | mbedTLS (auto-built) | CMake FetchContent |
| **Windows** | Schannel | CMake FetchContent |
| **Web** | Browser TLS | N/A (Fetch API fallback) |

## Why libcurl?

- **Battle-tested** — powers curl, PHP, Python requests, git, and 20 billion+ installations
- **Protocol support** — HTTP/1.1, HTTP/2, HTTP/3 (QUIC), WebSocket
- **Single codebase** — one C wrapper for all platforms (no OkHttp + URLSession + WinHTTP)
- **Connection pooling** — automatic keep-alive and connection reuse
- **Transparent compression** — gzip, deflate, brotli, zstd
- **Proxy support** — HTTP, SOCKS4, SOCKS5
- **Cookie engine** — built-in cookie jar
- **Redirect handling** — configurable automatic redirects

## Installation

```yaml
dependencies:
  native_net:
    git:
      url: https://github.com/example/flutter-native-net.git
      path: native_net
```

### Platform-specific setup

**Android, Linux, Windows** — no extra setup needed! libcurl and mbedTLS are
built automatically from source during the first Flutter build.

**iOS** — run the build script once before the first build:

```bash
cd native_net
bash scripts/build_curl_ios.sh
```

**macOS** — run the build script once before the first build:

```bash
cd native_net
bash scripts/build_curl_macos.sh
```

> The first build takes a few extra minutes to compile libcurl from source.
> Subsequent builds are cached and fast.

## Quick Start

```dart
import 'package:native_net/native_net.dart';

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

### HTTP Methods

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

### Configuration

```dart
const config = NativeNetConfig(
  connectTimeout: Duration(seconds: 30),    // Connection timeout
  readTimeout: Duration(seconds: 30),       // Read timeout
  writeTimeout: Duration(seconds: 30),      // Write timeout
  followRedirects: true,                     // Auto-follow redirects
  maxRedirects: 5,                           // Max redirect hops
  enableLogging: false,                      // curl verbose mode
  defaultHeaders: {                          // Applied to all requests
    'Authorization': 'Bearer token',
  },
);
```

### Response

```dart
response.statusCode;    // int: 200, 404, 500, …
response.body;          // String: UTF-8 decoded body
response.jsonBody;      // dynamic: Parsed JSON
response.bodyBytes;     // Uint8List: Raw bytes
response.headers;       // Map<String, String>
response.duration;      // Duration: Request time
response.isSuccess;     // bool: 2xx
response.isClientError; // bool: 4xx
response.isServerError; // bool: 5xx
response.finalUrl;      // String?: After redirects
```

### Interceptors

```dart
client.addRequestInterceptor((request) async {
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

client.addResponseInterceptor((response) async {
  if (response.statusCode == 401) {
    // Handle token refresh
  }
  return response;
});
```

### File Download

```dart
final token = CancelToken();

final response = await client.downloadFile(
  'https://example.com/large.zip',
  '/path/to/save/large.zip',
  onProgress: (received, total) {
    if (total > 0) {
      print('${(received / total * 100).toStringAsFixed(1)}%');
    }
  },
  cancelToken: token,
);

// To cancel mid-download:
// token.cancel();
```

Features:
- Streams directly to disk — supports arbitrarily large files
- Progress callback with bytes received and total size
- Cancellation via `CancelToken`
- Partial files are automatically deleted on error

### File Upload

```dart
final response = await client.uploadFile(
  'https://example.com/upload',
  '/path/to/photo.jpg',
  fieldName: 'photo',
  fileName: 'my_photo.jpg',
  contentType: 'image/jpeg',
  formFields: {'album': 'vacation', 'description': 'Beach day'},
  onProgress: (sent, total) {
    if (total > 0) {
      print('${(sent / total * 100).toStringAsFixed(1)}%');
    }
  },
);
```

Features:
- Uses libcurl's `curl_mime` API — file is streamed from disk, never loaded into memory
- Multipart/form-data with additional form fields
- Progress callback with bytes sent and total size
- Cancellation via `CancelToken`

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

## How It Works

1. **Dart layer** (`NativeNetClient`) provides a clean async API
2. Each HTTP request is sent to a **worker Isolate** (keeps UI thread responsive)
3. The worker isolate calls the **C wrapper** via `dart:ffi`
4. The C wrapper calls **libcurl's easy API** (blocking but in the isolate)
5. Response data is copied to Dart and the native memory is freed
6. On **web**, the browser's Fetch API is used instead (automatic fallback)

## Platform Requirements

| Platform | Minimum Version |
|----------|----------------|
| Android | API 24 (Android 7.0) |
| iOS | 12.0 |
| macOS | 10.14 |
| Linux | Any with libcurl 7.x+ |
| Windows | Windows 10+ |
| Web | Any modern browser |

## License

MIT License
