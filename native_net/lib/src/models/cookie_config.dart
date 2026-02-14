/// Cookie configuration for managing HTTP cookies.
///
/// ## In-memory cookies
/// ```dart
/// const cookies = CookieConfig(
///   cookies: 'session=abc123; theme=dark',
/// );
/// ```
///
/// ## Persistent cookie jar (read & write to file)
/// ```dart
/// const cookies = CookieConfig(
///   cookieFile: '/path/to/cookies.txt',   // read on start
///   cookieJar: '/path/to/cookies.txt',    // write on finish
/// );
/// ```
class CookieConfig {
  /// Cookies to send, in Netscape/HTTP format:
  /// `"name=value; name2=value2"`.
  final String? cookies;

  /// Path to a file to read cookies from (Netscape format).
  /// Set to `""` (empty string) to enable the cookie engine
  /// without loading any file.
  final String? cookieFile;

  /// Path to a file to write cookies to after the request.
  final String? cookieJar;

  const CookieConfig({
    this.cookies,
    this.cookieFile,
    this.cookieJar,
  });
}
