#
# macOS podspec – always builds libcurl from source.
#
Pod::Spec.new do |s|
  s.name             = 'native_net'
  s.version          = '0.2.0'
  s.summary          = 'Flutter plugin for native HTTP networking using libcurl.'
  s.description      = <<-DESC
A Flutter FFI plugin that wraps libcurl for HTTP networking on macOS.
libcurl is built from source with Secure Transport as the TLS backend
so the plugin has zero runtime dependencies on the host system.
                       DESC
  s.homepage         = 'https://github.com/example/flutter-native-net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Example' => 'example@example.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.{c,h}'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.14'

  # Build libcurl from source before compiling the plugin
  s.script_phase = {
    :name => 'Build libcurl for macOS',
    :script => 'bash "${PODS_TARGET_SRCROOT}/../scripts/build_curl_macos.sh" "${PODS_TARGET_SRCROOT}/Frameworks/curl-macos"',
    :execution_position => :before_compile,
    :shell_path => '/bin/bash',
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => [
      '"$(PODS_TARGET_SRCROOT)/../src"',
      '"$(PODS_TARGET_SRCROOT)/Frameworks/curl-macos/include"',
    ].join(' '),
    'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Frameworks/curl-macos/lib"',
    'OTHER_LDFLAGS' => '-lcurl',
  }
end
