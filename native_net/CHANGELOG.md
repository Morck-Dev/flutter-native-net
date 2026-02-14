## 0.3.0

* **降低平台最低版本** 以支持更老的设备：
  * Android: API 24 → **API 21** (Android 5.0 Lollipop, 2014)
  * iOS: 12.0 → **9.0** (iPhone 4S+, 2015)
  * macOS: 10.14 → **10.11** (El Capitan, 2015)
  * Linux: glibc 2.17+ (CentOS 7 / Ubuntu 14.04, 2014)
  * Windows: **Windows 7 SP1+** (2009)
* **重构 C API 为结构体传参** (`NativeNetRequestOptions`)
  * 全面暴露 libcurl TLS/SSL 选项
  * 全面暴露代理、Cookie、HTTP 认证、HTTP 版本、限速、DNS 等选项
  * libcurl 功能覆盖率从 ~25% 提升到 ~80%
* **新增 TLS 配置** (`TlsConfig`)：
  * `verifyPeer` / `verifyHost` — 自签名证书、IP 证书支持
  * `caInfoPath` / `caDirectoryPath` — 自定义 CA 证书
  * `clientCertPath` / `clientKeyPath` — 客户端证书 (mTLS)
  * `pinnedPublicKey` — 证书锁定
  * `TlsConfig.insecure` — 快捷方式跳过所有验证
* **新增代理配置** (`ProxyConfig`)：HTTP / SOCKS4 / SOCKS5 / 隧道
* **新增 Cookie 配置** (`CookieConfig`)：内存 Cookie / 文件持久化
* **新增 HTTP 版本控制** (`HttpVersion`)：1.0 / 1.1 / 2 / 3
* **新增限速**：`maxDownloadSpeed` / `maxUploadSpeed`
* **新增自定义 DNS**：`dnsServers`
* **新增 User-Agent 配置**
* 使用 Arena 管理 FFI 内存分配（自动释放）
* 29 个单元测试全部通过

## 0.2.1

* Always build libcurl from source (remove find_package)
* New: `downloadFile()`, `uploadFile()`, `CancelToken`, `ProgressCallback`

## 0.2.0

* Migrated from OkHttp/URLSession to unified libcurl backend
* Web platform support via Fetch API fallback
* Added Linux and Windows platform support

## 0.1.0

* Initial release with OkHttp (Android) and URLSession (iOS/macOS)
