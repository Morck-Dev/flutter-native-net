#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint native_net.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'native_net'
  s.version          = '0.2.0'
  s.summary          = 'Flutter plugin for native HTTP networking using libcurl.'
  s.description      = <<-DESC
A Flutter FFI plugin that wraps libcurl for HTTP networking on macOS.
Uses the system-provided libcurl (pre-installed on macOS).
                       DESC
  s.homepage         = 'https://github.com/example/flutter-native-net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Example' => 'example@example.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.{c,h}'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.14'

  # macOS ships with libcurl – just link against it
  s.library          = 'curl'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../src"',
  }
end
