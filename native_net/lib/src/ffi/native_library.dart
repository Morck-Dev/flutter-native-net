import 'dart:ffi';
import 'dart:io';

/// Loads the native_net shared library for the current platform.
DynamicLibrary openNativeLibrary() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libnative_net.so');
  }
  if (Platform.isLinux) {
    return DynamicLibrary.open('libnative_net.so');
  }
  if (Platform.isIOS) {
    // On iOS, vendored xcframework is statically linked into the app.
    // Symbols are available in the current process.
    return DynamicLibrary.process();
  }
  if (Platform.isMacOS) {
    // On macOS, vendored xcframework is loaded as a dynamic framework.
    // Try the framework bundle first, fall back to process symbols.
    try {
      return DynamicLibrary.open('native_net.framework/native_net');
    } catch (_) {
      return DynamicLibrary.process();
    }
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('native_net.dll');
  }
  throw UnsupportedError(
    'native_net does not support ${Platform.operatingSystem}',
  );
}
