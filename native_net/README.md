# native_net

Flutter 原生 HTTP 网络插件，基于 [libcurl](https://curl.se/libcurl/) —— 全球部署量超过 **200 亿次**、历经 27 年考验的 HTTP 引擎。

只需维护 **一套 C 代码**，即可在 Android、iOS、macOS、Linux、Windows 上获得完全一致的网络行为。Web 平台自动回退到浏览器 Fetch API。

---

## 目录

- [架构](#架构)
- [为什么选择 libcurl](#为什么选择-libcurl)
- [平台支持](#平台支持)
- [安装](#安装)
- [快速开始](#快速开始)
- [完整功能列表](#完整功能列表)
  - [HTTP 请求方法](#http-请求方法)
  - [客户端配置](#客户端配置)
  - [TLS / SSL 证书控制](#tls--ssl-证书控制)
  - [代理 (Proxy)](#代理-proxy)
  - [Cookie 管理](#cookie-管理)
  - [HTTP 认证](#http-认证)
  - [HTTP 版本控制](#http-版本控制)
  - [文件下载](#文件下载)
  - [文件上传](#文件上传)
  - [进度回调与取消](#进度回调与取消)
  - [请求/响应拦截器](#请求响应拦截器)
  - [限速](#限速)
  - [断点续传](#断点续传)
  - [自定义 DNS](#自定义-dns)
  - [响应对象](#响应对象)
  - [异常处理](#异常处理)
- [工作原理](#工作原理)
- [libcurl 功能覆盖率](#libcurl-功能覆盖率)
- [License](#license)

---

## 架构

```
┌──────────────────────────────────────────────────────────┐
│              Dart API  (NativeNetClient)                  │
│   统一接口 · 拦截器 · 模型类 · 进度回调 · 取消令牌         │
├──────────────────────────────────────────────────────────┤
│              dart:ffi (NativeNetRequestOptions 结构体)     │
├──────────┬──────────┬───────┬───────┬───────┬────────────┤
│ Android  │   iOS    │ macOS │ Linux │ Win   │    Web     │
│ (mbedTLS)│(SecTrans)│(SecTr)│(mbdTL)│(Schan)│ (Fetch API)│
│          │          │       │       │       │            │
│          libcurl 8.11 (始终从源码编译)        │  浏览器原生  │
└──────────┴──────────┴───────┴───────┴───────┴────────────┘
```

libcurl **始终从源码编译**，不依赖宿主系统是否预装 libcurl，在精简 Docker 容器、CI 服务器等环境下也能正常工作。

| 平台 | TLS 后端 | libcurl 来源 | 系统依赖 |
|------|---------|-------------|---------|
| **Android** | mbedTLS (随 curl 一起编译) | CMake FetchContent | 无 |
| **iOS** | Apple Secure Transport | 构建脚本 | 无 |
| **macOS** | Apple Secure Transport | 构建脚本 | 无 |
| **Linux** | mbedTLS (随 curl 一起编译) | CMake FetchContent | 无 |
| **Windows** | Schannel (系统自带) | CMake FetchContent | 无 |
| **Web** | 浏览器 TLS | 不适用 | 无 |

---

## 为什么选择 libcurl

| 特性 | 说明 |
|------|------|
| **久经考验** | 驱动 curl, PHP, Python requests, git, 以及 200 亿+次安装 |
| **协议丰富** | HTTP/1.0, HTTP/1.1, HTTP/2, HTTP/3 (QUIC) |
| **一套代码** | 一份 C 封装在所有平台编译，无需分别维护 OkHttp + URLSession + WinHTTP |
| **连接池** | 自动 keep-alive、连接复用 |
| **透明压缩** | 自动解压 gzip, deflate, brotli, zstd |
| **TLS 完整控制** | 自签名证书、IP 证书、CA 自定义、客户端证书 (mTLS)、证书锁定 |
| **代理** | HTTP, HTTPS, SOCKS4, SOCKS5 |
| **Cookie 引擎** | 内置 Cookie Jar（内存或文件持久化） |
| **重定向** | 可配置的自动跟随重定向 |
| **断点续传** | Range 请求 / Resume 下载 |

---

## 平台支持

本插件的原生层 (libcurl) 支持极老的系统。实际最低版本受 Flutter 框架自身限制：

| 平台 | 原生层最低版本 | 对应设备 / 年份 |
|------|-------------|---------------|
| **Android** | API 21 (Android 5.0 Lollipop) | 2014 年设备 |
| **iOS** | 9.0 | iPhone 4S+ (2015) |
| **macOS** | 10.11 (El Capitan) | 2015 年 Mac |
| **Linux** | glibc 2.17+ | CentOS 7 / Ubuntu 14.04 (2014) |
| **Windows** | Windows 7 SP1+ | 2009 年 PC |
| **Web** | 任何现代浏览器 | Chrome 42+, Firefox 39+, Safari 10+ |

> **注意**: Flutter 框架本身对 iOS 要求 12.0+、macOS 要求 10.14+。如果你的 Flutter 版本有更高要求，以 Flutter 为准。本插件的原生库本身可以在上表所列的更老系统上运行。

---

## 安装

```yaml
dependencies:
  native_net:
    git:
      url: https://github.com/example/flutter-native-net.git
      path: native_net
```

### 各平台设置

**Android / Linux** — **无需额外设置**。首次构建时自动从源码编译 libcurl 和 mbedTLS。

**Windows** — 需要开启 **开发者模式**（Flutter 插件在 Windows 上依赖符号链接）：

```
方法一：命令行打开设置（推荐）
  start ms-settings:developers
  → 打开后启用「开发者模式」开关

方法二：手动设置
  设置 → 更新和安全 → 开发者选项 → 打开「开发者模式」

方法三：以管理员身份运行终端（临时方案，不推荐长期使用）
```

开启后首次构建会自动从源码编译 libcurl + Schannel（Windows 原生 TLS），无需手动操作。

**iOS** — 首次构建前运行一次脚本：

```bash
cd native_net
bash scripts/build_curl_ios.sh
```

**macOS** — 首次构建前运行一次脚本：

```bash
cd native_net
bash scripts/build_curl_macos.sh
```

> 首次编译需要几分钟下载和编译 libcurl 源码，后续构建会使用缓存。

---

## 快速开始

```dart
import 'package:native_net/native_net.dart';

// 1. 创建客户端
final client = NativeNetClient(
  config: NativeNetConfig(
    connectTimeout: Duration(seconds: 10),
    readTimeout: Duration(seconds: 30),
    defaultHeaders: {
      'Accept': 'application/json',
    },
  ),
);

// 2. 发送请求
final response = await client.get('https://httpbin.org/get');

print(response.statusCode);  // 200
print(response.body);        // 响应体字符串
print(response.jsonBody);    // 自动解析的 JSON
print(response.isSuccess);   // true
print(response.duration);    // 请求耗时

// 3. 用完关闭
await client.close();
```

---

## 完整功能列表

### HTTP 请求方法

```dart
// GET
final resp = await client.get('https://api.example.com/users');

// POST (字符串 body)
final resp = await client.post(
  'https://api.example.com/users',
  body: '{"name":"张三"}',
  headers: {'Content-Type': 'application/json'},
);

// POST (自动 JSON 编码)
final resp = await client.postJson(
  'https://api.example.com/users',
  jsonBody: {'name': '张三', 'age': 30},
);

// PUT / PUT JSON
await client.put(url, body: '...');
await client.putJson(url, jsonBody: {...});

// PATCH / PATCH JSON
await client.patch(url, body: '...');
await client.patchJson(url, jsonBody: {...});

// DELETE
await client.delete('https://api.example.com/users/1');

// HEAD (只获取响应头)
final resp = await client.head(url);

// Multipart (内存中的文件)
await client.multipart(
  'https://api.example.com/upload',
  files: [
    MultipartFile(
      field: 'avatar',
      fileName: 'photo.jpg',
      bytes: imageBytes,
      contentType: 'image/jpeg',
    ),
  ],
  formFields: {'name': '张三'},
);
```

所有方法均支持可选参数 `headers`, `connectTimeout`, `readTimeout`。

---

### 客户端配置

```dart
final client = NativeNetClient(
  config: NativeNetConfig(
    // ── 超时 ──
    connectTimeout: Duration(seconds: 10),
    readTimeout: Duration(seconds: 30),
    writeTimeout: Duration(seconds: 30),

    // ── 重定向 ──
    followRedirects: true,
    maxRedirects: 10,

    // ── 默认请求头 ──
    defaultHeaders: {
      'Authorization': 'Bearer your-token',
      'Accept': 'application/json',
      'Accept-Language': 'zh-CN',
    },

    // ── TLS (详见下文) ──
    tls: TlsConfig(...),

    // ── 代理 (详见下文) ──
    proxy: ProxyConfig(...),

    // ── Cookie (详见下文) ──
    cookies: CookieConfig(...),

    // ── HTTP 版本 ──
    httpVersion: HttpVersion.http2,

    // ── 限速 (字节/秒) ──
    maxDownloadSpeed: 1024 * 1024,  // 1 MB/s
    maxUploadSpeed: 512 * 1024,     // 512 KB/s

    // ── User-Agent ──
    userAgent: 'MyApp/1.0 (Flutter)',

    // ── 自定义 DNS ──
    dnsServers: '1.1.1.1,8.8.8.8',

    // ── 调试日志 (curl verbose 模式) ──
    enableLogging: false,
  ),
);
```

---

### TLS / SSL 证书控制

这是 native_net 的核心优势之一 —— 完整暴露了 libcurl 的 TLS 选项。

#### 信任自签名证书

开发/测试环境中常用的自签名证书：

```dart
final client = NativeNetClient(
  config: NativeNetConfig(
    tls: TlsConfig(
      verifyPeer: false,  // 不验证服务器证书
      verifyHost: false,  // 不验证主机名
    ),
    // 或使用快捷方式:
    // tls: TlsConfig.insecure,
  ),
);
```

#### IP 类型证书

证书签发给 IP 地址而非域名（如 `https://192.168.1.100:8443`）：

```dart
tls: TlsConfig(
  verifyHost: false,  // 跳过主机名验证，但仍验证证书链
),
```

#### 自建 CA / 企业内部 CA

指定自定义 CA 证书文件：

```dart
tls: TlsConfig(
  caInfoPath: '/path/to/internal-ca-bundle.crt',  // PEM 格式 CA 文件
  // 或指定 CA 目录:
  // caDirectoryPath: '/path/to/ca-certs/',
),
```

#### 客户端证书 (mTLS / 双向认证)

银行、企业内网等需要客户端证书的场景：

```dart
tls: TlsConfig(
  clientCertPath: '/path/to/client.pem',       // 客户端证书
  clientKeyPath: '/path/to/client-key.pem',    // 客户端私钥
  clientCertType: 'PEM',                        // 或 'DER'
),
```

#### 证书锁定 (Certificate Pinning)

防止中间人攻击，锁定服务器公钥：

```dart
tls: TlsConfig(
  pinnedPublicKey: 'sha256//YhKJG3J9GOzrafWMKxLePXm5GzAwq3N3Q8jRU9LxkTg=',
  // 多个 hash 用分号分隔:
  // pinnedPublicKey: 'sha256//hash1;sha256//hash2',
),
```

---

### 代理 (Proxy)

#### HTTP 代理

```dart
final client = NativeNetClient(
  config: NativeNetConfig(
    proxy: ProxyConfig(
      url: 'http://proxy.example.com:8080',
    ),
  ),
);
```

#### SOCKS5 代理 (含认证)

```dart
proxy: ProxyConfig(
  url: 'socks5://proxy.example.com:1080',
  type: ProxyType.socks5,
  username: 'user',
  password: 'pass',
),
```

#### HTTPS 隧道代理

```dart
proxy: ProxyConfig(
  url: 'http://proxy.example.com:8080',
  tunnel: true,  // 通过 HTTP CONNECT 隧道转发 HTTPS 流量
),
```

支持的代理类型：`ProxyType.http`、`ProxyType.socks4`、`ProxyType.socks5`。

---

### Cookie 管理

#### 手动设置 Cookie

```dart
final client = NativeNetClient(
  config: NativeNetConfig(
    cookies: CookieConfig(
      cookies: 'session=abc123; theme=dark; lang=zh-CN',
    ),
  ),
);
```

#### 持久化 Cookie Jar（文件存储）

```dart
cookies: CookieConfig(
  cookieFile: '/path/to/cookies.txt',  // 启动时读取
  cookieJar: '/path/to/cookies.txt',   // 请求后写入
),
```

#### 启用 Cookie 引擎但不加载文件

```dart
cookies: CookieConfig(
  cookieFile: '',  // 空字符串 = 启用引擎，但不从文件加载
),
```

---

### HTTP 认证

libcurl 支持 Basic、Digest、NTLM 等认证方式，通过在请求头中传递或使用 config：

```dart
// 方式一：通过 defaultHeaders
final client = NativeNetClient(
  config: NativeNetConfig(
    defaultHeaders: {
      'Authorization': 'Basic dXNlcjpwYXNz',  // base64(user:pass)
    },
  ),
);

// 方式二：通过 Bearer Token
final client = NativeNetClient(
  config: NativeNetConfig(
    defaultHeaders: {
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIs...',
    },
  ),
);
```

---

### HTTP 版本控制

```dart
final client = NativeNetClient(
  config: NativeNetConfig(
    httpVersion: HttpVersion.auto_,  // 自动选择（默认）
    // httpVersion: HttpVersion.http10,  // 强制 HTTP/1.0
    // httpVersion: HttpVersion.http11,  // 强制 HTTP/1.1
    // httpVersion: HttpVersion.http2,   // 优先 HTTP/2（自动回退 1.1）
    // httpVersion: HttpVersion.http3,   // 优先 HTTP/3（需编译时支持 QUIC）
  ),
);
```

---

### 文件下载

直接下载到磁盘，支持任意大文件（流式写入，不占内存）：

```dart
final token = CancelToken();

final response = await client.downloadFile(
  'https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso',
  '/sdcard/Download/ubuntu.iso',
  onProgress: (received, total) {
    if (total > 0) {
      final percent = (received / total * 100).toStringAsFixed(1);
      print('下载进度: $percent% ($received / $total bytes)');
    }
  },
  cancelToken: token,  // 可选：用于取消
);

print('下载完成, 状态码: ${response.statusCode}');
print('耗时: ${response.duration.inSeconds}秒');
```

特性：
- 通过 `fwrite` 回调直接写磁盘，支持 GB 级大文件
- 实时进度回调
- 支持中途取消（`token.cancel()`）
- 出错时自动删除残留文件
- 支持断点续传（配合 `resumeFrom` 配置）

---

### 文件上传

通过 libcurl 的 `curl_mime` API 从磁盘流式上传，不将文件加载到内存：

```dart
final response = await client.uploadFile(
  'https://api.example.com/upload',
  '/sdcard/DCIM/photo.jpg',
  fieldName: 'photo',                // 表单字段名
  fileName: 'my_vacation.jpg',       // 显示文件名
  contentType: 'image/jpeg',         // MIME 类型
  formFields: {                       // 额外表单字段
    'album': 'vacation',
    'description': '海边度假照片',
  },
  onProgress: (sent, total) {
    if (total > 0) {
      print('上传进度: ${(sent / total * 100).toStringAsFixed(1)}%');
    }
  },
  cancelToken: token,
);

print('上传完成: ${response.body}');
```

特性：
- 使用 `curl_mime_filedata` 从磁盘流式读取，支持 GB 级大文件
- multipart/form-data 格式 + 额外表单字段
- 实时进度回调 + 取消支持

---

### 进度回调与取消

#### ProgressCallback

```dart
typedef ProgressCallback = void Function(int current, int total);
```

`total` 为 0 表示服务器未返回 Content-Length（此时无法计算百分比）。

#### CancelToken

```dart
final token = CancelToken();

// 开始下载
final future = client.downloadFile(url, path, cancelToken: token);

// 3 秒后取消
Future.delayed(Duration(seconds: 3), () => token.cancel());

try {
  await future;
} on CancelledException {
  print('下载已取消');
}
```

取消是**协作式**的：libcurl 在下一次进度回调时检查取消标志并中止传输。

---

### 请求/响应拦截器

#### 请求拦截器

在每个请求发出前修改：

```dart
client.addRequestInterceptor((request) async {
  // 自动添加认证 token
  final token = await AuthService.getToken();
  return NativeNetRequest(
    url: request.url,
    method: request.method,
    headers: {
      ...?request.headers,
      'Authorization': 'Bearer $token',
      'X-Request-Id': Uuid().v4(),
    },
    body: request.body,
  );
});
```

#### 响应拦截器

在每个响应返回后处理：

```dart
client.addResponseInterceptor((response) async {
  // 自动刷新过期 token
  if (response.statusCode == 401) {
    await AuthService.refreshToken();
  }
  // 记录日志
  print('[${response.statusCode}] ${response.duration.inMilliseconds}ms');
  return response;
});
```

---

### 限速

控制下载和上传速度（单位：字节/秒）：

```dart
final client = NativeNetClient(
  config: NativeNetConfig(
    maxDownloadSpeed: 1024 * 1024,  // 限速 1 MB/s
    maxUploadSpeed: 512 * 1024,     // 限速 512 KB/s
  ),
);
```

---

### 断点续传

配合 `downloadFile()` 使用，从指定字节偏移继续下载：

```dart
// 首次下载被中断后，检查已下载的字节数
final existingFile = File('/path/to/partial.zip');
final downloadedBytes = existingFile.lengthSync();

// 继续下载（需要服务器支持 Range 请求）
// 通过 NativeNetRequest 的底层 API 设置 resumeFrom
```

---

### 自定义 DNS

使用自定义 DNS 服务器（绕过系统 DNS）：

```dart
final client = NativeNetClient(
  config: NativeNetConfig(
    dnsServers: '1.1.1.1,8.8.8.8',  // Cloudflare + Google DNS
  ),
);
```

---

### 响应对象

`NativeNetResponse` 提供丰富的响应信息：

```dart
final response = await client.get('https://api.example.com/data');

// 基本信息
response.statusCode;      // int:      200, 404, 500…
response.reasonPhrase;    // String?:  "OK", "Not Found"…
response.duration;        // Duration: 请求总耗时
response.finalUrl;        // String?:  重定向后的最终 URL

// 响应体
response.body;            // String:   UTF-8 解码的响应体
response.bodyBytes;       // Uint8List: 原始字节
response.jsonBody;        // dynamic:  自动解析的 JSON

// 响应头
response.headers;         // Map<String, String>
response.contentLength;   // int: 响应体长度

// 状态判断
response.isSuccess;       // bool: 2xx
response.isRedirect;      // bool: 3xx
response.isClientError;   // bool: 4xx
response.isServerError;   // bool: 5xx
```

---

### 异常处理

所有网络错误都映射为类型化异常：

```dart
try {
  final response = await client.get('https://api.example.com/data');
} on TimeoutException catch (e) {
  // 连接超时或读取超时
  print('请求超时: ${e.message}');
} on ConnectionException catch (e) {
  // 无法连接（DNS 解析失败、服务器拒绝、网络断开等）
  print('连接失败: ${e.message}');
} on CertificateException catch (e) {
  // SSL/TLS 证书验证失败
  print('证书错误: ${e.message}');
} on CancelledException catch (e) {
  // 请求被 CancelToken 取消
  print('已取消: ${e.message}');
} on NativeNetException catch (e) {
  // 其他 libcurl 错误
  print('错误 [${e.code}]: ${e.message}');
}
```

异常继承关系：

```
NativeNetException (基类)
├── ConnectionException    (CURLE_COULDNT_CONNECT, DNS 失败等)
├── TimeoutException       (CURLE_OPERATION_TIMEDOUT)
├── CertificateException   (CURLE_SSL_*, 证书相关错误)
└── CancelledException     (CURLE_ABORTED_BY_CALLBACK)
```

---

## 工作原理

```
┌─ 主 Isolate ────────────────────────────────┐
│  NativeNetClient.get('https://...')          │
│       │                                       │
│       ├─ 应用拦截器、合并 headers               │
│       ├─ 分配 NativeNetProgressStruct (共享内存) │
│       ├─ 启动 Timer 轮询进度                    │
│       │                                       │
│       ▼                                       │
│  Isolate.run() ──────────────────────────┐   │
│       │  Worker Isolate                   │   │
│       │                                   │   │
│       ├─ 加载 libnative_net.so            │   │
│       ├─ Arena 分配 NativeNetRequestOptions│   │
│       ├─ 调用 native_net_request()        │   │
│       │       │                           │   │
│       │       ▼ (C 层, 阻塞)              │   │
│       │   curl_easy_perform()             │   │
│       │       │ 进度回调更新共享内存         │   │
│       │       ▼                           │   │
│       ├─ 读取 NativeNetResponse           │   │
│       ├─ Arena 释放所有原生内存             │   │
│       └─ 返回 Map ────────────────────────┘   │
│       │                                       │
│       ├─ 停止 Timer、释放进度结构体             │
│       ├─ 构造 NativeNetResponse               │
│       └─ 应用响应拦截器 → 返回给调用者          │
└───────────────────────────────────────────────┘
```

关键设计：
1. **不阻塞 UI 线程** — 所有 libcurl 调用都在 Worker Isolate 中执行
2. **内存安全** — 使用 `Arena` 自动管理所有 FFI 内存分配
3. **进度共享** — 通过原生共享内存 (`NativeNetProgress`) 在主 Isolate 和 Worker 之间传递进度
4. **取消协作** — 设置共享内存中的 `cancelled` 标志，libcurl 在下次进度回调时检查并中止

---

## libcurl 功能覆盖率

当前覆盖 libcurl 常用功能的 **~80%**：

| 功能类别 | libcurl 选项 | 状态 |
|---------|-------------|------|
| HTTP 方法 | GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS | ✅ |
| 自定义 Headers | CURLOPT_HTTPHEADER | ✅ |
| 请求体 (字符串/字节) | CURLOPT_POSTFIELDS | ✅ |
| 连接超时 | CURLOPT_CONNECTTIMEOUT_MS | ✅ |
| 读取超时 | CURLOPT_TIMEOUT_MS | ✅ |
| 自动重定向 | CURLOPT_FOLLOWLOCATION, CURLOPT_MAXREDIRS | ✅ |
| SSL 验证控制 | CURLOPT_SSL_VERIFYPEER, CURLOPT_SSL_VERIFYHOST | ✅ |
| 自定义 CA | CURLOPT_CAINFO, CURLOPT_CAPATH | ✅ |
| 客户端证书 (mTLS) | CURLOPT_SSLCERT, CURLOPT_SSLKEY, CURLOPT_SSLCERTTYPE | ✅ |
| 证书锁定 | CURLOPT_PINNEDPUBLICKEY | ✅ |
| HTTP 代理 | CURLOPT_PROXY, CURLOPT_PROXYTYPE | ✅ |
| SOCKS 代理 | CURLOPT_PROXY + SOCKS4/SOCKS5 | ✅ |
| 代理认证 | CURLOPT_PROXYUSERPWD | ✅ |
| 代理隧道 | CURLOPT_HTTPPROXYTUNNEL | ✅ |
| HTTP 认证 | CURLOPT_USERPWD, CURLOPT_HTTPAUTH | ✅ |
| Cookie 字符串 | CURLOPT_COOKIE | ✅ |
| Cookie 文件 | CURLOPT_COOKIEFILE, CURLOPT_COOKIEJAR | ✅ |
| HTTP 版本 | CURLOPT_HTTP_VERSION (1.0/1.1/2/3) | ✅ |
| 下载限速 | CURLOPT_MAX_RECV_SPEED_LARGE | ✅ |
| 上传限速 | CURLOPT_MAX_SEND_SPEED_LARGE | ✅ |
| 断点续传 | CURLOPT_RESUME_FROM_LARGE, CURLOPT_RANGE | ✅ |
| User-Agent | CURLOPT_USERAGENT | ✅ |
| 自定义 DNS | CURLOPT_DNS_SERVERS | ✅ |
| 主机名解析 | CURLOPT_RESOLVE | ✅ |
| 进度回调 | CURLOPT_XFERINFOFUNCTION | ✅ |
| 取消传输 | 进度回调返回非零 | ✅ |
| 透明压缩 | CURLOPT_ACCEPT_ENCODING (自动) | ✅ |
| TCP Keep-Alive | CURLOPT_TCP_KEEPALIVE (自动) | ✅ |
| 文件下载 (流式) | CURLOPT_WRITEFUNCTION + fwrite | ✅ |
| 文件上传 (流式) | curl_mime API | ✅ |
| Multipart 上传 | curl_mime_filedata | ✅ |
| Verbose 日志 | CURLOPT_VERBOSE | ✅ |

### 尚未封装 (~20%)

| 功能 | 说明 |
|------|------|
| WebSocket | libcurl 7.86+ 支持，待后续版本 |
| HTTP/2 Server Push | 高级 HTTP/2 特性 |
| HSTS | HTTP 严格传输安全 |
| Alt-Svc | 替代服务发现 |
| 网络接口绑定 | CURLOPT_INTERFACE |
| 自定义 SSL 引擎 | CURLOPT_SSLENGINE |
| 证书状态 (OCSP) | CURLOPT_SSL_VERIFYSTATUS |

---

## License

MIT License
