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
│  (NDK)  │(SecTrsp)│(sys)  │(sys)  │(Sch) │(Fetch API)│
│         │         │       │       │      │           │
│    libcurl + mbedTLS / SecureTransport / Schannel    │
└─────────┴─────────┴───────┴───────┴──────┴───────────┘
```

| Platform | TLS Backend | libcurl Source |
|----------|-------------|----------------|
| **Android** | mbedTLS (auto-built) | CMake FetchContent |
| **iOS** | Secure Transport | Build script |
| **macOS** | Secure Transport | System `/usr/lib/libcurl.dylib` |
| **Linux** | OpenSSL | System `libcurl.so` |
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

**Android, macOS, Linux, Windows** — no extra setup needed. libcurl is either
already on the system or is built automatically during the first Flutter build.

**iOS** — run the build script once before the first build:

```bash
cd native_net
bash scripts/build_curl_ios.sh
```

**Linux** — ensure system libcurl is installed:

```bash
sudo apt install libcurl4-openssl-dev   # Debian/Ubuntu
sudo dnf install libcurl-devel          # Fedora
```

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
