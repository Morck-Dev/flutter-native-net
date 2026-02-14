import 'dart:ffi';
import 'dart:io';

/// Loads the native_net shared library for the current platform.
///
/// The library is built via CMake (Android/Linux/Windows) or CocoaPods
/// (iOS/macOS) and bundled with the app automatically by Flutter.
DynamicLibrary openNativeLibrary() {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libnative_net.so');
  }
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }
  if (Platform.isMacOS) {
    return DynamicLibrary.open('native_net.framework/native_net');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('native_net.dll');
  }
  throw UnsupportedError(
    'native_net does not support ${Platform.operatingSystem}',
  );
}
