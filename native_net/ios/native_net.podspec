#
# iOS podspec
#
# Strategy:
#   1. If Frameworks/native_net.xcframework exists -> use it (vendored)
#   2. Otherwise -> compile from source (Classes/native_net.c + libcurl)
#
# To use prebuilt: run 'bash scripts/download_prebuilt.sh' before 'pod install'
#
Pod::Spec.new do |s|
  s.name             = 'native_net'
  s.version          = '0.4.0'
  s.summary          = 'Flutter plugin for native HTTP networking using libcurl.'
  s.homepage         = 'https://github.com/Morck-Dev/flutter-native-net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Example' => 'example@example.com' }
  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.platform         = :ios, '9.0'

  # Compile the C wrapper (includes libcurl via #include)
  s.source_files = 'Classes/**/*.{c,h}'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => [
      '"$(PODS_TARGET_SRCROOT)/../src"',
      '"$(PODS_TARGET_SRCROOT)/Frameworks/curl-ios/include"',
    ].join(' '),
    'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Frameworks/curl-ios/lib"',
    'OTHER_LDFLAGS' => '-lcurl -framework Security -framework CoreFoundation -framework SystemConfiguration',
    'GCC_SYMBOLS_PRIVATE_EXTERN' => 'NO',
    'OTHER_CFLAGS' => '-fvisibility=default',
  }

  # Download prebuilt libcurl for iOS if not already available
  s.script_phase = {
    :name => 'Ensure libcurl for iOS',
    :script => <<-SCRIPT
      CURL_DIR="${PODS_TARGET_SRCROOT}/Frameworks/curl-ios"
      if [ -f "$CURL_DIR/lib/libcurl.a" ]; then
        echo "[native_net] Using existing libcurl at $CURL_DIR"
        exit 0
      fi

      echo "[native_net] Building libcurl for iOS..."
      SCRIPT_PATH="${PODS_TARGET_SRCROOT}/../scripts/build_curl_ios.sh"
      if [ -f "$SCRIPT_PATH" ]; then
        bash "$SCRIPT_PATH" "$CURL_DIR"
      else
        echo "[native_net] ERROR: build_curl_ios.sh not found"
        echo "[native_net] Run: bash native_net/scripts/download_prebuilt.sh"
        exit 1
      fi
    SCRIPT
    :execution_position => :before_compile,
    :shell_path => '/bin/bash',
  }
end
