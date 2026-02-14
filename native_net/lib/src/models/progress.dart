/// Callback invoked periodically during file transfers.
///
/// [current] is the number of bytes transferred so far.
/// [total] is the total expected bytes, or 0 if unknown.
typedef ProgressCallback = void Function(int current, int total);

/// A token that can be used to cancel an in-progress file transfer.
///
/// Pass a [CancelToken] to [NativeNetClient.downloadFile] or
/// [NativeNetClient.uploadFile], then call [cancel()] to abort.
///
/// ```dart
/// final token = CancelToken();
/// client.downloadFile(url, path, cancelToken: token);
/// // Later…
/// token.cancel();
/// ```
class CancelToken {
  bool _isCancelled = false;

  /// The native memory address of the progress struct.
  /// Set internally by the client when the transfer starts.
  int progressAddress = 0;

  /// Whether [cancel] has been called.
  bool get isCancelled => _isCancelled;

  /// Cancels the in-progress transfer.
  ///
  /// The cancellation is cooperative: the next time libcurl checks
  /// the progress callback (typically every few milliseconds), it
  /// will abort the transfer and throw a [CancelledException].
  void cancel() {
    _isCancelled = true;
    // The actual cancellation happens in the client code which
    // writes to the native progress struct.
  }
}
