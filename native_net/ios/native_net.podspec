#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint native_net.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'native_net'
  s.version          = '0.2.0'
  s.summary          = 'Flutter plugin for native HTTP networking using libcurl.'
  s.description      = <<-DESC
A Flutter FFI plugin that wraps libcurl for HTTP networking on iOS.
libcurl is built from source with Secure Transport as the TLS backend.
                       DESC
  s.homepage         = 'https://github.com/example/flutter-native-net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Example' => 'example@example.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.{c,h}'
  s.dependency 'Flutter'
  s.platform         = :ios, '9.0'

  # Header search path so native_net_ffi.c can find <curl/curl.h>
  # The build_curl_ios.sh script outputs to ios/Frameworks/curl-ios/
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => [
      '"$(PODS_TARGET_SRCROOT)/../src"',
      '"$(PODS_TARGET_SRCROOT)/Frameworks/curl-ios/include"',
    ].join(' '),
    'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Frameworks/curl-ios/lib"',
    'OTHER_LDFLAGS' => '-lcurl',
  }

  # Build script that compiles libcurl for iOS if not already present
  s.script_phase = {
    :name => 'Build libcurl for iOS',
    :script => 'bash "${PODS_TARGET_SRCROOT}/../scripts/build_curl_ios.sh" "${PODS_TARGET_SRCROOT}/Frameworks/curl-ios"',
    :execution_position => :before_compile,
    :shell_path => '/bin/bash',
  }
end
