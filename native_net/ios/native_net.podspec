#
# iOS podspec - supports prebuilt XCFramework or build from source.
#
Pod::Spec.new do |s|
  s.name             = 'native_net'
  s.version          = '0.3.0'
  s.summary          = 'Flutter plugin for native HTTP networking using libcurl.'
  s.description      = <<-DESC
A Flutter FFI plugin that wraps libcurl for HTTP networking on iOS.
Uses prebuilt XCFramework or builds libcurl from source with Secure Transport.
                       DESC
  s.homepage         = 'https://github.com/Morck-Dev/flutter-native-net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Example' => 'example@example.com' }
  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.platform         = :ios, '9.0'

  xcfw_path = File.join(__dir__, 'Frameworks', 'native_net.xcframework')

  if File.exist?(xcfw_path)
    # --- Path A: Prebuilt XCFramework (fast, no build step) ---
    s.vendored_frameworks = 'Frameworks/native_net.xcframework'
    s.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES',
      'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    }
    Pod::UI.puts "[native_net] Using prebuilt XCFramework"
  else
    # --- Path B: Build from source (fallback) ---
    s.source_files = 'Classes/**/*.{c,h}'
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
    s.script_phase = {
      :name => 'Build libcurl for iOS',
      :script => 'bash "${PODS_TARGET_SRCROOT}/../scripts/build_curl_ios.sh" "${PODS_TARGET_SRCROOT}/Frameworks/curl-ios"',
      :execution_position => :before_compile,
      :shell_path => '/bin/bash',
    }
    Pod::UI.puts "[native_net] No prebuilt XCFramework, will build from source"
  end
end
